const chunk = @import("chunk.zig");
const opcode = chunk.Opcode;
const value = chunk.Value;

const std = @import("std");
const print = std.debug.print;

const MaxStack = 256;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
};

pub const InterpretError = error{
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
};

pub const VM = struct {
    chunk: *const chunk.Chunk,
    ip: usize = 0,
    stack: Stack = .{},

    pub fn run(self: *VM) InterpretError!InterpretResult {
        while (true) {
            const ins: opcode = @fromBackingInt(self.readByte());
            switch (ins) {
                .OP_RETURN => {
                    print("{d}\n", .{self.stack.pop()});
                    return .INTERPRET_OK;
                },
                .OP_CONSTANT => self.stack.push(self.readConstant()),
                .OP_CONSTANT_LONG => self.stack.push(self.readConstantLong()),
                _ => return InterpretError.INTERPRET_RUNTIME_ERROR,
            }
        }
    }

    inline fn readByte(self: *VM) u8 {
        defer self.ip += 1;
        return self.chunk.code.items[self.ip];
    }

    inline fn readConstant(self: *VM) value {
        return self.chunk.constants.items[self.readByte()];
    }

    inline fn readConstantLong(self: *VM) value {
        defer self.ip += 3;
        const idx = std.mem.readInt(u24, self.chunk.code.items[self.ip..][0..3], .little);
        return self.chunk.constants.items[idx];
    }
};

pub const Stack = struct {
    stack: [MaxStack]value = undefined,
    stackTop: usize = 0,

    pub fn push(self: *Stack, v: value) void {
        self.stack[self.stackTop] = v;
        self.stackTop += 1;
    }

    pub fn pop(self: *Stack) value {
        self.stackTop -= 1;
        return self.stack[self.stackTop];
    }
};

test "test the stack" {
    var stack: Stack = .{};
    try std.testing.expectEqual(0, stack.stackTop);

    for (0..10) |i| stack.push(@floatFromInt(i));
    try std.testing.expectEqual(10, stack.stackTop);
    try std.testing.expectEqual(9.0, stack.pop());
    try std.testing.expectEqual(9, stack.stackTop);
}

test "vm runs constant and long constant then returns" {
    const gpa = std.testing.allocator;
    var c: chunk.Chunk = .{};
    defer c.deinit(gpa);

    for (0..256) |i| _ = try c.addConstant(gpa, @floatFromInt(i));
    try c.writeConstant(gpa, 1.5, 1);
    try c.writeConstant(gpa, 2.5, 1);
    try c.writeChunk(gpa, @backingInt(opcode.OP_RETURN), 1);

    var vm: VM = .{ .chunk = &c };
    try std.testing.expectEqual(.INTERPRET_OK, try vm.run());
    try std.testing.expectEqual(1, vm.stack.stackTop);
    try std.testing.expectEqual(1.5, vm.stack.stack[0]);
}

test "unknown opcode is a runtime error" {
    const gpa = std.testing.allocator;
    var c: chunk.Chunk = .{};
    defer c.deinit(gpa);
    try c.writeChunk(gpa, 0xff, 1);

    var vm: VM = .{ .chunk = &c };
    try std.testing.expectError(InterpretError.INTERPRET_RUNTIME_ERROR, vm.run());
}
