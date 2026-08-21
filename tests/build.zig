const std = @import("std");
const build_crab = @import("build_crab");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigbuild_dep = b.dependency("zigbuild", .{});

    const zigbuild_tests: []const []const u8 = &.{
        // test depends on env: tries to search FHS /
        // "bindgen-exhaustive",
        "hello-aws-lc-rs",
        // requires cmake
        "hello-cmake",
        "hello-rustls",
        // needs gnumake
        "hello-tls",
        // this test seems broken upstream
        // "hello-windows",
        "libhello",
        "target-cpu",
    };

    for (zigbuild_tests) |case| {
        const cargo = build_crab.addCargoBuild(b, .{
            .manifest_path = zigbuild_dep.path(b.pathJoin(&.{ "tests", case, "Cargo.toml" })),
            .cargo_args = &.{"--quiet"},
        }, .{
            .optimize = optimize,
            .target = target,
        });
        const install = b.addInstallDirectory(.{ .source_dir = cargo, .install_dir = .prefix, .install_subdir = "install" });
        b.default_step.dependOn(&install.step);
    }
}
