const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const AST = @import("Ast.zig");

const Self = @This();

tokens: []Token,

arena_allocator: std.heap.ArenaAllocator,

root: Node = .{ .type = .PROGRAM },
levels: std.ArrayList(std.ArrayList(Node)),
expression_level: std.ArrayList(Node),

current_token: u32 = 0,
current_statement: u32 = 1,
current_level: i32 = -1,
current_parent_index: u32 = 0,

error_flag: bool = false,

fn setDefaults(self: *Self) void {
    self.root = .{ .type = .PROGRAM };
    self.current_token = 0;
    self.current_statement = 1;
    self.current_level = -1;
    self.current_parent_index = 0;
    self.error_flag = false;
}

pub fn init(internal_allocator: std.mem.Allocator, tokens: []Token) !*Self {
    var self = try internal_allocator.create(Self);

    self.tokens = tokens;
    self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);

    self.levels = std.ArrayList(std.ArrayList(Node)).init(self.arena_allocator.allocator());
    try self.levels.append(std.ArrayList(Node).init(self.arena_allocator.allocator()));
    
    self.expression_level = std.ArrayList(Node).init(self.arena_allocator.allocator());

    self.setDefaults();
    return self;
}

fn onError(self: *Self, message: []const u8) void {
    self.error_flag = true;

    if (self.getCurrentToken().metadata) |token_metadata| {
        const line_until_column = token_metadata.line[0..@intCast(token_metadata.column_no)];
        const line_after_column = token_metadata.line[@intCast(token_metadata.column_no + 1)..];
        const char_in_column = token_metadata.line[@intCast(token_metadata.column_no)..@intCast(token_metadata.column_no + 1)];

        std.log.err("Error at {}:{}: {s}\n\t{s}[{s}]{s}", .{
            token_metadata.line_no, token_metadata.column_no + 1, message,
            line_until_column, char_in_column, line_after_column,
        });
    } else {
        std.log.err("Error at ?:?: {s}\n\t??????", .{message});             
    }
}


const ParsingError = error {
    PARSE_EXPRESSION_ERROR,
    PARSE_ERROR,
};

const Error = ParsingError || std.mem.Allocator.Error;

fn parseFactor(self: *Self) Error!u32 {
    const token = self.getCurrentToken();
    self.current_token += 1;
    return switch (token.type) {
    .NAME => blk: {
        try self.expression_level.append(.{
            .type = .VAR,
            .value = token.value,
            .metadata = self.getNodeMetadata(&token, 0)
        });
        break :blk @intCast(self.expression_level.items.len - 1);
    },
    .INTEGER => blk: {
        try self.expression_level.append(.{
            .type = .CONST,
            .value = token.value,
            .metadata = self.getNodeMetadata(&token, 0)
        });
        break :blk @intCast(self.expression_level.items.len - 1);
    },
    .LEFT_PARENTHESIS => blk: {
        const node = try self.parseExpression();
        if (self.compareAdvance(.RIGHT_PARENTHESIS)) |_| {
            break :blk node;
        } else {
            self.onError("Expected ')'");
            break :blk error.PARSE_EXPRESSION_ERROR;
        }
    },
    else => blk: {
        self.onError("Factor can only be var name, integer or other expression enclosed in '('')'");
        break :blk error.PARSE_EXPRESSION_ERROR;
    }
    };
}

fn parseTerm(self: *Self) Error!u32 {
    var lhs_node = try self.parseFactor();
    while (self.compareAdvance(TokenType.MUL)) |token| {
        const rhs_node = try self.parseFactor();

        self.expression_level.items[lhs_node].parent_index = @intCast(self.expression_level.items.len);
        self.expression_level.items[rhs_node].parent_index = @intCast(self.expression_level.items.len);

        try self.expression_level.append(.{
            .type = NodeType.MUL,
            .children_index_or_lhs_child_index = lhs_node,
            .children_count_or_rhs_child_index = rhs_node,
            .metadata = self.getNodeMetadata(&token, 0)
        });
        lhs_node = @intCast(self.expression_level.items.len - 1);
    }
    return lhs_node;
}

