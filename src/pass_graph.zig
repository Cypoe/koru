//! Declared pass graph — `~[requires("a","b")]` on a tor declares ordering
//! edges: every named pass must have executed before the declaring pass runs.
//!
//! The checker's two jobs:
//!   1. The declared edge digraph itself must be sound: every required name
//!      resolves to a decl, and the edges admit a linearization (acyclic).
//!      That is a property of the declarations alone — a cycle is refused
//!      even if the members never share a chain.
//!   2. Every flow chain (`~x = a() |> b()`) is an observation of actual
//!      order. Segment invocations expand through their own `~x =` impl
//!      flows, so a `requires` edge between members of different segments
//!      (analysis requiring an elaborate pass) is checked against the
//!      flattened pipeline at `coordinate`, not left unverifiable.
//!
//! Rules of the order check, and why:
//!   - Both parties present in a chain: every occurrence of each required
//!     pass must precede every occurrence of the requirer. (A pass that runs
//!     twice — desugar-chains is the canonical case — is "established" only
//!     after its LAST run; checking all positions is the strict reading.)
//!   - Requirer present, required absent: refused only at ROOTS — flows
//!     never invoked inside another flow's chain (`coordinate`, user
//!     overrides of it, top-level program flows). A non-root chain like
//!     `~analysis` is invoked inside `coordinate` where outer segments
//!     legitimately provide the required pass; refusing there would deny
//!     the composition the mechanism exists to check.
//!
//! `requires` names pass *order* only. `preserves` (invariant obligations)
//! and transform blast-radius bounds are declared surface for later rungs —
//! they are parsed and stored but not yet enforced, and this module says so.
//!
//! Naming: the call form follows `depends_on` (build steps, main.zig).
//! `std/compiler:requires` the directive tor is a different grammar slot
//! (tor name vs annotation); the collision is recorded in the handoff for
//! a ruling on whether the spellings should share a word.

const std = @import("std");
const ast = @import("ast");
const annotation_parser = @import("annotation_parser");
const errors = @import("errors");

const PassDecl = struct {
    /// Last segment of the decl path ("check-structure").
    name: []const u8,
    /// Module-qualified spelling "module:name" for diagnostics and qualified
    /// matching (module separators normalized: '/' and '.' both -> '.').
    qualified: []const u8,
    requires: []const []const u8,
    preserves: []const []const u8,
    location: errors.SourceLocation,
};

/// A pass invocation observed in a flow chain, in execution order.
const Step = struct {
    /// Last path segment as invoked.
    name: []const u8,
    /// Normalized module qualifier ("" when bare).
    qualifier: []const u8,
};

fn normalizeQualifier(allocator: std.mem.Allocator, q: []const u8) ![]const u8 {
    const copy = try allocator.dupe(u8, q);
    for (copy) |*c| {
        if (c.* == '/') c.* = '.';
    }
    return copy;
}

fn lastSegment(path: ast.DottedPath) []const u8 {
    if (path.segments.len == 0) return "";
    return path.segments[path.segments.len - 1];
}

fn declQualifier(decl: *const ast.EventDecl) []const u8 {
    if (decl.path.module_qualifier) |mq| return mq;
    return decl.module;
}

/// Collect declared edges + impl flows. Returns false (via error) through
/// the caller on violation — this function only gathers.
const Graph = struct {
    decls: std.ArrayList(PassDecl),
    /// impl flows by last-segment name — expansion targets.
    impl_flows: std.StringHashMapUnmanaged(std.ArrayList(*const ast.Flow)),
    /// Every flow item (impl or top-level), each a chain to check.
    flows: std.ArrayList(*const ast.Flow),
    allocator: std.mem.Allocator,
};

fn collect(allocator: std.mem.Allocator, items: []const ast.Item) !Graph {
    var g: Graph = .{
        .decls = .empty,
        .impl_flows = .{},
        .flows = .empty,
        .allocator = allocator,
    };
    for (items) |*item| {
        switch (item.*) {
            .event_decl => |*decl| {
                var requires: std.ArrayList([]const u8) = .empty;
                if (try annotation_parser.getCall(allocator, decl.annotations, "requires")) |call| {
                    var c = call;
                    defer c.deinit(allocator);
                    for (c.args) |arg| try requires.append(allocator, try allocator.dupe(u8, arg));
                }
                var preserves: std.ArrayList([]const u8) = .empty;
                if (try annotation_parser.getCall(allocator, decl.annotations, "preserves")) |call| {
                    var c = call;
                    defer c.deinit(allocator);
                    for (c.args) |arg| try preserves.append(allocator, try allocator.dupe(u8, arg));
                }
                if (requires.items.len == 0 and preserves.items.len == 0) continue;
                const name = lastSegment(decl.path);
                const qual = if (declQualifier(decl).len > 0)
                    try std.fmt.allocPrint(allocator, "{s}:{s}", .{ try normalizeQualifier(allocator, declQualifier(decl)), name })
                else
                    name;
                try g.decls.append(allocator, .{
                    .name = name,
                    .qualified = qual,
                    .requires = try requires.toOwnedSlice(allocator),
                    .preserves = try preserves.toOwnedSlice(allocator),
                    .location = decl.location,
                });
            },
            .flow => |*flow| {
                try g.flows.append(allocator, flow);
                if (flow.impl_of) |io| {
                    const key = lastSegment(io);
                    const gop = try g.impl_flows.getOrPut(allocator, key);
                    if (!gop.found_existing) gop.value_ptr.* = .empty;
                    try gop.value_ptr.append(allocator, flow);
                }
            },
            else => {},
        }
    }
    return g;
}

