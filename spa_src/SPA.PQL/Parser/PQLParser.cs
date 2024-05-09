using System.Runtime.CompilerServices;
using SPA.PQL.Abstractions;
using SPA.PQL.Enums;
using SPA.PQL.Exceptions;
using SPA.PQL.QueryElements;

[assembly: InternalsVisibleTo("SPA.PQL.Tests")]

namespace SPA.PQL.Parser {
    internal class PQLParser {
        private readonly StringSplitOptions _tripOptions = StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries;
        internal const string SuchThatRegex = "such\\s+that";
        internal const string That = "that";
        internal const string With = "with";
        internal const string Pattern = "pattern";
        private const string Select = "Select";
        private static readonly string[] ConditionKeyWords = [SuchThatRegex, With, Pattern];

        internal PQLQuery Parse(string query)
        {
            //Here we shall separate the variables declarations and query
            var expressions = query.Split(';', _tripOptions);

            var result = new PQLQuery()
            {
                Variables = ParseVariables(expressions[..^1]).ToList(),
                QueryResult = ParseQueryResult(expressions[^1]),
                Conditions = ParseConditions(expressions[^1]).ToList(),
            };
            
            return result;
        }

        internal PQLQueryResult ParseQueryResult(string expression)
        {
            var selectIndex = expression.IndexOf(Select, StringComparison.InvariantCulture);

            if (selectIndex < 0)
                throw new InvalidSelectDeclarationException(expression);

            if (expression.Length <= selectIndex + Select.Length)
                throw new InvalidSelectDeclarationException(expression);

            var endIndexOfSelectExpression = expression.IndexOfAny(ConditionKeyWords);
            if (endIndexOfSelectExpression > 0 && expression.Length < endIndexOfSelectExpression - 1 + selectIndex + Select.Length)
                throw new InvalidSelectDeclarationException(expression);

            var selectExpression = (endIndexOfSelectExpression > 0
                ? expression.Substring(selectIndex + Select.Length, endIndexOfSelectExpression - 1 - (selectIndex + Select.Length))
                : expression.Substring(selectIndex + Select.Length)).Trim();

            if (selectExpression[0] == '<' && selectExpression[^1] == '>')
            {
                var variablesReturned = selectExpression.Substring(1, selectExpression.Length - 2)
                    .Split(',', StringSplitOptions.TrimEntries);

                foreach (var variableName in variablesReturned)
                {
                    if (!PQLParserHelper.IsValidVariableName(variableName))
                        throw new InvalidSelectDeclarationException(expression);
                }

                return new PQLQueryResult()
                {
                    IsBooleanResult = false,
                    VariableNames = variablesReturned,
                };
            }

            if (!PQLParserHelper.IsValidVariableName(selectExpression))
                throw new InvalidSelectDeclarationException(expression);

            if (selectExpression == "BOOLEAN")
            {
                return new PQLQueryResult()
                {
                    IsBooleanResult = true,
                    VariableNames = Array.Empty<string>(),
                };
            }
            
            return new PQLQueryResult()
            {
                IsBooleanResult = false,
                VariableNames = [selectExpression],
            };
        }

        internal IEnumerable<PQLVariable> ParseVariables(IEnumerable<string> variableDeclarations)
        {
            foreach (var variableDeclaration in variableDeclarations)
            {
                var tokens = variableDeclaration.SplitAt("\\s+");
                if (tokens.Length != 2)
                    throw new InvalidVariableDeclarationException(variableDeclaration);

                var entityType = PQLParserHelper.GetEntityTypesByTypeName(tokens[0]);
                if (entityType is null)
                    throw new InvalidVariableDeclarationException(variableDeclaration);

                var variableNames = tokens[1].Split(',', StringSplitOptions.TrimEntries);

                foreach (var variableName in variableNames)
                {
                    if (!PQLParserHelper.IsValidVariableName(variableName))
                        throw new InvalidVariableDeclarationException(variableDeclaration);

                    yield return new PQLVariable()
                    {
                        EntityType = entityType.Value,
                        Name = variableName
                    };
                }
            }
        }

        internal IEnumerable<PQLBaseCondition> ParseConditions(string expression)
        {
            var conditionSubstrings = PQLParserHelper.GetAllConditionSubstrings(expression);

            foreach (var conditionGroup in conditionSubstrings)
            {
                foreach (var condition in conditionGroup.Value.Split("and", StringSplitOptions.TrimEntries))
                {
                    switch (conditionGroup.Key)
                    {
                        case ConditionType.SuchThat:
                            yield return ParseSuchThatCondition(condition);
                            break;
                        case ConditionType.With:
                            yield return ParseWithCondition(condition);
                            break;
                        default:
                            throw new ArgumentOutOfRangeException();
                    }
                }
            }
        }
        
