using Microsoft.AspNetCore.Components.Web;
using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using SPA.PQL.Parser;

namespace SPA.Components.Pages
{
    public partial class Home {
        private string _pqlQuery = string.Empty;
        private string _simpleProgram = string.Empty;
        private PQLQueryValidationResult? _validationResult;
        private QueryResult? _result;

        public void Evaluate(MouseEventArgs obj)
        {
            var path = $"/{Guid.NewGuid()}.txt";
            File.WriteAllText(path, _simpleProgram);

            using var evaluator = new PQLEvaluator(new PKBInterface(), path);

            _validationResult = evaluator.ValidateQuery(_pqlQuery);

            if (_validationResult.Errors.Count > 0)
                return;

            _result = evaluator.Evaluate();
        }
    }
}