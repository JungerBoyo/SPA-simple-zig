const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const AST = @import("Ast.zig");
const ASTParser = @import("AstParser.zig").AstParser(@TypeOf(std.io.getStdErr().writer()));
const Tokenizer = @import("Tokenizer.zig").Tokenizer(@TypeOf(std.io.getStdErr().writer()));

test "parser#0" {
    const simple = "procedure Third{z=5;v=z;}";
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());

    var ast = try parser.parse();
    defer ast.deinit();

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
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

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
    var tokenizer = try Tokenizer.init(std.testing.allocator, std.io.getStdErr().writer());
    defer tokenizer.deinit();

    var fixed_buffer_stream = std.io.fixedBufferStream(simple[0..]);
    try tokenizer.tokenize(fixed_buffer_stream.reader());

    var parser = try ASTParser.init(std.testing.allocator, tokenizer.tokens.items[0..], std.io.getStdErr().writer());
    defer parser.deinit();

    var ast = try parser.parse();
    defer ast.deinit();

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