const std = @import("std");

// imports template
const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const ASTParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()), u32);
const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));
const AST = ASTParser.AST;

comptime {
    _ = @import("tokenizer_tests.zig");
    _ = @import("ast_parser_tests.zig");
    _ = @import("spa_api_tests.zig");
    _ = @import("ast_tests.zig");
}

fn getAST(simple_src: []const u8) !*AST {
    var tokenizer = try Tokenizer.init(std.heap.page_allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple_src);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.heap.page_allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());
    defer parser.deinit();

    return try parser.parse();
}
pub fn main() !void {
    const simple = 
    \\procedure Second {
    \\  x = 0;
    \\  i = 5;
    \\  while i {
    \\      x = x + 2 * y;
    \\      call Third;
    \\      i = i - 1;
    \\  }
    \\  if x then {
    \\      x = x + 1;
    \\  } else {
    \\      z = 1;
    \\  }
    \\  z = z + x + i;
    \\  y = z + 2;
    \\  x = x * y + z;
    \\}
    ;

    var ast = try getAST(simple[0..]);
    defer ast.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .NONE, 1, .NONE, 2));
    result_buffer_stream.reset();
    try std.testing.expect(1 == std.mem.readInt(u32, result_buffer[0..4], .Little));

    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, 2, .NONE, AST.STATEMENT_SELECTED));
    result_buffer_stream.reset();
    try std.testing.expect(3 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    
    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .WHILE, AST.STATEMENT_SELECTED, .IF, 7));
    result_buffer_stream.reset();
    try std.testing.expect(3 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    
    try std.testing.expect(0 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_SELECTED, .IF, 7));
    result_buffer_stream.reset();
    try std.testing.expect(0 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_SELECTED, .IF, AST.STATEMENT_UNDEFINED));
    result_buffer_stream.reset();

    
    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_SELECTED, .WHILE, AST.STATEMENT_UNDEFINED));
    result_buffer_stream.reset();
    try std.testing.expect(2 == std.mem.readInt(u32, result_buffer[0..4], .Little));

    try std.testing.expect(3 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_UNDEFINED, .ASSIGN, AST.STATEMENT_SELECTED));
    
    try std.testing.expect(2 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    try std.testing.expect(11 == std.mem.readInt(u32, result_buffer[4..8], .Little));
    try std.testing.expect(12 == std.mem.readInt(u32, result_buffer[8..12], .Little));
}

