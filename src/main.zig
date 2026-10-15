const std = @import("std");
const Io = std.Io;

const clox = @import("clox");

pub fn main(init: std.process.Init) !void {
    const Chunk = clox.chunk.Chunk;
    var chunk = Chunk.init(init.gpa);

    defer chunk.deinit();

    for (0..10) |_| {
        try chunk.writeChunk('H');
    }

    chunk.print();
}
