namespace SPA.PQL.QueryElements {
    internal sealed class PQLWithConditionReference {
        public required PQLWithConditionReferenceType Type { get; set; }
        public string? VariableName { get; set; }
        public string? MetadataFieldName { get; set; }
        public string? TextValue { get; set; }
        public int? IntValue { get; set; }
    }

    internal enum PQLWithConditionReferenceType {
        Metadata = 1,
        TextValue = 2,
        Integer = 3,
    }
}