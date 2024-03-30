const std = @import("std");

pub const Node = @import("node.zig").Node;

const Self = @This();

arena_allocator: std.heap.ArenaAllocator,
nodes: []Node,

pub fn init(internal_allocator: std.mem.Allocator, nodes_count: usize) !*Self {
    var self = try internal_allocator.create(Self);
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
    self.nodes = try self.arena_allocator.allocator().alloc(Node, @intCast(nodes_count));
    return self;
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

pub fn follows(self: *Self, s1: u32, s2: u32) bool {
    var s1_index: usize = for (self.nodes, 0..) |s1_node, i| {
        if (s1_node.metadata.statement_id == s1) {
            break i;
        }
    } else 0;

    if (s1_index == 0) {
        return false;
    }

    if (s1_index + 1 < self.nodes.len and self.nodes[s1_index].parent_index == self.nodes[s1_index + 1].parent_index) {
        return (self.nodes[s1_index + 1].metadata.statement_id == s2);
    }
    return false;
}

pub fn followsTransitive(self: *Self, s1: u32, s2: u32) bool {
    var s1_index: usize = for (self.nodes, 0..) |s1_node, i| {
        if (s1_node.metadata.statement_id == s1) {
            break i;
        }
    } else 0;

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


fn findInStmtListBinary(self: *Self, children_slice: []Node, statement_id: u32) bool {
    const child_index = children_slice.len/2;

    if (children_slice.len == 1) {
        return children_slice[child_index].metadata.statement_id == statement_id;
    }

    // don't have to perform the `children_slice[child_index].metadata.statement_id == 0` check
    // since children of statement list can't be PROGRAM, PROCEDURE or STMT_LIST
     if (children_slice[child_index].metadata.statement_id < statement_id) {
        return self.findInStmtListBinary(children_slice[(child_index+1)..], statement_id);
    } else if (children_slice[child_index].metadata.statement_id > statement_id) {
        return self.findInStmtListBinary(children_slice[0..(child_index)], statement_id);
    } else {
        return true;
    }

}
fn findInStmtList(self: *Self, stmt_list_index: usize, statement_id: u32) bool {
    const container = self.nodes[stmt_list_index];
    const children_begin = container.children_index_or_lhs_child_index;
    const children_end = container.children_index_or_lhs_child_index + container.children_count_or_rhs_child_index;
    return self.findInStmtListBinary(self.nodes[children_begin..children_end], statement_id);
}

pub fn parent(self: *Self, s1: u32, s2: u32) bool {
    for (self.nodes) |s1_node| {
        if (s1_node.metadata.statement_id == s1) {
            if (s1_node.type == .WHILE) {
                // second child of `while` is stmt list
                return self.findInStmtList(s1_node.children_index_or_lhs_child_index + 1, s2);
            } else if (s1_node.type == .IF) {
                return 
                    // second child of `if` is stmt list
                    self.findInStmtList(s1_node.children_index_or_lhs_child_index + 1, s2) or 
                    // third child of `if` is stmt list
                    self.findInStmtList(s1_node.children_index_or_lhs_child_index + 2, s2);
            } else {
                return false;
            }
        }
    }
    return false;
}