const std = @import("std");

const Self = @This();

pub const Error = error {
    PROC_MAP_OUT_OF_MEMORY,
};

pub const ProcId = u32;

pub const Entry = struct {
    node_index: u32,
    calls: std.DynamicBitSetUnmanaged, 
};

map: std.ArrayList(Entry),
arena_allocator: std.heap.ArenaAllocator,

pub fn init(internal_allocator: std.mem.Allocator) Error!*Self {
    var self = internal_allocator.create(Self) catch {
        return error.PROC_MAP_OUT_OF_MEMORY;
    };
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
    self.map = std.ArrayList(Entry).init(self.arena_allocator.allocator());
    return self;
}

pub fn resize(self: *Self, new_size: usize) Error!void {
    self.map.resize(new_size) 
        catch return error.PROC_MAP_OUT_OF_MEMORY;
}

pub fn add(self: *Self, proc_id: ProcId, node_index: u32) Error!void {
    self.map.items[proc_id] = Entry{
        .node_index = @intCast(node_index),
        .calls = std.DynamicBitSetUnmanaged.initEmpty(
            self.arena_allocator.allocator(),
            self.map.items.len
        ) catch return error.PROC_MAP_OUT_OF_MEMORY,
    };
}

pub fn setCalls(self: *Self, proc_id: ProcId, called_proc_id: ProcId) void {
    self.map.items[proc_id].calls.set(called_proc_id); 
}

pub fn get(self: *Self, proc_id: ProcId) Entry {
    return self.map.items[proc_id];
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

//pub const CallsArg = union (enum) {
//    proc_name: []const u8,
//    proc_id: u32,
//
//    fn isProcName(self: CallsArg) bool {
//        return switch (self) {
//        CallsArg.proc_name => return true,
//        CallsArg.proc_id => return false,
//        };
//    }
//};
//
//pub fn calls(self: *Self,
//    result_writer: std.io.FixedBufferStream([]u8).Writer,
//    p1: CallsArg, p2: CallsArg
//) !u32 {
//    _ = p2;
//    _ = result_writer;
//    _ = self;
//
//    if (
//}
    
