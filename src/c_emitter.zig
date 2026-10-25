// c_emitter.zig — sequential-fragment Koru → C emitter. The verification
// lane (docs/koru-verification-path.md): the emitted C is compiled by
// CompCert as the independent semantic oracle, so the bias everywhere is
// refuse-over-guess. A construct outside the first fragment surfaces as a
// named error, never as silently wrong output.
//
// FRAGMENT (what this emitter models, grown from the measured cells):
//   - event decls → `static <ret> <mangled>(struct <mangled>_in __koru_in)`
//   - `-> T` bare returns → the C return type; named `| branch` payloads →
//     refused (tagged results are the parked per-unit lane's shape)
//   - `immediate_impl` (`ev -> expr`) → `return <lowered>;`
//   - subflow impls (`flow.impl_of`) → statement walk ending in `return`
//   - `~proc <ev>|c` → verbatim C body after field bindings (the .kc/.kcs
//     contract: input fields bound as locals off __koru_in)
//   - top-level flows → `static void koru_flow_<n>(void)` + one `main`
//   - call+bind (`ev(a): x |> next`) → `const <ct> x = <call>;`
//   - transform-rendered inline bodies (`invocation.inline_body`) → spliced
//     verbatim; the |c transform authored C for this target
//   - `.kc` host lines → spliced verbatim (C facet text for this target)
//
// REFUSAL AXES (pre-flight, every applicable axis named in one diagnostic —
// the test plan's measured collision rate is why refusal is a census, not a
// first-match): raw host lines in the entry module ("cannot lower to C"),
// resumable `!` effect arms ("resume semantics out of oracle scope"),
// pump/rings/worker.spawn ("no verified concurrency"). Everything else fails
// at the point it is met: UnresolvedEvent / NoCProcBody /
// UnsupportedConstruct / ZigTextInOutput.

const std = @import("std");
const ast = @import("ast");
const errors = @import("errors");
const file_types = @import("file_types");
const codegen_utils = @import("codegen_utils");
const struct_literal = @import("struct_literal");
const parser = @import("parser");
const compiler_env = @import("compiler_env");
const emit_walk = @import("emit_walk");
const emit_audit = @import("emit_audit");

pub const CEmitError = error{
    OutOfMemory,
    UnresolvedEvent,
    UnsupportedConstruct,
    NoCProcBody,
    /// Pre-flight axis refusal — the axes were already printed by name.
    RefusedConstruct,
    /// Emitted C contained zig-only text (an un-lowered construct was
    /// spliced verbatim instead of refused).
    ZigTextInOutput,
};

const C_TARGET = "c";
const INPUT_PARAM = "__koru_in";

// ---------------------------------------------------------------------------
// Path/identity helpers
// ---------------------------------------------------------------------------

/// Canonical lookup key for a dotted path: `"std.io:print.ln"`.
fn pathKey(allocator: std.mem.Allocator, path: ast.DottedPath) ![]const u8 {
    return emit_walk.pathKey(allocator, path);
}

/// C identifier for an event/function — module-qualified by construction so
/// two modules' same-named events can't collide: `std_io_print_ln`.
fn mangle(allocator: std.mem.Allocator, path: ast.DottedPath) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    if (path.module_qualifier) |mq| {
        for (mq) |c| try buf.append(allocator, if (std.ascii.isAlphanumeric(c) or c == '_') c else '_');
        try buf.append(allocator, '_');
    }
    for (path.segments, 0..) |seg, i| {
        if (i > 0) try buf.append(allocator, '_');
        for (seg) |c| try buf.append(allocator, if (std.ascii.isAlphanumeric(c) or c == '_') c else '_');
    }
    return buf.toOwnedSlice(allocator);
}

/// Koru type → C type spelling, or null outside the first fragment.
/// The map itself lives in codegen_utils so koru_std C-minted decls agree.
fn cTypeOf(koru_type: []const u8) ?[]const u8 {
    return codegen_utils.cTypeOf(koru_type);
}

/// Identifier-alphabet fold for invented C tags — non-identifier runs
/// collapse to `_`, a digit or empty first char refuses. `Bridge<session>`,
/// `std/bridge:B`, `const char *` all land on `_`-joined spellings, the same
/// shape the monomorphizer's `List<i64>` → `List_i64` uses.
fn mangleOpaqueName(allocator: std.mem.Allocator, text: []const u8) ?[]const u8 {
    const buf = allocator.alloc(u8, text.len) catch return null;
    var n: usize = 0;
    var pending_sep = false;
    for (text) |ch| {
        if (codegen_utils.exprIdentChar(ch)) {
            if (n == 0 and std.ascii.isDigit(ch)) {
                allocator.free(buf);
                return null;
            }
            if (pending_sep) {
                buf[n] = '_';
                n += 1;
                pending_sep = false;
            }
            buf[n] = ch;
            n += 1;
        } else pending_sep = n > 0;
    }
    if (n == 0) {
        allocator.free(buf);
        return null;
    }
    return buf[0..n];
}

// ---------------------------------------------------------------------------
// std/target catalog — the declared `c` rows, harvested at emit time
// ---------------------------------------------------------------------------

/// Harvest `~std/target:<verb>(c)` site rows out of `koru_std/target.kz`.
/// Collect the raw `source` texts of every `std/target:<verb>(c)` flow,
/// in declared order — the shared walk for the flat-row harvester and
/// the ordered prelude loader. Null = catalog file absent/unparseable:
/// dual-answer is advisory, a missing catalog never breaks emission.
fn loadTargetSources(
    allocator: std.mem.Allocator,
    verb: []const u8,
) ?[][]const u8 {
    const home = compiler_env.CompilerEnv.koru_home;
    if (home.len == 0) {
        std.debug.print("std/target catalog: koru_home empty\n", .{});
        return null;
    }
    const path = std.fs.path.join(allocator, &.{ home, "koru_std", "target.kz" }) catch return null;
    const file = std.fs.cwd().openFile(path, .{}) catch |e| {
        std.debug.print("std/target catalog: open {s}: {s}\n", .{ path, @errorName(e) });
        return null;
    };
    defer file.close();
    const source = file.readToEndAlloc(allocator, 1 << 20) catch return null;
    var p = parser.Parser.init(allocator, source, path, &.{}, null) catch |e| {
        std.debug.print("std/target catalog: parser init: {s}\n", .{@errorName(e)});
        return null;
    };
    const result = p.parse() catch |e| {
        std.debug.print("std/target catalog: parse {s}: {s}\n", .{ path, @errorName(e) });
        return null;
    };
    var sources: std.ArrayList([]const u8) = .empty;
    for (result.source_file.items) |*item| {
        if (item.* != .flow) continue;
        const inv = item.flow.inv();
        const mq = inv.path.module_qualifier orelse continue;
        if (!std.mem.eql(u8, mq, "std.target") and !std.mem.eql(u8, mq, "std/target")) continue;
        if (inv.path.segments.len != 1 or !std.mem.eql(u8, inv.path.segments[0], verb)) continue;
        // The site-arg target name — positional `(c)` serializes with
        // name == value; only `c` rows feed this lane.
        var is_c = false;
        var source_text: ?[]const u8 = null;
        for (inv.args) |arg| {
            if (std.mem.eql(u8, arg.name, "source")) {
                source_text = arg.value;
            } else if (std.mem.eql(u8, std.mem.trim(u8, arg.value, " \t\n\""), "c")) {
                is_c = true;
            }
        }
        if (!is_c) continue;
        const src = source_text orelse continue;
        sources.append(allocator, src) catch continue;
    }
    return sources.toOwnedSlice(allocator) catch null;
}

/// Rows are JSON-shaped objects (`{ "i64": "long long", ... }`);
/// non-string values are skipped.
fn loadTargetRows(
    allocator: std.mem.Allocator,
    verb: []const u8,
) ?std.StringHashMap([]const u8) {
    const sources = loadTargetSources(allocator, verb) orelse return null;
    var table = std.StringHashMap([]const u8).init(allocator);
    for (sources) |src| {
        const wrapped = std.fmt.allocPrint(allocator, "{{{s}}}", .{src}) catch return table;
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, wrapped, .{}) catch |e| {
            // A malformed row block must not silently void the family —
            // a `construct` trailing comma sat dead this way until the
            // shadow's harvest count exposed it.
            std.debug.print("std/target catalog: `{s}` row block failed to parse: {s}\n", .{ verb, @errorName(e) });
            continue;
        };
        defer parsed.deinit();
        if (parsed.value != .object) continue;
        var it = parsed.value.object.iterator();
        while (it.next()) |e| {
            const key = allocator.dupe(u8, e.key_ptr.*) catch continue;
            switch (e.value_ptr.*) {
                .string => |s| {
                    const val = allocator.dupe(u8, s) catch continue;
                    table.put(key, val) catch {};
                },
                // List rows (prelude's includes/helpers): each element
                // registers itself as `element -> <list key>` — a
                // membership lookup, which is all the coverage checks ask.
                .array => |arr| {
                    for (arr.items) |elem| {
                        if (elem != .string) continue;
                        const elem_key = allocator.dupe(u8, elem.string) catch continue;
                        const key_val = allocator.dupe(u8, key) catch continue;
                        table.put(elem_key, key_val) catch {};
                    }
                },
                else => {},
            }
        }
    }
    std.debug.print("std/target catalog: `{s}` rows harvested: {d}\n", .{ verb, table.count() });
    return table;
}

/// One prelude def row — `text` null marks a minted family (declared
/// coverage, no fixed text: the `__koru_*_<store>` helpers the take/query
/// sweeps mint per store name). Rows whose value is `"minted"` declare
/// that shape; anything else is verbatim def text, emitted in declared
/// order (the JSON object walk is insertion-ordered).
const PreludeDef = struct { name: []const u8, text: ?[]const u8 };
const PreludeRows = struct {
    includes: [][]const u8,
    defs: []PreludeDef,
};

/// The prelude family, ordered and text-carrying: `includes` names render
/// as `#include <x>` lines, `defs` render verbatim in row order. This is
/// the catalog-as-sole-source shape — the preamble's text lives in the
/// rows; the emitter only sequences them.
fn loadPreludeRows(allocator: std.mem.Allocator) ?PreludeRows {
    const sources = loadTargetSources(allocator, "prelude") orelse return null;
    var includes: std.ArrayList([]const u8) = .empty;
    var defs: std.ArrayList(PreludeDef) = .empty;
    for (sources) |src| {
        const wrapped = std.fmt.allocPrint(allocator, "{{{s}}}", .{src}) catch return null;
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, wrapped, .{}) catch |e| {
            std.debug.print("std/target catalog: `prelude` row block failed to parse: {s}\n", .{@errorName(e)});
            continue;
        };
        defer parsed.deinit();
        if (parsed.value != .object) continue;
        var it = parsed.value.object.iterator();
        while (it.next()) |e| {
            const key = e.key_ptr.*;
            switch (e.value_ptr.*) {
                .array => |arr| {
                    if (!std.mem.eql(u8, key, "includes")) continue;
                    for (arr.items) |elem| {
                        if (elem != .string) continue;
                        includes.append(allocator, allocator.dupe(u8, elem.string) catch continue) catch {};
                    }
                },
                .object => |obj| {
                    if (!std.mem.eql(u8, key, "defs")) continue;
                    var dit = obj.iterator();
                    while (dit.next()) |de| {
                        if (de.value_ptr.* != .string) continue;
                        const name = allocator.dupe(u8, de.key_ptr.*) catch continue;
                        const val = de.value_ptr.string;
                        defs.append(allocator, .{
                            .name = name,
                            .text = if (std.mem.eql(u8, val, "minted")) null else allocator.dupe(u8, val) catch null,
                        }) catch {};
                    }
                },
                else => {},
            }
        }
    }
    std.debug.print("std/target catalog: `prelude` rows harvested: {d} includes, {d} defs\n", .{ includes.items.len, defs.items.len });
    return .{
        .includes = includes.toOwnedSlice(allocator) catch return null,
        .defs = defs.toOwnedSlice(allocator) catch return null,
    };
}

/// The LowerDiag/cArrayType resolver shape — hands the emitter's
/// catalog-sole-source flat table to codegen_utils paths that have no
/// `self` (`@as` inside lowerCBuiltin, cArrayType's base).
fn catalogCTypeResolver(ctx: ?*anyopaque, koru_type: []const u8) ?[]const u8 {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return null));
    return em.catalogFlatType(koru_type);
}

/// The builtin table's resolver — the row IS the answer: a `{1}`/`{2}`
/// template is the lowering, `rule:` names an emitter-owned arm,
/// `refused` is the boundary as data. Absent catalog → null → arms.
fn catalogBuiltinResolver(ctx: ?*anyopaque, name: []const u8) ?[]const u8 {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return null));
    em.ensureCatalog();
    const table = em.catalog_builtins orelse return null;
    const key = std.fmt.allocPrint(em.allocator, "@{s}", .{name}) catch return null;
    return table.get(key);
}

/// Drift lines: stderr + `catalog_drift.log` in CWD — codegen_utils owns
/// the writer (the std/emit shadow walk shares it).
const driftLog = codegen_utils.driftLog;

// The decl_writer's answers — thin adapters over the emitter's own
// resolvers so the walk's write path asks exactly what the oracle asks.
fn cDeclTypeOf(ctx: ?*anyopaque, koru_type: []const u8) ?[]const u8 {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return null));
    return em.cTypeOfResolved(koru_type);
}

fn cDeclMemberName(ctx: ?*anyopaque, allocator: std.mem.Allocator, name: []const u8) []const u8 {
    _ = ctx;
    return codegen_utils.cMemberName(allocator, name);
}

fn cDeclManglePath(ctx: ?*anyopaque, allocator: std.mem.Allocator, path: ast.DottedPath) ?[]const u8 {
    _ = ctx;
    return mangle(allocator, path) catch null;
}

// The definition-body slots — the same emitter internals, reached through
// the walk's vtable. Each swaps em.buf so the lane-owned body machinery
// renders into the walk's buffer untouched.
fn cDefProcBody(ctx: ?*anyopaque, event: *const ast.EventDecl) ?[]const u8 {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return null));
    const key = pathKey(em.allocator, event.path) catch return null;
    defer em.allocator.free(key);
    const p = em.cProcOf(key) orelse return null;
    return p.body.text;
}

fn cDefImmediateImpl(ctx: ?*anyopaque, out: *std.ArrayList(u8), event: *const ast.EventDecl) anyerror!bool {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return false));
    const key = try pathKey(em.allocator, event.path);
    defer em.allocator.free(key);
    const ii = em.impls.get(key) orelse return false;
    // `cur_event` is render context the oracle establishes for its own
    // body pass — the walk's render must see the same binding.
    const saved_event = em.cur_event;
    em.cur_event = event;
    defer em.cur_event = saved_event;
    const saved = em.buf;
    em.buf = out;
    defer em.buf = saved;
    try em.emitProduce(&ii.value, "    ");
    return true;
}

fn cDefImplFlow(ctx: ?*anyopaque, out: *std.ArrayList(u8), event: *const ast.EventDecl) anyerror!bool {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return false));
    const key = try pathKey(em.allocator, event.path);
    defer em.allocator.free(key);
    const flist = em.impl_flows.get(key) orelse return false;
    // `!=1` impls is the oracle's variant-selection refusal — the same
    // error rides the slot.
    if (flist.items.len != 1) return CEmitError.UnsupportedConstruct;
    const saved_event = em.cur_event;
    em.cur_event = event;
    defer em.cur_event = saved_event;
    const saved = em.buf;
    em.buf = out;
    defer em.buf = saved;
    try em.emitImplFlowBody(flist.items[0]);
    return true;
}

fn cDefRenderFlow(ctx: ?*anyopaque, out: *std.ArrayList(u8), flow: *const ast.Flow, index: usize) anyerror!void {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return));
    const saved = em.buf;
    em.buf = out;
    defer em.buf = saved;
    try em.emitFlow(flow, index);
}

fn cFlowName(ctx: ?*anyopaque, allocator: std.mem.Allocator, index: usize) ?[]const u8 {
    _ = ctx;
    return std.fmt.allocPrint(allocator, "koru_flow_{d}", .{index}) catch null;
}

/// `int_bindings.put` behind the walk's bindField slot — the field→C
/// type table expression lowering and rewriteSliceAccessors read.
fn cBindField(ctx: ?*anyopaque, field_name: []const u8, c_type: []const u8) anyerror!void {
    const em: *Emitter = @ptrCast(@alignCast(ctx orelse return));
    try em.int_bindings.put(field_name, c_type);
}

// ---------------------------------------------------------------------------
// Indexes
// ---------------------------------------------------------------------------

const EventIndex = std.StringHashMap(*const ast.EventDecl);
const ProcIndex = std.StringHashMap(std.ArrayList(*const ast.ProcDecl));
const ImplIndex = std.StringHashMap(*const ast.ImmediateImpl);
const ImplFlowIndex = std.StringHashMap(std.ArrayList(*const ast.Flow));

fn indexItems(
    allocator: std.mem.Allocator,
    items: []const ast.Item,
    events: *EventIndex,
    procs: *ProcIndex,
    impls: *ImplIndex,
    impl_flows: *ImplFlowIndex,
) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .module_decl => |*m| try indexItems(allocator, m.items, events, procs, impls, impl_flows),
            .event_decl => |*e| {
                const key = try pathKey(allocator, e.path);
                try events.put(key, e);
            },
            .proc_decl => |*p| {
                const key = try pathKey(allocator, p.path);
                const gop = try procs.getOrPut(key);
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                try gop.value_ptr.append(allocator, p);
            },
            .immediate_impl => |*ii| {
                const key = try pathKey(allocator, ii.event_path);
                try impls.put(key, ii);
            },
            .flow => |*f| {
                if (f.impl_of) |ip| {
                    const key = try pathKey(allocator, ip);
                    const gop = try impl_flows.getOrPut(key);
                    if (!gop.found_existing) gop.value_ptr.* = .empty;
                    try gop.value_ptr.append(allocator, f);
                }
            },
            else => {},
        }
    }
}

// ---------------------------------------------------------------------------
// Pre-flight refusal census — every applicable axis named in one diagnostic.
// Entry module only: dependency internals surface at the call site (a `!`
// continuation in a user flow, a pump invocation) or refuse at emit.
// ---------------------------------------------------------------------------

const AxisCensus = struct {
    host_lines: ?errors.SourceLocation = null,
    resumable: ?errors.SourceLocation = null,
    concurrency: ?errors.SourceLocation = null,
};

const CensusCtx = struct {
    allocator: std.mem.Allocator,
    events: *const EventIndex,
};

fn axisRefusalItems(
    items: []const ast.Item,
    main_module: []const u8,
    census: *AxisCensus,
    ctx: *const CensusCtx,
) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .host_line => |*line| {
                if (!std.mem.eql(u8, line.module, main_module)) continue;
                const host = file_types.hostLangOfFile(line.location.file) orelse continue;
                if (std.mem.eql(u8, host, C_TARGET)) continue;
                if (census.host_lines == null) census.host_lines = line.location;
            },
            .event_decl => |*e| {
                if (!std.mem.eql(u8, e.module, main_module)) continue;
                for (e.branches) |b| {
                    // A declared `!` is only a wall when its resume shape
                    // needs a handler VALUE (`-> T` / multi-arm sum) — the
                    // zig lane's own inline splice refuses the same shape.
                    // A void `!` decl is per-call-site splice vocabulary.
                    if (b.kind == .effect and (b.resume_type != null or b.resume_arms != null)) {
                        if (census.resumable == null) census.resumable = e.location;
                    }
                }
            },
            .flow => |*f| {
                if (!std.mem.eql(u8, f.module, main_module)) continue;
                // The flow's own head node still carries evidence (a pump
                // invocation, host text); its ARM LIST is template
                // vocabulary exactly when the flow itself was rendered —
                // `flow.inline_body` resolves markers against
                // `flow.body.continuations`.
                var head_inv: ?*const ast.Invocation = null;
                if (f.body.node) |*node| {
                    _ = try axisRefusalNode(node, f.body.location, census, ctx);
                    if (node.* == .invocation) head_inv = &node.invocation;
                }
                for (f.body.continuations) |*cont| try axisRefusalSite(cont, census, f.inline_body != null, ctx, head_inv);
            },
            .module_decl => |*m| {
                // Transforms consume their invocations before emission (pump flows are
                // rewritten wholesale), so the durable concurrency evidence is the
                // merged module itself: importing std.pump / std.threading
                // leaves a module_decl whose path names the family. Presence-scoped,
                // not use-scoped — stricter than the axis but always sound.
                // std.rings is absent — its transform mints sequential ops with
                // |c bodies, so the import alone is not concurrency evidence.
                if (isConcurrencyModule(m.logical_name) or isConcurrencyModule(m.canonical_path)) {
                    if (census.concurrency == null) census.concurrency = m.location;
                }
                try axisRefusalItems(m.items, main_module, census, ctx);
            },
            else => {},
        }
    }
}

