const std = @import("std");
const ast = @import("ast");

/// ThreadedChecker — propagates "reachable from a @threaded root" forward
/// through the call graph. A decl that any threaded path reaches is marked
/// is_threaded_dirty — the lockset's compile-time flag, consumed at codegen.
/// Modeled on PurityChecker: same events map, same call graph, opposite
/// propagation direction (purity meets over paths backward; dirty floods
/// forward — any threaded path wins, never duplicated trees).
pub const ThreadedChecker = struct {
    allocator: std.mem.Allocator,
    events: std.StringHashMap(*const ast.EventDecl),
    call_graph: std.StringHashMap(CallInfo),

    const CallInfo = struct {
        calls: std.ArrayList([]const u8),

        fn init(allocator: std.mem.Allocator) !CallInfo {
            return CallInfo{ .calls = try std.ArrayList([]const u8).initCapacity(allocator, 0) };
        }
    };

    pub fn init(allocator: std.mem.Allocator) ThreadedChecker {
        return .{
            .allocator = allocator,
            .events = std.StringHashMap(*const ast.EventDecl).init(allocator),
            .call_graph = std.StringHashMap(CallInfo).init(allocator),
        };
    }

    pub fn deinit(self: *ThreadedChecker) void {
        var iter = self.call_graph.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.calls.deinit(self.allocator);
        }
        self.call_graph.deinit();
        self.events.deinit();
    }

    /// Phase 1: build the call graph. Phase 2: flood dirty forward from
    /// is_threaded roots to fixpoint.
    pub fn check(self: *ThreadedChecker, source: *ast.Program) !void {
        try self.buildCallGraph(source);
        try self.seedParallelScopes(source.items);
        try self.floodDirty(source);
        if (std.posix.getenv("KORU_DEBUG_THREADED") != null)
            try self.dumpDirty(source.items);
    }

    /// Seed: a [parallel]-annotated invocation (e.g. `[parallel]for`) marks
    /// every tor invoked in its nested continuation subtree — the loop body —
    /// as a threaded root. The subtree IS the scope.
    fn seedParallelScopes(self: *ThreadedChecker, items: []const ast.Item) !void {
        for (items) |*item| {
            switch (item.*) {
                .flow => |*flow| try self.seedFromFlow(flow),
                .proc_decl => |*proc| {
                    for (proc.inline_flows) |*flow| try self.seedFromFlow(flow);
                },
                .module_decl => |*module| try self.seedParallelScopes(module.items),
                else => {},
            }
        }
    }

    fn seedFromFlow(self: *ThreadedChecker, flow: *const ast.Flow) !void {
        const first_inv = flow.inv();
        if (self.hasParallel(first_inv)) {
            for (flow.body.continuations) |*cont|
                try self.markContinuationTreeDirty(cont);
        }
        for (flow.body.continuations) |*cont|
            try self.seedFromContinuation(cont);
    }

    fn seedFromContinuation(self: *ThreadedChecker, cont: *const ast.Continuation) !void {
        if (cont.node) |*step| {
            const inv = if (step.* == .invocation) step.invocation else if (step.* == .label_with_invocation) step.label_with_invocation.invocation else null;
            if (inv) |i| {
                if (self.hasParallel(&i)) {
                    for (cont.continuations) |*nested|
                        try self.markContinuationTreeDirty(nested);
                }
            }
        }
        for (cont.continuations) |*nested| try self.seedFromContinuation(nested);
    }

    /// Every tor invoked anywhere in this continuation subtree goes dirty.
    fn markContinuationTreeDirty(self: *ThreadedChecker, cont: *const ast.Continuation) !void {
        if (cont.node) |*step| {
            const inv = if (step.* == .invocation) step.invocation else if (step.* == .label_with_invocation) step.label_with_invocation.invocation else null;
            if (inv) |i| {
                const name = try self.pathToString(i.path);
                defer self.allocator.free(name);
                if (self.events.get(name)) |ev| {
                    if (!ev.is_threaded_dirty) @constCast(ev).is_threaded_dirty = true;
                }
            }
        }
        for (cont.continuations) |*nested| try self.markContinuationTreeDirty(nested);
    }

    fn hasParallel(self: *ThreadedChecker, inv: *const ast.Invocation) bool {
        _ = self;
        for (inv.annotations) |ann| {
            if (std.mem.eql(u8, ann, "parallel")) return true;
        }
        return false;
    }

    /// Spike oracle: print the dirty set to stderr.
    fn dumpDirty(self: *ThreadedChecker, items: []const ast.Item) !void {
        for (items) |*item| {
            switch (item.*) {
                .proc_decl => |*proc| {
                    if (proc.is_threaded_dirty) {
                        const n = try self.pathToString(proc.path);
                        std.debug.print("  dirty proc: {s}\n", .{n});
                    }
                },
                .event_decl => |*event| {
                    if (event.is_threaded_dirty) {
                        const n = try self.pathToString(event.path);
                        std.debug.print("  dirty tor: {s}\n", .{n});
                    }
                },
                .module_decl => |*module| try self.dumpDirty(module.items),
                else => {},
            }
        }
    }

    fn buildCallGraph(self: *ThreadedChecker, source: *ast.Program) !void {
        try self.registerEventsRecursive(source.items);
        try self.buildCallGraphRecursive(source.items);
    }

    fn registerEventsRecursive(self: *ThreadedChecker, items: []const ast.Item) !void {
        for (items) |*item| {
            switch (item.*) {
                .event_decl => |*event| {
                    const name = try self.pathToString(event.path);
                    try self.events.put(name, event);
                },
                .module_decl => |*module| {
                    try self.registerEventsRecursive(module.items);
                },
                else => {},
            }
        }
    }

    fn buildCallGraphRecursive(self: *ThreadedChecker, items: []const ast.Item) !void {
        for (items) |*item| {
            switch (item.*) {
                .proc_decl => |*proc| {
                    const proc_name = try self.pathToString(proc.path);
                    var call_info = try CallInfo.init(self.allocator);
                    for (proc.inline_flows) |*flow| {
                        try self.collectFlowInvocations(flow, &call_info.calls);
                    }
                    try self.call_graph.put(proc_name, call_info);
                },
                .module_decl => |*module| {
                    try self.buildCallGraphRecursive(module.items);
                },
                else => {},
            }
        }
    }

    fn collectFlowInvocations(self: *ThreadedChecker, flow: *const ast.Flow, invocations: *std.ArrayList([]const u8)) !void {
        const first_event = try self.pathToString(flow.inv().path);
        try invocations.append(self.allocator, first_event);
        for (flow.body.continuations) |*cont| {
            try self.collectContinuationInvocations(cont, invocations);
        }
    }

    fn collectContinuationInvocations(self: *ThreadedChecker, cont: *const ast.Continuation, invocations: *std.ArrayList([]const u8)) !void {
        if (cont.node) |*step| {
            if (step.* == .invocation) {
                try invocations.append(self.allocator, try self.pathToString(step.invocation.path));
            } else if (step.* == .label_with_invocation) {
                try invocations.append(self.allocator, try self.pathToString(step.label_with_invocation.invocation.path));
            }
        }
        for (cont.continuations) |*nested| {
            try self.collectContinuationInvocations(nested, invocations);
        }
    }

    /// Forward flood: an is_threaded proc is dirty; a dirty proc dirties every
    /// event it calls; a dirty event dirties every proc implementing it;
    /// iterate to fixpoint.
    fn floodDirty(self: *ThreadedChecker, source: *ast.Program) !void {
        var changed = true;
        while (changed) {
            changed = false;
            try self.floodItems(source.items, &changed);
        }
    }

    fn floodItems(self: *ThreadedChecker, items: []const ast.Item, changed: *bool) !void {
        for (items) |*item| {
            switch (item.*) {
                .proc_decl => |*proc| {
                    // A ~[threaded] root is dirty by declaration.
                    if (proc.is_threaded and !proc.is_threaded_dirty) {
                        @constCast(proc).is_threaded_dirty = true;
                        changed.* = true;
                    }
                    if (!proc.is_threaded_dirty) continue;
                    // A dirty proc dirties every event it calls.
                    const proc_name = try self.pathToString(proc.path);
                    defer self.allocator.free(proc_name);
                    if (self.call_graph.get(proc_name)) |ci| {
                        for (ci.calls.items) |called| {
                            if (self.events.get(called)) |ev| {
                                if (!ev.is_threaded_dirty) {
                                    @constCast(ev).is_threaded_dirty = true;
                                    changed.* = true;
                                }
                            }
                        }
                    }
                },
                .event_decl => |*event| {
                    if (!event.is_threaded_dirty) continue;
                    // A dirty event dirties every proc implementing it —
                    // impl procs share the event's path suffix.
                    try self.dirtyImplsOf(event.path, items, changed);
                },
                .module_decl => |*module| {
                    try self.floodItems(module.items, changed);
                },
                else => {},
            }
        }
    }

    /// Dirties every proc_decl that implements `event_path` — impl procs carry
    /// `is_impl` and share the event path.
    fn dirtyImplsOf(self: *ThreadedChecker, event_path: ast.DottedPath, items: []const ast.Item, changed: *bool) !void {
        const event_name = try self.pathToString(event_path);
        defer self.allocator.free(event_name);
        for (items) |*item| {
            switch (item.*) {
                .proc_decl => |*proc| {
                    if (proc.is_threaded_dirty) continue;
                    const proc_name = try self.pathToString(proc.path);
                    defer self.allocator.free(proc_name);
                    if (std.mem.eql(u8, proc_name, event_name)) {
                        @constCast(proc).is_threaded_dirty = true;
                        changed.* = true;
                    }
                },
                .module_decl => |*module| {
                    try self.dirtyImplsOf(event_path, module.items, changed);
                },
                else => {},
            }
        }
    }

    fn pathToString(self: *ThreadedChecker, path: ast.DottedPath) ![]const u8 {
        return std.mem.join(self.allocator, ".", path.segments);
    }
};
