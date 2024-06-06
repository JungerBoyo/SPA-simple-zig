using SPA.PQL.Abstractions;
using SPA.PQL.QueryElements;

namespace SPA.PQL.Parser {
    internal sealed class PQLQuery {
        public required List<PQLVariable> Variables { get; set; }
        public required PQLQueryResult QueryResult { get; set; }
        public required List<PQLBaseCondition> Conditions { get; set; }

        public PQLQueryValidationResult ValidateQuery()
        {
            var result = new PQLQueryValidationResult();
            
            //Check if there are to variables declared with same name
            var duplicatedNames = Variables.GroupBy(x => x.Name).Where(x => x.Count() > 1).Select(x => x.First().Name);

            foreach (var variableName in duplicatedNames)
            {
                result.Errors.Add($"Two or more variables with same name: {variableName}");
            }
            
            //Validate result. If it's boolean, or whether it returns variables, that were declared

            if (QueryResult.VariableNames.Contains("BOOLEAN"))
            {
                if(QueryResult.VariableNames.Count > 1)
                    result.Errors.Add($"If we're returning BOOLEAN result, we cannot return any other variables");
            }
            else
            {
                foreach (var item in QueryResult.VariableNames.Where(x => !Variables.Any(y => y.Name == x)))
                {
                    result.Errors.Add($"You cannot return variables that are not declared. Variable name: {item}");
                }
            }
            
            // Validate conditions
            foreach (var condition in Conditions)
            {
                condition.Validate(this, result);
            }
            
            return result;
        }
    }
}