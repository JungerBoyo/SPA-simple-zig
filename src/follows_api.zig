const std = @import("std");

pub const AST = @import("Ast.zig");
pub const Node = @import("node.zig").Node;
pub const NodeId = @import("node.zig").NodeId;
pub const NodeType = @import("node.zig").NodeType;

const Pkb = @import("Pkb.zig");

pub const common = @import("spa_api_common.zig");

const checkNodeType = common.checkNodeType;

pub const CommonError = @import("spa_api_common.zig").Error;
pub const STATEMENT_UNDEFINED = @import("spa_api_common.zig").STATEMENT_UNDEFINED;
pub const STATEMENT_SELECTED = @import("spa_api_common.zig").STATEMENT_SELECTED;

pub fn FollowsApi(comptime ResultIntType: type) type { return struct {

const Self = @This();

fn followsModeSelUndef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    s_undef_type: NodeType, s_undef_value: ?[]const u8,
    begin: usize, step: i32
) !u32 {
    var written: u32 = 0;
    for (begin..pkb.ast.statement_map.len) |i| {
        const s_sel: u32 = @intCast(i);
        const s_undef: u32 = Self.getFollowingStatement(pkb, s_sel, step);
        if (s_undef == 0) {
            continue;
        }
        if (Self.followsCheck(pkb, s_sel_type, s_sel, s_sel_value, s_undef_type, s_undef, s_undef_value)) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(pkb.ast.statement_map[i])), .little);
            written += 1;
        }
    }
    return written;
}
fn followsModeSelDef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_def: u32, s_def_type: NodeType, s_def_value: ?[]const u8,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    step: i32
) !u32 {
    const s_sel = Self.getFollowingStatement(pkb, s_def, step);
    if (s_sel == 0) {
        return 0;
    }
    if (Self.followsCheck(pkb, s_def_type, s_def, s_def_value, s_sel_type, s_sel, s_sel_value)) {
        try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(pkb.ast.statement_map[s_sel])), .little);
        return 1;
    }
    return 0;
}

fn followsModeDef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    const s1_index = pkb.ast.findStatement(s1);
    if (s1_index == 0) {
        return 0;
    }
    if (s1_index + 1 < pkb.ast.nodes.len and pkb.ast.nodes[s1_index + 1].metadata.statement_id == s2) {
        if (Self.followsCheck(pkb, s1_type, s1, s1_value, s2_type, s2, s2_value)) {
            try result_writer.writeInt(ResultIntType, 1, .little);
            return 1;
        }
    }
    return 0;
}

pub fn follows(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (pkb.ast.statement_map.len < 2 or s1 == s2) {
        return 0;
    }
    // both undefined
    if (common.isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try Self.followsModeSelUndef(pkb, result_writer, s1_type, s1_value, s2_type, s2_value, 1, 1)
            else
                try Self.followsModeSelUndef(pkb, result_writer, s2_type, s2_value, s1_type, s1_value, 2,-1);
    // one of the statements defined
    } else if (common.isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try Self.followsModeSelDef(pkb, result_writer, s2, s2_type, s2_value, s1_type, s1_value,-1)
            else
                try Self.followsModeSelDef(pkb, result_writer, s1, s1_type, s1_value, s2_type, s2_value, 1);
    // both statements defined
    } else if (common.isModeDef(s1, s2)) {
        return try Self.followsModeDef(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}

fn followsTransitiveModeSelUndef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    s_undef_type: NodeType, s_undef_value: ?[]const u8,
    begin: usize, step: i32
) !u32 {
    var written: u32 = 0;
    for (begin..pkb.ast.statement_map.len) |i| {
        const s_sel_index = pkb.ast.statement_map[i];
        const s_sel_node = pkb.ast.nodes[s_sel_index];
        if (!checkNodeType(s_sel_node.type, s_sel_type) or !pkb.ast.checkValue(s_sel_node, s_sel_value)) {
            continue;            
        }
        
        var s_undef_index = @as(i32, @intCast(s_sel_index)) + step;
        while (s_undef_index < pkb.ast.nodes.len and s_undef_index > 0) : (s_undef_index += step) {
            const s_undef_node = pkb.ast.nodes[@intCast(s_undef_index)];
            if (s_undef_node.parent_index == s_sel_node.parent_index) {
                if (checkNodeType(s_undef_node.type, s_undef_type) and pkb.ast.checkValue(s_undef_node, s_undef_value)) {
                    try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_sel_index)), .little);
                    written += 1;
                    break;
                }
            } else {
                break;
            }
        }
    }
    return written;
}

