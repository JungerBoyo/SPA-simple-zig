const std = @import("std");

pub const AST = @import("Ast.zig");
pub const Node = @import("node.zig").Node;
pub const NodeId = @import("node.zig").NodeId;
pub const NodeType = @import("node.zig").NodeType;

pub const common = @import("spa_api_common.zig");

const checkNodeType = common.checkNodeType;

pub const CommonError = @import("spa_api_common.zig").Error;
pub const STATEMENT_UNDEFINED = @import("spa_api_common.zig").STATEMENT_UNDEFINED;
pub const STATEMENT_SELECTED = @import("spa_api_common.zig").STATEMENT_SELECTED;

const Pkb = @import("Pkb.zig");

pub fn ParentApi(comptime ResultIntType: type) type { return struct {

const Self = @This();

fn findInStmtListBinary(pkb: *Pkb, children_slice: []const Node, s_id: u32, s_type: NodeType, s_value: ?[]const u8) bool {
    const child_index = children_slice.len/2;
    if (children_slice.len == 0) {
        return false;
    }
    if (children_slice.len == 1) {
        return 
            children_slice[child_index].metadata.statement_id == s_id and
            checkNodeType(children_slice[child_index].type, s_type) and
            pkb.ast.checkValue(children_slice[child_index], s_value);
    }

    // don't have to perform the `children_slice[child_index].metadata.s_id == 0` check
    // since children of s list can't be PROGRAM, PROCEDURE or s_LIST
     if (children_slice[child_index].metadata.statement_id < s_id) {
        return Self.findInStmtListBinary(pkb, children_slice[(child_index+1)..], s_id, s_type, s_value);        
    } else if (children_slice[child_index].metadata.statement_id > s_id) {
        return Self.findInStmtListBinary(pkb, children_slice[0..(child_index)], s_id, s_type, s_value);
    } else {
        return
            checkNodeType(children_slice[child_index].type, s_type) and
            pkb.ast.checkValue(children_slice[child_index], s_value);
    }

}
fn getWhileStmtListChildren(pkb: *Pkb, while_index: usize) []const Node {
    const while_node = pkb.ast.nodes[while_index];
    const container = pkb.ast.nodes[while_node.children_index_or_lhs_child_index + 1];
    const children_begin = container.children_index_or_lhs_child_index;
    const children_end = container.children_index_or_lhs_child_index + container.children_count_or_rhs_child_index;
    return pkb.ast.nodes[children_begin..children_end];
}
fn getIfElseStmtListChildren(pkb: *Pkb, if_index: usize) []const Node {
    const if_node = pkb.ast.nodes[if_index];
    const if_s_list = pkb.ast.nodes[if_node.children_index_or_lhs_child_index + 1];
    const else_s_list = pkb.ast.nodes[if_node.children_index_or_lhs_child_index + 2];
    const children_begin = if_s_list.children_index_or_lhs_child_index;
    const children_end = 
        else_s_list.children_index_or_lhs_child_index + 
        else_s_list.children_count_or_rhs_child_index;
    return pkb.ast.nodes[children_begin..children_end];
}

fn parentModeSelChildUndefParent(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    var written: u32 = 0;
    for (pkb.ast.statement_map[1..]) |s_child_index| {
        const s_child_node = pkb.ast.nodes[s_child_index];
        if (checkNodeType(s_child_node.type, s_child_type) and pkb.ast.checkValue(s_child_node, s_child_value)) {
            const stmt_list_index = s_child_node.parent_index;
            const stmt_list_node = pkb.ast.nodes[stmt_list_index];
            const parent_index = stmt_list_node.parent_index;    
            const parent_node = pkb.ast.nodes[parent_index];
            if (parent_node.type == s_parent_type and pkb.ast.checkValue(parent_node, s_parent_value)) {
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_child_index)), .little);
                written += 1;
            }
        }
    }
    return written;
}
fn parentModeSelParentUndefChild(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    var written: u32 = 0;
    for (pkb.ast.statement_map[1..]) |s_parent_index| {
        const s_parent_node = pkb.ast.nodes[s_parent_index];
        if (s_parent_node.type == s_parent_type and pkb.ast.checkValue(s_parent_node, s_parent_value)) {
            const children_slice = if (s_parent_type == .WHILE)
                    Self.getWhileStmtListChildren(pkb, s_parent_index)
                else
                    Self.getIfElseStmtListChildren(pkb, s_parent_index);

            for (children_slice) |child_node| {
                if(checkNodeType(child_node.type, s_child_type) and pkb.ast.checkValue(child_node, s_child_value)) {
                    try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_parent_index)), .little);
                    written += 1;
                    break;
                }
            }
        }
    }
    return written;
}
fn parentModeSelParentDefChild(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child: u32, s_child_value: ?[]const u8,
) !u32 {
    const s_child_index = pkb.ast.findStatement(s_child);
    const s_child_node = pkb.ast.nodes[s_child_index];
    if (s_child_index == 0 or s_child_node.type != s_child_type or !pkb.ast.checkValue(s_child_node, s_child_value)) {
        return 0;
    }
    const stmt_list_index = s_child_node.parent_index;
    const stmt_list_node = pkb.ast.nodes[stmt_list_index];
    const parent_index = stmt_list_node.parent_index;
    const parent_node = pkb.ast.nodes[parent_index];
    if (parent_node.type == s_parent_type and pkb.ast.checkValue(parent_node, s_parent_value)) {
        try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(parent_index)), .little);
        return 1;
    }
    return 0;
}
fn parentModeSelChildDefParent(pkb: *Pkb, 
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent: u32, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    const s_parent_index = pkb.ast.findStatement(s_parent);
    const s_parent_node = pkb.ast.nodes[s_parent_index];
    if (s_parent_index == 0 or s_parent_node.type != s_parent_type or !pkb.ast.checkValue(s_parent_node, s_parent_value)) {
        return 0;
    }
    const children_index = pkb.ast.nodes[s_parent_node.children_index_or_lhs_child_index + 1].children_index_or_lhs_child_index;
    const children_slice = if (s_parent_type == .WHILE)
            Self.getWhileStmtListChildren(pkb, s_parent_index)
        else
            Self.getIfElseStmtListChildren(pkb, s_parent_index);
    var written: u32 = 0;
    for (children_slice, children_index..) |child_node, i| {
        if (checkNodeType(child_node.type, s_child_type) and pkb.ast.checkValue(child_node, s_child_value)) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(i)), .little);
            written += 1;
        }
    }
    return written;
}

