namespace SPA.PQL.Exceptions {
    public class InvalidDeclarationException : Exception {
        public string Declaration { get; set; }

        public InvalidDeclarationException(string message, string declaration) : base(message)
        {
            Declaration = declaration;
        }

        public override string ToString()
        {
            return $"Invalid Select declaration: {Declaration}";
        }
    }
}