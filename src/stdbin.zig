const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;
const math = std.math;
const builtin = @import("builtin");

/// Stable in-place sort. O(n) best case, O(pow(n, 2)) worst case. O(1) memory (no allocator required).
/// Uses binary search, which can be 2x better than iterative comparisons
pub fn insertionSort(comptime T: type, items: []T, lessThan: fn (T, T) bool) void {
    var i: usize = 1;
    while (i < items.len) : (i += 1) {
        // Skip search + rotate on already sorted pairs
        if (!lessThan(items[i], items[i - 1])) continue;

        const val = items[i];
        const ins = binaryLast(T, items, val, Range{ .start = 0, .end = i }, lessThan);
        std.mem.copyBackwards(T, items[ins + 1 ..], items[ins..i]);
        items[ins] = val;
    }
}

const Range = struct {
    start: usize,
    end: usize,

    fn init(start: usize, end: usize) Range {
        return Range{
            .start = start,
            .end = end,
        };
    }

    fn length(self: Range) usize {
        return self.end - self.start;
    }
};

fn binaryFirst(comptime T: type, items: []T, value: T, range: Range, lessThan: fn (T, T) bool) usize {
    var start = range.start;
    var end = range.end - 1;
    if (range.start >= range.end) return range.end;
    while (start < end) {
        const mid = start + (end - start) / 2;
        if (lessThan(items[mid], value)) {
            start = mid + 1;
        } else {
            end = mid;
        }
    }
    if (start == range.end - 1 and lessThan(items[start], value)) {
        start += 1;
    }
    return start;
}

fn binaryLast(comptime T: type, items: []T, value: T, range: Range, lessThan: fn (T, T) bool) usize {
    var curr = range.start;
    var size = range.length();
    if (range.start >= range.end) return range.end;
    while (size > 0) {
        const shift = size % 2;

        size /= 2;
        const mid = items[curr + size];
        if (!lessThan(value, mid)) {
            curr += size + shift;
        }
    }
    return curr;
}