// parse functions
fn parseExpression(self: *Self) Error!u32 {
    var lhs_node = try self.parseTerm();
    while (self.compare(TokenType.ADD) or self.compare(TokenType.SUB)) {
        const token = self.getCurrentToken();
        self.current_token += 1;
        const rhs_node = try self.parseTerm();

        self.expression_level.items[lhs_node].parent_index = @intCast(self.expression_level.items.len);
        self.expression_level.items[rhs_node].parent_index = @intCast(self.expression_level.items.len);

        try self.expression_level.append(.{
            .type = if (token.type == TokenType.ADD) NodeType.ADD else NodeType.SUB,
            .children_index_or_lhs_child_index = lhs_node,
            .children_count_or_rhs_child_index = rhs_node,
            .metadata = self.getNodeMetadata(&token, 0)
        });
        lhs_node = @intCast(self.expression_level.items.len - 1);
    }
    return lhs_node;
}

fn parseExpressionSetNode(self: *Self) Error!bool {
    const previous_children_count = self.expression_level.items.len;
    if (self.parseExpression()) |expression_children_index| {
        var assign_var_node = &self.currentLevel().items[self.currentLevel().items.len - 1];
        assign_var_node.children_index_or_lhs_child_index = expression_children_index;
        assign_var_node.children_count_or_rhs_child_index = @intCast(self.expression_level.items.len - previous_children_count);
        return true;
    } else |e| {
        return e;
    }
}

fn parseAssignment(self: *Self) Error!bool {
    try self.currentLevel().append(.{
        .type = .ASSIGN, 
        .children_index_or_lhs_child_index = self.whereAreMyKids(),
        .children_count_or_rhs_child_index = 1,
        .parent_index = self.whereIsMyDad(),
        .metadata = self.getCurrentNodeMetadata(1),
        .value = self.getCurrentToken().value
    });
    self.current_token += 1;
    // compare later, no harm in adding a node before compare if everything is correct
    if (self.compareAdvance(TokenType.ASSIGN)) |_| {
        if (try self.parseExpressionSetNode()) {
            if (self.compareAdvance(.SEMICOLON)) |_| {
                return true;
            } else {
                self.onError("Assignment statement must end with a ';'.");
            }
        }
    } else {
        self.onError("Assignment statement must consist of var name and '='.");
    }
    return false;
}
fn parseCall(self: *Self) Error!bool {
    self.current_token += 1;
    if (self.compareAdvance(TokenType.NAME)) |name_token| {
        if (self.compareAdvance(.SEMICOLON)) |_| {
            try self.currentLevel().append(.{
                .type = NodeType.CALL, 
                .parent_index = self.whereIsMyDad(),
                .value = name_token.value,
                .metadata = self.getNodeMetadata(&name_token, 1)
            });
            return true;
        } else {
            self.onError("Call statement must end with a ';");
        }
    } else {
        self.onError("Call statement must have procedure name.");
    }
    return false;
}
fn parseIf(self: *Self) Error!bool {
    try self.currentLevel().append(.{
        .type = .IF, 
        .children_index_or_lhs_child_index = self.whereAreMyKids(),
        .children_count_or_rhs_child_index = 3,
        .parent_index = self.whereIsMyDad(),
        .metadata = self.getCurrentNodeMetadata(1),
    });
    self.current_token += 1;

    if (try self.wrapInLevel(parseVar)) {
        if (self.compareAdvance(.THEN)) |_| {
            if (!try self.wrapInLevel(parseStatementListWithNode)) {
                return false;
            }
        } else {
            self.onError("Expecting then keyword before if statement list.");
            return false;
        }
    } else {
        return false;
    }

    if (self.compareAdvance(.ELSE)) |_| {
        return try self.wrapInLevel(parseStatementListWithNode);
    } else {
        self.onError("If statement must have matching else.");
    }
    return false;
}

fn parseVar(self: *Self) Error!bool {
    if (self.compareAdvance(.NAME)) |name_token| {
        try self.currentLevel().append(.{
            .type = .VAR, 
            .parent_index = self.whereIsMyDad(),
            .value = name_token.value.?,
            .metadata = self.getNodeMetadata(&name_token, 0),
        });
        return true;
    } else {
        self.onError("Expected variable.");
    }
    return false;        
}

