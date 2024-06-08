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


SpaApi.Uses(107, "x")

for (uint i = 0; i < SpaApi.GetVarTableSize(); i++)
{
    Console.WriteLine($"{Marshal.PtrToStringAnsi(SpaApi.GetVarName(i))}");
}


result = SpaApi.Deinit();

if (result != 0) {
    Console.WriteLine("Spa deinit failed !");
}
