const std = @import("std");

pub const Node = @import("node.zig").Node;
pub const NodeType = @import("node.zig").NodeType;

pub fn Ast(comptime ResultIntType: type) type { return struct {

const Self = @This();

pub const Error = error {
    UNSUPPORTED_COMBINATION,    
};

pub const STATEMENT_UNDEFINED: u32 = 0xFF_FF_FF_FF;
pub const STATEMENT_SELECTED: u32 = 0x0;

arena_allocator: std.heap.ArenaAllocator,
nodes: []Node,
statement_map: []usize,

pub fn init(internal_allocator: std.mem.Allocator, nodes_count: usize, statements_count: u32) !*Self {
    var self = try internal_allocator.create(Self);
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
    self.nodes = try self.arena_allocator.allocator().alloc(Node, @intCast(nodes_count));
    self.statement_map = try self.arena_allocator.allocator().alloc(usize, @intCast(statements_count));
    @memset(self.statement_map, 0);
    return self;
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

fn findStatement(self: *Self, statement_id: u32) usize {
    if (statement_id < self.statement_map.len) {
        return self.statement_map[statement_id];
    }
    return 0;
}

fn checkValue(node: Node, value: ?[]const u8) bool {
    return if (value == null or node.value == null)
            true 
        else
            std.mem.eql(u8, value.?, node.value.?);
}

fn checkNodeType(node_type: NodeType, expected_node_type: NodeType) bool {
    return (node_type == expected_node_type or expected_node_type == .NONE);
}

/// follows check doesn't care about
/// which statement follows which
fn followsCheck(self: *Self,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) bool {
    if (s1 >= self.statement_map.len or s2 >= self.statement_map.len) {
        return false;
    }
    const s1_node = self.nodes[self.statement_map[s1]];
    const s2_node = self.nodes[self.statement_map[s2]];
    return
        (s1_type == .NONE or s1_node.type == s1_type) and
        (s2_type == .NONE or s2_node.type == s2_type) and
        s1_node.parent_index == s2_node.parent_index and
        checkValue(s1_node, s1_value) and checkValue(s2_node, s2_value);
}

pub fn getFollowingStatement(self: *Self, statement_id: u32, step: i32) u32 {
    const s_index = self.findStatement(statement_id);
    if (s_index == 0) {
        return 0;
    }
    const index = @as(usize, @intCast(@as(i32, @intCast(s_index)) + step));
    if (index < self.nodes.len) {
        return self.nodes[index].metadata.statement_id;
    }
    return 0;
}

fn isModeSelUndef(s1: u32, s2: u32) bool {
    return ((s1 ^ s2) == STATEMENT_UNDEFINED);
}
fn isModeSelDef(s1: u32, s2: u32) bool {
    return (((s1 | s2) != 0) and ((s1 ^ s2) == s1 or (s1 ^ s2) == s2));
}
fn isModeDef(s1: u32, s2: u32) bool {
    return (((s1 | s2) != 0) and (s1 ^ s2) != STATEMENT_UNDEFINED);
}

fn followsModeSelUndef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    s_undef_type: NodeType, s_undef_value: ?[]const u8,
    begin: usize, step: i32
) !u32 {
    var written: u32 = 0;
    for (begin..self.statement_map.len) |i| {
        const s_sel: u32 = @intCast(i);
        const s_undef: u32 = self.getFollowingStatement(s_sel, step);
        if (s_undef == 0) {
            continue;
        }
        if (self.followsCheck(s_sel_type, s_sel, s_sel_value, s_undef_type, s_undef, s_undef_value)) {
            try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(self.statement_map[i])));
            written += 1;
        }
    }
    return written;
}
fn followsModeSelDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_def: u32, s_def_type: NodeType, s_def_value: ?[]const u8,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    step: i32
) !u32 {
    const s_sel = self.getFollowingStatement(s_def, step);
    if (s_sel == 0) {
        return 0;
    }
    if (self.followsCheck(s_def_type, s_def, s_def_value, s_sel_type, s_sel, s_sel_value)) {
        try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(self.statement_map[s_sel])));
        return 1;
    }
    return 0;
}

fn followsModeDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    const s1_index = self.findStatement(s1);
    if (s1_index == 0) {
        return 0;
    }
    if (s1_index + 1 < self.nodes.len and self.nodes[s1_index + 1].metadata.statement_id == s2) {
        if (self.followsCheck(s1_type, s1, s1_value, s2_type, s2, s2_value)) {
            try result_writer.writeIntLittle(ResultIntType, 1);
            return 1;
        }
    }
    return 0;
}

