const std = @import("std");

const clox = @import("clox");

pub fn main(init: std.process.Init) !void {
    const Chunk = clox.chunk.Chunk;
    var chunk = Chunk.init(init.gpa);

    const opcode = clox.chunk.Opcode;

    for (0..10) |_| {
        try chunk.writeChunk(@backingInt(opcode.OP_RETURN));
    }

    chunk.disassembleChunk("OP_RETURN");

    chunk.deinit();
}
