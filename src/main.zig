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
//
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

   var result_buffer: [1024]u8 = .{0} ** 1024;
   var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecute(ast, AST.parentTransitive, &result_buffer_stream, .IF, AST.STATEMENT_SELECTED, null, .WHILE, AST.STATEMENT_UNDEFINED, null, 1);
    try checkResult(ast, result_buffer[0..4], 3, true);

}
