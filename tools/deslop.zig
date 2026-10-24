// deslop — AST-subtree clone census for Zig sources.
//
// For every AST node spanning >= --min-tokens normalized tokens, hash the
// normalized token-tag sequence of its span. Normalization is the Type-2
// collapse: all identifiers share a token tag already, string/char
// literals fold to STR, numbers to NUM, doc comments drop out — so two
// subtrees that differ only in names and literals hash identically.
// Equal hashes form a clone cluster; ranking is
//   weight = tokens * (max_members - 1) * log2(1 + bytes)
// where max_members excludes members strictly contained in a larger
// duplicated node in the same file (nested clones don't double-count).
//
//   zig run tools/deslop.zig -- src/ --top=25 --min-tokens=48
//
// Sibling passes on the same walk:
//
//   --dead   dead-decl census: container-level decls whose name appears
//            nowhere else. Non-pub decls are file-confined, so a name with
//            no second identifier occurrence IN ITS OWN FILE is dead by
//            construction. Pub decls are judged against a raw-text
//            identifier harvest of the analysis roots plus every --refs
//            root — strings and comments count as occurrences, so the
//            public list is a candidate set, not a verdict (a name inside
//            a doc or a dead string keeps a decl off the list). test decls,
//            extern/export decls, and `main` are entry points, skipped.
//
//   --names  name-collision census: named decls sharing a spelling with
//            DIFFERENT normalized fingerprints — same name, different
//            contract (concepts/frag-dedup-is-lift-then-delete.md's
//            runtime_registry matchGlob class). Same-name same-hash groups
//            are clone clusters, the main census's territory, and are only
//            counted in the summary.
//
//   --refs=<path>  extra roots for the --dead corpus harvest (repeatable);
//            every file under the root contributes identifiers. .kz host
//            strings reach src/ decls, so koru_std is a required ref root
//            for a truthful public report.

const std = @import("std");
const Ast = std.zig.Ast;
const Token = std.zig.Token;

const STR: u32 = 0x10001;
const NUM: u32 = 0x10002;

fn normTag(tag: Token.Tag) ?u32 {
    return switch (tag) {
        .doc_comment, .container_doc_comment => null,
        .string_literal, .multiline_string_literal_line, .char_literal => STR,
        .number_literal => NUM,
        else => @intFromEnum(tag),
    };
}

const Member = struct {
    file: usize,
    node: Ast.Node.Index,
    t0: Ast.TokenIndex,
    t1: Ast.TokenIndex,
    bytes: usize,
    toks: usize,
    shadowed: bool = false,
};

const FileInfo = struct {
    path: []const u8,
    tree: Ast,
    source: [:0]const u8,
};

const Decl = struct {
    file: usize,
    node: Ast.Node.Index,
    name: []const u8,
    qual: []const u8,
    name_tok: Ast.TokenIndex,
    is_pub: bool,
    is_extern: bool,
    is_fn: bool,
    is_method: bool,
    is_alias: bool,
    hash: u64,
};

fn nodeHash(tree: *const Ast, node: Ast.Node.Index) !struct { hash: u64, t0: Ast.TokenIndex, t1: Ast.TokenIndex, toks: usize } {
    const t0 = tree.firstToken(node);
    const t1 = tree.lastToken(node);
    if (t1 <= t0) return error.Empty;
    var h = std.hash.Wyhash.init(0xD3510);
    var toks: usize = 0;
    const tags = tree.tokens.items(.tag);
    var t = t0;
    while (t <= t1) : (t += 1) {
        if (normTag(tags[t])) |v| {
            h.update(std.mem.asBytes(&v));
            toks += 1;
        }
    }
    return .{ .hash = h.final(), .t0 = t0, .t1 = t1, .toks = toks };
}

// init is a name-resolution alias — `const X = @import(...)` or a pure
// re-export path `const X = module.Y` — a pointer at a contract, not one
fn initIsAlias(tree: *const Ast, init: Ast.Node.Index) bool {
    const t0 = tree.firstToken(init);
    const t1 = tree.lastToken(init);
    if (std.mem.eql(u8, tree.tokenSlice(t0), "@import")) return true;
    const tags = tree.tokens.items(.tag);
    var t = t0;
    var expect_ident = true;
    while (t <= t1) : (t += 1) {
        if (expect_ident) {
            if (tags[t] != .identifier) return false;
        } else if (tags[t] != .period) return false;
        expect_ident = !expect_ident;
    }
    return !expect_ident;
}

