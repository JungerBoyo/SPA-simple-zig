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
    usingnamespace @import("calls_api.zig").CallsApi(u32);
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

fn checkExecuteFollowsParent(
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
fn checkExecuteUsesModifies(
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
fn checkExecuteCalls(
    pkb: *Pkb,
    func_ptr: *const fn(pkb: *Pkb,
        result_writer: std.io.FixedBufferStream([]u8).Writer,
        p1: RefQueryArg, p2: RefQueryArg
    ) anyerror!u32,
    stream: *std.io.FixedBufferStream([]u8),
    p1: RefQueryArg, p2: RefQueryArg,
    expected: u32,
) !void {
    try std.testing.expectEqual(
        expected, 
        try func_ptr(pkb, stream.writer(), p1, p2)
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

test "follows extra" {
    const simple =
    \\procedure Main {
    \\ call Init;
    \\ width = 1;
    \\ height = 0;
    \\ tmp = 0;
    \\ call Random;
    \\ while I {
    \\  x1 = width + incre + left;
    \\ }
    \\}
    \\procedure Random {
    \\ x = 1;
    \\}
    \\procedure Init {
    \\ b = 1;
    \\}
    ;
    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, 1, null, .ASSIGN, 2, null, 0);
    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, 2, null, .ASSIGN, 4, null, 0);
    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, 4, null, .ASSIGN, 2, null, 0);
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

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .NONE, 1, null, .NONE, 2, null, 1);
    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, 5, null, .ASSIGN, 6, null, 0);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, 2, "i", .NONE, common.STATEMENT_SELECTED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .IF, 7, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, 7, null, 0);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, common.STATEMENT_UNDEFINED, null, 0);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 2, true);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "i", .WHILE, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 2, true);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "x", .WHILE, common.STATEMENT_UNDEFINED, null, 0);
    
    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, "x",  1);
    try checkResult(pkb, result_buffer[0..4], 12, true);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, null,  3);
    try checkResult(pkb, result_buffer[0..4], 2, true);
    try checkResult(pkb, result_buffer[4..8], 11, true);
    try checkResult(pkb, result_buffer[8..12], 12, true);

    try checkExecuteFollowsParent(pkb, api.follows, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, "x",  1);
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

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .NONE, 1, null, .NONE, 2, null, 1);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, 2, null, .NONE, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 3, true);
   try checkResult(pkb, result_buffer[4..8], 7, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, 2, null, .ASSIGN, common.STATEMENT_SELECTED, "z", 2);
   try checkResult(pkb, result_buffer[0..4], 10, true);
   try checkResult(pkb, result_buffer[4..8], 11, true);
   
   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .IF, 7, null, 1);
   try checkResult(pkb, result_buffer[0..4], 3, true);
   
   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, 7, null, 2);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 1, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "i", .IF, 7, null, 1);
   try checkResult(pkb, result_buffer[0..4], 2, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .IF, common.STATEMENT_UNDEFINED, null, 2);
   try checkResult(pkb, result_buffer[0..4], 1, true);
   try checkResult(pkb, result_buffer[4..8], 2, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, "x", .IF, common.STATEMENT_UNDEFINED, null, 1);
   try checkResult(pkb, result_buffer[0..4], 1, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 2);
   try checkResult(pkb, result_buffer[0..4], 1, true);
   try checkResult(pkb, result_buffer[4..8], 2, true);
   
   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 6, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "x", .ASSIGN, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 6, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "x", .ASSIGN, common.STATEMENT_SELECTED, null, 5);
   try checkResult(pkb, result_buffer[0..4], 2, true);
   try checkResult(pkb, result_buffer[4..8], 6, true);
   try checkResult(pkb, result_buffer[8..12], 10, true);
   try checkResult(pkb, result_buffer[12..16], 11, true);
   try checkResult(pkb, result_buffer[16..20], 12, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "i", .ASSIGN, common.STATEMENT_SELECTED, null, 3);
   try checkResult(pkb, result_buffer[0..4], 10, true);
   try checkResult(pkb, result_buffer[4..8], 11, true);
   try checkResult(pkb, result_buffer[8..12], 12, true);

   try checkExecuteFollowsParent(pkb, api.followsTransitive, &result_buffer_stream, .ASSIGN, common.STATEMENT_UNDEFINED, "i", .ASSIGN, common.STATEMENT_SELECTED, "z", 2);
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
    
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, 4, null, 1);
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, common.STATEMENT_SELECTED, "i", 2);
    try checkResult(pkb, result_buffer[0..4], 6, true);
    try checkResult(pkb, result_buffer[4..8], 7, true);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .IF, 3, null, .NONE, 4, null, 0);
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .NONE, 4, null, 1);
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .ASSIGN, 4, null, 1);
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .CALL, 5, null, 1);
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, 3, null, .WHILE, 4, null, 0);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .CALL, 5, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .CALL, common.STATEMENT_UNDEFINED, "Third", 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, common.STATEMENT_SELECTED, null, 2);
    try checkResult(pkb, result_buffer[0..4], 9, true);
    try checkResult(pkb, result_buffer[4..8], 10, true);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, common.STATEMENT_SELECTED, "z", 1);
    try checkResult(pkb, result_buffer[0..4], 10, true);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .IF, 8, null, .ASSIGN, common.STATEMENT_SELECTED, "p", 0);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "m", 0);

    try checkExecuteFollowsParent(pkb, api.parent, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .NONE, common.STATEMENT_SELECTED, null, 4);
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
    
    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .NONE, 3, null, .NONE, 6, null, 1);
    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .ASSIGN, 6, null, 1);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .NONE, 6, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);
    
    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .NONE, 10, null, 2);
    try checkResult(pkb, result_buffer[0..4], 9, true);
    try checkResult(pkb, result_buffer[4..8], 3, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .NONE, 6, null, 1);
    try checkResult(pkb, result_buffer[0..4], 5, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .NONE, common.STATEMENT_SELECTED, null, 9);
    try checkResult(pkb, result_buffer[0..4], 4, true);
    try checkResult(pkb, result_buffer[4..8], 5, true);
    try checkResult(pkb, result_buffer[8..12], 6, true);
    try checkResult(pkb, result_buffer[12..16], 7, true);
    try checkResult(pkb, result_buffer[16..20], 8, true);
    try checkResult(pkb, result_buffer[20..24], 9, true);
    try checkResult(pkb, result_buffer[24..28], 10, true);
    try checkResult(pkb, result_buffer[28..32], 11, true);
    try checkResult(pkb, result_buffer[32..36], 12, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, 3, null, .ASSIGN, common.STATEMENT_SELECTED, "i", 2);
    try checkResult(pkb, result_buffer[0..4], 8, true);
    try checkResult(pkb, result_buffer[4..8], 10, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .ASSIGN, common.STATEMENT_UNDEFINED, "y", 2);
    try checkResult(pkb, result_buffer[0..4], 9, true);
    try checkResult(pkb, result_buffer[4..8], 3, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .CALL, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 5, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .IF, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 3, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_SELECTED, null, .WHILE, common.STATEMENT_UNDEFINED, null, 0);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .WHILE, common.STATEMENT_SELECTED, null, 0);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .IF, common.STATEMENT_SELECTED, null, 1);
    try checkResult(pkb, result_buffer[0..4], 9, true);

    try checkExecuteFollowsParent(pkb, api.parentTransitive, &result_buffer_stream, .WHILE, common.STATEMENT_UNDEFINED, null, .ASSIGN, common.STATEMENT_SELECTED, "i", 2);
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
    
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "x", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "z", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Second" }, "j", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "j", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "x", 0);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "y", 0);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "i", 0);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .proc_name = "Third" }, "z", 0);


    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(1)) }, "x", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "x", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "y", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(9)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.modifies, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(9)) }, "y", 1);
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
    
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "b", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "m", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "n", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "h", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "t", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "x", 0);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Second" }, "k", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);


    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "k", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "j", 0);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "y", 0);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "i", 0);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "z", 0);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .proc_name = "Third" }, "m", 0);


    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(4)) }, "b", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "b", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "m", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(3)) }, "x", 0);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "i", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(5)) }, "n", 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(9)) }, "y", 0);
}

