// Parser Error Code Tests
// Tests for ParserErrorCode to_int() and to_message() functions
// Tests critical parser error codes (TS1000-1185)

// ============================================================================
// Tests for ParserErrorCode::to_int()
// Verify error codes map to correct TypeScript diagnostic codes
// ============================================================================

///|
test "ParserErrorCode::to_int - string/literal errors" {
  // TS1002: Unterminated string literal
  assert_eq(@compiler.get_parser_error_int("UnterminatedStringLiteral"), 1002)
  // TS1160: Unterminated template literal
  assert_eq(@compiler.get_parser_error_int("UnterminatedTemplateLiteral"), 1160)
  // TS1161: Unterminated regex literal
  assert_eq(@compiler.get_parser_error_int("UnterminatedRegexLiteral"), 1161)
}

///|
test "ParserErrorCode::to_int - trailing comma" {
  // TS1009: Trailing comma not allowed
  assert_eq(@compiler.get_parser_error_int("TrailingCommaNotAllowed"), 1009)
}

///|
test "ParserErrorCode::to_int - rest parameter errors" {
  // TS1014: Rest parameter must be last
  assert_eq(@compiler.get_parser_error_int("RestParameterMustBeLast"), 1014)
  // TS1016: Required param after optional
  assert_eq(@compiler.get_parser_error_int("RequiredParamAfterOptional"), 1016)
  // TS1048: Rest parameter cannot be optional
  assert_eq(@compiler.get_parser_error_int("RestParameterCannotBeOptional"), 1048)
  // TS1049: Rest parameter cannot have initializer
  assert_eq(
    @compiler.get_parser_error_int("RestParameterCannotHaveInitializer"),
    1049,
  )
}

///|
test "ParserErrorCode::to_int - ambient context errors" {
  // TS1036: Statements not allowed in ambient
  assert_eq(@compiler.get_parser_error_int("StatementsNotAllowedInAmbient"), 1036)
  // TS1038: Declare in ambient context
  assert_eq(@compiler.get_parser_error_int("DeclareInAmbientContext"), 1038)
  // TS1039: Initializer not allowed in ambient
  assert_eq(@compiler.get_parser_error_int("InitializerNotAllowedInAmbient"), 1039)
  // TS1066: Ambient enum initializer must be constant
  assert_eq(
    @compiler.get_parser_error_int("AmbientEnumInitializerMustBeConstant"),
    1066,
  )
}

///|
test "ParserErrorCode::to_int - modifier errors" {
  // TS1042: Async modifier not allowed
  assert_eq(@compiler.get_parser_error_int("AsyncModifierNotAllowed"), 1042)
  // TS1044: Modifier cannot appear on class element
  assert_eq(
    @compiler.get_parser_error_int_with_arg(
      "ModifierCannotAppearOnClassElement",
      Some("static"),
    ),
    1044,
  )
  // TS1089: Modifier cannot appear on constructor
  assert_eq(
    @compiler.get_parser_error_int_with_arg(
      "ModifierCannotAppearOnConstructor",
      Some("async"),
    ),
    1089,
  )
  // TS1184: Modifiers not allowed here
  assert_eq(@compiler.get_parser_error_int("ModifiersNotAllowedHere"), 1184)
}

///|
test "ParserErrorCode::to_int - constructor errors" {
  // TS1092: Type params on constructor
  assert_eq(@compiler.get_parser_error_int("TypeParamsOnConstructor"), 1092)
}

///|
test "ParserErrorCode::to_int - accessor errors" {
  // TS1093: Set accessor cannot have return type
  assert_eq(@compiler.get_parser_error_int("SetAccessorCannotHaveReturnType"), 1093)
  // TS1094: Get accessor cannot have params
  assert_eq(@compiler.get_parser_error_int("GetAccessorCannotHaveParams"), 1094)
  // TS1095: Set accessor must have one param
  assert_eq(@compiler.get_parser_error_int("SetAccessorMustHaveOneParam"), 1095)
}

///|
test "ParserErrorCode::to_int - statement context errors" {
  // TS1108: Return outside function
  assert_eq(@compiler.get_parser_error_int("ReturnOutsideFunction"), 1108)
  // TS1110: Type expected
  assert_eq(@compiler.get_parser_error_int("TypeExpected"), 1110)
  // TS1128: Declaration or statement expected
  assert_eq(@compiler.get_parser_error_int("DeclarationOrStatementExpected"), 1128)
  // TS1131: Property or signature expected
  assert_eq(@compiler.get_parser_error_int("PropertyOrSignatureExpected"), 1131)
  // TS1141: String literal expected
  assert_eq(@compiler.get_parser_error_int("StringLiteralExpected"), 1141)
  // TS1142: Line break not permitted
  assert_eq(@compiler.get_parser_error_int("LineBreakNotPermitted"), 1142)
}

///|
test "ParserErrorCode::to_int - declaration errors" {
  // TS1155: Const declaration must be initialized
  assert_eq(
    @compiler.get_parser_error_int("ConstDeclarationMustBeInitialized"),
    1155,
  )
}

///|
test "ParserErrorCode::to_int - merge conflict" {
  // TS1185: Merge conflict marker
  assert_eq(@compiler.get_parser_error_int("MergeConflictMarker"), 1185)
}

// ============================================================================
// Tests for ParserErrorCode::to_message()
// Verify error codes return correct TypeScript error messages
// ============================================================================

///|
test "ParserErrorCode::to_message - string/literal errors" {
  assert_eq(
    @compiler.get_parser_error_message("UnterminatedStringLiteral"),
    "Unterminated string literal.",
  )
  assert_eq(
    @compiler.get_parser_error_message("UnterminatedTemplateLiteral"),
    "Unterminated template literal.",
  )
  assert_eq(
    @compiler.get_parser_error_message("UnterminatedRegexLiteral"),
    "Unterminated regular expression literal.",
  )
}

