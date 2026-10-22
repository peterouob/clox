const std = @import("std");

pub const Scanner = struct {
    source: []const u8,
    start: usize = 0,
    cur: usize = 0,
    line: usize = 1,

    pub fn init(source: []const u8) Scanner {
        return .{ .source = source };
    }

    pub fn scanToken(self: *Scanner) Token {
        self.skipWhiteSpace();
        self.start = self.cur;
        if (self.isEnd()) return self.makeToken(.eof);

        const char: u8 = self.advance();
        switch (char) {
            '(' => return self.makeToken(.left_paren),
            ')' => return self.makeToken(.right_paren),
            '{' => return self.makeToken(.left_brace),
            '}' => return self.makeToken(.right_brace),
            ';' => return self.makeToken(.semicolon),
            ',' => return self.makeToken(.comma),
            '.' => return self.makeToken(.dot),
            '-' => return self.makeToken(.minus),
            '+' => return self.makeToken(.plus),
            '/' => return self.makeToken(.slash),
            '*' => return self.makeToken(.star),
            else => return self.makeToken(.@"error"),
        }

        return self.makeToken(.@"error");
    }

    fn makeToken(self: *Scanner, tokenTyp: TokenType) Token {
        return .{
            .typ = tokenTyp,
            .lexeme = self.source[self.start..self.cur],
            .line = self.line,
        };
    }

    fn advance(self: *Scanner) u8 {
        const char = self.source[self.cur];
        self.cur += 1;
        return char;
    }

    fn isEnd(self: *const Scanner) bool {
        return self.cur >= self.source.len;
    }

    fn match(self: *Scanner, expect: u8) bool {
        if (self.isEnd() or self.source[self.cur] != expect) return false;
        self.cur += 1;
        return true;
    }

    fn skipWhiteSpace(self: *Scanner) void {
        while (true) {
            const c: u8 = self.peek();
            switch (c) {
                ' ', '\r', '\t' => _ = self.advance(),
                '\n' => {
                    self.line += 1;
                    _ = self.advance();
                },
                '/' => {
                    if (self.peekNext() == '/') {
                        while (self.peek() != '\n' and !self.isEnd()) _ = self.advance();
                    } else {
                        return;
                    }
                },
                else => return,
            }
        }
    }

    fn peek(self: *const Scanner) u8 {
        if (self.isEnd()) return 0;
        return self.source[self.cur];
    }

    fn peekNext(self: *Scanner) u8 {
        if (self.cur + 1 >= self.source.len) return 0;
        return self.source[self.cur + 1];
    }
};

pub const TokenType = enum {
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    identifier,
    string,
    number,

    keyword_and,
    keyword_class,
    keyword_else,
    keyword_false,
    keyword_for,
    keyword_fun,
    keyword_if,
    keyword_nil,
    keyword_or,
    keyword_print,
    keyword_return,
    keyword_super,
    keyword_this,
    keyword_true,
    keyword_var,
    keyword_while,
    @"error",
    eof,
};

pub const Token = struct {
    typ: TokenType,
    lexeme: []const u8,
    line: usize,
};

const testing = std.testing;

test "single-character tokens" {
    var scanner = Scanner.init("(){};,.-+/*");
    const expected = [_]TokenType{
        .left_paren, .right_paren, .left_brace, .right_brace,
        .semicolon,  .comma,       .dot,        .minus,
        .plus,       .slash,       .star,       .eof,
    };
    for (expected) |tag| {
        try testing.expectEqual(tag, scanner.scanToken().typ);
    }
}

test "skips whitespace and comments, counts lines" {
    var scanner = Scanner.init("  // comment\n\t+\n-");

    const plus = scanner.scanToken();
    try testing.expectEqual(TokenType.plus, plus.typ);
    try testing.expectEqualStrings("+", plus.lexeme);
    try testing.expectEqual(@as(usize, 2), plus.line);

    const minus = scanner.scanToken();
    try testing.expectEqual(TokenType.minus, minus.typ);
    try testing.expectEqual(@as(usize, 3), minus.line);
}

test "empty source returns eof" {
    var scanner = Scanner.init("");
    try testing.expectEqual(TokenType.eof, scanner.scanToken().typ);
}

test "unexpected character returns error token" {
    var scanner = Scanner.init("@");
    try testing.expectEqual(TokenType.@"error", scanner.scanToken().typ);
}
