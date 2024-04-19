using System;
using System.Runtime.InteropServices;

// See https://aka.ms/new-console-template for more information
Console.WriteLine("Hello, World!");

uint result = SpaApi.Init("test.simple");

if (result != 0) {
    Console.WriteLine("Spa init failed !");
    Console.WriteLine($"==> {Marshal.PtrToStringAnsi(SpaApi.GetErrorMessage())}");
    return;
} 

UIntPtr result_ptr = SpaApi.Follows(
    0, 1, "",
    0, 2, ""
);

if (MemoryReader.ReadUInt32(result_ptr) != 1) {
    Console.WriteLine("Follows failed!");
} else {
    Console.WriteLine("Follows succeeded!");
}
result = SpaApi.Deinit();

if (result != 0) {
    Console.WriteLine("Spa deinit failed !");
}
