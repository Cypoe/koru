// baseline.zig — the mail-protocol floor: the same filesystem semantics the
// koru program pays (post = mkdir-p + tmp write + rename; drain = lock dir +
// owner read + dir iterate + per-mail read & delete), with no interpreter,
// no custody stack, no turn execution. The routed-turn gap above this floor
// is the runtime's real price.
const std = @import("std");

const TURNS: usize = 60;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    const inbox = "/tmp/koru-bench-mail-baseline/.fleet/inbox/grain";
    const world = "/tmp/koru-bench-mail-baseline";
    const id = "grain";

    // arm A: send — makePath(inbox) + writeFile(tmp) + rename per post
    var t0 = try std.time.Instant.now();
    for (0..TURNS) |i| {
        try std.fs.cwd().makePath(inbox);
        var nb: [128]u8 = undefined;
        const name = try std.fmt.bufPrint(&nb, "{d}-nodeb-{x}", .{ std.time.nanoTimestamp(), i });
        var pb: [1024]u8 = undefined;
        const p = try std.fmt.bufPrint(&pb, "{s}/{s}", .{ inbox, name });
        var tb: [1024]u8 = undefined;
        const tmp = try std.fmt.bufPrint(&tb, "{s}.tmp", .{p});
        var rb: [128]u8 = undefined;
        const rec = try std.fmt.bufPrint(&rb, "from=nodeb\ntouch(k: 1)", .{});
        try std.fs.cwd().writeFile(.{ .sub_path = tmp, .data = rec });
        try std.fs.cwd().rename(tmp, p);
    }
    var t1 = try std.time.Instant.now();
    std.debug.print("baseline send: {d:.3}ms for {d} posts\n", .{ @as(f64, @floatFromInt(t1.since(t0))) / 1e6, TURNS });

    // arm B: drain file lifecycle — lock + owner read + iterate + read+delete
    // per mail (the turn execution it would carry is priced separately in 013)
    t0 = try std.time.Instant.now();
    var lb: [1024]u8 = undefined;
    var ob: [1024]u8 = undefined;
    const opath = try std.fmt.bufPrint(&ob, "{s}/.fleet/owners/{s}", .{ world, id });
    std.fs.cwd().makePath(try std.fmt.bufPrint(&lb, "{s}/.fleet/owners", .{world})) catch {};
    std.fs.cwd().makePath(try std.fmt.bufPrint(&lb, "{s}/.fleet/locks", .{world})) catch {};
    const lock = try std.fmt.bufPrint(&lb, "{s}/.fleet/locks/{s}", .{ world, id });
    try std.fs.cwd().makeDir(lock);
    defer std.fs.cwd().deleteDir(lock) catch {};
    try std.fs.cwd().writeFile(.{ .sub_path = opath, .data = "node=nodea\nepoch=1\nuntil=0\n" });
    const _rec = try std.fs.cwd().readFileAlloc(a, opath, 4096);
    a.free(@constCast(_rec));
    var d = try std.fs.cwd().openDir(inbox, .{ .iterate = true });
    defer d.close();
    var names = std.ArrayList([]u8){};
    defer {
        for (names.items) |n| a.free(n);
        names.deinit(a);
    }
    var it = d.iterate();
    while (try it.next()) |ent| {
        if (ent.kind != .file) continue;
        try names.append(a, try a.dupe(u8, ent.name));
    }
    std.mem.sort([]u8, names.items, {}, struct {
        fn lt(_: void, x: []u8, y: []u8) bool {
            return std.mem.lessThan(u8, x, y);
        }
    }.lt);
    var delivered: i64 = 0;
    for (names.items) |name| {
        const content = try d.readFileAlloc(a, name, 1 << 20);
        a.free(content);
        d.deleteFile(name) catch {};
        delivered += 1;
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline drain-floor: {d:.3}ms for {d} mails\n", .{ @as(f64, @floatFromInt(t1.since(t0))) / 1e6, delivered });
}
