const chunk = @import("chunk.zig");
const opcode = chunk.Opcode;
const Value = chunk.Value;

const std = @import("std");
const print = std.debug.print;

const MaxStack = 256;

pub const InterpretResult = enum(u8) {
    INTERPRET_OK,
};

pub const InterpretError = error{
    INTERPRET_COMPILE_ERROR,
    INTERPRET_RUNTIME_ERROR,
} || StackError;

const BinaryOP = enum(u8) {
    ADD,
    SUB,
    MUL,
    DIV,
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
                .OP_CONSTANT => try self.stack.push(self.readConstant()),
                .OP_CONSTANT_LONG => try self.stack.push(self.readConstantLong()),
                .OP_NEGATE => try self.stack.push(-self.stack.pop()),
                .OP_BINARY_ADD => try self.binaryOp(.ADD),
                .OP_BINARY_SUB => try self.binaryOp(.SUB),
                .OP_BINARY_MUL => try self.binaryOp(.MUL),
                .OP_BINARY_DIV => try self.binaryOp(.DIV),
                _ => return InterpretError.INTERPRET_RUNTIME_ERROR,
            }
        }
    }

    inline fn readByte(self: *VM) u8 {
        defer self.ip += 1;
        return self.chunk.code.items[self.ip];
    }

    inline fn readConstant(self: *VM) Value {
        return self.chunk.constants.items[self.readByte()];
    }

    inline fn readConstantLong(self: *VM) Value {
        defer self.ip += 3;
        const idx = std.mem.readInt(u24, self.chunk.code.items[self.ip..][0..3], .little);
        return self.chunk.constants.items[idx];
    }

    inline fn binaryOp(self: *VM, comptime op: BinaryOP) !void {
        const b = self.stack.pop();
        const a = self.stack.pop();

        try self.stack.push(switch (op) {
            .ADD => a + b,
            .SUB => a - b,
            .MUL => a * b,
            .DIV => a / b, // this is valid e.g. IEEE754 handle div 0 on f64
        });
    }
};

const StackError = error{StacvkOverFlow};

pub const Stack = struct {
    stack: [MaxStack]Value = undefined,
    stackTop: usize = 0,

    pub fn push(self: *Stack, v: Value) StackError!void {
        if (self.stackTop > MaxStack) {
            return StackError.StacvkOverFlow;
        }

        self.stack[self.stackTop] = v;
        self.stackTop += 1;
    }

    pub fn pop(self: *Stack) Value {
        self.stackTop -= 1;
        return self.stack[self.stackTop];
    }
};

test "test the stack" {
    var stack: Stack = .{};
    try std.testing.expectEqual(0, stack.stackTop);

    for (0..10) |i| try stack.push(@floatFromInt(i));
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

test "vm binary operator" {
    const f = struct {
        fn expectBinaryOp(comptime op: BinaryOP, a: f64, b: f64, expected: f64) !void {
            const gpa = std.testing.allocator;
            var c: chunk.Chunk = .{};

            defer c.deinit(gpa);

            var vm: VM = .{ .chunk = &c };
            try vm.stack.push(a);
            try vm.stack.push(b);
            try vm.binaryOp(op);

            try std.testing.expectEqual(expected, vm.stack.pop());
        }
    };

    try f.expectBinaryOp(.ADD, 1.5, 2.5, 4.0);
    try f.expectBinaryOp(.SUB, 10, 4, 6);
    try f.expectBinaryOp(.MUL, 3, 4, 12);
    try f.expectBinaryOp(.DIV, 10, 4, 2.5);
}
