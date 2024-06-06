using SPA.PQL.Abstractions;
using SPA.PQL.Elements;

namespace SPA.PQL.Evaluator;

public sealed class VariableQueryResult : QueryResult {
    internal List<ProgramElement> BaseResults { get; private init; }
    
    public VariableQueryResult(IEnumerable<string> queries, IEnumerable<ProgramElement> results) : base(queries)
    {
        BaseResults = results.ToList();
        Results = BaseResults.Select(x => x.ToString()).ToList();
    }
}