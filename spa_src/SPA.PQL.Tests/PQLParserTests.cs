using SPA.PQL.Exceptions;
using SPA.PQL.Parser;
using Xunit;

namespace SPA.PQL.Tests;

public class PQLParserTests {
    
    [Fact]
    public void Should_Parse_Single_Assign_Variable()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign a"};

        //act
        var result = parser.ParseVariables(expressions).ToList();
        
        //assert
        Assert.NotNull(result);
        Assert.Single(result);
        Assert.Equal("a", result[0].Name);
        Assert.Single(result[0].EntitiesTypes);
        Assert.Equal("Assign", result[0].EntitiesTypes[0]);
    }
    
    [Fact]
    public void Should_Parse_Two_Assign_Variables_In_One_Statement()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign a,   b"};

        //act
        var result = parser.ParseVariables(expressions).ToList();
        
        //assert
        Assert.NotNull(result);
        Assert.Equal(2, result.Count);
        Assert.Equal("a", result[0].Name);
        Assert.Single(result[0].EntitiesTypes);
        Assert.Equal("Assign", result[0].EntitiesTypes[0]);
        Assert.Equal("b", result[1].Name);
        Assert.Single(result[1].EntitiesTypes);
        Assert.Equal("Assign", result[1].EntitiesTypes[0]);
    }
    
    [Fact]
    public void Should_Parse_Two_Assign_Variables_In_Two_Statements()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign a", "assign b"};

        //act
        var result = parser.ParseVariables(expressions).ToList();
        
        //assert
        Assert.NotNull(result);
        Assert.Equal(2, result.Count);
        Assert.Equal("a", result[0].Name);
        Assert.Single(result[0].EntitiesTypes);
        Assert.Equal("Assign", result[0].EntitiesTypes[0]);
        Assert.Equal("b", result[1].Name);
        Assert.Single(result[1].EntitiesTypes);
        Assert.Equal("Assign", result[1].EntitiesTypes[0]);
    }
    
    [Fact]
    public void Should_Trow_Exception_For_Invalid_Variable_Name()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign 1a"};

        //act
        Assert.Throws<InvalidVariableDeclarationException>(() =>
        {
            _ = parser.ParseVariables(expressions).ToList();
        });
    }
    
    [Fact]
    public void Should_Trow_Exception_For_Missing_Variable_Name()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign "};

        //act
        Assert.Throws<InvalidVariableDeclarationException>(() =>
        {
            _ = parser.ParseVariables(expressions).ToList();
        });
    }
    
    [Fact]
    public void Should_Trow_Exception_For_Missing_Second_Variable_Name()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign a,  "};

        //act
        Assert.Throws<InvalidVariableDeclarationException>(() =>
        {
            _ = parser.ParseVariables(expressions).ToList();
        });
    }

    [Fact]
    public void Should_Trow_Exception_For_Wrong_Tuple_Declaration()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select <  a1";

        //act
        Assert.Throws<InvalidSelectDeclarationException>(() =>
        {
            _ = parser.ParseQueryResult(expression);
        });
    }
    
    [Fact]
    public void Should_Parse_Select_And_Return_Single_Variable_Without_Tuple_And_Without_Filtering_Statements()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1";

        //act
        var result = parser.ParseQueryResult(expression);
        
        //assert
        Assert.NotNull(result);
        Assert.Single(result.VariableNames);
        Assert.Equal("a1", result.VariableNames[0]);
    }
    
    [Fact]
    public void Should_Parse_Select_And_Return_Single_Variable_Without_Tuple_And_With_Filtering_Statements()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1 such that Parent*(_, a1)";

        //act
        var result = parser.ParseQueryResult(expression);
        
        //assert
        Assert.NotNull(result);
        Assert.Single(result.VariableNames);
        Assert.Equal("a1", result.VariableNames[0]);
    }
    
    [Fact]
    public void Should_Parse_Select_And_Return_Single_Variable_With_Tuple_And_With_Filtering_Statements()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select <a1> such that Parent*(_, a1)";

        //act
        var result = parser.ParseQueryResult(expression);
        
        //assert
        Assert.NotNull(result);
        Assert.Single(result.VariableNames);
        Assert.Equal("a1", result.VariableNames[0]);
    }
        
    [Fact]
    public void Should_Parse_Select_And_Return_Two_Variables_With_Tuple_And_With_Filtering_Statements()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select <a1, a2> such that Parent*(_, a1)";

        //act
        var result = parser.ParseQueryResult(expression);
        
        //assert
        Assert.NotNull(result);
        Assert.Equal(2, result.VariableNames.Length);
        Assert.Equal("a1", result.VariableNames[0]);
        Assert.Equal("a2", result.VariableNames[1]);
    }
        
    [Fact]
    public void Should_Trow_Exception_For_Returning_Two_Variables_Without_Tuple()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1, a2 such that Parent*(_, a1)";

        //act
        Assert.Throws<InvalidSelectDeclarationException>(() => _ = parser.ParseQueryResult(expression));
    }
}