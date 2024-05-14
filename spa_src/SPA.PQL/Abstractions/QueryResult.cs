namespace SPA.PQL.Abstractions;

public abstract class QueryResult(IEnumerable<string> queries)
{
    protected IEnumerable<string>? Results { get; init; }

    public override string ToString()
    {
        if (Results == null)
            return "Not computed";

        var resultsList = Results.ToList();
        return $"{string.Join("\n", queries)}\n{(resultsList.Count == 0 ? "none" : string.Join("\n", resultsList))}";
    }
}