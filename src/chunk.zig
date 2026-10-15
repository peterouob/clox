const std = @import("std");
const print = std.debug.print;

pub const Opcode = enum(u8) {
    OP_CONSTANT,
    OP_CONSTANT_LONG,
    OP_RETURN,
};

const LineStart = struct {
    line: u32,
    offset: usize,
};

const ChunkError = error{
    TooBigOverflow,
} || std.mem.Allocator.Error;

const Value = f64;

pub const Chunk = struct {
    code: std.ArrayList(u8) = .empty,
    lines: std.ArrayList(LineStart) = .empty,
    constants: std.ArrayList(Value) = .empty,

    pub fn writeChunk(self: *Chunk, gpa: std.mem.Allocator, byte: u8, line: u32) ChunkError!void {
        const offset = self.code.items.len;
        try self.code.append(gpa, byte);

        const lines = self.lines.items;
        if (lines.len > 0 and lines[lines.len - 1].line == line) return;

        try self.lines.append(gpa, .{ .line = line, .offset = offset });
    }

    pub fn writeConstant(self: *Chunk, gpa: std.mem.Allocator, value: Value, line: u32) ChunkError!void {
        if (self.constants.items.len > std.math.maxInt(u24)) return ChunkError.TooBigOverflow;
        const idx = try self.addConstant(gpa, value);

        if (idx <= std.math.maxInt(u8)) {
            try self.writeChunk(gpa, @backingInt(Opcode.OP_CONSTANT), line);
            try self.writeChunk(gpa, @intCast(idx), line);
        } else {
            try self.writeChunk(gpa, @backingInt(Opcode.OP_CONSTANT_LONG), line);
            var buf: [3]u8 = undefined;
            std.mem.writeInt(u24, &buf, @intCast(idx), .little);
            for (buf) |b| try self.writeChunk(gpa, b, line);
        }
    }

    pub fn getLine(self: *const Chunk, offset: usize) u32 {
        std.debug.assert(offset < self.code.items.len);

        const lines = self.lines.items;
        const idx = std.sort.partitionPoint(LineStart, lines, offset, struct {
            fn pred(target: usize, l: LineStart) bool {
                return l.offset <= target;
            }
        }.pred);

        return lines[idx - 1].line;
    }

    pub fn deinit(self: *Chunk, gpa: std.mem.Allocator) void {
        self.code.deinit(gpa);
        self.lines.deinit(gpa);
        self.constants.deinit(gpa);
        self.* = undefined;
    }

    pub fn disassembleChunk(
        self: *const Chunk,
        name: []const u8,
    ) void {
        print("=== {s} === \n", .{name});

        var offset: usize = 0;
        while (offset < self.code.items.len) {
            offset = self.disassembleIns(offset);
        }
    }

    pub fn disassembleIns(self: *const Chunk, offset: usize) usize {
        print("{d:0>4} ", .{offset});
        const line = self.getLine(offset);

        if (offset > 0 and line == self.getLine(offset - 1))
            print("   | ", .{})
        else
            print("{d:>4} ", .{line});

        const instruction = self.code.items[offset];
        switch (@as(Opcode, @fromBackingInt(instruction))) {
            .OP_RETURN => return simpleIns("OP_RETURN", offset),
            .OP_CONSTANT => return self.constantIns("OP_CONSTANT", offset),
            .OP_CONSTANT_LONG => return self.constantLongIns("OP_CONSTANT_LONG", offset),
            _ => {
                print("unknown op code {d}\n", .{instruction});
                return offset + 1;
            },
        }
    }

    pub fn addConstant(self: *Chunk, gpa: std.mem.Allocator, value: Value) !usize {
        try self.constants.append(gpa, value);
        return self.constants.items.len - 1;
    }

    pub fn constantIns(self: *const Chunk, name: []const u8, offset: usize) usize {
        const constant: usize = self.code.items[offset + 1];
        const value = self.constants.items[constant];
        print("{s:<16} {d:>4} '{d}'\n", .{ name, constant, value });
        return offset + 2;
    }

    pub fn constantLongIns(self: *const Chunk, name: []const u8, offset: usize) usize {
        const code = self.code.items;
        const constant = std.mem.readInt(u24, code[offset + 1 ..][0..3], .little);
        print("{s:<16} {d:>4}\n", .{ name, constant });
        return offset + 4;
    }
};

fn simpleIns(name: []const u8, offset: usize) usize {
    print("{s}\n", .{name});
    return offset + 1;
}

test "chunk grows past init capacity without leaking" {
    const gpa = std.testing.allocator;
    var chunk: Chunk = .{};
    defer chunk.deinit(gpa);

    for (0..100) |i| try chunk.writeChunk(gpa, @intCast(i), @intCast(i));
    const idx = try chunk.addConstant(gpa, 1.5);

    try std.testing.expectEqual(100, chunk.code.items.len);
    try std.testing.expectEqual(99, chunk.getLine(99));
    try std.testing.expectEqual(1.5, chunk.constants.items[idx]);
}

test "same line instructions are run-length encoded" {
    const gpa = std.testing.allocator;
    var chunk: Chunk = .{};
    defer chunk.deinit(gpa);

    try chunk.writeChunk(gpa, 0, 10);
    try chunk.writeChunk(gpa, 1, 10);
    try chunk.writeChunk(gpa, 2, 10);
    try chunk.writeChunk(gpa, 3, 11);
    try chunk.writeChunk(gpa, 4, 11);

    try std.testing.expectEqual(2, chunk.lines.items.len);
    try std.testing.expectEqual(10, chunk.getLine(0));
    try std.testing.expectEqual(10, chunk.getLine(2));
    try std.testing.expectEqual(11, chunk.getLine(3));
    try std.testing.expectEqual(11, chunk.getLine(4));
}

test "write constant switch after bigger than 256 constant" {
    const gpa = std.testing.allocator;
    var chunk: Chunk = .{};
    defer chunk.deinit(gpa);

    for (0..256) |i| try chunk.writeConstant(gpa, @floatFromInt(i), 1);

    const code = chunk.code.items;
    try std.testing.expectEqual(512, code.len);
    try std.testing.expectEqual(@backingInt(Opcode.OP_CONSTANT), code[510]);
    try std.testing.expectEqual(255, code[511]);

    try chunk.writeConstant(gpa, 256.0, 2);
    const code_ = chunk.code.items;

    try std.testing.expectEqual(516, code_.len);
    try std.testing.expectEqual(@backingInt(Opcode.OP_CONSTANT_LONG), code_[512]);
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x01, 0x00 }, code_[513..516]);
}

test "too big id error handle" {
    const gpa = std.testing.allocator;
    var chunk: Chunk = .{};
    defer chunk.deinit(gpa);

    try chunk.constants.appendNTimes(gpa, 0, std.math.maxInt(u24) + 1);
    const before_len = chunk.code.items.len;
    try std.testing.expectError(ChunkError.TooBigOverflow, chunk.writeConstant(gpa, 1.0, 1));
    try std.testing.expectEqual(before_len, chunk.code.items.len);
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u24) + 1), chunk.constants.items.len);
}
