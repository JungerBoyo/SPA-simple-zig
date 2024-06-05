const std = @import("std");

pub const AST = @import("Ast.zig");
pub const Node = @import("node.zig").Node;
pub const NodeId = @import("node.zig").NodeId;
pub const NodeType = @import("node.zig").NodeType;

const Pkb = @import("Pkb.zig");

pub const common = @import("spa_api_common.zig");

pub const RefQueryArg = common.RefQueryArg;

const checkNodeType = common.checkNodeType;

pub const CommonError = @import("spa_api_common.zig").Error;
pub const NODE_UNDEFINED = @import("spa_api_common.zig").NODE_UNDEFINED;
pub const NODE_SELECTED = @import("spa_api_common.zig").NODE_SELECTED;

pub fn UsesModifiesApi(comptime ResultIntType: type) type { return struct {

const Self = @This();

pub const Error = common.Error;

fn refProcDefVar(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    proc_name: []const u8, var_name: []const u8,
) !u32 {
    if (pkb.ast.proc_table.hashmap.get(proc_name)) |proc_id| {
        if (pkb.ast.var_table.hashmap.get(var_name)) |var_id| {
            const proc_index = pkb.ast.proc_map.get(proc_id).node_index;
            if (table[proc_index].isSet(var_id)) {
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
                return 1;
            }
        } else {
            return error.VAR_NOT_FOUND;
        }
    } else {
        return error.PROC_NOT_FOUND;
    }
    return 0;
}

fn refProcSelVar(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    proc_name: []const u8 
) !u32 {
    if (pkb.ast.proc_table.hashmap.get(proc_name)) |proc_id| {
        const proc_index = pkb.ast.proc_map.get(proc_id).node_index;

        var result: u32 = 0;
        var iterator = table[proc_index].iterator(.{ .kind = .set, .direction = .forward });
        while (iterator.next()) |i| {
            result += 1;
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(i)), .little);
        }

        return result;
    } else {
        return error.PROC_NOT_FOUND;
    }
}

fn refSelNodeDefVar(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    var_name: []const u8,
) !u32 {
    if (pkb.ast.var_table.hashmap.get(var_name)) |var_id| {
        var result: u32 = 0;
        for (table, 0..) |entry, i| {
            if (entry.isSet(var_id)) {
                result += 1;
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(i)), .little);
            }
        }
        return result;
    } else {
        return error.VAR_NOT_FOUND;
    }
}
fn refSelNodeUndefVar(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
) !u32 {
    _ = pkb;
    var result: u32 = 0;
    for (table, 0..) |entry, i| {
        if (entry.findFirstSet()) |_| {
            result += 1;
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(i)), .little);
        }
    }
    return result;
}
fn refUndefNodeSelVar(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
) !u32 {
    var result: u32 = 0;
    for (pkb.ast.var_table.table.items, 0..) |_, i| {
        result += 1;
        try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(i)), .little);
    }
    return result;
}

fn refDefNodeDefVar(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    node_id: u32, var_name: []const u8,
) !u32 {
    if (pkb.ast.var_table.hashmap.get(var_name)) |var_id| {
        if (table[node_id].isSet(var_id)) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
            return 1;
        }
    } else {
        return error.VAR_NOT_FOUND;
    }
    return 0;
}
fn refDefNodeSelVar(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    node_id: u32,
) !u32 {
    _ = pkb;
    var result: u32 = 0;
    var iterator = table[node_id].iterator(.{ .kind = .set, .direction = .forward });
    while (iterator.next()) |i| {
        result += 1;
        try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(i)), .little);
    }

    return result;
}

fn refGeneric(pkb: *Pkb,
    table: []std.DynamicBitSetUnmanaged,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    ref_query_arg: RefQueryArg, var_name: ?[]const u8,
) !u32 {
    if (ref_query_arg.hasProcName()) {
        if (var_name) |str| {
            // "proc_name" (D), "var_name" (D)
            return refProcDefVar(pkb, table, result_writer, ref_query_arg.proc_name, str);
        } else {
            // "proc_name" (D), null (S)
            return refProcSelVar(pkb, table, result_writer, ref_query_arg.proc_name);
        }
    } else {
        if (ref_query_arg.node_id == NODE_SELECTED) {
            if (var_name) |str| {
                // node_id (S), "var_name" (D)
                return refProcSelVar(pkb, table, result_writer, str);
            } else {
                // node_id (S), null (U)
                return refSelNodeUndefVar(pkb, table, result_writer);
            }
        } else if (ref_query_arg.node_id == NODE_UNDEFINED) {
            if (var_name) |_| {
                return CommonError.UNSUPPORTED_COMBINATION;
            } else {
                // node_id (U), null (S)
                return refUndefNodeSelVar(pkb, result_writer);
            }
        } else {
            if (var_name) |str| {
                // node_id (D), "var_name" (D)
                return refDefNodeDefVar(pkb, table, result_writer, ref_query_arg.node_id, str);
            } else {
                // node_id (D), null (S)
                return refDefNodeSelVar(pkb, table, result_writer, ref_query_arg.node_id);
            }
        }
    }
}

pub fn modifies(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    ref_query_arg: RefQueryArg, var_name: ?[]const u8,
) !u32 {
    return refGeneric(pkb, pkb.modifies_table, result_writer, ref_query_arg, var_name);
}
pub fn uses(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    ref_query_arg: RefQueryArg, var_name: ?[]const u8,
) !u32 {
    return refGeneric(pkb, pkb.uses_table, result_writer, ref_query_arg, var_name);
}

};}
