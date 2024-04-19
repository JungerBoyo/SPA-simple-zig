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
    func_ptr: *const fn(
        self: *AST, std.io.FixedBufferStream([]u8).Writer, 
        NodeType, u32, ?[]const u8,
        NodeType, u32, ?[]const u8,
    ) anyerror!u32,
    stream: *std.io.FixedBufferStream([]u8),
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
    expected: u32,
) !void {
    try std.testing.expectEqual(
        expected, 
        try func_ptr(ast,
            stream.writer(), 
            s1_type, s1, s1_value,
            s2_type, s2, s2_value,
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

    try checkExecute(ast, AST.follows, &result_buffer_stream, .NONE, 1, null, .NONE, 2, null, 1);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, 2, "i", .NONE, AST.STATEMENT_SELECTED, null, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.follows, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .IF, 7, null, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, null, .IF, 7, null, 0);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, null, .IF, AST.STATEMENT_UNDEFINED, null, 0);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, null, .WHILE, AST.STATEMENT_UNDEFINED, null, 1);
    try checkResult(ast, result_buffer[0..4], 2, true);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, "i", .WHILE, AST.STATEMENT_UNDEFINED, null, 1);
    try checkResult(ast, result_buffer[0..4], 2, true);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, "x", .WHILE, AST.STATEMENT_UNDEFINED, null, 0);
    
    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, null, .ASSIGN, AST.STATEMENT_SELECTED, "x",  1);
    try checkResult(ast, result_buffer[0..4], 12, true);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, null, .ASSIGN, AST.STATEMENT_SELECTED, null,  3);
    try checkResult(ast, result_buffer[0..4], 2, true);
    try checkResult(ast, result_buffer[4..8], 11, true);
    try checkResult(ast, result_buffer[8..12], 12, true);

    try checkExecute(ast, AST.follows, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, null, .ASSIGN, AST.STATEMENT_SELECTED, "x",  1);
    try checkResult(ast, result_buffer[0..4], 12, true);

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
   \\  z = z + 2;
   \\  x = x * y + z;
   \\}
   ;

   var ast = try getAST(simple[0..]);
   defer ast.deinit();

   var result_buffer: [1024]u8 = .{0} ** 1024;
   var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .NONE, 1, null, .NONE, 2, null, 1);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, 2, null, .NONE, AST.STATEMENT_SELECTED, null, 5);
   try checkResult(ast, result_buffer[0..4], 3, true);
   try checkResult(ast, result_buffer[4..8], 7, true);
   try checkResult(ast, result_buffer[8..12], 10, true);
   try checkResult(ast, result_buffer[12..16], 11, true);
   try checkResult(ast, result_buffer[16..20], 12, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, 2, null, .ASSIGN, AST.STATEMENT_SELECTED, "z", 2);
   try checkResult(ast, result_buffer[0..4], 10, true);
   try checkResult(ast, result_buffer[4..8], 11, true);
   
   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .IF, 7, null, 1);
   try checkResult(ast, result_buffer[0..4], 3, true);
   
   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, null, .IF, 7, null, 2);
   try checkResult(ast, result_buffer[0..4], 2, true);
   try checkResult(ast, result_buffer[4..8], 1, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, "i", .IF, 7, null, 1);
   try checkResult(ast, result_buffer[0..4], 2, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, null, .IF, AST.STATEMENT_UNDEFINED, null, 2);
   try checkResult(ast, result_buffer[0..4], 1, true);
   try checkResult(ast, result_buffer[4..8], 2, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, "x", .IF, AST.STATEMENT_UNDEFINED, null, 1);
   try checkResult(ast, result_buffer[0..4], 1, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_SELECTED, null, .WHILE, AST.STATEMENT_UNDEFINED, null, 2);
   try checkResult(ast, result_buffer[0..4], 1, true);
   try checkResult(ast, result_buffer[4..8], 2, true);
   
   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, null, .ASSIGN, AST.STATEMENT_SELECTED, null, 5);
   try checkResult(ast, result_buffer[0..4], 2, true);
   try checkResult(ast, result_buffer[4..8], 6, true);
   try checkResult(ast, result_buffer[8..12], 10, true);
   try checkResult(ast, result_buffer[12..16], 11, true);
   try checkResult(ast, result_buffer[16..20], 12, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, "x", .ASSIGN, AST.STATEMENT_SELECTED, null, 5);
   try checkResult(ast, result_buffer[0..4], 2, true);
   try checkResult(ast, result_buffer[4..8], 6, true);
   try checkResult(ast, result_buffer[8..12], 10, true);
   try checkResult(ast, result_buffer[12..16], 11, true);
   try checkResult(ast, result_buffer[16..20], 12, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, "x", .ASSIGN, AST.STATEMENT_SELECTED, null, 5);
   try checkResult(ast, result_buffer[0..4], 2, true);
   try checkResult(ast, result_buffer[4..8], 6, true);
   try checkResult(ast, result_buffer[8..12], 10, true);
   try checkResult(ast, result_buffer[12..16], 11, true);
   try checkResult(ast, result_buffer[16..20], 12, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, "i", .ASSIGN, AST.STATEMENT_SELECTED, null, 3);
   try checkResult(ast, result_buffer[0..4], 10, true);
   try checkResult(ast, result_buffer[4..8], 11, true);
   try checkResult(ast, result_buffer[8..12], 12, true);

   try checkExecute(ast, AST.followsTransitive, &result_buffer_stream, .ASSIGN, AST.STATEMENT_UNDEFINED, "i", .ASSIGN, AST.STATEMENT_SELECTED, "z", 2);
   try checkResult(ast, result_buffer[0..4], 10, true);
   try checkResult(ast, result_buffer[4..8], 11, true);
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
    
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, 4, null, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, AST.STATEMENT_SELECTED, "i", 2);
    try checkResult(ast, result_buffer[0..4], 6, true);
    try checkResult(ast, result_buffer[4..8], 7, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 3, null, .NONE, 4, null, 0);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, 4, null, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, null, .ASSIGN, 4, null, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, null, .CALL, 5, null, 1);
    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, 3, null, .WHILE, 4, null, 0);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .CALL, 5, null, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .CALL, AST.STATEMENT_UNDEFINED, "Third", 1);
    try checkResult(ast, result_buffer[0..4], 3, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .ASSIGN, AST.STATEMENT_UNDEFINED, "i", 1);
    try checkResult(ast, result_buffer[0..4], 3, true);
    
    try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, AST.STATEMENT_SELECTED, null, 2);
    try checkResult(ast, result_buffer[0..4], 9, true);
    try checkResult(ast, result_buffer[4..8], 10, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, AST.STATEMENT_SELECTED, "z", 1);
    try checkResult(ast, result_buffer[0..4], 10, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, AST.STATEMENT_SELECTED, "p", 0);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .ASSIGN, AST.STATEMENT_UNDEFINED, "i", 1);
    try checkResult(ast, result_buffer[0..4], 3, true);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_SELECTED, null, .ASSIGN, AST.STATEMENT_UNDEFINED, "m", 0);

    try checkExecute(ast, AST.parent, &result_buffer_stream, .WHILE, AST.STATEMENT_UNDEFINED, null, .NONE, AST.STATEMENT_SELECTED, null, 4);
    try checkResult(ast, result_buffer[0..4], 4, true);
    try checkResult(ast, result_buffer[4..8], 5, true);
    try checkResult(ast, result_buffer[8..12], 6, true);
    try checkResult(ast, result_buffer[12..16], 7, true);
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

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);
    
    try checkExecute(ast, AST.parentTransitive, &result_buffer_stream, .IF, 3, null, .NONE, 6, null, 1);
    try checkExecute(ast, AST.parentTransitive, &result_buffer_stream, .IF, 3, null, .ASSIGN, 6, null, 1);
    //try checkExecute(ast, AST.parent, &result_buffer_stream, .IF, 3, null, .ASSIGN, 6, null, 1);
}
