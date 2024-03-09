const std = @import("std");

////////////////////////////////////////////
////           TOKENIZER BEGIN          ////
////////////////////////////////////////////
const TokenType = enum {
    NAME,           // var/proc
    INTEGER,        // const value

    LEFT_PARENTHESIS,   // '('
    RIGHT_PARENTHESIS,  // ')'
    LEFT_BRACE,         // '{'
    RIGHT_BRACE,        // '}'
    SEMICOLON,          // ';'
    
    PROCEDURE,      // 'procedure'
    IF,             // 'if'
    THEN,           // 'then'
    ELSE,           // 'else'
    WHILE,          // 'while'
    CALL,           // 'call'

    ASSIGN,         // '='
    ADD,            // '+'
    SUB,            // '-'
    MUL,            // '*'

    EOF,    // end of file
    WHITE,  // pseudo-token type used to denote 
            // white char in tokenizer internally
            // means ' ', '\t' and '\r'
};

// Holds metadata to print good
// errors.
const TokenMetadata = struct {
    line_no: i32,
    column_no: i32,
    line: []u8,
};

// Consists of a type, eventually value
// (for pattern tokens) and metadata.
const Token = struct {
    type: TokenType,
    value: ?[]u8 = null,
    metadata: ?TokenMetadata = null,
};

// Scans any stream of bytes with `anytype` reader
// and generates tokens. Memory is allocated using
// arena allocator and is not freed until `deinit` is
// called. Variable `error_flag` is true when error
// occured during tokenization process.
const Tokenizer = struct {
    arena_allocator: std.heap.ArenaAllocator,
    tokens: std.ArrayList(Token),

    error_flag: bool = false,
    column_no: i32 = 0,
    line_no: i32 = 1,
    line: ?[]u8 = null,

    pub fn init(internal_allocator: std.mem.Allocator) !*Tokenizer {
        var self = try internal_allocator.create(Tokenizer);
        self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
        self.tokens = std.ArrayList(Token).init(self.arena_allocator.allocator());
        self.error_flag = false;
        self.column_no = 0;
        self.line_no = 1;
        self.line = null;
        return self;
    }

    fn getLine(self: *Tokenizer, reader: anytype) !?[]u8 {
        return try reader.readUntilDelimiterOrEofAlloc(self.arena_allocator.allocator(), '\n', 1024*1024);
    }

    fn onError(self: *Tokenizer, message: []const u8) void {
        self.error_flag = true;

        const line_until_column = self.line.?[0..@intCast(self.column_no)];
        const line_after_column = self.line.?[@intCast(self.column_no + 1)..];
        const char_in_column = self.line.?[@intCast(self.column_no)..@intCast(self.column_no + 1)];

        std.log.err("Error at {}:{}: {s}\n\t{s}[{s}]{s}", .{
            self.line_no, self.column_no + 1, message,
            line_until_column, char_in_column, line_after_column,
        });
    }

    fn isNumeric(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isLetter(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
    }

    fn isAlphaNumeric(c: u8) bool {
        return isNumeric(c) or isLetter(c);
    }

    fn getMetadata(self: *Tokenizer) TokenMetadata {
        return TokenMetadata {
            .line_no = self.line_no,
            .column_no = self.column_no,
            .line = self.line.?,
        };
    }

    fn getValue(self: *Tokenizer, end: i32) []u8 {
        return self.line.?[@intCast(self.column_no)..@intCast(end)];
    }

    fn getChar(self: *Tokenizer, i: i32) u8 {
        return self.line.?[@intCast(i)];
    }

    fn getCurrentChar(self: *Tokenizer) u8 {
        return self.getChar(self.column_no);
    }

    fn parseIntegerToken(self: *Tokenizer) Token {
        var tmp: i32 = self.column_no + 1;
        while (tmp < self.line.?.len and isNumeric(self.getChar(tmp))) {
            tmp += 1;
        }
        defer self.column_no = tmp; 
        return Token { 
            .type = .INTEGER,
            .value = self.getValue(tmp),
            .metadata = self.getMetadata()
        };
    }

    fn parseAlphaNumericToken(self: *Tokenizer) Token {
        var tmp: i32 = self.column_no + 1;
        while (tmp < self.line.?.len and isAlphaNumeric(self.getChar(tmp))) {
            tmp += 1;
        }
        defer self.column_no = tmp;

        const token_type: TokenType = blk: {
            if (std.mem.eql(u8, self.getValue(tmp), "procedure")) {
                break :blk .PROCEDURE;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "if")) {
                break :blk .IF;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "then")) {
                break :blk .THEN;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "else")) {
                break :blk .ELSE;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "while")) {
                break :blk .WHILE;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "call")) {
                break :blk .CALL;
            }
            break :blk .NAME;
        };

        return Token {
            .type = token_type,
            .value = if (token_type == .NAME) self.getValue(tmp) else null,
            .metadata = self.getMetadata()
        };
    }

    fn parseOneCharToken(self: *Tokenizer, token_type: TokenType) Token {
        defer self.column_no += 1;
        return Token {
            .type = token_type,
            .value = null,
            .metadata = self.getMetadata()
        };
    }

    fn parseToken(self: *Tokenizer) ?Token {
        const c = self.getCurrentChar();
        return switch (c) {
            ' ', '\t', '\r' => blk: { // inluding '\r'... because Windows........ :skull:
                self.column_no += 1; 
                break :blk Token{ .type = .WHITE }; 
            },
            '(' => self.parseOneCharToken( .LEFT_PARENTHESIS ),
            ')' => self.parseOneCharToken( .RIGHT_PARENTHESIS ),
            '{' => self.parseOneCharToken( .LEFT_BRACE ),
            '}' => self.parseOneCharToken( .RIGHT_BRACE ),
            ';' => self.parseOneCharToken( .SEMICOLON ),
            '=' => self.parseOneCharToken( .ASSIGN ),
            '+' => self.parseOneCharToken( .ADD ),
            '-' => self.parseOneCharToken( .SUB ),
            '*' => self.parseOneCharToken( .MUL ),
            else => blk: {
                if (Tokenizer.isNumeric(c)) {
                    break :blk self.parseIntegerToken();
                }
                if (Tokenizer.isLetter(c)) {
                    break :blk self.parseAlphaNumericToken();
                }

                self.onError("Unexpected char.");
                break :blk null;
            }
        };
    }

    pub fn tokenize(self: *Tokenizer, reader: anytype) !void {
        var eof: bool = false;
        while (!eof) {
            self.line = try self.getLine(reader); 
            if (self.line == null) {
                eof = true;
                break;
            }
            if (self.line.?.len == 0) {
                continue;
            }

            self.column_no = 0;
            while (self.column_no < self.line.?.len) {
                var token = self.parseToken();
                if (token == null) { // error (equivalent to `error_flag`)
                    eof = true;
                    break;
                }
                if (token.?.type == .WHITE) {
                    continue;
                }
                try self.tokens.append(token.?);
            }
            self.line_no += 1;
        }

        try self.tokens.append(Token{ .type = .EOF });
    }

    fn deinit(self: *Tokenizer) void {
        self.arena_allocator.deinit();
        self.arena_allocator.child_allocator.destroy(self);
    }
};
////////////////////////////////////////////
////           TOKENIZER END            ////
////////////////////////////////////////////


