namespace SPA.PQL.QueryElements {
    internal sealed class PQLVariable {
        public required string Name { get; init; }
        public required string[] EntitiesTypes { get; init; }
    }
}