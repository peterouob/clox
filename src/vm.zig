const chunk = @import("chunk.zig");
const std = @import("std");

pub const InterpretResult = enum(u8) { INTERPRET_OK };

pub const InterpretError = error{
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunks: std.ArrayList(chunk.Chunk) = .empty,
    ip: usize = 0,

    pub fn deinit(self: *VM, gpa: std.mem.Allocator) void {
        for (self.chunks.items) |*c| c.deinit(gpa);
        self.chunks.deinit(gpa);
        self.* = undefined;
    }
};
