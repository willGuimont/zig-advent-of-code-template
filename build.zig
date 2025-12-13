const std = @import("std");

pub const current_year = "2025";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const run_step = b.step("solve", "Run and print solution(s)");
    const test_step = b.step("test", "Run unit tests for solution(s)");
    const test_lib_step = b.step("test-lib", "Run unit tests for lib modules");

    // Top-level options (use b.option)
    const days_option = b.option([]const u8, "days", "Solution day(s), e.g. '5', '1..7', '..12' (end-inclusive)");
    const year_option = b.option([]const u8, "year", b.fmt("Solution directory (default: {s})", .{current_year})) orelse current_year;
    const timer = b.option(bool, "time", "Print performance time of each solution (default: true)") orelse true;
    const color = b.option(bool, "color", "Print ANSI color-coded output (default: true)") orelse true;
    const stop_at_failure = b.option(bool, "fail-stop", "If a solution returns an error, exit (default: false)") orelse false;
    _ = stop_at_failure;
    const part = b.option([]const u8, "part", "Select which solution part to run ('1','2','both')") orelse "both";
    const input_kind = b.option([]const u8, "input", "Which inputs to run ('example','real','both')") orelse "both";

    const write_runner = b.addWriteFiles();

    // decide which days to generate for
    var days_to_generate: []usize = &[_]usize{}; // default empty
    if (days_option) |days_str| {
        const allocator = b.allocator;
        const parsed = parseIntRange(allocator, days_str, usize) catch {
            const fail = b.addFail("Invalid range string for -Ddays");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        // convert []const usize to owned slice of usize
        const tmp = allocator.alloc(usize, parsed.len) catch {
            const fail = b.addFail("Out of memory allocating parsed days");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        for (0..parsed.len) |i| tmp[i] = parsed[i];
        days_to_generate = tmp;
        // free later not required here; build process ephemeral
    }

    const runner_path = write_runner.add("aoc_runner.zig", buildRunnerSource(year_option, days_to_generate, timer, color, part, input_kind));

    const runner_mod = b.createModule(.{
        .root_source_file = runner_path,
        .target = target,
        .optimize = optimize,
    });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    runner_mod.addImport("lib", lib_mod);

    // Add lib tests
    const lib_test = b.addTest(.{
        .name = "lib-test",
        .root_module = lib_mod,
    });
    const run_lib_test = b.addRunArtifact(lib_test);
    test_lib_step.dependOn(&run_lib_test.step);

    const runner_exe = b.addExecutable(.{
        .name = "advent-of-code",
        .root_module = runner_mod,
    });

    runner_exe.step.dependOn(&write_runner.step);

    // Fetch missing inputs before running
    const fetch_step = b.step("fetch-inputs", "Fetch missing Advent of Code inputs");
    if (days_option) |_| {
        const fetch_mod = b.createModule(.{
            .root_source_file = b.path("src/fetch_inputs_main.zig"),
            .target = target,
            .optimize = optimize,
        });
        const fetch_exe = b.addExecutable(.{
            .name = "fetch-inputs",
            .root_module = fetch_mod,
        });
        const fetch_cmd = b.addRunArtifact(fetch_exe);
        fetch_cmd.setCwd(b.path("./"));
        fetch_cmd.addArgs(&.{ year_option, days_option.? });
        fetch_step.dependOn(&fetch_cmd.step);
    }

    const run_cmd = b.addRunArtifact(runner_exe);
    run_cmd.step.dependOn(fetch_step);
    run_step.dependOn(&run_cmd.step);
    run_cmd.setCwd(b.path("./"));
    b.installArtifact(runner_exe);

    // If no days were provided, fail the run and test steps with a helpful message
    if (days_option == null) {
        const fail = b.addFail("Please select the solution day(s) using -Ddays");
        run_step.dependOn(&fail.step);
        test_step.dependOn(&fail.step);
    }

    // create tests for specified day modules if any
    if (days_option) |days_str| {
        const allocator = b.allocator;
        const parsed_days = parseIntRange(allocator, days_str, usize) catch {
            const fail = b.addFail("Invalid range string for -Ddays");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        const parsed_years = std.fmt.parseInt(usize, year_option, 10) catch {
            const fail = b.addFail("Invalid range string for -Dyear");
            run_step.dependOn(&fail.step);
            test_step.dependOn(&fail.step);
            return;
        };
        for (parsed_days) |day| {
            if (day <= 0) break;
            if (parsed_years >= 2025 and day > 12) break; // 2025 (onward?) only has 12 days
            if (day > 25) break; // sane guard
            const day_path = b.path(b.fmt("src/{d}/day{d:0>2}.zig", .{ parsed_years, day }));

            // Create day file if it doesn't exist
            const day_file_path = b.fmt("src/{d}/day{d:0>2}.zig", .{ parsed_years, day });
            std.fs.cwd().access(day_file_path, .{}) catch {
                // File doesn't exist, create it
                std.fs.cwd().makePath(b.fmt("src/{d}", .{parsed_years})) catch |err| {
                    if (err != error.PathAlreadyExists) {
                        const fail = b.addFail(b.fmt("Failed to create directory src/{d}", .{parsed_years}));
                        run_step.dependOn(&fail.step);
                        test_step.dependOn(&fail.step);
                        return;
                    }
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
                const file = std.fs.cwd().createFile(day_file_path, .{}) catch {
                    const fail = b.addFail(b.fmt("Failed to create file {s}", .{day_file_path}));
                    run_step.dependOn(&fail.step);
                    test_step.dependOn(&fail.step);
                    return;
                };
                defer file.close();
                file.writeAll(template) catch {
                    const fail = b.addFail(b.fmt("Failed to write to file {s}", .{day_file_path}));
                    run_step.dependOn(&fail.step);
                    test_step.dependOn(&fail.step);
                    return;
                };
            };

            const day_mod = b.createModule(.{
                .root_source_file = day_path,
                .target = target,
                .optimize = optimize,
            });
            day_mod.addImport("lib", lib_mod);

            runner_mod.addImport(b.fmt("day{d}", .{day}), day_mod);

            const day_test = b.addTest(.{
                .name = b.fmt("day-{d}-test", .{day}),
                .root_module = day_mod,
            });
            const run_day_test = b.addRunArtifact(day_test);
            test_step.dependOn(&run_day_test.step);
        }
    }
}

fn partTemplate(part: usize) []const u8 {
    if (part == 1) {
        return "    if (@hasDecl(day{d}, \"part1\")) {{\n        if (RUN_EXAMPLE) {{\n            const start_ex = if (USE_TIMER) std.time.nanoTimestamp() else 0;\n            const res_ex = try day{d}.part1(example_{d});\n            const dur_ex = if (USE_TIMER) (std.time.nanoTimestamp() - start_ex) else 0;\n            const pre_ex = if (USE_COLOR) COLOR_GREEN else \"\";\n            const post_ex = if (USE_COLOR) COLOR_RESET else \"\";\n            std.debug.print(\"{{s}}[{d}/1 example]{{s}} {{s}}\\n ╰─ ⏱ {{d}} ns\\n\", .{{pre_ex, post_ex, res_ex, dur_ex}});\n        }}\n        if (RUN_REAL) {{\n            const start = if (USE_TIMER) std.time.nanoTimestamp() else 0;\n            const res = try day{d}.part1(real_{d});\n            const dur = if (USE_TIMER) (std.time.nanoTimestamp() - start) else 0;\n            const pre = if (USE_COLOR) COLOR_RED else \"\";\n            const post = if (USE_COLOR) COLOR_RESET else \"\";\n            std.debug.print(\"{{s}}[{d}/1 input]{{s}} {{s}}\\n ╰─ ⏱ {{d}} ns\\n\", .{{pre, post, res, dur}});\n        }}\n    }}\n";
    } else {
        return "    if (@hasDecl(day{d}, \"part2\")) {{\n        if (RUN_EXAMPLE) {{\n            const start_ex = if (USE_TIMER) std.time.nanoTimestamp() else 0;\n            const res_ex = try day{d}.part2(example_{d});\n            const dur_ex = if (USE_TIMER) (std.time.nanoTimestamp() - start_ex) else 0;\n            const pre_ex = if (USE_COLOR) COLOR_GREEN else \"\";\n            const post_ex = if (USE_COLOR) COLOR_RESET else \"\";\n            std.debug.print(\"{{s}}[{d}/2 example]{{s}} {{s}}\\n ╰─ ⏱ {{d}} ns\\n\", .{{pre_ex, post_ex, res_ex, dur_ex}});\n        }}\n        if (RUN_REAL) {{\n            const start = if (USE_TIMER) std.time.nanoTimestamp() else 0;\n            const res = try day{d}.part2(real_{d});\n            const dur = if (USE_TIMER) (std.time.nanoTimestamp() - start) else 0;\n            const pre = if (USE_COLOR) COLOR_RED else \"\";\n            const post = if (USE_COLOR) COLOR_RESET else \"\";\n            std.debug.print(\"{{s}}[{d}/2 input]{{s}} {{s}}\\n ╰─ ⏱ {{d}} ns\\n\", .{{pre, post, res, dur}});\n        }}\n    }}\n\n";
    }
}

fn emitPart(comptime part: usize, tmp: []u8, d: usize) []const u8 {
    return std.fmt.bufPrint(tmp, partTemplate(part), .{ d, d, d, d, d, d, d }) catch unreachable;
}

fn buildRunnerSource(year: []const u8, days: []usize, use_timer: bool, use_color: bool, part_opt: []const u8, input_opt: []const u8) []const u8 {
    const allocator = std.heap.smp_allocator;
    const cap: usize = 65536;
    var buf = allocator.alloc(u8, cap) catch unreachable;
    var pos: usize = 0;

    // prelude
    {
        const s = "const std = @import(\"std\");\n\n";
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }
    {
        const s = "pub fn main() anyerror!void {\n\n";
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }

    var tmp: [1024]u8 = undefined;
    const do_p1 = std.mem.eql(u8, part_opt, "1") or std.mem.eql(u8, part_opt, "both");
    const do_p2 = std.mem.eql(u8, part_opt, "2") or std.mem.eql(u8, part_opt, "both");
    const run_example = std.mem.eql(u8, input_opt, "example") or std.mem.eql(u8, input_opt, "both");
    const run_real = std.mem.eql(u8, input_opt, "real") or std.mem.eql(u8, input_opt, "both");

    // Emit settings into generated runner (USE_TIMER, USE_COLOR and color codes)
    const settings1 = std.fmt.bufPrint(&tmp, "const USE_TIMER: bool = {s};\n", .{if (use_timer) "true" else "false"}) catch unreachable;
    {
        const s = settings1;
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }
    const settings2 = std.fmt.bufPrint(&tmp, "const USE_COLOR: bool = {s};\nconst COLOR_RED = \"\\x1b[31m\";\nconst COLOR_GREEN = \"\\x1b[32m\";\nconst COLOR_RESET = \"\\x1b[0m\";\n\n", .{if (use_color) "true" else "false"}) catch unreachable;
    {
        const s = settings2;
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }
    const settings3 = std.fmt.bufPrint(&tmp, "const RUN_EXAMPLE: bool = {s};\nconst RUN_REAL: bool = {s};\n\n", .{ if (run_example) "true" else "false", if (run_real) "true" else "false" }) catch unreachable;
    {
        const s = settings3;
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }

    // Global timer for the whole run (all selected days and parts).
    const settings4 = "    const TOTAL_START = if (USE_TIMER) std.time.nanoTimestamp() else 0;\n\n";
    {
        const s = settings4;
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }

    for (days) |d| {
        const import_line = std.fmt.bufPrint(&tmp, "    const day{d} = @import(\"day{d}\");\n", .{ d, d }) catch unreachable;
        {
            const s = import_line;
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                buf[pos] = s[i];
                pos += 1;
            }
        }
        const run_header = std.fmt.bufPrint(&tmp, "    // Day {d}\n", .{d}) catch unreachable;
        {
            const s = run_header;
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                buf[pos] = s[i];
                pos += 1;
            }
        }

        const paths = std.fmt.bufPrint(&tmp, "    const example_path_{d} = \"input/{s}/day{d:0>2}_example.txt\";\n    const real_path_{d} = \"input/{s}/day{d:0>2}.txt\";\n", .{ d, year, d, d, year, d }) catch unreachable;
        {
            const s = paths;
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                buf[pos] = s[i];
                pos += 1;
            }
        }

        const read_inputs = std.fmt.bufPrint(&tmp, "    const example_{d} = try std.fs.cwd().readFileAlloc(std.heap.smp_allocator, example_path_{d}, 8192);\n    defer std.heap.smp_allocator.free(example_{d});\n    const real_{d} = try std.fs.cwd().readFileAlloc(std.heap.smp_allocator, real_path_{d}, 65536);\n    defer std.heap.smp_allocator.free(real_{d});\n", .{ d, d, d, d, d, d }) catch unreachable;
        {
            const s = read_inputs;
            var i: usize = 0;
            while (i < s.len) : (i += 1) {
                buf[pos] = s[i];
                pos += 1;
            }
        }

        if (do_p1) {
            const p1 = emitPart(1, tmp[0..], d);
            {
                const s = p1;
                var i: usize = 0;
                while (i < s.len) : (i += 1) {
                    buf[pos] = s[i];
                    pos += 1;
                }
            }
        }

        if (do_p2) {
            const p2 = emitPart(2, tmp[0..], d);
            {
                const s = p2;
                var i: usize = 0;
                while (i < s.len) : (i += 1) {
                    buf[pos] = s[i];
                    pos += 1;
                }
            }
        }
    }

    {
        const s =
            "    if (USE_TIMER) {\n" ++
            "        const total_ns = std.time.nanoTimestamp() - TOTAL_START;\n" ++
            "        const total_ms: u64 = @as(u64, @intCast(@divTrunc(total_ns, std.time.ns_per_ms)));\n" ++
            "        std.debug.print(\"Total time: {d}ms\\n\", .{total_ms});\n" ++
            "    }\n" ++
            "    return;\n" ++
            "}\n";
        var i: usize = 0;
        while (i < s.len) : (i += 1) {
            buf[pos] = s[i];
            pos += 1;
        }
    }

    return buf[0..pos];
}

