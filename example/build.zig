const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const build_crab = b.dependency("build.crab", .{});
    const run_build_crab = b.addRunArtifact(build_crab.artifact("build_crab"));

    run_build_crab.addArg("--out");
    const crate_lib_path = run_build_crab.addOutputFileArg("libcrate.a");

    run_build_crab.addArg("--deps");
    _ = run_build_crab.addDepFileOutputArg("libcrate.d");

    run_build_crab.addArg("--manifest-path");
    _ = run_build_crab.addFileArg(b.path("rust/Cargo.toml"));

    const cargo_target = b.addNamedWriteFiles("cargo-target");
    const target_dir = cargo_target.getDirectory();
    run_build_crab.addArg("--target-dir");
    run_build_crab.addDirectoryArg(target_dir);

    run_build_crab.addArgs(&[_][]const u8{
        "--",
        "--release",
        "--quiet",
    });

    lib_unit_tests.linkLibCpp();
    lib_unit_tests.addLibraryPath(crate_lib_path.dirname());
    lib_unit_tests.linkSystemLibrary("crate");

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
