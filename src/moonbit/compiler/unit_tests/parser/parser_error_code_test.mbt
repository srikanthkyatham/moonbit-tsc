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

// ============================================================================
// Tests for Decorator Error Codes
// ============================================================================

///|
test "ParserErrorCode::to_int - decorator errors" {
  // TS1206: Decorators not valid here
  assert_eq(@compiler.get_parser_error_int("DecoratorsNotValidHere"), 1206)
  // TS1219: Experimental decorators warning
  assert_eq(@compiler.get_parser_error_int("ExperimentalDecoratorsWarning"), 1219)
  // TS1239: Unable to resolve class decorator
  assert_eq(@compiler.get_parser_error_int("UnableToResolveClassDecorator"), 1239)
  // TS1240: Unable to resolve parameter decorator
  assert_eq(
    @compiler.get_parser_error_int("UnableToResolveParameterDecorator"),
    1240,
  )
  // TS1241: Unable to resolve property decorator
  assert_eq(
    @compiler.get_parser_error_int("UnableToResolvePropertyDecorator"),
    1241,
  )
  // TS1270: Decorator return type must be assignable
  assert_eq(
    @compiler.get_parser_error_int("DecoratorReturnTypeMustBeAssignable"),
    1270,
  )
}

///|
test "ParserErrorCode::to_message - decorator errors" {
  assert_eq(
    @compiler.get_parser_error_message("DecoratorsNotValidHere"),
    "Decorators are not valid here.",
  )
  assert_eq(
    @compiler.get_parser_error_message("ExperimentalDecoratorsWarning"),
    "Experimental support for decorators is a feature that is subject to change in a future release.",
  )
  assert_eq(
    @compiler.get_parser_error_message("UnableToResolveClassDecorator"),
    "Unable to resolve signature of class decorator when called as an expression.",
  )
  assert_eq(
    @compiler.get_parser_error_message("UnableToResolveParameterDecorator"),
    "Unable to resolve signature of parameter decorator when called as an expression.",
  )
  assert_eq(
    @compiler.get_parser_error_message("UnableToResolvePropertyDecorator"),
    "Unable to resolve signature of property decorator when called as an expression.",
  )
  assert_eq(
    @compiler.get_parser_error_message("DecoratorReturnTypeMustBeAssignable"),
    "Decorator function return type is not assignable to type of the decorated target.",
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

// ============================================================================
// Tests for Assignment & Compatibility Error Codes (TS2304-TS2859)
// ============================================================================

///|
test "ParserErrorCode::to_int - name resolution errors" {
  // TS2304: Cannot find name
  assert_eq(@compiler.get_parser_error_int("CannotFindName"), 2304)
  // TS2305: Module has no exported member
  assert_eq(@compiler.get_parser_error_int("ModuleHasNoExportedMember"), 2305)
  // TS2306: File is not a module
  assert_eq(@compiler.get_parser_error_int("FileIsNotModule"), 2306)
  // TS2307: Cannot find module
  assert_eq(@compiler.get_parser_error_int("CannotFindModule"), 2307)
  // TS2315: Type is not generic
  assert_eq(@compiler.get_parser_error_int("TypeIsNotGeneric"), 2315)
  // TS2318: Cannot find global type
  assert_eq(@compiler.get_parser_error_int("CannotFindGlobalType"), 2318)
}

///|
test "ParserErrorCode::to_int - property and member access errors" {
  // TS2339: Property does not exist on type
  assert_eq(@compiler.get_parser_error_int("PropertyDoesNotExistOnType"), 2339)
  // TS2341: Property is private
  assert_eq(@compiler.get_parser_error_int("PropertyIsPrivate"), 2341)
  // TS2345: Argument not assignable to parameter
  assert_eq(
    @compiler.get_parser_error_int("ArgumentNotAssignableToParameter"),
    2345,
  )
}

///|
test "ParserErrorCode::to_int - this and super errors" {
  // TS2332: this cannot be referenced
  assert_eq(@compiler.get_parser_error_int("ThisCannotBeReferenced"), 2332)
  // TS2335: super only valid in derived class
  assert_eq(@compiler.get_parser_error_int("SuperOnlyInDerivedClass"), 2335)
  // TS2376: super call must be first
  assert_eq(@compiler.get_parser_error_int("SuperCallMustBeFirst"), 2376)
}

///|
test "ParserErrorCode::to_int - null safety errors" {
  // TS2531: Object possibly null
  assert_eq(@compiler.get_parser_error_int("ObjectPossiblyNull"), 2531)
  // TS2532: Object possibly undefined
  assert_eq(@compiler.get_parser_error_int("ObjectPossiblyUndefined"), 2532)
  // TS2533: Object possibly null or undefined
  assert_eq(
    @compiler.get_parser_error_int("ObjectPossiblyNullOrUndefined"),
    2533,
  )
  // TS2571: Object is of type unknown
  assert_eq(@compiler.get_parser_error_int("ObjectIsOfTypeUnknown"), 2571)
}

///|
test "ParserErrorCode::to_int - assignment and readonly errors" {
  // TS2540: Cannot assign to readonly
  assert_eq(@compiler.get_parser_error_int("CannotAssignToReadonly"), 2540)
  // TS2364: Left side of assignment must be a variable
  assert_eq(@compiler.get_parser_error_int("AssignmentLeftMustBeVariable"), 2364)
}

///|
test "ParserErrorCode::to_int - async and generator errors" {
  // TS2465: await only in async function
  assert_eq(@compiler.get_parser_error_int("AwaitOnlyInAsyncFunction"), 2465)
  // TS2466: yield only in generator
  assert_eq(@compiler.get_parser_error_int("YieldOnlyInGenerator"), 2466)
}

///|
test "ParserErrorCode::to_int - duplicate and scope errors" {
  // TS2761: Duplicate identifier
  assert_eq(@compiler.get_parser_error_int("DuplicateIdentifier"), 2761)
  // TS2448: Block-scoped var used before declaration
  assert_eq(
    @compiler.get_parser_error_int("BlockScopedVarUsedBeforeDeclaration"),
    2448,
  )
  // TS2451: Cannot redeclare block-scoped variable
  assert_eq(@compiler.get_parser_error_int("CannotRedeclareBlockScoped"), 2451)
  // TS2454: Variable used before assignment
  assert_eq(@compiler.get_parser_error_int("VariableUsedBeforeAssigned"), 2454)
}

///|
test "ParserErrorCode::to_int - type complexity errors" {
  // TS2589: Type instantiation too deep
  assert_eq(@compiler.get_parser_error_int("TypeInstantiationTooDeep"), 2589)
  // TS2590: Union type too complex
  assert_eq(@compiler.get_parser_error_int("UnionTypeTooComplex"), 2590)
  // TS2456: Type alias circularly references
  assert_eq(
    @compiler.get_parser_error_int("TypeAliasCircularlyReferences"),
    2456,
  )
}

///|
test "ParserErrorCode::to_int - callable errors" {
  // TS2834: Expression not callable
  assert_eq(@compiler.get_parser_error_int("ExpressionNotCallable"), 2834)
  // TS2351: Expression not constructable
  assert_eq(@compiler.get_parser_error_int("ExpressionNotConstructable"), 2351)
}

///|
test "ParserErrorCode::to_int - class and this errors" {
  // TS2683: this implicitly has type any
  assert_eq(@compiler.get_parser_error_int("ThisImplicitlyHasTypeAny"), 2683)
  // TS2377: Derived class must call super
  assert_eq(@compiler.get_parser_error_int("DerivedClassMustHaveSuper"), 2377)
  // TS2516: Abstract member only in abstract class
  assert_eq(
    @compiler.get_parser_error_int("AbstractMethodOnlyInAbstractClass"),
    2516,
  )
  // TS2515: Non-abstract class missing abstract member
  assert_eq(
    @compiler.get_parser_error_int("NonAbstractClassMissingAbstractMember"),
    2515,
  )
}

///|
test "ParserErrorCode::to_int - property initialization errors" {
  // TS2564: Property has no initializer
  assert_eq(@compiler.get_parser_error_int("PropertyHasNoInitializer"), 2564)
  // TS2565: Property used before assigned
  assert_eq(@compiler.get_parser_error_int("PropertyUsedBeforeAssigned"), 2565)
  // TS2366: Function lacks ending return
  assert_eq(@compiler.get_parser_error_int("FunctionLacksEndingReturn"), 2366)
}

// ============================================================================
// Tests for Assignment & Compatibility Error Messages
// ============================================================================

///|
test "ParserErrorCode::to_message - name resolution errors" {
  assert_eq(
    @compiler.get_parser_error_message_with_arg("CannotFindName", Some("foo")),
    "Cannot find name 'foo'.",
  )
  assert_eq(
    @compiler.get_parser_error_message_with_arg("CannotFindModule", Some("./module")),
    "Cannot find module './module'.",
  )
}

///|
test "ParserErrorCode::to_message - this and super errors" {
  assert_eq(
    @compiler.get_parser_error_message("ThisCannotBeReferenced"),
    "'this' cannot be referenced in current location.",
  )
  assert_eq(
    @compiler.get_parser_error_message("SuperOnlyInDerivedClass"),
    "'super' can only be referenced in a derived class.",
  )
}

///|
test "ParserErrorCode::to_message - null safety errors" {
  assert_eq(
    @compiler.get_parser_error_message("ObjectPossiblyNull"),
    "Object is possibly 'null'.",
  )
  assert_eq(
    @compiler.get_parser_error_message("ObjectPossiblyUndefined"),
    "Object is possibly 'undefined'.",
  )
  assert_eq(
    @compiler.get_parser_error_message("ObjectPossiblyNullOrUndefined"),
    "Object is possibly 'null' or 'undefined'.",
  )
}

///|
test "ParserErrorCode::to_message - async generator errors" {
  assert_eq(
    @compiler.get_parser_error_message("AwaitOnlyInAsyncFunction"),
    "'await' expression is only allowed within async function.",
  )
  assert_eq(
    @compiler.get_parser_error_message("YieldOnlyInGenerator"),
    "'yield' expression is only allowed within a generator body.",
  )
}

///|
test "ParserErrorCode::to_message - callable errors" {
  assert_eq(
    @compiler.get_parser_error_message("ExpressionNotCallable"),
    "This expression is not callable.",
  )
  assert_eq(
    @compiler.get_parser_error_message("ExpressionNotConstructable"),
    "This expression is not constructable.",
  )
}

///|
test "ParserErrorCode::to_message - class errors" {
  assert_eq(
    @compiler.get_parser_error_message("ThisImplicitlyHasTypeAny"),
    "'this' implicitly has type 'any' because it does not have a type annotation.",
  )
  assert_eq(
    @compiler.get_parser_error_message("DerivedClassMustHaveSuper"),
    "Constructors for derived classes must contain a 'super' call.",
  )
  assert_eq(
    @compiler.get_parser_error_message("AbstractMethodOnlyInAbstractClass"),
    "Abstract methods can only appear within an abstract class.",
  )
}

///|
test "ParserErrorCode::to_message - variable errors" {
  assert_eq(
    @compiler.get_parser_error_message("AssignmentLeftMustBeVariable"),
    "The left-hand side of an assignment expression must be a variable.",
  )
  assert_eq(
    @compiler.get_parser_error_message("FunctionLacksEndingReturn"),
    "Function lacks ending return statement.",
  )
}

///|
test "ParserErrorCode::to_message - type errors" {
  assert_eq(
    @compiler.get_parser_error_message("ObjectIsOfTypeUnknown"),
    "Object is of type 'unknown'.",
  )
  assert_eq(
    @compiler.get_parser_error_message("TypeInstantiationTooDeep"),
    "Type instantiation is excessively deep and possibly infinite.",
  )
  assert_eq(
    @compiler.get_parser_error_message("UnionTypeTooComplex"),
    "Expression produces a union type that is too complex to represent.",
  )
}