pub fn follows(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (self.statement_map.len < 2 or s1 == s2) {
        return 0;
    }
    // both undefined
    if (isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsModeSelUndef(result_writer, s1_type, s1_value, s2_type, s2_value, 1, 1)
            else
                try self.followsModeSelUndef(result_writer, s2_type, s2_value, s1_type, s1_value, 2,-1);
    // one of the statements defined
    } else if (isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsModeSelDef(result_writer, s2, s2_type, s2_value, s1_type, s1_value,-1)
            else
                try self.followsModeSelDef(result_writer, s1, s1_type, s1_value, s2_type, s2_value, 1);
    // both statements defined
    } else if (isModeDef(s1, s2)) {
        return try self.followsModeDef(result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}

fn followsTransitiveModeSelUndef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    s_undef_type: NodeType, s_undef_value: ?[]const u8,
    begin: usize, step: i32
) !u32 {
    var written: u32 = 0;
    for (begin..self.statement_map.len) |i| {
        const s_sel_index = self.statement_map[i];
        const s_sel_node = self.nodes[s_sel_index];
        if (!checkNodeType(s_sel_node.type, s_sel_type) or !checkValue(s_sel_node, s_sel_value)) {
            continue;            
        }
        
        var s_undef_index = @as(i32, @intCast(s_sel_index)) + step;
        while (s_undef_index < self.nodes.len and s_undef_index > 0) : (s_undef_index += step) {
            const s_undef_node = self.nodes[@intCast(s_undef_index)];
            if (s_undef_node.parent_index == s_sel_node.parent_index) {
                if (checkNodeType(s_undef_node.type, s_undef_type) and checkValue(s_undef_node, s_undef_value)) {
                    try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(s_sel_index)));
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

fn followsTransitiveModeSelDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_def_type: NodeType, s_def: u32, s_def_value: ?[]const u8,
    s_sel_type: NodeType, s_sel_value: ?[]const u8,
    step: i32
) !u32 {
    const s_def_index = self.findStatement(s_def);
    const s_def_node = self.nodes[s_def_index];
    if (s_def_index == 0 or !checkNodeType(s_def_node.type, s_def_type) or !checkValue(s_def_node, s_def_value)) {
        return 0;
    }
    const s_def_parent_index = self.nodes[s_def_index].parent_index; 
    var s_sel_index: i32 = @as(i32, @intCast(s_def_index)) + step;
    var written: u32 = 0;
    while (s_sel_index < self.nodes.len and s_sel_index > 0) : (s_sel_index += step) {
        const s_sel_node = self.nodes[@intCast(s_sel_index)];
        if (s_sel_node.parent_index == s_def_parent_index) {
            if (checkNodeType(s_sel_node.type, s_sel_type) and checkValue(s_sel_node, s_sel_value)) {
                try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(s_sel_index)));
                written += 1;
            }
        } else {
            break;
        }
    }
    return written;
}

fn followsTransitiveModeDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    const s1_index = self.findStatement(s1);
    const s1_node = self.nodes[s1_index];
    if (s1_index == 0 or !checkNodeType(s1_node.type, s1_type) or !checkValue(s1_node, s1_value)) {
        return 0;
    }
    const s1_parent_index = s1_node.parent_index; 
    for (self.nodes[(s1_index + 1)..]) |s2_node| {
        if (s2_node.parent_index == s1_parent_index) {
            if (s2_node.metadata.statement_id == s2 and checkNodeType(s2_node.type, s2_type) and checkValue(s2_node, s2_value)) {
                try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, 1));
                return 1;
            }
        } else {
            return 0;
        }
    }
    return 0;
}

