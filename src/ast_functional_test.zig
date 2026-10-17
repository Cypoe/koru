const std = @import("std");
const testing = std.testing;
const ast = @import("ast");
const ast_functional = @import("ast_functional");
const ast_json = @import("ast_json");

fn makeInvocation(allocator: std.mem.Allocator, name: []const u8) !ast.Invocation {
    const segments = try allocator.alloc([]const u8, 1);
    segments[0] = try allocator.dupe(u8, name);

    return ast.Invocation{
        .path = ast.DottedPath{
            .module_qualifier = null,
            .segments = segments,
        },
        .args = try allocator.alloc(ast.Arg, 0),
        .annotations = try allocator.alloc([]const u8, 0),
    };
}

test "findContinuationContainingInvocation returns the owning continuation" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const target_invocation = try makeInvocation(allocator, "pairwise");
    const nested = try allocator.alloc(ast.Continuation, 1);
    nested[0] = ast.Continuation{
        .branch = try allocator.dupe(u8, "kernel"),
        .binding = try allocator.dupe(u8, "k"),
        .condition = null,
        .node = ast.Node{ .invocation = target_invocation },
        .indent = 4,
        .continuations = try allocator.alloc(ast.Continuation, 0),
    };

    const root = try allocator.alloc(ast.Continuation, 1);
    root[0] = ast.Continuation{
        .branch = try allocator.dupe(u8, "ok"),
        .binding = null,
        .condition = null,
        .node = null,
        .indent = 0,
        .continuations = nested,
    };

    const found = ast_functional.findContinuationContainingInvocation(root, &nested[0].node.?.invocation);
    try testing.expect(found != null);
    try testing.expect(found.? == &nested[0]);
}

test "walkLexicalContinuationSubtree visits lexical nodes in order" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const child_continuations = try allocator.alloc(ast.Continuation, 1);
    child_continuations[0] = ast.Continuation{
        .branch = try allocator.dupe(u8, "done"),
        .binding = null,
        .condition = null,
        .node = ast.Node{ .branch_constructor = .{
            .branch_name = try allocator.dupe(u8, "done"),
            .fields = try allocator.alloc(ast.Field, 0),
        } },
        .indent = 4,
        .continuations = try allocator.alloc(ast.Continuation, 0),
    };

    const root = ast.Continuation{
        .branch = try allocator.dupe(u8, "kernel"),
        .binding = try allocator.dupe(u8, "k"),
        .condition = null,
        .node = ast.Node{ .invocation = try makeInvocation(allocator, "pairwise") },
        .indent = 0,
        .continuations = child_continuations,
    };

    const Seen = struct {
        items: [4][]const u8 = undefined,
        len: usize = 0,

        fn push(self: *@This(), item: []const u8) void {
            self.items[self.len] = item;
            self.len += 1;
        }

        fn visit(self: *@This(), visit_info: ast_functional.LexicalSubtreeVisit) !ast_functional.LexicalSubtreeWalkControl {
            switch (visit_info) {
                .continuation => |cont| self.push(cont.branch),
                .invocation => |info| self.push(info.invocation.path.segments[0]),
                .node => |info| switch (info.node.*) {
                    .branch_constructor => self.push("branch_constructor"),
                    else => self.push("node"),
                },
            }
            return .continue_walk;
        }
    };

    var seen = Seen{};
    try ast_functional.walkLexicalContinuationSubtree(Seen, &root, &seen, Seen.visit);

    try testing.expectEqual(@as(usize, 4), seen.len);
    try testing.expectEqualStrings("kernel", seen.items[0]);
    try testing.expectEqualStrings("pairwise", seen.items[1]);
    try testing.expectEqualStrings("done", seen.items[2]);
    try testing.expectEqualStrings("branch_constructor", seen.items[3]);
}