fn qualName(alloc: std.mem.Allocator, prefix: []const u8, name: []const u8) ![]const u8 {
    if (prefix.len == 0) return name;
    return std.fmt.allocPrint(alloc, "{s}.{s}", .{ prefix, name });
}

fn collectDecls(
    alloc: std.mem.Allocator,
    fi: *const FileInfo,
    fidx: usize,
    members: []const Ast.Node.Index,
    prefix: []const u8,
    out: *std.ArrayList(Decl),
) !void {
    const tree = &fi.tree;
    var cbuf: [2]Ast.Node.Index = undefined;
    for (members) |m| {
        switch (tree.nodeTag(m)) {
            .fn_decl, .fn_proto, .fn_proto_simple, .fn_proto_multi, .fn_proto_one => {
                var pbuf: [1]Ast.Node.Index = undefined;
                const proto = tree.fullFnProto(&pbuf, m) orelse continue;
                const nt = proto.name_token orelse continue;
                const name = tree.tokenSlice(nt);
                const nh = nodeHash(tree, m) catch continue;
                const tags = tree.tokens.items(.tag);
                const is_extern = if (proto.extern_export_inline_token) |t|
                    tags[t] == .keyword_extern or tags[t] == .keyword_export
                else
                    false;
                try out.append(alloc, .{
                    .file = fidx,
                    .node = m,
                    .name = name,
                    .qual = try qualName(alloc, prefix, name),
                    .name_tok = nt,
                    .is_pub = proto.visib_token != null,
                    .is_extern = is_extern,
                    .is_fn = true,
                    .is_method = prefix.len > 0,
                    .is_alias = false,
                    .hash = nh.hash,
                });
            },
            .global_var_decl, .local_var_decl, .simple_var_decl, .aligned_var_decl => {
                const vd = tree.fullVarDecl(m) orelse continue;
                const nt = tree.nodeMainToken(m) + 1;
                if (tree.tokens.items(.tag)[nt] != .identifier) continue;
                const name = tree.tokenSlice(nt);
                const nh = nodeHash(tree, m) catch continue;
                const qual = try qualName(alloc, prefix, name);
                var is_alias = false;
                if (vd.ast.init_node.unwrap()) |init| {
                    is_alias = initIsAlias(tree, init);
                    if (tree.fullContainerDecl(&cbuf, init)) |cd| {
                        try collectDecls(alloc, fi, fidx, cd.ast.members, qual, out);
                    }
                }
                try out.append(alloc, .{
                    .file = fidx,
                    .node = m,
                    .name = name,
                    .qual = qual,
                    .name_tok = nt,
                    .is_pub = vd.visib_token != null,
                    .is_extern = vd.extern_export_token != null,
                    .is_fn = false,
                    .is_method = prefix.len > 0,
                    .is_alias = is_alias,
                    .hash = nh.hash,
                });
            },
            else => continue,
        }
    }
}

fn collectFiles(alloc: std.mem.Allocator, roots: []const []const u8, exts_only: bool) !std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    for (roots) |root| {
        const st: ?std.fs.File.Stat = std.fs.cwd().statFile(root) catch |e| blk: {
            // Windows statFile refuses directories (IsDir) where POSIX
            // stat() answers — a directory root means descend, same result.
            if (e == error.IsDir) break :blk null;
            std.debug.print("deslop: cannot stat '{s}': {s}\n", .{ root, @errorName(e) });
            return e;
        };
        if (st != null and st.?.kind == .file) {
            if (!exts_only or std.mem.endsWith(u8, root, ".zig")) try out.append(alloc, try alloc.dupe(u8, root));
            continue;
        }
        var dir = std.fs.cwd().openDir(root, .{ .iterate = true }) catch continue;
        defer dir.close();
        var walker = try dir.walk(alloc);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (exts_only and !std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            if (std.mem.startsWith(u8, entry.basename, ".") or
                std.mem.indexOf(u8, entry.path, ".zig-cache") != null or
                std.mem.indexOf(u8, entry.path, "zig-out") != null or
                std.mem.indexOf(u8, entry.path, "node_modules") != null or
                std.mem.indexOf(u8, entry.path, "__pycache__") != null) continue;
            const p = try std.fs.path.join(alloc, &.{ root, entry.path });
            try out.append(alloc, p);
        }
    }
    return out;
}

