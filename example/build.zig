const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const build_crab = @import("build.crab");

    var crate_lib_path = build_crab.addRustStaticlib(
        b,
        .{
            .name = "libcrate.a",
            .manifest_path = b.path("rust/Cargo.toml"),
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

    lib_unit_tests.linkLibCpp();
    lib_unit_tests.addLibraryPath(crate_lib_path.dirname());
    lib_unit_tests.linkSystemLibrary("crate");

    b.installArtifact(lib_unit_tests);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
