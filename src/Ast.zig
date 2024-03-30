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
        if (s1_node.metadata) |metadata| {
            if (metadata.statement_id == s1) {
                break i;
            }
        }
    } else 0;

    if (s1_index == 0) {
        return false;
    }

    if (s1_index + 1 < self.nodes.len and self.nodes[s1_index].parent_index == self.nodes[s1_index + 1].parent_index) {
        if (self.nodes[s1_index + 1].metadata) |metadata| {
            return metadata.statement_id == s2;
        }
    }
    return false;
}