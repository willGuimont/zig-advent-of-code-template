const std = @import("std");

pub const example = @import("lib/example.zig");

test {
    std.testing.refAllDecls(@This());
}
