using SPA.PQL.API;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLVariable {
        public required string Name { get; init; }
        public required SpaApi.StatementType EntityType { get; init; }
    }
}