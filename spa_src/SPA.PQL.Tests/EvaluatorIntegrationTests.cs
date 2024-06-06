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

            using (var evaluator = new PQLEvaluator(new PKBInterface(), path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);
                
                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);
            }
        }
        
        [Fact]
        public void Test2()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/Test1.simple");

            var simpleQuery = "procedure x; Select x";

            using (var evaluator = new PQLEvaluator(new PKBInterface(), path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);
                
                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);
            }
        }
        
        [Fact]
        public void Test3()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/Test1.simple");

            var simpleQuery = "variable x;Select x such that Modifies(\"Proc1\", x)";

            using (var evaluator = new PQLEvaluator(new PKBInterface(), path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);
                
                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);
            }
        }
        
        [Fact]
        public void Test4()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/Test2.simple");

            var simpleQuery = "assign a, b;Select a such that Follows(b, a)";

            using (var evaluator = new PQLEvaluator(new PKBInterface(), path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);
                
                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);
            }
        }
    }
}