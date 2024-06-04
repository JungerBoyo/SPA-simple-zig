using SPA.PQL.Evaluator;
using SPA.PQL.Parser;

namespace SPA.PQL.Abstractions {
    internal abstract class PQLBaseCondition {
        public abstract void Validate(PQLQuery query, PQLQueryValidationResult result);

        public abstract void Evaluate(IPKBInterface pkbApi, List<EvaluatedVariable> variables);
        public abstract IEnumerable<string> GetNamesOfVariablesUsed();
    }
}