/// Depth-first cycle check over the resolved edge digraph.
/// edges: index into decls -> indexes of required decls. A required name that
/// resolved only to an impl flow (segment name) contributes no decl edge.
fn checkDag(g: *const Graph, decl_by_name: std.StringHashMapUnmanaged(usize)) !void {
    const n = g.decls.items.len;
    const color = try g.allocator.alloc(u8, n); // 0 white 1 gray 2 black
    defer g.allocator.free(color);
    @memset(color, 0);

    const Ctx = struct {
        g: *const Graph,
        decl_by_name: *const std.StringHashMapUnmanaged(usize),
        color: []u8,

        fn dfs(self: *@This(), i: usize, trail: *std.ArrayList(usize)) !void {
            self.color[i] = 1;
            try trail.append(self.g.allocator, i);
            for (self.g.decls.items[i].requires) |req| {
                const req_last = if (std.mem.indexOfScalar(u8, req, ':')) |ci| req[ci + 1 ..] else req;
                const j = self.decl_by_name.get(req_last) orelse continue;
                if (self.color[j] == 1) {
                    // Found a cycle — report the trail from j to i plus j.
                    var msg = std.ArrayList(u8){};
                    var started = false;
                    for (trail.items) |t| {
                        if (t == j) started = true;
                        if (!started) continue;
                        try msg.appendSlice(self.g.allocator, self.g.decls.items[t].name);
                        try msg.appendSlice(self.g.allocator, " requires ");
                    }
                    try msg.appendSlice(self.g.allocator, self.g.decls.items[j].name);
                    std.debug.print("error[KORU180]: pass-graph cycle — {s}\n  the declared edges admit no ordering; a chain satisfying one arm violates the other\n  fix: break the cycle — one of these `requires` is not an ordering fact but a coincidence of current order\n", .{msg.items});
                    std.process.exit(1);
                }
                if (self.color[j] == 0) try self.dfs(j, trail);
            }
            _ = trail.pop();
            self.color[i] = 2;
        }
    };
    var ctx: Ctx = .{ .g = g, .decl_by_name = &decl_by_name, .color = color };
    var trail: std.ArrayList(usize) = .empty;
    for (0..n) |i| {
        if (color[i] == 0) try ctx.dfs(i, &trail);
    }
}

/// Flatten a flow's chain into ordered steps, expanding invoked names through
/// their impl flows. `visited` holds flows already expanded on this path —
/// a recursive impl contributes its name but is not re-entered.
fn flattenChain(
    g: *const Graph,
    cont: *const ast.Continuation,
    visited: *std.AutoHashMapUnmanaged(*const ast.Flow, void),
    out: *std.ArrayList(Step),
) !void {
    if (cont.node) |*node| {
        switch (node.*) {
            .invocation => |*inv| {
                const name = lastSegment(inv.path);
                const qual: []const u8 = if (inv.path.module_qualifier) |mq|
                    try normalizeQualifier(g.allocator, mq)
                else
                    "";
                try out.append(g.allocator, .{ .name = name, .qualifier = qual });
                if (g.impl_flows.get(name)) |impls| {
                    for (impls.items) |impl| {
                        if (visited.contains(impl)) continue;
                        try visited.put(g.allocator, impl, {});
                        try flattenChain(g, &impl.body, visited, out);
                    }
                }
            },
            else => {},
        }
    }
    for (cont.continuations) |*sub| try flattenChain(g, sub, visited, out);
}

/// Which flows are invoked inside another flow's chain — non-roots skip the
/// "required pass never runs" refusal since outer context may provide it.
fn invokedNames(g: *const Graph) !std.StringHashMapUnmanaged(void) {
    var set: std.StringHashMapUnmanaged(void) = .{};
    for (g.flows.items) |flow| {
        var steps: std.ArrayList(Step) = .empty;
        defer steps.deinit(g.allocator);
        var visited: std.AutoHashMapUnmanaged(*const ast.Flow, void) = .{};
        defer visited.deinit(g.allocator);
        try flattenChain(g, &flow.body, &visited, &steps);
        for (steps.items) |s| try set.put(g.allocator, s.name, {});
    }
    return set;
}

fn matchStep(g: *const Graph, step: Step, req: []const u8) bool {
    _ = g;
    var req_last = req;
    var req_qual: []const u8 = "";
    if (std.mem.indexOfScalar(u8, req, ':')) |ci| {
        req_qual = req[0..ci];
        req_last = req[ci + 1 ..];
    }
    if (!std.mem.eql(u8, step.name, req_last)) return false;
    if (req_qual.len == 0) return true;
    var buf: [256]u8 = undefined;
    if (req_qual.len > buf.len) return false;
    @memcpy(buf[0..req_qual.len], req_qual);
    for (buf[0..req_qual.len]) |*c| {
        if (c.* == '/') c.* = '.';
    }
    return std.mem.eql(u8, step.qualifier, buf[0..req_qual.len]);
}

