using SPA.PQL.Parser;

namespace SPA.PQL.Abstractions {
    internal abstract class PQLBaseCondition {
        public abstract void Validate(PQLQuery query, PQLQueryValidationResult result);
    }
}