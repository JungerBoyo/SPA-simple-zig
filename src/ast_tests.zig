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

fn checkExecute(
    ast: *AST,
    func_ptr: *const fn(self: *AST, std.io.FixedBufferStream([]u8).Writer, NodeType, u32, NodeType, u32) anyerror!u32,
    stream: *std.io.FixedBufferStream([]u8),
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
    expected: u32,
) !void {
    try std.testing.expectEqual(
        expected, 
        try func_ptr(ast,
            stream.writer(), 
            s1_type, s1, s2_type, s2
        )
    );
    stream.reset();
}

fn checkResult(ast: *AST, buffer: *const [4]u8, expected: u32, convert: bool) !void {
    if (convert) {
        try std.testing.expectEqual(expected, ast.nodes[std.mem.readInt(u32, buffer, .Little)].metadata.statement_id);
    } else {
        try std.testing.expectEqual(expected, std.mem.readInt(u32, buffer, .Little));
    }
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

    try checkExecute(ast, AST.follows, &result_buffer_stream, .NONE, 1, .NONE, 2, 1);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, 2, .NONE, AST.STATEMENT_SELECTED, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.follows, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, .IF, 7, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, .IF, 7, 0);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, .IF, AST.STATEMENT_UNDEFINED, 0);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, .WHILE, AST.STATEMENT_UNDEFINED, 1);
    try checkResult(ast, result_buffer[0..4], 2, true);
    
    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, .ASSIGN, AST.STATEMENT_SELECTED, 3);
    try checkResult(ast, result_buffer[0..4], 2, true);
    try checkResult(ast, result_buffer[4..8], 11, true);
    try checkResult(ast, result_buffer[8..12], 12, true);
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

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .NONE, 1, .NONE, 2, 1);

    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, 2, .NONE, AST.STATEMENT_SELECTED, 5);
    try checkResult(ast, result_buffer[0..4], 3, true);
    try checkResult(ast, result_buffer[4..8], 7, true);
    try checkResult(ast, result_buffer[8..12], 10, true);
    try checkResult(ast, result_buffer[12..16], 11, true);
    try checkResult(ast, result_buffer[16..20], 12, true);
    
    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, .IF, 7, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, .IF, 7, 2);
    try checkResult(ast, result_buffer[0..4], 2, true);
    try checkResult(ast, result_buffer[4..8], 1, true);

    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, .IF, AST.STATEMENT_UNDEFINED, 2);
    try checkResult(ast, result_buffer[0..4], 1, true);
    try checkResult(ast, result_buffer[4..8], 2, true);

    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, .WHILE, AST.STATEMENT_UNDEFINED, 2);
    try checkResult(ast, result_buffer[0..4], 1, true);
    try checkResult(ast, result_buffer[4..8], 2, true);
    
    try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, .ASSIGN, AST.STATEMENT_SELECTED, 5);
    try checkResult(ast, result_buffer[0..4], 2, true);
    try checkResult(ast, result_buffer[4..8], 6, true);
    try checkResult(ast, result_buffer[8..12], 10, true);
    try checkResult(ast, result_buffer[12..16], 11, true);
    try checkResult(ast, result_buffer[16..20], 12, true);
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

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, .NONE, 4, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 3, .NONE, 4, 0);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, .NONE, 4, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, .ASSIGN, 4, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, .CALL, 5, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, .WHILE, 4, 0);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, .CALL, 5, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 7, .ASSIGN, AST.STATEMENT_SELECTED, 2);
    try checkResult(ast, result_buffer[0..4], 8, true);
    try checkResult(ast, result_buffer[4..8], 9, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, .ASSIGN, AST.STATEMENT_UNDEFINED, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_UNDEFINED, .NONE, AST.STATEMENT_SELECTED, 3);
    try checkResult(ast, result_buffer[0..4], 4, true);
    try checkResult(ast, result_buffer[4..8], 5, true);
    try checkResult(ast, result_buffer[8..12], 6, true);
}


//test "parent*" {
//    const simple = 
//    \\procedure Second {
//    \\  x = 0;
//    \\  i = 5;
//    \\  if x then {
//    \\      x = x + 1;
//    \\      while i {
//    \\          x = x + 2 * y;
//    \\          call Third;
//    \\          i = i - 1;
//    \\          if c then { i = 1; } else { i = 2; }
//    \\      }
//    \\  } else {
//    \\      z = 1;
//    \\  }
//    \\  z = z + x + i;
//    \\  y = z + 2;
//    \\  x = x * y + z;
//    \\}
//    ;
//
//    var ast = try getAST(simple[0..]);
//    defer ast.deinit();
//
//    try std.testing.expect(!ast.parentTransitive(1, 2));
//    try std.testing.expect(!ast.parentTransitive(2, 3));
//    try std.testing.expect(ast.parentTransitive(3, 4));
//    try std.testing.expect(ast.parentTransitive(3, 5));
//    try std.testing.expect(ast.parentTransitive(3, 12));
//    
//    try std.testing.expect(ast.parentTransitive(3, 6));
//    try std.testing.expect(ast.parentTransitive(3, 7));
//    try std.testing.expect(ast.parentTransitive(3, 8));
//    try std.testing.expect(ast.parentTransitive(3, 9));
//    try std.testing.expect(ast.parentTransitive(3, 10));
//    try std.testing.expect(ast.parentTransitive(3, 11));
//    
//    try std.testing.expect(ast.parentTransitive(5, 10));
//    try std.testing.expect(ast.parentTransitive(5, 11));
//    
//    try std.testing.expect(!ast.parentTransitive(5, 12));
//}
