const std = @import("std");

const clox = @import("clox");

const opcode = clox.chunk.Opcode;

pub fn main(init: std.process.Init) !void {
    const Chunk = clox.chunk.Chunk;
    const gpa = init.gpa;
    var chunk: Chunk = .{};
    defer chunk.deinit(gpa);

    const constant: usize = try chunk.addConstant(gpa, 123);
    try chunk.writeChunk(gpa, @backingInt(opcode.OP_CONSTANT), 123);
    try chunk.writeChunk(gpa, @intCast(constant), 123);
    try chunk.writeChunk(gpa, @backingInt(opcode.OP_RETURN), 123);

    chunk.disassembleChunk("OP_RETURN");
}
