const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const ERR_BUFFER_SIZE = 1024;
const RESULT_BUFFER_SIZE = 8192;

const ASTParser = @import("AstParser.zig").AstParser(std.io.FixedBufferStream([]u8).Writer, c_uint);
const Tokenizer = @import("Tokenizer.zig").Tokenizer(std.io.FixedBufferStream([]u8).Writer);
const AST = ASTParser.AST;

const allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

const SpaInstance = struct {
    ast: *AST
};

var error_buffer: [ERR_BUFFER_SIZE:0]u8 = .{0} ** ERR_BUFFER_SIZE;
var error_buffer_stream = std.io.fixedBufferStream(error_buffer[0..]);

var result_buffer: [RESULT_BUFFER_SIZE]u8 = .{0} ** RESULT_BUFFER_SIZE;
var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

var instance: ?SpaInstance = null;

fn makeInstance(simple_src_file_path: [*:0]const u8) Error!SpaInstance {
    if (instance) |value| {
        value.ast.deinit();
    }

    const file = std.fs.cwd().openFileZ(simple_src_file_path, .{ .mode = .read_only }) catch {
        error_buffer_stream.writer().print("Failed to open file at {s}.", .{simple_src_file_path}) catch unreachable;
        return Error.SIMPLE_FILE_OPEN_ERROR;
    };
    defer file.close();

    var tokenizer = try Tokenizer.init(std.heap.page_allocator, error_buffer_stream.writer());

    try tokenizer.tokenize(file.reader());
    defer tokenizer.deinit();

    var parser = try ASTParser.init(std.heap.page_allocator, tokenizer.tokens.items[0..], error_buffer_stream.writer());
    defer parser.deinit();

    var ast = try parser.parse();

    return .{ .ast = ast };
}

pub export fn Init(simple_src_file_path: [*:0]const u8) callconv(.C) c_uint {
    instance = makeInstance(simple_src_file_path) catch |e| {
        return @intFromEnum(errorToEnum(e));
    };

    return @intFromEnum(ErrorEnum.OK);
}

pub export fn Deinit() callconv(.C) c_uint { 
    if (instance) |value| {
        value.ast.deinit();
        return @intFromEnum(ErrorEnum.OK);
    }
    return @intFromEnum(ErrorEnum.TRIED_TO_DEINIT_EMPTY_INSTANCE);
}

pub export fn GetError() callconv(.C) [*:0]const u8 {
    return &error_buffer;
}

pub export fn Follows(s1_type: c_uint, s1: c_uint, s2_type: c_uint, s2: c_uint) callconv(.C) [*c]c_uint {
    // can't select 2 statments, can't select 
    if ((s1 == 0 and s2 == 0) or (s1 == 0xFF_FF_FF_FF and s2 == 0xFF_FF_FF_FF)) {
        return 0x0;
    }

    if (instance) |value| {
        _ = value.ast.follows(
            result_buffer_stream.writer(),
            @enumFromInt(@as(u32, s1_type)),
            @intCast(s1), 
            @enumFromInt(@as(u32, s2_type)),
            @intCast(s2)
        ) catch unreachable;
        return @alignCast(@ptrCast(result_buffer[0..].ptr));
    }

    return 0x0;
}

pub export fn FollowsTransitive(s1: c_uint, s2: c_uint) callconv(.C) c_uint {
    if (instance) |value| {
        return @intCast(@intFromBool(value.ast.followsTransitive(@intCast(s1), @intCast(s2))));
    }
    return 0;
}

pub export fn Parent(s1: c_uint, s2: c_uint) callconv(.C) c_uint {
    if (instance) |value| {
        return @intCast(@intFromBool(value.ast.parent(@intCast(s1), @intCast(s2))));
    }
    return 0;
}

pub export fn ParentTransitive(s1: c_uint, s2: c_uint) callconv(.C) c_uint {
    if (instance) |value| {
        return @intCast(@intFromBool(value.ast.parentTransitive(@intCast(s1), @intCast(s2))));
    }
    return 0;
}

pub const Error = error{ 
    SIMPLE_FILE_OPEN_ERROR, 
    TRIED_TO_DEINIT_EMPTY_INSTANCE
} || Tokenizer.Error || ASTParser.Error;

pub const ErrorEnum = enum(u32) {
    OK = 0,
    SIMPLE_FILE_OPEN_ERROR,
    TRIED_TO_DEINIT_EMPTY_INSTANCE,
    TOKENIZER_OUT_OF_MEMORY,
    SIMPLE_STREAM_READING_ERROR,
    UNEXPECTED_CHAR,
    PARSER_OUT_OF_MEMORY,
    NO_MATCHING_RIGHT_PARENTHESIS,
    WRONG_FACTOR,
    SEMICOLON_NOT_FOUND_AFTER_ASSIGN,
    ASSIGN_CHAR_NOT_FOUND,
    SEMICOLON_NOT_FOUND_AFTER_CALL,
    CALLED_PROCEDURE_NAME_NOT_FOUND,
    THEN_KEYWORD_NOT_FOUND,
    MATCHING_ELSE_CLOUSE_NOT_FOUND,
    VAR_NAME_NOT_FOUND,
    TOO_FEW_STATEMENTS,
    INVALID_STATEMENT,
    RIGHT_BRACE_NOT_FOUND,
    LEFT_BRACE_NOT_FOUND,        
    KEYWORD_NOT_FOUND,
    PROCEDURE_NAME_NOT_FOUND,
};

pub fn errorToEnum(err: Error) ErrorEnum {
    return switch (err) {
        inline else => |e| @field(ErrorEnum, @errorName(e)),
    };
}
