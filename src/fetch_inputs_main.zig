const std = @import("std");
const fetch_input = @import("fetch_input.zig");

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: fetch-inputs <year> <days>\n", .{});
        return;
    }

    const year = args[1];
    const days_str = args[2];

    // Parse days using the same logic as build.zig
    const parsed_days = try parseDays(allocator, days_str);
    defer allocator.free(parsed_days);

    // Ensure input directory exists
    const input_dir = try std.fmt.allocPrint(allocator, "input/{s}", .{year});
    defer allocator.free(input_dir);

    std.fs.cwd().makePath(input_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };

    // Fetch each day's input
    for (parsed_days) |day| {
        fetch_input.fetchInputIfNotExists(allocator, year, day, input_dir) catch |err| {
            std.debug.print("Failed to fetch day {d}: {}\n", .{ day, err });
        };
    }
}

fn parseDays(allocator: std.mem.Allocator, days_str: []const u8) ![]usize {
    var dot_index: ?usize = null;
    for (0..days_str.len) |i| {
        if (days_str[i] == '.') {
            dot_index = i;
            break;
        }
    }

    if (dot_index) |first_dot_index| {
        if (first_dot_index == 0 and days_str.len > 1 and days_str[1] == '.') {
            // ..N form
            if (days_str.len <= 2) return error.InvalidCharacter;
            const last = try std.fmt.parseUnsigned(usize, days_str[2..], 10);
            const list = try allocator.alloc(usize, last);
            for (0..list.len) |i| {
                list[i] = i + 1;
            }
            return list;
        } else if (days_str.len > first_dot_index + 2 and days_str[first_dot_index + 1] == '.') {
            const first = try std.fmt.parseUnsigned(usize, days_str[0..first_dot_index], 10);
            const last = try std.fmt.parseUnsigned(usize, days_str[first_dot_index + 2 ..], 10);
            if (last < first) return error.InvalidCharacter;
            const cnt = last - first + 1;
            const list = try allocator.alloc(usize, cnt);
            for (0..list.len) |i| {
                list[i] = first + i;
            }
            return list;
        } else return error.InvalidCharacter;
    } else {
        const v = try std.fmt.parseUnsigned(usize, days_str, 10);
        const list = try allocator.alloc(usize, 1);
        list[0] = v;
        return list;
    }
}
