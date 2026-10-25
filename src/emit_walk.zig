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
fn siteQuery(stats: *Stats, constructs: ?*const CatalogTypes, module: []const u8, path: *const ast.DottedPath) void {
    const mq = path.module_qualifier orelse return;
    if (!std.mem.startsWith(u8, mq, "std.") and !std.mem.startsWith(u8, mq, "std/")) return;
    const table = constructs orelse return;
    stats.construct_queries += 1;
    const key = constructKey(path) catch return;
    if (table.get(key)) |_| {
        stats.construct_answered += 1;
    } else {
        stats.construct_missed += 1;
        if (stats.construct_missed <= 16) {
            std.debug.print("std/emit shadow: site `{s}` (in {s}) has no construct row\n", .{ key, module });
        }
    }
}

fn walkNode(n: *const ast.Node, stats: *Stats, cat: *const Catalog, module: []const u8) void {
    stats.nodes += 1;
    switch (n.*) {
        .invocation => |*iv| {
            stats.sites += 1;
            siteQuery(stats, cat.constructs, module, &iv.path);
        },
        .label_with_invocation => |*lwi| {
            stats.sites += 1;
            siteQuery(stats, cat.constructs, module, &lwi.invocation.path);
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
                if (!flowEmitted(f, main_module)) continue;
                walkContinuation(&f.body, stats, cat, f.module);
            },
            else => {},
        }
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
