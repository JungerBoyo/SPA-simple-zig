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
const RefQueryArg = common.RefQueryArg;

const api = struct {
    usingnamespace @import("follows_api.zig").FollowsApi(u32);
    usingnamespace @import("parent_api.zig").ParentApi(u32);
    usingnamespace @import("uses_modifies_api.zig").UsesModifiesApi(u32);
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

    var result_buffer: [1024]u8 = .{0} ** 1024;
    var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

    try checkExecuteUsesModifies(pkb, api.uses, &result_buffer_stream, .{ .node_id = @intCast(pkb.ast.findStatement(87)) }, "y2", 1);
}
