using System;
using System.Runtime.InteropServices;

public class SpaApi {
    enum StatementType : uint
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

    enum StatementValueType : uint
    {
        SELECTED    = 0,
        UNDEFINED   = 0xFF_FF_FF_FF
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct NodeC
    {
        public uint type;
        public uint statement_id;
        public int line_no;
        public int column_no;
    };

    string spa_api_lib_path = "<PLACEHOLDER>";

    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Init(string simple_src_file_path);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Deinit();
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern string GetError();

    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern NodeC GetNodeMetadata(uint id);

    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern string GetNodeValue(uint id);

    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr Follows(uint s1_type, uint s1, uint s2_type, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr FollowsTransitive(uint s1_type, uint s1, uint s2_type, uint s2);
    // [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    // public static extern UIntPtr Parent(uint s1_type, uint s1, uint s2_type, uint s2);
    // [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    // public static extern UIntPtr ParentTransitive(uint s1_type, uint s1, uint s2_type, uint s2);
}
