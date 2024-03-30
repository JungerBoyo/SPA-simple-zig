namespace SPA.PQL.Parser {
    public class PQLQueryValidationResult {
        public List<string> Errors { get; set; }
        public List<string> Warnings { get; set; }

        public PQLQueryValidationResult()
        {
            Errors = new List<string>();
            Warnings = new List<string>();
        }
    }
}