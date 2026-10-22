const std = @import("std");
const emit_build_zig = @import("emit_build_zig");
const compiler_requires = @import("compiler_requires");

/// `koruc bundle` — package a built executable as a macOS .app from its
/// std/build:app declaration.
///
/// The layout is the documented minimum: Contents/Info.plist, the binary in
/// Contents/MacOS named for CFBundleExecutable, an empty Resources/ dir, and
/// the legacy PkgInfo marker LaunchServices still reads. The disk plist comes
/// from the same generator as the binary's embedded __TEXT,__info_plist, so
/// codesign's cross-check of the two always sees one identity. The bundle is
/// adhoc-signed — enough for local run + LaunchServices registration; release
/// signing is a distribution concern and deliberately not defaulted here.
///
/// Icons, entitlements, and non-adhoc signing are the remaining surface a
/// future option (or a richer std/build:app key) decides — the declaration
/// refuses unknown keys today, so that space is unclaimed.
pub fn assembleMacApp(
    allocator: std.mem.Allocator,
    output_dir: []const u8,
    built_exe_name: []const u8,
    decl: compiler_requires.AppDecl,
    bundle_path_arg: ?[]const u8,
) ![]const u8 {
    const app_path = if (bundle_path_arg) |p| blk: {
        if (!std.mem.endsWith(u8, p, ".app")) {
            try printStderr(allocator, "error: bundle output must end in .app (got '{s}')\n", .{p});
            return error.InvalidBundlePath;
        }
        break :blk try allocator.dupe(u8, p);
    } else try std.fmt.allocPrint(allocator, "{s}.app", .{decl.name});
    errdefer allocator.free(app_path);

    var root = try std.fs.cwd().openDir(output_dir, .{});
    defer root.close();

    const contents = try std.fs.path.join(allocator, &.{ app_path, "Contents" });
    defer allocator.free(contents);
    const macos_dir = try std.fs.path.join(allocator, &.{ contents, "MacOS" });
    defer allocator.free(macos_dir);
    const resources_dir = try std.fs.path.join(allocator, &.{ contents, "Resources" });
    defer allocator.free(resources_dir);

    try root.makePath(macos_dir);
    try root.makePath(resources_dir);

    // The executable inside the bundle is named for CFBundleExecutable — the
    // same value appInfoPlistRequirement baked into the embedded section.
    const xml = try emit_build_zig.appInfoPlistXml(allocator, decl.name, decl.id, decl.version, decl.name);
    defer allocator.free(xml);
    const plist_path = try std.fs.path.join(allocator, &.{ contents, "Info.plist" });
    defer allocator.free(plist_path);
    try root.writeFile(.{ .sub_path = plist_path, .data = xml });

    const pkginfo_path = try std.fs.path.join(allocator, &.{ contents, "PkgInfo" });
    defer allocator.free(pkginfo_path);
    try root.writeFile(.{ .sub_path = pkginfo_path, .data = "APPL????" });

    const dst_exe = try std.fs.path.join(allocator, &.{ macos_dir, decl.name });
    defer allocator.free(dst_exe);
    try root.copyFile(built_exe_name, root, dst_exe, .{});
    // Executable bit: copyFile preserves mode, but a harness-provided or
    // cached binary could land without it — force 0755, no guessing.
    {
        const f = try root.openFile(dst_exe, .{});
        defer f.close();
        try f.chmod(0o755);
    }

    // Adhoc signature — seals the bundle for LaunchServices and proves the
    // embedded/disk plists agree (codesign compares them when it signs).
    const abs_app = try root.realpathAlloc(allocator, app_path);
    defer allocator.free(abs_app);
    const sign = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "codesign", "--force", "--sign", "-", abs_app },
    });
    defer allocator.free(sign.stdout);
    defer allocator.free(sign.stderr);
    switch (sign.term) {
        .Exited => |code| if (code != 0) {
            try printStderr(allocator, "error: codesign refused the bundle\n{s}", .{sign.stderr});
            return error.CodesignFailed;
        },
        else => {
            try printStderr(allocator, "error: codesign did not exit cleanly\n{s}", .{sign.stderr});
            return error.CodesignFailed;
        },
    }

    return app_path;
}

fn printStderr(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) !void {
    const msg = try std.fmt.allocPrint(allocator, fmt, args);
    defer allocator.free(msg);
    try std.fs.File.stderr().writeAll(msg);
}
