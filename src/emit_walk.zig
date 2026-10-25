// std/emit's engine — a SHADOW walk. Traverses the same program.items the
// real emitter just consumed — decls, flows, continuations, sites — and asks
// the catalog the questions an emitter asks. Nothing reaches output: the
// stats + misses are the proof the traversal covers what the emitter
// touched — coverage first, bytes later (the same order the catalog earned
// its place: dual-answer, then sole-source).
const std = @import("std");
const ast = @import("ast");
const codegen_utils = @import("codegen_utils");

const CatalogTypes = std.StringHashMap([]const u8);

/// The row families the walk can currently ask: `type` (flat spellings, sole
/// source) and `construct` (capability index — the walk supplies the missing
/// positive direction: an invoked site the catalog doesn't claim is visible
/// here for the first time).
pub const Catalog = struct {
    types: ?*const CatalogTypes = null,
    constructs: ?*const CatalogTypes = null,
};

const Stats = struct {
    nodes: usize = 0,
    flows: usize = 0,
    continuations: usize = 0,
    sites: usize = 0,
    terminals: usize = 0,
    type_queries: usize = 0,
    type_answered: usize = 0,
    type_missed: usize = 0,
    construct_queries: usize = 0,
    construct_answered: usize = 0,
    construct_missed: usize = 0,
};

/// Flat-table-shaped questions only: a structural spelling ([]T, *X, {…},
/// T<U>) is a constructive arm, not a catalog row — the emitter's own flat
/// arm is consulted before structural fallthrough, so the shadow matches.
fn isFlatName(t: []const u8) bool {
    for (t) |ch| {
        if (!codegen_utils.exprIdentChar(ch) and ch != '.' and ch != '/' and
            ch != ':' and ch != ' ' and ch != '-') return false;
    }
    return t.len > 0;
}

/// Fields the emitter never asks a target spelling for: comptime-capture
/// markers (Source/Expression/InvocationMeta/File payloads) and phantom-
/// carrying fields — they are erased before emission, not emitted.
fn asksType(f: ast.Field) bool {
    return !(f.is_source or f.is_expression or f.is_invocation_meta or
        f.is_file or f.is_embed_file or f.phantom != null);
}

/// The compile driver's own vocabulary (compiler:*, compiler.ccp:*,
/// kernels:*, loops:* tors) rides every AST as coordination machinery — no
/// lane ever emits it, so the shadow skips its field-type questions too.
/// (Flow emission is bounded by flowEmitted's main-module rule, not this.)
fn driverModule(module: []const u8) bool {
    return std.mem.startsWith(u8, module, "compiler") or
        std.mem.eql(u8, module, "kernels") or
        std.mem.eql(u8, module, "loops");
}

/// Decls a lane never emits: `EventDecl.isComptimeOnly` is the emitter's own
/// rule (Source/Expression/Program params ⇒ erased at transform), plus the
/// `[norun]`/`[abstract]` annotations on compiler-machinery tors — their
/// CompilerContext/SiteResult fields ride the AST but reach no backend.
fn declSkipped(e: *const ast.EventDecl) bool {
    if (e.isComptimeOnly() or e.hasAnnotation("comptime") or
        e.hasAnnotation("norun") or e.hasAnnotation("abstract")) return true;
    return driverModule(e.module);
}

fn typeQuery(stats: *Stats, catalog: *const CatalogTypes, module: []const u8, decl: []const u8, koru_type: []const u8) void {
    const t = std.mem.trim(u8, koru_type, " \t");
    if (catalog.get(t)) |_| {
        stats.type_queries += 1;
        stats.type_answered += 1;
        return;
    }
    if (!isFlatName(t)) return;
    stats.type_queries += 1;
    stats.type_missed += 1;
    // Over-ask is a coverage question, not a declared-vs-live disagreement —
    // it stays out of catalog_drift.log so that artifact keeps its gate
    // semantics. Miss names ride stderr with the summary.
    if (stats.type_missed <= 16) {
        std.debug.print("std/emit shadow: type `{s}` on {s}:{s} has no catalog row\n", .{ t, module, decl });
    }
}

