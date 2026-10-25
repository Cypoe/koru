// std/emit's engine, first landing — a SHADOW walk. Traverses the same
// program.items the real emitter just consumed, classifies each item into
// the WalkNode shape declared in koru_std/emit.kz, and asks the catalog the
// flat-type questions an emitter asks. Nothing reaches output: the stats +
// misses are the proof the traversal covers what the emitter touched —
// coverage first, bytes later (the same order the catalog earned its place:
// dual-answer, then sole-source).
const std = @import("std");
const ast = @import("ast");
const codegen_utils = @import("codegen_utils");

const CatalogTypes = std.StringHashMap([]const u8);

const Stats = struct {
    nodes: usize = 0,
    type_queries: usize = 0,
    answered: usize = 0,
    missed: usize = 0,
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

/// Decls a lane never emits: `EventDecl.isComptimeOnly` is the emitter's own
/// rule (Source/Expression/Program params ⇒ erased at transform), plus the
/// `[norun]`/`[abstract]` annotations on compiler-machinery tors — their
/// CompilerContext/SiteResult fields ride the AST but reach no backend.
fn declSkipped(e: *const ast.EventDecl) bool {
    if (e.isComptimeOnly() or e.hasAnnotation("comptime") or
        e.hasAnnotation("norun") or e.hasAnnotation("abstract")) return true;
    // The compile driver's own tors (compiler:check-flow, compiler.ccp:*,
    // kernels:optimize, …) ride every AST as coordination vocabulary — no
    // lane ever emits them, so no lane asks their field types (measured:
    // every shadow miss sat on one of these modules).
    return std.mem.startsWith(u8, e.module, "compiler") or
        std.mem.eql(u8, e.module, "kernels") or
        std.mem.eql(u8, e.module, "loops");
}

fn typeQuery(stats: *Stats, catalog: *const CatalogTypes, module: []const u8, decl: []const u8, koru_type: []const u8) void {
    const t = std.mem.trim(u8, koru_type, " \t");
    if (catalog.get(t)) |_| {
        stats.type_queries += 1;
        stats.answered += 1;
        return;
    }
    if (!isFlatName(t)) return;
    stats.type_queries += 1;
    stats.missed += 1;
    // Over-ask is a coverage question, not a declared-vs-live disagreement —
    // it stays out of catalog_drift.log so that artifact keeps its gate
    // semantics. Miss names ride stderr with the summary.
    if (stats.missed <= 16) {
        std.debug.print("std/emit shadow: `{s}` on {s}:{s} has no catalog row\n", .{ t, module, decl });
    }
}

fn walkItems(items: []const ast.Item, stats: *Stats, catalog: ?*const CatalogTypes) void {
    for (items) |*item| {
        stats.nodes += 1;
        switch (item.*) {
            .module_decl => |*m| walkItems(m.items, stats, catalog),
            .event_decl => |*e| {
                if (catalog == null or declSkipped(e)) continue;
                const cat = catalog.?;
                const dname = if (e.path.segments.len > 0)
                    e.path.segments[e.path.segments.len - 1]
                else
                    "?";
                for (e.input.fields) |f| {
                    if (asksType(f)) typeQuery(stats, cat, e.module, dname, f.type);
                }
                for (e.branches) |*b| {
                    for (b.payload.fields) |f| {
                        if (asksType(f)) typeQuery(stats, cat, e.module, dname, f.type);
                    }
                    if (b.resume_type) |rt| typeQuery(stats, cat, e.module, dname, rt);
                    if (b.resume_arms) |arms| {
                        for (arms) |arm| {
                            if (arm.type) |at| typeQuery(stats, cat, e.module, dname, at);
                        }
                    }
                }
                if (e.return_type) |rt| typeQuery(stats, cat, e.module, dname, rt);
            },
            else => {},
        }
    }
}

/// Shadow-pass entry — call after a successful emission, on the same AST.
/// Prints coverage to stderr; per-miss drift lands in catalog_drift.log.
/// A null catalog = loader not wired for this lane; counts nodes only.
pub fn shadow(program: *const ast.Program, catalog: ?*const CatalogTypes) void {
    var stats = Stats{};
    walkItems(program.items, &stats, catalog);
    if (catalog) |_| {
        std.debug.print(
            "std/emit shadow: {d} items, {d} flat-type queries, {d} answered, {d} missed\n",
            .{ stats.nodes, stats.type_queries, stats.answered, stats.missed },
        );
    } else {
        std.debug.print("std/emit shadow: {d} items, no catalog loaded\n", .{stats.nodes});
    }
}
