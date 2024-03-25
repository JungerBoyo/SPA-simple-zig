// See https://aka.ms/new-console-template for more information
Console.WriteLine("Hello, World!");

int result = SpaApi.spaInit("test.simple");

if (result != 0) {
    Console.WriteLine("Spa init failed !");
} 

result = SpaApi.spaDeinit();

if (result != 0) {
    Console.WriteLine("Spa deinit failed !");
}