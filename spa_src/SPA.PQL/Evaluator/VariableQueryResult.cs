using SPA.PQL.Abstractions;

namespace SPA.PQL.Evaluator {
    public class VariableQueryResult : BaseQueryResult {
        public required List<uint> Results { get; set; }
    }
}