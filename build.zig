const std = @import("std");

pub const rust = @import("src/root.zig").rust;

const BuildCrab = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addModule("build_crab", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_tests = b.addTest(.{ .root_module = lib });
    const run_lib_tests = b.addRunArtifact(lib_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_tests.step);

    const build_crab = b.addExecutable(.{
        .name = "build_crab",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(build_crab);
    const run_build_crab = b.addRunArtifact(build_crab);
    run_build_crab.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_build_crab.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_build_crab.step);
}

const CargoConfig = struct {
    /// Path to Cargo.toml
    manifest_path: std.Build.LazyPath,

    /// `build`, `rustc`, `zigbuild`, etc.
    command: []const u8 = "build",

    /// Additional arguments to be forwarded to Cargo
    cargo_args: []const []const u8 = &.{},

    /// Target architecture.
    /// By default, build.crab will use gnu ABI on Windows.
    rust_target: Target = .{ .override = .{} },

    pub const Target = union(enum) {
        value: []const u8,
        override: PartialTarget,
    };

    pub const PartialTarget = struct {
        arch: ?BuildCrab.rust.Arch = null,
        vendor: ?BuildCrab.rust.Vendor = null,
        os: ?BuildCrab.rust.Os = null,
        env: ?BuildCrab.rust.Env = null,

        pub fn override(self: PartialTarget, target: BuildCrab.rust.Target) BuildCrab.rust.Target {
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
            var rust_target = BuildCrab.rust.Target.fromZig(zig_target) catch @panic("unable to convert target triple to Rust");
            rust_target = config.rust_target.override.override(rust_target);
            build_crab.addArg("--target");
            build_crab.addArg(b.fmt("{f}", .{rust_target}));
        },
    }

    build_crab.addArgs(config.cargo_args);

    return target_dir;
}

const StaticlibConfig = struct {
    /// The name of the output file
    name: []const u8,

    /// Path to Cargo.toml
    manifest_path: std.Build.LazyPath,

    /// `build`, `rustc`, `zigbuild`, etc.
    command: []const u8 = "build",

    /// Additional arguments to be forwarded to Cargo
    cargo_args: []const []const u8 = &.{},

    /// Target architecture.
    /// By default, build.crab will use gnu ABI on Windows.
    rust_target: CargoConfig.Target = .{ .override = .{} },
};

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
                v.* = std.Target.Query.fromTarget(&host_target);
            },
            std.Build.ResolvedTarget => {
                v.* = .{
                    .query = std.Target.Query.fromTarget(&host_target),
                    .result = host_target,
                };
            },
            else => {},
        }
    }

    return new_args;
}
