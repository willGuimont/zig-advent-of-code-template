const std = @import("std");
const fetch_input = @import("fetch_input.zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const env = init.environ_map;

    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 3) {
        std.debug.print("Usage: fetch-inputs <year> <days>\n", .{});
        return;
    }

    const year = args[1];
    const days_str = args[2];

    const token = env.get("AOC_TOKEN") orelse {
        std.debug.print("Error: AOC_TOKEN environment variable not set\n", .{});
        return error.MissingToken;
    };
    const user_agent = env.get("AOC_USER_AGENT") orelse {
        std.debug.print("Error: AOC_USER_AGENT environment variable not set\n", .{});
        return error.MissingUserAgent;
    };

    const parsed_days = try parseDays(allocator, days_str);
    defer allocator.free(parsed_days);

    const input_dir = try std.fmt.allocPrint(allocator, "input/{s}", .{year});
    defer allocator.free(input_dir);

    for (parsed_days) |day| {
        fetch_input.fetchInputIfNotExists(allocator, io, token, user_agent, year, day, input_dir) catch |err| {
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
            if (days_str.len <= 2) return error.InvalidCharacter;
            const last = try std.fmt.parseUnsigned(usize, days_str[2..], 10);
            const list = try allocator.alloc(usize, last);
            for (0..list.len) |i| list[i] = i + 1;
            return list;
        } else if (days_str.len > first_dot_index + 2 and days_str[first_dot_index + 1] == '.') {
            const first = try std.fmt.parseUnsigned(usize, days_str[0..first_dot_index], 10);
            const last = try std.fmt.parseUnsigned(usize, days_str[first_dot_index + 2 ..], 10);
            if (last < first) return error.InvalidCharacter;
            const list = try allocator.alloc(usize, last - first + 1);
            for (0..list.len) |i| list[i] = first + i;
            return list;
        } else return error.InvalidCharacter;
    } else {
        const v = try std.fmt.parseUnsigned(usize, days_str, 10);
        const list = try allocator.alloc(usize, 1);
        list[0] = v;
        return list;
    }
}
