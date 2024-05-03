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
    var crate_lib_path = run_build_crab.addOutputFileArg("libcrate.a");

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

    if (@import("builtin").target.os.tag == .windows) {
        run_build_crab.addArg("--target");
        run_build_crab.addArg("x86_64-pc-windows-gnu");

        // Both Rust and Zig define ___chkstk_ms on Windows with strong linking.
        // This leads to "duplicate symbol" error when linking Rust lib.
        // This step repacks the library archive removing the obj file containing ___chkstk_ms.
        // This is a hacky solution, but until either Rust or Zig make ___chkstk_ms have weak linking,
        // or allow to exclude compiler_rt.lib entirely, this is the best I could come up with.
        // And if you target windows-msvc, then you have to deal with msvcrt which is even more stupid.
        const strip_chkstk_ms = b.addRunArtifact(build_crab.artifact("strip_symbols"));
        strip_chkstk_ms.addArg("--archive");
        strip_chkstk_ms.addFileArg(crate_lib_path);
        strip_chkstk_ms.addArg("--temp-dir");
        strip_chkstk_ms.addDirectoryArg(target_dir);
        strip_chkstk_ms.addArg("--remove-symbol");
        strip_chkstk_ms.addArg("___chkstk_ms");
        strip_chkstk_ms.addArg("--output");
        crate_lib_path = strip_chkstk_ms.addOutputFileArg("libcrate.a");

        lib_unit_tests.linkLibC();
    }

    lib_unit_tests.linkLibCpp();
    lib_unit_tests.addLibraryPath(crate_lib_path.dirname());
    lib_unit_tests.linkSystemLibrary("crate");

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
