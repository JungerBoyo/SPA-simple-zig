const std = @import("std");

const Token         = @import("token.zig").Token;
const TokenMetadata = @import("token.zig").TokenMetadata;
const TokenType     = @import("token.zig").TokenType;

pub fn Tokenizer(comptime ErrWriter: type) type { return struct {

const Self = @This();

// Scans any stream of bytes with `anytype` reader
// and generates tokens. Memory is allocated using
// arena allocator and is not freed until `deinit` is
// called. Variable `error_flag` is true when error
// occured during tokenization process.

pub const Error = error {
    TOKENIZER_OUT_OF_MEMORY,
    SIMPLE_STREAM_READING_ERROR,
    UNEXPECTED_CHAR,
};

arena_allocator: std.heap.ArenaAllocator,
tokens: std.ArrayList(Token),
err_log_writer: ErrWriter,

column_no: i32 = 0,
line_no: i32 = 1,
line: ?[]u8 = null,

pub fn init(internal_allocator: std.mem.Allocator, err_log_writer: ErrWriter) Error!*Self {
    var self = internal_allocator.create(Self) catch return Error.TOKENIZER_OUT_OF_MEMORY;
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
    self.tokens = std.ArrayList(Token).init(self.arena_allocator.allocator());
    self.err_log_writer = err_log_writer;
    self.column_no = 0;
    self.line_no = 1;
    self.line = null;
    return self;
}

fn getLine(self: *Self, reader: anytype) !?[]u8 {
    return reader.readUntilDelimiterOrEofAlloc(self.arena_allocator.allocator(), '\n', 1024) catch
    return Error.SIMPLE_STREAM_READING_ERROR;
}

fn onError(self: *Self, message: []const u8) void {
    const line_until_column = self.line.?[0..@intCast(self.column_no)];
    const line_after_column = self.line.?[@intCast(self.column_no + 1)..];
    const char_in_column = self.line.?[@intCast(self.column_no)..@intCast(self.column_no + 1)];

    self.err_log_writer.print("Error at {}:{}: {s}\n\t{s}[{s}]{s}\n", .{
        self.line_no, self.column_no + 1, message,
        line_until_column, char_in_column, line_after_column,
    }) catch unreachable;
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

fn getMetadata(self: *Self) TokenMetadata {
    return TokenMetadata {
        .line_no = self.line_no,
        .column_no = self.column_no,
        .line = self.line.?,
    };
}

fn getValue(self: *Self, end: i32) []u8 {
    return self.line.?[@intCast(self.column_no)..@intCast(end)];
}

fn getChar(self: *Self, i: i32) u8 {
    return self.line.?[@intCast(i)];
}

fn getCurrentChar(self: *Self) u8 {
    return self.getChar(self.column_no);
}

fn parseIntegerToken(self: *Self) Token {
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

fn parseAlphaNumericToken(self: *Self) Token {
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

fn parseOneCharToken(self: *Self, token_type: TokenType) Token {
    defer self.column_no += 1;
    return Token {
        .type = token_type,
        .value = null,
        .metadata = self.getMetadata()
    };
}

fn parseToken(self: *Self) Error!Token {
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
            if (Self.isNumeric(c)) {
                break :blk self.parseIntegerToken();
            }
            if (Self.isLetter(c)) {
                break :blk self.parseAlphaNumericToken();
            }

            self.onError("Unexpected char.");
            break :blk Error.UNEXPECTED_CHAR;
        }
    };
}

pub fn tokenize(self: *Self, reader: anytype) Error!void {
    var eof: bool = false;
    while (!eof) {
        self.line = self.getLine(reader) catch |e| {
            eof = true;
            return e;
        }; 
        if (self.line == null) {
            eof = true;
            break;
        }
        if (self.line.?.len == 0) {
            continue;
        }

        self.column_no = 0;
        while (self.column_no < self.line.?.len) {
            const token = self.parseToken() catch |e| {
                eof = true;
                return e;
            };
            if (token.type == .WHITE) {
                continue;
            }
            self.tokens.append(token) catch return Error.TOKENIZER_OUT_OF_MEMORY;
        }
        self.line_no += 1;
    }

    self.tokens.append(.{ .type = .EOF }) catch return Error.TOKENIZER_OUT_OF_MEMORY;
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

};}
