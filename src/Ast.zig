const std = @import("std");

pub const Node = @import("node.zig").Node;
pub const NodeType = @import("node.zig").NodeType;

pub fn Ast(comptime ResultIntType: type) type { return struct {

const Self = @This();

pub const STATEMENT_UNDEFINED: u32 = 0xFFFFFFFF;
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
pub fn followsCheck(self: *Self,
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

pub fn getFollowingStatement(self: *Self, statement_id: u32, polarity: i32) u32 {
    const s_index = self.findStatement(statement_id);
    if (s_index == 0) {
        return 0;
    }
    const index = @as(usize, @intCast(@as(i32, @intCast(s_index)) + polarity));
    if (index < self.nodes.len) {
        return self.nodes[index].metadata.statement_id;
    }
    return 0;
}

pub fn follows(self: *Self,
    result_writer: std.io.FixedBufferStream([]u8).Writer,
    s1_type: NodeType, s1: u32,
    s2_type: NodeType, s2: u32,
) !u32 {
    var written: u32 = 0;

    if (self.statement_map.len < 2) {
        return written;
    }

    // both undefined
    if (s1 == STATEMENT_UNDEFINED or s2 == STATEMENT_UNDEFINED)  {
        const polarity: i32 = if (s1 == STATEMENT_SELECTED) 1 else -1;
        const begin: usize = if (s1 == STATEMENT_SELECTED) 1 else 2;
        const sx_type = if (s1 == STATEMENT_SELECTED) s1_type else s2_type;
        const sy_type = if (s1 == STATEMENT_SELECTED) s2_type else s1_type;
        for (begin..self.statement_map.len) |i| {
            const sx: u32 = @intCast(i);
            const sy: u32 = self.getFollowingStatement(sx, polarity);
            if (sy == 0) {
                continue;
            }
            if (self.followsCheck(sx_type, sx, sy_type, sy)) {
                try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(i)));
                written += 1;
            }
        }
    // one of the statements defined
    } else if (s1 == STATEMENT_SELECTED or s2 == STATEMENT_SELECTED) {
        const s: u32 = if (s1 == STATEMENT_SELECTED) s2 else s1;
        const polarity: i32 = if (s1 == STATEMENT_SELECTED) -1 else 1;
        const s_type: NodeType = if (s1 == STATEMENT_SELECTED) s2_type else s1_type;
        const other_type: NodeType = if (s1 == STATEMENT_SELECTED) s1_type else s2_type;

        const other_s = self.getFollowingStatement(s, polarity);
        if (other_s == 0) {
            return written;
        }
        if (self.followsCheck(s_type, s, other_type, other_s)) {
            try result_writer.writeIntLittle(ResultIntType, @as(ResultIntType, @intCast(other_s)));
            written += 1;
        }
    // both statements defined
    } else {
        const s1_index = self.findStatement(s1);
        if (s1_index == 0) {
            return written;
        }
        if (s1_index + 1 < self.nodes.len and self.nodes[s1_index + 1].metadata.statement_id == s2) {
            if (self.followsCheck(s1_type, s1, s2_type, s2)) {
                try result_writer.writeIntLittle(ResultIntType, 1);
                written += 1;
            }
        }
    }

    return written;
}

// pub fn followsParametric(self: *Self, s1: u32, s2: u32, result_writer: std.io.FixedBufferStream([]u8).Writer) void {
//     // if s1 is parametric polarity (step) is 1 else it is negative -1
//     const polarity: i32 = if (s1 == 0) -1 else 1;
//     const s_index = self.findStatement(if (s1 == 0) s2 else s1);

//     if (s_index == 0) {
//         return;
//     }
//     var i: usize = s_index + polarity;
//     // doesn't need to check for < 0 since s1 nor s2 can be 0 in this context
//     if (s_index + i < self.nodes.len and self.nodes[s_index].parent_index == self.nodes[s_index + i].parent_index) {
//         result_writer.writeIntLittle(ResultIntType, self.nodes[s_index + i].metadata.statement_id);
//     }
// }

pub fn followsTransitive(self: *Self, s1: u32, s2: u32) bool {
    const s1_index = self.findStatement(s1);
    if (s1_index == 0) {
        return false;
    }

    const s1_parent_index = self.nodes[s1_index].parent_index;

    for (self.nodes[(s1_index + 1)..]) |s2_node| {
        if (s2_node.parent_index == s1_parent_index) {
            if (s2_node.metadata.statement_id == s2) {
                return true;
            }
        } else {
            // early exit if left given parent's "children region"
            return false;
        }
    } 
    return false;
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