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

var result_buffer_size: u32 = 0;

var error_code: c_uint = 0;

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

    const ast = try parser.parse();

    return .{ .ast = ast };
}

pub const NodeC = extern struct {
    type: c_uint = 0,
    statement_id: c_uint = 0,
    line_no: c_int = 0,
    column_no: c_int = 0,
};


// Returns metadata of node which has an id <id>. In case of failure,
// returns zeroed out node metadata and sets error code.
pub export fn GetNodeMetadata(id: c_uint) callconv(.C) NodeC {
    if (instance) |value| {
        if (id < value.ast.nodes.len) {
            const node = value.ast.nodes[@intCast(id)];
            return .{
                .type = @intFromEnum(node.type),
                .statement_id = @intCast(node.metadata.statement_id),
                .line_no = @intCast(node.metadata.line_no),
                .column_no = @intCast(node.metadata.column_no)
            };
        } else {
            error_code = @intFromEnum(ErrorEnum.NODE_ID_OUT_OF_BOUNDS);
        }
    } else {
        error_code = @intFromEnum(ErrorEnum.TRIED_TO_USE_EMPTY_INSTANCE);
    }
    return .{};
}

// Returns node's value. Eg. in case of assign statement value
// will be the name of the variable, and in case of procedure value
// is going to be procedure name and so on. In case of failure,
// return empty string and sets error code.
pub export fn GetNodeValue(id: c_uint) callconv(.C) [*:0]const u8 {
    if (instance) |value| {
        if (id < value.ast.nodes.len) {
            const node = value.ast.nodes[@intCast(id)];
            if (node.type == .ASSIGN or node.type == .VAR) {
                if (value.ast.var_table.getByIndex(node.value_id_or_const)) |str| {
                    _ = result_buffer_stream.writer().write(str[0..]) catch unreachable;
                    _ = result_buffer_stream.writer().writeByte(0) catch unreachable;
                    return @ptrCast(result_buffer[0..].ptr);
                }
            }
            if (node.type == .PROCEDURE or node.type == .CALL) {
                if (value.ast.proc_table.getByIndex(node.value_id_or_const)) |str| {
                    _ = result_buffer_stream.writer().write(str[0..]) catch unreachable;
                    _ = result_buffer_stream.writer().writeByte(0) catch unreachable;
                    return @ptrCast(result_buffer[0..].ptr);
                }
            }
        } else {
            error_code = @intFromEnum(ErrorEnum.NODE_ID_OUT_OF_BOUNDS);
        }
    } else {
        error_code = @intFromEnum(ErrorEnum.TRIED_TO_USE_EMPTY_INSTANCE);
    }
    result_buffer[0] = 0;
    return @ptrCast(result_buffer[0..].ptr);
}


// Takes path to SPA lang source file and creates PKB instance
// based on it. MUST be called before any functions from the API are called.
// Returns error code or OK.
pub export fn Init(simple_src_file_path: [*:0]const u8) callconv(.C) c_uint {
    instance = makeInstance(simple_src_file_path) catch |e| {
        error_code = @intCast(@intFromEnum(errorToEnum(e)));
        return error_code;
    };

    return @intFromEnum(ErrorEnum.OK);
}

// Deinitializes context. Frees up memory basically.
// Returns OK or an error code.
pub export fn Deinit() callconv(.C) c_uint { 
    if (instance) |value| {
        value.ast.deinit();
        return @intFromEnum(ErrorEnum.OK);
    }
    error_code = @intFromEnum(ErrorEnum.TRIED_TO_DEINIT_EMPTY_INSTANCE);
    return @intFromEnum(ErrorEnum.TRIED_TO_DEINIT_EMPTY_INSTANCE);
}

// Gets current error message from error buffer. MUST correspond
// logically to error code. If it is not, then it means error message
// is "old".
pub export fn GetErrorMessage() callconv(.C) [*:0]const u8 {
    return &error_buffer;
}

// Gets current error code and OKays out current error code after
// returning.
pub export fn GetErrorCode() callconv(.C) c_uint {
    // clear error code upon reading it
    defer error_code = @intFromEnum(ErrorEnum.OK);
    return error_code;
}

// Gets current result size (eg. from last call to any of the
// relation funcitons). Upon return sets result buffer size
// to 0.
pub export fn GetResultSize() callconv(.C) c_uint {
    defer result_buffer_size = 0;
    return result_buffer_size;
}