// ── clone preserves the canonical view ──────────────────────────────────────
// transform_pass_runner.itemDigest fingerprints an item by serializeCanon;
// a clone that silently resets a serialized field reports a different item
// than the one it cloned. These tests pin byte-identical canonical output
// across cloneItem for every field class that has drifted.

fn canonBytes(allocator: std.mem.Allocator, item: *const ast.Item) ![]u8 {
    const one = [_]ast.Item{item.*};
    const view = ast.Program{
        .items = &one,
        .main_module_name = "input",
        .allocator = allocator,
    };
    return ast_json.serializeCanon(allocator, &view);
}

fn expectCloneCanonStable(allocator: std.mem.Allocator, item: *const ast.Item) !void {
    const before = try canonBytes(allocator, item);
    var cloned = try ast_functional.cloneItem(allocator, item);
    const after = try canonBytes(allocator, &cloned);
    try testing.expectEqualStrings(before, after);
}

fn makeDottedPath(allocator: std.mem.Allocator, segments: []const []const u8) !ast.DottedPath {
    const segs = try allocator.alloc([]const u8, segments.len);
    for (segments, 0..) |s, i| segs[i] = try allocator.dupe(u8, s);
    return .{ .segments = segs };
}

fn makeLeafFlow(allocator: std.mem.Allocator, event_name: []const u8) !ast.Flow {
    const conts = try allocator.alloc(ast.Continuation, 1);
    conts[0] = .{
        .branch = try allocator.dupe(u8, "ok"),
        .binding = null,
        .condition = null,
        .node = null,
        .indent = 0,
        .continuations = try allocator.alloc(ast.Continuation, 0),
    };
    return .{
        .body = ast.rootSite(try makeInvocation(allocator, event_name), conts, .{ .file = "test", .line = 0, .column = 0 }),
    };
}

test "cloneItem preserves canonical digest: proc_decl is_public + inline_flows" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const inline_flows = try allocator.alloc(ast.Flow, 1);
    inline_flows[0] = try makeLeafFlow(allocator, "inner");
    inline_flows[0].impl_of = try makeDottedPath(allocator, &.{ "lib", "outer" });
    inline_flows[0].is_impl = true;

    const proc = ast.Item{ .proc_decl = .{
        .path = try makeDottedPath(allocator, &.{"worker"}),
        .body = .{ .text = try allocator.dupe(u8, "return 1;"), .scope = .{ .bindings = &.{} } },
        .inline_flows = inline_flows,
        .is_public = true,
    } };
    try expectCloneCanonStable(allocator, &proc);
}

test "cloneItem preserves canonical digest: immediate_impl is_impl" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ii = ast.Item{ .immediate_impl = .{
        .event_path = try makeDottedPath(allocator, &.{ "lib", "cfg" }),
        .value = .{ .branch_name = try allocator.dupe(u8, "loaded"), .fields = try allocator.alloc(ast.Field, 0) },
        .is_impl = true,
    } };
    try expectCloneCanonStable(allocator, &ii);
}

test "cloneItem preserves canonical digest: event_tap annotations" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const anns = try allocator.alloc([]const u8, 2);
    anns[0] = try allocator.dupe(u8, "debug");
    anns[1] = try allocator.dupe(u8, "trace");

    const tap = ast.Item{ .event_tap = .{
        .source = try makeDottedPath(allocator, &.{"emit"}),
        .destination = null,
        .continuations = try allocator.alloc(ast.Continuation, 0),
        .is_input_tap = true,
        .annotations = anns,
    } };
    try expectCloneCanonStable(allocator, &tap);
}

test "cloneItem preserves canonical digest: flow super_shape + arg had_explicit_label" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const variants = try allocator.alloc(ast.SuperShape.BranchVariant, 1);
    variants[0] = .{
        .name = try allocator.dupe(u8, "ok"),
        .payload = .{ .fields = &.{} },
        .sources = try allocator.alloc(ast.DottedPath, 0),
    };

    const args = try allocator.alloc(ast.Arg, 1);
    args[0] = .{
        .name = try allocator.dupe(u8, "n"),
        .value = try allocator.dupe(u8, "1"),
        .had_explicit_label = true,
    };

    var flow = try makeLeafFlow(allocator, "pick");
    flow.super_shape = .{ .branches = variants };
    flow.body.node.?.invocation.args = args;

    const item = ast.Item{ .flow = flow };
    try expectCloneCanonStable(allocator, &item);
}