fn followsTransitiveModeSelDef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_def_type: NodeType, s_def: u32, s_def_value: ?[]const u8,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    step: i32
) !u32 {
    const s_def_index = pkb.ast.findStatement(s_def);
    const s_def_node = pkb.ast.nodes[s_def_index];
    if (s_def_index == 0 or !checkNodeType(s_def_node.type, s_def_type) or !pkb.ast.checkValue(s_def_node, s_def_value)) {
        return 0;
    }
    const s_def_parent_index = pkb.ast.nodes[s_def_index].parent_index; 
    var s_sel_index: i32 = @as(i32, @intCast(s_def_index)) + step;
    var written: u32 = 0;
    while (s_sel_index < pkb.ast.nodes.len and s_sel_index > 0) : (s_sel_index += step) {
        const s_sel_node = pkb.ast.nodes[@intCast(s_sel_index)];
        if (s_sel_node.parent_index == s_def_parent_index) {
            if (checkNodeType(s_sel_node.type, s_sel_type) and pkb.ast.checkValue(s_sel_node, s_sel_value)) {
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_sel_index)), .little);
                written += 1;
            }
        } else {
            break;
        }
    }
    return written;
}

fn followsTransitiveModeDef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    const s1_index = pkb.ast.findStatement(s1);
    const s1_node = pkb.ast.nodes[s1_index];
    if (s1_index == 0 or !checkNodeType(s1_node.type, s1_type) or !pkb.ast.checkValue(s1_node, s1_value)) {
        return 0;
    }
    const s1_parent_index = s1_node.parent_index; 
    for (pkb.ast.nodes[(s1_index + 1)..]) |s2_node| {
        if (s2_node.parent_index == s1_parent_index) {
            if (s2_node.metadata.statement_id == s2 and checkNodeType(s2_node.type, s2_type) and pkb.ast.checkValue(s2_node, s2_value)) {
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
                return 1;
            }
        } else {
            return 0;
        }
    }
    return 0;
}

pub fn followsTransitive(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (pkb.ast.statement_map.len < 2 or s1 == s2) {
        return 0;
    }
    // both undefined
    if (common.isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try Self.followsTransitiveModeSelUndef(pkb, result_writer, s1_type, s1_value, s2_type, s2_value, 1, 1)
            else
                try Self.followsTransitiveModeSelUndef(pkb, result_writer, s2_type, s2_value, s1_type, s1_value, 2, -1);
    // one of the statements defined
    } else if (common.isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try Self.followsTransitiveModeSelDef(pkb, result_writer, s2_type, s2, s2_value, s1_type, s1_value, -1)
            else
                try Self.followsTransitiveModeSelDef(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2_value, 1);
    // both statements defined
    } else if (common.isModeDef(s1, s2)) {
        return try Self.followsTransitiveModeDef(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}

/// follows check doesn't care about
/// which statement follows which
fn followsCheck(pkb: *Pkb,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) bool {
    if (s1 >= pkb.ast.statement_map.len or s2 >= pkb.ast.statement_map.len) {
        return false;
    }
    const s1_node = pkb.ast.nodes[pkb.ast.statement_map[s1]];
    const s2_node = pkb.ast.nodes[pkb.ast.statement_map[s2]];
    return
        (s1_type == .NONE or s1_node.type == s1_type) and
        (s2_type == .NONE or s2_node.type == s2_type) and
        s1_node.parent_index == s2_node.parent_index and
        pkb.ast.checkValue(s1_node, s1_value) and pkb.ast.checkValue(s2_node, s2_value);
}

fn getFollowingStatement(pkb: *Pkb, statement_id: u32, step: i32) u32 {
    const s_index = pkb.ast.findStatement(statement_id);
    if (s_index == 0) {
        return 0;
    }
    const index = @as(usize, @intCast(@as(i32, @intCast(s_index)) + step));
    if (index < pkb.ast.nodes.len) {
        return pkb.ast.nodes[index].metadata.statement_id;
    }
    return 0;
}

};}
