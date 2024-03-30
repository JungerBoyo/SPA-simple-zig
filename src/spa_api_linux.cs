using System;
using System.Runtime.InteropServices;

public class SpaApi {
    string spa_api_lib_path = "../zig-out/lib/libsimple-spa.so";
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Init(string simple_src_file_path);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Deinit();
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern string GetError();
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Follows(uint s1, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint FollowsTransitive(uint s1, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint Parent(uint s1, uint s2);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint ParentTransitive(uint s1, uint s2);
}
