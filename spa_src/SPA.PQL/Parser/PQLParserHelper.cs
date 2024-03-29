using System.Text.RegularExpressions;

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
                case "Next":
                    return true;
            }

            return false;
        }
    }
}