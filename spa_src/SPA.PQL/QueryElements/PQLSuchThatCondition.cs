using SPA.PQL.Abstractions;

namespace SPA.PQL.QueryElements {
    internal sealed class PQLSuchThatCondition : PQLBaseCondition {
        public required string RelationName { get; set; }
        public required PQLSuchThatConditionReference FirstValue { get; set; }
        public required PQLSuchThatConditionReference SecondValue { get; set; }
    }
}