/// Entry point. Walks the parsed program; refuses via KORU180 on
/// unresolvable edges, cycles, or order violations.
pub fn validate(allocator: std.mem.Allocator, items: []const ast.Item) !void {
    var g = try collect(allocator, items);
    if (g.decls.items.len == 0) return; // no declared edges — nothing to check

    // All decls (declared AND unannotated) indexed by last segment — required
    // names resolve against the whole tor namespace, not just edge-holders.
    var decl_by_name: std.StringHashMapUnmanaged(usize) = .{};
    var all_names: std.StringHashMapUnmanaged(void) = .{};
    for (items) |*item| {
        switch (item.*) {
            .event_decl => |*decl| {
                try all_names.put(allocator, lastSegment(decl.path), {});
            },
            else => {},
        }
    }
    for (g.decls.items, 0..) |*d, i| {
        try decl_by_name.put(allocator, d.name, i);
    }
    // impl-flow names also resolve (segment names like `elaborate`).
    var flow_names: std.StringHashMapUnmanaged(void) = .{};
    var fit = g.impl_flows.iterator();
    while (fit.next()) |e| try flow_names.put(allocator, e.key_ptr.*, {});

    // 1. Every required name must resolve to something real.
    for (g.decls.items) |*d| {
        for (d.requires) |req| {
            const req_last = if (std.mem.indexOfScalar(u8, req, ':')) |ci| req[ci + 1 ..] else req;
            if (!all_names.contains(req_last) and !flow_names.contains(req_last)) {
                std.debug.print("error[KORU180]: pass `{s}` requires `{s}`, but no tor or pipeline segment named `{s}` exists in this program\n  {s}:{d}: the edge names a pass identity, not an intention — the check refuses rather than guess which decl was meant\n  fix: fix the spelling, or declare the pass — a `requires` that names nothing is a dead assertion\n", .{ d.name, req, req_last, d.location.file, d.location.line });
                std.process.exit(1);
            }
        }
    }

    // 2. Declared edges must be acyclic (linearizable) on their own.
    try checkDag(&g, decl_by_name);

    // 3. Order check against observed chains.
    const invoked = try invokedNames(&g);

    for (g.flows.items) |flow| {
        var steps: std.ArrayList(Step) = .empty;
        defer steps.deinit(allocator);
        var visited: std.AutoHashMapUnmanaged(*const ast.Flow, void) = .{};
        defer visited.deinit(allocator);
        try flattenChain(&g, &flow.body, &visited, &steps);
        if (steps.items.len == 0) continue;
        // Root = never invoked inside another flow's chain — its ordering is
        // the full execution context, so an absent required pass is a refusal
        // there. Non-roots (segments like `elaborate`) are embedded in a wider
        // chain that legitimately provides the name.
        const root = if (flow.impl_of) |io| !invoked.contains(lastSegment(io)) else true;

        for (g.decls.items) |*d| {
            if (d.requires.len == 0) continue;
            for (steps.items, 0..) |s, i| {
                if (!std.mem.eql(u8, s.name, d.name)) continue;
                for (d.requires) |req| {
                    var last_req_pos: ?usize = null;
                    for (steps.items, 0..) |rs, j| {
                        if (matchStep(&g, rs, req)) last_req_pos = j;
                    }
                    if (last_req_pos) |p| {
                        if (p >= i) {
                            std.debug.print("error[KORU180]: `{s}` requires `{s}`, but the resolved chain runs `{s}` only at a later position\n  chain: {s}\n  the annotation is the contract and the chain is the observation — disagreement is a refusal, not a reorder\n  fix: move `{s}` earlier in the chain, or correct the declared edge\n", .{ d.name, req, req, chainRepr(allocator, steps.items) catch "?", req });
                            std.process.exit(1);
                        }
                    } else if (root) {
                        std.debug.print("error[KORU180]: `{s}` requires `{s}`, but the root pipeline never runs `{s}`\n  a `requires` that its own pipeline cannot satisfy is a dead edge — the check refuses rather than let it stand unverifiable\n  fix: run `{s}` before `{s}` in the chain, or drop the declared edge\n", .{ d.name, req, req, req, d.name });
                        std.process.exit(1);
                    }
                }
            }
        }
    }
}

fn chainRepr(allocator: std.mem.Allocator, steps: []const Step) ![]const u8 {
    var buf = std.ArrayList(u8){};
    for (steps, 0..) |s, i| {
        if (i > 0) try buf.appendSlice(allocator, " |> ");
        if (s.qualifier.len > 0) {
            try buf.appendSlice(allocator, s.qualifier);
            try buf.appendSlice(allocator, ":");
        }
        try buf.appendSlice(allocator, s.name);
    }
    return buf.toOwnedSlice(allocator);
}
