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

fn collectFiles(alloc: std.mem.Allocator, roots: []const []const u8) !std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    for (roots) |root| {
        const st = std.fs.cwd().statFile(root) catch |e| {
            std.debug.print("deslop: cannot stat '{s}': {s}\n", .{ root, @errorName(e) });
            return e;
        };
        if (st.kind == .file) {
            if (std.mem.endsWith(u8, root, ".zig")) try out.append(alloc, try alloc.dupe(u8, root));
            continue;
        }
        var dir = std.fs.cwd().openDir(root, .{ .iterate = true }) catch continue;
        defer dir.close();
        var walker = try dir.walk(alloc);
        defer walker.deinit();
        while (try walker.next()) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".zig")) continue;
            const p = try std.fs.path.join(alloc, &.{ root, entry.path });
            try out.append(alloc, p);
        }
    }
    return out;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    var min_tokens: usize = 48;
    var top: usize = 20;
    var roots: std.ArrayList([]const u8) = .empty;
    const args = try std.process.argsAlloc(alloc);
    for (args[1..]) |a| {
        if (std.mem.startsWith(u8, a, "--min-tokens=")) {
            min_tokens = try std.fmt.parseInt(usize, a["--min-tokens=".len..], 10);
        } else if (std.mem.startsWith(u8, a, "--top=")) {
            top = try std.fmt.parseInt(usize, a["--top=".len..], 10);
        } else {
            try roots.append(alloc, a);
        }
    }
    if (roots.items.len == 0) try roots.append(alloc, "src");

    const paths = try collectFiles(alloc, roots.items);

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
