using SPA.PQL.QueryElements;

namespace SPA.PQL.Parser {
    internal sealed class PQLQuery {
        public required List<PQLVariable> Variables { get; set; }
        public required PQLQueryResult QueryResult { get; set; }
    }
}