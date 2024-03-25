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