/// `governed` — the parent (invocation or flow) carried an inline body,
/// i.e. a transform/template already dispatched this site. Its `!` kind is
/// then transplant vocabulary (for's `! each`, capture's `! as`) — the
/// template's own body runs it — not a resumable pair. An ungoverned `!`
/// arm is the per-call-site splice the zig lane emits: the proc's `|c`
/// body inlines at the site and `__koru_raise_<arm>` markers splice the
/// consumer's arm text — same boundary the zig inline path draws, so a
/// VOID effect arm (`->` absent) on a resolvable event is fragment; a
/// RESUMING arm (`-> T` / multi-arm sum) stays refused — the zig lane
/// itself routes those to the comptime __H Handlers path, and a C
/// handler-value analog is a separate ruling. Governance is NOT inherited
/// past the direct parent: a nested event's `!` arm inside a rendered arm
/// is governed only by its own invocation.
fn axisRefusalSite(
    site: *const ast.Continuation,
    census: *AxisCensus,
    governed: bool,
    ctx: *const CensusCtx,
    parent_inv: ?*const ast.Invocation,
) CEmitError!void {
    if (site.kind == .effect and !governed and census.resumable == null) {
        if (!try effectArmInlineable(ctx, parent_inv, site.branch)) census.resumable = site.location;
    }
    var children_governed = false;
    var child_inv: ?*const ast.Invocation = null;
    if (site.node) |*node| {
        children_governed = try axisRefusalNode(node, site.location, census, ctx);
        if (node.* == .invocation) child_inv = &node.invocation;
    }
    for (site.continuations) |*cont| try axisRefusalSite(cont, census, children_governed, ctx, child_inv);
}

/// An ungoverned `! <arm>` site lowers by per-call-site inline exactly when
/// the invocation it arms resolves to an event whose declared `arm` is a
/// plain void effect — no `-> T` resume, no multi-arm resume sum.
fn effectArmInlineable(
    ctx: *const CensusCtx,
    parent_inv: ?*const ast.Invocation,
    arm_name: []const u8,
) CEmitError!bool {
    const inv = parent_inv orelse return false;
    const key = try pathKey(ctx.allocator, inv.path);
    defer ctx.allocator.free(key);
    const event = ctx.events.get(key) orelse return false;
    for (event.branches) |*b| {
        if (b.kind != .effect or !std.mem.eql(u8, b.name, arm_name)) continue;
        return b.resume_type == null and b.resume_arms == null;
    }
    return false;
}

/// Walk a site's node for axis evidence; returns whether the node dispatched
/// a template (its children are template vocabulary).
fn axisRefusalNode(node: *const ast.Node, loc: errors.SourceLocation, census: *AxisCensus, ctx: *const CensusCtx) CEmitError!bool {
    switch (node.*) {
        .invocation => |*inv| {
            if (isConcurrencyPath(inv.path) and census.concurrency == null) {
                census.concurrency = loc;
            }
            return inv.inline_body != null;
        },
        .conditional => |*c| try axisRefusalBranches(c.branches, census, ctx),
        .foreach => |*f| try axisRefusalBranches(f.branches, census, ctx),
        .switch_result => |*sw| try axisRefusalBranches(sw.branches, census, ctx),
        else => {},
    }
    return false;
}

fn axisRefusalBranches(branches: []const ast.NamedBranch, census: *AxisCensus, ctx: *const CensusCtx) CEmitError!void {
    for (branches) |*b| {
        for (b.body) |*site| try axisRefusalSite(site, census, false, ctx, null);
    }
}

/// pump / rings / worker.spawn — the concurrency axis. Matches the module
/// qualifier (std.pump, std.rings) or a `worker`/`spawn` segment pair.
/// std.rings' *import* is admitted (the transform mints sequential ops with
/// |c bodies); the call-path check below stays — a rings-qualified call that
/// survived the transform refused is better than an undefined symbol.
fn isConcurrencyModule(name: []const u8) bool {
    // `rings` is out of this family: std/rings is a comptime transform that
    // synthesizes sequential ring ops (a `.kc`-routed bounded FIFO cell the
    // oracle verifies — the Vyukov atomics are the native lane's). `pump`,
    // `threading`, and `worker.spawn` remain real concurrency: no
    // sequential C model exists for them.
    const families = [_][]const u8{ "pump", "threading", "worker" };
    var it = std.mem.tokenizeAny(u8, name, "./:_\\");
    while (it.next()) |seg| {
        for (families) |fam| {
            if (std.mem.eql(u8, seg, fam)) return true;
        }
    }
    return false;
}

fn isConcurrencyPath(path: ast.DottedPath) bool {
    if (path.module_qualifier) |mq| {
        if (std.mem.indexOf(u8, mq, "pump") != null) return true;
        if (std.mem.indexOf(u8, mq, "rings") != null) return true;
    }
    var saw_worker = false;
    var saw_spawn = false;
    for (path.segments) |seg| {
        if (std.mem.eql(u8, seg, "worker")) saw_worker = true;
        if (std.mem.eql(u8, seg, "spawn")) saw_spawn = true;
    }
    return saw_worker and saw_spawn;
}

/// Print one line per applicable axis and return RefusedConstruct. The
/// pinned phrases are the refusal table's own wording — the regression
/// cells grep stderr for them (400_217/209/210).
fn checkFragmentRow(fragment: ?*const std.StringHashMap([]const u8), key: []const u8) void {
    const table = fragment orelse return;
    if (!table.contains(key)) {
        driftLog("std/target drift: fragment refusal `{s}` not catalog-declared\n", .{key});
    }
}

fn refuseAxes(census: *const AxisCensus, fragment: ?*const std.StringHashMap([]const u8)) CEmitError {
    std.debug.print("error[KORU047]: C lane refusal — program uses constructs outside the CompCert-verified fragment:\n", .{});
    if (census.resumable) |loc| {
        std.debug.print("  - `!` effect arms: resume semantics out of oracle scope ({s}:{d})\n", .{ loc.file, loc.line });
        checkFragmentRow(fragment, "resumable-!");
    }
    if (census.host_lines) |loc| {
        std.debug.print("  - raw host lines: Zig host text has no C lowering — cannot lower to C ({s}:{d})\n", .{ loc.file, loc.line });
        checkFragmentRow(fragment, "raw-host-lines");
    }
    if (census.concurrency) |loc| {
        std.debug.print("  - pump / rings / worker.spawn: CompCert is a sequential C subset — no verified concurrency ({s}:{d})\n", .{ loc.file, loc.line });
        checkFragmentRow(fragment, "concurrency-runtime");
    }
    return CEmitError.RefusedConstruct;
}

// ---------------------------------------------------------------------------
// Reached set — only events a flow can dispatch to need emission; the rest of
// an imported module (most of std/io) is another lane's surface. In SOURCE
// ORDER — a hashmap-ordered emit would make output nondeterministic.
// ---------------------------------------------------------------------------

const Reached = std.StringHashMap(void);

/// Seed reach from the ENTRY module top-level flows only — a flow inside a
/// dependency module is not program entry code (it runs when invoked through
/// an event, which is what the impl-flow transitive walk below covers), and
/// marking through std/* flow internals would declare half the stdlib
/// reached.
fn markReachedCalls(
    allocator: std.mem.Allocator,
    items: []const ast.Item,
    main_module: []const u8,
    reached: *Reached,
    worklist: *std.ArrayList([]const u8),
) CEmitError!void {
    for (items) |*item| {
        if (item.* != .flow) continue;
        const f = &item.flow;
        if (f.impl_of != null) continue;
        if (!std.mem.eql(u8, f.module, main_module)) continue;
        try reachSite(allocator, &f.body, reached, worklist);
    }
}

/// `retain` marks an event a synthesized host-text body calls by name —
/// raw proc text is invisible to AST reachability (that is the same
/// contract dead_strip honors: the sweep's |c loop calls `__grid_body_*`
/// from C text). Seed them reached and onto the worklist so their impl
/// flows reach transitively.
fn markRetainedEvents(
    allocator: std.mem.Allocator,
    items: []const ast.Item,
    reached: *Reached,
    worklist: *std.ArrayList([]const u8),
) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .module_decl => |*m| try markRetainedEvents(allocator, m.items, reached, worklist),
            .event_decl => |*e| {
                for (e.annotations) |ann| {
                    if (std.mem.eql(u8, ann, "retain")) {
                        const key = try pathKey(allocator, e.path);
                        if (!reached.contains(key)) {
                            try reached.put(key, {});
                            try worklist.append(allocator, key);
                        }
                    }
                }
            },
            else => {},
        }
    }
}

/// An impl flows own calls count — reach through them transitively. |zig/|c
/// proc bodies and immediate `->` exprs cannot invoke Koru events, so impl
/// flows are the only channel.
fn reachImplFlows(
    allocator: std.mem.Allocator,
    impl_flows: *const ImplFlowIndex,
    reached: *Reached,
    worklist: *std.ArrayList([]const u8),
) CEmitError!void {
    while (worklist.pop()) |key| {
        if (impl_flows.get(key)) |flist| {
            for (flist.items) |f| try reachSite(allocator, &f.body, reached, worklist);
        }
    }
}

fn reachSite(allocator: std.mem.Allocator, site: *const ast.Continuation, reached: *Reached, worklist: *std.ArrayList([]const u8)) CEmitError!void {
    if (site.node) |*node| {
        switch (node.*) {
            .invocation => |*inv| {
                // A transform-rendered invocation is a statement, not a
                // dispatch — its handler never runs.
                if (inv.inline_body == null) {
                    const key = try pathKey(allocator, inv.path);
                    if (!reached.contains(key)) {
                        try reached.put(key, {});
                        try worklist.append(allocator, key);
                    }
                }
            },
            .conditional => |*c| try reachBranches(allocator, c.branches, reached, worklist),
            .foreach => |*f| try reachBranches(allocator, f.branches, reached, worklist),
            .switch_result => |*s| try reachBranches(allocator, s.branches, reached, worklist),
            else => {},
        }
    }
    for (site.continuations) |*cont| try reachSite(allocator, cont, reached, worklist);
}

fn reachBranches(allocator: std.mem.Allocator, branches: []const ast.NamedBranch, reached: *Reached, worklist: *std.ArrayList([]const u8)) CEmitError!void {
    for (branches) |*b| {
        for (b.body) |*site| try reachSite(allocator, site, reached, worklist);
    }
}

/// Events in declaration order, filtered to the reached set — deterministic
/// emission order (a map order would vary run to run).
fn collectReachedInOrder(
    allocator: std.mem.Allocator,
    items: []const ast.Item,
    events: *const EventIndex,
    reached: *const Reached,
    out: *std.ArrayList(*const ast.EventDecl),
    seen: *std.StringHashMap(void),
) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .module_decl => |*m| try collectReachedInOrder(allocator, m.items, events, reached, out, seen),
            .event_decl => |*e| {
                const key = try pathKey(allocator, e.path);
                if (reached.contains(key) and !seen.contains(key)) {
                    try seen.put(key, {});
                    try out.append(allocator, e);
                }
            },
            else => {},
        }
    }
}

// ---------------------------------------------------------------------------
// Emitter
// ---------------------------------------------------------------------------