fn execRelation(
    func: *const fn(*AST,
        std.io.FixedBufferStream([]u8).Writer,
        NodeType, u32, ?[]const u8,
        NodeType, u32, ?[]const u8
    ) anyerror!u32,
    s1_type: c_uint, s1: c_uint, s1_value: [*:0]const u8,
    s2_type: c_uint, s2: c_uint, s2_value: [*:0]const u8,
) [*c]c_uint {
    if (instance) |value| {
        result_buffer_size = func(value.ast,
            result_buffer_stream.writer(),
            @enumFromInt(@as(u32, s1_type)),
            @intCast(s1),
            if (std.mem.len(s1_value) > 0) s1_value[0..std.mem.len(s1_value)] else null,
            @enumFromInt(@as(u32, s2_type)),
            @intCast(s2),
            if (std.mem.len(s2_value) > 0) s2_value[0..std.mem.len(s2_value)] else null,
        ) catch |e| {
            if (e == error.UNSUPPORTED_COMBINATION) {
                error_code = @intFromEnum(errorToEnum(error.UNSUPPORTED_COMBINATION));
            } else {
                error_code = @intFromEnum(errorToEnum(error.UNDEFINED));
            }

            return 0x0;
        };
        result_buffer_stream.reset();
        return @alignCast(@ptrCast(result_buffer[0..].ptr));
    } else {
        error_code = @intFromEnum(ErrorEnum.TRIED_TO_USE_EMPTY_INSTANCE);
    }
    return 0x0;
}
// Follows relation. As parameters, takes statement type, id 
// (statement id not node id!!!) and value which is explained in 
// GetNodeValue. Important notes: 
//
// <s1>/<s2> can take 3 different TYPES of values;
//      - 0 -> means that that statement is SELECTED
//      - UINT32_MAX -> means that that statement is UNDEFINED (
//                      there are yet none constraints put onto it)
//      - (0, UINT32_MAX) -> concrete statement id
//
// examples:
//      * assign a; stmt s; select s such that follows(s, a) with a.varname = "x";
//          translates to:
//              Follows(NONE, 0, null, ASSIGN, UINT32_MAX, "x");
//              returns: all node ids of s's which fullfil the relation
//
//      * assign a; select a such that follows(5, a) with a.varname = "x";
//          translates to:
//              Follows(NONE, 5, null, ASSIGN, 0, "x");
//
//  etc.
// In case of failure, returns NULL and sets error code.
pub export fn Follows(
    s1_type: c_uint, s1: c_uint, s1_value: [*:0]const u8,
    s2_type: c_uint, s2: c_uint, s2_value: [*:0]const u8,
) callconv(.C) [*c]c_uint {
    return execRelation(AST.follows,
        s1_type, s1, s1_value,
        s2_type, s2, s2_value,
    );
}

// Follows transitive aka Follows* relation. As parameters, takes statement type, id 
// (statement id not node id!!!) and value which is explained in 
// GetNodeValue. Check 'Follows' comments for details.
// In case of failure, returns NULL and sets error code.
pub export fn FollowsTransitive(
    s1_type: c_uint, s1: c_uint, s1_value: [*:0]const u8,
    s2_type: c_uint, s2: c_uint, s2_value: [*:0]const u8,
) callconv(.C) [*c]c_uint {
    return execRelation(AST.followsTransitive,
        s1_type, s1, s1_value,
        s2_type, s2, s2_value,
    );
}

// Parent relation. As parameters, takes statement type, id 
// (statement id not node id!!!) and value which is explained in 
// GetNodeValue. Check 'Follows' comments for details.
// In case of failure, returns NULL and sets error code.
pub export fn Parent(
    s1_type: c_uint, s1: c_uint, s1_value: [*:0]const u8,
    s2_type: c_uint, s2: c_uint, s2_value: [*:0]const u8,
) callconv(.C) [*c]c_uint {
    return execRelation(AST.parent,
        s1_type, s1, s1_value,
        s2_type, s2, s2_value,
    );
}

// Parent* relation. As parameters, takes statement type, id 
// (statement id not node id!!!) and value which is explained in 
// GetNodeValue. Check 'Follows' comments for details.
// In case of failure, returns NULL and sets error code.
pub export fn ParentTransitive(
    s1_type: c_uint, s1: c_uint, s1_value: [*:0]const u8,
    s2_type: c_uint, s2: c_uint, s2_value: [*:0]const u8,
) callconv(.C) [*c]c_uint {
    return execRelation(AST.parentTransitive,
        s1_type, s1, s1_value,
        s2_type, s2, s2_value,
    );
}
pub const Error = error{ 
    SIMPLE_FILE_OPEN_ERROR, 
    TRIED_TO_DEINIT_EMPTY_INSTANCE,
    NODE_ID_OUT_OF_BOUNDS,
    TRIED_TO_USE_EMPTY_INSTANCE,
    UNDEFINED
} || Tokenizer.Error || ASTParser.Error || AST.Error;

pub const ErrorEnum = enum(u32) {
    OK = 0,
    SIMPLE_FILE_OPEN_ERROR,
    TRIED_TO_DEINIT_EMPTY_INSTANCE,
    NODE_ID_OUT_OF_BOUNDS,
    TRIED_TO_USE_EMPTY_INSTANCE,
    TOKENIZER_OUT_OF_MEMORY,
    SIMPLE_STREAM_READING_ERROR,
    UNEXPECTED_CHAR,
    PROC_VAR_TABLE_OUT_OF_MEMORY,
    PARSER_OUT_OF_MEMORY,
    INT_OVERFLOW,
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
    UNSUPPORTED_COMBINATION,
    WRITER_ERROR,
    UNDEFINED
};

pub fn errorToEnum(err: Error) ErrorEnum {
    return switch (err) {
        inline else => |e| @field(ErrorEnum, @errorName(e)),
    };
}
