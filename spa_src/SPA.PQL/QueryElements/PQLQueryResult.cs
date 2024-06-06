namespace SPA.PQL.QueryElements {
    internal sealed class PQLQueryResult {
        public required bool IsBooleanResult { get; set; }
        public required List<string> VariableNames { get; set; }
    }
}