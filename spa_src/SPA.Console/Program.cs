using SPA.PQL;
using SPA.PQL.Abstractions;
using static System.Console;

var _simpleProgram = "procedure p {\nx=1;\nx = 1;\n}";
var _pqlQuery = "assign a, b;\nSelect a with\"ab\" = \"ab\"";

// assign a, b; select b such that Parent("x", a) and Follows(a, b)

var path = $"C:\\Users\\PiotrSzuflicki\\Desktop\\Test\\simple.txt";
File.WriteAllText(path, _simpleProgram);

using (var evaluator = new PQLEvaluator(_pqlQuery, new PKBInterface()))
{
    var _validationResult = evaluator.ValidateQuery();

    if (_validationResult.Errors.Count > 0)
        return;

var result = evaluator.Evaluate(path);
WriteLine(result.ToString());
WriteLine("Press any key to exit...");
ReadLine();