fn parentModeDef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent: u32, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child: u32, s_child_value: ?[]const u8,
) !u32 {
    const s_parent_index = pkb.ast.findStatement(s_parent);
    const s_parent_node = pkb.ast.nodes[s_parent_index];
    if (s_parent_index == 0 or (s_parent_node.type != s_parent_type and s_parent_type != .NONE) or !pkb.ast.checkValue(s_parent_node, s_parent_value)) {
        return 0;
    }
    if (s_parent_node.type == .WHILE) {
        if (Self.findInStmtListBinary(pkb, Self.getWhileStmtListChildren(pkb, s_parent_index), s_child, s_child_type, s_child_value)) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
            return 1;
        }
    } else if (s_parent_node.type == .IF) {
        if (Self.findInStmtListBinary(pkb, Self.getIfElseStmtListChildren(pkb, s_parent_index), s_child, s_child_type, s_child_value)) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
            return 1;
        }
    }
    return 0;
}


pub fn parent(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (pkb.ast.statement_map.len < 2 or s1 == s2 or (s1_type != .IF and s1_type != .WHILE and s1_type != .NONE)) {
        return 0;
    }
    // both undefined
    if (common.isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try Self.parentModeSelParentUndefChild(pkb, result_writer, s1_type, s1_value, s2_type, s2_value)
            else 
                try Self.parentModeSelChildUndefParent(pkb, result_writer, s1_type, s1_value, s2_type, s2_value);
    // one of the statements defined
    } else if (common.isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try Self.parentModeSelParentDefChild(pkb, result_writer, s1_type, s1_value, s2_type, s2, s2_value)
            else 
                try Self.parentModeSelChildDefParent(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2_value);
    // both statements defined
    } else if (common.isModeDef(s1, s2)) {
        return try Self.parentModeDef(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}


// TODO revise if checking for value in case of parent will ever
// be needed

fn parentTransitiveModeSelChildUndefParent(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    var written: u32 = 0;
    for (pkb.ast.statement_map[1..]) |s_child_index| {
        const s_child_node = pkb.ast.nodes[s_child_index];
        if (checkNodeType(s_child_node.type, s_child_type) and pkb.ast.checkValue(s_child_node, s_child_value)) {
            var parent_index = s_child_node.parent_index;
            while (parent_index != 0) {
                const parent_node = pkb.ast.nodes[parent_index];
                if (parent_node.type == s_parent_type and pkb.ast.checkValue(parent_node, s_parent_value)) {
                    written += 1;
                    try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_child_index)), .little);
                    break;
                }
                parent_index = pkb.ast.nodes[parent_index].parent_index;
            }
        }
    }
    return written;
}