/// Site-key construction mirroring the construct row's `module:name`
/// spelling. Sites canonicalize the qualifier to dots (`std.io`), rows are
/// authored with slashes (`std/io`) — normalize so a site and a row name
/// the same construct. Allocates on page_allocator — the shadow is a
/// diagnostic pass inside a short-lived backend process.
fn constructKey(path: *const ast.DottedPath) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    const a = std.heap.page_allocator;
    if (path.module_qualifier) |mq| {
        for (mq) |ch| try buf.append(a, if (ch == '.') '/' else ch);
        try buf.append(a, ':');
    }
    for (path.segments, 0..) |seg, i| {
        if (i > 0) try buf.append(a, '.');
        try buf.appendSlice(a, seg);
    }
    return buf.toOwnedSlice(a);
}

/// The construct-row positive check, scoped to the row's own vocabulary:
/// construct rows name surface `std/*:` capabilities, so only `std.`/`std/`-
/// qualified sites are questions. Local and transform-minted names
/// (`input:__store_write_game`) are the program's own events — they lower
/// by their own impls, not by catalog claim. Measured on the emitted AST:
/// surface-vocabulary names are compiled OUT by transforms (the store watch
/// becomes minted `__store_*` sites), so a nonzero query count is itself
/// informative — it means a surface construct survived to a site.
/// A transform-stamped surface provenance: `@from_construct("std/store:stored")`
/// on a minted site's marks names the surface verb it lowers — the post-
/// transform name is minted (`__store_write_game`) but the catalog row is the
/// surface vocabulary, so the mark is the only honest key. Marks are
/// pass-internal (never parsed from surface syntax) — an author cannot
/// counterfeit one.
fn markedConstruct(marks: []const []const u8) ?[]const u8 {
    const prefix = "@from_construct(\"";
    for (marks) |m| {
        if (std.mem.startsWith(u8, m, prefix) and m.len > prefix.len + 1 and
            m[m.len - 1] == ')' and m[m.len - 2] == '"')
        {
            return m[prefix.len .. m.len - 2];
        }
    }
    return null;
}

fn siteAsk(stats: *Stats, table: *const CatalogTypes, module: []const u8, key: []const u8) void {
    stats.construct_queries += 1;
    if (table.get(key)) |_| {
        stats.construct_answered += 1;
    } else {
        stats.construct_missed += 1;
        if (stats.construct_missed <= 16) {
            std.debug.print("std/emit shadow: site `{s}` (in {s}) has no construct row\n", .{ key, module });
        }
    }
}

fn siteQuery(stats: *Stats, constructs: ?*const CatalogTypes, module: []const u8, iv: *const ast.Invocation) void {
    const table = constructs orelse return;
    const path = &iv.path;
    // A stamp names why the site exists; the canonical name (when still
    // std-qualified) names what it emits. Both can be true — a stamped
    // watch impl head is still a `print` site — so ask both.
    if (markedConstruct(iv.marks)) |mk| siteAsk(stats, table, module, mk);
    const mq = path.module_qualifier orelse return;
    if (!std.mem.startsWith(u8, mq, "std.") and !std.mem.startsWith(u8, mq, "std/")) return;
    siteAsk(stats, table, module, constructKey(path) catch return);
}

fn walkNode(n: *const ast.Node, stats: *Stats, cat: *const Catalog, module: []const u8) void {
    stats.nodes += 1;
    switch (n.*) {
        .invocation => |*iv| {
            stats.sites += 1;
            siteQuery(stats, cat.constructs, module, iv);
        },
        .label_with_invocation => |*lwi| {
            stats.sites += 1;
            siteQuery(stats, cat.constructs, module, &lwi.invocation);
        },
        .terminal => stats.terminals += 1,
        .conditional_block => |*cb| {
            for (cb.nodes) |*sub| walkNode(sub, stats, cat, module);
        },
        .foreach => |*fe| {
            for (fe.branches) |*b| {
                for (b.body) |*c| walkContinuation(c, stats, cat, module);
            }
        },
        .conditional => |*cond| {
            for (cond.branches) |*b| {
                for (b.body) |*c| walkContinuation(c, stats, cat, module);
            }
        },
        .switch_result => |*sr| {
            for (sr.branches) |*b| {
                for (b.body) |*c| walkContinuation(c, stats, cat, module);
            }
        },
        else => {},
    }
}

