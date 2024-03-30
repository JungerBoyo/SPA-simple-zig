const std = @import("std");


const SpaApi = @import("spa_api.zig");
const ErrorEnum = SpaApi.ErrorEnum;
const Error = SpaApi.Error;
const errorToEnum = SpaApi.errorToEnum;

test "spa-api#0" {
    //try std.testing.expectEqual(@as(c_uint, 0), SpaApi.spaInit("../../cs_src/test.simple"));
    //try std.testing.expectEqual(@as(c_uint, 0), SpaApi.spaDeinit());
}

test "errors enum generation" {
    try std.testing.expect(.SIMPLE_FILE_OPEN_ERROR == errorToEnum(error.SIMPLE_FILE_OPEN_ERROR));
    try std.testing.expect(.TRIED_TO_DEINIT_EMPTY_INSTANCE == errorToEnum(error.TRIED_TO_DEINIT_EMPTY_INSTANCE));
    try std.testing.expect(.TOKENIZER_OUT_OF_MEMORY == errorToEnum(error.TOKENIZER_OUT_OF_MEMORY));
    try std.testing.expect(.SIMPLE_STREAM_READING_ERROR == errorToEnum(error.SIMPLE_STREAM_READING_ERROR));
    try std.testing.expect(.UNEXPECTED_CHAR == errorToEnum(error.UNEXPECTED_CHAR));
    try std.testing.expect(.PARSER_OUT_OF_MEMORY == errorToEnum(error.PARSER_OUT_OF_MEMORY));
    try std.testing.expect(.NO_MATCHING_RIGHT_PARENTHESIS == errorToEnum(error.NO_MATCHING_RIGHT_PARENTHESIS));
    try std.testing.expect(.WRONG_FACTOR == errorToEnum(error.WRONG_FACTOR));
    try std.testing.expect(.SEMICOLON_NOT_FOUND_AFTER_ASSIGN == errorToEnum(error.SEMICOLON_NOT_FOUND_AFTER_ASSIGN));
    try std.testing.expect(.ASSIGN_CHAR_NOT_FOUND == errorToEnum(error.ASSIGN_CHAR_NOT_FOUND));
    try std.testing.expect(.SEMICOLON_NOT_FOUND_AFTER_CALL == errorToEnum(error.SEMICOLON_NOT_FOUND_AFTER_CALL));
    try std.testing.expect(.CALLED_PROCEDURE_NAME_NOT_FOUND == errorToEnum(error.CALLED_PROCEDURE_NAME_NOT_FOUND));
    try std.testing.expect(.THEN_KEYWORD_NOT_FOUND == errorToEnum(error.THEN_KEYWORD_NOT_FOUND));
    try std.testing.expect(.MATCHING_ELSE_CLOUSE_NOT_FOUND == errorToEnum(error.MATCHING_ELSE_CLOUSE_NOT_FOUND));
    try std.testing.expect(.VAR_NAME_NOT_FOUND == errorToEnum(error.VAR_NAME_NOT_FOUND));
    try std.testing.expect(.TOO_FEW_STATEMENTS == errorToEnum(error.TOO_FEW_STATEMENTS));
    try std.testing.expect(.INVALID_STATEMENT == errorToEnum(error.INVALID_STATEMENT));
    try std.testing.expect(.RIGHT_BRACE_NOT_FOUND == errorToEnum(error.RIGHT_BRACE_NOT_FOUND));
    try std.testing.expect(.LEFT_BRACE_NOT_FOUND == errorToEnum(error.LEFT_BRACE_NOT_FOUND));
    try std.testing.expect(.KEYWORD_NOT_FOUND == errorToEnum(error.KEYWORD_NOT_FOUND));
    try std.testing.expect(.PROCEDURE_NAME_NOT_FOUND == errorToEnum(error.PROCEDURE_NAME_NOT_FOUND));
}