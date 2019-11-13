const std = @import("std");
const testing = std.testing;

fn swap(comptime T: type, lhs: *T, rhs: *T) void {
    const temp = lhs.*;
    lhs.* = rhs.*;
    rhs.* = temp;
}

pub fn insertionSort(comptime T: type, items: []T, lessThan: fn (lhs: T, rhs: T) bool) void {
    for (items) |_, i| {
        var j: usize = i;
        while (j > 0) : (j -= 1) {
            if (lessThan(items[j], items[j - 1])) {
                swap(T, &items[j], &items[j - 1]);
            } else {
                break;
            }
        }
    }
}

pub fn quickSort(comptime T: type, items: []T, comptime lessThan: fn (lhs: T, rhs: T) bool) void {
    if (items.len < 2) {
        return;
    }

    const mid = items.len / 2;
    const pivot = items[mid];

    var i: usize = 0;
    var j: usize = items.len - 1;
    const pivotIdx = while (true) {
        while (lessThan(items[i], pivot)) : (i += 1) {}
        while (lessThan(pivot, items[j])) : (j -= 1) {}
        if (i < j and lessThan(items[j], items[i])) {
            swap(T, &items[i], &items[j]);
        } else {
            break j;
        }
    } else unreachable;

    quickSort(T, items[0..pivotIdx], lessThan);
    quickSort(T, items[pivotIdx..], lessThan);
}

pub fn quickSortAsync(comptime T: type, allocator: *std.mem.Allocator, items: []T, comptime lessThan: fn (lhs: T, rhs: T) bool) error{OutOfMemory}!void {
    const SelfFrame = @typeOf(@frame().*);

    if (items.len < 2) {
        return;
    }

    const mid = items.len / 2;
    const pivot = items[mid];

    var i: usize = 0;
    var j: usize = items.len - 1;
    const pivotIdx = while (true) {
        while (lessThan(items[i], pivot)) : (i += 1) {}
        while (lessThan(pivot, items[j])) : (j -= 1) {}
        if (i < j and lessThan(items[j], items[i])) {
            swap(T, &items[i], &items[j]);
        } else {
            break j;
        }
    } else unreachable;

    var frame0 = try allocator.create(SelfFrame);
    defer allocator.destroy(frame0);
    var frame1 = try allocator.create(SelfFrame);
    defer allocator.destroy(frame1);

    frame0.* = async quickSortAsync(T, allocator, items[0..pivotIdx], lessThan);
    frame1.* = async quickSortAsync(T, allocator, items[pivotIdx..], lessThan);
    try await frame0;
    try await frame1;
}

pub fn mergeSort(comptime T: type, allocator: *std.mem.Allocator, items: []T, comptime lessThan: fn (lhs: T, rhs: T) bool) !void {
    const Recur = struct {
        fn merge(src: []T, scratch: []T) []T {
            switch (src.len) {
                0, 1 => return src,
                2 => {
                    if (lessThan(src[1], src[0])) {
                        swap(T, &src[1], &src[0]);
                    }
                    return src;
                },
                else => {
                    const mid = src.len / 2;

                    const src0 = src[0..mid];
                    const src1 = src[mid..];

                    const scratch0 = scratch[0..mid];
                    const scratch1 = scratch[mid..];

                    var res0 = merge(src0, scratch0);
                    var res1 = merge(src1, scratch1);

                    const result = if (res0.ptr == scratch0.ptr and res1.ptr == scratch1.ptr)
                        src
                    else blk: {
                        if (res0.ptr == scratch0.ptr) {
                            std.mem.copy(T, src0, res0);
                            res0 = src0;
                        } else if (res1.ptr == scratch1.ptr) {
                            std.mem.copy(T, src1, res1);
                            res1 = src1;
                        }
                        break :blk scratch;
                    };

                    var i: usize = 0;
                    var j: usize = 0;
                    for (result) |*e| {
                        if (i < res0.len and (j >= res1.len or lessThan(res0[i], res1[j]))) {
                            e.* = res0[i];
                            i += 1;
                        } else {
                            e.* = res1[j];
                            j += 1;
                        }
                    }

                    return result;
                },
            }
        }
    };

    var buffer = try allocator.alloc(T, items.len);
    defer allocator.free(buffer);

    const result = Recur.merge(items, buffer);
    if (result.ptr != items.ptr) {
        std.mem.copy(T, items, result);
    }
}

