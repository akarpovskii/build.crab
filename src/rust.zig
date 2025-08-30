const std = @import("std");

pub const Target = struct {
    arch: Arch,
    vendor: Vendor,
    os: Os,
    env: Env,

    pub fn fromZig(target: std.Target) error{Unsupported}!Target {
        return .{
            .arch = try Arch.fromZig(target),
            .vendor = try Vendor.fromZig(target),
            .os = try Os.fromZig(target.os),
            .env = try Env.fromZig(target),
        };
    }

    pub fn fromQuery(query: std.Target.Query) !Target {
        const target = try std.zig.system.resolveTargetQuery(query);
        return fromZig(target);
    }

    pub fn fromArchOsAbi(arch_os_abi: []const u8) !Target {
        const query = try std.Target.Query.parse(.{
            .arch_os_abi = arch_os_abi,
        });
        return fromQuery(query);
    }

    pub fn format(self: Target, writer: *std.Io.Writer) !void {
        if (self.arch == .wasm32 and (self.os == .wasip1 or self.os == .wasip2)) {
            try writer.print("{f}-{f}", .{ self.arch, self.os });
        } else if (self.env == .none) {
            try writer.print("{f}-{f}-{f}", .{ self.arch, self.vendor, self.os });
        } else if (self.vendor == .unknown and (self.env == .android or self.env == .androideabi)) {
            try writer.print("{f}-{f}-{f}", .{ self.arch, self.os, self.env });
        } else {
            try writer.print("{f}-{f}-{f}-{f}", .{ self.arch, self.vendor, self.os, self.env });
        }
    }
};

pub const Arch = union(enum) {
    aarch64,
    aarch64_be,
    arm,
    arm64_32,
    armeb,
    armebv7r,
    armv4t,
    armv5te,
    armv6,
    armv6k,
    arm7,
    arm7a,
    arm7k,
    arm7r,
    arm7s,
    asmjs,
    avr,
    bpfeb,
    bpfel,
    csky,
    hexagon,
    i386,
    i586,
    i686,
    loongarch64,
    m68k,
    mips,
    mips64,
    mips64el,
    mipsel,
    mipsisa32r6,
    mipsisa32r6el,
    mipsisa64r6,
    mipsisa64r6el,
    msp430,
    nvptx64,
    powerpc,
    powerpc64,
    powerpc64le,
    riscv32,
    riscv32e,
    riscv32em,
    riscv32emc,
    riscv32gc,
    riscv32i,
    riscv32im,
    riscv32ima,
    riscv32imac,
    riscv32imafc,
    riscv32imc,
    riscv64,
    riscv64gc,
    riscv64imac,
    s390x,
    sparc,
    sparc64,
    sparcv9,
    thumbv4t,
    thumbv5te,
    thumbv6m,
    thumbv7a,
    thumbv7em,
    thumbv7m,
    thumbv7neon,
    thumbv8m_base,
    thumbv8m_main,
    wasm32,
    wasm64,
    x86_64,
    x86_64h,
    xtensa,

    custom: []const u8,

    pub fn fromZig(target: std.Target) error{Unsupported}!Arch {
        return switch (target.cpu.arch) {
            .aarch64 => .aarch64,
            .aarch64_be => .aarch64_be,
            .arm => .arm,
            .armeb => .armeb,
            .avr => .avr,
            .bpfeb => .bpfeb,
            .bpfel => .bpfel,
            .csky => .csky,
            .hexagon => .hexagon,
            .loongarch64 => .loongarch64,
            .m68k => .m68k,
            .mips => .mips,
            .mips64 => .mips64,
            .mips64el => .mips64el,
            .mipsel => .mipsel,
            .msp430 => .msp430,
            .nvptx64 => .nvptx64,
            .powerpc => .powerpc,
            .powerpc64 => .powerpc64,
            .powerpc64le => .powerpc64le,
            .riscv32 => blk: {
                if (target.os.tag == .linux and (target.abi == .gnu or target.abi == .musl))
                    break :blk .riscv32gc
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .e, .m, .c }))
                    break :blk .riscv32emc
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .e, .m }))
                    break :blk .riscv32em
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{.e}))
                    break :blk .riscv32e
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .i, .m, .a, .f, .c }))
                    break :blk .riscv32imafc
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .i, .m, .a, .c }))
                    break :blk .riscv32imac
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .i, .m, .c }))
                    break :blk .riscv32imc
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .i, .m, .a }))
                    break :blk .riscv32ima
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{ .i, .m }))
                    break :blk .riscv32im
                else if (std.Target.riscv.featureSetHasAll(target.cpu.features, .{.i}))
                    break :blk .riscv32i
                else
                    break :blk .riscv32;
            },
            .riscv64 => blk: {
                // Rust only seems to have `riscv64-` for `linux-android`, `riscv64gc-` for
                // everything else. In fact they do the same translation in rust-bindgen:
                // https://github.com/rust-lang/rust-bindgen/blob/f518815cc14a7f8c292964bb37179a1070d7e18a/bindgen/lib.rs#L1341-L1344
                if (target.os.tag == .linux and
                    target.abi == .android) break :blk .riscv64;
                break :blk .riscv64gc;
            },
            .s390x => .s390x,
            .sparc => .sparc,
            .sparc64 => .sparc64,
            .wasm32 => .wasm32,
            .wasm64 => .wasm64,
            .x86 => .i686,
            .x86_64 => .x86_64,
            .xtensa => .xtensa,

            // .amdgcn, .arc, .thumb, .thumbeb, .kalimba, .lanai, .loongarch32, .nvptx, .powerpcle, .propeller, .spirv, .spirv32, .spirv64, .ve, .xcore
            else => error.Unsupported,
        };
    }

    pub fn format(self: Arch, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .custom => try writer.print("{s}", .{self.custom}),
            else => try writer.print("{s}", .{@tagName(self)}),
        }
    }
};

