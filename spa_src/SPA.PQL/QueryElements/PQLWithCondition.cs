using SPA.PQL.Abstractions;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLWithCondition : PQLBaseCondition {
        public required PQLWithConditionReference LeftReference { get; set; }
        public required PQLWithConditionReference RightReference { get; set; }
    }
}