fn parseWhile(self: *Self) Error!bool {
    try self.currentLevel().append(.{
        .type = .WHILE, 
        .children_index_or_lhs_child_index = self.whereAreMyKids(),
        .children_count_or_rhs_child_index = 2,
        .parent_index = self.whereIsMyDad(),
        .metadata = self.getCurrentNodeMetadata(1),
    });
    self.current_token += 1;

    return try self.wrapInLevel(parseVar) and try self.wrapInLevel(parseStatementListWithNode);
}

fn parseStatementListWithNode(self: *Self) Error!bool {
    try self.currentLevel().append(.{
        .type = .STMT_LIST, 
        .parent_index = self.whereIsMyDad(),
        .children_index_or_lhs_child_index = self.whereAreMyKids(),
    });
    return try self.wrapInLevel(parseStatementList);
}

fn parseStatementList(self: *Self) Error!bool {
    if (self.compareAdvance(.LEFT_BRACE)) |_| {
        var i: u32 = 0;
        while (self.current_token < self.tokens.len) {
            const token = self.getCurrentToken();
            if (token.type == .RIGHT_BRACE) {
                if (i == 0) {
                    self.onError("Statement list must contain one or more statements.");
                    return false;
                }
                self.current_token += 1;

                var previous_level = &self.levels.items[@intCast(self.current_level - 1)];
                previous_level.items[previous_level.items.len - 1].children_count_or_rhs_child_index = i;

                return true;
            } else {
                const result = switch (token.type) {
                    .NAME   => try self.parseAssignment(),
                    .CALL   => try self.parseCall(),
                    .IF     => try self.parseIf(),
                    .WHILE  => try self.parseWhile(),
                    else => blk: {
                        self.onError("Valid statements are only assignements, calls, ifs and while loops.");
                        break :blk false;
                    },
                };
                if (!result) {
                    return false;
                }
                i += 1;
            }
        }
        self.onError("Statement list must end with a '}'.");
    } else {
        self.onError("Statement list must begin with a '{'.");
    }
    return false;
}

fn parseProcedure(self: *Self) Error!bool {
    if (self.compareAdvance(.PROCEDURE)) |_| {
        if (self.compareAdvance(.NAME)) |name_token| {
            try self.currentLevel().append(.{
                .type = .PROCEDURE, 
                .children_index_or_lhs_child_index = self.whereAreMyKids(),
                .value = name_token.value,
                .metadata = self.getNodeMetadata(&name_token, 0)
            });
            return try self.wrapInLevel(parseStatementList);
        } else {
            self.onError("Procedure declaration must contain procedure name.");
        }
    } else {
        self.onError("Program can consist only of procedures beginning with 'procedure' keyword.");
    }
    return false;
}


// helper functions
fn getNodeMetadata(self: *Self, token: *const Token, with_statement_id: u32) NodeMetadata {
    defer self.current_statement += with_statement_id;
    return NodeMetadata{
        .statement_id = with_statement_id * self.current_statement,
        .line_no = token.metadata.?.line_no,
        .column_no = token.metadata.?.column_no,
        // .line = token.metadata.?.line
    };
}
fn getCurrentNodeMetadata(self: *Self, with_statement_id: u32) NodeMetadata {
    const token = self.getCurrentToken();
    defer self.current_statement += with_statement_id;
    return NodeMetadata{
        .statement_id = with_statement_id * self.current_statement,
        .line_no = token.metadata.?.line_no,
        .column_no = token.metadata.?.column_no,
        // .line = token.metadata.?.line
    };
}

fn currentLevel(self: *Self) *std.ArrayList(Node) {
    return &self.levels.items[@intCast(self.current_level)];
}

