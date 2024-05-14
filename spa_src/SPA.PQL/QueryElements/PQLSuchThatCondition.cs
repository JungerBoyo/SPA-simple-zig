using SPA.PQL.Abstractions;
using SPA.PQL.API;
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
                if (!query.Variables.Any(x => x.Name == LeftReference.VariableName))
                {
                    result.Errors.Add($"Variable not declared: {LeftReference.VariableName}");
                }
            }

            if (RightReference.Type is PQLSuchThatConditionReferenceType.Variable)
            {
                if (!query.Variables.Any(x => x.Name == RightReference.VariableName))
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
                    EvaluateParent(pkbApi, variables);
                    break;
                case RelationType.Follows:
                    EvaluateFollow(pkbApi, variables);
                    break;
                case RelationType.Modifies:
                    break;
                case RelationType.Uses:
                    break;
                case RelationType.ParentAll:
                case RelationType.Next:
                case RelationType.NextAll:
                case RelationType.Assign:
                case RelationType.Calls:
                case RelationType.CallsAll:
                case RelationType.FollowsAll:
                case RelationType.Affects:
                case RelationType.AffectsAll:
                    throw new NotImplementedException();
                default:
                    throw new ArgumentOutOfRangeException();
            }
        }

        public void EvaluateParent(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber) 
                => pkbApi.Parent(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }
        
        public void EvaluateFollow(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber) 
                => pkbApi.Follow(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }
        
        public void EvaluateModifies(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber) 
                => pkbApi.Modifies(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }
        
        public void EvaluateUses(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber) 
                => pkbApi.Uses(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }

        private void EvaluateRelation(IPKBInterface pkbApi, List<EvaluatedVariable> variables,
            Func<IPKBInterface, uint, uint, uint, uint, bool> relationCheck)
        {
            var leftStatementType = GetStatementType(LeftReference, variables);
            var rightStatementType = GetStatementType(RightReference, variables);
            var leftStatementNumbers = GetStatementNumbers(LeftReference, variables, out var leftSelectedVariable);
            var rightStatementNumbers = GetStatementNumbers(RightReference, variables, out var rightSelectedVariable);

            var results = new List<(uint left, uint right)>();
            
            foreach (var leftStatementNumber in leftStatementNumbers)
            {
                foreach (var rightStatementNumber in rightStatementNumbers)
                {
                    if (relationCheck.Invoke(pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber))
                    {
                        results.Add((leftStatementNumber, rightStatementNumber));
                    }
                }
            }

            if(leftSelectedVariable is not null)
                leftSelectedVariable.Elements.RemoveAll(x => !results.Any(y => y.left == x.StatementNumber));
            
            if(rightSelectedVariable is not null)
                rightSelectedVariable.Elements.RemoveAll(x => !results.Any(y => y.right == x.StatementNumber));
        }
        
        private static List<uint> GetStatementNumbers(PQLSuchThatConditionReference reference, List<EvaluatedVariable> variables, out EvaluatedVariable? selectedVariable)
        {
            selectedVariable = null;
            
            if (reference.Type == PQLSuchThatConditionReferenceType.AnyValue)
                return [(uint)SpaApi.StatementValueType.UNDEFINED];

            if (reference.Type == PQLSuchThatConditionReferenceType.Integer)
                return [(uint)reference.IntValue!.Value];

            if (reference.Type == PQLSuchThatConditionReferenceType.Variable)
            {
                selectedVariable = variables.First(x => x.VariableName == reference.VariableName);

                return selectedVariable.Elements.Select(x => x.StatementNumber).ToList();
            }

            return [];
        }

        private static uint GetStatementType(PQLSuchThatConditionReference reference, List<EvaluatedVariable> variables)
        {
            if (reference.Type == PQLSuchThatConditionReferenceType.Variable)
            {
                var selectedVariable = variables.First(x => x.VariableName == reference.VariableName);

                return (uint)selectedVariable.StatementType;
            }

            return (uint)SpaApi.StatementType.NONE;
        }

        public override string ToString() => $"Select a such that {Relation} ({LeftReference} {RightReference})";
    }
}