const std = @import("std");

pub const AST = @import("Ast.zig");
pub const Node = @import("node.zig").Node;
pub const NodeId = @import("node.zig").NodeId;
pub const NodeType = @import("node.zig").NodeType;

const Pkb = @import("Pkb.zig");

pub const common = @import("spa_api_common.zig");

const RefQueryArg = common.RefQueryArg;

const ProcMapEntry = @import("ProcMap.zig").Entry;

const checkNodeType = common.checkNodeType;

pub const CommonError = @import("spa_api_common.zig").Error;
pub const STATEMENT_UNDEFINED = @import("spa_api_common.zig").STATEMENT_UNDEFINED;
pub const STATEMENT_SELECTED = @import("spa_api_common.zig").STATEMENT_SELECTED;

pub fn CallsApi(comptime ResultIntType: type) type { return struct {

const Self = @This();

pub const Error = common.Error;

fn getProcProcVarId(pkb: *Pkb, arg: RefQueryArg) !u32 {
    if (arg.hasProcName()) {
        if (pkb.ast.proc_table.hashmap.get(arg.proc_name)) |proc_var_id| {
            return proc_var_id;
        }
        return error.PROC_NOT_FOUND;
    }
    if (arg.node_id < pkb.ast.nodes.len) {
        const proc_node = pkb.ast.nodes[arg.node_id];
        if (proc_node.type != .PROCEDURE and proc_node.type != .CALL) {
            return error.PROC_NOT_FOUND;
        }

        const proc_var_id = proc_node.value_id_or_const;

        return proc_var_id;
    } else {
        return error.PROC_NOT_FOUND;
    }
}


pub fn calls(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    p1: RefQueryArg, p2: RefQueryArg
) !u32 {

    const p1_proc_var_id = try getProcProcVarId(pkb, p1);
    const p2_proc_var_id = try getProcProcVarId(pkb, p2);

    const p1_proc_map_entry = pkb.ast.proc_map.get(p1_proc_var_id);

    if (p1_proc_map_entry.calls.isSet(p2_proc_var_id)) {
        try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
        return 1;
    }

    return 0;
}

fn callsTransitiveRecursive(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    p1_proc_var_id: u32, p2_proc_var_id: u32
) !u32 {
    const p1_proc_map_entry = pkb.ast.proc_map.get(p1_proc_var_id);

    if (p1_proc_map_entry.calls.isSet(p2_proc_var_id)) {
        try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
        return 1;
    }

    var i = p1_proc_map_entry.calls.iterator(.{ .kind = .set, .direction = .forward });
    while (i.next()) |proc_var_id| {
        if (try callsTransitiveRecursive(pkb, result_writer, @intCast(proc_var_id), p2_proc_var_id) == 1) {
            return 1;
        }
    }
    return 0;
}

pub fn callsTransitive(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    p1: RefQueryArg, p2: RefQueryArg
) !u32 {
    
    const p1_proc_var_id = try getProcProcVarId(pkb, p1);
    const p2_proc_var_id = try getProcProcVarId(pkb, p2);
   
    return callsTransitiveRecursive(pkb, result_writer, p1_proc_var_id, p2_proc_var_id);
}

};}
