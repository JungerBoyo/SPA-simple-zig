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

    public PQLEvaluator(IPKBInterface pkbApi, string simpleProgramFilePath, Action<PQLEvaluatorOptions> options) : this(pkbApi,
        simpleProgramFilePath)
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

        BuildEvaluationTree();

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
                .Select(x => x.ProgramElement)
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
        var toRemove = new List<EvaluatorVariableValue>();
        foreach (var variable in loadedVariables)
        {
            for (int i = 0; i < variable.Elements.Count; i++)
            {
                var element = variable.Elements[i];
                if (element.Depends.Count == 0) continue;

                bool markedToDelete = true;

                foreach (var depend in element.Depends.Where(x => x.Key != variable))
                {
                    if (depend.Key.Elements.Any(x => x.ProgramElement == depend.Value))
                    {
                        markedToDelete = false;
                    }
                }

                if (markedToDelete)
                {
                    toRemove.Add(element);
                }
            }

            variable.Elements.RemoveAll(x => toRemove.Contains(x));

            toRemove.Clear();
        }
    }

    private void BuildEvaluationTree()
    {
        var tree = new List<List<PQLBaseCondition>>();

        var used = _query.QueryResult.VariableNames;

        do
        {
            tree.Add(GetConditionsThatUseVariables(used, tree.SelectMany(x => x), out used));
        } while (tree[^1].Count > 0);

        _query.Conditions = tree.SelectMany(x => x).Reverse().ToList();
    }

    private List<PQLBaseCondition> GetConditionsThatUseVariables(List<string> variableNames, IEnumerable<PQLBaseCondition> usedConditions,
        out List<string> nextVariables)
    {
        var conditions = _query.Conditions.Except(usedConditions);

        var result = conditions.Where(x => x.GetNamesOfVariablesUsed().Intersect(variableNames).Any()).ToList();

        nextVariables = result.SelectMany(x => x.GetNamesOfVariablesUsed()).Except(variableNames).ToList();

        return result.ToList();
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
            var partResult = new EvaluatedVariable()
            {
                VariableName = variable.Name,
                StatementType = variable.EntityType,
                Elements = elements.Where(x => x.Type == variable.EntityType || variable.EntityType == SpaApi.StatementType.NONE)
                    .Select(x => new EvaluatorVariableValue(x)).ToList(),
            };

            if (partResult.StatementType == SpaApi.StatementType.VAR || partResult.StatementType == SpaApi.StatementType.PROCEDURE)
            {
                partResult.Elements = partResult.Elements.DistinctBy(x => x.ProgramElement.ValueId).ToList();
            }

            yield return partResult;
        }
    }

    public void Dispose()
    {
        _pkbApi.DeInit();
    }
}