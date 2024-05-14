using SPA.PQL.Abstractions;

namespace SPA.PQL.Evaluator {
    public sealed class BooleanQueryResult : QueryResult
    {
        public BooleanQueryResult(IEnumerable<string> queries, IEnumerable<bool> results) : base(queries)
        {
            Results = results.Select(x => x.ToString()).ToList();
        }
    }
}