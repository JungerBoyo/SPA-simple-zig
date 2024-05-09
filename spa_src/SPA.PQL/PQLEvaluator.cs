using SPA.PQL.Abstractions;
using SPA.PQL.API;
using SPA.PQL.Elements;
using SPA.PQL.Evaluator;
using SPA.PQL.Parser;

namespace SPA.PQL {
    public class PQLEvaluator : IDisposable {
        private readonly IPKBInterface _pkbApi;
        private readonly PQLQuery _query;

        public PQLEvaluator(string pqlQuery, IPKBInterface pkbApi)
        {
            _pkbApi = pkbApi;
            var parser = new PQLParser();
            _query = parser.Parse(pqlQuery);
        }

        public PQLQueryValidationResult ValidateQuery()
        {
            return _query.ValidateQuery();
        }

        public BaseQueryResult Evaluate(string simpleProgramFilePath)
        {
            var programElements = _pkbApi.Init(simpleProgramFilePath);

            //RemoveFreeVariables();

            var loadedVariables = InitVariables(programElements).ToList();

            foreach (var condition in _query.Conditions)
            {
                condition.Evaluate(_pkbApi, loadedVariables);
            }

            if (_query.QueryResult.IsBooleanResult)
            {
                return new BooleanQueryResult()
                {
                    Result = loadedVariables.All(x => x.Elements.Count > 0),
                };
            }

            if (_query.QueryResult.VariableNames.Length == 1)
            {
                var data = loadedVariables.First(x => x.VariableName == _query.QueryResult.VariableNames[0])
                    .Elements.Select(x => x.StatementNumber).ToList();
                return new VariableQueryResult()
                {
                    Results = data,
                };
            }

            //TODO: Implement tuple return type

            return null!;
        }

        private IEnumerable<EvaluatedVariable> InitVariables(List<ProgramElement> elements)
        {
            foreach (var variable in _query.Variables)
            {
                yield return new EvaluatedVariable()
                {
                    VariableName = variable.Name,
                    StatementType = variable.EntityType,
                    Elements = elements.Where(x => x.Type == variable.EntityType || variable.EntityType == SpaApi.StatementType.NONE)
                        .ToList(),
                };
            }
        }

        public void Dispose()
        {
            _pkbApi.DeInit();
        }
    }
}