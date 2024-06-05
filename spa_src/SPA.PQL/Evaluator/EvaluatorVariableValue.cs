using SPA.PQL.Elements;

namespace SPA.PQL.Evaluator {
    internal class EvaluatorVariableValue {
        public ProgramElement ProgramElement { get; set; }
        public List<KeyValuePair<EvaluatedVariable, ProgramElement>> Depends { get; set; }

        public EvaluatorVariableValue(ProgramElement programElement)
        {
            ProgramElement = programElement;
            Depends = new List<KeyValuePair<EvaluatedVariable, ProgramElement>>();
        }
    }
}