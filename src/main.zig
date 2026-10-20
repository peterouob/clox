const std = @import("std");
const clox = @import("clox");

const opcode = clox.chunk.Opcode;
const vm = @import("vm.zig");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const io = init.io;
    const gpa = std.mem.Allocator;

    switch (args.len) {
        1 => repl(io, gpa),
        2 => runFile(io, gpa, args[1]),
        else => {
            std.debug.print("Usage: clox [path] \n", .{});
            std.process.exit(64);
        },
    }
}

fn repl(io: std.Io, gpa: std.mem.Allocator) !void {
    const Io = std.Io;

    var in_buf: [1024]u8 = undefined;
    var out_buf: [1024]u8 = undefined;

    var stdin_reader = Io.File.stdin().reader(io, &in_buf);
    var stdout_writer = Io.File.stdout().writer(io, &out_buf);

    const stdin = &stdin_reader.interface;
    const stdout = &stdout_writer.interface;

    var line: Io.Writer.Allocating = .init(gpa);
    defer line.deinit();

    while (true) {
        try stdout.writeAll("> ");
        try stdout.flush();

        _ = stdin.streamDelimiter(&line.writer, '\n') catch |err| switch (err) {
            .EndOfStream => {
                if (line.written().len > 0) interpret(line.written());
                try stdout.writeAll('\n');
                try stdout.flush();
                break;
            },
            else => return err,
        };

        stdin.toss(1);
        interpret(line.written());
    }
}

fn runFile(io: std.IO, gpa: std.mem.Allocator, path: []u8) void {
    const source = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited) catch |err| {
        std.debug.print("Could not open the file \"{s}\" error is: \"{s}\" ", .{ path, @errorName(err) });
        std.process.exit(74);
    };

    const result = interpret(source);
    gpa.free(source);

    switch (result) {
        .INTERPRET_OK => {},
        .INTERPRET_COMPILE_ERROR => std.process.exit(65),
        .INTERPRET_RUNTIME_ERROR => std.process.exit(70),
    }
}

fn interpret(data: []u8) vm.InterpretError!vm.InterpretResult {
    std.debug.print("{any}", .{data});
    return vm.InterpretResult.INTERPRET_OK;
}
