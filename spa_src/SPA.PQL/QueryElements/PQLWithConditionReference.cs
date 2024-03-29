namespace SPA.PQL.QueryElements {
    internal sealed class PQLWithConditionReference {
        public required PQLWithConditionReferenceType Type { get; set; }
        public string? VariableName { get; set; }
        public string? MetadataFieldName { get; set; }
        public string? TextValue { get; set; }
        public int? IntValue { get; set; }
    }

    internal enum PQLWithConditionReferenceType {
        Variable = 1,
        Metadata = 2,
        TextValue = 3,
        Integer = 4,
    }
}