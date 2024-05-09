using System.Text.RegularExpressions;
using SPA.PQL.API;
using SPA.PQL.Elements;
using SPA.PQL.Enums;
using SPA.PQL.QueryElements;

namespace SPA.PQL.Parser {
    internal static class PQLParserHelper {
        public static SpaApi.StatementType? GetEntityTypesByTypeName(string typeName)
        {
            switch (typeName)
            {
                case "procedure":
                    return SpaApi.StatementType.PROCEDURE;
                case "stmtLst":
                    return SpaApi.StatementType.STMT_LIST;
                case "stmt":
                    return SpaApi.StatementType.NONE;
                case "assign":
                    return SpaApi.StatementType.ASSIGN;
                case "plus":
                    return SpaApi.StatementType.ADD;
                case "minus":
                    return SpaApi.StatementType.SUB;
                case "times":
                    return SpaApi.StatementType.MUL;
                case "variable":
                    return SpaApi.StatementType.VAR;
                case "constant":
                    return SpaApi.StatementType.CONST;
                case "while":
                    return SpaApi.StatementType.WHILE;
                case "if":
                    return SpaApi.StatementType.IF;
                case "call":
                    return SpaApi.StatementType.CALL;
                case "prog_line":
                    return SpaApi.StatementType.NONE;
            }

            return null;
        }

        public static bool IsValidVariableName(string variableName)
        {
            if (string.IsNullOrWhiteSpace(variableName))
                return false;

            if (!Regex.IsMatch(variableName, "^[a-zA-Z][a-zA-Z0-9#]*$"))
                return false;

            return true;
        }

        public static bool IsValidMetadataCall(string expression)
        {
            return Regex.IsMatch(expression, "^[a-zA-Z][a-zA-Z0-9#]*\\.[a-zA-Z0-9#]*$");
        }

        public static bool IsValidLiteral(string expression)
        {
            return Regex.IsMatch(expression, "^\"[a-zA-Z][a-zA-Z0-9#]\"$");
        }

        public static RelationType? ParseRelationName(string relationName)
        {
            switch (relationName)
            {
                case "Parent":
                    return RelationType.Parent;
                case "Parent*":
                    return RelationType.ParentAll;
                case "Next":
                    return RelationType.Next;
                case "Next*":
                    return RelationType.NextAll;
                case "Assign":
                    return RelationType.Assign;
                case "Modifies": return RelationType.Modifies;
                case "Uses":
                    return RelationType.Uses;
                case "Calls":
                    return RelationType.Calls;
                case "Calls*":
                    return RelationType.CallsAll;
                case "Follows":
                    return RelationType.Follows;
                case "Follows*":
                    return RelationType.FollowsAll;
                case "Affects":
                    return RelationType.Affects;
                case "Affects*":
                    return RelationType.AffectsAll;
            }

            return null;
        }

        public static List<KeyValuePair<ConditionType, string>> GetAllConditionSubstrings(string expression)
        {
            var result = new List<KeyValuePair<ConditionType, string>>();
            var indexes = new List<PQLConditionSubstring>();

            var suchThatMatches = Regex.Matches(expression, PQLParser.SuchThatRegex);
            var withMatches = Regex.Matches(expression, PQLParser.With);
            var patternMatches = Regex.Matches(expression, PQLParser.Pattern);

            foreach (Match item in suchThatMatches)
            {
                indexes.Add(new PQLConditionSubstring()
                {
                    Type = ConditionType.SuchThat,
                    StartIndex = item.Index,
                    TypeLength = item.Length
                });
            }

            foreach (Match item in withMatches)
            {
                indexes.Add(new PQLConditionSubstring()
                {
                    Type = ConditionType.With,
                    StartIndex = item.Index,
                    TypeLength = item.Length
                });
            }

            foreach (Match item in patternMatches)
            {
                indexes.Add(new PQLConditionSubstring()
                {
                    Type = ConditionType.Pattern,
                    StartIndex = item.Index,
                    TypeLength = item.Length
                });
            }

            indexes.Sort((a, b) => a.StartIndex.CompareTo(b.StartIndex));

            for (int i = 0; i < indexes.Count; i++)
            {
                var item = indexes[i];
                var subStringStartIndex = item.StartIndex + item.TypeLength;
                if (i < indexes.Count - 1)
                {
                    var nextItem = indexes[i + 1];
                    result.Add(new KeyValuePair<ConditionType, string>(item.Type, expression.Substring(subStringStartIndex,
                        nextItem.StartIndex - subStringStartIndex)));
                }
                else
                {
                    result.Add(new KeyValuePair<ConditionType, string>(item.Type, expression.Substring(subStringStartIndex)));
                }
            }

            return result;
        }
    }
}