/// Tab
pub const TAB = "\x09";
/// Line Feed
pub const LF = "\x0A";
/// From Feed
pub const FF = "\x0C";
/// Carriage Return
pub const CR = "\x0D";
/// ANSI Escape Code
pub const ESC = "\x1B";

pub const Sgr = enum(u4) {
    reset = 0,
    bold = 1,
    dim = 2,
    italic = 3,
    underline = 4,
    blinking = 5,
    reverse = 7,
    hidden = 8,
    strike = 9,

    pub fn toCode(self: Sgr) []const u8 {
        return switch (self) {
            .reset => ESC ++ "[0m",
            .bold => ESC ++ "[1m",
            .dim => ESC ++ "[2m",
            .italic => ESC ++ "[3m",
            .underline => ESC ++ "[4m",
            .blinking => ESC ++ "[5m",
            .reverse => ESC ++ "[7m",
            .hidden => ESC ++ "[8m",
            .strike => ESC ++ "[9m",
        };
    }
};

pub const Color = enum(u7) {
    black = 30,
    red = 31,
    green = 32,
    yellow = 33,
    blue = 34,
    magenta = 35,
    cyan = 36,
    white = 37,
    default = 39,
    gray = 90,
    bright_red = 91,
    bright_green = 92,
    bright_yellow = 93,
    bright_blue = 94,
    bright_magenta = 95,
    bright_cyan = 96,
    bright_white = 97,

    pub fn toCode(self: Color) []const u8 {
        return switch (self) {
            .black => ESC ++ "[30m",
            .red => ESC ++ "[31m",
            .green => ESC ++ "[32m",
            .yellow => ESC ++ "[33m",
            .blue => ESC ++ "[34m",
            .magenta => ESC ++ "[35m",
            .cyan => ESC ++ "[36m",
            .white => ESC ++ "[37m",
            .default => ESC ++ "[39m",
            .gray => ESC ++ "[90m",
            .bright_red => ESC ++ "[91m",
            .bright_green => ESC ++ "[92m",
            .bright_yellow => ESC ++ "[93m",
            .bright_blue => ESC ++ "[94m",
            .bright_magenta => ESC ++ "[95m",
            .bright_cyan => ESC ++ "[96m",
            .bright_white => ESC ++ "[97m",
        };
    }
};
