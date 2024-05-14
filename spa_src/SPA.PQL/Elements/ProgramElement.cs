using SPA.PQL.API;

namespace SPA.PQL.Elements {
    public sealed class ProgramElement {
        public int LineNumber { get; set; }
        public SpaApi.StatementType Type { get; set; }
        public uint StatementNumber { get; set; }
    }
}