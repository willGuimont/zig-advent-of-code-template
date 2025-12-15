# Zig Advent of Code Template

Advent of Code solutions using the Zig programming language.
This template provides a starting point for your Advent of Code solutions.
It automatically fetches input data from [adventofcode.com](adventofcode.com) and generates templates for each day.

I used this template for my solutions in [willGuimont/zadvent](https://github.com/willGuimont/zadvent).

## Setup

Set environment variables for automatic input fetching:

```sh
export AOC_TOKEN="your_session_token_from_adventofcode.com"
export AOC_USER_AGENT="github.com/yourusername/zadvent by your.email@example.com"
```

To get your session token:

1. Log in to [adventofcode.com](https://adventofcode.com)
2. Open browser DevTools (F12)
3. Go to Application/Storage → Cookies
4. Copy the value of the `session` cookie

## Usage

### Run a Single Day

```sh
# Run both parts for day 1
zig build -Ddays=1 solve

# Run only part 1
zig build -Ddays=1 -Dpart=1 solve

# Run only part 2
zig build -Ddays=1 -Dpart=2 solve

# Run only example inputs
zig build -Ddays=1 -Dinput=example solve

# Run only real inputs
zig build -Ddays=1 -Dinput=real solve

# Run both (default)
zig build -Ddays=1 -Dinput=both solve
```

### Run Multiple Days

```sh
# Run days 1 through 5
zig build -Ddays=1..5 solve

# Run days 1 through 10
zig build -Ddays=..10 solve
```

### Options

```sh
# Disable timing information
zig build -Ddays=1 -Dtime=false solve

# Disable colored output
zig build -Ddays=1 -Dcolor=false solve

# Specify a different year (default: 2025, you can change it in `build.zig`)
zig build -Dyear=2024 -Ddays=1 solve

# Choose input set: example, real, or both (default)
zig build -Ddays=1 -Dinput=example solve

# Build with release-fast optimization
zig build -Ddays=1 -Doptimize=ReleaseFast solve
```

### Run Tests

```sh
# Run tests for a specific day
zig build -Ddays=1 test

# Run tests for multiple days
zig build -Ddays=1..5 test

# Run tests for lib modules
zig build test-lib
```

### Manual Input Fetching

Inputs are fetched automatically when running solutions.
To manually fetch inputs:

```sh
zig build -Ddays=1 fetch-inputs
zig build -Ddays=1..5 fetch-inputs
```

It should be noted that **`dayXX_example.txt`** should be manually added to the `input/2025` directory, as the example input cannot automatically be fetched.

## Project Structure

```
zadvent/
├── build.zig              # Build configuration
├── src/
│   ├── 2025/
│   │   ├── day01.zig      # Day 1 solution
│   │   ├── day02.zig      # Day 2 solution
│   │   └── ...
│   ├── lib/                    # Your custom library
│   ├── lib.zig                 # Library main module (add imports to your lib/ here)
│   ├── fetch_input.zig         # Input fetching logic
│   └── fetch_inputs_main.zig   # Input fetching CLI
├── input/
│   └── .gitkeep
│   └── 2025/
│       ├── day01.txt           # Real input (auto-fetched)
│       ├── day01_example.txt   # Example input (manually added)
│       └── ...
└── README.md
```

## Creating Solutions

Day files are automatically created with a template when you first run a day.
The template includes:

```zig
const std = @import("std");

var buf: [2048]u8 = undefined;

pub fn part1(input: []const u8) ![]const u8 {
    _ = input;
    // Your solution here
    return std.fmt.bufPrint(&buf, "not implemented: {d}", .{0}) catch "error";
}

pub fn part2(input: []const u8) ![]const u8 {
    _ = input;
    // Your solution here
    return std.fmt.bufPrint(&buf, "not implemented: {d}", .{0}) catch "error";
}
```

Both `part1` and `part2` functions must return a string (`[]const u8`).
Use a static buffer like `buf` to format results:

```zig
return std.fmt.bufPrint(&buf, "{d}", .{result}) catch "error";
```

## Example Output

```
$ zig build -Doptimize=ReleaseFast -Ddays=1..2 -Dinput=both solve
Input file already exists: input/2025/day01.txt
Input file already exists: input/2025/day02.txt
[1/1 example] 3
 ╰─ ⏱ 0 ns
[1/1 input] 1177
 ╰─ ⏱ 55000 ns
[1/2 example] 6
 ╰─ ⏱ 0 ns
[1/2 input] 6738
 ╰─ ⏱ 52000 ns
[2/1 example] 1227775554
 ╰─ ⏱ 3000 ns
[2/1 input] 54234399924
 ╰─ ⏱ 17564000 ns
[2/2 example] 4174379265
 ╰─ ⏱ 4000 ns
[2/2 input] 70187097315
 ╰─ ⏱ 29510000 ns
Total time: 48ms
```

- Green text: example input results
- Red text: real input results
- Timing: execution time in nanoseconds
- Total time: total execution time in milliseconds

## Debugging in VS Code (LLDB)

1. Build the target you want to debug so the binary exists (e.g. `zig build -Ddays=2`).
2. In VS Code, select the LLDB launch configuration (provided by the CodeLLDB extension) and start debugging. Point it at `zig-out/bin/advent-of-code` if prompted.
