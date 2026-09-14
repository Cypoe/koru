// Self-invoking transform module. The top-level `install(mymod)` flow is a
// transform SITE: the pass runner walks module_decl items, matches this
// invocation against the `install` transform entry, and fires it at Stage C.
// It must self-replace — a declined SiteResult only removes top-level flows,
// never one nested in a module_decl, so an empty return would leave a dead
// runtime call to `mymod:install` in the emitted program. `expr` is a
// required call input, so the self-invocation passes a token argument.
// `expr` is the only call input the site supplies; `item` is the transform
// ABI handle. `allocator`/`reporter`/`program` are omitted — the ABI binds
// params by name, and `std.mem.Allocator` cannot be spelled in a `.k`
// signature anyway (no host lines).
[comptime|transform]pub tor install {
    expr: Expression,
    item: *const std/compiler:Item
} -> SiteResult

proc install|zig {
    const std = @import("std");
    const ast = @import("ast");
    _ = expr;

    const flow = if (item.* == .flow)
        &item.flow
    else
        return .{};

    std.debug.print("mymod install fired\n", .{});
    return .{ .replacement = ast.Item{ .inline_code = ast.InlineCode{
        .code = "// install dissolved",
        .location = flow.location,
        .module = flow.module,
    } } };
}

install(mymod)
