using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using SPA.PQL.Parser;
using SPA.Simple.Elements;

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
            var programElements = _pkbApi.Init(simpleProgramFilePath);

            var loadedVariables = InitVariables(programElements).ToList();

            foreach (var condition in _query.Conditions)
            { 
                condition.Evaluate(_pkbApi, loadedVariables);
            }

            return null!;
        }

        private IEnumerable<EvaluatedVariable> InitVariables(List<ProgramElement> elements)
        {
            foreach (var variable in _query.Variables)
            {
                yield return new EvaluatedVariable()
                {
                    VariableName = variable.Name,
                    Elements = elements.Where(x => variable.EntitiesTypes.Contains(x.Type)).ToList(),
                };
            }
        }
    }
}