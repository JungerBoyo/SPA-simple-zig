const std = @import("std");

////////////////////////////////////////////
////           TOKENIZER BEGIN          ////
////////////////////////////////////////////
const TokenType = enum(u32) {
    NAME,           // var/proc
    INTEGER,        // const value

    LEFT_PARENTHESIS,   // '('
    RIGHT_PARENTHESIS,  // ')'
    LEFT_BRACE,         // '{'
    RIGHT_BRACE,        // '}'
    SEMICOLON,          // ';'
    
    PROCEDURE,      // 'procedure'
    IF,             // 'if'
    THEN,           // 'then'
    ELSE,           // 'else'
    WHILE,          // 'while'
    CALL,           // 'call'

    ASSIGN,         // '='
    ADD,            // '+'
    SUB,            // '-'
    MUL,            // '*'

    EOF,    // end of file
    WHITE,  // pseudo-token type used to denote 
            // white char in tokenizer internally
            // means ' ', '\t' and '\r'
};

// Holds metadata to print good
// errors.
const TokenMetadata = struct {
    line_no: i32,
    column_no: i32,
    line: []u8,
};

// Consists of a type, eventually value
// (for pattern tokens) and metadata.
const Token = struct {
    type: TokenType,
    value: ?[]u8 = null,
    metadata: ?TokenMetadata = null,
};

