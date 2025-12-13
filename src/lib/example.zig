const std = @import("std");

pub fn hard_computation(x: i32, y: i32) i32 {
    return x + y;
}

test "hard_computation" {
    try std.testing.expectEqual(hard_computation(1, 2), 3);
}
