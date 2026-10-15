const std = @import("std");
const mem = @import("mem.zig");

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
            const new_capacity: usize = mem.growCapacity(self.code.len);
            self.code = try mem.growArray(u8, self.allocator, self.code, new_capacity);
        }
        self.code[self.count] = byte;
        self.count += 1;
    }

    pub fn deinit(self: *Chunk) void {
        mem.freeArray(u8, self.allocator, self.code);
        self.* = undefined;
    }

    pub fn print(self: *Chunk) void {
        std.debug.print("count {d}, codes {s}", .{ self.count, self.code });
    }
};
