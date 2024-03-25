pub const TokenType = enum(u32) {
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
pub const TokenMetadata = struct {
    line_no: i32,
    column_no: i32,
    line: []u8,
};

// Consists of a type, eventually value
// (for pattern tokens) and metadata.
pub const Token = struct {
    type: TokenType,
    value: ?[]u8 = null,
    metadata: ?TokenMetadata = null,
};
