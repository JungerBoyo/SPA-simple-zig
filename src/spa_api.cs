using System;
using System.Runtime.InteropServices;

public class SpaApi {
    enum StatementType : uint
    {
        NONE    = 0, 
        CALL    = 3,
        WHILE   = 4,
        IF      = 5,
        ASSIGN  = 6,
    };

    enum StatementValueType : uint {
        SELECTED    = 0,
        UNDEFINED   = 0xFF_FF_FF_FF
    }

    string spa_api_lib_path = "<PLACEHOLDER>";
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Init(string simple_src_file_path);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Deinit();
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern string GetError();

    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr Follows(uint s1_type, uint s1, uint s2_type, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr FollowsTransitive(uint s1_type, uint s1, uint s2_type, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr Parent(uint s1_type, uint s1, uint s2_type, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr ParentTransitive(uint s1_type, uint s1, uint s2_type, uint s2);
}
