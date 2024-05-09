using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using SPA.PQL.Parser;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLWithCondition : PQLBaseCondition {
        public required PQLWithConditionReference LeftReference { get; set; }
        public required PQLWithConditionReference RightReference { get; set; }
        
        public override void Validate(PQLQuery query, PQLQueryValidationResult result)
        {
            if (LeftReference.Type is PQLWithConditionReferenceType.Variable or PQLWithConditionReferenceType.Metadata)
            {
                if (query.Variables.Any(x => x.Name == LeftReference.VariableName))
                {
                    result.Errors.Add($"Variable not declared: {LeftReference.VariableName}");
                }
            }
            
            if (RightReference.Type is PQLWithConditionReferenceType.Variable or PQLWithConditionReferenceType.Metadata)
            {
                if (query.Variables.Any(x => x.Name == RightReference.VariableName))
                {
                    result.Errors.Add($"Variable not declared: {RightReference.VariableName}");
                }
            }
            
            //TODO: Validate the Metadata name
        }

        public override void Evaluate(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            throw new NotImplementedException();
        }
    }
}