const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));
const AstParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()));
const AST = @import("Ast.zig");
const Pkb = @import("Pkb.zig");
const common = @import("spa_api_common.zig");

const RefQueryArg = common.RefQueryArg;

const api = struct {
    usingnamespace @import("follows_api.zig").FollowsApi(u32);
    usingnamespace @import("parent_api.zig").ParentApi(u32);
    usingnamespace @import("uses_modifies_api.zig").UsesModifiesApi(u32);
};

fn getPkb(simple_src: []const u8) !*Pkb {
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple_src);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try AstParser.init(std.testing.allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());
    defer parser.deinit();

    return try Pkb.init(try parser.parse(), std.testing.allocator);
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
fn checkExecute2(
    pkb: *Pkb,
    func_ptr: *const fn(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
        ref_query_arg: RefQueryArg, var_name: ?[]const u8,
    ) anyerror!u32,
    stream: *std.io.FixedBufferStream([]u8),
    ref_query_arg: RefQueryArg, var_name: ?[]const u8,
    expected: u32,
) !void {
    try std.testing.expectEqual(
        expected, 
        try func_ptr(pkb,
            stream.writer(), 
            ref_query_arg, var_name
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
    \\procedure Third {
    \\  j = 1;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .NONE, 1, null, .NONE, 2, null, 1);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, 2, "i", .NONE, common.STATEMENT_SELECTED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecute(pkb, api.follows, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .IF, 7, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, 7, null, 0);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, common.STATEMENT_UNDEFINED, null, 0);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 2, true);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "i", .WHILE, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 2, true);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "x", .WHILE, common.STATEMENT_UNDEFINED, null, 0);
    
    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, "x",  1);
    try checkResult(pkb, result_buffer[0..4], 12, true);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, null,  3);
    try checkResult(pkb, result_buffer[0..4], 2, true);
    try checkResult(pkb, result_buffer[4..8], 11, true);
    try checkResult(pkb, result_buffer[8..12], 12, true);

    try checkExecute(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, "x",  1);
    try checkResult(pkb, result_buffer[0..4], 12, true);

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
   \\procedure Third {
   \\  j = 1;
   \\}
   ;

   var pkb = try getPkb(simple[0..]);
   defer pkb.deinit();

   var result_buffer: [1024]u8 = .{0} ** 1024;
   var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .NONE, 1, null, .NONE, 2, null, 1);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, 2, null, .NONE, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 3, true);
   try checkResult(pkb, result_buffer[4..8], 7, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, 2, null, .ASSIGN, common.STATEMENT_SELECTED, "z", 2);
   try checkResult(pkb, result_buffer[0..4], 10, true);
   try checkResult(pkb, result_buffer[4..8], 11, true);
   
   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .IF, 7, null, 1);
   try checkResult(pkb, result_buffer[0..4], 3, true);
   
   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, 7, null, 2);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 1, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "i", .IF, 7, null, 1);
   try checkResult(pkb, result_buffer[0..4], 2, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, common.STATEMENT_UNDEFINED, null, 2);
   try checkResult(pkb, result_buffer[0..4], 1, true);
   try checkResult(pkb, result_buffer[4..8], 2, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "x", .IF, common.STATEMENT_UNDEFINED, null, 1);
   try checkResult(pkb, result_buffer[0..4], 1, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 2);
   try checkResult(pkb, result_buffer[0..4], 1, true);
   try checkResult(pkb, result_buffer[4..8], 2, true);
   
   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 6, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "x", .ASSIGN, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 6, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "x", .ASSIGN, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 6, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "i", .ASSIGN, common.STATEMENT_SELECTED, null, 3);
   try checkResult(pkb, result_buffer[0..4], 10, true);
   try checkResult(pkb, result_buffer[4..8], 11, true);
   try checkResult(pkb, result_buffer[8..12], 12, true);

   try checkExecute(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "i", .ASSIGN, common.STATEMENT_SELECTED, "z", 2);
   try checkResult(pkb, result_buffer[0..4], 10, true);
   try checkResult(pkb, result_buffer[4..8], 11, true);
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
    \\procedure Third {
    \\  j = 1;
    \\}
    ;
    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);
    
    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, 4, null, 1);
    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, common.STATEMENT_SELECTED, "i", 2);
    try checkResult(pkb, result_buffer[0..4], 6, true);
    try checkResult(pkb, result_buffer[4..8], 7, true);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .IF, 3, null, .NONE, 4, null, 0);
    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, 4, null, 1);
    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .ASSIGN, 4, null, 1);
    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .CALL, 5, null, 1);
    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .WHILE, 4, null, 0);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .CALL, 5, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .CALL, common.STATEMENT_UNDEFINED, "Third", 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecute(pkb, api.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, common.STATEMENT_SELECTED, null, 2);
    try checkResult(pkb, result_buffer[0..4], 9, true);
    try checkResult(pkb, result_buffer[4..8], 10, true);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, common.STATEMENT_SELECTED, "z", 1);
    try checkResult(pkb, result_buffer[0..4], 10, true);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, common.STATEMENT_SELECTED, "p", 0);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "m", 0);

    try checkExecute(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .NONE, common.STATEMENT_SELECTED, null, 4);
    try checkResult(pkb, result_buffer[0..4], 4, true);
    try checkResult(pkb, result_buffer[4..8], 5, true);
    try checkResult(pkb, result_buffer[8..12], 6, true);
    try checkResult(pkb, result_buffer[12..16], 7, true);
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
    \\          if c then { 
    \\              i = 1; 
    \\          } else {
    \\              y = 2;
    \\          }
    \\      }
    \\  } else {
    \\      z = 1;
    \\  }
    \\  z = z + x + i;
    \\  y = z + 2;
    \\  x = x * y + z;
    \\}
    \\procedure Third {
    \\  j = 1;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);
    
    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .NONE, 6, null, 1);
    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .ASSIGN, 6, null, 1);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .NONE, 6, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .NONE, 10, null, 2);
    try checkResult(pkb, result_buffer[0..4], 9, true);
    try checkResult(pkb, result_buffer[4..8], 3, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .NONE, 6, null, 1);
    try checkResult(pkb, result_buffer[0..4], 5, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .NONE, common.STATEMENT_SELECTED, null, 9);
    try checkResult(pkb, result_buffer[0..4], 4, true);
    try checkResult(pkb, result_buffer[4..8], 5, true);
    try checkResult(pkb, result_buffer[8..12], 6, true);
    try checkResult(pkb, result_buffer[12..16], 7, true);
    try checkResult(pkb, result_buffer[16..20], 8, true);
    try checkResult(pkb, result_buffer[20..24], 9, true);
    try checkResult(pkb, result_buffer[24..28], 10, true);
    try checkResult(pkb, result_buffer[28..32], 11, true);
    try checkResult(pkb, result_buffer[32..36], 12, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .ASSIGN, common.STATEMENT_SELECTED, "i", 2);
    try checkResult(pkb, result_buffer[0..4], 8, true);
    try checkResult(pkb, result_buffer[4..8], 10, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "y", 2);
    try checkResult(pkb, result_buffer[0..4], 9, true);
    try checkResult(pkb, result_buffer[4..8], 3, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .CALL, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 5, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 0);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .WHILE, common.STATEMENT_SELECTED, null, 0);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .IF, common.STATEMENT_SELECTED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 9, true);

    try checkExecute(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, "i", 2);
    try checkResult(pkb, result_buffer[0..4], 8, true);
    try checkResult(pkb, result_buffer[4..8], 10, true);
}


