namespace SPA.PQL.QueryElements {
    internal class PQLQueryResult {
        public required bool IsBooleanResult { get; set; }
        public required string[] VariableNames { get; set; }
    }
}