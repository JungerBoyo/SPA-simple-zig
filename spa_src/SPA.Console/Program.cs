using SPA.PQL;
using SPA.PQL.Abstractions;
using static System.Console;

const string simpleProgram = "procedure p {\nx=1;\nx = 1;\n}";
const string pqlQuery = "assign a, b;\nSelect a such that Parent(_, b)";

var path = $"{AppContext.BaseDirectory}/simple.txt";
File.WriteAllText(path, simpleProgram);

using var evaluator = new PQLEvaluator(pqlQuery, new PKBInterface());
var validationResult = evaluator.ValidateQuery();

if (validationResult.Errors.Count > 0)
    return;

var result = evaluator.Evaluate(path);
WriteLine(result.ToString());
WriteLine("Press any key to exit...");
ReadLine();