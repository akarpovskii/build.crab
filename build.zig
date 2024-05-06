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

const CargoConfig = struct {
    /// The name of the output file.
    /// It should match the actual file produced by Cargo (e.g. libCRATENAME.a)
    /// build.crab needs to know it beforehand to properly add the deps file dependency.
    name: []const u8,

    /// Path to Cargo.toml
    manifest_path: std.Build.LazyPath,

    /// If true, build.crab will use `cargo zigbuild` instead.
    zigbuild: bool = false,

    /// Additional arguments to be forwarded to Cargo
    cargo_args: []const []const u8 = &.{},

    /// Target architecture.
    /// If null, build.zig will use x86_64-pc-windows-gnu on Windows.
    target: ?[]const u8 = null,
};

/// See `addCargoBuildWithUserOptions` if you need to pass options to `b.dependency()`
pub fn addCargoBuild(b: *std.Build, config: CargoConfig) std.Build.LazyPath {
    return addCargoBuildWithUserOptions(b, config, .{});
}

/// Adds all the steps and dependencies required to build a Rust crate.
/// The crate must produce only one artifact (meaning shared libraries are not yet supported).
/// If you need more flexibility, `build_crab` artifact can be used directly.
pub fn addCargoBuildWithUserOptions(b: *std.Build, config: CargoConfig, args: anytype) std.Build.LazyPath {
    const @"build.crab" = b.dependency("build.crab", args);
    const build_crab = b.addRunArtifact(@"build.crab".artifact("build_crab"));

    if (config.zigbuild) {
        build_crab.addArg("--zigbuild");
    }

    const dep_filename = std.mem.concat(b.allocator, u8, &.{ std.fs.path.stem(config.name), ".d" }) catch @panic("OOM");
    build_crab.addArg("--deps");
    _ = build_crab.addDepFileOutputArg(dep_filename);

    build_crab.addArg("--manifest-path");
    _ = build_crab.addFileArg(config.manifest_path);

    const cargo_target = b.addWriteFiles();
    const target_dir = cargo_target.getDirectory();
    build_crab.addArg("--target-dir");
    build_crab.addDirectoryArg(target_dir);

    build_crab.addArg("--out");
    const lib_path = build_crab.addOutputFileArg(config.name);

    build_crab.addArg("--");

    if (config.target) |target| {
        build_crab.addArg("--target");
        build_crab.addArg(target);
    } else if (@import("builtin").target.os.tag == .windows) {
        build_crab.addArg("--target");
        build_crab.addArg("x86_64-pc-windows-gnu");
    }

    build_crab.addArgs(config.cargo_args);

    return lib_path;
}

const StripSymbolsConfig = struct {
    /// The name of the output file.
    name: []const u8,

    /// Path to .a archive
    archive: std.Build.LazyPath,

    /// List of symbols to remove from the archive
    symbols: []const []const u8,
};

/// See `addStripSymbolsWithUserOptions` if you need to pass options to `b.dependency()`
pub fn addStripSymbols(b: *std.Build, config: StripSymbolsConfig) std.Build.LazyPath {
    return addStripSymbolsWithUserOptions(b, config, .{});
}

/// Re-packs a static library removing object files containing `config.symbols`.
/// Only Windows is supported, does nothing on other systems.
/// If you need more flexibility, `strip_symbols` artifact can be used directly.
pub fn addStripSymbolsWithUserOptions(b: *std.Build, config: StripSymbolsConfig, args: anytype) std.Build.LazyPath {
    const @"build.crab" = b.dependency("build.crab", args);
    const strip_symbols = b.addRunArtifact(@"build.crab".artifact("strip_symbols"));

    strip_symbols.addArg("--archive");
    strip_symbols.addFileArg(config.archive);

    const temp_dir = b.addWriteFiles();
    strip_symbols.addArg("--temp-dir");
    strip_symbols.addDirectoryArg(temp_dir.getDirectory());

    for (config.symbols) |symbol| {
        strip_symbols.addArg("--remove-symbol");
        strip_symbols.addArg(symbol);
    }

    strip_symbols.addArg("--output");
    const out_file = strip_symbols.addOutputFileArg(config.name);

    return out_file;
}
