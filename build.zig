const std = @import("std");

pub const current_year = "2025";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const run_step = b.step("solve", "Run and print solution(s)");
    const test_step = b.step("test", "Run unit tests for solution(s)");
    const test_lib_step = b.step("test-lib", "Run unit tests for lib modules");

    const days_option = b.option([]const u8, "days", "Solution day(s), e.g. '5', '1..7', '..12' (end-inclusive)");
    const year_option = b.option([]const u8, "year", b.fmt("Solution directory (default: {s})", .{current_year})) orelse current_year;
    const timer = b.option(bool, "time", "Print performance time of each solution (default: true)") orelse true;
    const color = b.option(bool, "color", "Print ANSI color-coded output (default: true)") orelse true;
    const part = b.option([]const u8, "part", "Select which solution part to run ('1','2','both')") orelse "both";
    const input_kind = b.option([]const u8, "input", "Which inputs to run ('example','real','both')") orelse "both";

    const allocator = b.allocator;
    const io = b.graph.io;

    var days_to_generate: []usize = &[_]usize{};
    if (days_option) |days_str| {
        const parsed = parseIntRange(allocator, days_str, usize) catch {
            run_step.dependOn(&b.addFail("Invalid range string for -Ddays").step);
            test_step.dependOn(&b.addFail("Invalid range string for -Ddays").step);
            return;
        };
        days_to_generate = parsed;
    }

    const write_runner = b.addWriteFiles();
    const runner_path = write_runner.add("aoc_runner.zig", buildRunnerSource(allocator, year_option, days_to_generate, timer, color, part, input_kind));

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const runner_mod = b.createModule(.{
        .root_source_file = runner_path,
        .target = target,
        .optimize = optimize,
    });
    runner_mod.addImport("lib", lib_mod);

    // lib tests
    const lib_test = b.addTest(.{ .name = "lib-test", .root_module = lib_mod });
    test_lib_step.dependOn(&b.addRunArtifact(lib_test).step);

    const runner_exe = b.addExecutable(.{ .name = "advent-of-code", .root_module = runner_mod });
    runner_exe.step.dependOn(&write_runner.step);
    b.installArtifact(runner_exe);

    // ZLS check step
    const runner_check = b.addExecutable(.{ .name = "advent-of-code-check", .root_module = runner_mod });
    runner_check.step.dependOn(&write_runner.step);
    b.step("check", "Check if advent-of-code builds (for ZLS)").dependOn(&runner_check.step);

    // Fetch inputs step
    const fetch_step = b.step("fetch-inputs", "Fetch missing Advent of Code inputs");
    if (days_option) |days_str| {
        const fetch_mod = b.createModule(.{
            .root_source_file = b.path("src/fetch_inputs_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        const fetch_exe = b.addExecutable(.{ .name = "fetch-inputs", .root_module = fetch_mod });
        const fetch_cmd = b.addRunArtifact(fetch_exe);
        fetch_cmd.setCwd(b.path("./"));
        fetch_cmd.addArgs(&.{ year_option, days_str });
        fetch_step.dependOn(&fetch_cmd.step);
    }

    const run_cmd = b.addRunArtifact(runner_exe);
    run_cmd.step.dependOn(fetch_step);
    run_cmd.setCwd(b.path("./"));
    run_step.dependOn(&run_cmd.step);

    if (days_option == null) {
        run_step.dependOn(&b.addFail("Please select the solution day(s) using -Ddays").step);
        test_step.dependOn(&b.addFail("Please select the solution day(s) using -Ddays").step);
        return;
    }

    const parsed_years = std.fmt.parseInt(usize, year_option, 10) catch {
        run_step.dependOn(&b.addFail("Invalid year for -Dyear").step);
        return;
    };

    for (days_to_generate) |day| {
        if (day == 0 or day > 25) break;

        const day_file_path = b.fmt("src/{d}/day{d:0>2}.zig", .{ parsed_years, day });

        std.Io.Dir.cwd().access(io, day_file_path, .{}) catch {
            std.Io.Dir.cwd().createDirPath(io, b.fmt("src/{d}", .{parsed_years})) catch |err| {
                std.debug.print("Failed to create directory src/{d}: {}\n", .{ parsed_years, err });
                return;
            };
            const template =
                \\const std = @import("std");
                \\
                \\var buf: [2048]u8 = undefined;
                \\
                \\pub fn part1(input: []const u8) ![]const u8 {
                \\    _ = input;
                \\    // Your solution here
                \\    return std.fmt.bufPrint(&buf, "not implemented: {d}", .{0}) catch "error";
                \\}
                \\
                \\pub fn part2(input: []const u8) ![]const u8 {
                \\    _ = input;
                \\    // Your solution here
                \\    return std.fmt.bufPrint(&buf, "not implemented: {d}", .{0}) catch "error";
                \\}
                \\
            ;
            var new_file = std.Io.Dir.cwd().createFile(io, day_file_path, .{}) catch |err| {
                std.debug.print("Failed to create file {s}: {}\n", .{ day_file_path, err });
                return;
            };
            new_file.writeStreamingAll(io, template) catch |err| {
                std.debug.print("Failed to write to file {s}: {}\n", .{ day_file_path, err });
                new_file.close(io);
                return;
            };
            new_file.close(io);
        };

        const day_mod = b.createModule(.{
            .root_source_file = b.path(day_file_path),
            .target = target,
            .optimize = optimize,
        });
        day_mod.addImport("lib", lib_mod);
        runner_mod.addImport(b.fmt("day{d}", .{day}), day_mod);

        const day_test = b.addTest(.{
            .name = b.fmt("day-{d}-test", .{day}),
            .root_module = day_mod,
        });
        test_step.dependOn(&b.addRunArtifact(day_test).step);
    }
}

fn buildRunnerSource(gpa: std.mem.Allocator, year: []const u8, days: []usize, use_timer: bool, use_color: bool, part_opt: []const u8, input_opt: []const u8) []const u8 {
    var buf: std.ArrayList(u8) = .empty;

    const do_p1 = std.mem.eql(u8, part_opt, "1") or std.mem.eql(u8, part_opt, "both");
    const do_p2 = std.mem.eql(u8, part_opt, "2") or std.mem.eql(u8, part_opt, "both");
    const run_example = std.mem.eql(u8, input_opt, "example") or std.mem.eql(u8, input_opt, "both");
    const run_real = std.mem.eql(u8, input_opt, "real") or std.mem.eql(u8, input_opt, "both");

    buf.appendSlice(gpa, "const std = @import(\"std\");\n\n") catch unreachable;
    buf.print(gpa, "const USE_TIMER: bool = {};\n", .{use_timer}) catch unreachable;
    buf.print(gpa, "const USE_COLOR: bool = {};\n", .{use_color}) catch unreachable;
    buf.appendSlice(gpa, "const COLOR_RED = \"\\x1b[31m\";\nconst COLOR_GREEN = \"\\x1b[32m\";\nconst COLOR_RESET = \"\\x1b[0m\";\n\n") catch unreachable;
    buf.print(gpa, "const RUN_EXAMPLE: bool = {};\n", .{run_example}) catch unreachable;
    buf.print(gpa, "const RUN_REAL: bool = {};\n\n", .{run_real}) catch unreachable;

    buf.appendSlice(gpa, "pub fn main(init: std.process.Init) !void {\n") catch unreachable;
    buf.appendSlice(gpa, "    const io = init.io;\n") catch unreachable;
    buf.appendSlice(gpa, "    const gpa = init.gpa;\n\n") catch unreachable;

    if (days.len == 0) {
        buf.appendSlice(gpa, "    _ = gpa;\n\n") catch unreachable;
    }

    buf.appendSlice(gpa, "    const TOTAL_START: i96 = if (USE_TIMER) std.Io.Timestamp.now(io, .awake).nanoseconds else 0;\n\n") catch unreachable;

    for (days) |d| {
        buf.print(gpa, "    const day{d} = @import(\"day{d}\");\n", .{ d, d }) catch unreachable;
        buf.print(gpa, "    // Day {d}\n", .{d}) catch unreachable;
        buf.print(gpa, "    const example_path_{d} = \"input/{s}/day{d:0>2}_example.txt\";\n", .{ d, year, d }) catch unreachable;
        buf.print(gpa, "    const real_path_{d} = \"input/{s}/day{d:0>2}.txt\";\n", .{ d, year, d }) catch unreachable;
        buf.print(gpa, "    const example_{d} = try std.Io.Dir.cwd().readFileAlloc(io, example_path_{d}, gpa, std.Io.Limit.limited(8192));\n", .{ d, d }) catch unreachable;
        buf.print(gpa, "    defer gpa.free(example_{d});\n", .{d}) catch unreachable;
        buf.print(gpa, "    const real_{d} = try std.Io.Dir.cwd().readFileAlloc(io, real_path_{d}, gpa, std.Io.Limit.limited(65536));\n", .{ d, d }) catch unreachable;
        buf.print(gpa, "    defer gpa.free(real_{d});\n", .{d}) catch unreachable;

        if (do_p1) emitPart(&buf, gpa, 1, d);
        if (do_p2) emitPart(&buf, gpa, 2, d);
    }

    buf.appendSlice(gpa, "    if (USE_TIMER) {\n") catch unreachable;
    buf.appendSlice(gpa, "        const total_ns: i96 = std.Io.Timestamp.now(io, .awake).nanoseconds - TOTAL_START;\n") catch unreachable;
    buf.appendSlice(gpa, "        const total_ms: u64 = @as(u64, @intCast(@divTrunc(total_ns, std.time.ns_per_ms)));\n") catch unreachable;
    buf.appendSlice(gpa, "        std.debug.print(\"Total time: {d}ms\\n\", .{total_ms});\n") catch unreachable;
    buf.appendSlice(gpa, "    }\n}\n") catch unreachable;

    return buf.toOwnedSlice(gpa) catch unreachable;
}

fn emitPart(buf: *std.ArrayList(u8), gpa: std.mem.Allocator, comptime part: u8, d: usize) void {
    const part_str = if (part == 1) "1" else "2";
    buf.print(gpa, "    if (@hasDecl(day{d}, \"part{s}\")) {{\n", .{ d, part_str }) catch unreachable;
    buf.print(gpa, "        if (RUN_EXAMPLE and example_{d}.len > 0) {{\n", .{d}) catch unreachable;
    buf.appendSlice(gpa, "            const start_ex: i96 = if (USE_TIMER) std.Io.Timestamp.now(io, .awake).nanoseconds else 0;\n") catch unreachable;
    buf.print(gpa, "            if (day{d}.part{s}(example_{d})) |res_ex| {{\n", .{ d, part_str, d }) catch unreachable;
    buf.appendSlice(gpa, "                const dur_ex: i96 = if (USE_TIMER) (std.Io.Timestamp.now(io, .awake).nanoseconds - start_ex) else 0;\n") catch unreachable;
    buf.appendSlice(gpa, "                const pre_ex = if (USE_COLOR) COLOR_GREEN else \"\";\n") catch unreachable;
    buf.appendSlice(gpa, "                const post_ex = if (USE_COLOR) COLOR_RESET else \"\";\n") catch unreachable;
    buf.print(gpa, "                std.debug.print(\"{{s}}[{d}/{s} example]{{s}} {{s}}\\n ╰─ ⏱ {{d}} ns\\n\", .{{pre_ex, post_ex, res_ex, dur_ex}});\n", .{ d, part_str }) catch unreachable;
    buf.print(gpa, "            }} else |err| {{\n", .{}) catch unreachable;
    buf.print(gpa, "                std.debug.print(\"[{d}/{s} example] skipped: {{}}\\n\", .{{err}});\n", .{ d, part_str }) catch unreachable;
    buf.appendSlice(gpa, "            }\n") catch unreachable;
    buf.appendSlice(gpa, "        }\n") catch unreachable;
    buf.appendSlice(gpa, "        if (RUN_REAL) {\n") catch unreachable;
    buf.appendSlice(gpa, "            const start: i96 = if (USE_TIMER) std.Io.Timestamp.now(io, .awake).nanoseconds else 0;\n") catch unreachable;
    buf.print(gpa, "            const res = try day{d}.part{s}(real_{d});\n", .{ d, part_str, d }) catch unreachable;
    buf.appendSlice(gpa, "            const dur: i96 = if (USE_TIMER) (std.Io.Timestamp.now(io, .awake).nanoseconds - start) else 0;\n") catch unreachable;
    buf.appendSlice(gpa, "            const pre = if (USE_COLOR) COLOR_RED else \"\";\n") catch unreachable;
    buf.appendSlice(gpa, "            const post = if (USE_COLOR) COLOR_RESET else \"\";\n") catch unreachable;
    buf.print(gpa, "            std.debug.print(\"{{s}}[{d}/{s} input]{{s}} {{s}}\\n ╰─ ⏱ {{d}} ns\\n\", .{{pre, post, res, dur}});\n", .{ d, part_str }) catch unreachable;
    buf.appendSlice(gpa, "        }\n") catch unreachable;
    buf.appendSlice(gpa, "    }\n\n") catch unreachable;
}

fn parseIntRange(allocator: std.mem.Allocator, string: []const u8, comptime T: type) ![]T {
    var dot_index: ?usize = null;
    for (0..string.len) |i| {
        if (string[i] == '.') {
            dot_index = i;
            break;
        }
    }
    if (dot_index) |first_dot_index| {
        if (first_dot_index == 0 and string.len > 1 and string[1] == '.') {
            if (string.len <= 2) return error.InvalidCharacter;
            const last = try std.fmt.parseUnsigned(T, string[2..], 10);
            const list = try allocator.alloc(T, last);
            for (0..list.len) |i| list[i] = @as(T, i + 1);
            return list;
        } else if (string.len > first_dot_index + 2 and string[first_dot_index + 1] == '.') {
            const first = try std.fmt.parseUnsigned(T, string[0..first_dot_index], 10);
            const last = try std.fmt.parseUnsigned(T, string[first_dot_index + 2 ..], 10);
            if (last < first) return error.InvalidCharacter;
            const list = try allocator.alloc(T, last - first + 1);
            for (0..list.len) |i| list[i] = @as(T, first + i);
            return list;
        } else return error.InvalidCharacter;
    } else {
        const v = try std.fmt.parseUnsigned(T, string, 10);
        const list = try allocator.alloc(T, 1);
        list[0] = v;
        return list;
    }
}
