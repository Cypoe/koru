// baseline.zig — the speed-of-light arm: the SAME syscall sequences the
// fleet verbs perform, no interpreter, no dispatch, no record parsing beyond
// what the protocol itself requires. Answers: of the time a fleet verb takes,
// how much is the filesystem floor (shared cost) vs the runtime stack?
const std = @import("std");

const TURNS: usize = 60;
const W = "/tmp/koru-bench-fleet-baseline";

fn ensureDirs() !void {
    var pb: [1024]u8 = undefined;
    try std.fs.cwd().makePath(try std.fmt.bufPrint(&pb, "{s}/.fleet/owners", .{W}));
    try std.fs.cwd().makePath(try std.fmt.bufPrint(&pb, "{s}/.fleet/epochs", .{W}));
    try std.fs.cwd().makePath(try std.fmt.bufPrint(&pb, "{s}/.fleet/locks", .{W}));
}

fn ownerRead(id: []const u8) void {
    var pb: [1024]u8 = undefined;
    const p = std.fmt.bufPrint(&pb, "{s}/.fleet/owners/{s}", .{ W, id }) catch return;
    const f = std.fs.cwd().openFile(p, .{}) catch return;
    defer f.close();
    var buf: [4096]u8 = undefined;
    _ = f.read(&buf) catch return;
}

fn epochRead(id: []const u8) void {
    var pb: [1024]u8 = undefined;
    const p = std.fmt.bufPrint(&pb, "{s}/.fleet/epochs/{s}", .{ W, id }) catch return;
    const f = std.fs.cwd().openFile(p, .{}) catch return;
    defer f.close();
    var buf: [32]u8 = undefined;
    _ = f.read(&buf) catch return;
}

fn epochBump(id: []const u8) void {
    epochRead(id);
    var pb: [1024]u8 = undefined;
    const p = std.fmt.bufPrint(&pb, "{s}/.fleet/epochs/{s}", .{ W, id }) catch return;
    var tb: [1024]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tb, "{s}.tmp", .{p}) catch return;
    std.fs.cwd().writeFile(.{ .sub_path = tmp, .data = "1\n" }) catch return;
    std.fs.cwd().rename(tmp, p) catch {};
}

fn ownerWrite(id: []const u8) void {
    var pb: [1024]u8 = undefined;
    const p = std.fmt.bufPrint(&pb, "{s}/.fleet/owners/{s}", .{ W, id }) catch return;
    var tb: [1024]u8 = undefined;
    const tmp = std.fmt.bufPrint(&tb, "{s}.tmp", .{p}) catch return;
    std.fs.cwd().writeFile(.{ .sub_path = tmp, .data = "node=bench\nepoch=1\nuntil=0\n" }) catch return;
    std.fs.cwd().rename(tmp, p) catch {};
}

fn ms(t: u128) f64 {
    return @as(f64, @floatFromInt(t)) / 1e6;
}

pub fn main() !void {
    std.fs.cwd().deleteTree(W) catch {};
    try ensureDirs();

    // seeds
    ownerWrite("probe");
    ownerWrite("renewable");
    ownerWrite("seizable");

    var t0 = try std.time.Instant.now();
    var t1 = try std.time.Instant.now();

    // arm 1: owner — one record read
    t0 = try std.time.Instant.now();
    for (0..TURNS) |_| ownerRead("probe");
    t1 = try std.time.Instant.now();
    std.debug.print("baseline owner: {d:.3}ms for {d} probes\n", .{ ms(t1.since(t0)), TURNS });

    // arm 2: claim+release — CAS create + epoch bump + delete
    t0 = try std.time.Instant.now();
    for (0..TURNS) |_| {
        try ensureDirs();
        ownerRead("cycle"); // absent -> null
        epochRead("cycle");
        var pb: [1024]u8 = undefined;
        const p = try std.fmt.bufPrint(&pb, "{s}/.fleet/owners/cycle", .{W});
        const f = try std.fs.cwd().createFile(p, .{ .exclusive = true });
        f.writeAll("node=bench\nepoch=1\nuntil=0\n") catch {};
        f.close();
        epochBump("cycle");
        ownerRead("cycle"); // release's re-read
        std.fs.cwd().deleteFile(p) catch {};
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline claim+release: {d:.3}ms for {d} cycles\n", .{ ms(t1.since(t0)), TURNS });

    // arm 3: renew — lock + read + tmp+rename + unlock
    t0 = try std.time.Instant.now();
    for (0..TURNS) |_| {
        try ensureDirs();
        var lb: [1024]u8 = undefined;
        const lock = try std.fmt.bufPrint(&lb, "{s}/.fleet/locks/renewable", .{W});
        try std.fs.cwd().makeDir(lock);
        ownerRead("renewable");
        ownerWrite("renewable");
        std.fs.cwd().deleteDir(lock) catch {};
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline renew: {d:.3}ms for {d} renews\n", .{ ms(t1.since(t0)), TURNS });

    // arm 4: seize — lock + read + epoch bump + tmp+rename + unlock
    t0 = try std.time.Instant.now();
    for (0..TURNS) |_| {
        try ensureDirs();
        var lb: [1024]u8 = undefined;
        const lock = try std.fmt.bufPrint(&lb, "{s}/.fleet/locks/seizable", .{W});
        try std.fs.cwd().makeDir(lock);
        ownerRead("seizable");
        epochBump("seizable");
        ownerWrite("seizable");
        std.fs.cwd().deleteDir(lock) catch {};
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline seize: {d:.3}ms for {d} takeovers\n", .{ ms(t1.since(t0)), TURNS });
}