fn walkContinuation(c: *const ast.Continuation, stats: *Stats, cat: *const Catalog, module: []const u8) void {
    stats.continuations += 1;
    stats.nodes += 1;
    if (c.node) |*n| walkNode(n, stats, cat, module);
    for (c.continuations) |*sub| walkContinuation(sub, stats, cat, module);
}

/// The emitter's own flow boundary (c_emitter emit(): only main-module
/// flows emit, impl_of/declaration/norun are skipped).
fn flowEmitted(f: *const ast.Flow, main_module: []const u8) bool {
    if (f.impl_of != null) return false;
    if (!std.mem.eql(u8, f.module, main_module)) return false;
    for (f.annotations) |ann| {
        if (std.mem.eql(u8, ann, "declaration") or std.mem.eql(u8, ann, "norun")) return false;
    }
    return true;
}

fn walkItems(items: []const ast.Item, stats: *Stats, cat: *const Catalog, main_module: []const u8) void {
    for (items) |*item| {
        stats.nodes += 1;
        switch (item.*) {
            .module_decl => |*m| walkItems(m.items, stats, cat, main_module),
            .event_decl => |*e| {
                const types = cat.types orelse continue;
                if (declSkipped(e)) continue;
                const dname = if (e.path.segments.len > 0)
                    e.path.segments[e.path.segments.len - 1]
                else
                    "?";
                for (e.input.fields) |f| {
                    if (asksType(f)) typeQuery(stats, types, e.module, dname, f.type);
                }
                for (e.branches) |*b| {
                    for (b.payload.fields) |f| {
                        if (asksType(f)) typeQuery(stats, types, e.module, dname, f.type);
                    }
                    if (b.resume_type) |rt| typeQuery(stats, types, e.module, dname, rt);
                    if (b.resume_arms) |arms| {
                        for (arms) |arm| {
                            if (arm.type) |at| typeQuery(stats, types, e.module, dname, at);
                        }
                    }
                }
                if (e.return_type) |rt| typeQuery(stats, types, e.module, dname, rt);
            },
            .flow => |*f| {
                stats.flows += 1;
                if (f.impl_of != null) {
                    // `impl_of` skips only the emitter's standalone flow
                    // enumeration — the body still emits through its event
                    // (c_emitter impl_flows), so a stamped or std-qualified
                    // site inside an impl is a real emitted construct.
                    if (!std.mem.eql(u8, f.module, main_module)) continue;
                } else if (!flowEmitted(f, main_module)) continue;
                walkContinuation(&f.body, stats, cat, f.module);
            },
            else => {},
        }
    }
}

// ---------------------------------------------------------------------------
// Write stage — the walk stops only asking and starts sequencing. Coverage
// proved the traversal sees what the emitter touches; this stage proves the
// emitted TEXT agrees, one decl at a time, under the same dual-answer
// discipline the builtin solver used (the displaced path renders into
// scratch beside the walk's, a byte mismatch is drift, the oracle wins).
// ---------------------------------------------------------------------------

/// The agnostic decl classification — which emission shape a declared
/// event takes. Every lane's write path asks this; it is the piece of
/// "what emits" that is not target grammar. Mirrors the oracle's own
/// order: stub first (it pre-empts wildcard and branches), then wildcard,
/// then branched (an all-`!` event still gets its tagged-result decl and
/// input struct — only the prototype is absent), then plain.
pub const DeclShape = enum { stub, wildcard, branched, plain };

fn declStub(event: *const ast.EventDecl) bool {
    return event.hasAnnotation("transform") or event.hasAnnotation("comptime") or
        event.hasAnnotation("norun") or event.hasAnnotation("keyword");
}

fn hasEffectBranch(event: *const ast.EventDecl) bool {
    for (event.branches) |*b| {
        if (b.kind == .effect) return true;
    }
    return false;
}

pub fn declShape(event: *const ast.EventDecl) DeclShape {
    if (declStub(event)) return .stub;
    if (event.input.is_wildcard) return .wildcard;
    if (event.branches.len > 0) return .branched;
    return .plain;
}

