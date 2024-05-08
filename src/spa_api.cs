using System;
using System.Runtime.InteropServices;

public class SpaApi {
    public enum StatementType : uint
    {
        NONE, // null type
        // root node (aggregates procedures)
        PROGRAM,        // program : procedure+
        // directly aggregates STATEMENTS
        PROCEDURE,      // procedure : ‘procedure’ proc_name ‘{‘ stmtLst ‘}’
        // provides indirection for while and if to aggregate STATEMENTS
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
        CONST           // factor : var_name | const_value | ‘(’ expr ‘)’
    };

    public enum StatementValueType : uint
    {
        SELECTED    = 0,
        UNDEFINED   = 0xFF_FF_FF_FF
    }

    public enum Error : uint {
        OK = 0,
        SIMPLE_FILE_OPEN_ERROR,
        TRIED_TO_DEINIT_EMPTY_INSTANCE,
        NODE_ID_OUT_OF_BOUNDS,
        TRIED_TO_USE_EMPTY_INSTANCE,
        TOKENIZER_OUT_OF_MEMORY,
        SIMPLE_STREAM_READING_ERROR,
        UNEXPECTED_CHAR,
        PROC_VAR_TABLE_OUT_OF_MEMORY,
        PARSER_OUT_OF_MEMORY,
        INT_OVERFLOW,
        NO_MATCHING_RIGHT_PARENTHESIS,
        WRONG_FACTOR,
        SEMICOLON_NOT_FOUND_AFTER_ASSIGN,
        ASSIGN_CHAR_NOT_FOUND,
        SEMICOLON_NOT_FOUND_AFTER_CALL,
        CALLED_PROCEDURE_NAME_NOT_FOUND,
        THEN_KEYWORD_NOT_FOUND,
        MATCHING_ELSE_CLOUSE_NOT_FOUND,
        VAR_NAME_NOT_FOUND,
        TOO_FEW_STATEMENTS,
        INVALID_STATEMENT,
        RIGHT_BRACE_NOT_FOUND,
        LEFT_BRACE_NOT_FOUND,        
        KEYWORD_NOT_FOUND,
        PROCEDURE_NAME_NOT_FOUND,
        UNSUPPORTED_COMBINATION,
        WRITER_ERROR,
        UNDEFINED
    };

    [StructLayout(LayoutKind.Sequential)]
    public struct NodeC
    {
        public uint type;
        public uint statement_id;
        public int line_no;
        public int column_no;
    };

    const string spa_api_lib_path = "<PLACEHOLDER>";

    // Takes path to SPA lang source file and creates PKB instance
    // based on it. MUST be called before any functions from the API are called.
    // Returns error code or OK.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Init(string simple_src_file_path);

    // Deinitializes context. Frees up memory basically.
    // Returns OK or an error code.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Deinit();

    // Gets current error message from error buffer. MUST correspond
    // logically to error code. If it is not, then it means error message
    // is "old". ALWAYS copy string returned by this function. DO NOT
    // rely on memory of this string!!!
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr GetErrorMessage();

    // Gets current error code and OKays out current error code after
    // returning.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint GetError();

    // Gets current result size (eg. from last call to any of the
    // relation funcitons). Upon return sets result buffer size
    // to 0.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint GetResultsSize();
    
    // Returns metadata of node which has an id <id>. In case of failure,
    // returns zeroed out node metadata and sets error code.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern NodeC GetNodeMetadata(uint id);

    // Returns node's value. Eg. in case of assign statement value
    // will be the name of the variable, and in case of procedure value
    // is going to be procedure name and so on. In case of failure,
    // return empty string and sets error code. ALWAYS copy string returned 
    // by this function. DO NOT rely on memory of this string!!!
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr GetNodeValue(uint id);

    // Follows relation. As parameters, takes statement type, id 
    // (statement id not node id!!!) and value which is explained in 
    // GetNodeValue. Important notes: 
    //
    // <s1>/<s2> can take 3 different TYPES of values;
    //      - 0 -> means that that statement is SELECTED
    //      - UINT32_MAX -> means that that statement is UNDEFINED (
    //                      there are yet none constraints put onto it)
    //      - (0, UINT32_MAX) -> concrete statement id
    //
    // examples:
    //      * assign a; stmt s; select s such that follows(s, a) with a.varname = "x";
    //          translates to:
    //              Follows(NONE, 0, null, ASSIGN, UINT32_MAX, "x");
    //              returns: all node ids of s's which fullfil the relation
    //
    //      * assign a; select a such that follows(5, a) with a.varname = "x";
    //          translates to:
    //              Follows(NONE, 5, null, ASSIGN, 0, "x");
    //
    //  etc.
    // In case of failure, returns NULL and sets error code.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr Follows(uint s1_type, uint s1, string s1_value, uint s2_type, uint s2, string s2_value);

    // Follows transitive aka Follows* relation. As parameters, takes statement type, id 
    // (statement id not node id!!!) and value which is explained in 
    // GetNodeValue. Check 'Follows' comments for details.
    // In case of failure, returns NULL and sets error code.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr FollowsTransitive(uint s1_type, uint s1, string s1_value, uint s2_type, uint s2, string s2_value);

    // Parent relation. As parameters, takes statement type, id 
    // (statement id not node id!!!) and value which is explained in 
    // GetNodeValue. Check 'Follows' comments for details.
    // In case of failure, returns NULL and sets error code.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr Parent(uint s1_type, uint s1, string s1_value, uint s2_type, uint s2, string s2_value);

    // Parent* relation. As parameters, takes statement type, id 
    // (statement id not node id!!!) and value which is explained in 
    // GetNodeValue. Check 'Follows' comments for details.
    // In case of failure, returns NULL and sets error code.
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr ParentTransitive(uint s1_type, uint s1, string s1_value, uint s2_type, uint s2, string s2_value);
}
