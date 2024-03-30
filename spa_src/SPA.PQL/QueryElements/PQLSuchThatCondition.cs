using SPA.PQL.Abstractions;
using SPA.PQL.Parser;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLSuchThatCondition : PQLBaseCondition {
        public required string RelationName { get; set; }
        public required PQLSuchThatConditionReference LeftReference { get; set; }
        public required PQLSuchThatConditionReference RightReference { get; set; }
        
        public override void Validate(PQLQuery query, PQLQueryValidationResult result)
        {
            if (LeftReference.Type is PQLSuchThatConditionReferenceType.Variable)
            {
                if (query.Variables.Any(x => x.Name == LeftReference.VariableName))
                {
                    result.Errors.Add($"Variable not declared: {LeftReference.VariableName}");
                }
            }
            
            if (RightReference.Type is PQLSuchThatConditionReferenceType.Variable)
            {
                if (query.Variables.Any(x => x.Name == RightReference.VariableName))
                {
                    result.Errors.Add($"Variable not declared: {RightReference.VariableName}");
                }
            }
            
            //TODO: Validate references based on RelationName
        }
    }
}