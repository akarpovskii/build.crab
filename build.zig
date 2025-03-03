const std = @import("std");

pub usingnamespace @import("src/root.zig");

const BuildCrab = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("build_crab", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

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

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

const CargoConfig = struct {
    /// Path to Cargo.toml
    manifest_path: std.Build.LazyPath,

    /// `build`, `rustc`, `zigbuild`, etc.
    command: []const u8 = "build",

    /// Additional arguments to be forwarded to Cargo
    cargo_args: []const []const u8 = &.{},

    /// Target architecture.
    /// If null, build.zig will use gnu ABI on Windows.
    rust_target: Target = .{ .override = .{} },

    pub const Target = union(enum) {
        value: []const u8,
        override: PartialTarget,
    };

    pub const PartialTarget = struct {
        arch: ?BuildCrab.Arch = null,
        vendor: ?BuildCrab.Vendor = null,
        os: ?BuildCrab.Os = null,
        env: ?BuildCrab.Env = null,

        pub fn override(self: PartialTarget, target: BuildCrab.Target) BuildCrab.Target {
            var result = target;
            inline for (@typeInfo(@TypeOf(self)).@"struct".fields) |field| {
                const sf = @field(self, field.name);
                const rf = &@field(result, field.name);
                if (sf) |non_null| {
                    rf.* = non_null;
                }
            }
            return result;
        }
    };
};

/// Adds all the steps and dependencies required to build a Rust crate.
/// Returns a directory with all the artifacts produced by the crate.
/// If you need more flexibility, `build_crab` artifact can be used directly.
/// The `args` parameter is passed to `b.dependency`.
/// Use `args.target` to specify the target for cross-compilation.
/// Use `args.optimize` to set the optimization level of `build_crab` binaries.
pub fn addCargoBuild(b: *std.Build, config: CargoConfig, args: anytype) std.Build.LazyPath {
    const dep_args = overrideTargetUserInput(args);
    const build_crab_dep = b.dependency("build_crab", dep_args);
    const build_crab = b.addRunArtifact(build_crab_dep.artifact("build_crab"));

    build_crab.addArg("--command");
    build_crab.addArg(config.command);

    build_crab.addArg("--deps");
    _ = build_crab.addDepFileOutputArg("depinfo.d");

    build_crab.addArg("--manifest-path");
    _ = build_crab.addFileArg(config.manifest_path);

    build_crab.addArg("--target-dir");
    const target_dir = build_crab.addOutputDirectoryArg("build_crab_out");

    build_crab.addArg("--");

    switch (config.rust_target) {
        .value => {
            build_crab.addArg("--target");
            build_crab.addArg(config.rust_target.value);
        },
        .override => {
            var zig_target = targetFromUserInputOptions(args);
            if (zig_target.os.tag == .windows) {
                zig_target.abi = .gnu;
            }
            var rust_target = BuildCrab.Target.fromZig(zig_target) catch @panic("unable to convert target triple to Rust");
            rust_target = config.rust_target.override.override(rust_target);
            build_crab.addArg("--target");
            build_crab.addArg(b.fmt("{}", .{rust_target}));
        },
    }

    build_crab.addArgs(config.cargo_args);

    return target_dir;
}

const StripSymbolsConfig = struct {
    /// The name of the output file.
    name: []const u8,

    /// Path to .a archive
    archive: std.Build.LazyPath,

    /// List of symbols to remove from the archive
    symbols: []const []const u8,
};

/// Re-packs a static library removing object files containing `config.symbols`.
/// Only Windows is supported, does nothing on other systems.
/// If you need more flexibility, `strip_symbols` artifact can be used directly.
/// The `args` parameter is passed to `b.dependency`.
/// Use `args.target` to specify the target for cross-compilation.
/// Use `args.optimize` to set the optimization level of `build_crab` binaries.
pub fn addStripSymbols(b: *std.Build, config: StripSymbolsConfig, args: anytype) std.Build.LazyPath {
    const dep_args = overrideTargetUserInput(args);
    const build_crab = b.dependency("build_crab", dep_args);
    const strip_symbols = b.addRunArtifact(build_crab.artifact("strip_symbols"));

    strip_symbols.addArg("--archive");
    strip_symbols.addFileArg(config.archive);

    strip_symbols.addArg("--temp-dir");
    _ = strip_symbols.addOutputDirectoryArg("strip_symbols_tmp");

    for (config.symbols) |symbol| {
        strip_symbols.addArg("--remove-symbol");
        strip_symbols.addArg(symbol);
    }

    strip_symbols.addArg("--output");
    const out_file = strip_symbols.addOutputFileArg(config.name);

    const zig_target = targetFromUserInputOptions(args);
    strip_symbols.addArg("--os");
    strip_symbols.addArg(@tagName(zig_target.os.tag));

    return out_file;
}

const StaticlibConfig = struct {
    /// The name of the output file
    /// See StripSymbolsConfig
    name: []const u8,

    /// Path to Cargo.toml
    manifest_path: std.Build.LazyPath,

    /// `build`, `rustc`, `zigbuild`, etc.
    command: []const u8 = "build",

    /// Additional arguments to be forwarded to Cargo
    cargo_args: []const []const u8 = &.{},

    /// Target architecture.
    /// If null, build.zig will use gnu ABI on Windows.
    target: ?[]const u8 = null,
};

/// Deprecated: addStripSymbols no longer necessary, use addCargoBuild instead.
///
/// A combination of `addCargoBuild` and `addStripSymbols` that strips `___chkstk_ms` on Windows.
/// Returns a path to the generated library file.
/// The `args` parameter is passed to `b.dependency`.
/// Use `args.target` to specify the target for cross-compilation.
/// Use `args.optimize` to set the optimization level of `build_crab` binaries.
pub fn addRustStaticlib(b: *std.Build, config: StaticlibConfig, args: anytype) std.Build.LazyPath {
    std.log.warn("deprecated: use addCargoBuild instead", .{});
    const cargo_config: CargoConfig = .{
        .manifest_path = config.manifest_path,
        .command = config.command,
        .cargo_args = config.cargo_args,
        .target = config.target,
    };
    const crate_output = addCargoBuild(b, cargo_config, args);
    const crate_lib_path = crate_output.path(b, config.name);
    return crate_lib_path;
}

fn targetFromUserInputOptions(args: anytype) std.Target {
    inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
        const v = @field(args, field.name);
        const T = @TypeOf(v);
        switch (T) {
            std.Target.Query => return std.zig.system.resolveTargetQuery(v) catch
                @panic("failed to resolve target query"),
            std.Build.ResolvedTarget => return v.result,
            else => {},
        }
    }

    return @import("builtin").target;
}

fn overrideTargetUserInput(args: anytype) @TypeOf(args) {
    var new_args = args;
    const host_target = @import("builtin").target;
    inline for (@typeInfo(@TypeOf(args)).@"struct".fields) |field| {
        const v = &@field(new_args, field.name);
        const T = field.type;
        switch (T) {
            std.Target.Query => {
                v.* = std.Target.Query.fromTarget(host_target);
            },
            std.Build.ResolvedTarget => {
                v.* = .{
                    .query = std.Target.Query.fromTarget(host_target),
                    .result = host_target,
                };
            },
            else => {},
        }
    }

    return new_args;
}
