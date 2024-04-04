using System.Text.RegularExpressions;
using SPA.PQL.Enums;
using SPA.PQL.QueryElements;
using SPA.Simple.Elements;

namespace SPA.PQL.Parser {
    internal static class PQLParserHelper {
        private static readonly ProgramElementType[] ProcedureEntityTypes = [ProgramElementType.Procedure];
        private static readonly ProgramElementType[] StatementListEntityTypes = [ProgramElementType.StatementList];

        private static readonly ProgramElementType[] StatementEntityTypes =
        [
            ProgramElementType.Assign, ProgramElementType.Call, ProgramElementType.Plus, ProgramElementType.Minus,
            ProgramElementType.Times, ProgramElementType.Variable, ProgramElementType.Constant,
            ProgramElementType.While, ProgramElementType.If
        ];

        private static readonly ProgramElementType[] AssignEntityTypes = [ProgramElementType.Assign];
        private static readonly ProgramElementType[] PlusEntityTypes = [ProgramElementType.Plus];
        private static readonly ProgramElementType[] MinusEntityTypes = [ProgramElementType.Minus];
        private static readonly ProgramElementType[] TimesEntityTypes = [ProgramElementType.Times];
        private static readonly ProgramElementType[] VariableEntityTypes = [ProgramElementType.Variable];
        private static readonly ProgramElementType[] ConstantEntityTypes = [ProgramElementType.Constant];
        private static readonly ProgramElementType[] WhileEntityTypes = [ProgramElementType.While];
        private static readonly ProgramElementType[] IfEntityTypes = [ProgramElementType.If];
        private static readonly ProgramElementType[] CallEntityTypes = [ProgramElementType.Call];
        private static readonly ProgramElementType[] ProgramLineEntityTypes = [ProgramElementType.StatementList];

        public static ProgramElementType[] GetEntityTypesByTypeName(string typeName)
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

            return Array.Empty<ProgramElementType>();
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