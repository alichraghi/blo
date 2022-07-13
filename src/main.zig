const std = @import("std");
const Blo = @import("blo.zig").Blo;
const process = std.process;
const mem = std.mem;
const fs = std.fs;
const stdout = std.io.getStdOut();
const stdin = std.io.getStdIn();

pub const Error = error{
    UnkownOption,
};

const help_output =
    \\Usage: blo [OPTION]... [FILE]...
    \\With no FILE, read standard input.
    \\
    \\Options:
    \\-n, --number          prints number of lines
    \\-i, --info            prints the file info (size, mime, modification, etc)
    \\-e, --show-end        prints <end> after file
    \\-a, --ascii           uses ascii chars to print info and lines delimiter
    \\-c, --no-color        disable printing colored output
    \\-h, --help            display this help and exit
    \\
    \\Examples:
    \\blo test.txt          prints the test.txt content
    \\blo                   copy standard input to output
;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    const args = try process.argsAlloc(allocator);
    var files = std.ArrayList([]u8).init(allocator);
    defer {
        process.argsFree(allocator, args);
        files.deinit();
        arena.deinit();
    }

    var config = Blo.Config{
        .highlight = true,
        .ascii_chars = false,
        .colors = true,
        .show_end = false,
        .line_number = false,
        .info = false,
    };

    for (args[1..]) |arg| {
        if (arg.len > 1 and arg[0] == '-') {
            if (mem.eql(u8, arg, "-a") or mem.eql(u8, arg, "--ascii")) {
                config.ascii_chars = true;
            } else if (mem.eql(u8, arg, "-c") or mem.eql(u8, arg, "--no-color")) {
                config.colors = false;
            } else if (mem.eql(u8, arg, "-e") or mem.eql(u8, arg, "--show-end")) {
                config.show_end = true;
            } else if (mem.eql(u8, arg, "-n") or mem.eql(u8, arg, "--number")) {
                config.line_number = true;
            } else if (mem.eql(u8, arg, "-i") or mem.eql(u8, arg, "--info")) {
                config.info = true;
            } else if (mem.eql(u8, arg, "-h") or mem.eql(u8, arg, "--help")) {
                try stdout.writeAll(help_output);
                return;
            } else {
                return Error.UnkownOption;
            }
        } else {
            try files.append(arg);
        }
    }

    if (files.items.len == 0) {
        while (true) {
            var buf: [1024]u8 = undefined;
            if (try stdin.reader().readUntilDelimiterOrEof(&buf, '\n')) |line| {
                try stdout.writer().print("{s}\n", .{line});
            } else break;
        }
    } else {
        const blo = Blo.init(allocator, stdout, config);

        for (files.items) |file, index| {
            try blo.printFile(file);
            if (index < files.items.len - 1) {
                try blo.write("\n\n");
            }
        }
    }
}