fn harvestIdents(counts: *std.StringHashMap(usize), text: []const u8) !void {
    var i: usize = 0;
    while (i < text.len) {
        const c = text[i];
        if (c == '_' or std.ascii.isAlphabetic(c)) {
            const start = i;
            while (i < text.len and (text[i] == '_' or std.ascii.isAlphanumeric(text[i]))) i += 1;
            const gop = try counts.getOrPut(text[start..i]);
            if (!gop.found_existing) gop.value_ptr.* = 0;
            gop.value_ptr.* += 1;
        } else i += 1;
    }
}

fn lineOf(tree: *const Ast, tok: Ast.TokenIndex) usize {
    return tree.tokenLocation(0, tok).line + 1;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var min_tokens: usize = 48;
    var top: usize = 20;
    var mode_dead = false;
    var mode_names = false;
    var roots: std.ArrayList([]const u8) = .empty;
    var ref_roots: std.ArrayList([]const u8) = .empty;
    const args = try std.process.argsAlloc(alloc);
    for (args[1..]) |a| {
        if (std.mem.startsWith(u8, a, "--min-tokens=")) {
            min_tokens = try std.fmt.parseInt(usize, a["--min-tokens=".len..], 10);
        } else if (std.mem.startsWith(u8, a, "--top=")) {
            top = try std.fmt.parseInt(usize, a["--top=".len..], 10);
        } else if (std.mem.eql(u8, a, "--dead")) {
            mode_dead = true;
        } else if (std.mem.eql(u8, a, "--names")) {
            mode_names = true;
        } else if (std.mem.startsWith(u8, a, "--refs=")) {
            try ref_roots.append(alloc, a["--refs=".len..]);
        } else {
            try roots.append(alloc, a);
        }
    }
    if (roots.items.len == 0) try roots.append(alloc, "src");

    const paths = try collectFiles(alloc, roots.items, true);

    var files: std.ArrayList(FileInfo) = .empty;
    var skipped: usize = 0;
    for (paths.items) |p| {
        const src = std.fs.cwd().readFileAllocOptions(alloc, p, 64 << 20, null, .of(u8), 0) catch |e| {
            skipped += 1;
            std.debug.print("deslop: skipped {s} ({s})\n", .{ p, @errorName(e) });
            continue;
        };
        const tree = try Ast.parse(alloc, src, .zig);
        if (tree.errors.len > 0) {
            skipped += 1;
            std.debug.print("deslop: skipped {s} ({d} parse errors)\n", .{ p, tree.errors.len });
            continue;
        }
        try files.append(alloc, .{ .path = p, .tree = tree, .source = src });
    }

    if (mode_dead or mode_names) {
        var decls: std.ArrayList(Decl) = .empty;
        for (files.items, 0..) |*fi, fidx| {
            try collectDecls(alloc, fi, fidx, fi.tree.rootDecls(), "", &decls);
        }
        if (mode_dead) {
            // file-confined references: identifier tokens in the same file
            var file_counts = try alloc.alloc(std.StringHashMap(usize), files.items.len);
            for (files.items, 0..) |fi, fidx| {
                file_counts[fidx] = std.StringHashMap(usize).init(alloc);
                const tags = fi.tree.tokens.items(.tag);
                for (tags, 0..) |t, ti| {
                    if (t != .identifier) continue;
                    const s = fi.tree.tokenSlice(@intCast(ti));
                    const gop = try file_counts[fidx].getOrPut(s);
                    if (!gop.found_existing) gop.value_ptr.* = 0;
                    gop.value_ptr.* += 1;
                }
            }
            // corpus-wide references: raw text of the parsed sources plus
            // every file under each --refs root
            var corpus = std.StringHashMap(usize).init(alloc);
            for (files.items) |fi| try harvestIdents(&corpus, fi.source);
            var ref_files: usize = 0;
            const ref_paths = try collectFiles(alloc, ref_roots.items, false);
            for (ref_paths.items) |p| {
                if (std.mem.endsWith(u8, p, ".png") or std.mem.endsWith(u8, p, ".mp4") or
                    std.mem.endsWith(u8, p, ".vsix") or std.mem.endsWith(u8, p, ".zip")) continue;
                const txt = std.fs.cwd().readFileAlloc(alloc, p, 8 << 20) catch continue;
                ref_files += 1;
                try harvestIdents(&corpus, txt);
            }

            var out_buf: std.Io.Writer.Allocating = .init(alloc);
            const w = &out_buf.writer;
            var priv_dead: usize = 0;
            var pub_dead: usize = 0;
            try w.print("dead-decl: {d} files parsed ({d} skipped), {d} named decls; refs corpus: {d} files over {d} roots\n", .{ files.items.len, skipped, decls.items.len, ref_files, ref_roots.items.len });
            try w.print("PRIVATE dead (non-pub; name occurs only at its decl site in its own file):\n", .{});
            for (decls.items) |d| {
                if (d.is_pub or d.is_extern or std.mem.eql(u8, d.name, "main")) continue;
                const seen = file_counts[d.file].get(d.name) orelse 0;
                if (seen > 1) continue;
                priv_dead += 1;
                try w.print("  {s}:{d}  {s}{s}\n", .{ files.items[d.file].path, lineOf(&files.items[d.file].tree, d.name_tok), d.qual, if (d.is_fn) "()" else "" });
            }
            try w.print("  ({d})\nPUBLIC dead candidates (pub; name occurs only at its decl site corpus-wide — strings and docs count, verify before deleting):\n", .{priv_dead});
            for (decls.items) |d| {
                if (!d.is_pub or d.is_extern or std.mem.eql(u8, d.name, "main")) continue;
                const seen = corpus.get(d.name) orelse 0;
                if (seen > 1) continue;
                pub_dead += 1;
                try w.print("  {s}:{d}  {s}{s}\n", .{ files.items[d.file].path, lineOf(&files.items[d.file].tree, d.name_tok), d.qual, if (d.is_fn) "()" else "" });
            }
            try w.print("  ({d})\n", .{pub_dead});
            try std.fs.File.stdout().writeAll(out_buf.writer.buffered());
            return;
        }
        // --names
        var by_name = std.StringHashMap(std.ArrayList(usize)).init(alloc);
        var n_aliases: usize = 0;
        for (decls.items, 0..) |d, di| {
            // alias decls resolve a name, they don't declare a contract
            if (d.is_alias) {
                n_aliases += 1;
                continue;
            }
            const gop = try by_name.getOrPut(d.name);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(alloc, di);
        }
        const Group = struct {
            name: []const u8,
            members: []usize,
            n_hashes: usize,
            cross_file: bool,
            file_scope: bool,
        };
        // every type carries these; same name across types is the benign
        // protocol case, not the collision class
        const conventional = std.StaticStringMap(void).initComptime(.{
            .{"init"}, .{"deinit"},
        });
        var file_groups: std.ArrayList(Group) = .empty;
        var method_groups: std.ArrayList(Group) = .empty;
        var clone_groups: usize = 0;
        var conventional_groups: usize = 0;
        var nit = by_name.iterator();
        while (nit.next()) |e| {
            const members = e.value_ptr.items;
            if (members.len < 2) continue;
            var hashes = std.AutoHashMap(u64, void).init(alloc);
            var cross = false;
            var n_file_scope: usize = 0;
            for (members) |di| {
                const d = decls.items[di];
                try hashes.put(d.hash, {});
                if (d.file != decls.items[members[0]].file) cross = true;
                if (!d.is_method) n_file_scope += 1;
            }
            if (hashes.count() < 2) {
                clone_groups += 1;
                continue;
            }
            const g: Group = .{ .name = e.key_ptr.*, .members = members, .n_hashes = hashes.count(), .cross_file = cross, .file_scope = n_file_scope >= 2 };
            if (!g.file_scope and conventional.has(g.name)) {
                conventional_groups += 1;
                continue;
            }
            if (g.file_scope) {
                try file_groups.append(alloc, g);
            } else {
                try method_groups.append(alloc, g);
            }
        }
        const groupLess = struct {
            fn lt(_: void, a: Group, b: Group) bool {
                if (a.cross_file != b.cross_file) return a.cross_file;
                if (a.n_hashes != b.n_hashes) return a.n_hashes > b.n_hashes;
                return a.members.len > b.members.len;
            }
        }.lt;
        std.mem.sort(Group, file_groups.items, {}, groupLess);
        std.mem.sort(Group, method_groups.items, {}, groupLess);
        var out_buf: std.Io.Writer.Allocating = .init(alloc);
        const w = &out_buf.writer;
        try w.print("name-collision: {d} files, {d} named decls, {d} names shared; {d} file-scope + {d} method-scope divergent groups\n", .{ files.items.len, decls.items.len, by_name.count(), file_groups.items.len, method_groups.items.len });
        try w.print("suppressed: {d} clone-identical groups (census territory), {d} @import-alias decls excluded, {d} conventional-name groups (init/deinit)\n\n", .{ clone_groups, n_aliases, conventional_groups });
        try w.print("FILE-SCOPE (same name, different contract in the module namespace — the matchGlob class):\n", .{});
        for (file_groups.items[0..@min(top, file_groups.items.len)]) |g| {
            try w.print("{s}  {d}x, {d} fingerprints{s}\n", .{ g.name, g.members.len, g.n_hashes, if (g.cross_file) "  [cross-file]" else "" });
            for (g.members) |di| {
                const d = decls.items[di];
                try w.print("      {s}:{d}  {s}{s} {s} h={x:0>16}\n", .{ files.items[d.file].path, lineOf(&files.items[d.file].tree, d.name_tok), d.qual, if (d.is_fn) "()" else "", if (d.is_pub) "pub" else "   ", d.hash });
            }
        }
        try w.print("\nMETHOD-SCOPE (same name across types — usually protocol noise, ranked for the exceptions):\n", .{});
        for (method_groups.items[0..@min(top, method_groups.items.len)]) |g| {
            try w.print("{s}  {d}x, {d} fingerprints{s}\n", .{ g.name, g.members.len, g.n_hashes, if (g.cross_file) "  [cross-file]" else "" });
            for (g.members[0..@min(g.members.len, 8)]) |di| {
                const d = decls.items[di];
                try w.print("      {s}:{d}  {s}{s} {s} h={x:0>16}\n", .{ files.items[d.file].path, lineOf(&files.items[d.file].tree, d.name_tok), d.qual, if (d.is_fn) "()" else "", if (d.is_pub) "pub" else "   ", d.hash });
            }
            if (g.members.len > 8) try w.print("      ... +{d} more\n", .{g.members.len - 8});
        }
        try std.fs.File.stdout().writeAll(out_buf.writer.buffered());
        return;
    }

    // hash every node in every file
    var clusters = std.AutoHashMap(u64, std.ArrayList(Member)).init(alloc);
    var total_nodes: usize = 0;
    var hashed_nodes: usize = 0;
    for (files.items, 0..) |*fi, fidx| {
        const tree = &fi.tree;
        const n_nodes = tree.nodes.len;
        total_nodes += n_nodes;
        const starts = tree.tokens.items(.start);
        var i: u32 = 0;
        while (i < n_nodes) : (i += 1) {
            const node: Ast.Node.Index = @enumFromInt(i);
            const nh = nodeHash(tree, node) catch continue;
            if (nh.toks < min_tokens) continue;
            hashed_nodes += 1;
            const end = starts[nh.t1] + tree.tokenSlice(nh.t1).len;
            const gop = try clusters.getOrPut(nh.hash);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(alloc, .{
                .file = fidx,
                .node = node,
                .t0 = nh.t0,
                .t1 = nh.t1,
                .bytes = end - starts[nh.t0],
                .toks = nh.toks,
            });
        }
    }

    // mark members shadowed by a larger duplicated node in the same file:
    // gather every duplicated member's span per file, then check containment
    // only within that file's set
    var per_file = std.AutoHashMap(usize, std.ArrayList(*Member)).init(alloc);
    var pit = clusters.iterator();
    while (pit.next()) |e| {
        if (e.value_ptr.items.len < 2) continue;
        for (e.value_ptr.items) |*m| {
            const gop = try per_file.getOrPut(m.file);
            if (!gop.found_existing) gop.value_ptr.* = .empty;
            try gop.value_ptr.append(alloc, m);
        }
    }
    var fit = per_file.iterator();
    while (fit.next()) |e| {
        const spans = e.value_ptr.items;
        for (spans) |m| {
            for (spans) |o| {
                if (o.node != m.node and
                    o.t0 <= m.t0 and o.t1 >= m.t1 and (o.t0 < m.t0 or o.t1 > m.t1))
                {
                    m.shadowed = true;
                    break;
                }
            }
        }
    }

    const ClusterRow = struct {
        hash: u64,
        members: []Member,
        weight: f64,
        tag: []const u8,
        toks: usize,
        bytes: usize,
        cross_file: bool,
    };
    var rows: std.ArrayList(ClusterRow) = .empty;
    var n_clusters: usize = 0;
    var dup_members: usize = 0;
    var cit = clusters.iterator();
    while (cit.next()) |e| {
        const members = e.value_ptr.items;
        if (members.len < 2) continue;
        n_clusters += 1;
        var maximal: std.ArrayList(Member) = .empty;
        for (members) |m| {
            if (!m.shadowed) try maximal.append(alloc, m);
        }
        if (maximal.items.len < 2) continue;
        dup_members += maximal.items.len;
        const rep = maximal.items[0];
        var cross = false;
        for (maximal.items[1..]) |m| {
            if (m.file != rep.file) cross = true;
        }
        const bytes_f: f64 = @floatFromInt(rep.bytes);
        const weight = @as(f64, @floatFromInt(rep.toks)) *
            @as(f64, @floatFromInt(maximal.items.len - 1)) *
            @log2(1.0 + bytes_f);
        const tag = files.items[rep.file].tree.nodeTag(rep.node);
        try rows.append(alloc, .{
            .hash = e.key_ptr.*,
            .members = maximal.items,
            .weight = weight,
            .tag = @tagName(tag),
            .toks = rep.toks,
            .bytes = rep.bytes,
            .cross_file = cross,
        });
    }

    std.mem.sort(ClusterRow, rows.items, {}, struct {
        fn lt(_: void, a: ClusterRow, b: ClusterRow) bool {
            return a.weight > b.weight;
        }
    }.lt);

    var out_buf: std.Io.Writer.Allocating = .init(alloc);
    const w = &out_buf.writer;
    try w.print("files: {d} parsed, {d} skipped   nodes: {d} ({d} hashed >= {d} toks)\n", .{ files.items.len, skipped, total_nodes, hashed_nodes, min_tokens });
    try w.print("clusters: {d}   maximal members: {d}\n\n", .{ n_clusters, dup_members });

    const n_show = @min(top, rows.items.len);
    for (rows.items[0..n_show], 0..) |r, rank| {
        try w.print("#{d:2} w={d:7.0}  {d}x {s}  {d} toks / {d} B{s}\n", .{
            rank + 1, r.weight, r.members.len, r.tag, r.toks, r.bytes,
            if (r.cross_file) "  [cross-file]" else "",
        });
        for (r.members[0..@min(r.members.len, 8)]) |m| {
            const fi = files.items[m.file];
            const l0 = fi.tree.tokenLocation(0, m.t0).line + 1;
            const l1 = fi.tree.tokenLocation(0, m.t1).line + 1;
            try w.print("      {s}:{d}-{d}\n", .{ fi.path, l0, l1 });
        }
        if (r.members.len > 8) try w.print("      ... +{d} more\n", .{r.members.len - 8});
    }

    try std.fs.File.stdout().writeAll(out_buf.writer.buffered());
}