/// The spelling questions a C write path asks — narrow answers only.
/// The walk owns sequencing and grammar; the lane answers names and
/// types. Member/tag spellings (`cMemberName`, `cResTagConst`,
/// `cPayloadMember`) are codegen_utils-shared, not writer questions.
pub const CDeclWriter = struct {
    ctx: ?*anyopaque = null,
    /// koru type → C spelling (catalog-sole-source on the oracle).
    typeOf: *const fn (ctx: ?*anyopaque, koru_type: []const u8) ?[]const u8,
    /// field name → C member spelling.
    memberName: *const fn (ctx: ?*anyopaque, allocator: std.mem.Allocator, name: []const u8) []const u8,
    /// event path → C function name.
    manglePath: *const fn (ctx: ?*anyopaque, allocator: std.mem.Allocator, path: ast.DottedPath) ?[]const u8,
    /// The bound input parameter's spelling (`__koru_in` on the oracle).
    inputParam: []const u8 = "__koru_in",
};

fn writeInStruct(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    w: *const CDeclWriter,
    event: *const ast.EventDecl,
    name: []const u8,
) error{OutOfMemory, UnsupportedConstruct}!void {
    try out.print(allocator, "struct {s}_in {{\n", .{name});
    for (event.input.fields) |f| {
        if (codegen_utils.cArrayType(f.type, w.typeOf, w.ctx)) |at| {
            try out.print(allocator, "    {s} {s}{s};\n", .{ at.base, w.memberName(w.ctx, allocator, f.name), at.dims });
            continue;
        }
        const ct = w.typeOf(w.ctx, f.type) orelse return error.UnsupportedConstruct;
        try out.print(allocator, "    {s} {s};\n", .{ ct, w.memberName(w.ctx, allocator, f.name) });
    }
    try out.appendSlice(allocator, "};\n");
}

fn writeInParam(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    w: *const CDeclWriter,
    event: *const ast.EventDecl,
    name: []const u8,
) error{OutOfMemory}!void {
    if (event.input.fields.len == 0) {
        try out.appendSlice(allocator, "void");
    } else {
        try out.print(allocator, "struct {s}_in {s}", .{ name, w.inputParam });
    }
}

/// A branch's `_res` member type — the agnostic payload rules the oracle
/// carries: `| x *` (wildcard) mints the one-byte-hole `struct <n>_<b>_t`;
/// a bare `__type_ref` payload unwraps to the field's own type; `__type_ref`
/// mixed with named fields refuses (outside the fragment); named fields
/// mint `struct <n>_<b>_t` — and every field must answer a C type.
fn writePayloadCType(
    allocator: std.mem.Allocator,
    w: *const CDeclWriter,
    event_name: []const u8,
    b: *const ast.Branch,
) error{OutOfMemory, UnsupportedConstruct}!?[]const u8 {
    const eql = std.mem.eql;
    if (b.payload.is_wildcard) {
        return try std.fmt.allocPrint(allocator, "struct {s}_{s}_t", .{ event_name, w.memberName(w.ctx, allocator, b.name) });
    }
    const fs = b.payload.fields;
    if (fs.len == 0) return null;
    if (fs.len == 1 and eql(u8, fs[0].name, "__type_ref")) {
        return w.typeOf(w.ctx, fs[0].type) orelse error.UnsupportedConstruct;
    }
    for (fs) |f| {
        if (eql(u8, f.name, "__type_ref")) return error.UnsupportedConstruct;
        if (w.typeOf(w.ctx, f.type) == null) return error.UnsupportedConstruct;
    }
    return try std.fmt.allocPrint(allocator, "struct {s}_{s}_t", .{ event_name, w.memberName(w.ctx, allocator, b.name) });
}

