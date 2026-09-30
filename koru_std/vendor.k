// std/vendor — the copy in THIS tree is the module. The compiler pins it.
//
// Cargo.lock records a checksum of a registry tarball so cargo can re-fetch.
// That is not this module. `cargo vendor` copies crates into a directory cargo
// treats as read-only (edit via [patch] outside vendor/). That is not this
// module either.
//
// Acquire (`add` / `copy`) is how bytes arrive. `bindings` is what the program
// compiles. `vendor.lock` pins `as-copied` (upstream, never overwritten) and
// `as-compiled` (the tree the program builds). The difference is the patch.
// SHA-256 is assumed; this event does not prove collisions.
//
// `step` is the protocol: every (state, command) is `pin` or `refuse`.
// First match is the rule; unknown labels, then the refuses; pin is the rest.
// `[runtime]` is item-level so a program can name a cell without the module
// growing `|runtime`. Not `[comptime]`: a cond with pin/refuse residue is
// not foldable. `bindings` and `vendor` hash; they ask `step`.

[runtime] pub tor step { state: string, command: string }
| pin
| refuse string

step = cond(command)
| c _ when command != "add" and command != "copy" and command != "gate" and command != "check" and command != "diff" and command != "sync" => refuse "unreadable"
| c _ when state != "unpinned" and state != "unpatched" and state != "patched" and state != "drifted" and state != "not-recorded" and state != "corrupt" and state != "conflict" => refuse "unreadable"
| c _ when (command == "add" or command == "copy") and (state == "patched" or state == "drifted") => refuse "as-copied is never overwritten"
| c _ when state == "conflict" => refuse state
| c _ when state == "corrupt" and command != "sync" => refuse state
| c _ when (command == "gate" or command == "check" or command == "diff") and (state == "unpinned" or state == "drifted") => refuse state
| c _ => pin

[comptime|transform] pub tor bindings { source: Source, reporter: *std/compiler:ErrorReporter }

[comptime|command] pub tor vendor {
    program: *const Program,
    allocator: __koru_std.mem.Allocator,
    argv: []const []const u8,
}
