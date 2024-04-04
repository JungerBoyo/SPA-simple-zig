namespace SPA.Simple.Elements {
    public class ProgramElement {
        public int LineNumber { get; set; }
        public ProgramElementType Type { get; set; }
        public required Dictionary<string, string> Metadata { get; set; }
    }
}