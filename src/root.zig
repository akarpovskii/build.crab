const std = @import("std");

pub usingnamespace @import("rust.zig");

test {
    std.testing.refAllDecls(@This());
}
