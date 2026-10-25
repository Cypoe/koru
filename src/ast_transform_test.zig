const std = @import("std");
const ast = @import("ast");
const Parser = @import("parser").Parser;
const ast_transform = @import("ast_transform");
const errors = @import("errors");

// =============================================================================
// hoistInvariantLoopPrefix — the `for ! each` invariant-prefix pass.
// Positive: leading steps that never read the item lift out of the loop and
// the each-arm keeps only the item-dependent tail. Negative: a leading step
// that reads the item leaves the body untouched.
// =============================================================================

fn findFlowBodyIn(items: []const ast.Item) ?*ast.Continuation {
    for (items) |*item| {
        switch (item.*) {
            .flow => |*flow| if (flow.impl_of == null) return @constCast(&flow.body),
            .module_decl => |*m| if (findFlowBodyIn(m.items)) |c| return c,
            else => {},
        }
    }
    return null;
}

fn invName(cont: *const ast.Continuation) ?[]const u8 {
    const n = cont.node orelse return null;
    const inv = switch (n) {
        .invocation => |iv| iv,
        else => return null,
    };
    if (inv.path.segments.len == 0) return null;
    return inv.path.segments[inv.path.segments.len - 1];
}

fn findArm(cont: *ast.Continuation, branch: []const u8) ?*ast.Continuation {
    for (@constCast(cont.continuations)) |*c| {
        if (std.mem.eql(u8, c.branch, branch)) return c;
    }
    return null;
}

// `build`'s impl is a bare self-call: the cleanliness walk only needs a
// same-module flow impl whose transitive callees are clean — a `.visiting`
// recursion edge is skipped. No stdlib exists in a unit parse, so an `if`
// builtin would instead read as an unknown callee and taint the chain.
const PosSrc =
    \\~pub tor build { d: i64 } -> i64
    \\
    \\~build = build(d: d - 1): r -> r
    \\
    \\~capture { acc: 0[i64] }
    \\! as g |> for(0..10)
    \\    ! each _ |> build(d: 3): v |> captured { acc: g.acc + v }
    \\| captured res -> res
;

const NegSrc =
    \\~pub tor build { d: i64 } -> i64
    \\
    \\~build = build(d: d - 1): r -> r
    \\
    \\~capture { acc: 0[i64] }
    \\! as g |> for(1..5)
    \\    ! each i |> build(d: i): v |> captured { acc: g.acc + v }
    \\| captured res -> res
;

test "invariant leading step lifts out of the each body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const empty_flags: []const []const u8 = &.{};
    var parser = try Parser.init(arena_alloc, PosSrc, "test.kz", empty_flags, null);
    defer parser.deinit();
    var parse_result = try parser.parse();
    defer parse_result.deinit();
    const source_file = &parse_result.source_file;

    var reporter = try errors.ErrorReporter.init(std.testing.allocator, "test.kz", PosSrc);
    defer reporter.deinit();

    // pre-hoist sanity: `as` arm holds the for, each holds build as step 0
    const body = findFlowBodyIn(source_file.items).?;
    const as_arm = findArm(body, "as").?;
    try std.testing.expectEqualStrings("for", invName(as_arm).?);

    try ast_transform.hoistInvariantLoopPrefix(arena_alloc, source_file, &reporter);

    // post-hoist: `as` arm now begins at `build`; the for rides an unnamed
    // continuation under it, and each keeps only the captured tail.
    try std.testing.expectEqualStrings("build", invName(as_arm).?);
    try std.testing.expect(as_arm.continuations.len == 1);
    const next = @constCast(&as_arm.continuations[0]);
    try std.testing.expectEqualStrings("", next.branch);
    try std.testing.expectEqualStrings("for", invName(next).?);
    const each_arm = findArm(next, "each").?;
    try std.testing.expectEqualStrings("captured", invName(each_arm).?);
}

test "item-bound leading step is not hoisted" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const arena_alloc = arena.allocator();

    const empty_flags: []const []const u8 = &.{};
    var parser = try Parser.init(arena_alloc, NegSrc, "test.kz", empty_flags, null);
    defer parser.deinit();
    var parse_result = try parser.parse();
    defer parse_result.deinit();
    const source_file = &parse_result.source_file;

    var reporter = try errors.ErrorReporter.init(std.testing.allocator, "test.kz", NegSrc);
    defer reporter.deinit();

    const body = findFlowBodyIn(source_file.items).?;
    const as_arm = findArm(body, "as").?;
    try std.testing.expectEqualStrings("for", invName(as_arm).?);

    try ast_transform.hoistInvariantLoopPrefix(arena_alloc, source_file, &reporter);

    // untouched: `as` still holds the for directly, each still starts at build
    try std.testing.expectEqualStrings("for", invName(as_arm).?);
    const each_arm = findArm(as_arm, "each").?;
    try std.testing.expectEqualStrings("build", invName(each_arm).?);
}