test "calls" {
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
    \\    call First;
    \\}
    \\procedure First {
    \\    call Fourth;
    \\}
    \\procedure Fourth {
    \\  j = 1 + k;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecuteCalls(pkb, api.calls, &result_buffer_stream, .{ .proc_name = "Second" }, .{ .proc_name = "Third" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteCalls(pkb, api.calls, &result_buffer_stream, .{ .proc_name = "Second" }, .{ .proc_name = "First" }, 0);
    try checkExecuteCalls(pkb, api.calls, &result_buffer_stream, .{ .proc_name = "Second" }, .{ .proc_name = "Fourth" }, 0);

    try checkExecuteCalls(pkb, api.calls, &result_buffer_stream, .{ .proc_name = "Third" }, .{ .proc_name = "First" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteCalls(pkb, api.calls, &result_buffer_stream, .{ .proc_name = "Third" }, .{ .proc_name = "Fourth" }, 0);

    try checkExecuteCalls(pkb, api.calls, &result_buffer_stream, .{ .proc_name = "First" }, .{ .proc_name = "Fourth" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
}

test "calls*" {
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
    \\    call First;
    \\}
    \\procedure First {
    \\    call Fourth;
    \\}
    \\procedure Fourth {
    \\  j = 1 + k;
    \\}
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecuteCalls(pkb, api.callsTransitive, &result_buffer_stream, .{ .proc_name = "Second" }, .{ .proc_name = "Third" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteCalls(pkb, api.callsTransitive, &result_buffer_stream, .{ .proc_name = "Second" }, .{ .proc_name = "First" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteCalls(pkb, api.callsTransitive, &result_buffer_stream, .{ .proc_name = "Second" }, .{ .proc_name = "Fourth" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);

    try checkExecuteCalls(pkb, api.callsTransitive, &result_buffer_stream, .{ .proc_name = "Third" }, .{ .proc_name = "First" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
    try checkExecuteCalls(pkb, api.callsTransitive, &result_buffer_stream, .{ .proc_name = "Third" }, .{ .proc_name = "Fourth" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);

    try checkExecuteCalls(pkb, api.callsTransitive, &result_buffer_stream, .{ .proc_name = "First" }, .{ .proc_name = "Fourth" }, 1);
    try checkResult(pkb, result_buffer[0..4], 1, false);
}


test "custom" {
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
    \\    while j {
    \\      difference = I + j - 10;
    \\      if j then {
    \\        if k then {
    \\          while difference {
    \\            tmp = decrement * area;
    \\            call Enlarge;
    \\            radius = x1 * 3 + difference;
    \\            difference = difference - 1;
    \\            x2 = j + k - I;
    \\            call Shrink;
    \\            if tmp then {
    \\              y1 = 0;
    \\              y2 = 0; }
    \\            else {
    \\              while y1 {
    \\                y1 = y1 - 1;
    \\                y2 = tmp - 1; } }
    \\            while area {
    \\              width = x1 * x2 + incre * left;
    \\              height = right - y1 - incre * y2;
    \\              area = width * height;
    \\              call Transform; }
    \\            if area then {
    \\              radius = difference + 3 - (2 * incre);
    \\              x3 = radius + x1;
    \\              difference = x4 + x1 - incre; }
    \\            else {
    \\              if I then {
    \\                I = I - 1;
    \\                volume = height * 1 - (3 * width);
    \\                call Shear;
    \\                call Move; }
    \\              else {
    \\                distance = length + x1; 
    \\                call Random; } }
    \\            call Shift;
    \\            length = height * x2 - x1;
    \\            while length {
    \\              tmp = tmp - 1;
    \\              width = x2 + x1 - left;
    \\              length = y2 - y1 + tmp;
    \\              if length then {
    \\                length = length * 0; }
    \\              else {
    \\                length = 0; } }
    \\            call Random;
    \\            if volume then {
    \\              volume = x4 + x3 - x5;
    \\              x5 = 16 * (tmp + 83); }
    \\            else {
    \\              x8 = volume * 11 + volume - x9 + volume; }
    \\            while top {
    \\              tmp = 0;
    \\              height = tmp - k + I + y2;
    \\              call Enlarge; } }
    \\          call Move;
    \\          x5 = x1 + y2 - 3;
    \\          incre = I + k - decrement;
    \\          if x6 then {
    \\            x1 = top + bottom - difference;
    \\            x6 = x5 + 32;
    \\            while I {
    \\              I = I - 1;
    \\              x6 = x2 + x1 - x3 * I;
    \\              if j then {
    \\                j = j - 1; }
    \\              else {
    \\                x2 = x1 + radius - tmp; }
    \\              I = I - 1; } }
    \\          else {
    \\            if k then {
    \\              top = width - I - j; }
    \\            else {
    \\              call Transform; } } }
    \\        else {
    \\          while difference {
    \\            if incre then {
    \\              tmp = 0;
    \\              width = x2 - x1;
    \\              while width {
    \\                call Shrink;
    \\                width = width - 2 + x1;
    \\                if height then {
    \\                  call Draw; }
    \\                else {
    \\                  height = 0; } } }
    \\            else {
    \\              while top {
    \\                tmp = 0;
    \\                height = tmp - k + I + y2;
    \\                call Enlarge; } } } } }
    \\      else {
    \\        x7 = x8 + y1 - incre;
    \\        y7 = 0; }
    \\      while area {
    \\        tmp = 1;
    \\        if tmp then {
    \\          I = 0; }
    \\        else {
    \\          j = 0; }
    \\        j = 0; }
    \\      while radius {
    \\        circumference = 1 * radius + tmp;
    \\        while tmp {
    \\          circumference = I - (k + j * decrement); } }
    \\      while x {
    \\        x = x + 1;
    \\        if left then {
    \\          call Transform;
    \\          if right then {
    \\            incre = incre - 1;
    \\            b = 0;
    \\            c = area + length * width + incre; }
    \\          else {
    \\            while c {
    \\              call Shift;
    \\              c = c - 1; } 
    \\            x = x + 1; } }
    \\        else {
    \\          call Translate; } } }
    \\  call Draw; }
    \\  call Init; }

    \\procedure Init {
    \\  x1 = 0;
    \\  x2 = 0;
    \\  y1 = 0;
    \\  y2 = 0;
    \\  left = 1;
    \\  right = 1;
    \\  top = 1;
    \\  bottom = 1;
    \\  incre = 10;
    \\  decrement = 5; }

    \\procedure Random {
    \\  left = incre * bottom;
    \\  right = decrement * top; }

    \\procedure Transform {
    \\  weight = 1;
    \\  tmp = 100;
    \\  incre = incre * weight;
    \\  decrement = top - bottom + (right - left) * weight;
    \\  while tmp {
    \\    tmp = incre + height * weight;
    \\    x1 = x2 + tmp;
    \\    x2 = tmp * weight - tmp;
    \\    if x2 then {
    \\      weight = y2 - y1; }
    \\    else {
    \\      weight = x2 - x1; }
    \\    while tmp {
    \\      if weight then {
    \\        y2 = y2 + incre;
    \\        y1 = y1 - decrement; }
    \\      else {
    \\        y1 = x2 * tmp;
    \\        y2 = x1 * (height - bottom); } }
    \\    tmp = 0; } }

    \\procedure Shift {
    \\  top = x2 - x1 * incre;
    \\  bottom = y2 * y1 - decrement;
    \\  x3 = x1 + x2 * y1 + y2 * left + right;
    \\  x4 = x1 * x2 + y1 * y2 + left - right;
    \\  x5 = x1 + x2 + y1 + y2 * (left - right);
    \\  x6 = x1 * x2 * y1 - y2 + left * right;
    \\  x7 = x1 * x2 * y1 * y2 * left * right;
    \\  x8 = (x1 + x2 * y1) * (y2 * left - right);
    \\  x9 = x1 + x2 * y1 * y2 * left - right; }

    \\procedure Shear {
    \\  if x1 then {
    \\    if x2 then {
    \\      y1 = y2 + incre;
    \\      incre = x2 - x1;
    \\      if y1 then {
    \\        x1 = 0; }
    \\      else {
    \\        x1 = decrement + x1; }
    \\      if y2 then {
    \\        x2 = incre * 2; }
    \\      else {
    \\        x2 = y2 - y1; }
    \\      decrement = (x1 + x2) * (y1 + y2);
    \\      if decrement then {
    \\        factor = 0; }
    \\      else {
    \\        factor = 1; }
    \\      if factor then {
    \\        x1 = 0; }
    \\      else {
    \\        x2 = 0; } }
    \\    else {
    \\      if y1 then {
    \\        y1 = 0; }
    \\      else {
    \\        y1 = y1 - factor; } } }
    \\  else {
    \\    y2 = 0; } }

    \\procedure Move {
    \\  while tmp {
    \\    while factor {
    \\      x1 = x2 + incre * factor;
    \\      factor = factor - 1;
    \\      while I {
    \\        I = x1 + decrement; }
    \\      x2 = tmp * factor - (height * width);
    \\      while I {
    \\        tmp = factor;
    \\        factor = 0; } } } }

    \\procedure Draw {
    \\  call Clear;
    \\  while pct {
    \\    if mtoggle then {
    \\      dx = lengx + 1 - cover * pct;
    \\      dy = dx * marking - median; }
    \\    else {
    \\      call Random; }
    \\    while asterick {
    \\      range = dx - dy + range;
    \\      if range then {
    \\        peak = marking - y2 * mean;
    \\        marking = marking - 1; }
    \\      else {
    \\        pct = 0;
    \\        trim = 0; }
    \\      range = range + 1; }
    \\      if pct then {
    \\        pct = 0; }
    \\      else {
    \\        asterick = x1 * x1 + y1 * x2; }
    \\    pct = pct - 1; }
    \\  call Show; }

    \\procedure Clear {
    \\  while s {
    \\    p1 = 0;
    \\    p2 = 0;
    \\    s = s - 1; } }

    \\procedure Show {
    \\  pink= difference;
    \\  green = pink+ 1;
    \\  blue = green + pink; }

    \\procedure Enlarge {
    \\  if pixel then {
    \\    while dot {
    \\      while notmove {
    \\        line = edge + depth;
    \\        semi = edge + increase - temporary + depth;
    \\        call Fill;
    \\        call Fill;
    \\        edge = dot + 1 - decrease * temporary;
    \\        if edge then {
    \\          edge = 1 + (8 - temporary); }
    \\        else {
    \\          temporary = edge; }
    \\        call Show;
    \\        semi = temporary + edge;
    \\        depth = semi * pixel + 1 - 3 * temporary;
    \\        if notmove then {
    \\          call Fill; }
    \\        else {
    \\          call Fill; }
    \\        notmove = semi * half; }
    \\      while dot {
    \\        call Fill; }
    \\      pixel = temporary * temporary; } }
    \\  else {
    \\    if pixel then {
    \\      total = pixel * 1000; }
    \\    else {
    \\      while notdone {
    \\        total = pixel + notdone; } } } }

    \\procedure Fill {
    \\  if temporary then {
    \\    depth = depth + 1; }
    \\  else {
    \\    semi = depth - 1; } }

    \\procedure Shrink {
    \\  factor = incre - decrement;
    \\  x1 = x1 - 10;
    \\  x2 = x2 - 10;
    \\  y1 = y1 - (10 * factor);
    \\  y2 = y2 - (20 * factor);
    \\  factor = y2 - y1 + x2 - x1;
    \\  if factor then {
    \\    while I {
    \\      x1 = x1 - I;
    \\      I = I - 1; }
    \\    x2 = I * x1 - factor; }
    \\  else {
    \\    y2 = j * factor + incre;
    \\    while j {
    \\      j = j - 1;
    \\      y1 = j * factor - decrement; } }
    \\  call Draw;
    \\  factor = factor * 0; }

    \\procedure Translate {
    \\  factor = 0;
    \\  call Rotate; }

    \\procedure Rotate {
    \\  triangle = half * base * height;
    \\  while edge {
    \\    while line {
    \\      if edge then {
    \\        if pixel then {
    \\          semi = temporary - depth + triangle; }
    \\        else {
    \\          dot = dot + degrees; }
    \\        dx = dx + dy - triangle;
    \\        base = dx - dy + dx - dy;
    \\        height = base * dx * dy;
    \\        edge = height + line * 2; }
    \\      else {
    \\        call Random; }
    \\      dx = edge + triangle;
    \\      triangle = triange + edge + dx; }
    \\    call Show; } }

    \\procedure Scale {
    \\  if wrong then {
    \\    while wcounter {
    \\      location = unknown - wcounter; } }
    \\  else {
    \\    while wcounter {
    \\      location = correct - wcounter; } } }

    \\procedure PP {
    \\  cs1 = 1;
    \\  cs2 = 2;
    \\  cs3 = 3;
    \\  call QQ;
    \\  call TT; }

    \\procedure QQ {
    \\  cs1 = cs2 * cs3; }

    \\procedure RR {
    \\  while cs4 {
    \\    cs5 = 0;
    \\    if cs1 then {
    \\      call QQ; }
    \\    else {
    \\      call PP; } } }

    \\procedure SS {
    \\  call XX; }

    \\procedure TT {
    \\  call QQ;
    \\  call UU;
    \\  call SS; }

    \\procedure UU {
    \\  cs5 = 2;
    \\  cs6 = 3;
    \\  cs9 = 5;
    \\  while cs9 {
    \\    cs5 = cs5 - 1;
    \\    if cs5 then {
    \\      cs6 = cs5 + 1; }
    \\    else {
    \\      cs8 = cs6 + cs5; }
    \\    cs6 = cs6 + (cs5 + cs9);
    \\    call XX;
    \\    cs9 = cs6 - 1; } }

    \\procedure XX {
    \\  if cs5 then {
    \\    cs6 = cs5 + 1; }
    \\  else {
    \\    cs5 = cs6 + cs5; } }
    ;

    var pkb = try getPkb(simple[0..]);
    defer pkb.deinit();

    var result_buffer: [2048]u8 = .{0} ** 2048;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(107)) }, "x", 1);
    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(34)) }, "y2", 1);
    // try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = 414 }, "y2", 1);


    // try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = common.NODE_SELECTED }, null, 275);

    //var result: [4]u8 = .{0} ** 4;
    //for (0..275) |i| {
    //    std.mem.copyForwards(u8, result[0..], result_buffer[i*4..(i+1)*4]);
    //    const num = std.mem.readInt(u32, &result, .little);
    //    if (pkb.ast.nodes[num].type == .IF) {
    //        std.debug.print("{}\n", .{ pkb.ast.nodes[num].metadata.statement_id } );
    //    }
    //}
    
}
