#define LINUX

using System;
using System.Runtime.InteropServices;

public class SpaApi {

// #ifdef LINUX
    string spa_api_lib_path = "<PLACEHOLDER>";
// #else
//     string spa_api_lib_path = "../zig-out/lib/libsimple-spa.dll";
// #endif

    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint spaInit(string simple_src_file_path);
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern uint spaDeinit();
    [DllImport(spa_api_lib_path, CallingConvention = CallingConvention.Cdecl)]
    public static extern string spaGetError();
}
