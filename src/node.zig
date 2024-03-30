pub const NodeType = enum {
    // root node (aggregates procedures)
    PROGRAM,        // program : procedure+
    // directly aggregates STATEMENTS
    PROCEDURE,      // procedure : ‘procedure’ proc_name ‘{‘ stmtLst ‘}’
    // provides indirection to while and if to aggregate STATEMENTS
    STMT_LIST, // stmtLst : stmt+
    // STATEMENTS (stmt : call | while | if | assign)
    CALL,           // call : ‘call’ proc_name ‘;’
    WHILE,          // while : ‘while’ var_name ‘{‘ stmtLst ‘}’
    IF,             // if : ‘if’ var_name ‘then’ ‘{‘ stmtLst ‘}’ ‘else’ ‘{‘ stmtLst ‘}’
    ASSIGN,         // assign : var_name ‘=’ expr ‘;’

    MUL,            // term : term ‘*’ factor | factor

    ADD,            // expr : expr ‘+’ term | expr ‘-’ term | term
    SUB,            // expr : expr ‘+’ term | expr ‘-’ term | term

    VAR,            // factor : var_name | const_value | ‘(’ expr ‘)’
    CONST,          // factor : var_name | const_value | ‘(’ expr ‘)’

};

pub const NodeMetadata = struct {
    statement_id: u32 = 0,
    line_no: i32 = 0,
    column_no: i32 = 0,
    // line: []u8,
};

pub const Node = struct {
    type: NodeType,
    // index into children 
    children_index_or_lhs_child_index: u32 = 0, // valid values 1..
    // number of node's children
    children_count_or_rhs_child_index: u32 = 0,
    // parent index
    parent_index: u32 = 0, 
    // attributes (mostly procedure names, var names, constant values)
    value: ?[]u8 = null,
    // node metadata - similar to token metadata
    metadata: NodeMetadata = .{},
};