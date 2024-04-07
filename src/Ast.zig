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

/// follows check doesn't care about
/// which statement follows which
fn followsCheck(self: *Self,
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
) bool {
    if (s1 >= self.statement_map.len or s2 >= self.statement_map.len) {
        return false;
    }
    const s1_node = self.nodes[self.statement_map[s1]];
    const s2_node = self.nodes[self.statement_map[s2]];
    return
        (s1_type == .NONE or s1_node.type == s1_type) and
        (s2_type == .NONE or s2_node.type == s2_type) and
        s1_node.parent_index == s2_node.parent_index;
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
    s_sel_type: NodeType, s_undef_type: NodeType,
    begin: usize, step: i32
) !u32 {
    var written: u32 = 0;
    for (begin..self.statement_map.len) |i| {
        const s_sel: u32 = @intCast(i);
        const s_undef: u32 = self.getFollowingStatement(s_sel, step);
        if (s_undef == 0) {
            continue;
        }
        if (self.followsCheck(s_sel_type, s_sel, s_undef_type, s_undef)) {
            try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(self.statement_map[i])));
            written += 1;
        }
    }
    return written;
}
fn followsModeSelDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_def: u32, s_def_type: NodeType, s_sel_type: NodeType,
    step: i32
) !u32 {
    const s_sel = self.getFollowingStatement(s_def, step);
    if (s_sel == 0) {
        return 0;
    }
    if (self.followsCheck(s_def_type, s_def, s_sel_type, s_sel)) {
        try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(self.statement_map[s_sel])));
        return 1;
    }
    return 0;
}

fn followsModeDef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
) !u32 {
    const s1_index = self.findStatement(s1);
    if (s1_index == 0) {
        return 0;
    }
    if (s1_index + 1 < self.nodes.len and self.nodes[s1_index + 1].metadata.statement_id == s2) {
        if (self.followsCheck(s1_type, s1, s2_type, s2)) {
            try result_writer.writeIntLittle(ResultIntType, 1);
            return 1;
        }
    }
    return 0;
}

