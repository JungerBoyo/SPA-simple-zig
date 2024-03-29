namespace SPA.PQL.QueryElements {
    internal class PQLSuchThatConditionReference {
        public required PQLSuchThatConditionReferenceType Type { get; set; }
        public string? VariableName { get; set; }
        public string? TextValue { get; set; }
        public int? IntValue { get; set; }
    }
    
    internal enum PQLSuchThatConditionReferenceType {
        Variable = 1,
        AnyValue = 2,
        TextValue = 3,
        Integer = 4,
    }
}