const Emitter = struct {
    allocator: std.mem.Allocator,
    buf: *std.ArrayList(u8),
    events: *const EventIndex,
    procs: *const ProcIndex,
    impls: *const ImplIndex,
    impl_flows: *const ImplFlowIndex,
    /// `// proto-terminal Name: scalar` registry — Name is a typedef'd C
    /// spelling, so a declared terminal resolves to itself.
    aliases: *const std.StringHashMap([]const u8),

    /// Minted binding name → its declared C type — the wrap-op lowering's
    /// width registry (`*%` `+%` `-%` wrap at the DECLARED int width).
    /// Populated wherever a `{ct} const {name}` or `long long {name}` is
    /// minted; names that never minted (store member reads, call results)
    /// do not resolve, and an unresolved wrap op refuses.
    int_bindings: *std.StringHashMap([]const u8),

    /// Minted slice-cell tag → element member C spelling — a `[]T` type
    /// reaching declarations registers `struct __koru_slice_<tag>` here;
    /// the pre-pass over reached events emits the definitions before any
    /// `_in`/`_res` struct can name one.
    slice_decls: *std.StringArrayHashMap([]const u8),

    /// `std/proto(Name) { f: t }` field tables — live `std.proto:default`
    /// decl invocations and erased `// proto Name: f: t` markers both
    /// seed (the same two-form read rings.leafgate's protoSourceText
    /// does). Fields stay unflattened: a proto name resolves to
    /// `struct Name`, the same spelling the zig lane's emitted struct
    /// carries.
    protos: *const std.StringArrayHashMap([]const ProtoField),
    /// Anonymous record tag → field table — `{ a: i64, b: i64 }` spells
    /// `struct __koru_rec_<tag>` where the tag is the mangled canonical
    /// field signature. Records are STRUCTURAL in Koru: two events
    /// returning `{ a: i64, b: i64 }` share one C type, so a bound value
    /// of one event's record can return as another's (020_065).
    record_decls: *std.StringArrayHashMap([]const ProtoField),
    /// Depth guard on proto-field resolution — a value-recursive proto
    /// graph (`A` holds `B`, `B` holds `A`) can never mint; the cap
    /// refuses it rather than recursing.
    proto_depth: usize = 0,
    /// `i128`/`u128` named at least one type position — the two-word
    /// cells mint once in the def block.
    needs_i128: bool = false,
    needs_u128: bool = false,

    /// Capture cell names a `//@koru:stmt_scope` preamble declared —
    /// `struct __koru_cap_<cell>` is the one named type the `.assignment`
    /// lowering re-derives from `target` alone. A `.assignment` naming a
    /// cell no preamble minted refuses rather than emitting a call into an
    /// undeclared struct.
    cap_cells: *std.StringHashMap(void),

    /// Monotonic result-temp counter — `__koru_res_N` at tagged-dispatch
    /// call sites.
    res_counter: usize = 0,

    /// `std/target:*(c)` rows harvested from `koru_std/target.kz` —
    /// dual-answer mode: type spellings, minted names, the builtin
    /// refusal boundary, and the prelude include/helper surface all check
    /// against the declared rows and print drift on stderr; the emitter's
    /// own answer still wins until the corpus proves the rows and the
    /// flip rung makes the catalog the sole source.
    catalog_types: ?std.StringHashMap([]const u8) = null,
    catalog_names: ?std.StringHashMap([]const u8) = null,
    catalog_builtins: ?std.StringHashMap([]const u8) = null,
    catalog_prelude: ?std.StringHashMap([]const u8) = null,
    /// The prelude family, ordered + text-carrying — sole source of the
    /// emitted preamble when loaded (defs render in row order).
    prelude_rows: ?PreludeRows = null,
    /// The std/emit write-path's answer table — the walk owns decl
    /// sequencing, this supplies C spellings (ctx set post-init).
    decl_writer: emit_walk.CDeclWriter = .{
        .typeOf = cDeclTypeOf,
        .memberName = cDeclMemberName,
        .manglePath = cDeclManglePath,
        .procBody = cDefProcBody,
        .renderImmediateImpl = cDefImmediateImpl,
        .renderImplFlow = cDefImplFlow,
        .renderFlow = cDefRenderFlow,
        .flowName = cFlowName,
        .mainPrologueText = "    __koru_argc = argc;\n    __koru_argv = argv;\n",
        .bindField = cBindField,
    },
    catalog_fragment: ?std.StringHashMap([]const u8) = null,
    catalog_constructs: ?std.StringHashMap([]const u8) = null,
    catalog_loaded: bool = false,
    /// The event whose handler body is emitting — `=> name` produce nodes
    /// build its `struct <name>_res` literal.
    cur_event: ?*const ast.EventDecl = null,

    fn write(self: *Emitter, text: []const u8) CEmitError!void {
        try self.buf.appendSlice(self.allocator, text);
    }

    fn writeFmt(self: *Emitter, comptime fmt: []const u8, args: anytype) CEmitError!void {
        try self.buf.writer(self.allocator).print(fmt, args);
    }

    /// `resolve_int_ctype` entry for LowerDiag — the minted-cell registry.
    fn resolveIntCtype(ctx: ?*anyopaque, name: []const u8) ?[]const u8 {
        const c = ctx orelse return null;
        const self: *Emitter = @ptrCast(@alignCast(c));
        return self.int_bindings.get(name);
    }

    /// Lower Koru expression text through the ONE shared lowering (the C
    /// target arm of codegen_utils.lowerKoruExpr), or refuse the builtin it
    /// names.
    fn writeExpr(self: *Emitter, text: []const u8) CEmitError!void {
        var diag: codegen_utils.LowerDiag = .{};
        diag.resolve_int_ctype = resolveIntCtype;
        diag.int_width_ctx = self;
        diag.resolve_c_type = catalogCTypeResolver;
        diag.c_type_ctx = self;
        diag.resolve_builtin = catalogBuiltinResolver;
        diag.builtin_ctx = self;
        const lowered = codegen_utils.lowerKoruExpr(self.allocator, text, .c, .koru_expr, &diag) catch |err| {
            if (err == error.UnsupportedBuiltin) {
                if (diag.unsupported_op.len != 0) {
                    std.debug.print("error[KORU047]: C lane: wrapping operator `{s}` in expression `{s}` — wrap width is the operand's declared int width, which neither operand resolves to in this scope\n", .{ diag.unsupported_op, text });
                } else {
                    std.debug.print("error[KORU047]: C lane: unsupported builtin {s} in expression `{s}`\n", .{ diag.unknown_builtin, text });
                    self.checkCatalogBuiltinRefusal(diag.unknown_builtin);
                }
                return CEmitError.UnsupportedConstruct;
            }
            return CEmitError.OutOfMemory;
        };
        defer self.allocator.free(lowered);
        try self.write(lowered);
    }

    /// Host text authored for this target (inline_code, |c bodies, .kc
    /// lines): verbatim, no re-lowering.
    fn writeHostText(self: *Emitter, text: []const u8) CEmitError!void {
        try self.write(text);
    }

    /// Lazy-load all declared `(c)` rows once — `null` maps mean absent
    /// catalog/env (advisory stage: silent) while present maps are
    /// authoritative on coverage.
    fn ensureCatalog(self: *Emitter) void {
        if (self.catalog_loaded) return;
        self.catalog_loaded = true;
        self.catalog_types = loadTargetRows(self.allocator, "type");
        self.catalog_names = loadTargetRows(self.allocator, "name");
        self.catalog_builtins = loadTargetRows(self.allocator, "builtin");
        // One parse, two views: ordered defs for emission, a flat
        // membership map (include names + def keys) for the coverage
        // check. Absent rows → both stay null → advisory-off, like the
        // other families.
        if (loadPreludeRows(self.allocator)) |pr| {
            self.prelude_rows = pr;
            var membership = std.StringHashMap([]const u8).init(self.allocator);
            for (pr.includes) |inc| membership.put(inc, "includes") catch {};
            for (pr.defs) |d| membership.put(d.name, "defs") catch {};
            self.catalog_prelude = membership;
        }
        self.catalog_fragment = loadTargetRows(self.allocator, "fragment");
        self.catalog_constructs = loadTargetRows(self.allocator, "construct");
    }

    /// The flat type table, catalog-sole-source: the declared
    /// `type(c)` rows answer when the catalog is loaded, with the legacy
    /// `cTypeOf` demoted to drift-check. A catalog miss on a name the
    /// legacy table knows is a refusal (returns null + prints drift) —
    /// never a silent fallback; the catalog's completeness IS what the
    /// suite is proving. Catalog absent (file/env missing) → legacy.
    fn catalogFlatType(self: *Emitter, koru_type: []const u8) ?[]const u8 {
        self.ensureCatalog();
        const t = std.mem.trim(u8, koru_type, " \t");
        if (self.catalog_types) |table| {
            if (table.get(t)) |declared| {
                if (cTypeOf(t)) |legacy| {
                    if (!std.mem.eql(u8, legacy, declared)) {
                        driftLog("std/target drift: `{s}` emitter=`{s}` catalog=`{s}` (catalog wins)\n", .{ t, legacy, declared });
                    }
                }
                return declared;
            }
            if (cTypeOf(t) != null) {
                driftLog("std/target drift: type row missing for `{s}` — catalog is sole source\n", .{t});
            }
            return null;
        }
        return cTypeOf(t);
    }

    /// A minted constant against its declared `name` row — called at the
    /// mint sites whose spellings are ABI between declaration and use
    /// (slice/rec/cap struct tags). Same drift contract as the types.
    fn checkCatalogName(self: *Emitter, key: []const u8, literal: []const u8) void {
        self.ensureCatalog();
        const table = self.catalog_names orelse return;
        const declared = table.get(key) orelse {
            driftLog("std/target drift: name row missing for `{s}` (emitter mints `{s}`)\n", .{ key, literal });
            return;
        };
        if (!std.mem.eql(u8, declared, literal)) {
            driftLog("std/target drift: name `{s}` emitter=`{s}` catalog=`{s}`\n", .{ key, literal, declared });
        }
    }

    /// The builtin refusal boundary — called where a builtin refuses.
    /// A row that claims a lowering (`rule:` or a template) but refuses
    /// here is an overpromise; a refusal the row does not name at all
    /// keeps the boundary from being data.
    fn checkCatalogBuiltinRefusal(self: *Emitter, name: []const u8) void {
        self.ensureCatalog();
        const table = self.catalog_builtins orelse return;
        const key = if (name.len > 0 and name[0] == '@') blk: {
            // `unknown_builtin` carries the whole call (`@sqrt(x)`) — the
            // row key is the name only.
            var e: usize = 1;
            while (e < name.len and (std.ascii.isAlphanumeric(name[e]) or name[e] == '_')) e += 1;
            break :blk std.fmt.allocPrint(self.allocator, "{s}", .{name[0..e]}) catch return;
        } else std.fmt.allocPrint(self.allocator, "@{s}", .{name}) catch return;
        const declared = table.get(key) orelse {
            driftLog("std/target drift: builtin refusal `{s}` not catalog-declared\n", .{key});
            return;
        };
        if (!std.mem.eql(u8, declared, "refused")) {
            driftLog("std/target drift: builtin `{s}` catalog=`{s}` but emitter refuses\n", .{ key, declared });
        }
    }

    /// The fragment refusal boundary — every construct refusal the emitter
    /// names must be a key in the declared `refuses` list. A refusal the
    /// catalog does not carry is an undeclared boundary — same contract
    /// the builtin row holds, one altitude up.
    fn checkCatalogFragment(self: *Emitter, key: []const u8) void {
        self.ensureCatalog();
        const table = self.catalog_fragment orelse return;
        if (!table.contains(key)) {
            driftLog("std/target drift: fragment refusal `{s}` not catalog-declared\n", .{key});
        }
    }

    /// The construct boundary — called where a proc has no |c body.
    /// A catalog-claimed construct (`supported`) refusing is overpromise;
    /// unclaimed and refused is consistent silence.
    fn checkCatalogConstruct(self: *Emitter, key: []const u8) void {
        self.ensureCatalog();
        const table = self.catalog_constructs orelse return;
        if (table.get(key)) |decl| {
            if (std.mem.eql(u8, decl, "supported")) {
                driftLog("std/target drift: construct `{s}` catalog=`supported` but emitter refuses\n", .{key});
            }
        }
    }

    /// `__koru_foo_*` in a row declares the whole minted family — the
    /// take/query sweep names its helpers per store (`__koru_row_of_todos`)
    /// so a literal row can never enumerate them.
    fn preludePatternDeclared(table: *const std.StringHashMap([]const u8), full: []const u8) bool {
        var it = table.keyIterator();
        while (it.next()) |k| {
            const key = k.*;
            if (key.len > 1 and key[key.len - 1] == '*' and
                std.mem.startsWith(u8, full, key[0 .. key.len - 1])) return true;
        }
        return false;
    }

    /// Post-emit prelude coverage — every `#include <x>` and
    /// `static … __koru_<name>(` definition reaching output must be
    /// catalog-declared (emitted ⊆ declared). |c-body-authored `__koru_`
    /// locals inside function bodies are out of scope — the row names
    /// the static prelude surface, not stdlib internals.
    fn checkCatalogPrelude(self: *Emitter, buf: *const std.ArrayList(u8)) void {
        self.ensureCatalog();
        const table = self.catalog_prelude orelse return;
        var rest = buf.items;
        while (std.mem.indexOf(u8, rest, "#include <")) |at| {
            const after = rest[at + "#include <".len ..];
            const end = std.mem.indexOfScalar(u8, after, '>') orelse break;
            const inc = after[0..end];
            if (!table.contains(inc)) {
                driftLog("std/target drift: include `<{s}>` emitted but not catalog-declared\n", .{inc});
            }
            rest = after[end..];
        }
        rest = buf.items;
        while (std.mem.indexOf(u8, rest, " __koru_")) |at| {
            const after = rest[at + " __koru_".len ..];
            var n: usize = 0;
            while (n < after.len and (std.ascii.isAlphanumeric(after[n]) or after[n] == '_')) n += 1;
            const ident = after[0..n];
            // Only prelude definitions count — a `__koru_x(` call site or
            // an indented local is the caller/author's text, not the
            // emitted surface. Definitions are the `static … __koru_N(`
            // shape, so require the line to carry `static` before the id.
            const line_start = if (std.mem.lastIndexOfScalar(u8, rest[0..at], '\n')) |nl| nl + 1 else 0;
            const line_head = rest[line_start..at];
            const is_def = std.mem.indexOf(u8, line_head, "static") != null and n < after.len and after[n] == '(';
            rest = after[n..];
            if (is_def) {
                const full = std.fmt.allocPrint(self.allocator, "__koru_{s}", .{ident}) catch continue;
                if (!table.contains(full) and !preludePatternDeclared(&table, full)) {
                    driftLog("std/target drift: helper `{s}` emitted but not catalog-declared\n", .{full});
                }
            }
        }
    }

    /// Primitives map directly; a declared proto terminal IS its C spelling
    /// (the minted `typedef` binds it). Everything else stays refused.
    fn cTypeOfResolved(self: *Emitter, koru_type: []const u8) ?[]const u8 {
        const t = std.mem.trim(u8, koru_type, " \t");
        if (self.catalogFlatType(t)) |ct| return ct;
        // Sole-source: a flat-table name the loaded catalog lacks refuses —
        // it must not fall into the structural arms (`[]const u8` is both
        // a flat row and `[]`-shaped).
        if (self.catalog_types != null and cTypeOf(t) != null) return null;
        if (self.aliases.contains(t)) return t;
        // `*X` — a pointer cell. A proto terminal's typedef already binds
        // `X`, so `X *` points at the alias's own spelling; a primitive
        // pointee spells its real C type (`*i64` → `int64_t *`); anything
        // else mints `struct <tag> *` — an incomplete type: declarations,
        // parameters, fields, returns, assignment and `==`/`!=` all compile,
        // while any dereference dies inside ccomp — the oracle enforces
        // opacity itself, no check needed here. Qualified and generic
        // spellings (`*std/bridge:Bridge<session>`, `*ast.Flow`) mangle
        // non-identifier runs to `_`, matching the monomorphizer's own
        // `List<i64>` → `List_i64` shape. `**X`, `[*]X` stay refused.
        if (t.len > 1 and t[0] == '*') {
            var inner = std.mem.trim(u8, t[1..], " \t");
            var pointee_const = false;
            if (inner.len > "const".len and std.mem.startsWith(u8, inner, "const") and
                (inner["const".len] == ' ' or inner["const".len] == '\t'))
            {
                pointee_const = true;
                inner = std.mem.trim(u8, inner["const".len..], " \t");
            }
            // `**X`, `*(*X)`, `*[4]X` — a leading non-identifier char means
            // the pointee is not a name; refuse rather than drop a level.
            if (inner.len == 0 or !codegen_utils.exprIdentChar(inner[0])) return null;
            const kw = if (pointee_const) "const " else "";
            if (self.catalogFlatType(inner)) |ct|
                return std.fmt.allocPrint(self.allocator, "{s}{s} *", .{ kw, ct }) catch null;
            // A proto terminal's `X` spells the typedef only when its scalar
            // actually minted one (`i64` does, `i128` does not) — otherwise
            // the same opaque `struct X *` arm applies.
            if (self.aliases.get(inner)) |scalar| {
                if (self.catalogFlatType(scalar) != null)
                    return std.fmt.allocPrint(self.allocator, "{s}{s} *", .{ kw, inner }) catch null;
            }
            const tag = mangleOpaqueName(self.allocator, inner) orelse return null;
            return std.fmt.allocPrint(self.allocator, "{s}struct {s} *", .{ kw, tag }) catch null;
        }
        // `[]T`/`[]const T` — a fat slice cell: `struct __koru_slice_<tag>`
        // carries `T *ptr` + `uintptr_t len`, the `{ptr, len}` pair the zig
        // lane's slice is. Byte slices (`[]const u8`, `[]u8`, `[:0]u8`)
        // returned from cTypeOf above — the string ruling keeps them thin.
        // The element resolves the ordinary way (a named element mints the
        // same incomplete `struct <tag>` `*X` uses), so the cell, `.len`
        // and `xs[i]` compile, while an element use the oracle cannot see
        // still dies inside ccomp. Resolution only REGISTERS the cell —
        // the pre-pass over reached events emits the definition ahead of
        // every struct that names it.
        if (std.mem.startsWith(u8, t, "[]")) {
            var elem = std.mem.trim(u8, t[2..], " \t");
            var const_elem = false;
            if (elem.len > "const".len and std.mem.startsWith(u8, elem, "const") and
                (elem["const".len] == ' ' or elem["const".len] == '\t'))
            {
                const_elem = true;
                elem = std.mem.trim(u8, elem["const".len..], " \t");
            }
            var elem_ct = self.cTypeOfResolved(elem);
            if (elem_ct == null) {
                const etag = mangleOpaqueName(self.allocator, elem) orelse return null;
                elem_ct = std.fmt.allocPrint(self.allocator, "struct {s}", .{etag}) catch null;
            }
            const ct = elem_ct orelse return null;
            const member = if (const_elem and !std.mem.startsWith(u8, ct, "const "))
                std.fmt.allocPrint(self.allocator, "const {s}", .{ct}) catch return null
            else
                ct;
            const tag = mangleOpaqueName(self.allocator, member) orelse return null;
            self.slice_decls.put(tag, member) catch return null;
            self.checkCatalogName("slice_prefix", "__koru_slice_");
            return std.fmt.allocPrint(self.allocator, "struct __koru_slice_{s}", .{tag}) catch null;
        }
        // `{ f: T, g: U }` — an anonymous record. Koru records are
        // structural: the C type is `struct __koru_rec_<tag>` where the tag
        // is the mangled canonical `f:t` list — shape-identical records
        // share one struct, so a value bound to one event's `{a,b}` returns
        // through another's. Resolution registers the cell for the def pass.
        // (Before the `<` strip — a phantom-qualified field type inside the
        // braces must not split the record at its inner `<`.)
        if (t.len > 1 and t[0] == '{' and struct_literal.isKoruStructLiteral(t)) {
            const rfields = struct_literal.parseFields(self.allocator, t) catch return null;
            defer self.allocator.free(rfields);
            for (rfields) |f| {
                if (self.cTypeOfResolved(f.value) == null) return null;
            }
            const tag = recordTagOf(self.allocator, t) orelse return null;
            if (!self.record_decls.contains(tag)) {
                var pfields: std.ArrayList(ProtoField) = .empty;
                for (rfields) |f| {
                    pfields.append(self.allocator, .{
                        .name = self.allocator.dupe(u8, f.name) catch return null,
                        .ktype = self.allocator.dupe(u8, f.value) catch return null,
                    }) catch return null;
                }
                self.record_decls.put(self.allocator.dupe(u8, tag) catch return null, pfields.toOwnedSlice(self.allocator) catch return null) catch return null;
            }
            self.checkCatalogName("rec_prefix", "__koru_rec_");
            return std.fmt.allocPrint(self.allocator, "struct __koru_rec_{s}", .{tag}) catch null;
        }
        // `T<...>` — a phantom-qualified scalar: the obligation marks the
        // value, not the runtime shape (`string<!allocated>` IS a
        // `const char *`). The base name resolves the same way;
        // `List_i64<list!>` strips to `List_i64` and still finds no C type.
        if (std.mem.indexOfScalar(u8, t, '<')) |lt| {
            return self.cTypeOfResolved(std.mem.trim(u8, t[0..lt], " \t"));
        }
        // A record proto's name IS its C struct's name — `Reading` spells
        // `struct Reading`, the same nominal type the zig lane mints. Every
        // field must resolve (a nested proto field resolves by the same
        // rule); the depth cap refuses value-recursive field graphs that
        // could never mint a finite struct.
        if (self.protos.get(t)) |pfields| {
            if (self.proto_depth >= 16) return null;
            self.proto_depth += 1;
            defer self.proto_depth -= 1;
            for (pfields) |pf| {
                if (self.cTypeOfResolved(pf.ktype) == null) return null;
            }
            return std.fmt.allocPrint(self.allocator, "struct {s}", .{t}) catch null;
        }
        // `Expression`/`Source` — the compiler's own AST types reach input
        // records on comptime-surface events as flow-through holes: the C
        // lane never observes the value (any read is already a comptime
        // boundary), so a nominal one-byte placeholder is the honest cell.
        // `__koru_comptime_*` tags keep distinct holes from binding across
        // each other and can never collide with a proto-typedef'd name.
        if (std.mem.eql(u8, t, "Expression")) return "struct __koru_comptime_Expression";
        if (std.mem.eql(u8, t, "Source")) return "struct __koru_comptime_Source";
        // `i128`/`u128` — the oracle's C has no `__int128` (CompCert refuses
        // the keyword outright), so the representation is the honest
        // two-word cell, two's-complement hi/lo. Only the *type* is
        // promised: the pump wait contract (`-> i128` re-poll ns, the
        // `{ fd, wait_ns }` record) needs a signature and a literal
        // initializer, both of which this spells; genuine 128-bit
        // arithmetic in program text produces ill-typed C and fails at
        // ccomp — a loud boundary, never a silent narrowing to i64.
        if (std.mem.eql(u8, t, "i128")) {
            self.needs_i128 = true;
            return "struct __koru_i128";
        }
        if (std.mem.eql(u8, t, "u128")) {
            self.needs_u128 = true;
            return "struct __koru_u128";
        }
        return null;
    }

    // -- event emission ----------------------------------------------------

    fn eventIsStub(event: *const ast.EventDecl) bool {
        return event.hasAnnotation("transform") or event.hasAnnotation("comptime") or
            event.hasAnnotation("norun") or event.hasAnnotation("keyword");
    }

    /// `struct <name>_in { <ct> <f>; ... };` + prototype, ahead of the
    /// definitions so handlers may call each other in any order.
    fn emitEventDeclaration(self: *Emitter, event: *const ast.EventDecl) CEmitError!void {
        const key = try pathKey(self.allocator, event.path);
        defer self.allocator.free(key);
        const name = try mangle(self.allocator, event.path);
        defer self.allocator.free(name);

        if (eventIsStub(event)) {
            try self.writeFmt("static void {s}(void);\n", .{name});
            return;
        }
        if (event.input.is_wildcard) return;

        if (event.branches.len > 0) {
            try self.emitTaggedResultDecl(event, name, key);
            if (event.input.fields.len > 0) {
                try self.writeFmt("struct {s}_in {{\n", .{name});
                for (event.input.fields) |f| {
                    if (codegen_utils.cArrayType(f.type, catalogCTypeResolver, self)) |at| {
                        try self.writeFmt("    {s} {s}{s};\n", .{ at.base, codegen_utils.cMemberName(self.allocator, f.name), at.dims });
                        continue;
                    }
                    const ct = self.cTypeOfResolved(f.type) orelse {
                        std.debug.print("error[KORU047]: C lane: {s} field {s} has type {s} — no C type in the first fragment\n", .{ key, f.name, f.type });
                        return CEmitError.UnsupportedConstruct;
                    };
                    try self.writeFmt("    {s} {s};\n", .{ ct, codegen_utils.cMemberName(self.allocator, f.name) });
                }
                try self.write("};\n");
            }
            // An event declaring `!` arms has no standalone function — its
            // `|c` body is per-call-site inline text (raise markers splice
            // the consumer's arms), so no prototype exists either. The zig
            // lane's `handler(input, comptime __H)` is the same shape: the
            // decl exists, the call never does.
            if (eventHasEffectBranch(event)) return;
            try self.writeFmt("static struct {s}_res {s}(", .{ name, name });
            if (event.input.fields.len == 0) {
                try self.write("void");
            } else {
                try self.writeFmt("struct {s}_in {s}", .{ name, INPUT_PARAM });
            }
            try self.write(");\n");
            return;
        }

        const ret = try self.eventReturnType(event, key);
        if (event.input.fields.len > 0) {
            try self.writeFmt("struct {s}_in {{\n", .{name});
            for (event.input.fields) |f| {
                if (codegen_utils.cArrayType(f.type, catalogCTypeResolver, self)) |at| {
                    try self.writeFmt("    {s} {s}{s};\n", .{ at.base, codegen_utils.cMemberName(self.allocator, f.name), at.dims });
                    continue;
                }
                const ct = self.cTypeOfResolved(f.type) orelse {
                    std.debug.print("error[KORU047]: C lane: {s} field {s} has type {s} — no C type in the first fragment\n", .{ key, f.name, f.type });
                    return CEmitError.UnsupportedConstruct;
                };
                try self.writeFmt("    {s} {s};\n", .{ ct, codegen_utils.cMemberName(self.allocator, f.name) });
            }
            try self.write("};\n");
        }
        try self.writeFmt("static {s} {s}(", .{ ret, name });
        if (event.input.fields.len == 0) {
            try self.write("void");
        } else {
            try self.writeFmt("struct {s}_in {s}", .{ name, INPUT_PARAM });
        }
        try self.write(");\n");
    }

    fn eventReturnType(self: *Emitter, event: *const ast.EventDecl, key: []const u8) CEmitError![]const u8 {
        if (event.return_type) |rt| {
            return self.cTypeOfResolved(rt) orelse {
                std.debug.print("error[KORU047]: C lane: {s} returns {s} — no C type in the first fragment\n", .{ key, rt });
                return CEmitError.UnsupportedConstruct;
            };
        }
        return "void";
    }

    fn emitEventDecl(self: *Emitter, event: *const ast.EventDecl) CEmitError!void {
        const key = try pathKey(self.allocator, event.path);
        defer self.allocator.free(key);
        const name = try mangle(self.allocator, event.path);
        defer self.allocator.free(name);

        if (eventIsStub(event)) {
            // A transform/comptime/[norun] tor reached at emission — emit a
            // loud stub the way the js emitter emits its throwing handler:
            // the shape is declared, the call is a defect.
            try self.writeFmt("static void {s}(void) {{\n", .{name});
            try self.writeFmt("    __koru_unreachable(\"{s}: transform/comptime tor invoked on the C lane\");\n}}\n\n", .{key});
            return;
        }

        // An event declaring `!` arms is never a C function: its `|c` body
        // is per-call-site inline text, spliced where the flow invokes it
        // (the zig lane's `handler(input, comptime __H)` twin — decl yes,
        // direct call never). Requiring the |c body here keeps the wall
        // honest: a `!` event without one is NoCProcBody, not a silent void.
        if (eventHasEffectBranch(event)) {
            if (self.cProcOf(key) == null) {
                std.debug.print("error[KORU047]: C lane: {s} has no |c proc body and no Koru impl (NoCProcBody)\n", .{key});
self.checkCatalogFragment("missing-target-proc-body");
            self.checkCatalogConstruct(key);
                return CEmitError.NoCProcBody;
            }
            return;
        }

        if (event.input.is_wildcard) {
            std.debug.print("error[KORU047]: C lane: {s} wildcard input — outside the first fragment\n", .{key});
            return CEmitError.UnsupportedConstruct;
        }

        const ret = if (event.branches.len > 0)
            try std.fmt.allocPrint(self.allocator, "struct {s}_res", .{name})
        else
            try self.eventReturnType(event, key);
        const saved_event = self.cur_event;
        self.cur_event = event;
        defer self.cur_event = saved_event;
        try self.writeFmt("static {s} {s}(", .{ ret, name });
        if (event.input.fields.len == 0) {
            try self.write("void");
        } else {
            try self.writeFmt("struct {s}_in {s}", .{ name, INPUT_PARAM });
        }
        try self.write(") {\n");

        // Impl resolution: |c proc > immediate `->` > subflow impl > refuse.
        if (self.cProcOf(key)) |p| {
            try self.emitFieldBindings(event);
            try self.writeHostText(p.body.text);
            try self.write("\n}\n\n");
            return;
        }
        if (self.impls.get(key)) |ii| {
            // An immediate impl's value is a BranchConstructor — the same
            // produce a continuation body emits, so it routes through the
            // same lowering: `-> expr` returns, `=> name {…}` / `=> name v`
            // build the tagged `struct <name>_res`, and what emitProduce
            // cannot carry it refuses named.
            try self.emitFieldBindings(event);
            try self.emitProduce(&ii.value, "    ");
            try self.write("}\n\n");
            return;
        }
        if (self.impl_flows.get(key)) |flist| {
            if (flist.items.len != 1) {
                std.debug.print("error[KORU047]: C lane: {s} has {d} subflow impls — variant selection is outside the first fragment\n", .{ key, flist.items.len });
                return CEmitError.UnsupportedConstruct;
            }
            try self.emitFieldBindings(event);
            try self.emitImplFlowBody(flist.items[0]);
            try self.write("}\n\n");
            return;
        }
        std.debug.print("error[KORU047]: C lane: {s} has no |c proc body and no Koru impl (NoCProcBody)\n", .{key});
        self.checkCatalogFragment("missing-target-proc-body");
            self.checkCatalogConstruct(key);
        return CEmitError.NoCProcBody;
    }

    /// An impl flow's body — `flow.inline_body` is transform output the
    /// same way a top-level flow's is (the print family's reroute lands
    /// here too, and emitSite alone would miss it and call the [norun]
    /// stub). Splice like emitFlow does, continuations resolved. A
    /// `//@koru:stmt_scope` preamble (~capture) is fn-local and the head
    /// call is consumed — emit it, then walk only dissolved continuations.
    /// A file-scope preamble on an impl is still dropped — const|c has no
    /// impl author today. The impl-resolution path and the walk's
    /// write-stage adapter share this — one cascade, one truth.
    fn emitImplFlowBody(self: *Emitter, implf: *const ast.Flow) CEmitError!void {
        try self.emitSplicedFlowBody(implf, .in_impl, if (implf.preamble_code) |pre| stripStmtScopeMarker(pre) else null);
    }

    fn findBranch(event: *const ast.EventDecl, name: []const u8) ?*const ast.Branch {
        for (event.branches) |*b| {
            if (std.mem.eql(u8, b.name, name)) return b;
        }
        return null;
    }

    /// The event declares `!` arms — the shape that makes it call-site
    /// inline text rather than a standalone function.
    fn eventHasEffectBranch(event: *const ast.EventDecl) bool {
        for (event.branches) |*b| {
            if (b.kind == .effect) return true;
        }
        return false;
    }

    /// The event's declared `|c` proc body, if one exists.
    fn cProcOf(self: *Emitter, key: []const u8) ?*const ast.ProcDecl {
        if (self.procs.get(key)) |plist| {
            for (plist.items) |p| {
                if (p.target) |t| {
                    if (std.mem.eql(u8, t, C_TARGET)) return p;
                }
            }
        }
        return null;
    }

    /// The payload member's C spelling for a branch: null for an empty
    /// payload, the scalar's C type for a `__type_ref` single, the named
    /// payload struct `struct <name>_<branch>_t` for a record payload.
    fn branchPayloadCType(self: *Emitter, event_name: []const u8, key: []const u8, b: *const ast.Branch) CEmitError!?[]const u8 {
        if (b.payload.is_wildcard) {
            // `| x *` — the payload's shape is filled by the use site, not the
            // decl; the zig union member is `struct {}` for the same reason.
            // The C fragment mints a named one-byte placeholder: the decl
            // compiles, while any real produce (`=> x v` fails the __type_ref
            // check) or typed read refuses downstream instead of coercing.
            return try std.fmt.allocPrint(
                self.allocator,
                "struct {s}_{s}_t",
                .{ event_name, codegen_utils.cMemberName(self.allocator, b.name) },
            );
        }
        const fs = b.payload.fields;
        if (fs.len == 0) return null;
        if (fs.len == 1 and std.mem.eql(u8, fs[0].name, "__type_ref")) {
            const ct = self.cTypeOfResolved(fs[0].type) orelse {
                std.debug.print("error[KORU047]: C lane: {s} branch `| {s}` payload type {s} — no C type in the first fragment\n", .{ key, b.name, fs[0].type });
                return CEmitError.UnsupportedConstruct;
            };
            return ct;
        }
        for (fs) |f| {
            if (std.mem.eql(u8, f.name, "__type_ref")) {
                std.debug.print("error[KORU047]: C lane: {s} branch `| {s}` mixes `__type_ref` with named fields — outside the first fragment\n", .{ key, b.name });
                return CEmitError.UnsupportedConstruct;
            }
            if (self.cTypeOfResolved(f.type) == null) {
                std.debug.print("error[KORU047]: C lane: {s} branch `| {s}` payload field {s} has type {s} — no C type in the first fragment\n", .{ key, b.name, f.name, f.type });
                return CEmitError.UnsupportedConstruct;
            }
        }
        return try std.fmt.allocPrint(self.allocator, "struct {s}_{s}_t", .{ event_name, codegen_utils.cMemberName(self.allocator, b.name) });
    }

    /// `enum { <name>_tag_<b>, … };` + record payload struct types +
    /// `struct <name>_res { int tag; <members> };` — the tagged-result
    /// machinery an event's named `|` branches lower to (the union(enum)
    /// the zig lane emits, spelled flat the way the js record is).
    fn emitTaggedResultDecl(self: *Emitter, event: *const ast.EventDecl, name: []const u8, key: []const u8) CEmitError!void {
        // `!` effect branches join no result — they splice per call site.
        // Their payload structs still emit (an effect arm's binding reads
        // that type at the raise), but the enum and `_res` members are
        // terminal-only.
        var terminal_count: usize = 0;
        for (event.branches) |*b| {
            if (b.kind == .effect) continue;
            terminal_count += 1;
            _ = try self.branchPayloadCType(name, key, b);
        }
        for (event.branches) |*b| {
            const fs = b.payload.fields;
            const is_rec = (fs.len > 0 and !std.mem.eql(u8, fs[0].name, "__type_ref")) or b.payload.is_wildcard;
            if (!is_rec) continue;
            try self.writeFmt("struct {s}_{s}_t {{\n", .{ name, codegen_utils.cMemberName(self.allocator, b.name) });
            if (b.payload.is_wildcard) {
                // C has no `struct {}` — one byte carries the shape hole the
                // `| x *` decl leaves for the use site to fill.
                try self.write("    char __koru_wildcard;\n");
            } else {
                for (fs) |f| {
                    const ct = self.cTypeOfResolved(f.type) orelse {
                        std.debug.print("error[KORU047]: C lane: {s} branch `! {s}` payload field {s} has type {s} — no C type in the first fragment\n", .{ key, b.name, f.name, f.type });
                        return CEmitError.UnsupportedConstruct;
                    };
                    try self.writeFmt("    {s} {s};\n", .{ ct, codegen_utils.cMemberName(self.allocator, f.name) });
                }
            }
            try self.write("};\n");
        }
        if (terminal_count == 0) return;
        try self.write("enum {\n");
        for (event.branches) |*b| {
            if (b.kind == .effect) continue;
            try self.writeFmt("    {s},\n", .{codegen_utils.cResTagConst(self.allocator, name, b.name)});
        }
        try self.write("};\n");
        try self.writeFmt("struct {s}_res {{\n", .{name});
        try self.write("    int tag;\n");
        for (event.branches) |*b| {
            if (b.kind == .effect) continue;
            const ptype = (try self.branchPayloadCType(name, key, b)) orelse continue;
            try self.writeFmt("    {s} {s};\n", .{ ptype, codegen_utils.cPayloadMember(self.allocator, b.name) });
        }
        try self.write("};\n");
    }

    /// `const <ct> <field> = __koru_in.<field>;` — the |c proc binding
    /// convention, same as the js/cs prologue off their input param.
    fn emitFieldBindings(self: *Emitter, event: *const ast.EventDecl) CEmitError!void {
        for (event.input.fields) |f| {
            const cm = codegen_utils.cMemberName(self.allocator, f.name);
            if (codegen_utils.cArrayType(f.type, catalogCTypeResolver, self)) |at| {
                // `[N]T` fields bind as pointers — C arrays are not
                // assignable, and `arr[i]` indexes identically on
                // `T *` (1-D) / `T (*)[M]` (N-D), so .kc bodies stay
                // verbatim.
                try self.int_bindings.put(f.name, at.base);
                try self.writeFmt("    {s} = {s}.{s};\n", .{ codegen_utils.cArrayPtrDecl(self.allocator, at, cm), INPUT_PARAM, cm });
                continue;
            }
            const ct = self.cTypeOfResolved(f.type) orelse {
                std.debug.print("error[KORU047]: C lane: field {s} has type {s} — no C type in the first fragment\n", .{ f.name, f.type });
                return CEmitError.UnsupportedConstruct;
            };
            try self.int_bindings.put(f.name, ct);
            try self.writeFmt("    {s} const {s} = {s}.{s};\n", .{ ct, cm, INPUT_PARAM, cm });
        }
    }

    // -- call/continuation emission ----------------------------------------

    const SiteCtx = enum { in_flow, in_impl };

    fn emitSite(self: *Emitter, site: *const ast.Continuation, indent: []const u8, ctx: SiteCtx) CEmitError!void {
        if (site.kind == .effect) return CEmitError.RefusedConstruct;
        // A `.terminal` node on a named arm is the auto_discharge_inserter's
        // synthesized NO-OP for a declared-but-absent optional branch
        // (auto_discharge_inserter.zig:5444) — e.g. `| ?captured` after the
        // ~capture transform consumed it. The arm fires nothing by
        // construction; only an arm with a body is real tagged dispatch.
        if (site.node != null and site.node.? == .terminal) return;
        if (site.branch.len != 0) {
            std.debug.print("error[KORU047]: C lane: branch arm `| {s}` — tagged dispatch is outside the first fragment\n", .{site.branch});
            return CEmitError.UnsupportedConstruct;
        }
        if (site.binding != null or site.destructure.len != 0) {
            std.debug.print("error[KORU047]: C lane: branch-arm binding — tagged payloads are outside the first fragment\n", .{});
            return CEmitError.UnsupportedConstruct;
        }
        var consumed: u64 = 0;
        if (site.condition) |cond| {
            try self.write(indent);
            try self.write("if (");
            try self.writeExpr(cond);
            try self.write(") {\n");
            consumed = try self.emitSiteNode(site, indent, ctx);
            try self.write(indent);
            try self.write("}\n");
        } else {
            consumed = try self.emitSiteNode(site, indent, ctx);
        }
        try self.emitUnconsumedContinuations(site.continuations, consumed, indent, ctx);
    }

    /// The arms an inline body resolved NO marker for — the js emitter's drain
    /// semantics: an unmarked effect was never installed, a consumed arm was
    /// emitted at its marker, and under a DISPATCHER body (consumed != 0) a
    /// named leftover is the template's own dispatch vocabulary (skip it)
    /// while an unnamed one is the caller's sequel (drain body-only). Under a
    /// rendered-statement body (consumed == 0) every terminal drains through
    /// the normal refusal gates.
    fn emitUnconsumedContinuations(
        self: *Emitter,
        continuations: []const ast.Continuation,
        consumed: u64,
        indent: []const u8,
        ctx: SiteCtx,
    ) CEmitError!void {
        for (continuations, 0..) |*cont, ci| {
            if (cont.kind != .terminal) continue;
            if (ci < 64 and (consumed & (@as(u64, 1) << @intCast(ci))) != 0) continue;
            if (consumed != 0) {
                if (cont.branch.len != 0) continue;
                try self.emitInlineContinuationBody(cont, indent, ctx);
            } else {
                try self.emitSite(cont, indent, ctx);
            }
        }
    }

    /// One marker-resolved arm's body: the node plus its sequel, without
    /// emitSite's gates — a template already dispatched this arm, so `!`
    /// effect handlers and arm bindings land here by design.
    fn emitInlineContinuationBody(self: *Emitter, cont: *const ast.Continuation, indent: []const u8, ctx: SiteCtx) CEmitError!void {
        const consumed = try self.emitSiteNode(cont, indent, ctx);
        try self.emitUnconsumedContinuations(cont.continuations, consumed, indent, ctx);
    }

    /// Scan template-authored body text for the hand-off markers
    /// `__koru_continue[_bare_]_N` (terminal arm splice) and
    /// `__koru_inline_[scoped_]_N(arg)` (effect-handler splice with the
    /// iterated value bound). The scaffolding between markers is C the |c
    /// templates authored — verbatim through writeHostText. Any other
    /// `__koru_` token is a refusal the template named (`__koru_c_refuse_*`)
    /// or a marker this fragment does not know — either way KORU047, never
    /// leaked into the output. Port of js_emitter's
    /// emitInlineBodyResolvingContinuations.
    fn emitInlineBodyResolvingContinuations(
        self: *Emitter,
        body: []const u8,
        continuations: []const ast.Continuation,
        indent: []const u8,
        ctx: SiteCtx,
        consumed: ?*u64,
    ) CEmitError!void {
        if (consumed) |c| {
            if (continuations.len > 64) c.* = ~@as(u64, 0);
        }
        const body_indent = try std.fmt.allocPrint(self.allocator, "{s}    ", .{indent});
        defer self.allocator.free(body_indent);

        const SPLICE_PREFIX = "__koru_inline_";
        const CONTINUE_PREFIX = "__koru_continue_";
        const REFUSE_PREFIX = "__koru_c_refuse_";
        const SCOPED_INFIX = "scoped_";
        const BARE_INFIX = "bare_";

        const trimmed = std.mem.trim(u8, body, " \t\r\n");
        var pos: usize = 0;
        while (true) {
            // Only the three marker families are intercepted; every other
            // `__koru_*` token is a runtime helper the file prelude defines
            // (__koru_stdout_write, __koru_concat, ...) and passes through as
            // ordinary host text — an undefined one fails loudly at the C
            // compiler downstream, never silently.
            const splice_at = std.mem.indexOfPos(u8, trimmed, pos, SPLICE_PREFIX);
            const continue_at = std.mem.indexOfPos(u8, trimmed, pos, CONTINUE_PREFIX);
            const refuse_at = std.mem.indexOfPos(u8, trimmed, pos, REFUSE_PREFIX);
            var m: usize = undefined;
            var kind: enum { splice, cont, refuse } = undefined;
            if (splice_at) |s| {
                m = s;
                kind = .splice;
            } else {
                m = trimmed.len;
                kind = .cont;
            }
            if (continue_at) |c| {
                if (c < m) {
                    m = c;
                    kind = .cont;
                }
            }
            if (refuse_at) |r| {
                if (r < m) {
                    m = r;
                    kind = .refuse;
                }
            }
            if (m == trimmed.len) break;
            try self.writeHostText(trimmed[pos..m]);

            if (kind == .refuse) {
                var j = m + REFUSE_PREFIX.len;
                while (j < trimmed.len and (std.ascii.isAlphanumeric(trimmed[j]) or trimmed[j] == '_')) j += 1;
                std.debug.print("error[KORU047]: C lane: `{s}` is outside the first fragment\n", .{trimmed[m..j]});
                return CEmitError.UnsupportedConstruct;
            }

            if (kind == .cont) {
                var i = m + CONTINUE_PREFIX.len;
                const is_bare = std.mem.startsWith(u8, trimmed[i..], BARE_INFIX);
                if (is_bare) i += BARE_INFIX.len;
                const idx = codegen_utils.scanDecimalIndex(trimmed, &i) orelse {
                    std.debug.print("error[KORU047]: C lane: malformed __koru_continue marker\n", .{});
                    return CEmitError.UnsupportedConstruct;
                };
                if (idx >= continuations.len) {
                    std.debug.print("error[KORU047]: C lane: __koru_continue_{d} has no matching continuation (have {d})\n", .{ idx, continuations.len });
                    return CEmitError.UnsupportedConstruct;
                }
                if (consumed) |c| {
                    if (idx < 64) c.* |= @as(u64, 1) << @intCast(idx);
                }
                const cont = &continuations[idx];
                const guarded = !is_bare and cont.condition != null;
                try self.write("{ ");
                if (guarded) {
                    try self.write("if (");
                    try self.writeExpr(cont.condition.?);
                    try self.write(") { ");
                }
                try self.emitInlineContinuationBody(cont, body_indent, ctx);
                if (guarded) try self.write(" }");
                try self.write(" }\n");
                pos = i;
                continue;
            }

            if (kind == .splice) {
                var i = m + SPLICE_PREFIX.len;
                if (std.mem.startsWith(u8, trimmed[i..], SCOPED_INFIX)) i += SCOPED_INFIX.len;
                const maybe_idx = codegen_utils.scanDecimalIndex(trimmed, &i);

                var arg: []const u8 = "";
                if (maybe_idx != null and i < trimmed.len and trimmed[i] == '(') {
                    const arg_start = i + 1;
                    var depth: usize = 1;
                    var j = arg_start;
                    while (j < trimmed.len and depth > 0) : (j += 1) {
                        if (trimmed[j] == '(') {
                            depth += 1;
                        } else if (trimmed[j] == ')') {
                            depth -= 1;
                        }
                    }
                    arg = std.mem.trim(u8, trimmed[arg_start .. j - 1], " \t");
                    i = j;
                    if (i < trimmed.len and trimmed[i] == ';') i += 1;
                }

                const idx = maybe_idx orelse {
                    std.debug.print("error[KORU047]: C lane: malformed __koru_inline marker\n", .{});
                    return CEmitError.UnsupportedConstruct;
                };
                if (idx >= continuations.len) {
                    std.debug.print("error[KORU047]: C lane: __koru_inline_{d} has no matching continuation (have {d})\n", .{ idx, continuations.len });
                    return CEmitError.UnsupportedConstruct;
                }
                if (consumed) |c| {
                    if (idx < 64) c.* |= @as(u64, 1) << @intCast(idx);
                }
                const cont = &continuations[idx];
                if (cont.destructure.len != 0) {
                    std.debug.print("error[KORU047]: C lane: destructured effect binding — outside the first fragment\n", .{});
self.checkCatalogFragment("destructure");
                    return CEmitError.UnsupportedConstruct;
                }
                try self.write("{ ");
                if (cont.binding) |binding| {
                    if (!std.mem.eql(u8, binding, "_")) {
                        // `long long` is the fragment's int — for|c only mints
                        // this splice for a range item, which is one.
                        try self.int_bindings.put(binding, "long long");
                        try self.writeFmt("long long {s} = {s}; ", .{ binding, arg });
                    }
                }
                const guarded = cont.condition != null;
                if (guarded) {
                    try self.write("if (");
                    try self.writeExpr(cont.condition.?);
                    try self.write(") { ");
                }
                try self.emitInlineContinuationBody(cont, body_indent, ctx);
                if (guarded) try self.write(" }");
                try self.write(" }\n");
                pos = i;
                continue;
            }

        }
        try self.writeHostText(trimmed[pos..]);
    }

    /// A `!`-declaring event's call site: the proc's `|c` body emits INLINE
    /// at the site — the same lowering the zig lane performs (its emitted
    /// flow text splices the proc body and each `item(it)` raise is the
    /// consumer's `!` arm). Field binds come from the invocation args;
    /// `__koru_raise_<arm>(v)` markers in the body splice the site's
    /// matching `!` continuations with `v` bound to the arm's payload name;
    /// every `return` in the host text becomes `<res> = E; goto <done>` so
    /// a `|` dispatch can follow the block. Ambient locals are plain
    /// locals — scope is shared, no env exists. Returns the consumed mask:
    /// all of the site's continuations are handled here (~0).
    fn emitEffectInlineSite(
        self: *Emitter,
        site: *const ast.Continuation,
        inv: *const ast.Invocation,
        event: *const ast.EventDecl,
        key: []const u8,
        indent: []const u8,
        ctx: SiteCtx,
    ) CEmitError!u64 {
        const name = try mangle(self.allocator, inv.path);
        defer self.allocator.free(name);
        const cproc = self.cProcOf(key) orelse {
            std.debug.print("error[KORU047]: C lane: {s} has no |c proc body and no Koru impl (NoCProcBody)\n", .{key});
            self.checkCatalogFragment("missing-target-proc-body");
            self.checkCatalogConstruct(key);
            return CEmitError.NoCProcBody;
        };
        if (inv.return_destructure.len != 0) {
            std.debug.print("error[KORU047]: C lane: {s} destructure at the bind — outside the first fragment\n", .{key});
self.checkCatalogFragment("destructure");
            return CEmitError.UnsupportedConstruct;
        }
        for (site.continuations) |*c| {
            if (c.kind != .terminal) continue;
            if (c.is_catchall) {
                std.debug.print("error[KORU047]: C lane: {s} — `|*` catchall arm is outside the first fragment\n", .{key});
                return CEmitError.UnsupportedConstruct;
            }
            if (c.branch.len != 0 and c.condition != null) {
                std.debug.print("error[KORU047]: C lane: {s} arm `| {s} when` — guarded dispatch is outside the first fragment\n", .{ key, c.branch });
                return CEmitError.UnsupportedConstruct;
            }
            if (c.branch.len != 0 and findBranch(event, c.branch) == null) {
                std.debug.print("error[KORU047]: C lane: {s} arm `| {s}` names no declared branch\n", .{ key, c.branch });
                return CEmitError.UnsupportedConstruct;
            }
        }

        var has_terms = false;
        for (event.branches) |*b| {
            if (b.kind == .terminal) has_terms = true;
        }
        self.res_counter += 1;
        const site_id = self.res_counter;
        var res_ty_owned: ?[]const u8 = null;
        defer if (res_ty_owned) |t| self.allocator.free(t);
        const res_ty: ?[]const u8 = if (has_terms)
            blk: {
                res_ty_owned = try std.fmt.allocPrint(self.allocator, "struct {s}_res", .{name});
                break :blk res_ty_owned;
            }
        else if (event.return_type) |rt|
            self.cTypeOfResolved(rt) orelse {
                std.debug.print("error[KORU047]: C lane: {s} returns {s} — no C type in the first fragment\n", .{ key, rt });
                return CEmitError.UnsupportedConstruct;
            }
        else
            null;
        var res_name_owned: ?[]const u8 = null;
        defer if (res_name_owned) |rn| self.allocator.free(rn);
        const res_name: ?[]const u8 = if (res_ty != null)
            if (inv.return_binding) |bind| bind else blk: {
                res_name_owned = try std.fmt.allocPrint(self.allocator, "__koru_eff_res_{d}", .{site_id});
                break :blk res_name_owned;
            }
        else
            null;
        const done_label = try std.fmt.allocPrint(self.allocator, "__koru_eff_done_{d}", .{site_id});
        defer self.allocator.free(done_label);

        if (res_ty) |rt| {
            if (res_name) |rn| {
                try self.int_bindings.put(rn, rt);
                try self.writeFmt("{s}{s} {s};\n", .{ indent, rt, rn });
            }
        }
        try self.writeFmt("{s}{{\n", .{indent});
        const inner = try std.fmt.allocPrint(self.allocator, "{s}    ", .{indent});
        defer self.allocator.free(inner);
        // `const <ct> <field> = <arg>;` — the emitFieldBindings shape with
        // the call site's expression instead of `__koru_in.<field>`.
        for (event.input.fields, 0..) |f, fi| {
            const ct = self.cTypeOfResolved(f.type) orelse {
                std.debug.print("error[KORU047]: C lane: {s} field {s} has type {s} — no C type in the first fragment\n", .{ key, f.name, f.type });
                return CEmitError.UnsupportedConstruct;
            };
            try self.int_bindings.put(f.name, ct);
            try self.writeFmt("{s}{s} const {s} = ", .{ inner, ct, codegen_utils.cMemberName(self.allocator, f.name) });
            var argbuf: std.ArrayList(u8) = .empty;
            const saved_buf = self.buf;
            self.buf = &argbuf;
            defer self.buf = saved_buf;
            try self.emitArgForField(inv, f, fi);
            self.buf = saved_buf;
            try self.write(argbuf.items);
            argbuf.deinit(self.allocator);
            try self.write(";\n");
        }
        try self.emitEffectBodyInline(cproc.body.text, site, event, name, key, res_name, done_label, inner, ctx);
        try self.writeFmt("{s}{s}: ;\n{s}}}\n", .{ inner, done_label, indent });

        // `|` dispatch on the produced result — the emitTaggedCall shape.
        if (res_name != null and has_terms) {
            const rn = res_name.?;
            try self.writeFmt("{s}switch ({s}.tag) {{\n", .{ indent, rn });
            for (site.continuations) |*cont| {
                if (cont.kind != .terminal or cont.branch.len == 0) continue;
                try self.writeFmt("{s}case {s}: {{\n", .{ indent, codegen_utils.cResTagConst(self.allocator, name, cont.branch) });
                try self.emitBranchBinding(event, cont, rn, inner);
                const consumed = try self.emitSiteNode(cont, inner, ctx);
                try self.emitUnconsumedContinuations(cont.continuations, consumed, inner, ctx);
                try self.writeFmt("{s}break; }}\n", .{inner});
            }
            try self.writeFmt("{s}default: break;\n{s}}}\n", .{ indent, indent });
        }
        // The post-call sequel: unnamed terminal continuations always run.
        for (site.continuations) |*cont| {
            if (cont.kind != .terminal or cont.branch.len != 0) continue;
            try self.emitSite(cont, indent, ctx);
        }
        return ~@as(u64, 0);
    }

    /// One `|c` proc body emitted as call-site inline text. Two host-text
    /// spells get rewritten; everything else passes verbatim:
    ///   `__koru_raise_<arm>(<v>);` — splice the site's `! <arm>`
    ///     continuations with `<v>` bound to the arm payload name (all
    ///     matching arms, each under its `when`; an optional arm with no
    ///     installed continuation splices nothing).
    ///   `return E;` — `<res> = (E); goto <done>;` so the block stays
    ///     inline under the enclosing flow (a `return` would exit `main`,
    ///     and `break` could not escape a nested `for`).
    /// Strings, chars, and comments are never rewritten.
    fn emitEffectBodyInline(
        self: *Emitter,
        body: []const u8,
        site: *const ast.Continuation,
        event: *const ast.EventDecl,
        name: []const u8,
        key: []const u8,
        res_name: ?[]const u8,
        done_label: []const u8,
        indent: []const u8,
        ctx: SiteCtx,
    ) CEmitError!void {
        const RAISE = "__koru_raise_";
        var i: usize = 0;
        while (i < body.len) {
            const c = body[i];
            // literals and comments pass through untouched.
            if (c == '"' or c == '\'') {
                const start = i;
                i += 1;
                while (i < body.len and body[i] != c) {
                    if (body[i] == '\\') i += 1;
                    i += 1;
                }
                if (i < body.len) i += 1;
                try self.writeHostText(body[start..i]);
                continue;
            }
            if (c == '/' and i + 1 < body.len and body[i + 1] == '/') {
                const start = i;
                while (i < body.len and body[i] != '\n') i += 1;
                try self.writeHostText(body[start..i]);
                continue;
            }
            if (c == '/' and i + 1 < body.len and body[i + 1] == '*') {
                const start = i;
                i += 2;
                while (i + 1 < body.len and !(body[i] == '*' and body[i + 1] == '/')) i += 1;
                if (i + 1 < body.len) i += 2;
                try self.writeHostText(body[start..i]);
                continue;
            }
            if (std.ascii.isAlphabetic(c) or c == '_') {
                const id_start = i;
                while (i < body.len and codegen_utils.exprIdentChar(body[i])) i += 1;
                const ident = body[id_start..i];
                if (std.mem.eql(u8, ident, "return")) {
                    var j = i;
                    var depth: usize = 0;
                    while (j < body.len) : (j += 1) {
                        const b = body[j];
                        if (b == '(' or b == '[' or b == '{') depth += 1;
                        if (b == ')' or b == ']' or b == '}') {
                            if (depth == 0) break;
                            depth -= 1;
                        }
                        if (b == ';' and depth == 0) break;
                    }
                    const expr = std.mem.trim(u8, body[i..j], " \t\r\n");
                    if (j < body.len) j += 1; // the ';'
                    if (expr.len == 0) {
                        try self.writeFmt("goto {s}; ", .{done_label});
                    } else if (res_name) |rn| {
                        try self.writeFmt("{s} = ({s}); goto {s}; ", .{ rn, expr, done_label });
                    } else {
                        try self.writeFmt("({s}); goto {s}; ", .{ expr, done_label });
                    }
                    i = j;
                    continue;
                }
                if (std.mem.startsWith(u8, ident, RAISE)) {
                    const arm_name = ident[RAISE.len..];
                    // `<name>(<args>)` — balanced parens, then optional `;`.
                    var j = i;
                    while (j < body.len and std.ascii.isWhitespace(body[j])) j += 1;
                    if (j >= body.len or body[j] != '(') {
                        std.debug.print("error[KORU047]: C lane: `__koru_raise_{s}` is a marker, not a value — write `__koru_raise_{s}(v);`\n", .{ arm_name, arm_name });
                        return CEmitError.UnsupportedConstruct;
                    }
                    const arg_start = j + 1;
                    var depth: usize = 1;
                    j = arg_start;
                    while (j < body.len and depth > 0) : (j += 1) {
                        if (body[j] == '(') depth += 1;
                        if (body[j] == ')') depth -= 1;
                    }
                    const argtext = body[arg_start .. j - 1];
                    if (topLevelComma(argtext) != null) {
                        std.debug.print("error[KORU047]: C lane: `__koru_raise_{s}` carries several values — an effect payload is one value\n", .{arm_name});
                        return CEmitError.UnsupportedConstruct;
                    }
                    const arg = std.mem.trim(u8, argtext, " \t\r\n");
                    if (j < body.len and body[j] == ';') j += 1;
                    try self.spliceEffectArms(site, event, name, key, arm_name, arg, indent, ctx);
                    i = j;
                    continue;
                }
                try self.writeHostText(ident);
                continue;
            }
            try self.writeHostText(body[i .. i + 1]);
            i += 1;
        }
    }

    /// Splice every `! <arm>` continuation the site installed for `arm_name`
    /// — `{ <payload-type> const <bind> = <arg>; if (<when>) { <body> } }`
    /// per arm, source order (the zig multicast: several same-name arms each
    /// fire under their own guard). An optional arm never installed splices
    /// nothing; a required arm never installed — or a raise naming no
    /// declared effect — is a named refusal, never a silent skip.
    fn spliceEffectArms(
        self: *Emitter,
        site: *const ast.Continuation,
        event: *const ast.EventDecl,
        name: []const u8,
        key: []const u8,
        arm_name: []const u8,
        arg: []const u8,
        indent: []const u8,
        ctx: SiteCtx,
    ) CEmitError!void {
        // `! out-of-bounds` is authored `__koru_raise_out_of_bounds` in the
        // |c body — a C identifier; compare on the mangled spelling.
        var arm: ?*const ast.Branch = null;
        for (event.branches) |*b| {
            if (!std.mem.eql(u8, codegen_utils.cMemberName(self.allocator, b.name), arm_name)) continue;
            arm = b;
            break;
        }
        const arm_b = arm orelse {
            std.debug.print("error[KORU047]: C lane: `__koru_raise_{s}` names no branch of {s}\n", .{ arm_name, key });
            return CEmitError.UnsupportedConstruct;
        };
        if (arm_b.kind != .effect) {
            std.debug.print("error[KORU047]: C lane: `__koru_raise_{s}` names a `|` terminal — only `!` arms splice at raises\n", .{arm_name});
            return CEmitError.UnsupportedConstruct;
        }
        var installed: usize = 0;
        for (site.continuations) |*cont| {
            if (cont.kind != .effect or !std.mem.eql(u8, cont.branch, arm_b.name)) continue;
            installed += 1;
            if (cont.destructure.len != 0) {
                std.debug.print("error[KORU047]: C lane: destructured effect binding — outside the first fragment\n", .{});
                self.checkCatalogFragment("destructure");
                return CEmitError.UnsupportedConstruct;
            }
            try self.write("{ ");
            if (cont.binding) |binding| {
                if (!std.mem.eql(u8, binding, "_")) {
                    if (try self.branchPayloadCType(name, key, arm_b)) |pt| {
                        try self.int_bindings.put(binding, pt);
                        try self.writeFmt("{s} const {s} = {s}; ", .{ pt, binding, arg });
                    }
                }
            }
            const guarded = cont.condition != null;
            if (guarded) {
                try self.write("if (");
                try self.writeExpr(cont.condition.?);
                try self.write(") { ");
            }
            try self.emitInlineContinuationBody(cont, indent, ctx);
            if (guarded) try self.write(" }");
            try self.write(" }\n");
        }
        if (installed == 0 and !arm_b.is_optional) {
            std.debug.print("error[KORU047]: C lane: {s} raises `! {s}` but the call site installs no handler — a required arm cannot fire silently\n", .{ key, arm_name });
            return CEmitError.UnsupportedConstruct;
        }
    }

    /// Emit the arm's own node; returns the marker-consumed mask of the
    /// site's continuation list (0 when the node installed nothing — the
    /// caller drains the rest).
    fn emitSiteNode(self: *Emitter, site: *const ast.Continuation, indent: []const u8, ctx: SiteCtx) CEmitError!u64 {
        const node = site.node orelse return 0;
        switch (node) {
            .invocation => |*inv| {
                if (inv.preamble_code) |pre| {
                    try self.emitVerbatimLines(pre, indent);
                }
                if (inv.inline_body) |body| {
                    var consumed: u64 = 0;
                    try self.emitInlineBodyResolvingContinuations(stripInlineStmtMarker(body), site.continuations, indent, ctx, &consumed);
                    return consumed;
                } else {
                    const key = try pathKey(self.allocator, inv.path);
                    defer self.allocator.free(key);
                    if (self.events.get(key)) |event| {
                        if (eventHasEffectBranch(event)) {
                            // Per-call-site inline: the |c body lands here
                            // and its raise markers splice the site's `!`
                            // arms — the zig lane's identical lowering.
                            return try self.emitEffectInlineSite(site, inv, event, key, indent, ctx);
                        }
                    }
                    for (site.continuations) |*c| {
                        if (c.kind == .terminal and (c.branch.len != 0 or c.is_catchall)) {
                            try self.emitTaggedCall(site, inv, indent, ctx);
                            return ~@as(u64, 0);
                        }
                    }
                    try self.emitCall(inv, indent);
                    return 0;
                }
            },
            .inline_code => |text| {
                // A nested-site preamble dissolves into an `.inline_code`
                // node (transform_pass_runner's preamble→inline_code
                // contract — the husk is already dropped). If it carries
                // the stmt_scope marker it is a capture cell declaration:
                // register the cell name or a later `.assignment` cannot
                // prove its target was minted.
                if (stripStmtScopeMarker(text)) |sp| {
                    try self.emitCapPreamble(sp, indent);
                } else {
                    try self.emitVerbatimLines(text, indent);
                }
            },
            .assignment => |*asgn| {
                // `captured { f: e, ... }` lowered by ~capture. Snapshot
                // semantics (ruled 2026-07-02, pinned 320_102): every RHS
                // reads the INCOMING cell, then all stores land — the
                // temp-copy form keeps that ordering without needing a
                // per-field C type: `__koru_snap` is the cell's own type,
                // spelled by the `__koru_cap_<cell>` preamble convention.
                if (!self.cap_cells.contains(asgn.target)) {
                    std.debug.print("error[KORU047]: C lane: `.assignment` target `{s}` names no declared capture cell — a `//@koru:stmt_scope` preamble mints `struct __koru_cap_<cell>` first\n", .{asgn.target});
self.checkCatalogFragment("unregistered-assignment-target");
                    return CEmitError.UnsupportedConstruct;
                }
                if (asgn.fields.len == 0) return 0;
                if (asgn.fields.len == 1) {
                    // Single field — no cross-field read is possible; the
                    // direct store is the snapshot form.
                    const f = asgn.fields[0];
                    try self.write(indent);
                    try self.emitMemberPath(asgn.target, f.name);
                    try self.write(" = ");
                    try self.writeExpr(f.expression_str orelse f.type);
                    try self.write(";\n");
                } else {
                    const ind2 = try std.fmt.allocPrint(self.allocator, "{s}    ", .{indent});
                    defer self.allocator.free(ind2);
                    try self.writeFmt("{s}{{\n", .{indent});
                    self.checkCatalogName("cap_prefix", "__koru_cap_");
                    self.checkCatalogName("snap_name", "__koru_snap");
                    try self.writeFmt("{s}struct __koru_cap_{s} __koru_snap = {s};\n", .{ ind2, asgn.target, asgn.target });
                    for (asgn.fields) |f| {
                        try self.write(ind2);
                        try self.emitMemberPath("__koru_snap", f.name);
                        try self.write(" = ");
                        try self.writeExpr(f.expression_str orelse f.type);
                        try self.write(";\n");
                    }
                    try self.writeFmt("{s}{s} = __koru_snap;\n{s}}}\n", .{ ind2, asgn.target, indent });
                }
            },
            .terminal => {},
            .branch_constructor => |*bc| {
                if (ctx != .in_impl) {
                    std.debug.print("error[KORU047]: C lane: a produce value in a top-level flow has nowhere to land\n", .{});
                    return CEmitError.UnsupportedConstruct;
                }
                try self.emitProduce(bc, indent);
            },
            .expression => |expr| {
                try self.write(indent);
                if (ctx == .in_impl) try self.write("return ");
                try self.writeExpr(expr);
                try self.write(";\n");
            },
            else => {
                std.debug.print("error[KORU047]: C lane: node kind `{s}` is outside the first fragment\n", .{@tagName(node)});
                return CEmitError.UnsupportedConstruct;
            },
        }
        return 0;
    }

    /// `<owner>.<member>` where the field may carry an index chain —
    /// `arr[i]`, `g[a][b]` (captured-on-array writes): the base member
    /// name mangles, each bracket's expression lowers through writeExpr.
    fn emitMemberPath(self: *Emitter, owner: []const u8, field: []const u8) CEmitError!void {
        const brk = std.mem.indexOfScalar(u8, field, '[') orelse field.len;
        try self.writeFmt("{s}.{s}", .{ owner, codegen_utils.cMemberName(self.allocator, field[0..brk]) });
        var rest = field[brk..];
        while (rest.len > 0) {
            if (rest[0] != '[') {
                std.debug.print("error[KORU047]: C lane: indexed field `{s}` — trailing text after index chain\n", .{field});
                return CEmitError.UnsupportedConstruct;
            }
            const close = std.mem.indexOfScalar(u8, rest, ']') orelse {
                std.debug.print("error[KORU047]: C lane: indexed field `{s}` — unclosed index\n", .{field});
                return CEmitError.UnsupportedConstruct;
            };
            try self.write("[");
            try self.writeExpr(rest[1..close]);
            try self.write("]");
            rest = rest[close + 1 ..];
        }
    }

    /// A `->`/produce: `return <value>;` — bare value only; named or fielded
    /// branch payloads are the tagged-result lane.
    /// `{ f: v, ... }` against a known C struct → `(<ct>){ .f = v, ... }`.
    /// Field names and values come through the shared struct_literal
    /// projector (the pun law's ONE parser); values lower via writeExpr.
    fn emitRecordLiteral(self: *Emitter, text: []const u8, ct: []const u8) CEmitError!void {
        const fields = struct_literal.parseFields(self.allocator, text) catch |err| {
            std.debug.print("error[KORU047]: C lane: record literal `{s}` — {s}\n", .{ text, struct_literal.describeError(err) });
            return CEmitError.UnsupportedConstruct;
        };
        defer self.allocator.free(fields);
        try self.writeFmt("({s}){{ ", .{ct});
        for (fields, 0..) |f, fi| {
            if (fi > 0) try self.write(", ");
            try self.writeFmt(".{s} = ", .{codegen_utils.cMemberName(self.allocator, f.name)});
            try self.writeExpr(f.value);
        }
        try self.write(" }");
    }

    /// The C struct a `{ f: v }` produce must spell: `-> { f: T }` resolves
    /// to `struct __koru_rec_<tag>`, `-> Proto` to the proto's own
    /// `struct <Name>` — both through the ordinary type resolver.
    fn recordProduceCType(self: *Emitter, ev: *const ast.EventDecl, pv: []const u8) CEmitError![]const u8 {
        const rt = ev.return_type orelse {
            std.debug.print("error[KORU047]: C lane: record produce `{s}` against a void `->`\n", .{pv});
            return CEmitError.UnsupportedConstruct;
        };
        const ct = self.cTypeOfResolved(std.mem.trim(u8, rt, " \t\n\r")) orelse {
            std.debug.print("error[KORU047]: C lane: record produce `{s}` against return `{s}` — no C type in the first fragment\n", .{ pv, rt });
            return CEmitError.UnsupportedConstruct;
        };
        if (!std.mem.startsWith(u8, ct, "struct ")) {
            std.debug.print("error[KORU047]: C lane: record produce `{s}` against return `{s}` — `{s}` is not a record type\n", .{ pv, rt, ct });
            return CEmitError.UnsupportedConstruct;
        }
        return ct;
    }

    /// `return <pv>;` — a `{ f: v, ... }` produce against a record return
    /// lowers to a compound literal of the declared struct; anything else
    /// emits verbatim through writeExpr.
    fn emitReturnExpr(self: *Emitter, pv: []const u8) CEmitError!void {
        const t = std.mem.trim(u8, pv, " \t\n\r");
        if (t.len > 1 and t[0] == '{' and t[t.len - 1] == '}') {
            const ev = self.cur_event orelse {
                std.debug.print("error[KORU047]: C lane: record produce `{s}` outside an event\n", .{t});
                return CEmitError.UnsupportedConstruct;
            };
            const ct = try self.recordProduceCType(ev, t);
            try self.write("return ");
            try self.emitRecordLiteral(t, ct);
            try self.write(";\n");
            return;
        }
        try self.write("return ");
        try self.writeExpr(t);
        try self.write(";\n");
    }

    fn emitProduce(self: *Emitter, bc: *const ast.BranchConstructor, indent: []const u8) CEmitError!void {
        try self.write(indent);
        if (!bc.is_bare_return and bc.branch_name.len != 0) {
            const ev = self.cur_event orelse {
                std.debug.print("error[KORU047]: C lane: named branch `=> {s}` outside an event body\n", .{bc.branch_name});
                return CEmitError.UnsupportedConstruct;
            };
            const bname = try mangle(self.allocator, ev.path);
            defer self.allocator.free(bname);
            const b = findBranch(ev, bc.branch_name) orelse {
                std.debug.print("error[KORU047]: C lane: `=> {s}` names no declared branch\n", .{bc.branch_name});
                return CEmitError.UnsupportedConstruct;
            };
            const tagc = codegen_utils.cResTagConst(self.allocator, bname, b.name);
            const pmem = codegen_utils.cPayloadMember(self.allocator, b.name);
            if (bc.fields.len != 0) {
                try self.writeFmt("return (struct {s}_res){{ .tag = {s}, .{s} = (struct {s}_{s}_t){{ ", .{ bname, tagc, pmem, bname, codegen_utils.cMemberName(self.allocator, b.name) });
                for (bc.fields, 0..) |f, fi| {
                    const fexpr = f.expression_str orelse {
                        std.debug.print("error[KORU047]: C lane: `=> {s}` field {s} carries no expression text\n", .{ bc.branch_name, f.name });
                        return CEmitError.UnsupportedConstruct;
                    };
                    if (fi > 0) try self.write(", ");
                    try self.writeFmt(".{s} = ", .{codegen_utils.cMemberName(self.allocator, f.name)});
                    try self.writeExpr(fexpr);
                }
                try self.write(" } };\n");
                return;
            }
            const fs = b.payload.fields;
            if (bc.plain_value) |pv| {
                if (b.payload.is_wildcard) {
                    std.debug.print("error[KORU047]: C lane: `=> {s}` produces a value a `| {s} *` wildcard cannot carry — the payload has no declared shape\n", .{ bc.branch_name, bc.branch_name });
                    return CEmitError.UnsupportedConstruct;
                }
                if (fs.len != 1 or !std.mem.eql(u8, fs[0].name, "__type_ref")) {
                    std.debug.print("error[KORU047]: C lane: `=> {s}` scalar produce against a non-scalar payload\n", .{bc.branch_name});
                    return CEmitError.UnsupportedConstruct;
                }
                try self.writeFmt("return (struct {s}_res){{ .tag = {s}, .{s} = ", .{ bname, tagc, pmem });
                try self.writeExpr(pv);
                try self.write(" };\n");
            } else {
                if (fs.len != 0) {
                    std.debug.print("error[KORU047]: C lane: `=> {s}` produces no value for a payload-carrying branch\n", .{bc.branch_name});
                    return CEmitError.UnsupportedConstruct;
                }
                try self.writeFmt("return {s};\n", .{codegen_utils.cResCtorEmpty(self.allocator, bname, b.name)});
            }
            return;
        }
        if (bc.fields.len != 0) {
            std.debug.print("error[KORU047]: C lane: fielded produce — outside the first fragment\n", .{});
            return CEmitError.UnsupportedConstruct;
        }
        if (bc.plain_value) |pv| {
            try self.emitReturnExpr(pv);
        } else {
            try self.write("return;\n");
        }
    }

    /// Target-authored statement text (`preamble_code`, `inline_body`,
    /// legacy `inline_code`): verbatim lines, re-indented. The |c transform
    /// authored C here — the js emitter's rendered-statement case.
    fn emitVerbatimLines(self: *Emitter, text: []const u8, indent: []const u8) CEmitError!void {
        var it = std.mem.splitScalar(u8, text, '\n');
        while (it.next()) |line| {
            const t = std.mem.trim(u8, line, " \t\r");
            if (t.len == 0) continue;
            for ([_][]const u8{ "__koru_continue_", "__koru_inline_", "__koru_c_refuse_" }) |pfx| {
                if (std.mem.indexOf(u8, t, pfx)) |mi| {
                    var j = mi + pfx.len;
                    while (j < t.len and (std.ascii.isAlphanumeric(t[j]) or t[j] == '_')) j += 1;
                    std.debug.print("error[KORU047]: C lane: `{s}` is outside the first fragment\n", .{t[mi..j]});
                    return CEmitError.UnsupportedConstruct;
                }
            }
            try self.write(indent);
            try self.writeHostText(t);
            try self.write("\n");
        }
    }

    /// A stmt-scope preamble declares `struct __koru_cap_<cell> { … }
    /// <cell> = { … };` — register each cell name so a later `.assignment`
    /// node can prove its target was minted rather than emitting a store
    /// into an undeclared struct.
    fn emitCapPreamble(self: *Emitter, text: []const u8, indent: []const u8) CEmitError!void {
        var it = std.mem.splitScalar(u8, text, '\n');
        while (it.next()) |line| {
            if (std.mem.indexOf(u8, line, "struct __koru_cap_")) |si| {
                const rest = line[si + "struct __koru_cap_".len ..];
                var end: usize = 0;
                while (end < rest.len and (std.ascii.isAlphanumeric(rest[end]) or rest[end] == '_')) end += 1;
                try self.cap_cells.put(rest[0..end], {});
            }
        }
        try self.emitVerbatimLines(text, indent);
    }

    /// Invocation → call statement. Args map to the event's declared input
    /// fields by name (positional args fill in declared order); the emitted
    /// call is `name((struct <name>_in){ .f = v, ... })`.
    fn emitCall(self: *Emitter, inv: *const ast.Invocation, indent: []const u8) CEmitError!void {
        const key = try pathKey(self.allocator, inv.path);
        defer self.allocator.free(key);
        const event = self.events.get(key) orelse {
            std.debug.print("error[KORU047]: C lane: cannot resolve invocation {s} to an event\n", .{key});
            return CEmitError.UnresolvedEvent;
        };
        const name = try mangle(self.allocator, inv.path);
        defer self.allocator.free(name);

        try self.write(indent);
        if (inv.return_destructure.len != 0) {
            std.debug.print("error[KORU047]: C lane: {s} destructure at the bind — outside the first fragment\n", .{key});
            self.checkCatalogFragment("destructure");
            return CEmitError.UnsupportedConstruct;
        }
        if (inv.return_binding) |bind| {
            const rt = event.return_type orelse {
                std.debug.print("error[KORU047]: C lane: {s} bound to `{s}` but the event has no `-> T` return\n", .{ key, bind });
                return CEmitError.UnsupportedConstruct;
            };
            const ct = self.cTypeOfResolved(rt) orelse {
                std.debug.print("error[KORU047]: C lane: {s} returns {s} — no C type in the first fragment\n", .{ key, rt });
                return CEmitError.UnsupportedConstruct;
            };
            try self.int_bindings.put(bind, ct);
            try self.writeFmt("{s} const {s} = ", .{ ct, bind });
        }
        if (eventIsStub(event)) {
            // Reached but transform-annotated — a call that should never
            // exist post-transform; emit the loud stub call.
            try self.writeFmt("{s}();\n", .{name});
            return;
        }
        try self.emitCallExpr(inv, event);
        try self.write(";\n");
    }

    /// `name((struct <name>_in){ .f = v, … })` — the call itself, no
    /// statement machinery: the tagged-dispatch path embeds it in the
    /// `__koru_res_N` declaration.
    fn emitCallExpr(self: *Emitter, inv: *const ast.Invocation, event: *const ast.EventDecl) CEmitError!void {
        const name = try mangle(self.allocator, inv.path);
        defer self.allocator.free(name);
        try self.write(name);
        try self.write("(");
        if (event.input.fields.len > 0) {
            try self.writeFmt("(struct {s}_in){{ ", .{name});
            for (event.input.fields, 0..) |f, fi| {
                if (fi > 0) try self.write(", ");
                try self.writeFmt(".{s} = ", .{codegen_utils.cMemberName(self.allocator, f.name)});
                try self.emitArgForField(inv, f, fi);
            }
            try self.write(" }");
        }
        try self.write(")");
    }

    /// A call site carrying `| branch` arms: bind the tagged result and
    /// switch-dispatch each arm — the `switch (result)` the zig lane emits
    /// around `.{ .row = …, .full = … }`.
    ///
    /// Fragment: terminal arms only, every arm naming a declared branch, no
    /// `when` guards, no `|*` catchall — each is a named refusal, never a
    /// silent skip. Unnamed terminal continuations are the post-call sequel
    /// and emit after the switch.
    fn emitTaggedCall(
        self: *Emitter,
        site: *const ast.Continuation,
        inv: *const ast.Invocation,
        indent: []const u8,
        ctx: SiteCtx,
    ) CEmitError!void {
        const key = try pathKey(self.allocator, inv.path);
        defer self.allocator.free(key);
        const event = self.events.get(key) orelse {
            std.debug.print("error[KORU047]: C lane: cannot resolve invocation {s} to an event\n", .{key});
            return CEmitError.UnresolvedEvent;
        };
        const name = try mangle(self.allocator, inv.path);
        defer self.allocator.free(name);

        if (eventIsStub(event)) {
            std.debug.print("error[KORU047]: C lane: {s} — tagged call against a transform/comptime tor\n", .{key});
            return CEmitError.UnsupportedConstruct;
        }
        if (inv.inline_body != null) {
            std.debug.print("error[KORU047]: C lane: {s} — tagged call under a transform-rendered inline body is outside the first fragment\n", .{key});
            return CEmitError.UnsupportedConstruct;
        }
        if (inv.return_destructure.len != 0) {
            std.debug.print("error[KORU047]: C lane: {s} destructure at the tagged bind — outside the first fragment\n", .{key});
self.checkCatalogFragment("destructure");
            return CEmitError.UnsupportedConstruct;
        }
        for (event.branches) |*b| {
            if (b.kind == .effect) {
                std.debug.print("error[KORU047]: C lane: {s} declares effect branch `! {s}` — handler dispatch is outside the first fragment\n", .{ key, b.name });
                return CEmitError.UnsupportedConstruct;
            }
        }
        for (site.continuations) |*c| {
            if (c.kind != .terminal) {
                std.debug.print("error[KORU047]: C lane: {s} — `!` handler arm under a tagged call is outside the first fragment\n", .{key});
                return CEmitError.UnsupportedConstruct;
            }
            if (c.is_catchall) {
                std.debug.print("error[KORU047]: C lane: {s} — `|*` catchall arm is outside the first fragment\n", .{key});
                return CEmitError.UnsupportedConstruct;
            }
            if (c.branch.len != 0) {
                if (c.condition != null) {
                    std.debug.print("error[KORU047]: C lane: {s} arm `| {s} when` — guarded dispatch is outside the first fragment\n", .{ key, c.branch });
                    return CEmitError.UnsupportedConstruct;
                }
                if (findBranch(event, c.branch) == null) {
                    std.debug.print("error[KORU047]: C lane: {s} arm `| {s}` names no declared branch\n", .{ key, c.branch });
                    return CEmitError.UnsupportedConstruct;
                }
            }
        }

        self.res_counter += 1;
        const rn = if (inv.return_binding) |bind|
            bind
        else
            try std.fmt.allocPrint(self.allocator, "__koru_res_{d}", .{self.res_counter});

        try self.write(indent);
        try self.writeFmt("struct {s}_res {s} = ", .{ name, rn });
        try self.emitCallExpr(inv, event);
        try self.write(";\n");
        try self.writeFmt("{s}switch ({s}.tag) {{\n", .{ indent, rn });
        const inner = try std.fmt.allocPrint(self.allocator, "{s}    ", .{indent});
        defer self.allocator.free(inner);
        for (site.continuations) |*cont| {
            if (cont.kind != .terminal or cont.branch.len == 0) continue;
            try self.writeFmt("{s}case {s}: {{\n", .{ indent, codegen_utils.cResTagConst(self.allocator, name, cont.branch) });
            try self.emitBranchBinding(event, cont, rn, inner);
            const consumed = try self.emitSiteNode(cont, inner, ctx);
            try self.emitUnconsumedContinuations(cont.continuations, consumed, inner, ctx);
            try self.writeFmt("{s}break; }}\n", .{inner});
        }
        try self.writeFmt("{s}default: break;\n", .{indent});
        try self.writeFmt("{s}}}\n", .{indent});
        // The post-call sequel: unnamed terminal continuations always run.
        for (site.continuations) |*cont| {
            if (cont.kind != .terminal or cont.branch.len != 0) continue;
            try self.emitSite(cont, indent, ctx);
        }
    }

    /// `const <ct> <bind> = <rn>.<member>;` — the arm's payload bind, or the
    /// shape-destructure `| item {{ hp }}` spelled as one field copy each.
    fn emitBranchBinding(
        self: *Emitter,
        event: *const ast.EventDecl,
        cont: *const ast.Continuation,
        rn: []const u8,
        indent: []const u8,
    ) CEmitError!void {
        const ename = try mangle(self.allocator, event.path);
        defer self.allocator.free(ename);
        if (cont.binding) |bind| {
            if (!std.mem.eql(u8, bind, "_")) {
                const b = findBranch(event, cont.branch).?;
                // An empty-payload arm may still carry a synthesized binding
                // (auto-discharge names panic arms `_auto_N`); zig binds it to
                // nothing, C emits nothing.
                if ((try self.branchPayloadCType(ename, "", b))) |pt| {
                    try self.int_bindings.put(bind, pt);
                    try self.writeFmt("{s}{s} const {s} = {s}.{s};\n", .{ indent, pt, bind, rn, codegen_utils.cPayloadMember(self.allocator, cont.branch) });
                }
            }
        }
        for (cont.destructure) |df| {
            if (std.mem.eql(u8, df.name, "_")) continue;
            if (df.sub.len != 0) {
                std.debug.print("error[KORU047]: C lane: nested destructure at `| {s}` — outside the first fragment\n", .{cont.branch});
self.checkCatalogFragment("destructure");
                return CEmitError.UnsupportedConstruct;
            }
            const b = findBranch(event, cont.branch).?;
            var ftype: ?[]const u8 = null;
            for (b.payload.fields) |pf| {
                if (std.mem.eql(u8, pf.name, df.name)) ftype = self.cTypeOfResolved(pf.type);
            }
            const ct = ftype orelse {
                std.debug.print("error[KORU047]: C lane: `| {s} {{ {s} }}` names no payload field with a C type\n", .{ cont.branch, df.name });
                return CEmitError.UnsupportedConstruct;
            };
            try self.int_bindings.put(df.name, ct);
            try self.writeFmt("{s}{s} const {s} = {s}.{s}.{s};\n", .{ indent, ct, df.name, rn, codegen_utils.cPayloadMember(self.allocator, cont.branch), codegen_utils.cMemberName(self.allocator, df.name) });
        }
    }

    /// The value for declared field `f` (ordinal `fi`) at a call site: the
    /// arg named `f`, else the positional arg at the same ordinal, else the
    /// field default, else refuse — a missing argument is a shape error the
    /// C lane does not guess on. A `&[_]T{…}` / `[_]T{…}` slice literal
    /// against a `[]T` field emits the fat-cell compound literal — arg
    /// position is where the element type is declared, so no inference is
    /// needed: `(struct __koru_slice_<tag>){ .ptr = (<elem>[]){…}, .len = n }`.
    fn emitArgForField(self: *Emitter, inv: *const ast.Invocation, f: ast.Field, fi: usize) CEmitError!void {
        // A comptime-hole field takes its hole, not the arg text — the
        // source expression is comptime cargo the C lane never evaluates.
        if (self.cTypeOfResolved(f.type)) |ct| {
            if (std.mem.startsWith(u8, ct, "struct __koru_comptime_")) {
                try self.write("{0}");
                return;
            }
        }
        var positional: usize = 0;
        for (inv.args) |*a| {
            if (a.name.len == 0) {
                if (positional == fi) {
                    try self.emitArgValue(a.value, f);
                    return;
                }
                positional += 1;
            } else if (std.mem.eql(u8, a.name, f.name)) {
                try self.emitArgValue(a.value, f);
                return;
            }
        }
        if (f.default) |d| {
            try self.emitArgValue(d, f);
            return;
        }
        std.debug.print("error[KORU047]: C lane: call supplies no value for field {s}\n", .{f.name});
        return CEmitError.UnresolvedEvent;
    }

    /// One arg's value against declared field `f`: slice-literal lowering
    /// when the field spells a `[]T` cell, else ordinary expression text.
    fn emitArgValue(self: *Emitter, value: []const u8, f: ast.Field) CEmitError!void {
        // `[N]T` field — `.arr = v` is not a C initializer (arrays are
        // not assignable). A `[N]T{…}` literal lowers its elements; any
        // other value expands by the declared dims: `{ v[0], v[1], … }`.
        if (codegen_utils.cArrayType(f.type, catalogCTypeResolver, self)) |at| {
            try self.write("{ ");
            const vt = std.mem.trim(u8, value, " \t\n");
            if (std.mem.indexOfScalar(u8, vt, '{')) |open| {
                if (vt.len > 1 and vt[vt.len - 1] == '}') {
                    try self.emitArrayInitText(vt[open + 1 .. vt.len - 1]);
                    try self.write(" }");
                    return;
                }
            }
            try self.emitArrayElems(value, at.dims);
            try self.write(" }");
            return;
        }
        const ct = self.cTypeOfResolved(f.type) orelse return self.writeExpr(value);
        // `{ f: v, ... }` into a record-typed field → the compound literal
        // `(<ct>){ .f = v }`. Payload, `_in`, `_ret` and proto structs all
        // spell `struct <name>`; `__koru_` cells take their own arms below.
        // `__koru_rec_<tag>` is a minted record cell — it takes the same
        // compound literal as a nominal struct; only the other `__koru_`
        // cells (slice, comptime holes) keep their own arms below.
        if (std.mem.startsWith(u8, ct, "struct ") and
            (!std.mem.startsWith(u8, ct, "struct __koru_") or
                std.mem.startsWith(u8, ct, "struct __koru_rec_")))
        {
            const vt = std.mem.trim(u8, value, " \t\n\r");
            if (vt.len > 1 and vt[0] == '{' and vt[vt.len - 1] == '}') {
                return self.emitRecordLiteral(vt, ct);
            }
        }
        if (!std.mem.startsWith(u8, ct, "struct __koru_slice_")) return self.writeExpr(value);
        // Parse `&[_]T{ e0, e1, … }` / `[_]T{ … }` — the Koru array-literal
        // reference spellings. Anything else is an expression and stays one.
        var t = std.mem.trim(u8, value, " \t");
        if (std.mem.startsWith(u8, t, "&")) t = std.mem.trim(u8, t[1..], " \t");
        if (!std.mem.startsWith(u8, t, "[_]")) return self.writeExpr(value);
        t = std.mem.trim(u8, t[3..], " \t");
        const open = std.mem.indexOfScalar(u8, t, '{') orelse return self.writeExpr(value);
        if (t.len == 0 or t[t.len - 1] != '}') return self.writeExpr(value);
        const elem_ty = self.sliceMemberOf(ct) orelse return self.writeExpr(value);
        const elems_text = t[open + 1 .. t.len - 1];
        try self.writeFmt("(({s}){{ ", .{ct});
        if (std.mem.trim(u8, elems_text, " \t\n").len == 0) {
            try self.write(".ptr = 0, .len = 0 }})");
            return;
        }
        try self.writeFmt(".ptr = ({s}[]){{ ", .{elem_ty});
        var n: usize = 0;
        var rest = elems_text;
        while (true) {
            const comma = topLevelComma(rest) orelse rest.len;
            const piece = std.mem.trim(u8, rest[0..comma], " \t\n");
            if (piece.len == 0) break;
            if (n > 0) try self.write(", ");
            try self.writeExpr(piece);
            n += 1;
            if (comma == rest.len) break;
            rest = rest[comma + 1 ..];
        }
        try self.writeFmt(" }}, .len = {d} }})", .{n});
    }

    /// `{ e0, e1, … }` — a `[N]T{…}` literal's elements lowered one per
    /// brace slot; nested `.{…}` ranks recurse by dropping the `.`.
    fn emitArrayInitText(self: *Emitter, interior: []const u8) CEmitError!void {
        var rest = interior;
        var n: usize = 0;
        while (true) {
            var depth: usize = 0;
            var comma: usize = rest.len;
            for (rest, 0..) |ch, i| {
                switch (ch) {
                    '(', '[', '{' => depth += 1,
                    ')', ']', '}' => depth -= 1,
                    ',' => if (depth == 0) {
                        comma = i;
                        break;
                    },
                    else => {},
                }
            }
            const piece = std.mem.trim(u8, rest[0..comma], " \t\n");
            if (piece.len == 0) break;
            if (n > 0) try self.write(", ");
            const inner = if (std.mem.startsWith(u8, piece, ".{")) piece[1..] else piece;
            if (inner.len > 1 and inner[0] == '{' and inner[inner.len - 1] == '}') {
                try self.write("{ ");
                try self.emitArrayInitText(inner[1 .. inner.len - 1]);
                try self.write(" }");
            } else {
                try self.writeExpr(inner);
            }
            n += 1;
            if (comma == rest.len) break;
            rest = rest[comma + 1 ..];
        }
    }

    /// `{ v[0], v[1], … }` — a `[N]T` arg's braced init expanded by the
    /// declared dims, recursing through nested `[N][M]` ranks.
    fn emitArrayElems(self: *Emitter, value: []const u8, dims: []const u8) CEmitError!void {
        const close = std.mem.indexOfScalar(u8, dims, ']') orelse return CEmitError.UnsupportedConstruct;
        const n = std.fmt.parseInt(usize, dims[1..close], 10) catch return CEmitError.UnsupportedConstruct;
        const rest = dims[close + 1 ..];
        for (0..n) |i| {
            if (i > 0) try self.write(", ");
            const elem = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ value, i });
            defer self.allocator.free(elem);
            if (rest.len == 0) {
                try self.writeExpr(elem);
            } else {
                try self.write("{ ");
                try self.emitArrayElems(elem, rest);
                try self.write(" }");
            }
        }
    }

    /// `<slice-cell>` → its `ptr` member's pointee C type —
    /// `struct __koru_slice_<tag>`'s registered `<member>` spelling.
    fn sliceMemberOf(self: *Emitter, ct: []const u8) ?[]const u8 {
        const tag = ct["struct __koru_slice_".len..];
        return self.slice_decls.get(tag);
    }

    // -- flow emission ------------------------------------------------------

    fn emitFlow(self: *Emitter, flow: *const ast.Flow, flow_num: usize) CEmitError!void {
        // Flow preamble at FILE scope: `const|c`'s `static const`
        // declarations are module-scope values — inside the fn they would be
        // invisible to sibling flows. A `//@koru:stmt_scope` preamble is the
        // other kind: a dissolving transform's (~capture's) per-call locals
        // land at the head-call position INSIDE the fn, and the head call
        // itself is consumed — the zig lane's `preamble replaces the call`
        // (visitor_emitter.zig:3635). Only the dissolved continuations walk.
        const stmt_pre = if (flow.preamble_code) |pre| stripStmtScopeMarker(pre) else null;
        if (flow.preamble_code) |pre| {
            if (stmt_pre == null) try self.emitVerbatimLines(pre, "");
        }
        try self.writeFmt("static void koru_flow_{d}(void) {{\n", .{flow_num});
        try self.emitSplicedFlowBody(flow, .in_flow, stmt_pre);
        try self.write("}\n\n");
    }

    /// Top-level flows → flow functions + one main driving them in
    /// order. The oracle's enumeration; the walk's `writeDriver` answers
    /// the same question beside it during dual-answer.
    fn emitDriverFns(self: *Emitter, program: *const ast.Program) CEmitError!void {
        var flow_num: usize = 0;
        for (program.items) |*item| {
            if (item.* != .flow) continue;
            const f = &item.flow;
            if (f.impl_of != null) continue;
            if (!std.mem.eql(u8, f.module, program.main_module_name)) continue;
            var skip = false;
            for (f.annotations) |ann| {
                if (std.mem.eql(u8, ann, "declaration") or std.mem.eql(u8, ann, "norun")) skip = true;
            }
            if (skip) continue;
            if (f.body.node) |n| {
                if (n == .invocation) {
                    if (n.invocation.path.module_qualifier) |mq| {
                        if (std.mem.eql(u8, mq, "koru")) continue;
                    }
                }
            }
            try self.emitFlow(f, flow_num);
            flow_num += 1;
        }

        try self.write("int main(int argc, char **argv) {\n");
        try self.write("    __koru_argc = argc;\n    __koru_argv = argv;\n");
        for (0..flow_num) |i| {
            try self.writeFmt("    koru_flow_{d}();\n", .{i});
        }
        try self.write("    return 0;\n}\n");
    }

    /// The flow-body splice shared by top-level flows (.in_flow) and impl
    /// flows (.in_impl): a stmt-scope preamble emits cap text at the
    /// head-call position with the head call consumed; a non-file-scope
    /// inline body resolves its statements against continuations; else
    /// the body's site walks. File-scope preambles are the caller's
    /// business — emitFlow emits them verbatim at file scope; an impl's
    /// is still dropped (const|c has no impl author today).
    fn emitSplicedFlowBody(self: *Emitter, flow: *const ast.Flow, ctx: SiteCtx, stmt_pre: ?[]const u8) CEmitError!void {
        if (stmt_pre) |sp| {
            try self.emitCapPreamble(sp, "    ");
            try self.emitUnconsumedContinuations(flow.body.continuations, 0, "    ", ctx);
        } else if (flow.inline_body) |body| {
            if (stripFileScopeMarker(stripInlineStmtMarker(body)) == null) {
                var consumed: u64 = 0;
                try self.emitInlineBodyResolvingContinuations(stripInlineStmtMarker(body), flow.body.continuations, "    ", ctx, &consumed);
                try self.emitUnconsumedContinuations(flow.body.continuations, consumed, "    ", ctx);
            }
            // else: `//@koru:file_scope` — the decl text already landed via
            // emitFileScopeBodies; the empty shell keeps main()'s call list
            // uniform.
        } else {
            try self.emitSite(&flow.body, "    ", ctx);
        }
    }

    /// Render `render(args…)` into `out` beside the real output with the
    /// emitter's minting state restored on exit — the audit's oracle
    /// render: the text is comparable to what the walk emits, the
    /// `res_counter` advance is discarded, the buffer returns.
    fn renderIsolated(
        self: *Emitter,
        out: *std.ArrayList(u8),
        comptime render: anytype,
        args: anytype,
    ) CEmitError!void {
        const rc = self.res_counter;
        defer self.res_counter = rc;
        const saved = self.buf;
        self.buf = out;
        defer self.buf = saved;
        try @call(.auto, render, .{self} ++ args);
    }
};

