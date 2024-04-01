const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));
const ASTParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()), u32);
const AST = ASTParser.AST;

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

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .NONE, 1, .NONE, 2));
    try std.testing.expect(1 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    result_buffer_stream.reset();

    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, 2, .NONE, AST.STATEMENT_SELECTED));
    try std.testing.expect(3 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    result_buffer_stream.reset();
    
    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .WHILE, AST.STATEMENT_SELECTED, .IF, 7));
    try std.testing.expect(3 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    result_buffer_stream.reset();
    
    try std.testing.expect(0 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_SELECTED, .IF, 7));
    try std.testing.expect(0 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_SELECTED, .IF, AST.STATEMENT_UNDEFINED));
    
    try std.testing.expect(1 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_SELECTED, .WHILE, AST.STATEMENT_UNDEFINED));
    try std.testing.expect(2 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    result_buffer_stream.reset();

    try std.testing.expect(3 == try ast.follows(result_buffer_stream.writer(), .ASSIGN, AST.STATEMENT_UNDEFINED, .ASSIGN, AST.STATEMENT_SELECTED));
    
    try std.testing.expect(2 == std.mem.readInt(u32, result_buffer[0..4], .Little));
    try std.testing.expect(11 == std.mem.readInt(u32, result_buffer[4..8], .Little));
    try std.testing.expect(12 == std.mem.readInt(u32, result_buffer[8..12], .Little));
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