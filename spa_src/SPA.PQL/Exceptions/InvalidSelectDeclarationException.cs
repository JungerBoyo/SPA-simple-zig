namespace SPA.PQL.Exceptions {
    public sealed class InvalidSelectDeclarationException : InvalidDeclarationException {
        public InvalidSelectDeclarationException(string declaration): base($"Invalid declaration of Select", declaration)
        {
            Declaration = declaration;
        }

        public override string ToString()
        {
            return $"Invalid Select declaration: {Declaration}";
        }
    }
}