/// Transform-rendered inline bodies arrive with a `//@koru:inline_stmt` flag
/// line; the flag is for the dispatch machinery, not for C output.
fn stripInlineStmtMarker(text: []const u8) []const u8 {
    const marker = "//@koru:inline_stmt\n";
    if (std.mem.startsWith(u8, text, marker)) return text[marker.len..];
    return text;
}

/// `//@koru:file_scope` — the declaration hoist flag a |c template mints
/// (const|c today): the rendered body is module-scope C, not a statement
/// inside a flow fn. Returns the body past the flag line, or null when the
/// flag is absent.
fn stripFileScopeMarker(text: []const u8) ?[]const u8 {
    const marker = "//@koru:file_scope\n";
    const t = std.mem.trimLeft(u8, text, " \t\r\n");
    if (std.mem.startsWith(u8, t, marker)) return t[marker.len..];
    return null;
}

/// `//@koru:stmt_scope` — the OTHER preamble scope: a dissolving transform
/// (~capture) whose preamble is a per-call local, emitted at the head-call
/// position inside the fn rather than at file scope, with the head call
/// itself consumed (the zig lane's `preamble replaces the call` rule,
/// visitor_emitter.zig:3635). Returns the text past the flag, or null.
fn stripStmtScopeMarker(text: []const u8) ?[]const u8 {
    const marker = "//@koru:stmt_scope\n";
    const t = std.mem.trimLeft(u8, text, " \t\r\n");
    if (std.mem.startsWith(u8, t, marker)) return t[marker.len..];
    return null;
}

