using SPA.PQL.Enums;

namespace SPA.PQL.QueryElements {
    public struct PQLConditionSubstring {
        public ConditionType Type { get; set; }
        public int StartIndex { get; set; }
        public int TypeLength { get; set; }
    }
}