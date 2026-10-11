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
    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);
    if (path.module_qualifier) |mq| {
        try buf.appendSlice(allocator, mq);
    }
    try buf.append(allocator, ':');
    for (path.segments, 0..) |seg, i| {
        if (i > 0) try buf.append(allocator, '.');
        try buf.appendSlice(allocator, seg);
    }
    return buf.toOwnedSlice(allocator);
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
fn cTypeOf(koru_type: []const u8) ?[]const u8 {
    const t = std.mem.trim(u8, koru_type, " \t");
    if (std.mem.eql(u8, t, "string") or std.mem.eql(u8, t, "[]const u8")) return "const char *";
    if (std.mem.eql(u8, t, "i64") or std.mem.eql(u8, t, "i32") or
        std.mem.eql(u8, t, "i16") or std.mem.eql(u8, t, "i8") or
        std.mem.eql(u8, t, "u64") or std.mem.eql(u8, t, "u32") or
        std.mem.eql(u8, t, "u16") or std.mem.eql(u8, t, "u8") or
        std.mem.eql(u8, t, "usize") or std.mem.eql(u8, t, "isize") or
        std.mem.eql(u8, t, "int") or std.mem.eql(u8, t, "number")) return "long long";
    if (std.mem.eql(u8, t, "f64") or std.mem.eql(u8, t, "f32") or
        std.mem.eql(u8, t, "float")) return "double";
    if (std.mem.eql(u8, t, "bool")) return "int";
    return null;
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

fn axisRefusalItems(
    items: []const ast.Item,
    main_module: []const u8,
    census: *AxisCensus,
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
                    if (b.kind == .effect) {
                        if (census.resumable == null) census.resumable = e.location;
                    }
                }
            },
            .flow => |*f| {
                if (!std.mem.eql(u8, f.module, main_module)) continue;
                try axisRefusalSite(&f.body, census);
            },
            .module_decl => |*m| {
                // Transforms consume their invocations before emission (pump flows are
                // rewritten wholesale), so the durable concurrency evidence is the
                // merged module itself: importing std.pump / std.rings / std.threading
                // leaves a module_decl whose path names the family. Presence-scoped,
                // not use-scoped — stricter than the axis but always sound.
                if (isConcurrencyModule(m.logical_name) or isConcurrencyModule(m.canonical_path)) {
                    if (census.concurrency == null) census.concurrency = m.location;
                }
                try axisRefusalItems(m.items, main_module, census);
            },
            else => {},
        }
    }
}

fn axisRefusalSite(site: *const ast.Continuation, census: *AxisCensus) CEmitError!void {
    if (site.kind == .effect and census.resumable == null) census.resumable = site.location;
    if (site.node) |*node| {
        switch (node.*) {
            .invocation => |*inv| {
                if (isConcurrencyPath(inv.path) and census.concurrency == null) {
                    census.concurrency = site.location;
                }
            },
            .conditional => |*c| try axisRefusalBranches(c.branches, census),
            .foreach => |*f| try axisRefusalBranches(f.branches, census),
            .switch_result => |*s| try axisRefusalBranches(s.branches, census),
            else => {},
        }
    }
    for (site.continuations) |*cont| try axisRefusalSite(cont, census);
}

fn axisRefusalBranches(branches: []const ast.NamedBranch, census: *AxisCensus) CEmitError!void {
    for (branches) |*b| {
        for (b.body) |*site| try axisRefusalSite(site, census);
    }
}

