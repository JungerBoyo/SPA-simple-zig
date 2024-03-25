using System;
using System.Runtime.InteropServices;

public class SpaApi {
    [DllImport("../zig-out/lib/libsimple-spa.so", CallingConvention = CallingConvention.Cdecl)]
    public static extern int spaInit(string simple_src_file_path);

   [DllImport("../zig-out/lib/libsimple-spa.so", CallingConvention = CallingConvention.Cdecl)]
    public static extern int spaDeinit();
}