test "cloneItem preserves canonical digest: facet_decl field alts" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const alts = try allocator.alloc(i64, 2);
    alts[0] = 1;
    alts[1] = 7;
    const fields = try allocator.alloc(ast.FacetField, 1);
    fields[0] = .{
        .name = try allocator.dupe(u8, "port"),
        .type = try allocator.dupe(u8, "i64"),
        .alts = alts,
        .alt_default = 7,
    };

    const fd = ast.Item{ .facet_decl = .{
        .name = try allocator.dupe(u8, "Server"),
        .module = try allocator.dupe(u8, "app"),
        .fields = fields,
    } };
    try expectCloneCanonStable(allocator, &fd);
}

test "cloneItem preserves canonical digest: tap-marked step flags" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const conts = try allocator.alloc(ast.Continuation, 2);
    conts[0] = .{
        .branch = try allocator.dupe(u8, "guarded"),
        .binding = null,
        .condition = null,
        .node = .{ .conditional_block = .{
            .condition = try allocator.dupe(u8, "x > 0"),
            .condition_expr = null,
            .nodes = try allocator.alloc(ast.Node, 0),
            .inserted_by_tap = true,
            .from_opaque_tap = true,
        } },
        .indent = 0,
        .continuations = try allocator.alloc(ast.Continuation, 0),
    };
    conts[1] = .{
        .branch = try allocator.dupe(u8, "meta"),
        .binding = null,
        .condition = null,
        .node = .{ .metatype_binding = .{
            .metatype = try allocator.dupe(u8, "Audit"),
            .binding = try allocator.dupe(u8, "a"),
            .source_event = try allocator.dupe(u8, "src"),
            .dest_event = null,
            .branch = try allocator.dupe(u8, "done"),
            .inserted_by_tap = true,
        } },
        .indent = 0,
        .continuations = try allocator.alloc(ast.Continuation, 0),
    };

    const item = ast.Item{ .flow = .{
        .body = ast.rootSite(try makeInvocation(allocator, "emit"), conts, .{ .file = "test", .line = 0, .column = 0 }),
    } };
    try expectCloneCanonStable(allocator, &item);
}

test "cloneItem preserves canonical digest: module_decl nesting drift carriers" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const anns = try allocator.alloc([]const u8, 1);
    anns[0] = try allocator.dupe(u8, "debug");

    const items = try allocator.alloc(ast.Item, 3);
    items[0] = .{ .proc_decl = .{
        .path = try makeDottedPath(allocator, &.{"worker"}),
        .body = .{ .text = try allocator.dupe(u8, "return 1;"), .scope = .{ .bindings = &.{} } },
        .is_public = true,
    } };
    items[1] = .{ .immediate_impl = .{
        .event_path = try makeDottedPath(allocator, &.{ "lib", "cfg" }),
        .value = .{ .branch_name = try allocator.dupe(u8, "loaded"), .fields = try allocator.alloc(ast.Field, 0) },
        .is_impl = true,
    } };
    items[2] = .{ .event_tap = .{
        .source = null,
        .destination = null,
        .continuations = try allocator.alloc(ast.Continuation, 0),
        .is_input_tap = false,
        .annotations = anns,
    } };

    const module = ast.Item{ .module_decl = .{
        .logical_name = try allocator.dupe(u8, "mymod"),
        .canonical_path = try allocator.dupe(u8, "lib/mymod"),
        .items = items,
        .is_system = false,
    } };
    try expectCloneCanonStable(allocator, &module);
}
