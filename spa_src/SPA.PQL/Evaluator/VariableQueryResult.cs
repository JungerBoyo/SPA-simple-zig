using SPA.PQL.Abstractions;

namespace SPA.PQL.Evaluator;

public sealed class VariableQueryResult : QueryResult {
    public VariableQueryResult(IEnumerable<string> queries, IEnumerable<uint> results) : base(queries)
    {
        Results = results.Select(x => x.ToString()).ToList();
    }
}