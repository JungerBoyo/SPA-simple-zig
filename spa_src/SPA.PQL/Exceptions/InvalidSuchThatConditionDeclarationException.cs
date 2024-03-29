namespace SPA.PQL.Exceptions {
    public class InvalidSuchThatConditionDeclarationException : InvalidDeclarationException {
        public InvalidSuchThatConditionDeclarationException(string declaration) : base("Invalid such that condition declaration", declaration)
        {
        }
    }
}