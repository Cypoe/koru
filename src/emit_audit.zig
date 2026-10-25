//! emit_audit — the dual-answer audit for emit_walk's sole-source writes.
//!
//! The walk's text is what emits; the lane's legacy renderer (the
//! "oracle") renders into scratch beside it under state isolation —
//! minting counters restored, buf swapped — so its render is comparable
//! but its side effects are discarded. Divergence is drift: logged to
//! `catalog_drift.log` and both texts dumped beside it, never fatal.
//! The scaffold lives here so the emitter reads as calls to the walk,
//! not as the audit machinery itself.

const std = @import("std");
const driftLog = @import("codegen_utils").driftLog;

/// Byte-compare the oracle's scratch render against the walk's emitted
/// text; a mismatch logs drift and writes `drift_oracle_<key>.c` /
/// `drift_walk_<key>.c` beside the log so the divergence is inspectable
/// without rerunning.
pub fn compare(
    comptime label: []const u8,
    allocator: std.mem.Allocator,
    key: []const u8,
    oracle_bytes: []const u8,
    walk_bytes: []const u8,
) void {
    if (std.mem.eql(u8, oracle_bytes, walk_bytes)) return;
    driftLog("std/target drift: emit-walk " ++ label ++ " `{s}` bytes differ (walk wins)\n", .{key});
    const oname = std.fmt.allocPrint(allocator, "drift_oracle_{s}.c", .{std.fs.path.basename(key)}) catch null;
    const wname = std.fmt.allocPrint(allocator, "drift_walk_{s}.c", .{std.fs.path.basename(key)}) catch null;
    if (oname) |n| {
        std.fs.cwd().writeFile(.{ .sub_path = n, .data = oracle_bytes }) catch {};
    }
    if (wname) |n| {
        std.fs.cwd().writeFile(.{ .sub_path = n, .data = walk_bytes }) catch {};
    }
}

/// The oracle refused during its audit render — worth logging only
/// when the walk emitted anyway (walk accepts what the lane refused:
/// the migration's sharpest divergence direction).
pub fn oracleErrored(comptime label: []const u8, key: []const u8, err_name: []const u8) void {
    driftLog("std/target drift: oracle " ++ label ++ " `{s}` errored {s} (walk wins)\n", .{ key, err_name });
}

/// The walk refused where the oracle emitted — the migration made the
/// lane stricter at this construct. Logged before the refusal
/// propagates as the lane's own; the oracle's render already printed
/// its diagnostic only if it refused too.
pub fn walkRefusedPastOracle(comptime label: []const u8, key: []const u8, err_name: []const u8) void {
    driftLog("std/target drift: emit-walk " ++ label ++ " `{s}` refused {s} where oracle emitted (walk is the lane)\n", .{ key, err_name });
}
