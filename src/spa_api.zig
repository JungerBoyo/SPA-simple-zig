const std = @import("std");

const Token             = @import("token.zig").Token;
const TokenType         = @import("token.zig").TokenType;
const Node              = @import("node.zig").Node;
const NodeType          = @import("node.zig").NodeType;
const NodeMetadata      = @import("node.zig").NodeMetadata;

const AST = @import("Ast.zig");
const ASTParser = @import("AstParser.zig");
const Tokenizer = @import("Tokenizer.zig");

const allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);

const SpaInstance = struct {
    ast: *AST
};

const OK: c_int = 0;

const FAILED_TO_OPEN_SIMPLE_SRC: c_int        = -1;
const FAILED_TO_INIT_TOKENIZER: c_int         = -2;
const FAILED_TO_TOKENIZE_SIMPLE_SRC: c_int    = -3;
const FAILED_TO_INIT_PARSER: c_int            = -4;
const FAILED_TO_PARSE_SIMPLE_SRC: c_int       = -5;

const TRIED_TO_DEINITIALIZE_EMPTY_INSTANCE: c_int = -6;

var instance: ?SpaInstance = null;

pub export fn spaInit(simple_src_file_path: [*:0]const u8) callconv(.C) c_int {
    if (instance) |value| {
        value.ast.deinit();
    }

    const file = std.fs.cwd().openFileZ(simple_src_file_path, .{ .mode = .read_only }) catch {
        return FAILED_TO_OPEN_SIMPLE_SRC;
    };
    defer file.close();

    var tokenizer = Tokenizer.init(std.heap.page_allocator) catch {
        return FAILED_TO_INIT_TOKENIZER;
    };

    tokenizer.tokenize(file.reader()) catch {
        return FAILED_TO_TOKENIZE_SIMPLE_SRC;
    };
    defer tokenizer.deinit();
    if (tokenizer.error_flag) {
        return FAILED_TO_TOKENIZE_SIMPLE_SRC;        
    }

    // errory poprawic lol
    var parser = ASTParser.init(std.heap.page_allocator, tokenizer.tokens.items[0..]) catch {
        return FAILED_TO_INIT_PARSER;
    };
    defer parser.deinit();
    if (parser.error_flag) {
        return FAILED_TO_INIT_PARSER;
    }

    var ast = parser.parse() catch {
        return FAILED_TO_PARSE_SIMPLE_SRC;
    };

    instance = SpaInstance{ .ast = ast };

    return OK;
}

pub export fn spaDeinit() callconv(.C) c_int { 
    if (instance) |value| {
        value.ast.deinit();
        return OK;
    }
    return TRIED_TO_DEINITIALIZE_EMPTY_INSTANCE;
}