pub const Vendor = union(enum) {
    apple,
    esp,
    fortanix,
    ibm,
    kmc,
    linux,
    nintendo,
    none,
    nvidia,
    openwrt,
    pc,
    sony,
    sun,
    unikraft,
    unknown,
    uwp,
    wrc,

    custom: []const u8,

    pub fn fromZig(target: std.Target) error{Unsupported}!Vendor {
        return switch (target.os.tag) {
            .ios, .macos, .watchos, .tvos => .apple,
            .linux => .unknown,
            .windows => .pc,
            .solaris => .sun,
            .cuda => .nvidia,
            else => .unknown,
        };
    }

    pub fn format(self: Vendor, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .custom => try writer.print("{s}", .{self.custom}),
            else => try writer.print("{t}", .{self}),
        }
    }
};

pub const Os = union(enum) {
    @"3ds",
    aix,
    android,
    cuda,
    darwin,
    dragonfly,
    emscripten,
    espidf,
    freebsd,
    fuchsia,
    haiku,
    hermit,
    hurd,
    illumos,
    ios,
    l4re,
    linux,
    netbsd,
    none,
    nto,
    openbsd,
    psp,
    psx,
    redox,
    rtems,
    solaris,
    solid_asp3,
    @"switch",
    teeos,
    tvos,
    uefi,
    unknown,
    visionos,
    vita,
    vxworks,
    wasip1,
    wasip2,
    watchos,
    windows,
    xous,

    custom: []const u8,

    pub fn fromZig(os: std.Target.Os) error{Unsupported}!Os {
        return switch (os.tag) {
            .freestanding => .none,
            .dragonfly => .dragonfly,
            .freebsd => .freebsd,
            .fuchsia => .fuchsia,
            .ios => .ios,
            .linux => .linux,
            .macos => .darwin,
            .netbsd => .netbsd,
            .openbsd => .openbsd,
            .solaris => .solaris,
            .uefi => .uefi,
            .windows => .windows,
            .haiku => .haiku,
            .aix => .aix,
            .cuda => .cuda,
            .tvos => .tvos,
            .watchos => .watchos,
            .hermit => .hermit,
            .hurd => .hurd,
            .wasi => if (os.version_range.semver.includesVersion(.{ .major = 0, .minor = 1, .patch = 0 }))
                .wasip1
            else if (os.version_range.semver.includesVersion(.{ .major = 0, .minor = 2, .patch = 0 }))
                .wasip2
            else
                error.Unsupported,
            .emscripten => .emscripten,
            .illumos => .illumos,
            .other => .unknown,
            .rtems => .rtems,
            .visionos => .visionos,

            // .contiki, .elfiamcu, .plan9, .serenity, .zos, .driverkit, .ps3, .ps4, .ps5, .amdhsa, .amdpal, .mesa3d, .nvcl, .opencl, .opengl, .vulkan
            else => error.Unsupported,
        };
    }

    pub fn format(self: Os, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .custom => try writer.print("{s}", .{self.custom}),
            else => try writer.print("{s}", .{@tagName(self)}),
        }
    }
};

