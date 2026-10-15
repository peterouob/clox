const std = @import("std");

pub const Opcode = enum { OP_RETURN };

pub const Chunk = struct {
    count: usize = 0,
    code: []u8 = &.{},
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Chunk {
        return .{ .allocator = allocator };
    }

    pub fn writeChunk(self: *Chunk, byte: u8) !void {
        if (self.count == self.code.len) {
            const new_capacity: usize = growCapacity(self.code.len);
            self.code = try self.allocator.realloc(self.code, new_capacity);
        }
        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn deinit(self: *Chunk) void {
        self.allocator.free(self.code);
        self.* = undefined;
    }

    pub fn print(self: *Chunk) void {
        std.debug.print("count {d}, codes {s}", .{ self.count, self.code });
    }
};

inline fn growCapacity(capacity: usize) usize {
    return if (capacity < 8) 8 else capacity * 2;
}
