const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "build_crab",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const strip_symbols = b.addExecutable(.{
        .name = "strip_symbols",
        .root_source_file = b.path("src/strip_symbols.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(strip_symbols);

    const run_strip_symbols = b.addRunArtifact(strip_symbols);

    run_strip_symbols.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_strip_symbols.addArgs(args);
    }

    const run_strip_symbols_step = b.step("strip", "Run the app");
    run_strip_symbols_step.dependOn(&run_strip_symbols.step);
}