// Scans any stream of bytes with `anytype` reader
// and generates tokens. Memory is allocated using
// arena allocator and is not freed until `deinit` is
// called. Variable `error_flag` is true when error
// occured during tokenization process.
const Tokenizer = struct {
    arena_allocator: std.heap.ArenaAllocator,
    tokens: std.ArrayList(Token),

    error_flag: bool = false,
    column_no: i32 = 0,
    line_no: i32 = 1,
    line: ?[]u8 = null,

    pub fn init(internal_allocator: std.mem.Allocator) !*Tokenizer {
        var self = try internal_allocator.create(Tokenizer);
        self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
        self.tokens = std.ArrayList(Token).init(self.arena_allocator.allocator());
        self.error_flag = false;
        self.column_no = 0;
        self.line_no = 1;
        self.line = null;
        return self;
    }

    fn getLine(self: *Tokenizer, reader: anytype) !?[]u8 {
        return try reader.readUntilDelimiterOrEofAlloc(self.arena_allocator.allocator(), '\n', 1024*1024);
    }

    fn onError(self: *Tokenizer, message: []const u8) void {
        self.error_flag = true;

        const line_until_column = self.line.?[0..@intCast(self.column_no)];
        const line_after_column = self.line.?[@intCast(self.column_no + 1)..];
        const char_in_column = self.line.?[@intCast(self.column_no)..@intCast(self.column_no + 1)];

        std.log.err("Error at {}:{}: {s}\n\t{s}[{s}]{s}", .{
            self.line_no, self.column_no + 1, message,
            line_until_column, char_in_column, line_after_column,
        });
    }

    fn isNumeric(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    fn isLetter(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
    }

    fn isAlphaNumeric(c: u8) bool {
        return isNumeric(c) or isLetter(c);
    }

    fn getMetadata(self: *Tokenizer) TokenMetadata {
        return TokenMetadata {
            .line_no = self.line_no,
            .column_no = self.column_no,
            .line = self.line.?,
        };
    }

    fn getValue(self: *Tokenizer, end: i32) []u8 {
        return self.line.?[@intCast(self.column_no)..@intCast(end)];
    }

    fn getChar(self: *Tokenizer, i: i32) u8 {
        return self.line.?[@intCast(i)];
    }

    fn getCurrentChar(self: *Tokenizer) u8 {
        return self.getChar(self.column_no);
    }

    fn parseIntegerToken(self: *Tokenizer) Token {
        var tmp: i32 = self.column_no + 1;
        while (tmp < self.line.?.len and isNumeric(self.getChar(tmp))) {
            tmp += 1;
        }
        defer self.column_no = tmp; 
        return Token { 
            .type = .INTEGER,
            .value = self.getValue(tmp),
            .metadata = self.getMetadata()
        };
    }

    fn parseAlphaNumericToken(self: *Tokenizer) Token {
        var tmp: i32 = self.column_no + 1;
        while (tmp < self.line.?.len and isAlphaNumeric(self.getChar(tmp))) {
            tmp += 1;
        }
        defer self.column_no = tmp;

        const token_type: TokenType = blk: {
            if (std.mem.eql(u8, self.getValue(tmp), "procedure")) {
                break :blk .PROCEDURE;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "if")) {
                break :blk .IF;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "then")) {
                break :blk .THEN;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "else")) {
                break :blk .ELSE;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "while")) {
                break :blk .WHILE;
            }
            if (std.mem.eql(u8, self.getValue(tmp), "call")) {
                break :blk .CALL;
            }
            break :blk .NAME;
        };

        return Token {
            .type = token_type,
            .value = if (token_type == .NAME) self.getValue(tmp) else null,
            .metadata = self.getMetadata()
        };
    }

    fn parseOneCharToken(self: *Tokenizer, token_type: TokenType) Token {
        defer self.column_no += 1;
        return Token {
            .type = token_type,
            .value = null,
            .metadata = self.getMetadata()
        };
    }

    fn parseToken(self: *Tokenizer) ?Token {
        const c = self.getCurrentChar();
        return switch (c) {
            ' ', '\t', '\r' => blk: { // inluding '\r'... because Windows........ :skull:
                self.column_no += 1; 
                break :blk Token{ .type = .WHITE }; 
            },
            '(' => self.parseOneCharToken( .LEFT_PARENTHESIS ),
            ')' => self.parseOneCharToken( .RIGHT_PARENTHESIS ),
            '{' => self.parseOneCharToken( .LEFT_BRACE ),
            '}' => self.parseOneCharToken( .RIGHT_BRACE ),
            ';' => self.parseOneCharToken( .SEMICOLON ),
            '=' => self.parseOneCharToken( .ASSIGN ),
            '+' => self.parseOneCharToken( .ADD ),
            '-' => self.parseOneCharToken( .SUB ),
            '*' => self.parseOneCharToken( .MUL ),
            else => blk: {
                if (Tokenizer.isNumeric(c)) {
                    break :blk self.parseIntegerToken();
                }
                if (Tokenizer.isLetter(c)) {
                    break :blk self.parseAlphaNumericToken();
                }

                self.onError("Unexpected char.");
                break :blk null;
            }
        };
    }

    pub fn tokenize(self: *Tokenizer, reader: anytype) !void {
        var eof: bool = false;
        while (!eof) {
            self.line = try self.getLine(reader); 
            if (self.line == null) {
                eof = true;
                break;
            }
            if (self.line.?.len == 0) {
                continue;
            }

            self.column_no = 0;
            while (self.column_no < self.line.?.len) {
                var token = self.parseToken();
                if (token == null) { // error (equivalent to `error_flag`)
                    eof = true;
                    break;
                }
                if (token.?.type == .WHITE) {
                    continue;
                }
                try self.tokens.append(token.?);
            }
            self.line_no += 1;
        }

        try self.tokens.append(.{ .type = .EOF });
    }

    fn deinit(self: *Tokenizer) void {
        self.arena_allocator.deinit();
        self.arena_allocator.child_allocator.destroy(self);
    }
};
////////////////////////////////////////////
////           TOKENIZER END            ////
////////////////////////////////////////////


////////////////////////////////////////////
////          AST PARSER BEGIN          ////
////////////////////////////////////////////

const NodeType = enum {
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

const NodeMetadata = struct {
    statement_id: u32 = 0,
    line_no: i32,
    column_no: i32,
    // line: []u8,
};

const Node = struct {
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
    metadata: ?NodeMetadata = null,
};

const AST = struct {
    arena_allocator: std.heap.ArenaAllocator,
    nodes: []Node,

    pub fn init(internal_allocator: std.mem.Allocator, nodes_count: usize) !*AST {
        var self = try internal_allocator.create(AST);
        self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);
        self.nodes = try self.arena_allocator.allocator().alloc(Node, @intCast(nodes_count));
        return self;
    }

    pub fn deinit(self: *AST) void {
        self.arena_allocator.deinit();
        self.arena_allocator.child_allocator.destroy(self);
    }
};

