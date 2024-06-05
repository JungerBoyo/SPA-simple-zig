using SPA.PQL.Abstractions;
using SPA.PQL.API;
using SPA.PQL.Elements;
using SPA.PQL.Evaluator;
using SPA.PQL.Exceptions;
using SPA.PQL.Parser;

namespace SPA.PQL.QueryElements;

internal sealed class PQLWithCondition : PQLBaseCondition {
    private const string ProcName = "procName";
    private const string VarName = "varName";
    private const string Value = "value";
    private const string StmtNo = "stmt#";
    
    public required PQLWithConditionReference LeftReference { get; set; }
    public required PQLWithConditionReference RightReference { get; set; }

    public delegate string? MetadataFunc(IPKBInterface pkbInterface, uint statementNo, uint valueId);

    private static readonly string[] ValidMetadataNames = [ 
        ProcName, VarName, Value, StmtNo
    ];
        
    public override void Validate(PQLQuery query, PQLQueryValidationResult result)
    {
        ValidateReference(LeftReference, query, result);
        ValidateReference(RightReference, query, result);
    }

    public override void Evaluate(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
    {
        var leftCollection = GetStatementCollection(variables, LeftReference, out var leftVariable);
        var rightCollection = GetStatementCollection(variables, RightReference, out var rightVariable);
        
        var leftValue = GetValue(LeftReference, leftVariable);
        var rightValue = GetValue(RightReference, rightVariable);

        var result = new List<(ProgramElement? left, ProgramElement? right)>();
            
        if (leftCollection is not null && rightCollection is not null)
        {
            foreach (var left in leftCollection)
            {
                foreach (var right in rightCollection)
                {
                    if (leftValue.Invoke(pkbApi, left.StatementNumber, left.ValueId) == rightValue.Invoke(pkbApi, right.StatementNumber, right.ValueId))
                    {
                        result.Add((left, right));
                    }
                }
            }

            foreach (var item in result)
            {
                var left = leftVariable?.Elements.FirstOrDefault(x => x.ProgramElement == item.left);
                var right = rightVariable?.Elements.FirstOrDefault(x => x.ProgramElement == item.right);

                if (left is not null && right is not null)
                {
                    left.Depends.Add(KeyValuePair.Create(leftVariable!, item.right!));
                    right.Depends.Add(KeyValuePair.Create(rightVariable!, item.left!));
                }
            }
            
            leftVariable?.Elements.RemoveAll(x => !result.Any(y => y.left == x.ProgramElement));
            rightVariable?.Elements.RemoveAll(x => !result.Any(y => y.right == x.ProgramElement));
        }

        if (leftCollection is not null && rightCollection is null)
        {
            foreach (var left in leftCollection)
            {
                if (leftValue.Invoke(pkbApi, left.StatementNumber, left.ValueId) == rightValue.Invoke(pkbApi, 0, 0))
                {
                    result.Add((left, null));
                }
            }

            leftVariable?.Elements.RemoveAll(x => !result.Any(y => y.left == x.ProgramElement));
        }
            
        if (leftCollection is null && rightCollection is not null)
        {
            foreach (var right in rightCollection)
            {
                if (leftValue.Invoke(pkbApi, 0, 0) == rightValue.Invoke(pkbApi, right.StatementNumber, right.ValueId))
                {
                    result.Add((null, right));
                }
            }

            rightVariable?.Elements.RemoveAll(x => !result.Any(y => y.left == x.ProgramElement));
        }

        if (leftCollection is null && rightCollection is null)
        {
            if (leftValue.Invoke(pkbApi, 0, 0) != rightValue.Invoke(pkbApi, 0, 0))
            {
                throw new EvaluationException(string.Empty);
            }
        }
    }

    private MetadataFunc GetValue(PQLWithConditionReference reference, EvaluatedVariable? variable)
    {
        switch (reference.Type)
        {
            case PQLWithConditionReferenceType.Metadata:
                return (pkbInterface, statementId, valueId) =>
                {
                    if (reference.MetadataFieldName == VarName)
                        return pkbInterface.GetVariableName(valueId);
                    
                    if (reference.MetadataFieldName == ProcName)
                        return pkbInterface.GetProcedureName(valueId);
                    
                    if (reference.MetadataFieldName == StmtNo)
                        return statementId.ToString();

                    return string.Empty;
                };
            case PQLWithConditionReferenceType.Integer:
                return (_, _, _) => reference.IntValue?.ToString() ?? string.Empty;
            case PQLWithConditionReferenceType.TextValue:
                return (_, _, _) => reference.TextValue ?? string.Empty;
        }

        throw new ArgumentException("");
    }

    private List<ProgramElement>? GetStatementCollection(List<EvaluatedVariable> variables, PQLWithConditionReference reference, out EvaluatedVariable? variable)
    {
        variable = null;
            
        if (reference.Type == PQLWithConditionReferenceType.Metadata)
        {
            variable = variables.First(x => x.VariableName == reference.VariableName);

            return variable.Elements.Select(x => x.ProgramElement).ToList();
        }

        return null;
    }

    public override IEnumerable<string> GetNamesOfVariablesUsed()
    {
        if (LeftReference.Type is PQLWithConditionReferenceType.Metadata)
            yield return LeftReference.VariableName!;
        
        if (RightReference.Type is PQLWithConditionReferenceType.Metadata)
            yield return RightReference.VariableName!;
    }

    private static void ValidateReference(PQLWithConditionReference reference, 
        PQLQuery query,
        PQLQueryValidationResult result)
    {
        switch (reference.Type)
        {
            case PQLWithConditionReferenceType.Metadata:
                CheckVariableDeclaration(query, result, reference.VariableName);
                CheckMetadataName(result, reference.MetadataFieldName);
                break;
        }
    }

    private static void CheckVariableDeclaration(PQLQuery query,
        PQLQueryValidationResult result,
        string? variableName)
    {
        if(!IsVariableDeclared(query, variableName))
            result.Errors.Add($"Variable not declared: {variableName ?? "null"}");
    }
        
    private static void CheckMetadataName(PQLQueryValidationResult result, string? metadataName)
    {
        if(!IsValidMetadataName(metadataName))
            result.Errors.Add($"Invalid metadata name {metadataName ?? "null"}");
    }
        
    private static bool IsVariableDeclared(PQLQuery query, string? variableName) 
        => !string.IsNullOrEmpty(variableName) && query.Variables.Any(x => x.Name == variableName);
        
    private static bool IsValidMetadataName(string? name) 
        => !string.IsNullOrEmpty(name) && ValidMetadataNames.Contains(name);
    
    //TODO: Implement ToString properly
    public override string ToString() 
        => $"Select {LeftReference.VariableName} with {LeftReference.VariableName}.{LeftReference.Type} = {RightReference.VariableName}.{RightReference.Type}";

}