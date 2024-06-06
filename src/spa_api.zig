const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const ERR_BUFFER_SIZE = 1024;
const RESULT_BUFFER_SIZE = 8192;

const ASTParser = @import("AstParser.zig").AstParser(std.io.FixedBufferStream([]u8).Writer);
const Tokenizer = @import("Tokenizer.zig").Tokenizer(std.io.FixedBufferStream([]u8).Writer);
const AST = @import("Ast.zig");
const Pkb = @import("Pkb.zig");
const ApiCommon = @import("spa_api_common.zig");
const ProcMap = @import("ProcMap.zig");

const api = struct {
    usingnamespace @import("follows_api.zig").FollowsApi(c_uint);
    usingnamespace @import("parent_api.zig").ParentApi(c_uint);
    usingnamespace @import("uses_modifies_api.zig").UsesModifiesApi(c_uint);
    usingnamespace @import("calls_api.zig").CallsApi(c_uint);
};

const allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

var error_buffer: [ERR_BUFFER_SIZE:0]u8 = .{0} ** ERR_BUFFER_SIZE;
var error_buffer_stream = std.io.fixedBufferStream(error_buffer[0..]);

var result_buffer: [RESULT_BUFFER_SIZE]u8 = .{0} ** RESULT_BUFFER_SIZE;
var result_buffer_stream = std.io.fixedBufferStream(result_buffer[0..]);

var result_buffer_size: u32 = 0;

var error_code: c_uint = 0;

var instance: ?*Pkb = null;

pub const NodeC = extern struct {
    type: c_uint = 0,
    value_id: c_uint = 0,
    statement_id: c_uint = 0,
    line_no: c_int = 0,
    column_no: c_int = 0,
};

