using System.Runtime.Serialization;

namespace SPA.PQL.Exceptions {
    public class InvalidVariableDeclarationException : InvalidDeclarationException {
        public InvalidVariableDeclarationException(string declaration): base($"Invalid declaration of variable", declaration)
        {
            Declaration = declaration;
        }

        public override string ToString()
        {
            return $"Invalid variable declaration: {Declaration}";
        }
    }
}