/// `enum { <n>_tag_<b>, … };` + record payload structs + `struct <n>_res`
/// — the tagged-result machinery, sequenced by the walk. `!` effect
/// branches splice per call site: their payload structs still emit (the
/// raise reads the type), but the enum and `_res` members are
/// terminal-only. The C text lives here; the lane only answers spellings.
fn writeTaggedResultDecl(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    w: *const CDeclWriter,
    event: *const ast.EventDecl,
    name: []const u8,
) anyerror!void {
    const eql = std.mem.eql;
    var terminal_count: usize = 0;
    for (event.branches) |*b| {
        if (b.kind == .effect) continue;
        terminal_count += 1;
        _ = try writePayloadCType(allocator, w, name, b);
    }
    for (event.branches) |*b| {
        const fs = b.payload.fields;
        const is_rec = (fs.len > 0 and !eql(u8, fs[0].name, "__type_ref")) or b.payload.is_wildcard;
        if (!is_rec) continue;
        try out.print(allocator, "struct {s}_{s}_t {{\n", .{ name, w.memberName(w.ctx, allocator, b.name) });
        if (b.payload.is_wildcard) {
            // C has no `struct {}` — one byte carries the shape hole.
            try out.appendSlice(allocator, "    char __koru_wildcard;\n");
        } else {
            for (fs) |f| {
                const ct = w.typeOf(w.ctx, f.type) orelse return error.UnsupportedConstruct;
                try out.print(allocator, "    {s} {s};\n", .{ ct, w.memberName(w.ctx, allocator, f.name) });
            }
        }
        try out.appendSlice(allocator, "};\n");
    }
    if (terminal_count == 0) return;
    try out.appendSlice(allocator, "enum {\n");
    for (event.branches) |*b| {
        if (b.kind == .effect) continue;
        try out.print(allocator, "    {s},\n", .{codegen_utils.cResTagConst(allocator, name, b.name)});
    }
    try out.appendSlice(allocator, "};\n");
    try out.print(allocator, "struct {s}_res {{\n", .{name});
    try out.appendSlice(allocator, "    int tag;\n");
    for (event.branches) |*b| {
        if (b.kind == .effect) continue;
        const ptype = (try writePayloadCType(allocator, w, name, b)) orelse continue;
        try out.print(allocator, "    {s} {s};\n", .{ ptype, codegen_utils.cPayloadMember(allocator, b.name) });
    }
    try out.appendSlice(allocator, "};\n");
}

/// One event declaration — `struct <n>_in`, tagged-result decl, forward
/// prototype — sequenced by `declShape`, spelled by the writer. This is
/// the oracle's `emitEventDeclaration` lifted onto the walk; during the
/// dual-answer stage the oracle still emits its own text and this
/// renders beside it into scratch.
pub fn writeEventDecl(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    event: *const ast.EventDecl,
    w: *const CDeclWriter,
) anyerror!void {
    const name = w.manglePath(w.ctx, allocator, event.path) orelse return error.UnsupportedConstruct;
    switch (declShape(event)) {
        .stub => try out.print(allocator, "static void {s}(void);\n", .{name}),
        .wildcard => {},
        .branched => {
            try writeTaggedResultDecl(out, allocator, w, event, name);
            if (event.input.fields.len > 0) try writeInStruct(out, allocator, w, event, name);
            // An all-`!` event is never a C function — its `|c` body is
            // per-call-site inline text, so no prototype exists either.
            if (!hasEffectBranch(event)) {
                try out.print(allocator, "static struct {s}_res {s}(", .{ name, name });
                try writeInParam(out, allocator, w, event, name);
                try out.appendSlice(allocator, ");\n");
            }
        },
        .plain => {
            if (event.input.fields.len > 0) try writeInStruct(out, allocator, w, event, name);
            const ret = if (event.return_type) |rt|
                w.typeOf(w.ctx, rt) orelse return error.UnsupportedConstruct
            else
                "void";
            try out.print(allocator, "static {s} {s}(", .{ ret, name });
            try writeInParam(out, allocator, w, event, name);
            try out.appendSlice(allocator, ");\n");
        },
    }
}

/// Shadow-pass entry — call after a successful emission, on the same AST.
/// Prints coverage to stderr; misses are advisory (stderr), never drift —
/// an over-ask is a coverage question, not a declared-vs-live disagreement.
pub fn shadow(program: *const ast.Program, cat: *const Catalog) void {
    var stats = Stats{};
    walkItems(program.items, &stats, cat, program.main_module_name);
    std.debug.print(
        "std/emit shadow: {d} items, {d} flows, {d} continuations, {d} sites, {d} terminals; " ++
            "type {d}/{d} answered, construct {d}/{d} answered\n",
        .{
            stats.nodes,               stats.flows,        stats.continuations,
            stats.sites,               stats.terminals,    stats.type_answered,
            stats.type_queries,        stats.construct_answered,
            stats.construct_queries,
        },
    );
}
