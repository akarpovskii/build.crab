const std = @import("std");

pub const rust = @import("rust.zig");

test {
    std.testing.refAllDecls(@This());
}
