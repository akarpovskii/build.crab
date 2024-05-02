const std = @import("std");

extern fn ping_rust(ping: bool) bool;

test "ping-pong" {
    try std.testing.expect(ping_rust(true) == false);
    try std.testing.expect(ping_rust(false) == true);
}
