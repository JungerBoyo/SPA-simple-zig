using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using SPA.PQL.Parser;

namespace SPA.PQL.QueryElements;

internal sealed class PQLWithCondition : PQLBaseCondition {
    public required PQLWithConditionReference LeftReference { get; set; }
    public required PQLWithConditionReference RightReference { get; set; }

    private static readonly string[] ValidMetadataNames = [ 
        "procName", "varName", "value", "stmt#"
    ];
        
    public override void Validate(PQLQuery query, PQLQueryValidationResult result)
    {
        ValidateReference(LeftReference, query, result);
        ValidateReference(RightReference, query, result);
    }

    public override void Evaluate(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
    {
        throw new NotImplementedException();
    }

    public override IEnumerable<string> GetNamesOfVariablesUsed()
    {
        if (LeftReference.Type is PQLWithConditionReferenceType.Metadata or PQLWithConditionReferenceType.Variable)
            yield return LeftReference.VariableName!;
        
        if (RightReference.Type is PQLWithConditionReferenceType.Metadata or PQLWithConditionReferenceType.Variable)
            yield return RightReference.VariableName!;
    }

    private static void ValidateReference(PQLWithConditionReference reference, 
        PQLQuery query,
        PQLQueryValidationResult result)
    {
        switch (reference.Type)
        {
            case PQLWithConditionReferenceType.Variable:
                CheckVariableDeclaration(query, result, reference.VariableName);
                break;
            case PQLWithConditionReferenceType.Metadata:
                CheckVariableDeclaration(query, result, reference.VariableName);
                CheckMetadataName(result, reference.VariableName);
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