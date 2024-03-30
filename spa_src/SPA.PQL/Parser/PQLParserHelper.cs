using System.Text.RegularExpressions;
using SPA.PQL.Enums;
using SPA.PQL.QueryElements;

namespace SPA.PQL.Parser {
    internal static class PQLParserHelper {
        private static readonly string[] ProcedureEntityTypes = ["Procedure"];
        private static readonly string[] StatementListEntityTypes = ["StatementList"];

        private static readonly string[] StatementEntityTypes =
            ["Assign", "Call", "Plus", "Minus", "Times", "Variable", "Constant", "While", "If"];

        private static readonly string[] AssignEntityTypes = ["Assign"];
        private static readonly string[] PlusEntityTypes = ["Plus"];
        private static readonly string[] MinusEntityTypes = ["Minus"];
        private static readonly string[] TimesEntityTypes = ["Times"];
        private static readonly string[] VariableEntityTypes = ["Variable"];
        private static readonly string[] ConstantEntityTypes = ["Constant"];
        private static readonly string[] WhileEntityTypes = ["While"];
        private static readonly string[] IfEntityTypes = ["If"];
        private static readonly string[] CallEntityTypes = ["Call"];
        private static readonly string[] ProgramLineEntityTypes = ["Line"];

        public static string[] GetEntityTypesByTypeName(string typeName)
        {
            switch (typeName)
            {
                case "procedure":
                    return ProcedureEntityTypes;
                case "stmtLst":
                    return StatementListEntityTypes;
                case "stmt":
                    return StatementEntityTypes;
                case "assign":
                    return AssignEntityTypes;
                case "plus":
                    return PlusEntityTypes;
                case "minus":
                    return MinusEntityTypes;
                case "times":
                    return TimesEntityTypes;
                case "variable":
                    return VariableEntityTypes;
                case "constant":
                    return ConstantEntityTypes;
                case "while":
                    return WhileEntityTypes;
                case "if":
                    return IfEntityTypes;
                case "call":
                    return CallEntityTypes;
                case "prog_line":
                    return ProgramLineEntityTypes;
            }

            return Array.Empty<string>();
        }

        public static bool IsValidVariableName(string variableName)
        {
            if (string.IsNullOrWhiteSpace(variableName))
                return false;

            if (!Regex.IsMatch(variableName, "^[a-zA-Z][a-zA-Z0-9#]*$"))
                return false;

            if (GetEntityTypesByTypeName(variableName).Length > 0)
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

        public static bool IsValidRelationName(string relationName)
        {
            switch (relationName)
            {
                case "Parent":
                case "Parent*":
                case "Next":
                case "Next*":
                case "Assign":
                case "Modifies":
                case "Uses":
                case "Calls":
                case "Calls*":
                case "Follows":
                case "Follows*":
                case "Affects":
                case "Affects*":
                    return true;
            }

            return false;
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