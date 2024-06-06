using SPA.PQL.Abstractions;
using SPA.PQL.Evaluator;
using Xunit;

namespace SPA.PQL.Tests
{
    public sealed class EvaluatorIntegrationTests
    {
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

                var variableResult = (result as VariableQueryResult)!;

                Assert.NotEmpty(variableResult.BaseResults);
                Assert.Contains(variableResult.BaseResults, x => x.StatementNumber == 3);
            }
        }

        [Fact]
        public void Test5()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/Test3.simple");

            var simpleQuery = "assign a, b, c;Select a such that Follows(b, a) and Follows (c, b)";

            using (var evaluator = new PQLEvaluator(new PKBInterface(), path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);

                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);

                var variableResult = (result as VariableQueryResult)!;

                Assert.NotEmpty(variableResult.BaseResults);
                Assert.Single(variableResult.BaseResults);
                Assert.Contains(variableResult.BaseResults, x => x.StatementNumber == 4);
            }
        }

        [Fact]
        public void Test6()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/SIMPLE_Source_test.txt");

            var simpleQuery = "stmt s;Select s such that Parent(s, 10)";

            using (var evaluator = new PQLEvaluator(new PKBInterface(), path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);
                
                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);

                var variableResult = (result as VariableQueryResult)!;

                Assert.NotEmpty(variableResult.BaseResults);
                Assert.Single(variableResult.BaseResults);
                Assert.Contains(variableResult.BaseResults, x => x.StatementNumber == 6);
            }
        }

        [Fact]
        public void Test7()
        {
            var path = Path.Combine(Environment.CurrentDirectory, "TestCodes/SIMPLE_Source_test.txt");

            var simpleQuery = "variable v;Select v such that Modifies(\"Main\", v)";
            var pkb = new PKBInterface();
            using (var evaluator = new PQLEvaluator(pkb, path))
            {
                var validationResult = evaluator.ValidateQuery(simpleQuery);

                Assert.Empty(validationResult.Errors);

                var result = evaluator.Evaluate();
                Assert.IsType<VariableQueryResult>(result);

                var variableResult = (result as VariableQueryResult)!;
            }
        }
    }
}