const AstParser = struct {
};


pub fn main() !void {}

fn tokenizerTestGood(simple: []const u8, tokens: []const TokenType) !void {
    var tokenizer = try Tokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    try std.testing.expectEqual(false, tokenizer.error_flag);
    
    for (tokenizer.tokens.items, tokens) |*to_check_token, good_token_type| {
        try std.testing.expectEqual(good_token_type, to_check_token.type);
    }
}

fn tokenizerTestBad(simple: []const u8) !void {
    var tokenizer = try Tokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    try std.testing.expectEqual(true, tokenizer.error_flag);
}

test "tokenizer#0" {
    const simple = 
    \\procedure First {
    \\  x = 2;
    \\  z = 3;
    \\  call Second;
    \\}
    ;
    const tokens = [_]TokenType {
        .PROCEDURE, .NAME, .LEFT_BRACE,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .CALL, .NAME, .SEMICOLON,
        .RIGHT_BRACE,
        .EOF
    };

    try tokenizerTestGood(simple[0..], tokens[0..]);
}

test "tokenizer#1" {
    const simple = "procedure Third{z=5;v=z;}";
    const tokens = [_]TokenType {
        .PROCEDURE, .NAME, .LEFT_BRACE,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .NAME, .SEMICOLON,
        .RIGHT_BRACE,
        .EOF
    };
    try tokenizerTestGood(simple[0..], tokens[0..]);
}

test "tokenizer#2" {
    const simple = 
    \\procedure Second {
    \\ x = 0;
    \\ i = 5;
    \\ while i {
    \\
    \\x = x + 2 * y;
    \\
    \\call Third;
    \\
    \\i = i - 1; }
    \\ if x then {
    \\
    \\x = x + 1; }
    \\else {
    \\
    \\z = 1; }
    \\ z = z + x + i;
    \\ y = z + 2;
    \\ x = x * y + z; }
    ;
    const tokens = [_]TokenType {
        .PROCEDURE, .NAME, .LEFT_BRACE,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .WHILE, .NAME, .LEFT_BRACE,
                .NAME, .ASSIGN, .NAME, .ADD, .INTEGER, .MUL, .NAME, .SEMICOLON,
                .CALL, .NAME, .SEMICOLON,
                .NAME, .ASSIGN, .NAME, .SUB, .INTEGER, .SEMICOLON,
            .RIGHT_BRACE,
            .IF, .NAME, .THEN, .LEFT_BRACE,
                .NAME, .ASSIGN, .NAME, .ADD, .INTEGER, .SEMICOLON,
            .RIGHT_BRACE, .ELSE, .LEFT_BRACE,
                .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .RIGHT_BRACE,
            .NAME, .ASSIGN, .NAME, .ADD, .NAME, .ADD, .NAME, .SEMICOLON,
            .NAME, .ASSIGN, .NAME, .ADD, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .NAME, .MUL, .NAME, .ADD, .NAME, .SEMICOLON,
        .RIGHT_BRACE,
        .EOF
    };

    try tokenizerTestGood(simple[0..], tokens[0..]);
}

test "tokenizer#3" {
    const simple = "if x then { y! = 1; }";
    try tokenizerTestBad(simple[0..]);
}