const std = @import("std");

pub const Node = @import("node.zig").Node;
pub const NodeId = @import("node.zig").NodeId;
pub const NodeType = @import("node.zig").NodeType;
pub const ProcVarTable = @import("ProcVarTable.zig");
pub const ProcMap = @import("ProcMap.zig");

const Self = @This();

arena_allocator: std.heap.ArenaAllocator,
nodes: []Node,
statement_map: []usize,

var_table: *ProcVarTable,
proc_table: *ProcVarTable,
proc_map: *ProcMap,

pub fn init(
    internal_allocator: std.mem.Allocator,
    nodes_count: usize,
    statements_count: u32,
    var_table: *ProcVarTable,
    proc_table: *ProcVarTable,
    proc_map: *ProcMap
) !*Self {
    var self = try internal_allocator.create(Self);
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
    self.nodes = try self.arena_allocator.allocator().alloc(Node, @intCast(nodes_count));
    self.statement_map = try self.arena_allocator.allocator().alloc(usize, @intCast(statements_count));
    @memset(self.statement_map, 0);
    self.var_table = var_table;
    self.proc_table = proc_table;
    self.proc_map = proc_map;
    return self;
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.var_table.deinit();
    self.proc_table.deinit();
    self.proc_map.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

pub fn buildCallsProcMap(self: *Self) void {
    for (self.nodes, 0..) |*node, i| {
        if (node.type == .CALL) {
            const parent_proc_index = self.findParentProcedure(@intCast(i));
            const parent_proc_node = self.nodes[parent_proc_index];
            self.proc_map.setCalls(parent_proc_node.value_id_or_const, node.value_id_or_const);
        }
    }
}

pub fn findParentProcedure(self: *Self, node_index: NodeId) NodeId {
    var node = self.nodes[node_index];
    var result = node_index;
    while (node.type != .PROCEDURE) {
        result = node.parent_index;
        node = self.nodes[node.parent_index];
    }
    return result;
}
pub fn findParent(self: *Self, node_index: NodeId) NodeId {
    const node = self.nodes[node_index];
    const parent_node = self.nodes[node.parent_index];
    if (parent_node.type == .STMT_LIST) {
        return parent_node.parent_index;
    } else {
        return node.parent_index;
    }
}

pub fn findStatement(self: *Self, statement_id: u32) usize {
    if (statement_id < self.statement_map.len) {
        return self.statement_map[statement_id];
    }
    return 0;
}

pub fn checkValue(self: *Self, node: Node, value: ?[]const u8) bool {
    // check value only used in parent and follows (for now)
    const node_value = if (node.type == .PROCEDURE or node.type == .CALL)
            self.proc_table.getByIndex(node.value_id_or_const)
        else
            self.var_table.getByIndex(node.value_id_or_const);
    return if (value == null or node_value == null)
            true 
        else
            std.mem.eql(u8, value.?, node_value.?);
}
