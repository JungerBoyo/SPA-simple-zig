using SPA.PQL.API;
using SPA.PQL.Elements;
using SPA.PQL.Enums;
using SPA.PQL.Exceptions;
using SPA.PQL.Parser;
using SPA.PQL.QueryElements;
using Xunit;

namespace SPA.PQL.Tests;

public sealed class PQLParserTests {
    
    [Fact]
    public void Should_Parse_Single_Assign_Variable()
    {
        //prepare
        var parser = new PQLParser();
        var expressions = new string[] {"assign \na"};

        //act
        var result = parser.ParseVariables(expressions).ToList();
        
        //assert
        Assert.NotNull(result);
        Assert.Single(result);
        Assert.Equal("a", result[0].Name);
        Assert.Equal(SpaApi.StatementType.ASSIGN, result[0].EntityType);
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
        Assert.Equal(SpaApi.StatementType.ASSIGN, result[0].EntityType);
        Assert.Equal("b", result[1].Name);
        Assert.Equal(SpaApi.StatementType.ASSIGN, result[1].EntityType);
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
        Assert.Equal(SpaApi.StatementType.ASSIGN, result[0].EntityType);
        Assert.Equal("b", result[1].Name);
        Assert.Equal(SpaApi.StatementType.ASSIGN, result[1].EntityType);
    }
    
    [Fact]
    public void Should_Throw_Exception_For_Invalid_Variable_Name()
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
    public void Should_Throw_Exception_For_Missing_Variable_Name()
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
    public void Should_Throw_Exception_For_Missing_Second_Variable_Name()
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
    public void Should_Throw_Exception_For_Wrong_Tuple_Declaration()
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
    public void Should_Throw_Exception_For_Returning_Two_Variables_Without_Tuple()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1, a2 such that Parent*(_, a1)";

