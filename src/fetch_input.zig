const std = @import("std");

pub fn fetchInputIfNotExists(
    allocator: std.mem.Allocator,
    year: []const u8,
    day: usize,
    output_dir: []const u8,
) !void {
    // Construct the input file path
    var path_buf: [256]u8 = undefined;
    const input_path = try std.fmt.bufPrint(
        &path_buf,
        "{s}/day{d:0>2}.txt",
        .{ output_dir, day },
    );

    // Check if file already exists
    if (std.fs.cwd().openFile(input_path, .{})) |file| {
        file.close();
        std.debug.print("Input file already exists: {s}\n", .{input_path});
        return;
    } else |err| {
        if (err != error.FileNotFound) {
            return err;
        }
    }

    // Get environment variables
    const token = std.process.getEnvVarOwned(allocator, "AOC_TOKEN") catch |err| {
        std.debug.print("Error: AOC_TOKEN environment variable not set\n", .{});
        return err;
    };
    defer allocator.free(token);

    const user_agent = std.process.getEnvVarOwned(allocator, "AOC_USER_AGENT") catch |err| {
        std.debug.print("Error: AOC_USER_AGENT environment variable not set\n", .{});
        return err;
    };
    defer allocator.free(user_agent);

    // Construct the URL
    var url_buf: [512]u8 = undefined;
    const url_str = try std.fmt.bufPrint(
        &url_buf,
        "https://adventofcode.com/{s}/day/{d}/input",
        .{ year, day },
    );

    // Ensure output directory exists
    std.fs.cwd().makePath(output_dir) catch |err| {
        if (err != error.PathAlreadyExists) {
            return err;
        }
    };

    // Use curl to fetch the input
    const session_cookie = try std.fmt.allocPrint(allocator, "session={s}", .{token});
    defer allocator.free(session_cookie);

    const argv = &[_][]const u8{
        "curl",
        "-s",
        "-A",
        user_agent,
        "-b",
        session_cookie,
        url_str,
    };

    var child = std.process.Child.init(argv, allocator);

    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Ignore;

    try child.spawn();

    var response_buf: [1024 * 1024]u8 = undefined;
    var response_len: usize = 0;

    if (child.stdout) |stdout| {
        response_len = try stdout.readAll(&response_buf);
    }

    const term = try child.wait();

    if (term == .Exited and term.Exited != 0) {
        std.debug.print("Error: curl failed with exit code {d}\n", .{term.Exited});
        return error.CurlError;
    }

    if (response_len == 0) {
        std.debug.print("Error: no response from curl\n", .{});
        return error.EmptyResponse;
    }

    // Write to file
    var file = try std.fs.cwd().createFile(input_path, .{});
    defer file.close();

    try file.writeAll(response_buf[0..response_len]);

    std.debug.print("Fetched input for day {d} to {s}\n", .{ day, input_path });

    // Create empty example file if it doesn't exist
    var example_path_buf: [256]u8 = undefined;
    const example_path = try std.fmt.bufPrint(
        &example_path_buf,
        "{s}/day{d:0>2}_example.txt",
        .{ output_dir, day },
    );

    if (std.fs.cwd().openFile(example_path, .{})) |example_file| {
        example_file.close();
    } else |err| {
        if (err == error.FileNotFound) {
            var example_file = try std.fs.cwd().createFile(example_path, .{});
            example_file.close();
            std.debug.print("Created empty example file: {s}\n", .{example_path});
        }
    }
}
