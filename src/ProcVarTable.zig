const std = @import("std");

const NodeType = @import("node.zig").NodeType;
const NodeId = @import("node.zig").NodeId;

const Self = @This();

pub const Error = error {
    PROC_VAR_TABLE_OUT_OF_MEMORY,
};

const Entry = struct {
    value: []u8,
};

pub const ProcVarId = u32;

table: std.ArrayList(Entry),
hashmap: std.StringHashMap(ProcVarId),

arena_allocator: std.heap.ArenaAllocator,

pub fn init(internal_allocator: std.mem.Allocator) Error!*Self {
    var self = internal_allocator.create(Self) catch {
        return error.PROC_VAR_TABLE_OUT_OF_MEMORY;
    };
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
    self.table = std.ArrayList(Entry).init(self.arena_allocator.allocator());
    self.hashmap = std.StringHashMap(ProcVarId).init(self.arena_allocator.allocator());
    return self;
}

/// Returns an `index` to inserted `value` in the `table`. 
/// If `value` exists just returns its `index` without 
/// modifying its internal state.
pub fn tryInsert(self: *Self, value: []const u8) Error!ProcVarId {
    if (self.hashmap.get(value)) |index| {
        return index;
    } else {
        const index: u32 = @intCast(self.table.items.len);
        const duped_value_ptr = self.arena_allocator.allocator().dupe(u8, value) catch {
            return error.PROC_VAR_TABLE_OUT_OF_MEMORY;
        };
        self.table.append(.{
            .value = duped_value_ptr
            //.node_ids = std.ArrayList(NodeId),
        }) catch { return error.PROC_VAR_TABLE_OUT_OF_MEMORY; };
        self.hashmap.put(self.table.getLast().value, index) catch {
            return error.PROC_VAR_TABLE_OUT_OF_MEMORY;
        };
        return index;
    }
}

/// No bounds checking.
//pub fn addNodeId(self: *Self, index: ProcVarId, node_id: NodeId) void {
//    self.table.items[index].node_ids.append(node_id);
//}

pub fn size(self: *Self) usize {
    return self.table.items.len;
}

/// No bounds checking.
pub fn getByIndex(self: *Self, index: ProcVarId) ?[]const u8 {
    return if(index < self.table.items.len) self.table.items[index].value else null; 
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}
