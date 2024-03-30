const std = @import("std");

// imports template
const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const AST = @import("Ast.zig");
const ASTParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()));
const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));

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
    \\  if x then {
    \\      x = x + 1;
    \\      while i {
    \\          x = x + 2 * y;
    \\          call Third;
    \\          i = i - 1;
    \\          if c then { i = 1; } else { i = 2; }
    \\      }
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

    try std.testing.expect(ast.parentTransitive(3, 12));

}