///|
test "ParserErrorCode::to_message - trailing comma" {
  assert_eq(
    @compiler.get_parser_error_message("TrailingCommaNotAllowed"),
    "Trailing comma not allowed.",
  )
}

///|
test "ParserErrorCode::to_message - rest parameter errors" {
  assert_eq(
    @compiler.get_parser_error_message("RestParameterMustBeLast"),
    "A rest parameter must be last in a parameter list.",
  )
  assert_eq(
    @compiler.get_parser_error_message("RequiredParamAfterOptional"),
    "A required parameter cannot follow an optional parameter.",
  )
  assert_eq(
    @compiler.get_parser_error_message("RestParameterCannotBeOptional"),
    "A rest parameter cannot be optional.",
  )
  assert_eq(
    @compiler.get_parser_error_message("RestParameterCannotHaveInitializer"),
    "A rest parameter cannot have an initializer.",
  )
}

///|
test "ParserErrorCode::to_message - ambient context errors" {
  assert_eq(
    @compiler.get_parser_error_message("StatementsNotAllowedInAmbient"),
    "Statements are not allowed in ambient contexts.",
  )
  assert_eq(
    @compiler.get_parser_error_message("DeclareInAmbientContext"),
    "A 'declare' modifier cannot be used in an already ambient context.",
  )
  assert_eq(
    @compiler.get_parser_error_message("InitializerNotAllowedInAmbient"),
    "Initializers are not allowed in ambient contexts.",
  )
  assert_eq(
    @compiler.get_parser_error_message("AmbientEnumInitializerMustBeConstant"),
    "In ambient enum declarations member initializer must be constant expression.",
  )
}

///|
test "ParserErrorCode::to_message - modifier errors" {
  assert_eq(
    @compiler.get_parser_error_message("AsyncModifierNotAllowed"),
    "'async' modifier cannot be used here.",
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg(
      "ModifierCannotAppearOnClassElement",
      Some("static"),
    ),
    "'static' modifier cannot appear on a class element.",
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg(
      "ModifierCannotAppearOnConstructor",
      Some("async"),
    ),
    "'async' modifier cannot appear on a constructor declaration.",
  )
  assert_eq(
    @compiler.get_parser_error_message("ModifiersNotAllowedHere"),
    "Modifiers cannot appear here.",
  )
}

///|
test "ParserErrorCode::to_message - constructor errors" {
  assert_eq(
    @compiler.get_parser_error_message("TypeParamsOnConstructor"),
    "Type parameters cannot appear on a constructor declaration.",
  )
}

///|
test "ParserErrorCode::to_message - accessor errors" {
  assert_eq(
    @compiler.get_parser_error_message("SetAccessorCannotHaveReturnType"),
    "A 'set' accessor cannot have a return type annotation.",
  )
  assert_eq(
    @compiler.get_parser_error_message("GetAccessorCannotHaveParams"),
    "An accessor cannot have parameters.",
  )
  assert_eq(
    @compiler.get_parser_error_message("SetAccessorMustHaveOneParam"),
    "A 'set' accessor must have exactly one parameter.",
  )
}

///|
test "ParserErrorCode::to_message - statement context errors" {
  assert_eq(
    @compiler.get_parser_error_message("ReturnOutsideFunction"),
    "A 'return' statement can only be used within a function body.",
  )
  assert_eq(@compiler.get_parser_error_message("TypeExpected"), "Type expected.")
  assert_eq(
    @compiler.get_parser_error_message("DeclarationOrStatementExpected"),
    "Declaration or statement expected.",
  )
  assert_eq(
    @compiler.get_parser_error_message("PropertyOrSignatureExpected"),
    "Property or signature expected.",
  )
  assert_eq(
    @compiler.get_parser_error_message("StringLiteralExpected"),
    "String literal expected.",
  )
  assert_eq(
    @compiler.get_parser_error_message("LineBreakNotPermitted"),
    "Line break not permitted here.",
  )
}

///|
test "ParserErrorCode::to_message - declaration errors" {
  assert_eq(
    @compiler.get_parser_error_message("ConstDeclarationMustBeInitialized"),
    "'const' declarations must be initialized.",
  )
}

///|
test "ParserErrorCode::to_message - merge conflict" {
  assert_eq(
    @compiler.get_parser_error_message("MergeConflictMarker"),
    "Merge conflict marker encountered.",
  )
}

///|
test "ParserErrorCode::to_message - modifier with dynamic name" {
  // Test that the parameterized error codes work with different modifiers
  assert_eq(
    @compiler.get_parser_error_message_with_arg(
      "ModifierCannotAppearOnClassElement",
      Some("private"),
    ),
    "'private' modifier cannot appear on a class element.",
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg(
      "ModifierCannotAppearOnClassElement",
      Some("public"),
    ),
    "'public' modifier cannot appear on a class element.",
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg(
      "ModifierCannotAppearOnConstructor",
      Some("static"),
    ),
    "'static' modifier cannot appear on a constructor declaration.",
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg(
      "ModifierCannotAppearOnConstructor",
      Some("readonly"),
    ),
    "'readonly' modifier cannot appear on a constructor declaration.",
  )
}

///|
test "ParserErrorCode::to_int - unknown error returns -1" {
  assert_eq(@compiler.get_parser_error_int("NonExistentError"), -1)
}

///|
test "ParserErrorCode::to_message - unknown error returns message" {
  assert_eq(
    @compiler.get_parser_error_message("NonExistentError"),
    "Unknown error",
  )
}
