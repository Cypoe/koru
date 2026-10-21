// baseline.zig — the speed-of-light arm: the SAME semantics the koru program
// measures (counter increment + durable write per turn), no interpreter, no
// bridge, no transform machinery. This is what the workload costs when the
// whole cell story is a hashmap lookup and a file write.
//
// The comparator question it answers: of the time a koru turn takes, how much
// is the materializer's I/O (shared cost) vs the interpreter/custody stack
// (the part a "runtime" would blame)? If koru-durable ≈ baseline-durable the
// machinery is free; the gap is the honest cost of the shape.
const std = @import("std");

const TURNS: usize = 60;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = gpa.allocator();

    // arm A: resident — map increment, no I/O
    var t0 = try std.time.Instant.now();
    var hits: i64 = 0;
    for (0..TURNS) |_| hits += 1;
    var t1 = try std.time.Instant.now();
    std.debug.print("baseline resident: {d:.3}ms for {d} turns\n", .{ @as(f64, @floatFromInt(t1.since(t0))) / 1e6, TURNS });

    // arm B: durable — increment + state.kv write per turn
    std.fs.cwd().makePath("/tmp/koru-bench-baseline/grain") catch {};
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, "/tmp/koru-bench-baseline/grain/state.kv", .{});
    t0 = try std.time.Instant.now();
    var dhits: i64 = 0;
    for (0..TURNS) |_| {
        dhits += 1;
        var buf: [256]u8 = undefined;
        const body = try std.fmt.bufPrint(&buf, "#shape=counter\n#shape_def=hits:u32\nhits={d}\n", .{dhits});
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = body });
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline durable: {d:.3}ms for {d} turns\n", .{ @as(f64, @floatFromInt(t1.since(t0))) / 1e6, TURNS });

    // arm D: durable+sync — same write, fsync'd per turn (celld's ack level)
    const spath = "/tmp/koru-bench-baseline/grain-s/state.kv";
    std.fs.cwd().makePath("/tmp/koru-bench-baseline/grain-s") catch {};
    t0 = try std.time.Instant.now();
    var shits: i64 = 0;
    for (0..TURNS) |_| {
        shits += 1;
        var buf: [256]u8 = undefined;
        const body = try std.fmt.bufPrint(&buf, "#shape=counter\n#shape_def=hits:u32\nhits={d}\n", .{shits});
        try std.fs.cwd().writeFile(.{ .sub_path = spath, .data = body });
        const sf = try std.fs.cwd().openFile(spath, .{});
        sf.sync() catch {};
        sf.close();
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline durable+sync: {d:.3}ms for {d} turns\n", .{ @as(f64, @floatFromInt(t1.since(t0))) / 1e6, TURNS });

    // arm C: activation — delete + rewrite the file (the hibernate/wake pair's
    // raw cost: create dir, write file, read file back)
    t0 = try std.time.Instant.now();
    for (0..TURNS) |_| {
        std.fs.cwd().deleteTree("/tmp/koru-bench-baseline/grain") catch {};
        std.fs.cwd().makePath("/tmp/koru-bench-baseline/grain") catch {};
        var buf: [256]u8 = undefined;
        const body = try std.fmt.bufPrint(&buf, "#shape=counter\n#shape_def=hits:u32\nhits={d}\n", .{dhits});
        try std.fs.cwd().writeFile(.{ .sub_path = path, .data = body });
        const back = try std.fs.cwd().readFileAlloc(a, path, 4096);
        a.free(back);
    }
    t1 = try std.time.Instant.now();
    std.debug.print("baseline activation: {d:.3}ms for {d} cycles\n", .{ @as(f64, @floatFromInt(t1.since(t0))) / 1e6, TURNS });
}
