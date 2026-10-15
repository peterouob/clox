const std = @import("std");

const clox = @import("clox");

const opcode = clox.chunk.Opcode;

pub fn main(init: std.process.Init) !void {
    const Chunk = clox.chunk.Chunk;
    var chunk = Chunk.init(init.gpa);

    const constant: usize = try chunk.addConstant(123);
    try chunk.writeChunk(@backingInt(opcode.OP_CONSTANT), 123);
    try chunk.writeChunk(@intCast(constant), 123);
    try chunk.writeChunk(@backingInt(opcode.OP_RETURN), 123);

    chunk.disassembleChunk("OP_RETURN");

    chunk.deinit();
}
