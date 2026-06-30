const std = @import("std");

pub fn fetchInputIfNotExists(
    allocator: std.mem.Allocator,
    io: std.Io,
    token: []const u8,
    user_agent: []const u8,
    year: []const u8,
    day: usize,
    output_dir: []const u8,
) !void {
    var path_buf: [256]u8 = undefined;
    const input_path = try std.fmt.bufPrint(&path_buf, "{s}/day{d:0>2}.txt", .{ output_dir, day });

    const cwd = std.Io.Dir.cwd();

    if (cwd.openFile(io, input_path, .{})) |file| {
        file.close(io);
        std.debug.print("Input file already exists: {s}\n", .{input_path});
        return;
    } else |err| {
        if (err != error.FileNotFound) return err;
    }

    var url_buf: [512]u8 = undefined;
    const url_str = try std.fmt.bufPrint(&url_buf, "https://adventofcode.com/{s}/day/{d}/input", .{ year, day });

    try cwd.createDirPath(io, output_dir);

    const session_cookie = try std.fmt.allocPrint(allocator, "session={s}", .{token});
    defer allocator.free(session_cookie);

    const argv = &[_][]const u8{ "curl", "-s", "-A", user_agent, "-b", session_cookie, url_str };

    const result = try std.process.run(allocator, io, .{ .argv = argv });
    defer {
        allocator.free(result.stdout);
        allocator.free(result.stderr);
    }

    if (result.term == .exited and result.term.exited != 0) {
        std.debug.print("Error: curl failed with exit code {d}\n", .{result.term.exited});
        return error.CurlError;
    }

    if (result.stdout.len == 0) {
        std.debug.print("Error: no response from curl\n", .{});
        return error.EmptyResponse;
    }

    var file = try cwd.createFile(io, input_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, result.stdout);

    std.debug.print("Fetched input for day {d} to {s}\n", .{ day, input_path });

    var example_path_buf: [256]u8 = undefined;
    const example_path = try std.fmt.bufPrint(&example_path_buf, "{s}/day{d:0>2}_example.txt", .{ output_dir, day });

    if (cwd.openFile(io, example_path, .{})) |example_file| {
        example_file.close(io);
    } else |err| {
        if (err == error.FileNotFound) {
            var example_file = try cwd.createFile(io, example_path, .{});
            example_file.close(io);
            std.debug.print("Created empty example file: {s}\n", .{example_path});
        }
    }
}
