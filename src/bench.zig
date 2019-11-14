const builtin = @import("builtin");
const std = @import("std");

const debug = std.debug;
const io = std.io;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const time = std.time;

const Decl = builtin.TypeInfo.Declaration;

pub fn benchmark(comptime B: type) !void {
    const args = if (@hasDecl(B, "args")) B.args else [_]void{{}};
    const iterations: u32 = if (@hasDecl(B, "iterations")) B.iterations else 100000;

    comptime var max_fn_name_len = 0;
    const functions = comptime blk: {
        var res: []const Decl = [_]Decl{};
        for (meta.declarations(B)) |decl| {
            if (decl.data != Decl.Data.Fn)
                continue;

            if (max_fn_name_len < decl.name.len)
                max_fn_name_len = decl.name.len;
            res = res ++ [_]Decl{decl};
        }

        break :blk res;
    };
    if (functions.len == 0)
        @compileError("No benchmarks to run.");

    const max_name_spaces = comptime math.max(max_fn_name_len + digits(u64, 10, args.len) + 1, "Benchmark".len);

    var timer = try time.Timer.start();
    debug.warn("\n");
    debug.warn("Benchmark");
    nTimes(' ', (max_name_spaces - "Benchmark".len) + 1);
    nTimes(' ', digits(u64, 10, math.maxInt(u64)) - "Mean(ns)".len);
    debug.warn("Mean(ns)\n");
    nTimes('-', max_name_spaces + digits(u64, 10, math.maxInt(u64)) + 1);
    debug.warn("\n");

    inline for (functions) |def| {
        for (args) |arg, index| {
            var runtime_sum: u128 = 0;

            var i: usize = 0;
            while (i < iterations) : (i += 1) {
                timer.reset();

                const res = switch (@typeOf(arg)) {
                    void => @noInlineCall(@field(B, def.name)),
                    else => @noInlineCall(@field(B, def.name), arg),
                };

                const runtime = timer.read();
                runtime_sum += runtime;
                doNotOptimize(res);
            }

            const runtime_mean = @intCast(u64, runtime_sum / iterations);

            debug.warn("{}.{}", def.name, index);
            nTimes(' ', (max_name_spaces - (def.name.len + digits(u64, 10, index) + 1)) + 1);
            nTimes(' ', digits(u64, 10, math.maxInt(u64)) - digits(u64, 10, runtime_mean));
            debug.warn("{}\n", runtime_mean);
        }
    }
}

/// Pretend to use the value so the optimizer cant optimize it out.
fn doNotOptimize(val: var) void {
    const T = @typeOf(val);
    var store: T = undefined;
    @ptrCast(*volatile T, &store).* = val;
}

fn digits(comptime N: type, comptime base: comptime_int, n: N) usize {
    comptime var res = 1;
    comptime var check = base;

    inline while (check <= math.maxInt(N)) : ({
        check *= base;
        res += 1;
    }) {
        if (n < check)
            return res;
    }

    return res;
}

fn nTimes(c: u8, times: usize) void {
    var i: usize = 0;
    while (i < times) : (i += 1)
        debug.warn("{c}", c);
}

const sorts = @import("main.zig");
test "ZeeAlloc benchmark" {
    try benchmark(struct {
        const Arg = struct {
            input: []const u8,

            fn benchSort(a: Arg, comptime sort: var) anyerror!void {
                var buffer: [1024 * 1024]u8 = undefined;
                std.mem.copy(u8, buffer[0..], a.input);
                sort(u8, buffer[0..a.input.len], sorts.u8LessThan);
                //try sorts.validate(u8, buffer[0..a.input.len], sorts.u8LessThan);
            }

            fn benchSortAlloc(a: Arg, comptime sort: var) anyerror!void {
                var alloc_buf: [1048576]u8 = undefined;
                var fba = std.heap.FixedBufferAllocator.init(alloc_buf[0..]);

                var buffer: [1024 * 1024]u8 = undefined;
                std.mem.copy(u8, buffer[0..], a.input);
                try sort(u8, &fba.allocator, buffer[0..a.input.len], sorts.u8LessThan);
                //try sorts.validate(u8, buffer[0..a.input.len], sorts.u8LessThan);
            }
        };

        pub const args = [_]Arg{
            Arg{ .input = "zyxabimpncc" },
            Arg{ .input = @embedFile("sorted.data") },
            Arg{ .input = @embedFile("reversed.data") },
            Arg{ .input = @embedFile("rand.data") },
            Arg{ .input = @embedFile("double.data") },
        };

        pub const iterations = 1000;

        pub fn InsertionSort(a: Arg) void {
            a.benchSort(sorts.insertionSort) catch unreachable;
        }

        pub fn QuickSort(a: Arg) void {
            a.benchSort(sorts.quickSort) catch unreachable;
        }

        pub fn MergeSort(a: Arg) void {
            a.benchSortAlloc(sorts.mergeSort) catch unreachable;
        }

        pub fn StdSort(a: Arg) void {
            a.benchSort(std.sort.sort) catch unreachable;
        }
    });
}
