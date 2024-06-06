using System.Text;
using SPA.PQL.Abstractions;

namespace SPA.PQL.Evaluator {
    public class TupleQueryResult : QueryResult {
        internal IEnumerable<IEnumerable<uint>> BaseResults { get; private init; }
        
        public TupleQueryResult(IEnumerable<string> queries, IEnumerable<IEnumerable<uint>> baseResults) : base(queries)
        {
            BaseResults = baseResults;
        }

        public override string ToString()
        {
            var builder = new StringBuilder();

            foreach (var item in BaseResults)
            {
                builder.Append(string.Join(" ", item));
                builder.Append(',');
            }

            return builder.ToString();
        }
    }
}