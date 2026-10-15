const std = @import("std");
const print = std.debug.print;

pub const Opcode = enum(u8) {
    OP_CONSTANT,
    OP_RETURN,
    _,
};

const Value = f64;

pub const Chunk = struct {
    code: std.ArrayList(u8) = .empty,
    lines: std.ArrayList(u32) = .empty,
    constants: std.ArrayList(Value) = .empty,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Chunk {
        return .{ .allocator = allocator };
    }

    pub fn writeChunk(self: *Chunk, byte: u8, line: u32) !void {
        try self.code.append(self.allocator, byte);
        try self.lines.append(self.allocator, line);
    }

    pub fn deinit(self: *Chunk) void {
        self.code.deinit(self.allocator);
        self.lines.deinit(self.allocator);
        self.constants.deinit(self.allocator);
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
        const lines = self.lines.items;

        print("{d:0>4} ", .{offset});
        if (offset > 0 and lines[offset] == lines[offset - 1])
            print("   | ", .{})
        else
            print("{d:>4} ", .{lines[offset]});

        const instruction = self.code.items[offset];
        switch (@as(Opcode, @fromBackingInt(instruction))) {
            .OP_RETURN => return simpleIns("OP_RETURN", offset),
            .OP_CONSTANT => return self.constantIns("OP_CONSTANT", offset),
            _ => {
                print("unknown op code {d}\n", .{instruction});
                return offset + 1;
            },
        }
    }

    pub fn addConstant(self: *Chunk, value: Value) !usize {
        try self.constants.append(self.allocator, value);
        return self.constants.items.len - 1;
    }

    pub fn constantIns(self: *const Chunk, name: []const u8, offset: usize) usize {
        const constant: usize = self.code.items[offset + 1];
        const value = self.constants.items[constant];
        print("{s:<16} {d:>4} '{d}'\n", .{ name, constant, value });
        return offset + 2;
    }
};

fn simpleIns(name: []const u8, offset: usize) usize {
    print("{s}\n", .{name});
    return offset + 1;
}

test "chunk grows past init capacity without leaking" {
    const gpa = std.testing.allocator;
    var chunk = Chunk.init(gpa);
    defer chunk.deinit();

    for (0..100) |i| try chunk.writeChunk(@intCast(i), @intCast(i));
    const idx = try chunk.addConstant(1.5);

    try std.testing.expectEqual(100, chunk.code.items.len);
    try std.testing.expectEqual(99, chunk.lines.items[99]);
    try std.testing.expectEqual(1.5, chunk.constants.items[idx]);
}
