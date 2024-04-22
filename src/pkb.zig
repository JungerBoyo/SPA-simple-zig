
const std = @import("std");

pub const Node = @import("node.zig").Node;
pub const NodeType = @import("node.zig").NodeType;

pub fn PkbModifies(comptime ResultIntType: type) type { return struct {
    pub const AST = @import("Ast.zig").Ast(ResultIntType);
    const Self = @This();
    ast: *AST,

    //modifies_hashmap_var_to_stmts: std.StringHashMap(std.ArrayList(u32)), 
    //modifies_hashmap_stmt_to_vars: std.HashMap

};}

pub fn Pkb(comptime ResultIntType: type) type { return struct {
    pub const AST = @import("Ast.zig").Ast(ResultIntType);
    const Self = @This();
    ast: *AST,

    modifies_hashmap: std.StringHashMap(std.ArrayList(u32)),
    uses_hashmap: std.StringHashMap(std.ArrayList(u32)),
    procedures_hashmap: std.StringHashMap(u32),

    pub fn init(ast: *AST) *Pkb {
        var self = ast.internal_allocator.create(Self);
        self.modifies_hashmap = std.StringHashMap(std.ArrayList(u32)).init(ast.arena_allocator);
        self.uses_hashmap = std.StringHashMap(std.ArrayList(u32)).init(ast.arena_allocator);
        return self;
    }

    //pub fn build(self: *Self) void {
    //    for (self.ast.nodes, 0..) |node, node_index| {
    //        switch (node.type) {
    //        }
    //    }
    //}

    // TODO memory is freed by AST. Do it more elegantly. 
    pub fn deinit(self: *Self) void {
        self.ast.arena_allocator.child_allocator.destroy(self);
    }
};}

