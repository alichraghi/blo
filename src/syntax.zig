const std = @import("std");
const blo = @import("blo.zig");

pub const Token = struct {
    color: blo.Color,
    start: usize,
    end: usize,
};

pub const Language = enum {
    json,
};

pub const Theme = struct {
    string: blo.Color,
    keyword: blo.Color,
    number: blo.Color,
    operator: blo.Color,
    bracket: blo.Color,
    comment: blo.Color,
    variable: blo.Color,
    declaration: blo.Color,
    meaning: blo.Color,
};

pub const SyntaxIterator = struct {
    const default_theme = Theme{
        .string = .Yellow,
        .keyword = .Red,
        .number = .BrightBlue,
        .operator = .BrightRed,
        .bracket = .BrightMagenta,
        .comment = .Gray,
        .variable = .White,
        .declaration = .BrightGreen,
        .meaning = .Gray,
    };

    lang: Language,
    theme: Theme,
    src: []const u8,
    index: usize,
    token: Token,

    pub fn init(lang: Language, theme: ?Theme, src: []const u8) SyntaxIterator {
        return SyntaxIterator{
            .lang = lang,
            .theme = theme orelse default_theme,
            .src = src,
            .index = 0,
            .token = undefined,
        };
    }

    fn c(self: *SyntaxIterator) u8 {
        return self.src[self.index];
    }

    fn lexJSON(self: *SyntaxIterator) void {
        var state: enum {
            start,
            string_literal,
            string_double_literal,
            string_literal_backslash,
            number,
            hexadecimal,
            zero,
            slash,
            comment_start,
            comment_end,
            whitespace,
        } = .start;

        while (self.index < self.src.len) : (self.index += 1) {
            switch (state) {
                .start => switch (self.c()) {
                    ' ', '\t', '\r' => {
                        state = .whitespace;
                    },
                    '\n' => {
                        self.index += 1;
                        break;
                    },
                    '"' => {
                        self.token.color = .Yellow;
                        state = .string_double_literal;
                    },
                    '\'' => {
                        self.token.color = .Yellow;
                        state = .string_literal;
                    },
                    '{', '}', '[', ']' => {
                        self.token.color = .Magenta;
                        self.index += 1;
                        break;
                    },
                    '-' => {
                        self.token.color = .BrightRed;
                        self.index += 1;
                        break;
                    },
                    '/' => {
                        self.token.color = self.theme.comment;
                        state = .slash;
                    },
                    ',', ':' => {
                        self.token.color = .Gray;
                        self.index += 1;
                        break;
                    },
                    '0' => {
                        self.token.color = .Cyan;
                        state = .zero;
                    },
                    '1'...'9' => {
                        self.token.color = .Cyan;
                        state = .number;
                    },
                    else => {
                        self.index += 1;
                        break;
                    },
                },
                .whitespace => switch (self.c()) {
                    ' ', '\t', '\r' => {},
                    else => {
                        break;
                    },
                },
                .string_literal, .string_double_literal => switch (self.c()) {
                    '\\' => {
                        state = .string_literal_backslash;
                    },
                    '"' => {
                        if (state == .string_double_literal) {
                            self.index += 1;
                            break;
                        }
                    },
                    '\'' => {
                        if (state == .string_literal) {
                            self.index += 1;
                            break;
                        }
                    },
                    else => {},
                },
                .string_literal_backslash => state = .string_literal,
                .zero => switch (self.c()) {
                    'x' => {
                        state = .hexadecimal;
                    },
                    else => {
                        break;
                    },
                },
                .number => switch (self.c()) {
                    '0'...'9' => {},
                    else => {
                        break;
                    },
                },
                .hexadecimal => switch (self.c()) {
                    'a'...'f', 'A'...'F', '0'...'9' => {},
                    else => {
                        break;
                    },
                },
                .slash => switch (self.c()) {
                    '*' => state = .comment_start,
                    else => {
                        break;
                    },
                },
                .comment_start => switch (self.c()) {
                    '*' => state = .comment_end,
                    else => {},
                },
                .comment_end => switch (self.c()) {
                    '/' => {
                        self.index += 1;
                        break;
                    },
                    else => state = .comment_start,
                },
            }
        }
    }

    pub fn next(self: *SyntaxIterator) ?Token {
        if (self.index == self.src.len) return null;

        self.token = Token{
            .color = .Reset,
            .start = self.index,
            .end = undefined,
        };

        switch (self.lang) {
            .json => self.lexJSON(),
        }

        self.token.end = self.index;
        return self.token;
    }
};

test "json" {
    const value = @embedFile("../test/json.json");
    var syntax = SyntaxIterator.init(.json, null, value);
    std.debug.print("\n\n-----JSON-----\n", .{});
    var prev_token_end: usize = 0;
    while (syntax.next()) |v| {
        std.debug.assert(prev_token_end == v.start);
        std.debug.print("{s}{s}", .{
            v.color.getColor(),
            value[v.start..v.end],
        });
        prev_token_end = v.end;
    }
    std.debug.print("\x1b[0m\n--------------\n\n", .{});
}