fn parentTransitiveModeSelParentUndefChildInternal(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    written: *u32,
    s_parent_type: NodeType, s_parent_index: usize, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !usize {
    const s_parent_node = pkb.ast.nodes[s_parent_index];
    const children_index = pkb.ast.nodes[s_parent_node.children_index_or_lhs_child_index + 1].children_index_or_lhs_child_index;
    const children_slice = if (s_parent_type == .WHILE)
            Self.getWhileStmtListChildren(pkb, s_parent_index)
        else
            Self.getIfElseStmtListChildren(pkb, s_parent_index);
    for (children_slice, children_index..) |child_node, child_index| {
        if(checkNodeType(child_node.type, s_child_type) and pkb.ast.checkValue(child_node, s_child_value)) {
            if (s_parent_node.type == s_parent_type and pkb.ast.checkValue(s_parent_node, s_parent_value)) {
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_parent_index)), .little);
                written.* += 1;
            }
            return child_node.metadata.statement_id;
        } else if (child_node.type == .WHILE or child_node.type == .IF) {
            return try Self.parentTransitiveModeSelParentUndefChildInternal(pkb,
                result_writer, written,
                s_parent_type, child_index, s_parent_value,
                s_child_type, s_child_value,
            );
        }
    }
    return 0;
}
fn parentTransitiveModeSelParentUndefChild(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    var written: u32 = 0;
    var s_parent: usize = 1;
    while (s_parent < pkb.ast.statement_map.len) : (s_parent += 1) {
        const s_parent_index = pkb.ast.statement_map[s_parent];
        const s_parent_node = pkb.ast.nodes[s_parent_index];
        if (s_parent_index != 0 and s_parent_node.type == s_parent_type and pkb.ast.checkValue(s_parent_node, s_parent_value)) {
            const children_index = pkb.ast.nodes[s_parent_node.children_index_or_lhs_child_index + 1].children_index_or_lhs_child_index;
            const children_slice = if (s_parent_type == .WHILE)
                    Self.getWhileStmtListChildren(pkb, s_parent_index)
                else
                    Self.getIfElseStmtListChildren(pkb, s_parent_index);
            for (children_slice, children_index..) |child_node, child_index| {
                if(checkNodeType(child_node.type, s_child_type) and pkb.ast.checkValue(child_node, s_child_value)) {
                    try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_parent_index)), .little);
                    written += 1;
                    break;
                } else if (child_node.type == .WHILE or child_node.type == .IF) {
                    const s = try Self.parentTransitiveModeSelParentUndefChildInternal(pkb,
                        result_writer, &written,
                        s_parent_type, child_index, s_parent_value,
                        s_child_type, s_child_value,
                    );
                    if (s != 0) {
                        s_parent = s;
                        try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(s_parent_index)), .little);

                        written += 1;
                        break;
                    }
                }
            }
        }
    }
    return written;
}

fn parentTransitiveModeSelParentDefChild(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child: u32, s_child_value: ?[]const u8,
) !u32 {
    const s_child_index = pkb.ast.findStatement(s_child);
    const s_child_node = pkb.ast.nodes[s_child_index];
    if (s_child_index == 0 or !checkNodeType(s_child_node.type, s_child_type) or !pkb.ast.checkValue(s_child_node, s_child_value)) {
        return 0;
    }
    var parent_index = s_child_node.parent_index;
    var written: u32 = 0;
    while (parent_index != 0) {
        const parent_node = pkb.ast.nodes[parent_index];
        if (parent_node.type == s_parent_type and pkb.ast.checkValue(parent_node, s_parent_value)) {
            written += 1;
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, parent_index), .little);
        }
        parent_index = pkb.ast.nodes[parent_index].parent_index;
    }
    return written;
}