// ---------------------------------------------------------------------------
// Host lines + top-level inline code
// ---------------------------------------------------------------------------

/// `// proto-terminal <Name>: <scalar>` markers are the terminal registry —
/// the same channel `TerminalRef` reads for the other hosts. Records the
/// names the typedef arm of `mintTerminal` will bind.
fn seedProtoTerminals(items: []const ast.Item, aliases: *std.StringHashMap([]const u8)) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .inline_code => |*ic| {
                var lines = std.mem.splitScalar(u8, ic.code, '\n');
                while (lines.next()) |line| {
                    const rest = std.mem.trim(u8, line, " \t\r");
                    const body = std.mem.trimLeft(u8, rest, "/");
                    const after = std.mem.trim(u8, body, " \t");
                    if (!std.mem.startsWith(u8, after, "proto-terminal ")) continue;
                    const spec = after["proto-terminal ".len..];
                    const colon = std.mem.indexOfScalar(u8, spec, ':') orelse continue;
                    const name = std.mem.trim(u8, spec[0..colon], " \t");
                    const scalar = std.mem.trim(u8, spec[colon + 1 ..], " \t");
                    if (name.len == 0 or scalar.len == 0) continue;
                    try aliases.put(name, scalar);
                }
            },
            .module_decl => |*m| try seedProtoTerminals(m.items, aliases),
            else => {},
        }
    }
}

