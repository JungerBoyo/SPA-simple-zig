namespace SPA.PQL.Exceptions {
    public sealed class InvalidSuchThatConditionDeclarationException : InvalidDeclarationException {
        public InvalidSuchThatConditionDeclarationException(string declaration) : base("Invalid such that condition declaration", declaration)
        {
        }
    }
}