pub fn follows(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
) !u32 {
    if (self.statement_map.len < 2 or s1 == s2) {
        return 0;
    }
    // both undefined
    if (isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsModeSelUndef(result_writer, s1_type, s2_type, 1, 1)
            else
                try self.followsModeSelUndef(result_writer, s2_type, s1_type, 2, -1);
    // one of the statements defined
    } else if (isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsModeSelDef(result_writer, s2, s2_type, s1_type, -1)
            else
                try self.followsModeSelDef(result_writer, s1, s1_type, s2_type, 1);
    // both statements defined
    } else if (isModeDef(s1, s2)) {
        return try self.followsModeDef(result_writer, s1_type, s1, s2_type, s2);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}

fn followsTransitiveModeSelUndef(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s_sel_type: NodeType, s_undef_type: NodeType,
    begin: usize, step: i32
) !u32 {
    var written: u32 = 0;
    for (begin..self.statement_map.len) |i| {
        const s_sel_index = self.statement_map[i];
        const s_sel_node = self.nodes[s_sel_index];
        if (s_sel_node.type != s_sel_type and s_sel_type != .NONE) {
            continue;            
        }
        
        var s_undef_index = @as(i32, @intCast(s_sel_index)) + step;
        while (s_undef_index < self.nodes.len and s_undef_index > 0) : (s_undef_index += step) {
            const s_undef_node = self.nodes[@intCast(s_undef_index)];
            if (s_undef_node.parent_index == s_sel_node.parent_index) {
                if (s_undef_node.type == s_undef_type or s_undef_type == .NONE) {
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
    s_def: u32, s_def_type: NodeType, s_sel_type: NodeType,
    step: i32
) !u32 {
    const s_def_index = self.findStatement(s_def);
    if (s_def_index == 0 or self.nodes[s_def_index].type != s_def_type) {
        return 0;
    }
    const s_def_parent_index = self.nodes[s_def_index].parent_index; 
    var s_sel_index: i32 = @as(i32, @intCast(s_def_index)) + step;
    var written: u32 = 0;
    while (s_sel_index < self.nodes.len and s_sel_index > 0) : (s_sel_index += step) {
        const s_sel_node = self.nodes[@intCast(s_sel_index)];
        if (s_sel_node.parent_index == s_def_parent_index) {
            if (s_sel_type == .NONE or s_sel_node.type == s_sel_type) {
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
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
) !u32 {
    const s1_index = self.findStatement(s1);
    if (s1_index == 0 or (self.nodes[s1_index].type != s1_type and s1_type != .NONE)) {
        return 0;
    }
    const s1_parent_index = self.nodes[s1_index].parent_index; 
    for (self.nodes[(s1_index + 1)..]) |s2_node| {
        if (s2_node.parent_index == s1_parent_index) {
            if (s2_node.metadata.statement_id == s2 and 
                (s2_node.type == s2_type or s2_type == .NONE)) {
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
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
) !u32 {
    if (self.statement_map.len < 2 or s1 == s2) {
        return 0;
    }
    // both undefined
    if (isModeSelUndef(s1, s2))  {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsTransitiveModeSelUndef(result_writer, s1_type, s2_type, 1, 1)
            else
                try self.followsTransitiveModeSelUndef(result_writer, s2_type, s1_type, 2, -1);
    // one of the statements defined
    } else if (isModeSelDef(s1, s2)) {
        return if (s1 == STATEMENT_SELECTED)
                try self.followsTransitiveModeSelDef(result_writer, s2, s2_type, s1_type, -1)
            else
                try self.followsTransitiveModeSelDef(result_writer, s1, s1_type, s2_type, 1);
    // both statements defined
    } else if (isModeDef(s1, s2)) {
        return try self.followsTransitiveModeDef(result_writer, s1_type, s1, s2_type, s2);
    } else {
        return error.UNSUPPORTED_COMBINATION;
    }
    return 0;
}


fn findInStmtListBinary(children_slice: []const Node, statement_id: u32) bool {
    const child_index = children_slice.len/2;
    if (children_slice.len == 0) {
        return false;
    }
    if (children_slice.len == 1) {
        return children_slice[child_index].metadata.statement_id == statement_id;
    }

    // don't have to perform the `children_slice[child_index].metadata.statement_id == 0` check
    // since children of statement list can't be PROGRAM, PROCEDURE or STMT_LIST
     if (children_slice[child_index].metadata.statement_id < statement_id) {
        return findInStmtListBinary(children_slice[(child_index+1)..], statement_id);        
    } else if (children_slice[child_index].metadata.statement_id > statement_id) {
        return findInStmtListBinary(children_slice[0..(child_index)], statement_id);
    } else {
        return true;
    }

}
fn getStmtListChildren(self: *Self, stmt_list_index: usize) []const Node {
    const container = self.nodes[stmt_list_index];
    const children_begin = container.children_index_or_lhs_child_index;
    const children_end = container.children_index_or_lhs_child_index + container.children_count_or_rhs_child_index;
    return self.nodes[children_begin..children_end];
}

pub fn parent(self: *Self, s1: u32, s2: u32) bool {
    for (self.nodes) |s1_node| {
        if (s1_node.metadata.statement_id == s1) {
            if (s1_node.type == .WHILE) {
                // second child of `while` is stmt list
                return findInStmtListBinary(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2);
            } else if (s1_node.type == .IF) {
                return 
                    // second child of `if` is stmt list
                    findInStmtListBinary(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2) or 
                    // third child of `if` is stmt list
                    findInStmtListBinary(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 2), s2);
            } else {
                return false;
            }
        }
    }
    return false;
}
fn parentTransitiveInternal(self: *Self, children_nodes: []const Node, s2: u32) bool {
    // we can omit check if nodes len is 0 because 
    // containers must contain at least one statement
    for (children_nodes) |s2_node| {
        if (s2_node.metadata.statement_id == s2) {
            return true;
        } else if (s2_node.type == .WHILE) {
            return
                self.parentTransitiveInternal(self.getStmtListChildren(s2_node.children_index_or_lhs_child_index + 1), s2);
        } else if (s2_node.type == .IF) {
            return
                self.parentTransitiveInternal(self.getStmtListChildren(s2_node.children_index_or_lhs_child_index + 1), s2) or
                self.parentTransitiveInternal(self.getStmtListChildren(s2_node.children_index_or_lhs_child_index + 2), s2);
        }
    }
    return false;
} 
pub fn parentTransitive(self: *Self, s1: u32, s2: u32) bool {
    for (self.nodes) |s1_node| {
        if (s1_node.metadata.statement_id == s1) {
            if (s1_node.type == .WHILE) {
                // second child of `while` is stmt list
                return self.parentTransitiveInternal(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2);
            } else if (s1_node.type == .IF) {
                return 
                    // second child of `if` is stmt list
                    self.parentTransitiveInternal(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 1), s2) or
                    // third child of `if` is stmt list
                    self.parentTransitiveInternal(self.getStmtListChildren(s1_node.children_index_or_lhs_child_index + 2), s2);
            } else {
                return false;
            }
        }
    }
    return false;
}

};}