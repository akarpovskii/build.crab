const std = @import("std");

pub const Target = struct {
    arch: Arch,
    vendor: Vendor,
    os: Os,
    env: Env,

    pub fn fromZig(target: std.Target) error{Unsupported}!Target {
        return Target{
            .arch = try Arch.fromZig(target.cpu.arch),
            .vendor = try Vendor.fromZig(target),
            .os = try Os.fromZig(target.os),
            .env = try Env.fromZig(target.abi),
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

    pub fn format(self: Target, comptime fmt_spec: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt_spec;
        _ = options;
        if (self.arch == .wasm32 and self.os == .wasi) {
            try writer.print("{s}-{s}", .{ @tagName(self.arch), @tagName(self.os) });
        } else if (self.env == .none) {
            try writer.print("{s}-{s}-{s}", .{ @tagName(self.arch), @tagName(self.vendor), @tagName(self.os) });
        } else {
            try writer.print("{s}-{s}-{s}-{s}", .{ @tagName(self.arch), @tagName(self.vendor), @tagName(self.os), @tagName(self.env) });
        }
    }
};

pub const Arch = enum {
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
    riscv32gc,
    riscv32i,
    riscv32im,
    riscv32imac,
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

    pub fn fromZig(arch: std.Target.Cpu.Arch) error{Unsupported}!Arch {
        return switch (arch) {
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
            .riscv64 => .riscv64,
            .s390x => .s390x,
            .sparc => .sparc,
            .sparc64 => .sparc64,
            .wasm32 => .wasm32,
            .wasm64 => .wasm64,
            .x86 => .i686,
            .x86_64 => .x86_64,

            else => error.Unsupported,
        };
    }
};

pub const Vendor = enum {
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

    pub fn fromZig(target: std.Target) error{Unsupported}!Vendor {
        return switch (target.os.tag) {
            .ios, .macos, .watchos, .tvos => .apple,
            .linux => .unknown,
            .windows => .pc,
            .solaris => .sun,
            .cuda => .nvidia,
            else => {
                if (target.abi == .android) return .linux;
                return .unknown;
            },
        };
    }
};

pub const Os = enum {
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
    solaris,
    solid_asp3,
    @"switch",
    teeos,
    tvos,
    uefi,
    unknown,
    vita,
    vxworks,
    wasi,
    watchos,
    windows,
    xous,

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
            .wasi => .wasi,
            .emscripten => .emscripten,
            .illumos => .illumos,
            .other => .unknown,
            else => error.Unsupported,
        };
    }
};

pub const Env = enum {
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

    pub fn fromZig(abi: std.Target.Abi) error{Unsupported}!Env {
        return switch (abi) {
            .none => .none,
            .gnu => .gnu,
            .gnuabi64 => .gnuabi64,
            .gnueabi => .gnuabi64,
            .gnueabihf => .gnueabihf,
            .eabi => .eabi,
            .eabihf => .eabihf,
            .android => .androideabi,
            .musl => .musl,
            .musleabi => .musleabi,
            .musleabihf => .musleabihf,
            .msvc => .msvc,
            .macabi => .macabi,
            else => error.Unsupported,
        };
    }
};

test "tier 1" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expectEqualStrings = std.testing.expectEqualStrings;

    {
        const target = try Target.fromArchOsAbi("aarch64-macos");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("aarch64-apple-darwin", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("aarch64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("aarch64-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("aarch64-windows-msvc");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("aarch64-pc-windows-msvc", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86_64-macos");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("x86_64-apple-darwin", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86_64-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("x86_64-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86-windows-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("i686-pc-windows-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86-linux-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("i686-unknown-linux-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("x86_64-windows-gnu");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("x86_64-pc-windows-gnu", target_str);
    }

    {
        const target = try Target.fromArchOsAbi("wasm32-wasi");
        const target_str = try std.fmt.allocPrint(allocator, "{}", .{target});
        try expectEqualStrings("wasm32-wasi", target_str);
    }
}
