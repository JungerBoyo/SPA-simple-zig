using SPA.Simple.Elements;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLVariable {
        public required string Name { get; init; }
        public required ProgramElementType[] EntitiesTypes { get; init; }
    }
}