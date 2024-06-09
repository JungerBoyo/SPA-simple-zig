const std = @import("std");

pub const Node = @import("node.zig").Node;
pub const NodeType = @import("node.zig").NodeType;
pub const AST = @import("Ast.zig");

const Self = @This();

pub const Error = error {
    PKB_OUT_OF_MEMORY,
};

ast: *AST,
modifies_table: []std.DynamicBitSetUnmanaged,
uses_table: []std.DynamicBitSetUnmanaged,

arena_allocator: std.heap.ArenaAllocator,

pub fn init(ast: *AST, internal_allocator: std.mem.Allocator) Error!*Self {
    var self: *Self = internal_allocator.create(Self) catch
        return error.PKB_OUT_OF_MEMORY;

    self.ast = ast;
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);

    self.modifies_table = self.arena_allocator.allocator().alloc(std.DynamicBitSetUnmanaged, self.ast.nodes.len) catch
       return error.PKB_OUT_OF_MEMORY;
    self.uses_table = self.arena_allocator.allocator().alloc(std.DynamicBitSetUnmanaged, self.ast.nodes.len) catch
       return error.PKB_OUT_OF_MEMORY;

    for (self.uses_table, self.modifies_table) |*uses_vector, *modifies_vector| {
       uses_vector.* = std.DynamicBitSetUnmanaged.initEmpty(self.arena_allocator.allocator(), self.ast.var_table.size()) catch
           return error.PKB_OUT_OF_MEMORY;
       modifies_vector.* = std.DynamicBitSetUnmanaged.initEmpty(self.arena_allocator.allocator(), self.ast.var_table.size()) catch
           return error.PKB_OUT_OF_MEMORY;
    }

    try self.build();

    return self;
}

