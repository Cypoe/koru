// Primitive price list — the bare-array twin.
//
// Every arm isolates ONE emitted shape and answers "what does this op cost
// when nothing else is in the loop". The Koru side spells the same work
// through std/store's machinery; the delta between matched arms is the price
// of that machinery — resolve, write-through, event call, announce, mint —
// attributed per-op rather than smeared across a scenario.
//
// Sinks are bit-identical with koru_price by construction; a divergence is a
// semantic bug in a port, not a performance note.

const std = @import("std");

const N = 100_000;

var hp: [N]i32 = undefined;
var act: [N]i32 = undefined;
var on: [N]i32 = undefined;
var gi: [N]i64 = undefined; // indirection table — koru's handle grid twin
var wv: [N]i64 = undefined; // watched column twin
var active: [N]usize = undefined;
var n_active: usize = 0;
var sink: i64 = 0;
var fresh_hp: [N]i32 = undefined;
var fresh_act: [N]i32 = undefined; // indexable column — insert_idx twin

// The accumulator reads a memory cell (`gi[i]`) so LLVM cannot close-form
// the loop — a pure function of `i` folds to a constant and the arm times
// nothing, while a serial recurrence's latency hides the machinery.
fn ping(v: i64) void {
    sink +%= v;
}

fn timed(scenario: []const u8, entities: usize, frames: usize) !u64 {
    const n = entities;
    const t0 = std.time.nanoTimestamp();

    if (std.mem.eql(u8, scenario, "read_row")) {
        for (0..frames) |_| {
            for (0..n) |i| sink +%= hp[i];
        }
    } else if (std.mem.eql(u8, scenario, "capture_for")) {
        // Register fold over a counted loop — koru's `capture` cell twin.
        // The cell is fresh per frame, folded into the sink once at the end.
        for (0..frames) |_| {
            var s: i64 = 0;
            for (0..n) |i| s +%= gi[i];
            sink +%= s;
        }
    } else if (std.mem.eql(u8, scenario, "read_handle")) {
        for (0..frames) |_| {
            for (0..n) |i| sink +%= hp[@intCast(gi[i])];
        }
    } else if (std.mem.eql(u8, scenario, "write_row")) {
        for (0..frames) |_| {
            for (0..n) |i| hp[i] -%= 1;
        }
    } else if (std.mem.eql(u8, scenario, "write_handle")) {
        for (0..frames) |_| {
            for (0..n) |i| hp[@intCast(gi[i])] -%= 1;
        }
    } else if (std.mem.eql(u8, scenario, "write_sink")) {
        for (0..frames) |_| {
            for (0..n) |i| ping(gi[i]);
        }
    } else if (std.mem.eql(u8, scenario, "event_call")) {
        for (0..frames) |_| {
            for (0..n) |i| ping(gi[i]);
        }
    } else if (std.mem.eql(u8, scenario, "insert")) {
        for (0..n) |i| fresh_hp[i] = @intCast(@mod(i * 7, 1000));
    } else if (std.mem.eql(u8, scenario, "insert_idx")) {
        // Koru pays the index join on top of this; the twin is identical work.
        for (0..n) |i| {
            fresh_hp[i] = @intCast(@mod(i * 7, 1000));
            fresh_act[i] = @intFromBool(i % 10 == 0);
        }
    } else if (std.mem.eql(u8, scenario, "drain")) {
        // Swap-remove teardown of every row.
        var len = n;
        const i: usize = 0;
        while (i < len) {
            hp[i] = hp[len - 1];
            len -= 1;
        }
        sink +%= @intCast(len);
    } else if (std.mem.eql(u8, scenario, "routed")) {
        for (0..frames) |_| {
            for (active[0..n_active]) |i| sink +%= hp[i];
        }
    } else if (std.mem.eql(u8, scenario, "guarded")) {
        for (0..frames) |_| {
            for (0..n) |i| {
                if (on[i] == 1) sink +%= hp[i];
            }
        }
    } else if (std.mem.eql(u8, scenario, "watch")) {
        for (0..frames) |_| {
            for (0..n) |i| {
                wv[i] +%= 1;
                sink +%= 1; // the watch body
            }
        }
    } else if (std.mem.eql(u8, scenario, "grid")) {
        for (0..frames) |_| {
            for (0..n) |i| gi[i] +%= 1;
        }
    } else {
        return error.UnknownScenario;
    }

    return @intCast(std.time.nanoTimestamp() - t0);
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next();
    var scenario: []const u8 = "";
    var entities: usize = N;
    var frames: usize = 100;
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--scenario")) {
            scenario = args.next() orelse return error.MissingScenario;
        } else if (std.mem.eql(u8, a, "--entities")) {
            entities = try std.fmt.parseInt(usize, args.next() orelse return error.MissingEntities, 10);
        } else if (std.mem.eql(u8, a, "--frames")) {
            frames = try std.fmt.parseInt(usize, args.next() orelse return error.MissingFrames, 10);
        }
    }

    // Untimed prep — the state every arm starts from.
    for (0..N) |i| {
        hp[i] = @intCast(@mod(i * 7, 1000));
        act[i] = @intFromBool(i % 10 == 0);
        on[i] = @intFromBool(i % 8 == 0);
        gi[i] = @intCast(i);
        wv[i] = 0;
    }
    n_active = 0;
    for (0..entities) |i| {
        if (act[i] == 1) {
            active[n_active] = i;
            n_active += 1;
        }
    }

    const start = std.time.nanoTimestamp();
    const timed_ns = try timed(scenario, entities, frames);
    _ = start;

    // Post-state checksum, untimed — write arms fold the store back in here.
    if (std.mem.eql(u8, scenario, "write_row") or std.mem.eql(u8, scenario, "write_handle")) {
        for (0..entities) |i| sink +%= hp[i];
    }
    if (std.mem.eql(u8, scenario, "grid")) {
        for (0..entities) |i| sink +%= gi[i];
    }
    if (std.mem.eql(u8, scenario, "watch")) {
        for (0..entities) |i| sink +%= wv[i];
    }
    if (std.mem.eql(u8, scenario, "insert") or std.mem.eql(u8, scenario, "insert_idx")) {
        for (0..entities) |i| sink +%= fresh_hp[i];
    }

    var buf: [512]u8 = undefined;
    const out = try std.fmt.bufPrint(&buf, "{{\"impl\":\"zig_flat\",\"scenario\":\"{s}\",\"entities\":{d},\"frames\":{d},\"elapsed_ns\":{d},\"sink\":{d}}}\n", .{ scenario, entities, frames, timed_ns, sink });
    try std.fs.File.stdout().writeAll(out);
}