pub fn mergeSortAsync(comptime T: type, allocator: *std.mem.Allocator, items: []T, comptime lessThan: fn (lhs: T, rhs: T) bool) !void {
    const Recur = struct {
        fn merge(alloc: *std.mem.Allocator, src: []T, scratch: []T) error{OutOfMemory}![]T {
            const SelfFrame = @typeOf(@frame().*);

            switch (src.len) {
                0, 1 => return src,
                2 => {
                    if (lessThan(src[1], src[0])) {
                        swap(T, &src[1], &src[0]);
                    }
                    return src;
                },
                else => {
                    const mid = src.len / 2;

                    const src0 = src[0..mid];
                    const src1 = src[mid..];

                    const scratch0 = scratch[0..mid];
                    const scratch1 = scratch[mid..];

                    var frame0 = try alloc.create(SelfFrame);
                    defer alloc.destroy(frame0);
                    var frame1 = try alloc.create(SelfFrame);
                    defer alloc.destroy(frame1);

                    frame0.* = async merge(alloc, src0, scratch0);
                    frame1.* = async merge(alloc, src1, scratch1);

                    var res0 = try await frame0;
                    var res1 = try await frame1;

                    const result = if (res0.ptr == scratch0.ptr and res1.ptr == scratch1.ptr)
                        src
                    else blk: {
                        if (res0.ptr == scratch0.ptr) {
                            std.mem.copy(T, src0, res0);
                            res0 = src0;
                        } else if (res1.ptr == scratch1.ptr) {
                            std.mem.copy(T, src1, res1);
                            res1 = src1;
                        }
                        break :blk scratch;
                    };

                    var i: usize = 0;
                    var j: usize = 0;
                    for (result) |*e| {
                        if (i < res0.len and (j >= res1.len or lessThan(res0[i], res1[j]))) {
                            e.* = res0[i];
                            i += 1;
                        } else {
                            e.* = res1[j];
                            j += 1;
                        }
                    }

                    return result;
                },
            }
        }
    };

    var buffer = try allocator.alloc(T, items.len);
    defer allocator.free(buffer);

    const result = try Recur.merge(allocator, items, buffer);
    if (result.ptr != items.ptr) {
        std.mem.copy(T, items, result);
    }
}

fn checkSorted(comptime T: type, items: []T, lessThan: fn (lhs: T, rhs: T) bool) !void {
    var i: usize = 0;
    while (i < items.len - 1) : (i += 1) {
        if (lessThan(items[i + 1], items[i])) {
            std.debug.warn("Unsorted! {}", items);
            return error.Unsorted;
        }
    }
}

test "basic sort" {
    const helpers = struct {
        fn lessThan(lhs: u8, rhs: u8) bool {
            return lhs < rhs;
        }
    };

    var buf: [0x100000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(buf[0..]);

    const base = "zyxabimpncc";
    var scratch: [base.len]u8 = undefined;

    std.mem.copy(u8, scratch[0..], base[0..]);
    insertionSort(u8, scratch[0..], helpers.lessThan);
    try checkSorted(u8, scratch[0..], helpers.lessThan);

    std.mem.copy(u8, scratch[0..], base[0..]);
    quickSort(u8, scratch[0..], helpers.lessThan);
    try checkSorted(u8, scratch[0..], helpers.lessThan);

    std.mem.copy(u8, scratch[0..], base[0..]);
    _ = async quickSortAsync(u8, &fba.allocator, scratch[0..], helpers.lessThan);
    try checkSorted(u8, scratch[0..], helpers.lessThan);

    std.mem.copy(u8, scratch[0..], base[0..]);
    try mergeSort(u8, &fba.allocator, scratch[0..], helpers.lessThan);
    try checkSorted(u8, scratch[0..], helpers.lessThan);

    std.mem.copy(u8, scratch[0..], base[0..]);
    _ = async mergeSortAsync(u8, &fba.allocator, scratch[0..], helpers.lessThan);
    try checkSorted(u8, scratch[0..], helpers.lessThan);
}
