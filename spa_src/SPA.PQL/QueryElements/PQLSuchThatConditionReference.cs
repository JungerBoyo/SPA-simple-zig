namespace SPA.PQL.QueryElements {
    internal sealed class PQLSuchThatConditionReference {
        public required PQLSuchThatConditionReferenceType Type { get; set; }
        public string? VariableName { get; set; }
        public string? TextValue { get; set; }
        public int? IntValue { get; set; }

        public override string ToString()
        {
            return VariableName ?? "null";
        }
    }
    
    internal enum PQLSuchThatConditionReferenceType {
        Variable = 1,
        AnyValue = 2,
        TextValue = 3,
        Integer = 4,
    }
}