fn compareAdvance(self: *Self, token_type: TokenType) ?Token {
    if (self.current_token < self.tokens.len) {
        const token = self.getCurrentToken();
        if (token.type == token_type) {
            self.current_token += 1;
            return token;
        }
    }
    return null;
}
fn compare(self: *Self, token_type: TokenType) bool {
    return (self.current_token < self.tokens.len) and (self.getCurrentToken().type == token_type);
}
fn whereAreMyKids(self: *Self) u32 {
    // it is safe because 1 more level in advance in `wrapInLevel` func is allocat
    return @intCast(self.levels.items[@intCast(self.current_level + 1)].items.len);
}
fn whereIsMyDad(self: *Self) u32 {
    return @intCast(self.levels.items[@intCast(self.current_level - 1)].items.len - 1);
}
fn getCurrentToken(self: *Self) Token {
    return self.tokens[@intCast(self.current_token)];
}
fn getCurrentTokenOffset(self: *Self, offset: i32) Token {
    return self.tokens[@intCast(self.current_token + offset)];
}
fn getStatementId(self: *Self) u32 { 
    defer self.current_statement += 1;
    return self.current_statement;
}
fn wrapInLevel(self: *Self, parse_ptr: *const fn(self: *Self) Error!bool) Error!bool {
    self.current_level += 1;
    while (self.current_level + 2 > self.levels.items.len) { // reserve this level and next one
        try self.levels.append(std.ArrayList(Node).init(self.arena_allocator.allocator()));
    }
    defer self.current_level -= 1;
    return try parse_ptr(self);
}

pub fn deinit(self: *Self) void {
    self.arena_allocator.deinit();
    self.arena_allocator.child_allocator.destroy(self);
}

// main parse function
pub fn parse(self: *Self) Error!*AST {
    while (!self.compare(.EOF)) {
        if (!try self.wrapInLevel(parseProcedure)) {
            return error.PARSE_ERROR;
        } else {
            // set children count for parent
            self.root.children_count_or_rhs_child_index += 1;
        }
    }

    var flattened_tree_size: usize = 1 + self.expression_level.items.len; // 1 => root node
    for (self.levels.items) |*level| {
        flattened_tree_size += level.items.len;
    }

    var ast = try AST.init(self.arena_allocator.child_allocator, flattened_tree_size);

    ast.nodes[0] = self.root;
    ast.nodes[0].children_index_or_lhs_child_index = 1; // levels start from 1 index

    var previous_level_offset: usize = 0;
    var level_offset: usize = 1;
    const expression_region_offset = flattened_tree_size - self.expression_level.items.len;
    var i_nodes: usize = 1;
    var i_expressions: usize = expression_region_offset;

    for (self.levels.items) |*level| {
        const old_level_offset = level_offset;
        defer previous_level_offset = old_level_offset;
        level_offset += level.items.len;
        for (level.items) |*node| {
            ast.nodes[i_nodes] = node.*;
            // recognize expression
            if (node.type == .ASSIGN) {
                ast.nodes[i_nodes].parent_index += @intCast(previous_level_offset);
                ast.nodes[i_nodes].children_index_or_lhs_child_index += @intCast(expression_region_offset);
                for (
                    self.expression_level.items[(node.children_index_or_lhs_child_index - (node.children_count_or_rhs_child_index - 1))..(node.children_index_or_lhs_child_index + 1)],
                    ast.nodes[i_expressions..(i_expressions+node.children_count_or_rhs_child_index)]
                ) |src_expr_node, *dst_expr_node| {
                    dst_expr_node.* = src_expr_node;

                    dst_expr_node.parent_index += @intCast(expression_region_offset);
                    if (dst_expr_node.type != .VAR and dst_expr_node.type != .CONST) {
                        dst_expr_node.children_index_or_lhs_child_index += @intCast(expression_region_offset);
                        dst_expr_node.children_count_or_rhs_child_index += @intCast(expression_region_offset);
                    }

                    if (dst_expr_node.value) |*value| {
                        value.* = try ast.arena_allocator.allocator().dupe(u8, value.*);                            
                    }
                }
                ast.nodes[ast.nodes[i_nodes].children_index_or_lhs_child_index].parent_index = @intCast(i_nodes);
                i_expressions += node.children_count_or_rhs_child_index;
            } else {
                ast.nodes[i_nodes].parent_index += @intCast(previous_level_offset);
                if (ast.nodes[i_nodes].children_count_or_rhs_child_index != 0) {
                    ast.nodes[i_nodes].children_index_or_lhs_child_index += @intCast(level_offset);
                }
                if (ast.nodes[i_nodes].value) |*value| {
                    value.* = try ast.arena_allocator.allocator().dupe(u8, value.*);
                }
            }
            i_nodes += 1;
        }
    }

    return ast;
}
