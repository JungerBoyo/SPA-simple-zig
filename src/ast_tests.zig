const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const AST = @import("Ast.zig");
const ASTParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()));
const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));

fn getAST(simple_src: []const u8) !*AST {
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple_src);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());
    defer parser.deinit();

    return try parser.parse();
}

test "follows" {
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

    try std.testing.expect(ast.follows(1, 2));
    try std.testing.expect(ast.follows(2, 3));
    try std.testing.expect(!ast.follows(3, 4));
    try std.testing.expect(ast.follows(4, 5));
    try std.testing.expect(ast.follows(5, 6));
    try std.testing.expect(!ast.follows(6, 7));
    try std.testing.expect(ast.follows(3, 7));
    try std.testing.expect(!ast.follows(7, 8));
    try std.testing.expect(!ast.follows(8, 9));
    try std.testing.expect(ast.follows(7, 10));
    try std.testing.expect(ast.follows(10, 11));
    try std.testing.expect(ast.follows(11, 12));
    try std.testing.expect(!ast.follows(12, 13));
}

test "follows*" {
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

    try std.testing.expect(ast.followsTransitive(1, 2));
    try std.testing.expect(ast.followsTransitive(2, 3));
    try std.testing.expect(ast.followsTransitive(1, 3));
    try std.testing.expect(!ast.followsTransitive(3, 4));
    try std.testing.expect(ast.followsTransitive(4, 5));
    try std.testing.expect(ast.followsTransitive(5, 6));
    try std.testing.expect(!ast.followsTransitive(6, 7));
    try std.testing.expect(ast.followsTransitive(3, 7));
    try std.testing.expect(!ast.followsTransitive(7, 8));
    try std.testing.expect(!ast.followsTransitive(8, 9));
    try std.testing.expect(ast.followsTransitive(7, 10));
    try std.testing.expect(ast.followsTransitive(10, 11));
    try std.testing.expect(ast.followsTransitive(11, 12));
    try std.testing.expect(!ast.followsTransitive(12, 13));

    try std.testing.expect(ast.followsTransitive(1, 10));
    try std.testing.expect(ast.followsTransitive(1, 11));
    try std.testing.expect(ast.followsTransitive(1, 12));

    try std.testing.expect(ast.followsTransitive(3, 10));
    try std.testing.expect(ast.followsTransitive(3, 11));
    try std.testing.expect(ast.followsTransitive(3, 12));

    try std.testing.expect(!ast.followsTransitive(8, 9));
    try std.testing.expect(ast.followsTransitive(4, 6));
    try std.testing.expect(!ast.followsTransitive(4, 8));
}


test "parent" {
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

    try std.testing.expect(!ast.parent(1, 2));
    try std.testing.expect(!ast.parent(2, 3));
    try std.testing.expect(ast.parent(3, 4));
    try std.testing.expect(ast.parent(3, 5));
    try std.testing.expect(ast.parent(3, 6));
    try std.testing.expect(!ast.parent(3, 7));
    try std.testing.expect(ast.parent(7, 8));
    try std.testing.expect(ast.parent(7, 9));
    try std.testing.expect(!ast.parent(7, 10));
    try std.testing.expect(!ast.parent(3, 12));
}


test "parent*" {
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

    try std.testing.expect(!ast.parentTransitive(1, 2));
    try std.testing.expect(!ast.parentTransitive(2, 3));
    try std.testing.expect(ast.parentTransitive(3, 4));
    try std.testing.expect(ast.parentTransitive(3, 5));
    try std.testing.expect(ast.parentTransitive(3, 12));
    
    try std.testing.expect(ast.parentTransitive(3, 6));
    try std.testing.expect(ast.parentTransitive(3, 7));
    try std.testing.expect(ast.parentTransitive(3, 8));
    try std.testing.expect(ast.parentTransitive(3, 9));
    try std.testing.expect(ast.parentTransitive(3, 10));
    try std.testing.expect(ast.parentTransitive(3, 11));
    
    try std.testing.expect(ast.parentTransitive(5, 10));
    try std.testing.expect(ast.parentTransitive(5, 11));
    
    try std.testing.expect(!ast.parentTransitive(5, 12));
}