const std = @import("std");
const Allocator = std.mem.Allocator;

pub inline fn growCapacity(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}

fn reallocate(comptime T: type, allocator: Allocator, old: []T, new_count: usize) ![]T {
    if (new_count == 0) {
        allocator.free(old);
        return &.{};
    }

    return allocator.realloc(old, new_count);
}

pub fn growArray(comptime T: type, allocator: Allocator, old: []T, new_count: usize) ![]T {
    return reallocate(T, allocator, old, new_count);
}

pub fn freeArray(comptime T: type, allocator: Allocator, old: []T) void {
    _ = reallocate(T, allocator, old, 0) catch unreachable;
}
