const std = @import("std");

// imports template
const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const ASTParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()));
const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));
const Pkb = @import("Pkb.zig");
const common = @import("spa_api_common.zig");

const api = struct {
    usingnamespace @import("follows_api.zig").FollowsApi(u32);
    usingnamespace @import("parent_api.zig").ParentApi(u32);
};


comptime {
    _ = @import("tokenizer_tests.zig");
    _ = @import("ast_parser_tests.zig");
    _ = @import("ast_tests.zig");
}

fn getPkb(simple_src: []const u8) !*Pkb {
    var tokenizer = try Tokenizer.init(std.heap.page_allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple_src);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.heap.page_allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());
    defer parser.deinit();

    return try Pkb.init(try parser.parse(), std.heap.page_allocator);
}

fn checkExecute(
    pkb: *Pkb,
    func_ptr: *const fn(
        *Pkb, std.io.FixedBufferStream([]u8).Writer, 
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
        try func_ptr(pkb,
            stream.writer(), 
            s1_type, s1, s1_value,
            s2_type, s2, s2_value,
        )
    );
    stream.reset();
}

fn checkResult(pkb: *Pkb, buffer: *const [4]u8, expected: u32, convert: bool) !void {
    if (convert) {
        try std.testing.expectEqual(expected, pkb.ast.nodes[std.mem.readInt(u32, buffer, .little)].metadata.statement_id);
    } else {
        try std.testing.expectEqual(expected, std.mem.readInt(u32, buffer, .little));
    }
}
//
pub fn main() !void {
    const simple = 
    \\procedure Main {
    \\  call Init;
    \\  width = 1;
    \\  height = 0;
    \\  tmp = 0;
    \\  call Random;
    \\  while I {
    \\    x1 = width + incre + left;
    \\    x2 = x1 + incre + right;
    \\    y1 = height + incre * top;
    \\    y2 = y1 + incre * bottom;
    \\    area = width * height;
    \\  }
    \\}
    \\procedure Init {
    \\  x = 0;
    \\}
    \\procedure Random {
    \\  x = 0;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try std.testing.expect(std.mem.eql(u8, pkb.ast.var_table.getByIndex(0).?, "width"));
    try std.testing.expect(std.mem.eql(u8, pkb.ast.var_table.getByIndex(1).?, "height"));

    try checkExecute(pkb, api.parent, &result_buffer_stream, .NONE, 6, null, .NONE, 7, null, 1);
}
