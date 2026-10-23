const std = @import("std");

// Builds libspike — the mounted scope module for 440_056. The koru repo
// root comes in as -Dkoru_root so the module links the compiler's own
// ast.zig: Invocation is too large a layout to mirror.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const koru_root = b.option([]const u8, "koru_root", "path to the koru repo root") orelse
        @panic("pass -Dkoru_root=<path to koru repo>");

    const errors_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ koru_root, "src/errors.zig" }) },
        .target = target,
        .optimize = optimize,
    });
    const gpm_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ koru_root, "src/glob_pattern_matcher.zig" }) },
        .target = target,
        .optimize = optimize,
    });
    const ast_mod = b.createModule(.{
        .root_source_file = .{ .cwd_relative = b.pathJoin(&.{ koru_root, "src/ast.zig" }) },
        .target = target,
        .optimize = optimize,
    });
    ast_mod.addImport("errors", errors_mod);
    ast_mod.addImport("glob_pattern_matcher", gpm_mod);

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "spike",
        .root_module = b.createModule(.{
            .root_source_file = b.path("module.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addImport("ast", ast_mod);
    lib.linkLibC();
    b.installArtifact(lib);
}
