pub const Color = enum {
    Reset,
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    Gray,
    BrightRed,
    BrightGreen,
    BrightYellow,
    BrightBlue,
    BrightMagenta,
    BrightCyan,
    BrightWhite,

    pub fn toCode(self: Color) []const u8 {
        return switch (self) {
            .Reset => "\x1b[0m",
            .Black => "\x1b[30m",
            .Red => "\x1b[31m",
            .Green => "\x1b[32m",
            .Yellow => "\x1b[33m",
            .Blue => "\x1b[34m",
            .Magenta => "\x1b[35m",
            .Cyan => "\x1b[36m",
            .White => "\x1b[37m",
            .Gray => "\x1b[90m",
            .BrightRed => "\x1b[91m",
            .BrightGreen => "\x1b[92m",
            .BrightYellow => "\x1b[93m",
            .BrightBlue => "\x1b[94m",
            .BrightMagenta => "\x1b[95m",
            .BrightCyan => "\x1b[96m",
            .BrightWhite => "\x1b[97m",
        };
    }
};
