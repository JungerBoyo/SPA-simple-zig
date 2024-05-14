namespace SPA.PQL.QueryElements {
    internal sealed class PQLQueryResult {
        public required bool IsBooleanResult { get; set; }
        public required string[] VariableNames { get; set; }
    }
}