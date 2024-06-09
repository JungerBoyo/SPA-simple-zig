using SPA.PQL.API;

namespace SPA.PQL.Elements {
    public sealed class ProgramElement {
        public int LineNumber { get; set; }
        public SpaApi.StatementType Type { get; set; }
        public uint StatementNumber { get; set; }
        public uint ValueId { get; set; }
        public string? Metadata { get; set; }
        public uint? Index { get; set; }

        public override string ToString()
        {
            return Type == SpaApi.StatementType.VAR || Type == SpaApi.StatementType.PROCEDURE ? Metadata! : StatementNumber.ToString();
        }
    }
}