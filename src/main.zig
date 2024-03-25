const std = @import("std");

// imports template
// const Token             = @import("token.zig").Token;
// const TokenType         = @import("token.zig").TokenType;
// const Node              = @import("node.zig").Node;
// const NodeType          = @import("node.zig").NodeType;
// const NodeMetadata      = @import("node.zig").NodeMetadata;
// 
// const AST = @import("Ast.zig");
// const ASTParser = @import("AstParser.zig");
// const Tokenizer = @import("Tokenizer.zig");

comptime {
    _ = @import("tokenizer_tests.zig");
    _ = @import("ast_parser_tests.zig");
    _ = @import("spa_api_tests.zig");
}

pub fn main() !void {}

