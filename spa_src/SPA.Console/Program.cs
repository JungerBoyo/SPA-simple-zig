using SPA.PQL;
using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using static System.Console;

var path = args[0];

using var evaluator = new PQLEvaluator(new PKBInterface(), path);

bool isProgramEnd = false;

WriteLine("Ready");

while (!isProgramEnd)
{
    try
    {
        var statements = ReadLine();
        var query = ReadLine();
        var pqlQuery = statements + query;
        var validationResult = evaluator.ValidateQuery(pqlQuery);
        if (validationResult.Errors.Count > 0)
        {
            Write("#");
            foreach (var error in validationResult.Errors)
            {
                Write(error);
            }
            Write("\n");
        }
        else
        {
            var result = evaluator.Evaluate();
            WriteLine(result?.ToString());
        }
    }
    catch (Exception ex)
    {
        WriteLine($"# {ex.Message}");
    }
}