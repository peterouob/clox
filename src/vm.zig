const chunk = @import("chunk.zig");
const std = @import("std");

pub const InterpretResult = enum(u8) { INTERPRET_OK };

pub const InterpretError = error{
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunks: std.ArrayList(chunk) = .empty,
    ip: usize = 0,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) VM {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *VM) void {
        self.allocator.free(self.chunks);
        self.* = undefined;
    }
};
