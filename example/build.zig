const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_crab = @import("build.crab");

    const folders: []const []const u8 = &.{
        "staticlib",
        "cdylib_staticlib",
    };

    const test_step = b.step("test", "Run unit tests");

    const zigbuild = b.option(bool, "zigbuild", "Use cargo zigbuild") orelse false;

    for (folders) |folder| {
        var crate_lib_path = build_crab.addRustStaticlib(
            b,
            .{
                .name = "libcrate.a",
                .manifest_path = b.path(b.fmt("{s}/Cargo.toml", .{folder})),
                .command = if (zigbuild) "zigbuild" else "build",
                .cargo_args = &.{
                    "--release",
                    "--quiet",
                },
            },
            .{
                .target = target,
                .optimize = optimize,
            },
        );

        const lib_unit_tests = b.addTest(.{
            .root_source_file = b.path("src/root.zig"),
            .name = b.fmt("test-{s}", .{folder}),
            .target = target,
            .optimize = optimize,
        });
        lib_unit_tests.linkLibCpp();
        lib_unit_tests.addLibraryPath(crate_lib_path.dirname());
        lib_unit_tests.root_module.linkSystemLibrary("crate", .{ .preferred_link_mode = .static });

        b.installArtifact(lib_unit_tests);

        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        test_step.dependOn(&run_lib_unit_tests.step);
    }
}