pub fn followsTransitive(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (self.statement_map.len < 2 or s1 == s2) {
        return 0;
    }
    // both undefined
    if (isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsTransitiveModeSelUndef(result_writer, s1_type, s1_value, s2_type, s2_value, 1, 1)
            else
                try self.followsTransitiveModeSelUndef(result_writer, s2_type, s2_value, s1_type, s1_value, 2, -1);
    // one of the statements defined
    } else if (isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsTransitiveModeSelDef(result_writer, s2_type, s2, s2_value, s1_type, s1_value, -1)
            else
                try self.followsTransitiveModeSelDef(result_writer, s1_type, s1, s1_value, s2_type, s2_value, 1);
    // both statements defined
    } else if (isModeDef(s1, s2)) {
        return try self.followsTransitiveModeDef(result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}


fn findInStmtListBinary(children_slice: []const Node, s_id: u32, s_type: NodeType, s_value: ?[]const u8) bool {
    const child_index = children_slice.len/2;
    if (children_slice.len == 0) {
        return false;
    }
    if (children_slice.len == 1) {
        return 
            children_slice[child_index].metadata.statement_id == s_id and
            checkNodeType(children_slice[child_index].type, s_type) and
            checkValue(children_slice[child_index], s_value);
    }

    // don't have to perform the `children_slice[child_index].metadata.s_id == 0` check
    // since children of s list can't be PROGRAM, PROCEDURE or s_LIST
     if (children_slice[child_index].metadata.statement_id < s_id) {
        return findInStmtListBinary(children_slice[(child_index+1)..], s_id, s_type, s_value);        
    } else if (children_slice[child_index].metadata.statement_id > s_id) {
        return findInStmtListBinary(children_slice[0..(child_index)], s_id, s_type, s_value);
    } else {
        return
            checkNodeType(children_slice[child_index].type, s_type) and
            checkValue(children_slice[child_index], s_value);
    }

}
fn getStmtListChildren(self: *Self, s_list_index: usize) []const Node {
    const container = self.nodes[s_list_index];
    const children_begin = container.children_index_or_lhs_child_index;
    const children_end = container.children_index_or_lhs_child_index + container.children_count_or_rhs_child_index;
    return self.nodes[children_begin..children_end];
}
fn getIfElseStmtListChildren(self: *Self, if_index: usize) []const Node {
    const if_node = self.nodes[if_index];
    const if_s_list = self.nodes[if_node.children_index_or_lhs_child_index + 1];
    const else_s_list = self.nodes[if_node.children_index_or_lhs_child_index + 3];
    const children_begin = if_s_list.children_index_or_lhs_child_index;
    const children_end = 
        else_s_list.children_index_or_lhs_child_index + 
        else_s_list.children_count_or_rhs_child_index;
    return self.nodes[children_begin..children_end];
}

fn parentModeSelChildUndefParent(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    var written: u32 = 0;
    for (self.statement_map[1..]) |s_child_index| {
        const s_child_node = self.nodes[s_child_index];
        if (checkNodeType(s_child_node.type, s_child_type) and checkValue(s_child_node, s_child_value)) {
            const stmt_list_index = s_child_node.parent_index;
            const stmt_list_node = self.nodes[stmt_list_index];
            const parent_index = stmt_list_node.parent_index;    
            const parent_node = self.nodes[parent_index];
            if (parent_node.type == s_parent_type and checkValue(parent_node, s_parent_value)) {
                try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(s_child_index)));
                written += 1;
            }
        }
    }
    return written;
}
fn parentModeSelParentUndefChild(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    var written: u32 = 0;
    for (self.statement_map[1..]) |s_parent_index| {
        const s_parent_node = self.nodes[s_parent_index];
        if (s_parent_node.type == s_parent_type and checkValue(s_parent_node, s_parent_value)) {
            const children_slice = if (s_parent_type == .WHILE)
                    self.getStmtListChildren(s_parent_node.children_index_or_lhs_child_index + 1)
                else
                    self.getIfElseStmtListChildren(s_parent_index);

            for (children_slice) |child_node| {
                if(checkNodeType(child_node.type, s_child_type) and checkValue(child_node, s_child_value)) {
                    try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(s_parent_index)));
                    written += 1;
                    break;
                }
            }
        }
    }
    return written;
}
fn parentModeSelParentDefChild(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_child_type: NodeType, s_child: u32, s_child_value: ?[]const u8,
    s_parent_type: NodeType, s_parent_value: ?[]const u8,
) !u32 {
    const s_child_index = self.findStatement(s_child);
    const s_child_node = self.nodes[s_child_index];
    if (s_child_index == 0 or s_child_node.type != s_child_type or !checkValue(s_child_node, s_child_value)) {
        return 0;
    }
    const stmt_list_index = s_child_node.parent_index;
    const stmt_list_node = self.nodes[stmt_list_index];
    const parent_index = stmt_list_node.parent_index;
    const parent_node = self.nodes[parent_index];
    if (parent_node.type == s_parent_type and checkValue(parent_node, s_parent_value)) {
        try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(parent_index)));
        return 1;
    }
    return 0;
}
fn parentModeSelChildDefParent(self: *Self, 
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_parent_type: NodeType, s_parent: u32, s_parent_value: ?[]const u8,
    s_child_type: NodeType, s_child_value: ?[]const u8,
) !u32 {
    const s_parent_index = self.findStatement(s_parent);
    const s_parent_node = self.nodes[s_parent_index];
    if (s_parent_index == 0 or s_parent_node.type != s_parent_type or !checkValue(s_parent_node, s_parent_value)) {
        return 0;
    }
    const children_index = self.nodes[s_parent_node.children_index_or_lhs_child_index + 1].children_index_or_lhs_child_index;
    const children_slice = if (s_parent_type == .WHILE)
            self.getStmtListChildren(s_parent_node.children_index_or_lhs_child_index + 1)
        else
            self.getIfElseStmtListChildren(s_parent_index);
    var written: u32 = 0;
    for (children_slice, children_index..) |child_node, i| {
        if (checkNodeType(child_node.type, s_child_type) and checkValue(child_node, s_child_value)) {
            try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(i)));
            written += 1;
        }
    }
    return written;
}

