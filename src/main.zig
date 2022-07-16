const std = @import("std");
const term = @import("term.zig");
const syntax = @import("syntax.zig");
const process = std.process;
const mem = std.mem;
const fs = std.fs;
const math = std.math;
const stdout = std.io.getStdOut();
const stdin = std.io.getStdIn();
const outWriter = stdout.writer();
const inReader = stdin.reader();

const max_file_size = math.pow(usize, 1024, 4) * 1; // 1TB
const line_space_len = 4;
const help_output =
    \\Usage: blo [OPTION]... [FILE]...
    \\With no FILE, reads standard input.
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

pub const Error = error{
    UnkownOption,
};

pub const Config = struct {
    ascii_chars: bool,
    info: bool,
    colors: bool,
    show_end: bool,
    line_number: bool,
};

pub const Blo = struct {
    allocator: mem.Allocator,
    config: Config,

    pub fn init(allocator: mem.Allocator, config: Config) Blo {
        return .{
            .allocator = allocator,
            .config = config,
        };
    }

    /// count integer length
    /// `12 -> 2` `5 -> 1` `555 -> 3`
    fn digitLen(n: usize) usize {
        if (n < 10) return 1;
        return 1 + digitLen(n / 10);
    }

    fn withColor(self: Blo, value: []const u8, color: term.Color, out_color: ?term.Color) ![]const u8 {
        if (self.config.colors) {
            var res = std.ArrayList(u8).init(self.allocator);
            defer res.deinit();

            try res.appendSlice(color.toCode());
            try res.appendSlice(value);
            if (out_color) |out|
                try res.appendSlice(out.toCode());

            return res.toOwnedSlice();
        } else return value;
    }

    pub fn echoStdin(self: Blo) !void {
        while (true) {
            if (try inReader.readUntilDelimiterOrEofAlloc(self.allocator, '\n', max_file_size)) |line| {
                _ = try outWriter.write(line);
                _ = try outWriter.write("\n");
            } else break;
        }
    }

    fn fillSlice(slice: []u8, value: []const u8) void {
        var i: usize = 0;
        while (i < slice.len) : (i += value.len) {
            mem.copy(u8, slice[i .. i + value.len], value);
        }
    }

    pub fn printFile(self: Blo, path: []const u8) !void {
        const file = try fs.cwd().openFile(path, .{});
        const data = try file.readToEndAlloc(self.allocator, max_file_size);

        // space that caused by line numbers
        const line_space = if (self.config.line_number)
            " " ** (line_space_len + 1)
        else
            "";

        // writing file information (header)
        if (self.config.info) {
            // file stat
            const stat = try file.stat();
            // size
            var size_buf_stream = std.io.fixedBufferStream(@as(*[6]u8, undefined));
            try std.fmt.fmtIntSizeBin(stat.size).format("", .{}, size_buf_stream.writer());
            const size = size_buf_stream.getWritten();

            if (self.config.ascii_chars) {
                // ASCII Header
                const header_width = "--  --  --".len + path.len + size.len;

                // Horizontal border
                const horiz_border = try self.allocator.alloc(u8, header_width);
                defer self.allocator.free(horiz_border);
                for (horiz_border) |*c| c.* = '-';

                // print
                try outWriter.print(
                    \\{s}{s}
                    \\{s}-- {s} -- {s} --
                    \\{s}{s}
                    \\
                , .{
                    line_space,
                    self.withColor(horiz_border, .gray, null),

                    line_space,
                    self.withColor(path, .bright_magenta, .gray),
                    self.withColor(size, .green, .gray),

                    line_space,
                    horiz_border,
                });
            } else {
                const padding_width = 2;
                const border_char = "─";

                var path_width = try self.allocator.alloc(u8, (path.len + padding_width) * border_char.len);
                var size_width = try self.allocator.alloc(u8, (size.len + padding_width) * border_char.len);
                fillSlice(path_width, border_char);
                fillSlice(size_width, border_char);
                defer {
                    self.allocator.free(path_width);
                    self.allocator.free(size_width);
                }

                const left_bottom_corner = if (self.config.line_number) "├" else "└";

                try outWriter.print(
                    \\{s}┌{s}┬{s}┐
                    \\{s}│ {s} │ {s} │
                    \\{s}{s}{s}┴{s}┘
                    \\
                , .{
                    self.withColor(line_space, .gray, null),
                    path_width,
                    size_width,
                    line_space,
                    self.withColor(path, .bright_magenta, .gray),
                    self.withColor(size, .green, .gray),
                    line_space,
                    left_bottom_corner,
                    path_width,
                    size_width,
                });
            }
        }

        const line_split_char = if (self.config.ascii_chars) "|" else "│";
        var line_num: usize = 2;
        var line_num_buf: [line_space_len]u8 = undefined;

        if (self.config.line_number) {
            // first line
            try outWriter.print("{s} {s} ", .{
                self.withColor(" " ** (line_space_len - 1) ++ "1", .cyan, .gray),
                line_split_char,
            });
        }

        var syntax_iterator = syntax.SyntaxIterator.init(.json, data, null);

        var i: usize = 0;
        while (syntax_iterator.next()) |token| : (i += 1) {
            if (data[token.start..token.end][0] == '\n') {
                if (self.config.line_number) {
                    try outWriter.print("\n{s} {s} ", .{
                        self.withColor(
                            std.fmt.bufPrintIntToSlice(
                                &line_num_buf,
                                line_num,
                                10,
                                .lower,
                                .{ .width = line_space_len },
                            ),
                            .cyan,
                            .gray,
                        ),
                        line_split_char,
                    });

                    line_num += 1;
                } else {
                    _ = try outWriter.write("\n");
                }
            } else {
                _ = try outWriter.write(try self.withColor(data[token.start..token.end], token.color, null));
            }
        }

        // show EOF with `⏎` or `<END>`
        if (self.config.show_end) {
            if (self.config.ascii_chars)
                _ = try outWriter.write(try self.withColor("<END>", .gray, null))
            else
                _ = try outWriter.write(try self.withColor("⏎", .gray, null));
        }

        // clean up
        _ = try outWriter.write(term.Sgr.reset.toCode());
        _ = try outWriter.write("\n");
    }
};

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

    var config = Config{
        .ascii_chars = false,
        .colors = true,
        .show_end = false,
        .line_number = false,
        .info = false,
    };

    if (!stdout.supportsAnsiEscapeCodes()) {
        config.ascii_chars = true;
        config.colors = false;
    }

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

    const blo = Blo.init(allocator, config);
    if (files.items.len == 0) {
        try blo.echoStdin();
    } else {
        for (files.items) |file, index| {
            try blo.printFile(file);
            if (index < files.items.len - 1) {
                try stdout.writeAll("\n\n");
            }
        }
    }
}
