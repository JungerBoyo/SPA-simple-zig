using SPA.PQL.Abstractions;
using SPA.PQL.API;
using SPA.PQL.Enums;
using SPA.PQL.Evaluator;
using SPA.PQL.Exceptions;
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
            if (Relation == RelationType.Calls)
            {
                //if(LeftReference)
            }
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
                    EvaluateModifies(pkbApi, variables);
                    break;
                case RelationType.Uses:
                    EvaluateUses(pkbApi, variables);
                    break;
                case RelationType.ParentAll:
                    EvaluateParentAll(pkbApi, variables);
                    break;
                case RelationType.Next:
                case RelationType.NextAll:
                case RelationType.Assign:
                case RelationType.Calls:
                    EvaluateCalls(pkbApi, variables);
                    break;
                case RelationType.CallsAll:
                    EvaluateCallsTransitive(pkbApi, variables);
                    break;
                case RelationType.FollowsAll:
                    EvaluateFollowAll(pkbApi, variables);
                    break;
                case RelationType.Affects:
                case RelationType.AffectsAll:
                    throw new NotImplementedException();
                default:
                    throw new ArgumentOutOfRangeException();
            }
        }

        private void EvaluateFollowAll(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber)
                => pkbApi.FollowsTransitive(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }

        private void EvaluateParentAll(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber)
                => pkbApi.ParentTransitive(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }

        public override IEnumerable<string> GetNamesOfVariablesUsed()
        {
            if (LeftReference.Type is PQLSuchThatConditionReferenceType.Variable)
                yield return LeftReference.VariableName!;

            if (RightReference.Type is PQLSuchThatConditionReferenceType.Variable)
                yield return RightReference.VariableName!;
        }

        private void EvaluateParent(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber)
                => pkbApi.Parent(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }

        private void EvaluateFollow(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            EvaluateRelation(pkbApi, variables, (pkbApi, leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber)
                => pkbApi.Follow(leftStatementType, leftStatementNumber, rightStatementType, rightStatementNumber));
        }

        private void EvaluateModifies(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            var rightValues = GetVariableNames(RightReference, pkbApi, variables, out var rightSelectedVariable);

            if (LeftReference.Type != PQLSuchThatConditionReferenceType.TextValue)
            {
                var leftStatementNumbers = GetStatementNumbers(LeftReference, variables, out var leftSelectedVariable);

                var pairs = new List<(uint, string)>();

                foreach (var left in leftStatementNumbers)
                {
                    foreach (var right in rightValues)
                    {
                        if (pkbApi.Modifies(left, right))
                        {
                            pairs.Add((left, right));
                        }
                    }
                }

                if (leftSelectedVariable is not null)
                {
                    leftSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item1 == x.ProgramElement.StatementNumber));
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item2 == x.ProgramElement.Metadata));
                }
            }
            else
            {
                var results = new List<string>();
                foreach (var rightValue in rightValues)
                {
                    if (pkbApi.ModifiesProc(LeftReference.TextValue!, rightValue))
                    {
                        results.Add(rightValue);
                    }
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !results.Any(y => y == x.ProgramElement.Metadata));
                }
                else
                {
                    if (results.Count == 0)
                        throw new EvaluationException("No results");
                }
            }
        }

        private void EvaluateUses(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            var rightValues = GetVariableNames(RightReference, pkbApi, variables, out var rightSelectedVariable);

            if (LeftReference.Type != PQLSuchThatConditionReferenceType.TextValue)
            {
                var leftStatementNumbers = GetStatementNumbers(LeftReference, variables, out var leftSelectedVariable);

                var pairs = new List<(uint, string)>();

                foreach (var left in leftStatementNumbers)
                {
                    foreach (var right in rightValues)
                    {
                        if (pkbApi.Uses(left, right))
                        {
                            pairs.Add((left, right));
                        }
                    }
                }

                if (leftSelectedVariable is not null)
                {
                    leftSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item1 == x.ProgramElement.StatementNumber));
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item2 == x.ProgramElement.Metadata));
                }
            }
            else
            {
                var results = new List<string>();
                foreach (var rightValue in rightValues)
                {
                    if (pkbApi.UsesProc(LeftReference.TextValue!, rightValue))
                    {
                        results.Add(rightValue);
                    }
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !results.Any(y => y == x.ProgramElement.Metadata));
                }
                else
                {
                    if (results.Count == 0)
                        throw new EvaluationException("No results");
                }
            }
        }
        
        public void EvaluateCalls(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            var rightValues = GetVariableNames(RightReference, pkbApi, variables, out var rightSelectedVariable);

            if (LeftReference.Type != PQLSuchThatConditionReferenceType.TextValue)
            {
                var leftStatementNumbers = GetValueIds(LeftReference, variables, out var leftSelectedVariable);

                var pairs = new List<(uint, string)>();

                foreach (var left in leftStatementNumbers)
                {
                    foreach (var right in rightValues)
                    {
                        var leftName = pkbApi.GetProcedureName(left);
                        
                        foreach (var variable in variables.SelectMany(x => x.Elements).Where(x => x.ProgramElement.ValueId == left))
                        {
                            variable.ProgramElement.Metadata = leftName;
                        }
                        
                        if (pkbApi.Calls(leftName, right))
                        {
                            pairs.Add((left, right));
                        }
                    }
                }

                if (leftSelectedVariable is not null)
                {
                    leftSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item1 == x.ProgramElement.StatementNumber));
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item2 == x.ProgramElement.Metadata));
                }
            }
            else
            {
                var results = new List<string>();
                foreach (var rightValue in rightValues)
                {
                    if (pkbApi.Calls(LeftReference.TextValue!, rightValue))
                    {
                        results.Add(rightValue);
                    }
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !results.Any(y => y == x.ProgramElement.Metadata));
                }
                else
                {
                    if (results.Count == 0)
                        throw new EvaluationException("No results");
                }
            }
        }

        public void EvaluateCallsTransitive(IPKBInterface pkbApi, List<EvaluatedVariable> variables)
        {
            var rightValues = GetVariableNames(RightReference, pkbApi, variables, out var rightSelectedVariable);

            if (LeftReference.Type != PQLSuchThatConditionReferenceType.TextValue)
            {
                var leftStatementNumbers = GetValueIds(LeftReference, variables, out var leftSelectedVariable);

                var pairs = new List<(uint, string)>();

                foreach (var left in leftStatementNumbers)
                {
                    foreach (var right in rightValues)
                    {
                        var leftName = pkbApi.GetProcedureName(left);
                        
                        foreach (var variable in variables.SelectMany(x => x.Elements).Where(x => x.ProgramElement.ValueId == left))
                        {
                            variable.ProgramElement.Metadata = leftName;
                        }
                        
                        if (pkbApi.CallsTransitive(leftName, right))
                        {
                            pairs.Add((left, right));
                        }
                    }
                }

                if (leftSelectedVariable is not null)
                {
                    leftSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item1 == x.ProgramElement.StatementNumber));
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !pairs.Any(y => y.Item2 == x.ProgramElement.Metadata));
                }
            }
            else
            {
                var results = new List<string>();
                foreach (var rightValue in rightValues)
                {
                    if (pkbApi.CallsTransitive(LeftReference.TextValue!, rightValue))
                    {
                        results.Add(rightValue);
                    }
                }

                if (rightSelectedVariable is not null)
                {
                    rightSelectedVariable.Elements.RemoveAll(x => !results.Any(y => y == x.ProgramElement.Metadata));
                }
                else
                {
                    if (results.Count == 0)
                        throw new EvaluationException("No results");
                }
            }
        }
        
        private List<string> GetVariableNames(PQLSuchThatConditionReference reference, IPKBInterface pkbApi,
            List<EvaluatedVariable> variables, out EvaluatedVariable? variable)
        {
            variable = null;
            if (reference.Type == PQLSuchThatConditionReferenceType.TextValue)
                return [reference.TextValue!];

            if (reference.Type == PQLSuchThatConditionReferenceType.Variable)
            {
                variable = variables.FirstOrDefault(x => x.VariableName == reference.VariableName);

                if (variable is not null)
                {
                    foreach (var element in variable.Elements.Where(x => x.ProgramElement.ValueId > 0))
                    {
                        element.ProgramElement.Metadata = element.ProgramElement.Type == SpaApi.StatementType.VAR ? pkbApi.GetVariableName(element.ProgramElement.ValueId) : pkbApi.GetProcedureName(element.ProgramElement.ValueId);
                    }

                    return variable.Elements.Where(x => x.ProgramElement.Metadata is not null)
                        .Select(x => x.ProgramElement.Metadata!).Distinct().ToList();
                }
            }

            throw new NotSupportedException("Wrong issues");
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

            foreach (var item in results)
            {
                var left = leftSelectedVariable?.Elements.FirstOrDefault(x => x.ProgramElement.StatementNumber == item.left);
                var right = rightSelectedVariable?.Elements.FirstOrDefault(x => x.ProgramElement.StatementNumber == item.right);
                
                if (left is not null && right is not null)
                {
                    left.Depends.Add(KeyValuePair.Create(rightSelectedVariable!, right.ProgramElement));
                    right.Depends.Add(KeyValuePair.Create(leftSelectedVariable!, left.ProgramElement));
                }
            }
            
            leftSelectedVariable?.Elements.RemoveAll(x => !results.Any(y => y.left == x.ProgramElement.StatementNumber));

            rightSelectedVariable?.Elements.RemoveAll(x => !results.Any(y => y.right == x.ProgramElement.StatementNumber));
        }

        private static List<uint> GetStatementNumbers(PQLSuchThatConditionReference reference, List<EvaluatedVariable> variables,
            out EvaluatedVariable? selectedVariable)
        {
            selectedVariable = null;

            if (reference.Type == PQLSuchThatConditionReferenceType.AnyValue)
                return [(uint)SpaApi.StatementValueType.UNDEFINED];

            if (reference.Type == PQLSuchThatConditionReferenceType.Integer)
                return [(uint)reference.IntValue!.Value];

            if (reference.Type == PQLSuchThatConditionReferenceType.Variable)
            {
                selectedVariable = variables.First(x => x.VariableName == reference.VariableName);

                return selectedVariable.Elements.Select(x => x.ProgramElement.StatementNumber).Distinct().ToList();
            }

            return [];
        }
        
        private static List<uint> GetValueIds(PQLSuchThatConditionReference reference, List<EvaluatedVariable> variables,
            out EvaluatedVariable? selectedVariable)
        {
            selectedVariable = null;

            if (reference.Type == PQLSuchThatConditionReferenceType.AnyValue)
                return [(uint)SpaApi.StatementValueType.UNDEFINED];

            if (reference.Type == PQLSuchThatConditionReferenceType.Integer)
                return [(uint)reference.IntValue!.Value];

            if (reference.Type == PQLSuchThatConditionReferenceType.Variable)
            {
                selectedVariable = variables.First(x => x.VariableName == reference.VariableName);

                return selectedVariable.Elements.Select(x => x.ProgramElement.ValueId).Distinct().ToList();
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