pub const Env = union(enum) {
    android,
    androideabi,
    eabi,
    eabihf,
    elf,
    freestanding,
    @"gnu-atmega328",
    gnu_ilp32,
    gnu,
    gnuabi64,
    gnuabiv2,
    gnueabi,
    gnueabihf,
    gnullvm,
    gnuspe,
    gnux32,
    macabi,
    msvc,
    musl,
    muslabi64,
    musleabi,
    musleabihf,
    none,
    ohos,
    @"preview1-threads",
    qnx700,
    qnx710,
    sgx,
    sim,
    softfloat,
    spe,
    uclibceabi,

    custom: []const u8,

    pub fn fromZig(target: std.Target) error{Unsupported}!Env {
        return switch (target.abi) {
            .none => blk: {
                if (target.cpu.arch.isRISCV())
                    break :blk switch (target.ofmt) {
                        .elf => .elf,
                        else => error.Unsupported,
                    };
                break :blk .none;
            },
            .gnu => blk: {
                // Rust only seems to have `-msvc` and `-gnullvm` for `aarch64-windows`
                // https://doc.rust-lang.org/rustc/platform-support/pc-windows-gnullvm.html
                if (target.cpu.arch == .aarch64 and
                    target.os.tag == .windows) break :blk .gnullvm;
                break :blk .gnu;
            },
            .gnuabi64 => .gnuabi64,
            .gnueabi => .gnueabi,
            .gnueabihf => .gnueabihf,
            .gnux32 => .gnux32,
            .eabi => .eabi,
            .eabihf => .eabihf,
            .android => switch (target.cpu.arch) {
                .aarch64, .riscv64, .x86, .x86_64 => .android,
                else => .androideabi,
            },
            .androideabi => .androideabi,
            .musl => .musl,
            .muslabi64 => .muslabi64,
            .musleabi => .musleabi,
            .musleabihf => .musleabihf,
            .msvc => .msvc,
            .macabi => .macabi,
            .ohos => .ohos,
            .simulator => .sim,

            // .code16, .itanium, .cygnus, .gnuabin32, .gnuf32, .gnusf, .gnu_ilp32, .ilp32, .muslabin32, .muslx32, .ohoseabi
            else => error.Unsupported,
        };
    }

    pub fn format(self: Env, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        switch (self) {
            .custom => try writer.print("{s}", .{self.custom}),
            else => try writer.print("{s}", .{@tagName(self)}),
        }
    }
};

