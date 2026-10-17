const chunk = @import("chunk.zig");
const opcode = chunk.Opcode;
const value = chunk.Value;

const std = @import("std");
const print = std.debug.print;

pub const InterpretResult = enum(u8) { INTERPRET_OK };

pub const InterpretError = error{
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *chunk.Chunk = undefined,
    ip: usize = 0,

    pub fn deinit(self: *VM, gpa: std.mem.Allocator) void {
        for (self.chunks.items) |*c| c.deinit(gpa);
        self.chunks.deinit(gpa);
        self.* = undefined;
    }

    pub fn run(self: *VM) InterpretError!InterpretResult {
        while (true) {
            const ins: opcode = @backingInt(self.readByte());
            switch (ins) {
                opcode.OP_RETURN => return InterpretResult.INTERPRET_OK,
                opcode.OP_CONSTANT => {
                    const constant: value = self.readConstant();
                    print("{d}\n", constant);
                    break;
                },
            }
        }
    }

    inline fn readByte(self: *VM) u8 {
        defer self.ip += 1;
        return self.chunk.code.items[self.ip];
    }

    inline fn readConstant(self: *VM) u8 {
        return self.chunk.constants.items[self.readByte()];
    }
};
