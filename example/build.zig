const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");
    const zigbuild = b.option(bool, "zigbuild", "Use cargo zigbuild") orelse false;

    const run_staticlib_test = linkRustLibrary(b, target, optimize, "staticlib", zigbuild);
    test_step.dependOn(&run_staticlib_test.step);

    const run_cdylib_staticlib_test = linkRustLibrary(b, target, optimize, "cdylib_staticlib", zigbuild);
    test_step.dependOn(&run_cdylib_staticlib_test.step);

    // Exclude from cross-compilation
    if (target.result.os.tag == @import("builtin").os.tag) {
        const run_cargo_build_test = addCargoBuild(b, target, optimize);
        test_step.dependOn(&run_cargo_build_test.step);
    }
}

/// Demonstrates how to build a Rust library and use it from Zig
/// See `src/root.zig` and `staticlib` crate for the source code.
pub fn linkRustLibrary(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    folder: []const u8,
    zigbuild: bool,
) *std.Build.Step.Run {
    const crate_artifacts = @import("build_crab").addCargoBuild(
        b,
        .{
            .manifest_path = b.path(b.fmt("{s}/Cargo.toml", .{folder})),
            // This is part of the CI pipeline.
            // Normally, you don't need to use zigbuild and can leave the default value unchanged.
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
    // Link the library
    lib_unit_tests.addLibraryPath(crate_artifacts);
    lib_unit_tests.root_module.linkSystemLibrary("crate", .{ .preferred_link_mode = .static });

    b.installArtifact(lib_unit_tests);

    return b.addRunArtifact(lib_unit_tests);
}

/// Demonstrates how to build a Rust crate and access its artifacts.
/// See `hello_world` crate for the source code.
pub fn addCargoBuild(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step.Run {
    const artifacts = @import("build_crab").addCargoBuild(
        b,
        .{
            .manifest_path = b.path("hello_world/Cargo.toml"),
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

    const exe_name = if (target.result.os.tag == .windows)
        "hello_world.exe"
    else
        "hello_world";

    const installed = b.addInstallBinFile(artifacts.path(b, exe_name), exe_name);
    const run_hello_world = b.addSystemCommand(&.{
        b.getInstallPath(installed.dir, installed.dest_rel_path),
    });
    run_hello_world.step.dependOn(&installed.step);

    run_hello_world.expectStdOutEqual("I'm using the library: 3\n");

    return run_hello_world;
}
