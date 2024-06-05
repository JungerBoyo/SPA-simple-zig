pub const NodeType = @import("node.zig").NodeType;

pub const Error = error {
    UNSUPPORTED_COMBINATION,
    PROC_NOT_FOUND,
    VAR_NOT_FOUND,
};

pub const STATEMENT_UNDEFINED: u32 = 0xFF_FF_FF_FF;
pub const STATEMENT_SELECTED: u32 = 0x0;

pub const NODE_SELECTED: u32 = 0x0;
pub const NODE_UNDEFINED: u32 = 0xFF_FF_FF_FF;

pub fn isModeSelUndef(lhs: u32, rhs: u32) bool {
    return ((lhs ^ rhs) == 0xFF_FF_FF_FF);//STATEMENT_UNDEFINED);
}
pub fn isModeSelDef(lhs: u32, rhs: u32) bool {
    return (((lhs | rhs) != 0) and ((lhs ^ rhs) == lhs or (lhs ^ rhs) == rhs));
}
pub fn isModeDef(lhs: u32, rhs: u32) bool {
    return (((lhs | rhs) != 0) and (lhs ^ rhs) != 0xFF_FF_FF_FF);//STATEMENT_UNDEFINED);
}
pub fn checkNodeType(node_type: NodeType, expected_node_type: NodeType) bool {
    return (node_type == expected_node_type or expected_node_type == .NONE);
}

// lhs argument type for modifies ,uses relation and lhs/rhs
// argument of calls relation
pub const RefQueryArg = union(enum) {
    node_id: u32,
    proc_name: []const u8,

    pub fn hasProcName(self: RefQueryArg) bool {
        return self == RefQueryArg.proc_name;
    }
};
