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

Console.WriteLine($"x: {Marshal.PtrToStringAnsi(SpaApi.GetVarName(0))}");
Console.WriteLine($"y: {Marshal.PtrToStringAnsi(SpaApi.GetVarName(1))}");
Console.WriteLine($"z: {Marshal.PtrToStringAnsi(SpaApi.GetVarName(2))}");

result = SpaApi.Deinit();

if (result != 0) {
    Console.WriteLine("Spa deinit failed !");
}