test "tier 1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expectEqualStrings = std.testing.expectEqualStrings;

    // https://doc.rust-lang.org/rustc/platform-support.html#tier-1-with-host-tools

    {
        const target = try Target.fromArchOsAbi("aarch64-macos");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("aarch64-apple-darwin", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("aarch64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("aarch64-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86_64-macos");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("x86_64-apple-darwin", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86_64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("x86_64-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86-windows-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("i686-pc-windows-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("i686-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86_64-windows-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("x86_64-pc-windows-gnu", target_str);
    }
}

test "tier 2" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expectEqualStrings = std.testing.expectEqualStrings;

    // https://doc.rust-lang.org/rustc/platform-support.html#tier-2-with-host-tools

    {
        const target = try Target.fromArchOsAbi("aarch64-windows-msvc");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("aarch64-pc-windows-msvc", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("aarch64-linux-musl");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("aarch64-unknown-linux-musl", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("arm-linux-gnueabi");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("arm-unknown-linux-gnueabi", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("arm-linux-gnueabihf");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("arm-unknown-linux-gnueabihf", target_str);
    }

    // Omitted: armv7-unknown-linux-gnueabihf

    {
        const target = try Target.fromArchOsAbi("loongarch64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("loongarch64-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("loongarch64-linux-musl");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("loongarch64-unknown-linux-musl", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("powerpc-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("powerpc-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("powerpc64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("powerpc64-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("powerpc64le-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("powerpc64le-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromQuery(try std.Target.Query.parse(.{
            .arch_os_abi = "riscv32-freestanding-none",
            .cpu_features = "baseline+i-m-a-f-c",
            .object_format = "elf",
        }));
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv32i-unknown-none-elf", target_str);
    }

    {
        const target = try Target.fromQuery(try std.Target.Query.parse(.{
            .arch_os_abi = "riscv32-freestanding-none",
            .cpu_features = "baseline+i+m-a-f-c",
            .object_format = "elf",
        }));
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv32im-unknown-none-elf", target_str);
    }

    {
        const target = try Target.fromQuery(try std.Target.Query.parse(.{
            .arch_os_abi = "riscv32-freestanding-none",
            .cpu_features = "baseline+i+m+a-f-c",
            .object_format = "elf",
        }));
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv32ima-unknown-none-elf", target_str);
    }

    {
        const target = try Target.fromQuery(try std.Target.Query.parse(.{
            .arch_os_abi = "riscv32-freestanding-none",
            .cpu_features = "baseline+i+m-a-f+c",
            .object_format = "elf",
        }));
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv32imc-unknown-none-elf", target_str);
    }

    {
        const target = try Target.fromQuery(try std.Target.Query.parse(.{
            .arch_os_abi = "riscv32-freestanding-none",
            .cpu_features = "baseline+i+m+a-f+c",
            .object_format = "elf",
        }));
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv32imac-unknown-none-elf", target_str);
    }

    {
        const target = try Target.fromQuery(try std.Target.Query.parse(.{
            .arch_os_abi = "riscv32-freestanding-none",
            .cpu_features = "baseline+i+m+a+f+c",
            .object_format = "elf",
        }));
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv32imafc-unknown-none-elf", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("riscv64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv64gc-unknown-linux-gnu", target_str);
    }

    // https://doc.rust-lang.org/rustc/platform-support.html#tier-2-without-host-tools

    {
        const target = try Target.fromArchOsAbi("aarch64-linux-android");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("aarch64-linux-android", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("arm-linux-android");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("arm-linux-androideabi", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86-linux-android");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("i686-linux-android", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("wasm32-wasi");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("wasm32-wasip1", target_str);
    }
}

test "tier 3" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expectEqualStrings = std.testing.expectEqualStrings;

    // https://doc.rust-lang.org/rustc/platform-support.html#tier-3

    {
        const target = try Target.fromArchOsAbi("riscv64-linux-musl");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv64gc-unknown-linux-musl", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("riscv64-linux-android");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("riscv64-linux-android", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("wasm32-wasi.0.2.0");
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("wasm32-wasip2", target_str);
    }
}

test "custom" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expectEqualStrings = std.testing.expectEqualStrings;

    {
        const target = Target{
            .arch = .{ .custom = "arch" },
            .vendor = .{ .custom = "vendor" },
            .os = .{ .custom = "os" },
            .env = .{ .custom = "env" },
        };
        const target_str = try std.fmt.allocPrint(allocator, "{f}", .{target});
        try expectEqualStrings("arch-vendor-os-env", target_str);
    }
}
