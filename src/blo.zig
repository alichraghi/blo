const std = @import("std");
const syntax = @import("syntax.zig");
const Color = @import("term.zig").Color;
const mem = std.mem;
const fs = std.fs;

pub const Blo = struct {
    const Self = Blo;
    const max_file_size = 1024 * 1024 * 10;

    pub const Config = struct {
        highlight: bool,
        ascii_chars: bool,
        info: bool,
        colors: bool,
        show_end: bool,
        line_number: bool,
    };

    allocator: mem.Allocator,
    out: fs.File,
    writer: fs.File.Writer,
    config: Config,

    pub fn init(allocator: mem.Allocator, out: fs.File, config: Config) Self {
        var modif_config = config;

        if (!out.supportsAnsiEscapeCodes()) {
            modif_config.ascii_chars = true;
            modif_config.colors = false;
        }

        return .{ .allocator = allocator, .out = out, .writer = out.writer(), .config = modif_config };
    }

    pub fn write(self: Self, data: []const u8) !void {
        try self.writer.writeAll(data);
    }

    pub fn writeNTime(self: Self, data: []const u8) !void {
        try self.writer.writeByteNTimes(data);
    }

    fn writeSliceNTime(self: Self, slice: []const u8, n: usize) !void {
        var i = n;
        while (i > 0) : (i -= 1) {
            try self.writer.writeAll(slice);
        }
    }

    fn print(self: Self, comptime format: []const u8, args: anytype) !void {
        try self.writer.print(format, args);
    }

    // count number length
    fn digitLen(n: usize) usize {
        if (n < 10) return 1;
        return 1 + digitLen(n / 10);
    }

    // Format to human readable size like 10B, 10KB, etc
    fn fmtSize(self: Self, bytes: usize) ![]const u8 {
        const suffix = &[_][]const u8{ "B", "KB", "MB" };
        var size = bytes;
        var i: usize = 0;
        while (size >= 1024) {
            size /= 1024;
            i += 1;
        }
        return std.fmt.allocPrint(self.allocator, "{d} {s}", .{ size, suffix[i] }) catch "Unkown";
    }

    fn fillSlice(slice: []u8, value: []const u8) void {
        var i: usize = 0;
        while (i < slice.len) : (i += value.len) {
            mem.copy(u8, slice[i .. i + value.len], value);
        }
    }

    fn setColor(self: Self, value: []const u8, color: Color, out: ?Color) ![]const u8 {
        if (self.config.colors) {
            var res = std.ArrayList(u8).init(self.allocator);
            defer res.deinit();
            try res.appendSlice(color.toCode());
            try res.appendSlice(value);
            if (out) |out_color| {
                try res.appendSlice(out_color.toCode());
            } else {
                try res.appendSlice(Color.Reset.toCode());
            }
            return res.toOwnedSlice();
        } else return value;
    }

    pub fn printFile(self: Self, path: []const u8) !void {
        // reading file
        const file = try fs.cwd().openFile(path, .{});
        const data = try file.readToEndAlloc(self.allocator, max_file_size);

        // writing file information
        if (self.config.info) {
            // file stat
            const stat = try file.stat();

            // file size
            const size = try self.fmtSize(@intCast(usize, stat.size));

            // file info
            const stat_len = 2; // path - size - owner
            const total_stat_len = path.len + size.len;
            const space = if (self.config.line_number) " " ** 5 else "";

            // printing
            if (self.config.ascii_chars) {
                const width_len = (total_stat_len + (stat_len * 3) + 5);
                const width = try self.allocator.alloc(u8, width_len);
                defer self.allocator.free(width);
                for (width) |*char| char.* = '-';

                try self.print(
                    \\{s}{s}{s}
                    \\{s}-- {s} -- {s} --
                    \\{s}{s}{s}
                    \\
                , .{ space, Color.Gray.toCode(), width, space, self.setColor(path, .Yellow, .Gray), self.setColor(size, .Magenta, .Gray), space, width, Color.Reset.toCode() });
            } else {
                const side_margin = 2;
                const brick = "─";
                var path_width = try self.allocator.alloc(u8, (path.len + side_margin) * brick.len);
                var size_width = try self.allocator.alloc(u8, (size.len + side_margin) * brick.len);
                fillSlice(path_width, brick);
                fillSlice(size_width, brick);
                defer {
                    self.allocator.free(path_width);
                    self.allocator.free(size_width);
                }

                const left_bottom_corner = if (self.config.line_number) "├" else "└";

                try self.print(
                    \\{s}{s}┌{s}┬{s}┐
                    \\{s}│ {s} │ {s} │
                    \\{s}{s}{s}┴{s}┘{s}
                    \\
                , .{
                    space,
                    Color.Gray.toCode(),
                    path_width,
                    size_width,
                    space,
                    self.setColor(path, .Yellow, .Gray),
                    self.setColor(size, .Magenta, .Gray),
                    space,
                    left_bottom_corner,
                    path_width,
                    size_width,
                    Color.Reset.toCode(),
                });
            }
        }

        // check for line numbers
        if (self.config.line_number) {
            var line_num: usize = 1;
            if (self.config.highlight) {
                var syntax_iterator = syntax.SyntaxIterator.init(.json, null, data);
                const line_split_char = if (self.config.ascii_chars) "|" else "│";
                var i: usize = 0;
                while (syntax_iterator.next()) |token| : (i += 1) {
                    const lnl = digitLen(line_num); // line number length
                    if (i == 0) {
                        try self.writer.writeByteNTimes(' ', 4 - lnl);
                        try self.writer.print("{s}{d}{s} {s} ", .{ Color.Cyan.toCode(), line_num, Color.Reset.toCode(), self.setColor(line_split_char, .Gray, null) });
                        try self.writer.writeAll(token.color.toCode());
                        try self.writer.writeAll(data[token.start..token.end]);
                    } else if (data[token.start..token.end][0] == '\n') {
                        line_num += 1;
                        try self.writer.writeByte('\n');
                        try self.writer.writeByteNTimes(' ', 4 - lnl);
                        try self.writer.print("{s}{d}{s} {s} ", .{ Color.Cyan.toCode(), line_num, Color.Reset.toCode(), self.setColor(line_split_char, .Gray, null) });
                    } else {
                        try self.writer.writeAll(token.color.toCode());
                        try self.writer.writeAll(data[token.start..token.end]);
                    }
                }
            } else {
                var lines = mem.split(u8, data, "\n");
                const line_split_char = if (self.config.ascii_chars) "|" else "│";
                while (lines.next()) |line| : (line_num += 1) {
                    const lnl = digitLen(line_num); // line number length
                    try self.writer.writeByteNTimes(' ', 4 - lnl);
                    try self.writer.print("{s}{d}{s} {s} ", .{ Color.Cyan.toCode(), line_num, Color.Reset.toCode(), self.setColor(line_split_char, .Gray, null) });
                    try self.writer.writeAll(line);
                    if (lines.index != null) try self.writer.writeByte('\n');
                }
            }
        } else {
            if (self.config.highlight) {
                var syntax_iterator = syntax.SyntaxIterator.init(.json, null, data);
                while (syntax_iterator.next()) |token| {
                    try self.writer.writeAll(token.color.toCode());
                    try self.writer.writeAll(data[token.start..token.end]);
                }
            } else {
                try self.writer.writeAll(data);
            }
        }

        // show file end with <end>
        if (self.config.show_end) {
            try self.writer.writeAll("<end>");
        }
    }
};