        private PQLWithCondition ParseWithCondition(string condition)
        {
            var tokens = condition.Split('=', StringSplitOptions.TrimEntries);

            if (tokens.Length != 2)
                throw new InvalidWithConditionDeclarationException(condition);

            return new PQLWithCondition()
            {
                LeftReference = ParseWithConditionReference(tokens[0]),
                RightReference = ParseWithConditionReference(tokens[1]),
            };
        }

        private PQLWithConditionReference ParseWithConditionReference(string expression)
        {
            if (string.IsNullOrWhiteSpace(expression))
                throw new InvalidWithConditionDeclarationException(expression);

            if (PQLParserHelper.IsValidMetadataCall(expression))
            {
                var tokens = expression.Split('.');

                return new PQLWithConditionReference()
                {
                    Type = PQLWithConditionReferenceType.Metadata,
                    VariableName = tokens[0],
                    MetadataFieldName = tokens[1],
                };
            }

            if (int.TryParse(expression, out var literalInt))
            {
                return new PQLWithConditionReference()
                {
                    Type = PQLWithConditionReferenceType.Integer,
                    IntValue = literalInt,
                };
            }
            
            if (PQLParserHelper.IsValidLiteral(expression))
            {
                var literal = expression.Replace("\"", string.Empty);

                return new PQLWithConditionReference()
                {
                    Type = PQLWithConditionReferenceType.TextValue,
                    TextValue = literal,
                };
            }

            if (PQLParserHelper.IsValidVariableName(expression))
            {
                return new PQLWithConditionReference()
                {
                    Type = PQLWithConditionReferenceType.Variable,
                    VariableName = expression,
                };
            }

            throw new InvalidWithConditionDeclarationException(expression);
        }

        private PQLSuchThatCondition ParseSuchThatCondition(string condition)
        {
            var leftParenthesisIndex = condition.IndexOf('(');
            var rightParenthesisIndex = condition.IndexOf(')');

            if (leftParenthesisIndex < 0 || rightParenthesisIndex < 0 || leftParenthesisIndex > rightParenthesisIndex)
                throw new InvalidSuchThatConditionDeclarationException(condition);

            string relationName = condition.Substring(0, leftParenthesisIndex).Trim();

            var relationType = PQLParserHelper.ParseRelationName(relationName);
            
            if (relationType is null)
                throw new InvalidSuchThatConditionDeclarationException(condition);

            int callArgumentsLiteralLength = rightParenthesisIndex - leftParenthesisIndex - 1;

            if (callArgumentsLiteralLength <= 0)
                throw new InvalidSuchThatConditionDeclarationException(condition);
            
            string relationCallArguments = condition.Substring(leftParenthesisIndex + 1, callArgumentsLiteralLength);

            if (string.IsNullOrWhiteSpace(relationCallArguments))
                throw new InvalidSuchThatConditionDeclarationException(condition);

            var arguments = relationCallArguments.Split(',', StringSplitOptions.TrimEntries);

            if (arguments.Length != 2)
                throw new InvalidSuchThatConditionDeclarationException(condition);

            return new PQLSuchThatCondition()
            {
                Relation = relationType.Value,
                LeftReference = ParseSuchThatConditionReference(arguments[0]),
                RightReference = ParseSuchThatConditionReference(arguments[1]),
            };
        }

        private PQLSuchThatConditionReference ParseSuchThatConditionReference(string expression)
        {
            if (string.IsNullOrWhiteSpace(expression))
                throw new InvalidSuchThatConditionDeclarationException(expression);

            if (expression == "_")
            {
                return new PQLSuchThatConditionReference()
                {
                    Type = PQLSuchThatConditionReferenceType.AnyValue,
                };
            }
            
            if (int.TryParse(expression, out var literalInt))
            {
                return new PQLSuchThatConditionReference()
                {
                    Type = PQLSuchThatConditionReferenceType.Integer,
                    IntValue = literalInt,
                };
            }
            
            if (PQLParserHelper.IsValidLiteral(expression))
            {
                return new PQLSuchThatConditionReference()
                {
                    Type = PQLSuchThatConditionReferenceType.TextValue,
                    TextValue = expression.Substring(1, expression.Length - 2),
                };
            }

            if (PQLParserHelper.IsValidVariableName(expression))
            {
                return new PQLSuchThatConditionReference()
                {
                    Type = PQLSuchThatConditionReferenceType.Variable,
                    VariableName = expression,
                };
            }

            throw new InvalidSuchThatConditionDeclarationException(expression);
        }
    }
}