namespace SPA.PQL.Exceptions {
    public sealed class InvalidWithConditionDeclarationException : InvalidDeclarationException {
        public InvalidWithConditionDeclarationException(string declaration) : base("Invalid with condition", declaration)
        {
        }
    }
}