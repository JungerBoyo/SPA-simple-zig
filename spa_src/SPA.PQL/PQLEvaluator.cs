using SPA.PQL.Abstractions;
using SPA.PQL.Parser;

namespace SPA.PQL {
    public class PQLEvaluator {
        private readonly IPKBInterface _pkbApi;
        private readonly PQLQuery _query;

        public PQLEvaluator(string pqlQuery, IPKBInterface pkbApi)
        {
            _pkbApi = pkbApi;
            var parser = new PQLParser();
            _query = parser.Parse(pqlQuery);
        }
        
        public PQLQueryValidationResult ValidateQuery(string pqlQuery)
        {
            return _query.ValidateQuery();
        }
        
        public IEnumerable<BaseQueryResult> Evaluate(string simpleProgramFilePath)
        {
            throw new NotImplementedException();
        } 
    }
}