/// One `std/proto` field: declared name + its Koru type text. The table
/// stays unflattened — a nested proto field keeps its proto type and
/// resolves to that proto's own `struct`, the nested shape the zig lane
/// emits.
pub const ProtoField = struct { name: []const u8, ktype: []const u8 };

/// The proto door's live form — `std/proto(Name) { f: t }` / a
/// `std/types:proto` decl arrives as a flow-head invocation of the module's
/// `default`/`proto` verb. Mirror of rings.leafgate's isProtoDoor.
fn isProtoDoorInv(inv: *const ast.Invocation) bool {
    if (inv.path.segments.len != 1) return false;
    const verb = inv.path.segments[0];
    if (!std.mem.eql(u8, verb, "proto") and !std.mem.eql(u8, verb, "default")) return false;
    const mq = inv.path.module_qualifier orelse return false;
    return std.mem.eql(u8, mq, "std.proto") or std.mem.eql(u8, mq, "std/proto") or
        std.mem.eql(u8, mq, "std.types") or std.mem.eql(u8, mq, "std/types");
}

/// `name: type` pairs from proto field text — the live decl's `source`
/// arg (newline-joined) and the erased `// proto Name: f: t, g: u` marker
/// (comma-joined) both tokenize the same way.
fn seedProtoFields(allocator: std.mem.Allocator, protos: *std.StringArrayHashMap([]const ProtoField), name: []const u8, text: []const u8) CEmitError!void {
    if (name.len == 0 or protos.contains(name)) return;
    var fields: std.ArrayList(ProtoField) = .empty;
    defer fields.deinit(allocator);
    var lines = std.mem.tokenizeAny(u8, text, "\n,");
    while (lines.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r,");
        if (line.len == 0) continue;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const fname = std.mem.trim(u8, line[0..colon], " \t");
        const ftype = std.mem.trim(u8, line[colon + 1 ..], " \t,");
        if (fname.len == 0 or ftype.len == 0) continue;
        try fields.append(allocator, .{ .name = try allocator.dupe(u8, fname), .ktype = try allocator.dupe(u8, ftype) });
    }
    try protos.put(try allocator.dupe(u8, name), try fields.toOwnedSlice(allocator));
}

