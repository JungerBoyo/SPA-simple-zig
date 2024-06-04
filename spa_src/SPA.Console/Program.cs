using SPA.PQL;
using SPA.PQL.Abstractions;
using static System.Console;

var path = args[0];

using var evaluator = new PQLEvaluator(new PKBInterface(), path);

bool isProgramEnd = false;

WriteLine("Ready");

while (!isProgramEnd)
{
    var statements = ReadLine();
    var query = ReadLine();
    var pqlQuery = statements + query;
    var validationResult = evaluator.ValidateQuery(pqlQuery);
    if (validationResult.Errors.Count > 0)
    {
        Write("#");
        foreach(var error in validationResult.Errors)
        {
            Write(error);
        }
    }
    else
    {
        var result = evaluator.Evaluate();
        WriteLine(result.ToString());
    }
}