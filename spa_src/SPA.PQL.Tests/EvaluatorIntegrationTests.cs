using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using Xunit;

namespace SPA.PQL.Tests {
    public sealed class EvaluatorIntegrationTests {

        [Fact]
        public void Test1()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/Test1.simple");

            var simpleQuery = "assign x; Select x";

            using (var evaluator = new PQLEvaluator(simpleQuery, new PKBInterface()))
            {
                var validationResult = evaluator.ValidateQuery();

                Assert.Empty(validationResult.Errors);
                
                var result = evaluator.Evaluate(path);
                Assert.IsType<VariableQueryResult>(result);
                var casted = result as VariableQueryResult;
            }
        }
    }
}