using SPA.PQL.Abstractions;
using SPA.PQL.API;
using SPA.PQL.Elements;
using SPA.PQL.Exceptions;
using SPA.PQL.Parser;

namespace SPA.PQL.Evaluator;

public sealed class PQLEvaluator : IDisposable {
    private static readonly PQLEvaluatorOptions DefaultOptions = new PQLEvaluatorOptions();
    private readonly IPKBInterface _pkbApi;
    private PQLQuery _query;
    private readonly PQLEvaluatorOptions _options;
    private readonly List<ProgramElement> _programElements;

    private List<PQLBaseCondition>? _freeConditions = null;

    public PQLEvaluator(IPKBInterface pkbApi, string simpleProgramFilePath)
    {
        _options ??= DefaultOptions;

        _pkbApi = pkbApi;
        _programElements = _pkbApi.Init(simpleProgramFilePath);
    }

    public PQLEvaluator(IPKBInterface pkbApi, string simpleProgramFilePath, Action<PQLEvaluatorOptions> options) : this(pkbApi, simpleProgramFilePath)
    {
        _options = new PQLEvaluatorOptions();
        options.Invoke(_options);
    }

    public PQLQueryValidationResult ValidateQuery(string pqlQuery)
    {
        var parser = new PQLParser();
        _query = parser.Parse(pqlQuery);
        return _query.ValidateQuery();
    }

    public QueryResult Evaluate()
    {
        if (_query is null)
        {
            throw new NotValidatedException();
        }

        if (_options.RemoveFreeVariables)
        {
            RemoveFreeVariables();
        }

        if (_options.BuildEvaluationTree)
        {
            _freeConditions = new List<PQLBaseCondition>();

            BuildEvaluationTree();
        }

        var loadedVariables = InitVariables(_programElements).ToList();
        var compiledRelations = _query.Conditions.Select(x => x.ToString() ?? string.Empty);
        bool wasInterrupted = false;
        foreach (var condition in _query.Conditions)
        {
            if (loadedVariables.Any(x => x.Elements.Count == 0))
            {
                loadedVariables.ForEach(x => x.Elements.Clear());
                wasInterrupted = true;
                break;
            }

            try
            {
                condition.Evaluate(_pkbApi, loadedVariables);
                UpdateVariablesBasedOnDependedValues(loadedVariables);
            }
            catch (EvaluationException)
            {
                loadedVariables.ForEach(x => x.Elements.Clear());
                wasInterrupted = true;
                break;
            }
        }

        if (_query.QueryResult.IsBooleanResult)
        {
            return new BooleanQueryResult(compiledRelations,
                [!wasInterrupted && loadedVariables.All(x => x.Elements.Count > 0)]);
        }

        if (_query.QueryResult.VariableNames.Count == 1)
        {
            var data = loadedVariables
                .First(x => x.VariableName == _query.QueryResult.VariableNames[0]).Elements
                .Select(x => x.ProgramElement.StatementNumber)
                .ToList();

            return new VariableQueryResult(compiledRelations, data);
        }
        else
        {
            // var temp = loadedVariables.Where(x => _query.QueryResult.VariableNames.Contains(x.VariableName))
            //     .OrderBy(x => _query.QueryResult.VariableNames.IndexOf(x.VariableName))
            //     .Select(x => );
        }

        return null!;
    }

    private void UpdateVariablesBasedOnDependedValues(List<EvaluatedVariable> loadedVariables)
    {
        foreach (var variable in loadedVariables)
        {
            for (int i = 0; i < variable.Elements.Count; i++)
            {
                var element = variable.Elements[i];
                if (element.Depends.Count == 0) continue;

                foreach (var depend in element.Depends)
                {
                    if (depend.Key.Elements.All(x => x.ProgramElement != depend.Value))
                    {
                        variable.Elements.Remove(element);
                    }
                }
            }
        }
    }

    private void BuildEvaluationTree()
    {
    }

    private void RemoveFreeVariables()
    {
        var usedVariables = _query.QueryResult.VariableNames.Union(_query.Conditions.SelectMany(x => x.GetNamesOfVariablesUsed())).ToList();
        _query.Variables.RemoveAll(x => !usedVariables.Contains(x.Name));
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
                    .Select(x => new EvaluatorVariableValue(x)).ToList(),
            };
        }
    }

    public void Dispose()
    {
        _pkbApi.DeInit();
    }
}