/// pump / rings / worker.spawn — the concurrency axis. Matches the module
/// qualifier (std.pump, std.rings) or a `worker`/`spawn` segment pair.
fn isConcurrencyModule(name: []const u8) bool {
    const families = [_][]const u8{ "pump", "rings", "threading", "worker" };
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
/// cells grep stderr for them (400_208/209/210).
fn refuseAxes(census: *const AxisCensus) CEmitError {
    std.debug.print("error[KORU047]: C lane refusal — program uses constructs outside the CompCert-verified fragment:\n", .{});
    if (census.resumable) |loc| {
        std.debug.print("  - `!` effect arms: resume semantics out of oracle scope ({s}:{d})\n", .{ loc.file, loc.line });
    }
    if (census.host_lines) |loc| {
        std.debug.print("  - raw host lines: Zig host text has no C lowering — cannot lower to C ({s}:{d})\n", .{ loc.file, loc.line });
    }
    if (census.concurrency) |loc| {
        std.debug.print("  - pump / rings / worker.spawn: CompCert is a sequential C subset — no verified concurrency ({s}:{d})\n", .{ loc.file, loc.line });
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

    fn write(self: *Emitter, text: []const u8) CEmitError!void {
        try self.buf.appendSlice(self.allocator, text);
    }

    fn writeFmt(self: *Emitter, comptime fmt: []const u8, args: anytype) CEmitError!void {
        try self.buf.writer(self.allocator).print(fmt, args);
    }

    /// Lower Koru expression text through the ONE shared lowering (the C
    /// target arm of codegen_utils.lowerKoruExpr), or refuse the builtin it
    /// names.
    fn writeExpr(self: *Emitter, text: []const u8) CEmitError!void {
        var diag: codegen_utils.LowerDiag = .{};
        const lowered = codegen_utils.lowerKoruExpr(self.allocator, text, .c, .koru_expr, &diag) catch |err| {
            if (err == error.UnsupportedBuiltin) {
                std.debug.print("error[KORU047]: C lane: unsupported builtin {s} in expression `{s}`\n", .{ diag.unknown_builtin, text });
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
        if (event.branches.len > 0) return; // definition pass refuses
        if (event.input.is_wildcard) return;

        const ret = try self.eventReturnType(event, key);
        if (event.input.fields.len > 0) {
            try self.writeFmt("struct {s}_in {{\n", .{name});
            for (event.input.fields) |f| {
                const ct = cTypeOf(f.type) orelse {
                    std.debug.print("error[KORU047]: C lane: {s} field {s} has type {s} — no C type in the first fragment\n", .{ key, f.name, f.type });
                    return CEmitError.UnsupportedConstruct;
                };
                try self.writeFmt("    {s} {s};\n", .{ ct, f.name });
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
        _ = self;
        if (event.return_type) |rt| {
            return cTypeOf(rt) orelse {
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

        if (event.branches.len > 0) {
            std.debug.print("error[KORU047]: C lane: {s} declares named branches — tagged results are outside the first fragment\n", .{key});
            return CEmitError.UnsupportedConstruct;
        }
        if (event.input.is_wildcard) {
            std.debug.print("error[KORU047]: C lane: {s} wildcard input — outside the first fragment\n", .{key});
            return CEmitError.UnsupportedConstruct;
        }

        const ret = try self.eventReturnType(event, key);
        try self.writeFmt("static {s} {s}(", .{ ret, name });
        if (event.input.fields.len == 0) {
            try self.write("void");
        } else {
            try self.writeFmt("struct {s}_in {s}", .{ name, INPUT_PARAM });
        }
        try self.write(") {\n");

        // Impl resolution: |c proc > immediate `->` > subflow impl > refuse.
        if (self.procs.get(key)) |plist| {
            var c_proc: ?*const ast.ProcDecl = null;
            for (plist.items) |p| {
                if (p.target) |t| {
                    if (std.mem.eql(u8, t, C_TARGET)) c_proc = p;
                }
            }
            if (c_proc) |p| {
                try self.emitFieldBindings(event);
                try self.writeHostText(p.body.text);
                try self.write("\n}\n\n");
                return;
            }
        }
        if (self.impls.get(key)) |ii| {
            const v = ii.value;
            if (!v.is_bare_return or v.branch_name.len != 0 or v.fields.len != 0 or v.plain_value == null) {
                std.debug.print("error[KORU047]: C lane: {s} immediate impl is a named/fielded branch — outside the first fragment\n", .{key});
                return CEmitError.UnsupportedConstruct;
            }
            try self.emitFieldBindings(event);
            try self.write("    return ");
            try self.writeExpr(v.plain_value.?);
            try self.write(";\n}\n\n");
            return;
        }
        if (self.impl_flows.get(key)) |flist| {
            if (flist.items.len != 1) {
                std.debug.print("error[KORU047]: C lane: {s} has {d} subflow impls — variant selection is outside the first fragment\n", .{ key, flist.items.len });
                return CEmitError.UnsupportedConstruct;
            }
            try self.emitFieldBindings(event);
            try self.emitSite(&flist.items[0].body, "    ", .in_impl);
            try self.write("}\n\n");
            return;
        }
        std.debug.print("error[KORU047]: C lane: {s} has no |c proc body and no Koru impl (NoCProcBody)\n", .{key});
        return CEmitError.NoCProcBody;
    }

    /// `const <ct> <field> = __koru_in.<field>;` — the |c proc binding
    /// convention, same as the js/cs prologue off their input param.
    fn emitFieldBindings(self: *Emitter, event: *const ast.EventDecl) CEmitError!void {
        for (event.input.fields) |f| {
            const ct = cTypeOf(f.type) orelse {
                std.debug.print("error[KORU047]: C lane: field {s} has type {s} — no C type in the first fragment\n", .{ f.name, f.type });
                return CEmitError.UnsupportedConstruct;
            };
            try self.writeFmt("    {s} const {s} = {s}.{s};\n", .{ ct, f.name, INPUT_PARAM, f.name });
        }
    }

    // -- call/continuation emission ----------------------------------------

    const SiteCtx = enum { in_flow, in_impl };

    fn emitSite(self: *Emitter, site: *const ast.Continuation, indent: []const u8, ctx: SiteCtx) CEmitError!void {
        if (site.kind == .effect) return CEmitError.RefusedConstruct;
        if (site.branch.len != 0) {
            std.debug.print("error[KORU047]: C lane: branch arm `| {s}` — tagged dispatch is outside the first fragment\n", .{site.branch});
            return CEmitError.UnsupportedConstruct;
        }
        if (site.binding != null or site.destructure.len != 0) {
            std.debug.print("error[KORU047]: C lane: branch-arm binding — tagged payloads are outside the first fragment\n", .{});
            return CEmitError.UnsupportedConstruct;
        }
        if (site.condition) |cond| {
            try self.write(indent);
            try self.write("if (");
            try self.writeExpr(cond);
            try self.write(") {\n");
            try self.emitSiteNode(site, indent, ctx);
            try self.write(indent);
            try self.write("}\n");
        } else {
            try self.emitSiteNode(site, indent, ctx);
        }
        for (site.continuations) |*cont| {
            try self.emitSite(cont, indent, ctx);
        }
    }

    fn emitSiteNode(self: *Emitter, site: *const ast.Continuation, indent: []const u8, ctx: SiteCtx) CEmitError!void {
        const node = site.node orelse return;
        switch (node) {
            .invocation => |*inv| {
                if (inv.preamble_code) |pre| {
                    try self.emitVerbatimLines(pre, indent);
                }
                if (inv.inline_body) |body| {
                    try self.emitVerbatimLines(body, indent);
                } else {
                    try self.emitCall(inv, indent);
                }
            },
            .inline_code => |text| try self.emitVerbatimLines(text, indent),
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
    }

    /// A `->`/produce: `return <value>;` — bare value only; named or fielded
    /// branch payloads are the tagged-result lane.
    fn emitProduce(self: *Emitter, bc: *const ast.BranchConstructor, indent: []const u8) CEmitError!void {
        try self.write(indent);
        if (!bc.is_bare_return and bc.branch_name.len != 0) {
            std.debug.print("error[KORU047]: C lane: named branch `=> {s}` needs tagged results — outside the first fragment\n", .{bc.branch_name});
            return CEmitError.UnsupportedConstruct;
        }
        if (bc.fields.len != 0) {
            std.debug.print("error[KORU047]: C lane: fielded produce — outside the first fragment\n", .{});
            return CEmitError.UnsupportedConstruct;
        }
        if (bc.plain_value) |pv| {
            try self.write("return ");
            try self.writeExpr(pv);
            try self.write(";\n");
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
            try self.write(indent);
            try self.writeHostText(t);
            try self.write("\n");
        }
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
            return CEmitError.UnsupportedConstruct;
        }
        if (inv.return_binding) |bind| {
            const rt = event.return_type orelse {
                std.debug.print("error[KORU047]: C lane: {s} bound to `{s}` but the event has no `-> T` return\n", .{ key, bind });
                return CEmitError.UnsupportedConstruct;
            };
            const ct = cTypeOf(rt) orelse {
                std.debug.print("error[KORU047]: C lane: {s} returns {s} — no C type in the first fragment\n", .{ key, rt });
                return CEmitError.UnsupportedConstruct;
            };
            try self.writeFmt("{s} const {s} = ", .{ ct, bind });
        }
        if (eventIsStub(event)) {
            // Reached but transform-annotated — a call that should never
            // exist post-transform; emit the loud stub call.
            try self.writeFmt("{s}();\n", .{name});
            return;
        }
        try self.write(name);
        try self.write("(");
        if (event.input.fields.len > 0) {
            try self.writeFmt("(struct {s}_in){{ ", .{name});
            for (event.input.fields, 0..) |f, fi| {
                if (fi > 0) try self.write(", ");
                try self.writeFmt(".{s} = ", .{f.name});
                try self.emitArgForField(inv, f, fi);
            }
            try self.write(" }");
        }
        try self.write(");\n");
    }

    /// The value for declared field `f` (ordinal `fi`) at a call site: the
    /// arg named `f`, else the positional arg at the same ordinal, else the
    /// field default, else refuse — a missing argument is a shape error the
    /// C lane does not guess on.
    fn emitArgForField(self: *Emitter, inv: *const ast.Invocation, f: ast.Field, fi: usize) CEmitError!void {
        var positional: usize = 0;
        for (inv.args) |*a| {
            if (a.name.len == 0) {
                if (positional == fi) {
                    try self.writeExpr(a.value);
                    return;
                }
                positional += 1;
            } else if (std.mem.eql(u8, a.name, f.name)) {
                try self.writeExpr(a.value);
                return;
            }
        }
        if (f.default) |d| {
            try self.writeExpr(d);
            return;
        }
        std.debug.print("error[KORU047]: C lane: call supplies no value for field {s}\n", .{f.name});
        return CEmitError.UnresolvedEvent;
    }

    // -- flow emission ------------------------------------------------------

    fn emitFlow(self: *Emitter, flow: *const ast.Flow, flow_num: usize) CEmitError!void {
        try self.writeFmt("static void koru_flow_{d}(void) {{\n", .{flow_num});
        if (flow.preamble_code) |pre| {
            try self.emitVerbatimLines(pre, "    ");
        }
        if (flow.inline_body) |body| {
            try self.emitVerbatimLines(body, "    ");
            for (flow.body.continuations) |*cont| {
                try self.emitSite(cont, "    ", .in_flow);
            }
        } else {
            try self.emitSite(&flow.body, "    ", .in_flow);
        }
        try self.write("}\n\n");
    }
};

// ---------------------------------------------------------------------------
// Host lines + top-level inline code
// ---------------------------------------------------------------------------

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

fn validateNoZigInC(buf: *const std.ArrayList(u8)) CEmitError!void {
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
pub fn emit(allocator: std.mem.Allocator, program: *const ast.Program, library: bool) CEmitError![]const u8 {
    if (library) {
        std.debug.print("error[KORU047]: C lane: --library emission is outside the first fragment\n", .{});
        return CEmitError.UnsupportedConstruct;
    }

    var buf: std.ArrayList(u8) = .empty;
    errdefer buf.deinit(allocator);

    var events = EventIndex.init(allocator);
    defer events.deinit();
    var procs = ProcIndex.init(allocator);
    defer {
        var it = procs.valueIterator();
        while (it.next()) |v| v.deinit(allocator);
        procs.deinit();
    }
    var impls = ImplIndex.init(allocator);
    defer impls.deinit();
    var impl_flows = ImplFlowIndex.init(allocator);
    defer {
        var it = impl_flows.valueIterator();
        while (it.next()) |v| v.deinit(allocator);
        impl_flows.deinit();
    }
    try indexItems(allocator, program.items, &events, &procs, &impls, &impl_flows);

    // Pre-flight: name every applicable refusal axis before emitting a byte.
    var census: AxisCensus = .{};
    try axisRefusalItems(program.items, program.main_module_name, &census);
    if (census.host_lines != null or census.resumable != null or census.concurrency != null) {
        return refuseAxes(&census);
    }

    var reached = Reached.init(allocator);
    defer reached.deinit();
    var worklist: std.ArrayList([]const u8) = .empty;
    defer worklist.deinit(allocator);
    try markReachedCalls(allocator, program.items, program.main_module_name, &reached, &worklist);
    try reachImplFlows(allocator, &impl_flows, &reached, &worklist);

    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();
    var reached_events: std.ArrayList(*const ast.EventDecl) = .empty;
    defer reached_events.deinit(allocator);
    try collectReachedInOrder(allocator, program.items, &events, &reached, &reached_events, &seen);

    var em = Emitter{
        .allocator = allocator,
        .buf = &buf,
        .events = &events,
        .procs = &procs,
        .impls = &impls,
        .impl_flows = &impl_flows,
    };

    // Preamble — includes plus the runtime surface the lowering and the |c
    // transforms write against.
    try em.write(
        \\#include <stdio.h>
        \\#include <stdlib.h>
        \\#include <string.h>
        \\#include <stdint.h>
        \\#include <stdbool.h>
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
        \\static long long __koru_len(const char *s) { return (long long)strlen(s); }
        \\static char *__koru_str_i64(long long v) {
        \\    char buf[32];
        \\    snprintf(buf, sizeof buf, "%lld", v);
        \\    return __koru_concat(buf, "");
        \\}
        \\static void __koru_stdout_write_i64(long long v) { printf("%lld", v); }
        \\static void __koru_stderr_write_i64(long long v) { fprintf(stderr, "%lld", v); }
        \\static void __koru_stdout_write_f64(double v) { printf("%g", v); }
        \\static void __koru_stderr_write_f64(double v) { fprintf(stderr, "%g", v); }
        \\static void __koru_unreachable(const char *what) {
        \\    fprintf(stderr, "koru: %s\n", what);
        \\    abort();
        \\}
        \\
    );

    try emitCHostLines(&em, program.items);
    try emitTopLevelInlineCode(&em, program.items);

    for (reached_events.items) |event| {
        try em.emitEventDeclaration(event);
    }
    try em.write("\n");
    for (reached_events.items) |event| {
        try em.emitEventDecl(event);
    }

    // Top-level flows → flow functions + one main driving them in order.
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
        try em.emitFlow(f, flow_num);
        flow_num += 1;
    }

    try em.write("int main(void) {\n");
    for (0..flow_num) |i| {
        try em.writeFmt("    koru_flow_{d}();\n", .{i});
    }
    try em.write("    return 0;\n}\n");

    try validateNoZigInC(&buf);
    return buf.toOwnedSlice(allocator);
}
