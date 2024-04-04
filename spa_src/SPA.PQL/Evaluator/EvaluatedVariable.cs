using SPA.Simple.Elements;

namespace SPA.PQL.Evaluator {
    public class EvaluatedVariable {
        public required string VariableName { get; set; }
        public required List<ProgramElement> Elements { get; set; }
    }
}