namespace SPA.PQL.Exceptions {
    public class InvalidWithConditionDeclarationException : InvalidDeclarationException {
        public InvalidWithConditionDeclarationException(string declaration) : base("Invalid with condition", declaration)
        {
        }
    }
}