/// Record the field table of every record proto in reach — the live
/// `std/proto(Name)` decl flow (its `source` arg text) or the erased
/// `// proto Name: f: t` marker inside transform-minted inline code.
fn seedProtoStructs(allocator: std.mem.Allocator, items: []const ast.Item, protos: *std.StringArrayHashMap([]const ProtoField)) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .flow => |*f| {
                if (f.body.node) |*n| {
                    if (n.* == .invocation and isProtoDoorInv(&n.invocation)) {
                        const inv = &n.invocation;
                        if (inv.args.len == 0) continue;
                        const a0 = inv.args[0];
                        const name = if (a0.had_explicit_label)
                            std.mem.trim(u8, std.mem.trimRight(u8, a0.name, "<:"), " \t")
                        else
                            std.mem.trim(u8, a0.value, " \t\"'");
                        for (inv.args) |a| {
                            if (a.source_value) |sv| {
                                try seedProtoFields(allocator, protos, name, sv.text);
                                break;
                            }
                        }
                    }
                }
            },
            .inline_code => |*ic| {
                var lines = std.mem.splitScalar(u8, ic.code, '\n');
                while (lines.next()) |raw| {
                    const line = std.mem.trimLeft(u8, raw, " \t");
                    const prefix = "// proto ";
                    if (!std.mem.startsWith(u8, line, prefix)) continue;
                    const spec = line[prefix.len..];
                    const colon = std.mem.indexOfScalar(u8, spec, ':') orelse continue;
                    const name = std.mem.trim(u8, spec[0..colon], " \t");
                    try seedProtoFields(allocator, protos, name, spec[colon + 1 ..]);
                }
            },
            .module_decl => |*m| try seedProtoStructs(allocator, m.items, protos),
            else => {},
        }
    }
}

/// The canonical `f:t` signature of a `{ f: T, g: U }` record text —
/// the `struct __koru_rec_<tag>` tag's preimage. Shape-identical records
/// canonicalize to one tag, the same struct.
fn recordTagOf(allocator: std.mem.Allocator, t: []const u8) ?[]const u8 {
    const rfields = struct_literal.parseFields(allocator, t) catch return null;
    defer allocator.free(rfields);
    var sig: std.ArrayList(u8) = .empty;
    defer sig.deinit(allocator);
    for (rfields, 0..) |f, fi| {
        if (fi > 0) sig.append(allocator, ',') catch return null;
        sig.appendSlice(allocator, f.name) catch return null;
        sig.append(allocator, ':') catch return null;
        sig.appendSlice(allocator, f.value) catch return null;
    }
    return mangleOpaqueName(allocator, sig.items);
}

const CellKind = enum { proto, record };

/// `struct <Name>` protos and `struct __koru_rec_<tag>` records, emitted
/// member-complete: a struct whose field names another cell waits for the
/// member's def (a `struct B` member is ill-formed while B is incomplete).
/// A cell that never resolves — an unresolvable field or a value-cycle —
/// stays unminted; every type position naming it refuses upstream.
fn emitCellStructDefs(em: *Emitter) CEmitError!void {
    var emitted = std.StringHashMap(void).init(em.allocator);
    defer emitted.deinit();
    var in_progress = std.StringHashMap(void).init(em.allocator);
    defer in_progress.deinit();
    var pit = em.protos.iterator();
    while (pit.next()) |e| try emitCellDef(em, .proto, e.key_ptr.*, &emitted, &in_progress);
    var rit = em.record_decls.iterator();
    while (rit.next()) |e| try emitCellDef(em, .record, e.key_ptr.*, &emitted, &in_progress);
}

fn emitCellDef(em: *Emitter, kind: CellKind, key: []const u8, emitted: *std.StringHashMap(void), in_progress: *std.StringHashMap(void)) CEmitError!void {
    const sname = switch (kind) {
        .proto => try std.fmt.allocPrint(em.allocator, "struct {s}", .{key}),
        .record => try std.fmt.allocPrint(em.allocator, "struct __koru_rec_{s}", .{key}),
    };
    if (emitted.contains(sname) or in_progress.contains(sname)) return;
    const fields = switch (kind) {
        .proto => em.protos.get(key) orelse return,
        .record => em.record_decls.get(key) orelse return,
    };
    try in_progress.put(sname, {});
    defer _ = in_progress.remove(sname);
    // Member cells first: a field whose type is a proto or a record needs
    // that struct's def above this one.
    for (fields) |f| {
        const ft = std.mem.trim(u8, f.ktype, " \t");
        if (em.protos.contains(ft)) {
            try emitCellDef(em, .proto, ft, emitted, in_progress);
        } else if (ft.len > 1 and ft[0] == '{' and struct_literal.isKoruStructLiteral(ft)) {
            const rtag = recordTagOf(em.allocator, ft) orelse return;
            if (em.record_decls.contains(rtag)) try emitCellDef(em, .record, rtag, emitted, in_progress);
        }
    }
    // A member that never minted — unresolvable or a value-cycle — blocks
    // this struct as well; its own uses refuse through cTypeOfResolved.
    for (fields) |f| {
        const ft = std.mem.trim(u8, f.ktype, " \t");
        if (em.protos.contains(ft)) {
            const m = try std.fmt.allocPrint(em.allocator, "struct {s}", .{ft});
            if (!emitted.contains(m)) return;
        } else if (ft.len > 1 and ft[0] == '{' and struct_literal.isKoruStructLiteral(ft)) {
            const rtag = recordTagOf(em.allocator, ft) orelse return;
            if (em.record_decls.contains(rtag)) {
                const m = try std.fmt.allocPrint(em.allocator, "struct __koru_rec_{s}", .{rtag});
                if (!emitted.contains(m)) return;
            }
        }
    }
    var ctypes: std.ArrayList([]const u8) = .empty;
    defer ctypes.deinit(em.allocator);
    for (fields) |f| {
        const ct = em.cTypeOfResolved(f.ktype) orelse return;
        try ctypes.append(em.allocator, ct);
    }
    try em.writeFmt("{s} {{\n", .{sname});
    if (fields.len == 0) try em.write("    char __koru_empty;\n");
    for (fields, ctypes.items) |f, ct| {
        try em.writeFmt("    {s} {s};\n", .{ ct, codegen_utils.cMemberName(em.allocator, f.name) });
    }
    try em.write("};\n");
    try emitted.put(sname, {});
}

fn emitCHostLines(em: *Emitter, items: []const ast.Item) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .host_line => |*line| {
                const host = file_types.hostLangOfFile(line.location.file) orelse continue;
                if (!std.mem.eql(u8, host, C_TARGET)) continue;
                try em.write(line.content);
                try em.write("\n");
            },
            .module_decl => |*m| try emitCHostLines(em, m.items),
            else => {},
        }
    }
}

/// `//@koru:file_scope` bodies land here, in source order, before every
/// flow fn and event decl that could reference them. `const|c` is the only
/// minter; an empty shell remains in the flow fns so main()'s call list
/// stays uniform.
fn emitFileScopeBodies(em: *Emitter, items: []const ast.Item) CEmitError!void {
    for (items) |*item| {
        if (item.* != .flow) continue;
        const f = &item.flow;
        if (f.inline_body) |body| {
            const hoisted = stripFileScopeMarker(stripInlineStmtMarker(body)) orelse continue;
            try em.emitVerbatimLines(hoisted, "");
            try em.write("\n");
        }
    }
}

fn emitTopLevelInlineCode(em: *Emitter, items: []const ast.Item) CEmitError!void {
    for (items) |*item| {
        switch (item.*) {
            .inline_code => |*ic| {
                try em.write(ic.code);
                try em.write("\n");
            },
            .module_decl => |*m| try emitTopLevelInlineCode(em, m.items),
            else => {},
        }
    }
}

// ---------------------------------------------------------------------------
// The zig-text wall — refuse-not-paste, C twin of validateNoZigInJs/Cs
// ---------------------------------------------------------------------------

const ZIG_TOKENS = [_][]const u8{
    "@import",        "@as",           "@intCast",  "@floatCast", "@ptrCast",
    "@bitCast",       "@panic",        "@compileError", "@embedFile",
    "std.debug.",     "std.mem.",      "std.fmt.",  "pub fn ",    "comptime ",
    ".{ .",           "orelse ",       "catch |",   "errdefer",
};