// Parse a compact integer range string into an allocator-allocated slice of integers.
fn parseIntRange(allocator: std.mem.Allocator, string: []const u8, comptime T: type) ![]T {
    const fmt = std.fmt;
    var dot_index: ?usize = null;
    for (0..string.len) |i| {
        if (string[i] == '.') {
            dot_index = i;
            break;
        }
    }
    if (dot_index) |first_dot_index| {
        if (first_dot_index == 0 and string.len > 1 and string[1] == '.') {
            // ..N form
            if (string.len <= 2) return error.InvalidCharacter;
            const last = try fmt.parseUnsigned(T, string[2..], 10);
            const list = try allocator.alloc(T, last);
            for (0..list.len) |i| {
                list[i] = @as(T, i + 1);
            }
            return list;
        } else if (string.len > first_dot_index + 2 and string[first_dot_index + 1] == '.') {
            const first = try fmt.parseUnsigned(T, string[0..first_dot_index], 10);
            const last = try fmt.parseUnsigned(T, string[first_dot_index + 2 ..], 10);
            if (last < first) return error.InvalidCharacter;
            const cnt = last - first + 1;
            const list = try allocator.alloc(T, cnt);
            for (0..list.len) |i| {
                list[i] = @as(T, first + i);
            }
            return list;
        } else return error.InvalidCharacter;
    } else {
        const v = try fmt.parseUnsigned(T, string, 10);
        const list = try allocator.alloc(T, 1);
        list[0] = v;
        return list;
    }
}

pub const Day = u8;
