const std = @import("std");
const opts = @import("build_options");

const Tool = enum {
    cc,
    ar,
    ranlib,
    dlltool,
};

pub fn main(init: std.process.Init) !u8 {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const exe = std.fs.path.basename(args[0]);

    const maybe_target: ?[]const u8, const tool: Tool = D: {
        inline for (std.enums.values(Tool)) |tool| {
            if (std.mem.endsWith(u8, exe, "-" ++ @tagName(tool))) {
                break :D .{ exe[0 .. exe.len - ("-" ++ @tagName(tool)).len], tool };
            }
        }
        break :D .{ null, std.meta.stringToEnum(Tool, exe) orelse .cc };
    };

    const effective_target = switch (tool) {
        // dlltool is prefixed with {arch}-mingw32 which is not a zig target triple
        // effective_target does not matter for that anyhow
        .dlltool => @import("builtin").target,
        else => try std.zig.system.resolveTargetQuery(init.io, try .parse(.{
            .arch_os_abi = maybe_target orelse "native",
        })),
    };

    var argv: std.ArrayList([]const u8) = .empty;
    try argv.appendSlice(init.arena.allocator(), &.{
        opts.zig,
        @tagName(tool),
    });

    if (tool == .cc) {
        if (maybe_target) |target| {
            try argv.appendSlice(init.arena.allocator(), &.{ "-target", target });
        }
    }

    iter: for (args[1..]) |arg| {
        if (std.mem.startsWith(u8, arg, "--target=")) continue;
        switch (effective_target.os.tag) {
            .windows => {
                const filtered: []const []const u8 = &.{
                    "-lwindows",
                    "-l:libpthread.a",
                    "-lgcc",
                    "-lmsvcrt",
                };
                if (std.mem.startsWith(u8, arg, "-Wl,") and std.mem.endsWith(u8, arg, "/list.def")) continue;
                for (filtered) |filter| if (std.mem.eql(u8, arg, filter)) continue :iter;
            },
            else => {},
        }
        try argv.append(init.arena.allocator(), arg);
    }

    var child = try std.process.spawn(init.io, .{ .argv = argv.items });
    const res = try child.wait(init.io);
    return res.exited;
}
