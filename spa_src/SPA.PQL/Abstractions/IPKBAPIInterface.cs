using SPA.Simple.Elements;

namespace SPA.PQL.Abstractions {
    public interface IPKBInterface {
        int Init(string path);
        Program LoadProgram();
    }
}