fn parentTransitiveModeSelChildDefParentInternal(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_index: usize,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    const s_parent_node = pkb.ast.nodes[s_parent_index];
    const children_index = pkb.ast.nodes[s_parent_node.children_index_or_lhs_child_index + 1].children_index_or_lhs_child_index;
    const children_slice = if (s_parent_node.type == .WHILE) 
            Self.getWhileStmtListChildren(pkb, s_parent_index)
        else
            Self.getIfElseStmtListChildren(pkb, s_parent_index);
    var written: u32 = 0;
    for (children_slice, children_index..) |child_node, child_index| {
        if (child_node.type == .WHILE or child_node.type == .IF) {
            if (checkNodeType(child_node.type, s_child_type) and pkb.ast.checkValue(child_node, s_child_value)) {
                try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(child_index)), .little);
                written += 1;
            }
            written += try Self.parentTransitiveModeSelChildDefParentInternal(pkb, result_writer, child_index, s_child_type, s_child_value);
        } else if (checkNodeType(child_node.type, s_child_type) and pkb.ast.checkValue(child_node, s_child_value)) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, @intCast(child_index)), .little);
            written += 1;
        } 
    }
    return written;
}

fn parentTransitiveModeSelChildDefParent(pkb: *Pkb, 
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent: u32, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    const s_parent_index = pkb.ast.findStatement(s_parent);
    const s_parent_node = pkb.ast.nodes[s_parent_index];
    if (s_parent_index == 0 or s_parent_node.type != s_parent_type or !pkb.ast.checkValue(s_parent_node, s_parent_value)) {
        return 0;
    }
    return try Self.parentTransitiveModeSelChildDefParentInternal(pkb, result_writer, s_parent_index, s_child_type, s_child_value);
}

fn parentTransitiveModeDef(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent: u32, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child: u32, s_child_value: ?[]const u8,
) !u32 {
    const s_parent_index = pkb.ast.findStatement(s_parent);
    const s_parent_node = pkb.ast.nodes[s_parent_index];
    if (s_parent_index == 0 or !checkNodeType(s_parent_node.type, s_parent_type) or !pkb.ast.checkValue(s_parent_node, s_parent_value)) {
        return 0;
    }
    const s_child_index = pkb.ast.findStatement(s_child);
    const s_child_node = pkb.ast.nodes[s_child_index];
    if (s_child_index == 0 or !checkNodeType(s_child_node.type, s_child_type) or !pkb.ast.checkValue(s_child_node, s_child_value)) {
        return 0;
    }
    var parent_index = s_child_node.parent_index;
    while (parent_index != 0) {
        if (parent_index == s_parent_index) {
            try result_writer.writeInt(ResultIntType, @as(ResultIntType, 1), .little);
            return 1;
        }
        parent_index = pkb.ast.nodes[parent_index].parent_index;
    }
    return 0;
}

pub fn parentTransitive(pkb: *Pkb,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (pkb.ast.statement_map.len < 2 or s1 == s2 or (s1_type != .NONE and s1_type != .IF and s1_type != .WHILE)) {
        return 0;
    }
    // both undefined
    if (common.isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try Self.parentTransitiveModeSelParentUndefChild(pkb, result_writer, s1_type, s1_value, s2_type, s2_value)
            else 
                try Self.parentTransitiveModeSelChildUndefParent(pkb, result_writer, s1_type, s1_value, s2_type, s2_value);
    // one of the statements defined
    } else if (common.isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try Self.parentTransitiveModeSelParentDefChild(pkb, result_writer, s1_type, s1_value, s2_type, s2, s2_value)
            else 
                try Self.parentTransitiveModeSelChildDefParent(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2_value);
    // both statements defined
    } else if (common.isModeDef(s1, s2)) {
        return try Self.parentTransitiveModeDef(pkb, result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}

};}