pub fn deinit(self: *Self) void {
    self.ast.deinit();
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

fn setModifiesBit(self: *Self, node_index: usize, var_index: usize) void {
    self.modifies_table[node_index].set(var_index);
}
fn setModifiesBitVector(self: *Self, src_node_index: usize, dst_node_index: usize) void {
    self.modifies_table[dst_node_index].setUnion(self.modifies_table[src_node_index]);
}
fn getModifiesBitState(self: *Self, node_index: usize, var_index: usize) bool {
    return self.modifies_table[node_index].isSet(var_index);
}

fn setUsesBit(self: *Self, node_index: usize, var_index: usize) void {
    self.uses_table[node_index].set(var_index);
}
fn setUsesBitVector(self: *Self, src_node_index: usize, dst_node_index: usize) void {
    self.uses_table[dst_node_index].setUnion(self.uses_table[src_node_index]);
}
fn getUsesBitState(self: *Self, node_index: usize, var_index: usize) bool {
    return self.uses_table[node_index].isSet(var_index);
}

pub fn build(self: *Self) Error!void {
    self.ast.buildCallsProcMap();
    try self.buildRefTables();
}


fn buildRefTables(self: *Self) Error!void {
    for (self.ast.nodes, 0..) |node, node_index| {
        switch (node.type) {
        .IF, .WHILE => {
            const control_var = self.ast.nodes[node.children_index_or_lhs_child_index];
            self.setUsesBit(node_index, control_var.value_id_or_const);
        },
        .ASSIGN => {
            // may be redundant 
            // First set all of the bits in ASSIGN node
            self.setModifiesBit(node_index, node.value_id_or_const);
            const node_child_count = node.children_count_or_rhs_child_index;
            const node_child_index = node.children_index_or_lhs_child_index;
            var i = node_child_index;
            var tmp_node = node;
            while (i > (node_child_index - node_child_count)) : (i -= 1) {
                tmp_node = self.ast.nodes[@intCast(i)];
                if (tmp_node.type == .VAR) {
                    self.setUsesBit(node_index, tmp_node.value_id_or_const);
                }
            }
        },
        else => continue
        }
        const proc_parent_node = self.propagateRefBitVectorsToParents(@intCast(node_index), @intCast(node_index));
        try self.propagateRefBitVectorsToCallers(@intCast(node_index), proc_parent_node);
    }
    for (self.ast.nodes, 0..) |node, node_index| {
        if (node.type == .CALL) {
            const proc_node_index = self.ast.proc_map.get(node.value_id_or_const).node_index;

            const proc_parent_node = self.propagateRefBitVectorsToParents(@intCast(node_index), proc_node_index);
            try self.propagateRefBitVectorsToCallers(@intCast(proc_node_index), proc_parent_node);
        }
    }
}

fn propagateRefBitVectorsToParents(self: *Self, node_index: u32, src_node_index: u32) Node {
    var parent_index = self.ast.findParent(@intCast(node_index));
    var parent_node = self.ast.nodes[parent_index];
    while (true) {
        if (parent_node.type == .PROCEDURE or parent_node.type == .IF or parent_node.type == .WHILE) {
            self.setModifiesBitVector(src_node_index, parent_index);
            self.setUsesBitVector(src_node_index, parent_index);
        }
        if (parent_node.type == .PROCEDURE) {
            break;
        }
        parent_index = self.ast.findParent(@intCast(parent_index));
        parent_node = self.ast.nodes[parent_index];
    }
    return parent_node;
}
fn propagateRefBitVectorsToCallers(self: *Self, src_node_index: u32, proc_parent_node: Node) !void {
    const proc_parent_id = proc_parent_node.value_id_or_const;

    var current_proc_vector = std.DynamicBitSetUnmanaged.initEmpty(self.arena_allocator.allocator(), self.ast.proc_table.size()) catch
        return error.PKB_OUT_OF_MEMORY;
    defer current_proc_vector.deinit(self.arena_allocator.allocator());

    current_proc_vector.set(proc_parent_id);

    var new_proc_vector = std.DynamicBitSetUnmanaged.initEmpty(self.arena_allocator.allocator(), self.ast.proc_table.size()) catch
        return error.PKB_OUT_OF_MEMORY;
    defer current_proc_vector.deinit(self.arena_allocator.allocator());

    while (current_proc_vector.findFirstSet()) |_| {
        new_proc_vector.unsetAll();
        for (self.ast.proc_map.map.items, 0..) |*item, proc_id| {
            var tmp_proc_vector = current_proc_vector.clone(self.arena_allocator.allocator()) catch
                return error.PKB_OUT_OF_MEMORY;
            defer tmp_proc_vector.deinit(self.arena_allocator.allocator());

            tmp_proc_vector.setIntersection(item.calls);
            if (tmp_proc_vector.findFirstSet()) |_| {
                new_proc_vector.set(proc_id);
                self.setModifiesBitVector(src_node_index, item.node_index);
                self.setUsesBitVector(src_node_index,  item.node_index);
            }
        }
        std.mem.swap(std.DynamicBitSetUnmanaged, &current_proc_vector, &new_proc_vector);
    }
}

//fn recursivelySetVectorsForCallers(self: *Self, proc_id: u32, src_node_index: u32) void {
//    for (self.ast.proc_map.map.items, 0..) |*entry, caller_proc_id| {
//        if (entry.calls.isSet(@intCast(proc_id))) {
//            self.setModifiesBitVector(src_node_index, entry.node_index);
//            self.setUsesBitVector(src_node_index, entry.node_index);
//        }        
//    }
//}
//
//    pub fn deinit(self: *Self) void {
//        self.arena_allocator.deinit();
//        self.arena_allocator.child_allocator.destroy(self);
//    }
//
//    pub const RefQueryArg = union(enum) {
//        node_id: u32,
//        proc_name: []const u8,
//    };
//    pub fn modifies(self: *Self,
//        result_writer: std.io.FixedBufferStream([]u8).Writer,
//        ref_query_arg: RefQueryArg, var_name: ?[]const u8,
//    ) !u32 {
//        switch(ref_query_arg) {
//        RefQueryArg.node_id => {
//        },
//        RefQueryArg.proc_name => {
//        },
//        RefQueryArg.undef => {
//        },
//        }
//    }

