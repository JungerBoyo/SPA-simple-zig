using SPA.PQL.Abstractions;
using SPA.PQL.Enums;
using SPA.PQL.Evaluator;
using SPA.PQL.Parser;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLSuchThatCondition : PQLBaseCondition {
        public required RelationType Relation { get; set; }
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

        public override void Evaluate(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            
            
            switch (Relation)
            {
                case RelationType.Parent:
                    break;
                case RelationType.ParentAll:
                    break;
                case RelationType.Next:
                    break;
                case RelationType.NextAll:
                    break;
                case RelationType.Assign:
                    break;
                case RelationType.Modifies:
                    break;
                case RelationType.Uses:
                    break;
                case RelationType.Calls:
                    break;
                case RelationType.CallsAll:
                    break;
                case RelationType.Follows:
                    break;
                case RelationType.FollowsAll:
                    break;
                case RelationType.Affects:
                    break;
                case RelationType.AffectsAll:
                    break;
                default:
                    throw new ArgumentOutOfRangeException();
            }
        }
    }
}