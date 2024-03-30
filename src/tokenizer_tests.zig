const std = @import("std");

const Token = @import("token.zig").Token;
const TokenType = @import("token.zig").TokenType;
const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));

fn tokenizerTestGood(simple: []const u8, tokens: []const TokenType) !void {
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    for (tokenizer.tokens.items, tokens) |*to_check_token, good_token_type| {
        try std.testing.expectEqual(good_token_type, to_check_token.type);
    }
}

fn tokenizerTestBad(simple: []const u8) !void {
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try std.testing.expectError(Tokenizer.Error.UNEXPECTED_CHAR, tokenizer.tokenize(fixed_buffer_stream.reader()));
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