const ASTParser = struct {
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

    fn setDefaults(self: *ASTParser) void {
        self.root = .{ .type = .PROGRAM };
        self.current_token = 0;
        self.current_statement = 1;
        self.current_level = -1;
        self.current_parent_index = 0;
        self.error_flag = false;
    }

    pub fn init(internal_allocator: std.mem.Allocator, tokens: []Token) !*ASTParser {
        var self = try internal_allocator.create(ASTParser);

        self.tokens = tokens;
        self.arena_allocator = std.heap.ArenaAllocator.init(internal_allocator);

        self.levels = std.ArrayList(std.ArrayList(Node)).init(self.arena_allocator.allocator());
        try self.levels.append(std.ArrayList(Node).init(self.arena_allocator.allocator()));
        
        self.expression_level = std.ArrayList(Node).init(self.arena_allocator.allocator());

        self.setDefaults();
        return self;
    }

    fn onError(self: *ASTParser, message: []const u8) void {
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

    fn parseFactor(self: *ASTParser) Error!u32 {
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

    fn parseTerm(self: *ASTParser) Error!u32 {
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
    fn parseExpression(self: *ASTParser) Error!u32 {
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
    
    fn parseExpressionSetNode(self: *ASTParser) Error!bool {
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

    fn parseAssignment(self: *ASTParser) Error!bool {
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
    fn parseCall(self: *ASTParser) Error!bool {
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
    fn parseIf(self: *ASTParser) Error!bool {
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

    fn parseVar(self: *ASTParser) Error!bool {
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

    fn parseWhile(self: *ASTParser) Error!bool {
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

    fn parseStatementListWithNode(self: *ASTParser) Error!bool {
        try self.currentLevel().append(.{
            .type = .STMT_LIST, 
            .parent_index = self.whereIsMyDad(),
            .children_index_or_lhs_child_index = self.whereAreMyKids(),
        });
        return try self.wrapInLevel(parseStatementList);
    }

    fn parseStatementList(self: *ASTParser) Error!bool {
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

    fn parseProcedure(self: *ASTParser) Error!bool {
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
    fn getNodeMetadata(self: *ASTParser, token: *const Token, with_statement_id: u32) NodeMetadata {
        defer self.current_statement += with_statement_id;
        return NodeMetadata{
            .statement_id = with_statement_id * self.current_statement,
            .line_no = token.metadata.?.line_no,
            .column_no = token.metadata.?.column_no,
            // .line = token.metadata.?.line
        };
    }
    fn getCurrentNodeMetadata(self: *ASTParser, with_statement_id: u32) NodeMetadata {
        const token = self.getCurrentToken();
        defer self.current_statement += with_statement_id;
        return NodeMetadata{
            .statement_id = with_statement_id * self.current_statement,
            .line_no = token.metadata.?.line_no,
            .column_no = token.metadata.?.column_no,
            // .line = token.metadata.?.line
        };
    }
    
    fn currentLevel(self: *ASTParser) *std.ArrayList(Node) {
        return &self.levels.items[@intCast(self.current_level)];
    }

    fn compareAdvance(self: *ASTParser, token_type: TokenType) ?Token {
        if (self.current_token < self.tokens.len) {
            const token = self.getCurrentToken();
            if (token.type == token_type) {
                self.current_token += 1;
                return token;
            }
        }
        return null;
    }
    fn compare(self: *ASTParser, token_type: TokenType) bool {
        return (self.current_token < self.tokens.len) and (self.getCurrentToken().type == token_type);
    }
    fn whereAreMyKids(self: *ASTParser) u32 {
        // it is safe because 1 more level in advance in `wrapInLevel` func is allocat
        return @intCast(self.levels.items[@intCast(self.current_level + 1)].items.len);
    }
    fn whereIsMyDad(self: *ASTParser) u32 {
        return @intCast(self.levels.items[@intCast(self.current_level - 1)].items.len - 1);
    }
    fn getCurrentToken(self: *ASTParser) Token {
        return self.tokens[@intCast(self.current_token)];
    }
    fn getCurrentTokenOffset(self: *ASTParser, offset: i32) Token {
        return self.tokens[@intCast(self.current_token + offset)];
    }
    fn getStatementId(self: *ASTParser) u32 { 
        defer self.current_statement += 1;
        return self.current_statement;
    }
    fn wrapInLevel(self: *ASTParser, parse_ptr: *const fn(self: *ASTParser) Error!bool) Error!bool {
        self.current_level += 1;
        while (self.current_level + 2 > self.levels.items.len) { // reserve this level and next one
            try self.levels.append(std.ArrayList(Node).init(self.arena_allocator.allocator()));
        }
        defer self.current_level -= 1;
        return try parse_ptr(self);
    }

    fn deinit(self: *ASTParser) void {
        self.arena_allocator.deinit();
        self.arena_allocator.child_allocator.destroy(self);
    }

    // main parse function
    pub fn parse(self: *ASTParser) Error!*AST {
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
};
////////////////////////////////////////////
////           AST PARSER END           ////
////////////////////////////////////////////

pub fn main() !void {
}

fn tokenizerTestGood(simple: []const u8, tokens: []const TokenType) !void {
    var tokenizer = try Tokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    try std.testing.expectEqual(false, tokenizer.error_flag);
    
    for (tokenizer.tokens.items, tokens) |*to_check_token, good_token_type| {
        try std.testing.expectEqual(good_token_type, to_check_token.type);
    }
}

fn tokenizerTestBad(simple: []const u8) !void {
    var tokenizer = try Tokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    try std.testing.expectEqual(true, tokenizer.error_flag);
}

test "tokenizer#0" {
    const simple = 
    \\procedure First {
    \\  x = 2;
    \\  z = 3;
    \\  call Second;
    \\}
    ;
    const tokens = [_]TokenType {
        .PROCEDURE, .NAME, .LEFT_BRACE,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .CALL, .NAME, .SEMICOLON,
        .RIGHT_BRACE,
        .EOF
    };

    try tokenizerTestGood(simple[0..], tokens[0..]);
}

test "tokenizer#1" {
    const simple = "procedure Third{z=5;v=z;}";
    const tokens = [_]TokenType {
        .PROCEDURE, .NAME, .LEFT_BRACE,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .NAME, .SEMICOLON,
        .RIGHT_BRACE,
        .EOF
    };
    try tokenizerTestGood(simple[0..], tokens[0..]);
}

test "tokenizer#2" {
    const simple = 
    \\procedure Second {
    \\ x = 0;
    \\ i = 5;
    \\ while i {
    \\
    \\x = x + 2 * y;
    \\
    \\call Third;
    \\
    \\i = i - 1; }
    \\ if x then {
    \\
    \\x = x + 1; }
    \\else {
    \\
    \\z = 1; }
    \\ z = z + x + i;
    \\ y = z + 2;
    \\ x = x * y + z; }
    ;
    const tokens = [_]TokenType {
        .PROCEDURE, .NAME, .LEFT_BRACE,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .WHILE, .NAME, .LEFT_BRACE,
                .NAME, .ASSIGN, .NAME, .ADD, .INTEGER, .MUL, .NAME, .SEMICOLON,
                .CALL, .NAME, .SEMICOLON,
                .NAME, .ASSIGN, .NAME, .SUB, .INTEGER, .SEMICOLON,
            .RIGHT_BRACE,
            .IF, .NAME, .THEN, .LEFT_BRACE,
                .NAME, .ASSIGN, .NAME, .ADD, .INTEGER, .SEMICOLON,
            .RIGHT_BRACE, .ELSE, .LEFT_BRACE,
                .NAME, .ASSIGN, .INTEGER, .SEMICOLON,
            .RIGHT_BRACE,
            .NAME, .ASSIGN, .NAME, .ADD, .NAME, .ADD, .NAME, .SEMICOLON,
            .NAME, .ASSIGN, .NAME, .ADD, .INTEGER, .SEMICOLON,
            .NAME, .ASSIGN, .NAME, .MUL, .NAME, .ADD, .NAME, .SEMICOLON,
        .RIGHT_BRACE,
        .EOF
    };

    try tokenizerTestGood(simple[0..], tokens[0..]);
}

test "tokenizer#3" {
    const simple = "if x then { y! = 1; }";
    try tokenizerTestBad(simple[0..]);
}


test "parser#0" {
    const simple = "procedure Third{z=5;v=z;}";
    var tokenizer = try Tokenizer.init(std.testing.allocator);

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..]);

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(false, parser.error_flag);

    // ast memory should be independent of parser and tokenizer memories
    parser.deinit();
    tokenizer.deinit();

    const nodes = [_]NodeType {
        .PROGRAM, 
        .PROCEDURE,
        .ASSIGN,.ASSIGN,
        .CONST, .VAR
    };


    for (ast.nodes, nodes) |*to_check_node, good_node_type| {
        try std.testing.expectEqual(good_node_type, to_check_node.type);
    }
}

test "parser#1" {
    const simple = 
    \\procedure Third{z=5;v=z;}
    \\procedure Second {
    \\ x = 0;
    \\ i = 5;
    \\ while i {
    \\
    \\x = x + 2 * y;
    \\
    \\call Third;
    \\
    \\i = i - 1; }
    \\ if x then {
    \\
    \\x = x + 1; }
    \\else {
    \\
    \\z = 1; }
    \\ z = z + x + i;
    \\ y = z + 2;
    \\ x = x * y + z; }
    ;
    var tokenizer = try Tokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..]);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(false, parser.error_flag);


    const nodes = [_]NodeType {
        .PROGRAM, 
        .PROCEDURE, .PROCEDURE,
        .ASSIGN, .ASSIGN, .ASSIGN, .ASSIGN,    .WHILE,                 .IF,                 .ASSIGN, .ASSIGN, .ASSIGN,
                                            .VAR,.STMT_LIST,  .VAR,.STMT_LIST,.STMT_LIST,
//                                                    |                 |           |
//         ___________________________________________|                 |           |
//         |                                                            |           |
        .ASSIGN, .CALL, .ASSIGN,                                     .ASSIGN,   .ASSIGN,
// expressions (basically RPN)
//        z=5    v=z    x=0     i=5           z=z+x+i                 y=z+2                 x=x*y+z
        .CONST, .VAR, .CONST, .CONST, .VAR,.VAR,.ADD,.VAR,.ADD, .VAR,.CONST,.ADD, .VAR,.VAR,.MUL,.VAR,.ADD,
//                  x=x+2*y                 i=i-1            x=x+1         z=1
        .VAR,.CONST,.VAR,.MUL,.ADD,  .VAR,.CONST,.SUB, .VAR,.CONST,.ADD, .CONST
    };


   for (ast.nodes, nodes) |*to_check_node, good_node_type| {
       try std.testing.expectEqual(good_node_type, to_check_node.type);
   }
}

fn testMakeNode(
    node_type: NodeType, 
    children_index_or_lhs_child_index: u32,
    children_count_or_rhs_child_index: u32,
    parent_index: u32
) Node {
    return .{
        .type = node_type,
        .children_index_or_lhs_child_index = children_index_or_lhs_child_index,
        .children_count_or_rhs_child_index = children_count_or_rhs_child_index,
        .parent_index = parent_index,
    };
}

test "parser#2" {
    const simple = 
    \\procedure Second {
    \\ while i {
    \\
    \\x = x + 2 * y;
    \\
    \\call Third;
    \\
    \\i = i - 1; }
    \\}
    ;
    var tokenizer = try Tokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..]);
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

    try std.testing.expectEqual(false, parser.error_flag);

    const nodes = [_]Node {
        testMakeNode(.PROGRAM, 1, 1, 0),    //0
        testMakeNode(.PROCEDURE, 2, 1, 0),  //1

        testMakeNode(.WHILE, 3, 2, 1),      //2

        testMakeNode(.VAR, 0, 0, 2),        //3
        testMakeNode(.STMT_LIST, 5, 3, 2),  //4
        
        testMakeNode(.ASSIGN, 12, 5, 4),    //5
        testMakeNode(.CALL, 0, 0, 4),       //6
        testMakeNode(.ASSIGN, 15, 3, 4),    //7

        testMakeNode(.VAR, 0, 0, 12),        //8
        testMakeNode(.CONST, 0, 0, 11),      //9
        testMakeNode(.VAR, 0, 0, 11),        //10
        testMakeNode(.MUL, 9, 10, 12),        //11
        testMakeNode(.ADD, 8, 11, 5),        //12

        testMakeNode(.VAR, 0, 0, 15),        //13
        testMakeNode(.CONST, 0, 0, 15),      //14
        testMakeNode(.SUB, 13, 14, 7),        //15
    };

    for (ast.nodes, nodes) |*to_check_node, good_node| {
        try std.testing.expectEqual(good_node.type, to_check_node.type);
        try std.testing.expectEqual(good_node.children_index_or_lhs_child_index, to_check_node.children_index_or_lhs_child_index);
        try std.testing.expectEqual(good_node.children_count_or_rhs_child_index, to_check_node.children_count_or_rhs_child_index);
        try std.testing.expectEqual(good_node.parent_index, to_check_node.parent_index);
    }

}