const std = @import("std");
const mem = @import("mem.zig");

pub const Opcode = enum(u8) {
    OP_RETURN,
    _,
};

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

    pub fn freeChunk(self: *Chunk) void {
        mem.freeArray(u8, self.allocator, self.code);
        self.* = init(self.allocator);
    }

    pub fn print(self: *Chunk) void {
        std.debug.print("count {d}, codes {s}", .{ self.count, self.code });
    }

    pub fn disassembleChunk(
        self: *const Chunk,
        name: []const u8,
    ) void {
        std.debug.print("=== {s} === \n", .{name});

        var offset: usize = 0;
        while (offset < self.count) {
            offset = self.disassembleIns(offset, name);
        }
    }

    pub fn disassembleIns(self: *const Chunk, offset: usize, name: []const u8) usize {
        const instruction = self.code[offset];
        switch (@as(Opcode, @fromBackingInt(instruction))) {
            .OP_RETURN => return simpleIns(name, offset),
            _ => {
                std.debug.print("unknown op code {d}\n", .{instruction});
                return offset + 1;
            },
        }
    }
};

fn simpleIns(name: []const u8, offset: usize) usize {
    std.debug.print("{s} \n", .{name});
    return offset + 1;
}