// Returns metadata of node which has an id <id>. In case of failure,
// returns zeroed out node metadata and sets error code.
pub export fn GetNode(id: c_uint) callconv(.C) NodeC {
    if (instance) |value| {
        if (id < value.ast.nodes.len) {
            const node = value.ast.nodes[@intCast(id)];
            return .{
                .type = @intFromEnum(node.type),
                .value_id = @intCast(node.value_id_or_const),
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

// Returns proc name of id specified in Node structure.
pub export fn GetProcName(proc_id: c_uint) callconv(.C) [*:0]const u8 {
    if (instance) |value| {
        if (value.ast.proc_table.getByIndex(proc_id)) |str| {
            _ = result_buffer_stream.writer().write(str[0..]) catch unreachable;
            _ = result_buffer_stream.writer().writeByte(0) catch unreachable;
            result_buffer_stream.reset();
            return @ptrCast(result_buffer[0..].ptr);
        } else {
            error_code = @intFromEnum(ErrorEnum.PROC_ID_OUT_OF_BOUNDS);
        }
    } else {
        error_code = @intFromEnum(ErrorEnum.TRIED_TO_USE_EMPTY_INSTANCE);
    }
    result_buffer[0] = 0;
    return @ptrCast(result_buffer[0..].ptr);
}

// Returns var name of id specified in Node structure.
pub export fn GetVarName(var_id: c_uint) callconv(.C) [*:0]const u8 {
    if (instance) |value| {
        if (value.ast.var_table.getByIndex(var_id)) |str| {
            _ = result_buffer_stream.writer().write(str[0..]) catch unreachable;
            _ = result_buffer_stream.writer().writeByte(0) catch unreachable;
            result_buffer_stream.reset();
            return @ptrCast(result_buffer[0..].ptr);
        } else {
            error_code = @intFromEnum(ErrorEnum.VAR_ID_OUT_OF_BOUNDS);
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

// Gets Ast size
pub export fn GetAstSize() callconv(.C) c_uint {
    if (instance) |pkb| {
        return @intCast(pkb.ast.nodes.len);
    }
    return 0;
}
// Gets proc table size
pub export fn GetProcTableSize() callconv(.C) c_uint {
    if (instance) |pkb| {
        return @intCast(pkb.ast.proc_table.table.items.len);
    }
    return 0;
}
// Gets var table size
pub export fn GetVarTableSize() callconv(.C) c_uint {
    if (instance) |pkb| {
        return @intCast(pkb.ast.var_table.table.items.len);
    }
    return 0;
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
    return execRelationFollowsParent(api.follows,
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
    return execRelationFollowsParent(api.followsTransitive,
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
    return execRelationFollowsParent(api.parent,
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
    return execRelationFollowsParent(api.parentTransitive,
        s1_type, s1, s1_value,
        s2_type, s2, s2_value,
    );
}

pub export fn ModifiesProc(proc_name: [*:0]const u8, var_name: [*:0]const u8) callconv(.C) [*c]c_uint {
    return execRelationUsesModifies(api.modifies,
        .{ .proc_name = proc_name[0..std.mem.len(proc_name)] },
        var_name
    );
}
pub export fn Modifies(node_id: c_uint, var_name: [*:0]const u8) callconv(.C) [*c]c_uint {
    return execRelationUsesModifies(api.modifies, .{ .node_id = node_id }, var_name );
}

pub export fn UsesProc(proc_name: [*:0]const u8, var_name: [*:0]const u8) callconv(.C) [*c]c_uint {
    return execRelationUsesModifies(api.uses,
        .{ .proc_name = proc_name[0..std.mem.len(proc_name)] },
        var_name
    );
}
pub export fn Uses(node_id: c_uint, var_name: [*:0]const u8) callconv(.C) [*c]c_uint {
    return execRelationUsesModifies(api.uses, .{ .node_id = node_id }, var_name );
}

pub export fn CallsProcNameProcName(p1: [*:0]const u8, p2: [*:0]const u8) callconv(.C) [*c]c_uint {
    return execRelationCalls(api.calls,
        .{ .proc_name = p1[0..std.mem.len(p1)] },
        .{ .proc_name = p2[0..std.mem.len(p2)] }
    );
}
pub export fn CallsTransitiveProcNameProcName(p1: [*:0]const u8, p2: [*:0]const u8) callconv(.C) [*c]c_uint {
    return execRelationCalls(api.callsTransitive,
        .{ .proc_name = p1[0..std.mem.len(p1)] },
        .{ .proc_name = p2[0..std.mem.len(p2)] }
    );
}
pub export fn CallsNodeIdNodeId(p1: c_uint, p2: c_uint) callconv(.C) [*c]c_uint {
    return execRelationCalls(api.calls, .{ .node_id = p1 }, .{ .node_id = p2 });
}
pub export fn CallsTransitiveNodeIdNodeId(p1: c_uint, p2: c_uint) callconv(.C) [*c]c_uint {
    return execRelationCalls(api.callsTransitive, .{ .node_id = p1 }, .{ .node_id = p2 });
}



pub const Error = error{ 
    SIMPLE_FILE_OPEN_ERROR, 
    TRIED_TO_DEINIT_EMPTY_INSTANCE,
    NODE_ID_OUT_OF_BOUNDS,
    PROC_ID_OUT_OF_BOUNDS,
    VAR_ID_OUT_OF_BOUNDS,
    TRIED_TO_USE_EMPTY_INSTANCE,
    UNDEFINED
} || Tokenizer.Error || ASTParser.Error || ApiCommon.Error || Pkb.Error || ProcMap.Error;

pub const ErrorEnum = enum(u32) {
    OK = 0,
    SIMPLE_FILE_OPEN_ERROR,
    TRIED_TO_DEINIT_EMPTY_INSTANCE,
    NODE_ID_OUT_OF_BOUNDS,
    PROC_ID_OUT_OF_BOUNDS,
    VAR_ID_OUT_OF_BOUNDS,
    PROC_NOT_FOUND,
    VAR_NOT_FOUND,
    TRIED_TO_USE_EMPTY_INSTANCE,
    TOKENIZER_OUT_OF_MEMORY,
    SIMPLE_STREAM_READING_ERROR,
    UNEXPECTED_CHAR,
    PROC_VAR_TABLE_OUT_OF_MEMORY,
    PARSER_OUT_OF_MEMORY,
    PROC_MAP_OUT_OF_MEMORY,
    PKB_OUT_OF_MEMORY,
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

fn execRelationFollowsParent(
    func: *const fn(*Pkb,
        std.io.FixedBufferStream([]u8).Writer,
        NodeType, u32, ?[]const u8,
        NodeType, u32, ?[]const u8
    ) anyerror!u32,
    s1_type: c_uint, s1: c_uint, s1_value: [*:0]const u8,
    s2_type: c_uint, s2: c_uint, s2_value: [*:0]const u8,
) [*c]c_uint {
    if (instance) |value| {
        result_buffer_size = func(value,
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
fn execRelationUsesModifies(
    func: *const fn(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
        ref_query_arg: ApiCommon.RefQueryArg, var_name: ?[]const u8,
    ) anyerror!u32,
    ref_query_arg: ApiCommon.RefQueryArg, var_name: [*:0]const u8,
) [*c]c_uint {
    if (instance) |value| {
        result_buffer_size = func(value,
            result_buffer_stream.writer(),
            ref_query_arg,
            if (std.mem.len(var_name) > 0) var_name[0..std.mem.len(var_name)] else null
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
fn execRelationCalls(
    func: *const fn(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
        p1: ApiCommon.RefQueryArg, p2: ApiCommon.RefQueryArg
    ) anyerror!u32,
    p1: ApiCommon.RefQueryArg, p2: ApiCommon.RefQueryArg
) [*c]c_uint {
    if (instance) |value| {
        result_buffer_size = func(value,
            result_buffer_stream.writer(),
            p1, p2,
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

fn makeInstance(simple_src_file_path: [*:0]const u8) Error!*Pkb {
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

    return try Pkb.init(ast, std.heap.page_allocator);
}