fn validateNoZigInC(em: *Emitter, buf: *const std.ArrayList(u8)) CEmitError!void {
    const text = buf.items;
    var i: usize = 0;
    var in_str: ?u8 = null;
    var in_line_comment = false;
    var in_block_comment = false;
    var line: usize = 1;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == '\n') {
            line += 1;
            in_line_comment = false;
            continue;
        }
        if (in_str) |q| {
            if (c == '\\' and i + 1 < text.len) {
                i += 1;
            } else if (c == q) {
                in_str = null;
            }
            continue;
        }
        if (in_line_comment) continue;
        if (in_block_comment) {
            if (c == '*' and i + 1 < text.len and text[i + 1] == '/') in_block_comment = false;
            continue;
        }
        if (c == '"' or c == '\'') {
            in_str = c;
            continue;
        }
        if (c == '/' and i + 1 < text.len and text[i + 1] == '/') {
            in_line_comment = true;
            i += 1;
            continue;
        }
        if (c == '/' and i + 1 < text.len and text[i + 1] == '*') {
            in_block_comment = true;
            i += 1;
            continue;
        }
        // `@`-builtins are never valid C — any `@name` reaching output is
        // an un-lowered builtin. The fixed ZIG_TOKENS list can only name
        // builtins already seen; this covers the whole alphabet (and is
        // what catches a swallowed lowerKoruExpr refusal, e.g. the
        // ioLowerCExpr `catch text` fallback in print-arg text).
        if (c == '@' and i + 1 < text.len and codegen_utils.exprIdentChar(text[i + 1])) {
            var e = i + 1;
            while (e < text.len and codegen_utils.exprIdentChar(text[e])) e += 1;
            const name = text[i + 1 .. e];
            std.debug.print("error[KORU047]: C lane: un-lowered builtin `@{s}` reached output line {d}\n", .{ name, line });
            em.checkCatalogBuiltinRefusal(name);
            return CEmitError.ZigTextInOutput;
        }
        for (ZIG_TOKENS) |tok| {
            if (i + tok.len <= text.len and std.mem.eql(u8, text[i .. i + tok.len], tok)) {
                std.debug.print("error[KORU047]: C lane: un-lowered Zig text `{s}` reached output line {d}\n", .{ tok, line });
                return CEmitError.ZigTextInOutput;
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Entry
// ---------------------------------------------------------------------------

/// Emit C for the given program. Returns a heap-allocated string owned by the
/// caller's allocator.
/// Bare-identifier operand bound to a fat slice cell, or not.
fn isSliceBinding(int_bindings: *std.StringHashMap([]const u8), operand: []const u8) bool {
    if (operand.len == 0) return false;
    for (operand) |ch| {
        if (!codegen_utils.exprIdentChar(ch)) return false;
    }
    const ct = int_bindings.get(operand) orelse return false;
    return std.mem.startsWith(u8, ct, "struct __koru_slice_");
}

/// `name(` at `text[i]`, not preceded by an identifier char — the
/// position just past the `(`.
fn matchCallOpen(text: []const u8, i: usize, name: []const u8) ?usize {
    if (!std.mem.startsWith(u8, text[i..], name)) return null;
    if (text[i + name.len] != '(') return null;
    if (i > 0 and codegen_utils.exprIdentChar(text[i - 1])) return null;
    return i + name.len + 1;
}

/// Matching `)` index for `text[open] == '('`, or null unbalanced.
fn matchParenEnd(text: []const u8, open: usize) ?usize {
    var depth: usize = 0;
    var quote: ?u8 = null;
    var j = open;
    while (j < text.len) : (j += 1) {
        const c = text[j];
        if (quote) |q| {
            if (c == q) quote = null;
            continue;
        }
        if (c == '"' or c == '\'') {
            quote = c;
            continue;
        }
        if (c == '(') depth += 1;
        if (c == ')') {
            depth -= 1;
            if (depth == 0) return j;
        }
    }
    return null;
}

/// First `,` at paren depth 0 — the `__koru_idx` operand/index split.
fn topLevelComma(text: []const u8) ?usize {
    var depth: usize = 0;
    for (text, 0..) |c, j| {
        if (c == '(' or c == '[' or c == '{') depth += 1;
        if (c == ')' or c == ']' or c == '}') depth -= 1;
        if (c == ',' and depth == 0) return j;
    }
    return null;
}

/// `__koru_len(x)`/`__koru_idx(x, i)` spell a type question the lowerer
/// cannot answer — `.len`/`[i]` are rewritten at transform time, before
/// the binding registry exists (io placeholders, `{{ }}` text, `|c`
/// bodies all reach it verbatim). This pass runs where the registry
/// DOES exist: a bare-identifier operand bound to a fat cell emits its
/// own member — `(x).len`, `(x).ptr[i]` — and everything else keeps the
/// strlen getter / plain index. A member or call operand the registry
/// cannot see stays on the thin default: a slice hiding behind
/// `a.b[i]` is the same honest oracle refusal it was before slices.
fn rewriteSliceAccessors(
    out: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    text: []const u8,
    int_bindings: *std.StringHashMap([]const u8),
) !void {
    var i: usize = 0;
    var quote: ?u8 = null;
    while (i < text.len) {
        const c = text[i];
        if (quote) |q| {
            try out.append(allocator, c);
            if (c == '\\' and i + 1 < text.len) {
                try out.append(allocator, text[i + 1]);
                i += 2;
                continue;
            }
            if (c == q) quote = null;
            i += 1;
            continue;
        }
        if (c == '"' or c == '\'') {
            quote = c;
            try out.append(allocator, c);
            i += 1;
            continue;
        }
        if (matchCallOpen(text, i, "__koru_len")) |body_start| {
            const call_end = matchParenEnd(text, body_start - 1) orelse {
                try out.append(allocator, c);
                i += 1;
                continue;
            };
            const operand = std.mem.trim(u8, text[body_start..call_end], " \t\n");
            if (isSliceBinding(int_bindings, operand)) {
                try out.append(allocator, '(');
            } else {
                try out.appendSlice(allocator, "__koru_len_str(");
            }
            try rewriteSliceAccessors(out, allocator, operand, int_bindings);
            try out.appendSlice(allocator, if (isSliceBinding(int_bindings, operand)) ").len" else ")");
            i = call_end + 1;
            continue;
        }
        if (matchCallOpen(text, i, "__koru_idx")) |body_start| {
            const call_end = matchParenEnd(text, body_start - 1) orelse {
                try out.append(allocator, c);
                i += 1;
                continue;
            };
            const body = text[body_start..call_end];
            const comma = topLevelComma(body) orelse {
                try out.appendSlice(allocator, text[i .. call_end + 1]);
                i = call_end + 1;
                continue;
            };
            const operand = std.mem.trim(u8, body[0..comma], " \t\n");
            const index = std.mem.trim(u8, body[comma + 1 ..], " \t\n");
            try out.append(allocator, '(');
            try rewriteSliceAccessors(out, allocator, operand, int_bindings);
            try out.appendSlice(allocator, if (isSliceBinding(int_bindings, operand)) ").ptr[" else ")[");
            try rewriteSliceAccessors(out, allocator, index, int_bindings);
            try out.append(allocator, ']');
            i = call_end + 1;
            continue;
        }
        try out.append(allocator, c);
        i += 1;
    }
}

/// One C-lane emission run's shared state — the indexes, binding tables,
/// and the Emitter the walk's passes write through. The pipeline's emit-c
/// chain threads the session across pass tors as an opaque usize handle;
/// `emit()` is the same five calls composed in one function.
pub const Session = struct {
    allocator: std.mem.Allocator,
    program: *const ast.Program,
    buf: std.ArrayList(u8) = .empty,
    events: EventIndex,
    procs: ProcIndex,
    impls: ImplIndex,
    impl_flows: ImplFlowIndex,
    aliases: std.StringHashMap([]const u8),
    protos: std.StringArrayHashMap([]const ProtoField),
    record_decls: std.StringArrayHashMap([]const ProtoField),
    int_bindings: std.StringHashMap([]const u8),
    slice_decls: std.StringArrayHashMap([]const u8),
    cap_cells: std.StringHashMap(void),
    reached_events: std.ArrayList(*const ast.EventDecl) = .empty,
    em: Emitter,
};

/// open — refuse the out-of-fragment shapes up front, build the indexes
/// and binding tables, then emit everything the walk's passes are not:
/// the catalog preamble, the cell/struct pre-pass, and the file-scope
/// host text.
pub fn sessionOpen(allocator: std.mem.Allocator, program: *const ast.Program, library: bool) CEmitError!*Session {
    if (library) {
        std.debug.print("error[KORU047]: C lane: --library emission is outside the first fragment\n", .{});
        return CEmitError.UnsupportedConstruct;
    }

    const s = allocator.create(Session) catch return CEmitError.OutOfMemory;
    s.* = .{
        .allocator = allocator,
        .program = program,
        .events = EventIndex.init(allocator),
        .procs = ProcIndex.init(allocator),
        .impls = ImplIndex.init(allocator),
        .impl_flows = ImplFlowIndex.init(allocator),
        .aliases = std.StringHashMap([]const u8).init(allocator),
        .protos = std.StringArrayHashMap([]const ProtoField).init(allocator),
        .record_decls = std.StringArrayHashMap([]const ProtoField).init(allocator),
        .int_bindings = std.StringHashMap([]const u8).init(allocator),
        .slice_decls = std.StringArrayHashMap([]const u8).init(allocator),
        .cap_cells = std.StringHashMap(void).init(allocator),
        .em = undefined,
    };
    try indexItems(allocator, program.items, &s.events, &s.procs, &s.impls, &s.impl_flows);

    // Pre-flight: name every applicable refusal axis before emitting a byte.
    var census: AxisCensus = .{};
    const census_ctx = CensusCtx{ .allocator = allocator, .events = &s.events };
    try axisRefusalItems(program.items, program.main_module_name, &census, &census_ctx);
    if (census.host_lines != null or census.resumable != null or census.concurrency != null) {
        // The pre-flight runs before an Emitter exists — the fragment
        // table loads standalone, same file the emitter's lazier checks
        // harvest.
        var frag = loadTargetRows(allocator, "fragment");
        return refuseAxes(&census, if (frag) |*f| f else null);
    }

    var reached = Reached.init(allocator);
    defer reached.deinit();
    var worklist: std.ArrayList([]const u8) = .empty;
    defer worklist.deinit(allocator);
    try markReachedCalls(allocator, program.items, program.main_module_name, &reached, &worklist);
    try markRetainedEvents(allocator, program.items, &reached, &worklist);
    try reachImplFlows(allocator, &s.impl_flows, &reached, &worklist);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();
    try collectReachedInOrder(allocator, program.items, &s.events, &reached, &s.reached_events, &seen);

    try seedProtoTerminals(program.items, &s.aliases);
    try seedProtoStructs(allocator, program.items, &s.protos);

    s.em = Emitter{
        .cap_cells = &s.cap_cells,
        .allocator = allocator,
        .buf = &s.buf,
        .events = &s.events,
        .procs = &s.procs,
        .impls = &s.impls,
        .impl_flows = &s.impl_flows,
        .aliases = &s.aliases,
        .int_bindings = &s.int_bindings,
        .slice_decls = &s.slice_decls,
        .protos = &s.protos,
        .record_decls = &s.record_decls,
    };
    const em = &s.em;

    // Preamble — includes plus the runtime surface the lowering and the |c
    // transforms write against. Catalog loaded → the `prelude(c)` rows are
    // the sole source: includes render as `#include <x>`, `defs` render
    // verbatim in declared order, minted families carry no text. Absent →
    // the legacy literal.
    em.ensureCatalog();
    if (em.prelude_rows) |pr| {
        for (pr.includes) |inc| try em.writeFmt("#include <{s}>\n", .{inc});
        try em.write("\n");
        for (pr.defs) |d| {
            const t = d.text orelse continue;
            try em.write(t);
            try em.write("\n");
        }
        try em.write("\n");
    } else {
        try em.write(
            \\#include <stdio.h>
            \\#include <stdlib.h>
            \\#include <string.h>
            \\#include <stdint.h>
            \\#include <stdbool.h>
            \\#include <errno.h>
            \\
            \\static char *__koru_concat(const char *a, const char *b) {
            \\    size_t la = strlen(a), lb = strlen(b);
            \\    char *r = (char *)malloc(la + lb + 1);
            \\    if (!r) { fputs("koru: out of memory\n", stderr); abort(); }
            \\    memcpy(r, a, la);
            \\    memcpy(r + la, b, lb + 1);
            \\    return r;
            \\}
            \\static void __koru_stdout_write(const char *s) { fputs(s, stdout); }
            \\static void __koru_stderr_write(const char *s) { fputs(s, stderr); }
            \\static long long __koru_len_str(const char *s) { return (long long)strlen(s); }
            \\static int __koru_streq(const char *a, const char *b) { return strcmp(a, b) == 0; }
            \\static char *__koru_str_i64(long long v) {
            \\    char buf[32];
            \\    snprintf(buf, sizeof buf, "%lld", v);
            \\    return __koru_concat(buf, "");
            \\}
            \\static void __koru_stdout_write_i64(long long v) { printf("%lld", v); }
            \\static void __koru_stderr_write_i64(long long v) { fprintf(stderr, "%lld", v); }
            \\static void __koru_stdout_write_f64(double v) { printf("%g", v); }
            \\static void __koru_stderr_write_f64(double v) { fprintf(stderr, "%g", v); }
            \\static void __koru_stdout_write_f64_prec(double v, int prec) { printf("%.*f", prec, v); }
            \\static void __koru_stderr_write_f64_prec(double v, int prec) { fprintf(stderr, "%.*f", prec, v); }
            \\static int __koru_argc;
            \\static char **__koru_argv;
            \\static char __koru_readln_buf[8192];
            \\struct __koru_comptime_Expression { char __koru_comptime; };
            \\struct __koru_comptime_Source { char __koru_comptime; };
            \\static _Noreturn void __koru_unreachable(const char *what) {
            \\    fflush(NULL); // buffered stdout must land before the trap (zig flushes; abort does not)
            \\    fprintf(stderr, "koru: %s\n", what);
            \\    abort();
            \\}
            \\static long long __koru_intcast(long long v, long long lo, long long hi) {
            \\    if (v < lo || v > hi) __koru_unreachable("@intCast out of range");
            \\    return v;
            \\}
            \\static unsigned long long __koru_intcast_u(unsigned long long v, unsigned long long lo, unsigned long long hi) {
            \\    if (v < lo || v > hi) __koru_unreachable("@intCast out of range");
            \\    return v;
            \\}
            \\static long long __koru_max_ll(long long a, long long b) { return a > b ? a : b; }
            \\static long long __koru_min_ll(long long a, long long b) { return a < b ? a : b; }
            \\
        );
    }

    // Cell-definition pre-pass — resolving every declared type on the
    // reached events (and every proto's whole field table) registers each
    // `struct __koru_slice_<tag>` and proto struct a `.kc` host line,
    // `_in`/`_res`/`_ret` struct or prototype can spell. The definitions
    // emit before any text that can name one — the ring's `.kc` cell
    // types its buffer `struct Reading`, so the struct must already exist.
    for (s.reached_events.items) |event| {
        for (event.input.fields) |f| _ = em.cTypeOfResolved(f.type);
        if (event.return_type) |rt| _ = em.cTypeOfResolved(rt);
        for (event.branches) |*b| {
            for (b.payload.fields) |f| _ = em.cTypeOfResolved(f.type);
        }
    }
    var pit = s.protos.iterator();
    while (pit.next()) |e| _ = em.cTypeOfResolved(e.key_ptr.*);
    for (s.slice_decls.keys(), s.slice_decls.values()) |tag, member| {
        try em.writeFmt("struct __koru_slice_{s} {{ {s} *ptr; uintptr_t len; }};\n", .{ tag, member });
    }
    // The two-word 128-bit cells — leaf types, so they precede any
    // proto/record def that might name one as a field.
    if (em.needs_i128) try em.write("struct __koru_i128 { unsigned long long lo; long long hi; };\n");
    if (em.needs_u128) try em.write("struct __koru_u128 { unsigned long long lo; unsigned long long hi; };\n");
    // Proto-terminal typedefs — a proto field spelled `Health` binds the
    // alias name in a cell def, so the typedef must precede every struct
    // that binds it. The transform's verbatim `typedef` still lands later
    // in program order; a duplicate identical typedef is legal C11
    // (verified through ccomp).
    {
        var td_names: std.ArrayList([]const u8) = .empty;
        defer td_names.deinit(allocator);
        var ait = s.aliases.iterator();
        while (ait.next()) |e| try td_names.append(allocator, e.key_ptr.*);
        std.mem.sort([]const u8, td_names.items, {}, struct {
            fn lt(_: void, a: []const u8, b: []const u8) bool {
                return std.mem.lessThan(u8, a, b);
            }
        }.lt);
        for (td_names.items) |name| {
            const scalar = s.aliases.get(name).?;
            const host = if (std.mem.eql(u8, scalar, "string")) "[]const u8" else scalar;
            if (em.catalogFlatType(host)) |ct| try em.writeFmt("typedef {s} {s};\n", .{ ct, name });
        }
    }
    try emitCellStructDefs(em);

    try emitCHostLines(em, program.items);
    try emitTopLevelInlineCode(em, program.items);
    try emitFileScopeBodies(em, program.items);

    em.decl_writer.ctx = em;
    return s;
}

/// decls — the walk's declaration pass: one tagged-result grammar and
/// prototype per reached event. Sole-source: the walk's text is what
/// emits; the oracle renders beside it under emit_audit's isolation.
pub fn sessionDeclPass(s: *Session) CEmitError!void {
    const allocator = s.allocator;
    const em = &s.em;
    for (s.reached_events.items) |event| {
        // Sole-source: the walk writes the declaration — its text is
        // what emits and its refusals are the lane's. The oracle renders
        // beside it into scratch under isolation (emit_audit) — the pin
        // on the migration, never the emitted bytes.
        const dkey = pathKey(allocator, event.path) catch "?";
        var oracle: std.ArrayList(u8) = .empty;
        defer oracle.deinit(allocator);
        var oracle_ok = true;
        em.renderIsolated(&oracle, Emitter.emitEventDeclaration, .{event}) catch |e| {
            oracle_ok = false;
            emit_audit.oracleErrored("decl", dkey, @errorName(e));
        };
        const mark = em.buf.items.len;
        emit_walk.writeEventDecl(em.buf, allocator, event, &em.decl_writer) catch |e| {
            if (oracle_ok) emit_audit.walkRefusedPastOracle("decl", dkey, @errorName(e));
            return @errorCast(e);
        };
        if (oracle_ok) emit_audit.compare("decl", allocator, dkey, oracle.items, em.buf.items[mark..]);
    }
    try em.write("\n");
}

/// defs — the definition pass: signature + field bindings + the
/// impl-resolution body per reached event. Same audit shape as decls.
pub fn sessionDefPass(s: *Session) CEmitError!void {
    const allocator = s.allocator;
    const em = &s.em;
    for (s.reached_events.items) |event| {
        // Same sole-source audit as the declaration pass: the walk's
        // definition (signature + impl-resolution body) is what emits.
        const fkey = pathKey(allocator, event.path) catch "?";
        var oracle_def: std.ArrayList(u8) = .empty;
        defer oracle_def.deinit(allocator);
        var oracle_def_ok = true;
        em.renderIsolated(&oracle_def, Emitter.emitEventDecl, .{event}) catch |e| {
            oracle_def_ok = false;
            emit_audit.oracleErrored("def", fkey, @errorName(e));
        };
        const mark = em.buf.items.len;
        emit_walk.writeEventDef(em.buf, allocator, event, &em.decl_writer) catch |e| {
            if (oracle_def_ok) emit_audit.walkRefusedPastOracle("def", fkey, @errorName(e));
            return @errorCast(e);
        };
        if (oracle_def_ok) emit_audit.compare("def", allocator, fkey, oracle_def.items, em.buf.items[mark..]);
    }
}

/// driver — the flow functions plus `main`'s call order for the runnable
/// flows. Same audit shape; flow bodies mint __koru_res_N the way event
/// defs do, so renderIsolated still guards the counter.
pub fn sessionDriverPass(s: *Session) CEmitError!void {
    const allocator = s.allocator;
    const em = &s.em;
    const program = s.program;
    var oracle_drv: std.ArrayList(u8) = .empty;
    defer oracle_drv.deinit(allocator);
    var oracle_drv_ok = true;
    em.renderIsolated(&oracle_drv, Emitter.emitDriverFns, .{program}) catch |e| {
        oracle_drv_ok = false;
        emit_audit.oracleErrored("driver", "driver", @errorName(e));
    };
    const drv_mark = em.buf.items.len;
    emit_walk.writeDriver(em.buf, allocator, program, &em.decl_writer) catch |e| {
        if (oracle_drv_ok) emit_audit.walkRefusedPastOracle("driver", "driver", @errorName(e));
        return @errorCast(e);
    };
    if (oracle_drv_ok) emit_audit.compare("driver", allocator, "driver", oracle_drv.items, em.buf.items[drv_mark..]);
}

/// close — the post-passes that consume what the walk registered: slice
/// accessors rewritten against int_bindings, catalog prelude checked,
/// no-zig-in-c validated, the shadow walk's coverage report. Returns the
/// emitted code; sessionDestroy frees the session's own tables.
pub fn sessionClose(s: *Session) CEmitError![]const u8 {
    const allocator = s.allocator;
    const em = &s.em;
    var rewritten: std.ArrayList(u8) = .empty;
    errdefer rewritten.deinit(allocator);
    try rewriteSliceAccessors(&rewritten, allocator, s.buf.items, &s.int_bindings);
    s.buf.deinit(allocator);
    s.buf = .empty;
    em.checkCatalogPrelude(&rewritten);
    try validateNoZigInC(em, &rewritten);
    em.ensureCatalog();
    const shadow_catalog = emit_walk.Catalog{
        .types = if (em.catalog_types) |*t| t else null,
        .constructs = if (em.catalog_constructs) |*t| t else null,
    };
    emit_walk.shadow(s.program, &shadow_catalog);
    return rewritten.toOwnedSlice(allocator);
}

/// Free every table the session owns. The returned code slice is the
/// caller's — it outlives the session.
pub fn sessionDestroy(s: *Session) void {
    const allocator = s.allocator;
    s.buf.deinit(allocator);
    s.events.deinit();
    var pit = s.procs.valueIterator();
    while (pit.next()) |v| v.deinit(allocator);
    s.procs.deinit();
    s.impls.deinit();
    var fit = s.impl_flows.valueIterator();
    while (fit.next()) |v| v.deinit(allocator);
    s.impl_flows.deinit();
    s.aliases.deinit();
    s.protos.deinit();
    s.record_decls.deinit();
    s.int_bindings.deinit();
    s.slice_decls.deinit();
    s.cap_cells.deinit();
    s.reached_events.deinit(allocator);
    allocator.destroy(s);
}

pub fn emit(allocator: std.mem.Allocator, program: *const ast.Program, library: bool) CEmitError![]const u8 {
    const s = try sessionOpen(allocator, program, library);
    errdefer sessionDestroy(s);
    try sessionDeclPass(s);
    try sessionDefPass(s);
    try sessionDriverPass(s);
    const code = try sessionClose(s);
    sessionDestroy(s);
    return code;
}