        //act
        Assert.Throws<InvalidSelectDeclarationException>(() => _ = parser.ParseQueryResult(expression));
    }
        
    [Fact]
    public void Should_Return_Single_SuchThat_Condition()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1, a2 such that Parent*(_, a1)";

        //act
        var value = parser.ParseConditions(expression).ToList();
        
        //assert
        Assert.Single(value);
        Assert.NotNull(value[0]);
        Assert.IsType<PQLSuchThatCondition>(value[0]);
        
        var condition = value[0] as PQLSuchThatCondition;
        
        Assert.NotNull(condition);
        Assert.NotNull(condition.LeftReference);
        Assert.NotNull(condition.RightReference);
        Assert.Equal(RelationType.ParentAll, condition.Relation);
        Assert.Equal(PQLSuchThatConditionReferenceType.AnyValue, condition.LeftReference.Type);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, condition.RightReference.Type);
        Assert.Equal("a1", condition.RightReference.VariableName);
    }    
    
    [Fact]
    public void Should_Return_Two_SuchThat_Condition_With_And()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1, a2 such that Parent*(_, a1) and Parent  (  a1  , a2  )";

        //act
        var value = parser.ParseConditions(expression).ToList();
        
        //assert
        Assert.Equal(2, value.Count);
        Assert.NotNull(value[0]);
        Assert.NotNull(value[1]);
        Assert.IsType<PQLSuchThatCondition>(value[0]);
        Assert.IsType<PQLSuchThatCondition>(value[1]);
        
        var firstCondition = value[0] as PQLSuchThatCondition;
        
        Assert.NotNull(firstCondition);
        Assert.NotNull(firstCondition.LeftReference);
        Assert.NotNull(firstCondition.RightReference);
        Assert.Equal(RelationType.ParentAll, firstCondition.Relation);
        Assert.Equal(PQLSuchThatConditionReferenceType.AnyValue, firstCondition.LeftReference.Type);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, firstCondition.RightReference.Type);
        Assert.Equal("a1", firstCondition.RightReference.VariableName);        
        
        var secondCondition = value[1] as PQLSuchThatCondition;
        
        Assert.NotNull(secondCondition);
        Assert.NotNull(secondCondition.LeftReference);
        Assert.NotNull(secondCondition.RightReference);
        Assert.Equal(RelationType.Parent, secondCondition.Relation);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, secondCondition.LeftReference.Type);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, secondCondition.RightReference.Type);
        Assert.Equal("a1", secondCondition.LeftReference.VariableName);
        Assert.Equal("a2", secondCondition.RightReference.VariableName);
    } 
    
    [Fact]
    public void Should_Return_Two_SuchThat_Condition()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1, a2 such that Parent*(_, a1) such    \n that Parent  (  a1  , a2  )";

        //act
        var value = parser.ParseConditions(expression).ToList();
        
        //assert
        Assert.Equal(2, value.Count);
        Assert.NotNull(value[0]);
        Assert.NotNull(value[1]);
        Assert.IsType<PQLSuchThatCondition>(value[0]);
        Assert.IsType<PQLSuchThatCondition>(value[1]);
        
        var firstCondition = value[0] as PQLSuchThatCondition;
        
        Assert.NotNull(firstCondition);
        Assert.NotNull(firstCondition.LeftReference);
        Assert.NotNull(firstCondition.RightReference);
        Assert.Equal(RelationType.ParentAll, firstCondition.Relation);
        Assert.Equal(PQLSuchThatConditionReferenceType.AnyValue, firstCondition.LeftReference.Type);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, firstCondition.RightReference.Type);
        Assert.Equal("a1", firstCondition.RightReference.VariableName);        
        
        var secondCondition = value[1] as PQLSuchThatCondition;
        
        Assert.NotNull(secondCondition);
        Assert.NotNull(secondCondition.LeftReference);
        Assert.NotNull(secondCondition.RightReference);
        Assert.Equal(RelationType.Parent, secondCondition.Relation);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, secondCondition.LeftReference.Type);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, secondCondition.RightReference.Type);
        Assert.Equal("a1", secondCondition.LeftReference.VariableName);
        Assert.Equal("a2", secondCondition.RightReference.VariableName);
    }
    
    [Fact]
    public void Should_Return_One_SuchThat_And_One_With_Condition()
    {
        //prepare
        var parser = new PQLParser();
        var expression = "Select a1, a2 such that Parent*(_, a1) with a1.stmt# = 3";

        //act
        var value = parser.ParseConditions(expression).ToList();
        
        //assert
        Assert.Equal(2, value.Count);
        Assert.NotNull(value[0]);
        Assert.NotNull(value[1]);
        Assert.IsType<PQLSuchThatCondition>(value[0]);
        Assert.IsType<PQLWithCondition>(value[1]);
        
        var firstCondition = value[0] as PQLSuchThatCondition;
        
        Assert.NotNull(firstCondition);
        Assert.NotNull(firstCondition.LeftReference);
        Assert.NotNull(firstCondition.RightReference);
        Assert.Equal(RelationType.ParentAll, firstCondition.Relation);
        Assert.Equal(PQLSuchThatConditionReferenceType.AnyValue, firstCondition.LeftReference.Type);
        Assert.Equal(PQLSuchThatConditionReferenceType.Variable, firstCondition.RightReference.Type);
        Assert.Equal("a1", firstCondition.RightReference.VariableName);        
        
        var secondCondition = value[1] as PQLWithCondition;
        
        Assert.NotNull(secondCondition);
        Assert.NotNull(secondCondition.LeftReference);
        Assert.NotNull(secondCondition.RightReference);
        Assert.Equal(PQLWithConditionReferenceType.Metadata, secondCondition.LeftReference.Type);
        Assert.Equal(PQLWithConditionReferenceType.Integer, secondCondition.RightReference.Type);
        Assert.Equal("a1", secondCondition.LeftReference.VariableName);
        Assert.Equal("stmt#", secondCondition.LeftReference.MetadataFieldName);
        Assert.Equal(PQLWithConditionReferenceType.Integer, secondCondition.RightReference.Type);
        Assert.Equal(3, secondCondition.RightReference.IntValue);
    }
}