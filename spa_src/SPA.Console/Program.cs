using SPA.PQL;
using SPA.PQL.Abstractions;
using SPA.PQL.API;

var _simpleProgram = "procedure p {\nx=1;\nx = 1;\n}";
var _pqlQuery = "assign a, b;\nSelect a such that Parent(_, b)";

var path = $"C:\\Users\\PiotrSzuflicki\\Desktop\\Test\\simple.txt";
File.WriteAllText(path, _simpleProgram);

using (var evaluator = new PQLEvaluator(_pqlQuery, new PKBInterface()))
{
    var _validationResult = evaluator.ValidateQuery();

    if (_validationResult.Errors.Count > 0)
        return;

    var result = evaluator.Evaluate(path);
    //Console.WriteLine(result.ToString());
    Console.ReadLine();
}