fn parentModeDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    const s1_index = self.findStatement(s1);
    const s1_node = self.nodes[s1_index];
    if (s1_index == 0 or s1_node.type != s1_type or !checkValue(s1_node, s1_value)) {
        return 0;
    }
    if (s1_node.type == .WHILE) {
        // second child of `while` is stmt list
        if (findInStmtListBinary(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2, s2_type, s2_value)) {
            try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, 1));
            return 1;
        }
    } else if (s1_node.type == .IF) {
        if (findInStmtListBinary(self.getIfElseStmtListChildren(s1_index), s2, s2_type, s2_value)) {
            try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, 1));
            return 1;
        }
    }
    return 0;
}


pub fn parent(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32, s1_value: ?[]const u8,
    s2_type: NodeType, s2: u32, s2_value: ?[]const u8,
) !u32 {
    if (self.statement_map.len < 2 or s1 == s2 or (s1_type != .IF and s1_type != .WHILE)) {
        return 0;
    }
    // both undefined
    if (isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try self.parentModeSelParentUndefChild(result_writer, s1_type, s1_value, s2_type, s2_value)
            else 
                try self.parentModeSelChildUndefParent(result_writer, s1_type, s1_value, s2_type, s2_value);
    // one of the statements defined
    } else if (isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try self.parentModeSelParentDefChild(result_writer, s2_type, s2, s2_value, s1_type, s1_value)
            else 
                try self.parentModeSelChildDefParent(result_writer, s1_type, s1, s1_value, s2_type, s2_value);
    // both statements defined
    } else if (isModeDef(s1, s2)) {
        return try self.parentModeDef(result_writer, s1_type, s1, s1_value, s2_type, s2, s2_value);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}
//fn parentTransitiveInternal(self: *Self, children_nodes: []const Node, s2: u32) bool {
//    // we can omit check if nodes len is 0 because 
//    // containers must contain at least one statement
//    for (children_nodes) |s2_node| {
//        if (s2_node.metadata.statement_id == s2) {
//            return true;
//        } else if (s2_node.type == .WHILE) {
//            return
//                self.parentTransitiveInternal(self.getStmtListChildren(s2_node.children_index_or_lhs_child_index + 1), s2);
//        } else if (s2_node.type == .IF) {
//            return
//                self.parentTransitiveInternal(self.getStmtListChildren(s2_node.children_index_or_lhs_child_index + 1), s2) or
//                self.parentTransitiveInternal(self.getStmtListChildren(s2_node.children_index_or_lhs_child_index + 2), s2);
//        }
//    }
//    return false;
//} 
//pub fn parentTransitive(self: *Self, s1: u32, s2: u32) bool {
//    for (self.nodes) |s1_node| {
//        if (s1_node.metadata.statement_id == s1) {
//            if (s1_node.type == .WHILE) {
//                // second child of `while` is stmt list
//                return self.parentTransitiveInternal(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2);
//            } else if (s1_node.type == .IF) {
//                return 
//                    // second child of `if` is stmt list
//                    self.parentTransitiveInternal(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2) or
//                    // third child of `if` is stmt list
//                    self.parentTransitiveInternal(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 2), s2);
//            } else {
//                return false;
//            }
//        }
//    }
//    return false;
//}

};}