test "modifies" {
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
    \\          if c then { 
    \\              i = 1; 
    \\          } else {
    \\              y = 2;
    \\          }
    \\      }
    \\  } else {
    \\      z = 1;
    \\  }
    \\  z = z + x + i;
    \\  y = z + 2;
    \\  x = x * y + z;
    \\}
    \\procedure Third {
    \\  j = 1;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);
    
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "x", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "z", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "j", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "j", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "x", 0);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "y", 0);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "i", 0);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "z", 0);


    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(1)) }, "x", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "x", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(9)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(9)) }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
}


test "uses" {
    const simple = 
    \\procedure Second {
    \\  x = 0;
    \\  i = 5;
    \\  if s then {
    \\      x = 1 + b;
    \\      while i {
    \\          x = 2 * y + m;
    \\          call Third;
    \\          i = i - 1;
    \\          if c then { 
    \\              i = 1; 
    \\          } else {
    \\              y = 2 + n;
    \\          }
    \\      }
    \\  } else {
    \\      z = 1 + h;
    \\  }
    \\  z = z + i;
    \\  y = z + 2;
    \\  x = y + z + t;
    \\}
    \\procedure Third {
    \\  j = 1 + k;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);
    
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "b", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "m", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "n", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "h", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "t", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "x", 0);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "k", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);


    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "k", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "j", 0);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "y", 0);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "i", 0);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "z", 0);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "m", 0);


    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(4)) }, "b", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "b", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "m", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "x", 0);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "n", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecute2(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(9)) }, "y", 0);
}
