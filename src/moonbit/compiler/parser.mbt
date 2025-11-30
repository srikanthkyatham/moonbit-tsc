// Parser for TypeScript
// Converts token stream into Abstract Syntax Tree (AST)
// Uses recursive descent parsing strategy

///|
/// Maximum recursion depth for expression parsing
/// Prevents stack overflow on deeply nested expressions
let max_expression_depth : Int = 1000

///|
/// Maximum errors before giving up
let max_errors : Int = 100

///|
/// Parser context flags for handling ambiguous constructs
pub struct ParserContext {
  /// Allow 'in' operator (false in for-in initializer)
  allow_in : Bool
  /// Allow 'yield' as identifier (false in generators)
  allow_yield : Bool
  /// Allow 'await' as identifier (false in async functions)
  allow_await : Bool
  /// Currently parsing type context
  in_type_context : Bool
  /// Currently parsing expression context
  in_expression_context : Bool
  /// Currently in strict mode
  strict_mode : Bool
  /// Currently parsing JSX
  in_jsx : Bool
  /// Currently parsing decorator
  in_decorator : Bool
  /// Disallow comma operator
  disallow_comma : Bool
  /// In conditional expression (for : vs ? disambiguation)
  in_conditional : Bool
  /// Currently inside a function body (for return statement validation)
  in_function : Bool
} derive(Show)

///|
/// Default parser context
pub fn ParserContext::default() -> ParserContext {
  {
    allow_in: true,
    allow_yield: true,
    allow_await: false,
    in_type_context: false,
    in_expression_context: false,
    strict_mode: false,
    in_jsx: false,
    in_decorator: false,
    disallow_comma: false,
    in_conditional: false,
    in_function: false,
  }
}

///|
/// Parser state
pub struct Parser {
  tokens : Array[Token]
  position : Int
  diagnostics : Array[Diagnostic]
  depth : Int // Current recursion depth for expression parsing
  context : ParserContext
  /// Stack of saved contexts for restoration
  context_stack : Array[ParserContext]
} derive(Show)

///|
/// Parser result type
pub type ParseResult[T] = Result[T, Array[Diagnostic]]

///|
/// Create a new parser
pub fn Parser::new(tokens : Array[Token]) -> Parser {
  {
    tokens,
    position: 0,
    diagnostics: [],
    depth: 0,
    context: ParserContext::default(),
    context_stack: [],
  }
}

///|
/// Save current context and push new one
fn push_context(parser : Parser, new_context : ParserContext) -> Parser {
  let stack = parser.context_stack.copy()
  stack.push(parser.context)
  { ..parser, context: new_context, context_stack: stack }
}

///|
/// Restore previous context
fn pop_context(parser : Parser) -> Parser {
  if parser.context_stack.is_empty() {
    parser
  } else {
    let stack = parser.context_stack.copy()
    match stack.pop() {
      Some(prev_context) =>
        { ..parser, context: prev_context, context_stack: stack }
      None => parser
    }
  }
}

///|
/// Modify context temporarily
fn with_context(
  parser : Parser,
  modifier : (ParserContext) -> ParserContext,
) -> Parser {
  { ..parser, context: modifier(parser.context) }
}

///|
/// Add error with limit check
fn add_error_checked(
  parser : Parser,
  message : String,
  location : SourceLocation,
  code : Int,
) -> Parser {
  if parser.diagnostics.length() >= max_errors {
    parser // Stop adding errors
  } else {
    let diagnostic = Diagnostic::error(message, location, code)
    let diagnostics = parser.diagnostics
    diagnostics.push(diagnostic)
    { ..parser, diagnostics, }
  }
}

// ============================================================================
// Enhanced Error Recovery
// ============================================================================

///|
/// Parser error codes
/// Aligned with TypeScript's official diagnostic codes where applicable
pub enum ParserErrorCode {
  // ============================================================================
  // Expected Token Errors (all use TS1005: "{0} expected")
  // These map to TypeScript's TS1005 generic expected token error
  // ============================================================================
  ExpectedSemicolon // TS1005: ';' expected
  ExpectedColon // TS1005: ':' expected
  ExpectedOpenParen // TS1005: '(' expected
  ExpectedCloseParen // TS1005: ')' expected
  ExpectedOpenBrace // TS1005: '{' expected
  ExpectedCloseBrace // TS1005: '}' expected
  ExpectedCloseBracket // TS1005: ']' expected
  ExpectedFunctionKeyword // TS1005: 'function' expected
  ExpectedClassKeyword // TS1005: 'class' expected
  ExpectedEquals // TS1005: '=' expected

  // ============================================================================
  // JSX Errors (TS17xxx)
  // ============================================================================
  JSXClosingTagMismatch // TS17004: Expected corresponding JSX closing tag
  JSXExpectedClosingTag // TS17008: JSX element has no corresponding closing tag
  JSXExpectedAttributeValue // TS17001: JSX attribute expected

  // ============================================================================
  // JSON Errors
  // ============================================================================
  JSONExpectedPropertyName // TS1005: Property name expected
  JSONExpectedValue // TS1005: Value expected
  JSONTrailingComma // TS1009: Trailing comma not allowed

  // ============================================================================
  // Critical Parser Errors (TS1000-1185)
  // These are official TypeScript error codes for parser/syntax errors
  // ============================================================================

  // Identifier errors
  IdentifierExpected // TS1003

  // String/Literal errors
  UnterminatedStringLiteral // TS1002
  UnterminatedTemplateLiteral // TS1160
  UnterminatedRegexLiteral // TS1161

  // Trailing comma
  TrailingCommaNotAllowed // TS1009

  // Rest parameter errors
  RestParameterMustBeLast // TS1014
  RequiredParamAfterOptional // TS1016
  RestParameterCannotBeOptional // TS1048
  RestParameterCannotHaveInitializer // TS1049

  // Ambient context errors
  StatementsNotAllowedInAmbient // TS1036
  DeclareInAmbientContext // TS1038
  InitializerNotAllowedInAmbient // TS1039
  AmbientEnumInitializerMustBeConstant // TS1066

  // Modifier errors
  AsyncModifierNotAllowed // TS1042
  ModifierCannotAppearOnClassElement(String) // TS1044
  ModifierCannotAppearOnConstructor(String) // TS1089
  ModifiersNotAllowedHere // TS1184

  // Constructor errors
  TypeParamsOnConstructor // TS1092

  // Accessor errors
  SetAccessorCannotHaveReturnType // TS1093
  GetAccessorCannotHaveParams // TS1094
  SetAccessorMustHaveOneParam // TS1095

  // Statement context errors
  ReturnOutsideFunction // TS1108
  ExpressionExpected // TS1109
  TypeExpected // TS1110
  UnexpectedEndOfText // TS1126
  DeclarationOrStatementExpected // TS1128
  PropertyOrSignatureExpected // TS1131
  StringLiteralExpected // TS1141
  LineBreakNotPermitted // TS1142

  // Declaration errors
  ConstDeclarationMustBeInitialized // TS1155

  // Merge conflict
  MergeConflictMarker // TS1185

  // Decorator errors
  DecoratorsNotValidHere // TS1206
  ExperimentalDecoratorsWarning // TS1219
  UnableToResolveClassDecorator // TS1239
  UnableToResolveParameterDecorator // TS1240
  UnableToResolvePropertyDecorator // TS1241
  DecoratorReturnTypeMustBeAssignable // TS1270

  // Module/Import errors
  ModuleHasNoDefaultExport(String) // TS1192
  ImportAssignmentNotAllowedInESModules // TS1202
  IsolatedModulesScriptFile(String) // TS1208
  IsolatedModulesConstEnum(String) // TS1209
  AmbientConstEnumsNotAllowedWithIsolatedModules // TS1211
  ExportAssignmentNotAllowedWithModuleExports // TS1218
  TypeAssertionNotAllowedInExponentiation // TS1227
  ImportAliasCannotReferenceTypeExport // TS1232
  DeleteCannotBeCalledOnIdentifier // TS1243
  ClassMemberCannotHaveConst // TS1248
  ConstInitializerMustBeLiteral // TS1254
  AwaitOnlyAllowedAtTopLevel // TS1278
  EqualsOnlyInDestructuring // TS1312
  AwaitNotAllowedInParameterInitializer // TS1313
  DynamicImportSecondArgOnlyEsnext // TS1323
  TopLevelAwaitRequiresEsnext // TS1378
  TopLevelForAwaitNotSupported // TS1431
  DecoratorsNotAfterExport // TS1432
  DecoratorReturnTypeNotAssignable(String) // TS1433
  AwaitUsingOnlyInAsyncFunctions // TS1437
  ImportPathNotStringLiteral // TS1440
  ModifierOnlyInTypeScriptFiles(String) // TS1450
  TypeAnnotationsOnlyInTypeScriptFiles // TS1451
  VariableDeclarationExpected // TS1462
  UsingDeclarationsRequireAwait // TS1463
  UsingDeclarationNotInParameter // TS1484
  ESMImportExportNotValid // TS1486

  // ============================================================================
  // Assignment & Compatibility Errors (TS2307-TS2859)
  // Note: TS2304-TS2306 are in DiagnosticCode for the type checker
  // ============================================================================
  CannotFindModule(String) // TS2307
  TypeIsNotGeneric(String) // TS2315
  CannotFindGlobalType(String) // TS2318
  InterfaceCannotExtendConflictingTypes(String, String, String) // TS2320
  PropertyMissingInType(String, String) // TS2324
  ParameterTypesIncompatible(String, String) // TS2326
  PropertyTypesIncompatible(String) // TS2328
  IndexSignatureMissingInType(String) // TS2329
  ThisCannotBeReferenced // TS2332
  ThisCannotBeReferencedInStaticProperty // TS2334
  SuperOnlyInDerivedClass // TS2335
  SuperCallsNotPermittedOutsideConstructors // TS2337
  PropertyDoesNotExistOnType(String, String) // TS2339
  PropertyIsPrivate(String, String) // TS2341
  ArgumentNotAssignableToParameter(String, String) // TS2345
  TypeHasNoPropertiesInCommon(String, String) // TS2348
  OnlyVoidFunctionCanBeCalledWithNew // TS2350
  ExpressionNotConstructable // TS2351
  ConversionMayBeMistake(String, String) // TS2352
  ImportedHelperNotFound // TS2354
  ArithmeticOperandMustBeNumberOrBigInt // TS2356
  IncrementDecrementOperandMustBeVariable // TS2357
  InstanceofLeftMustBeObjectType // TS2358
  InstanceofRightMustBeFunction // TS2359
  ArithmeticLeftMustBeNumber // TS2362
  AssignmentLeftMustBeVariable // TS2364
  FunctionLacksEndingReturn // TS2366
  ComparisonAppearUnintentional // TS2367
  TypeParameterNameCannotBe(String) // TS2368
  ParameterPropertyOnlyInConstructor // TS2369
  ParameterInitializerOnlyInImplementation // TS2371
  ParameterCannotReferenceSelf(String) // TS2372
  SuperCallMustBeFirst // TS2376
  DerivedClassMustHaveSuper // TS2377
  GetAccessorMustReturnValue // TS2378
  GetSetVisibilityMustAgree // TS2379
  GetSetMustHaveSameType // TS2380
  FunctionImplementationNameMismatch // TS2388
  FunctionSignatureIncompatibleWithOverload // TS2389
  ConstructorImplementationMissing // TS2390
  DuplicateFunctionImplementation // TS2393
  MergedDeclarationExportMismatch // TS2395
  SubsequentVariableMustHaveSameType // TS2403
  ForInLeftMustBeVariable // TS2406
  ForInRightMustBeObject // TS2407
  ClassIncorrectlyImplementsInterface(String, String) // TS2410
  IndexTypeNotAssignable(String, String, String, String) // TS2411
  TypeNotAssignableWithExactOptionalProperties(String, String) // TS2412
  ClassIncorrectlyExtendsBase(String, String) // TS2415
  PropertyNotAssignableToBaseProperty(String, String) // TS2416
  ClassStaticSideIncorrectlyExtendsBase(String, String) // TS2417
  ClassIncorrectlyImplementsInterface2(String, String) // TS2420
  InterfaceIncorrectlyExtendsInterface(String, String) // TS2430
  PropertyIsProtected(String, String) // TS2445
  PropertyProtectedNotDerived(String, String, String) // TS2446
  BlockScopedVarUsedBeforeDeclaration(String) // TS2448
  CannotRedeclareBlockScoped(String) // TS2451
  EnumMemberCannotHaveNumericName // TS2452
  VariableUsedBeforeAssigned(String) // TS2454
  TypeAliasCircularlyReferences(String) // TS2456
  TypeHasNoPropertyAndNoIndexSignature(String, String) // TS2459
  VoidIsNotArrayType // TS2460
  RestElementMustBeLastInDestructuring // TS2461
  RestElementCannotHaveInitializer // TS2462
  ComputedPropertyMustBeStringOrNumber // TS2464
  AwaitOnlyInAsyncFunction // TS2465
  YieldOnlyInGenerator // TS2466
  CatchVariableMustBeAnyOrUnknown // TS2467
  ConstEnumInitializerMustBeLiteral // TS2474
  ConstEnumNotAllowedInIsolatedModules // TS2475
  ConstEnumMemberOnlyStringLiteral // TS2476
  ExportDeclarationConflicts(String) // TS2484
  ForOfLeftMustBeVariable // TS2487
  TupleHasNoElementAtIndex(String, String, String) // TS2493
  UsingPrivateName(String) // TS2494
  ArgumentsObjectCannotBeReferenced // TS2496
  CannotInvokePossiblyNull // TS2497
  CircularBaseExpression(String) // TS2502
  NoBaseConstructorWithTypeArguments // TS2508
  BaseConstructorsMustHaveSameReturnType // TS2510
  NonAbstractClassMissingAbstractMember(String, String) // TS2515
  AbstractMethodOnlyInAbstractClass // TS2516
  NonAbstractClassCannotHaveAbstractProperty // TS2517
  AbstractModifierOnlyOnClassMethodProperty // TS2520
  InferredTypeReferencesInaccessible(String, String) // TS2527
  ModuleCannotHaveMultipleDefaultExports // TS2528
  ObjectPossiblyNull // TS2531
  ObjectPossiblyUndefined // TS2532
  ObjectPossiblyNullOrUndefined // TS2533
  TypeCannotBeUsedToIndex(String, String) // TS2536
  TypeCannotBeUsedAsIndex(String) // TS2538
  CannotAssignToReadonly(String) // TS2540
  IndexSignatureOnlyPermitsReading(String) // TS2542
  TypeNotArrayOrString(String) // TS2548
  TypeNotArrayOrStringOrIterator(String) // TS2549
  ParameterHasNameButNoType // TS2550
  PropertyDoesNotExistDidYouMean(String, String, String) // TS2551
  CannotFindNameDidYouMean(String, String) // TS2552
  ComputedValuesNotPermittedInStringEnum // TS2553
  ExpectedAtLeastArguments(Int, Int) // TS2555
  SpreadArgumentMustBeTupleOrRest // TS2556
  ExpectedArgumentsButGotMore(Int, Int) // TS2557
  TypeHasNoPropertiesInCommon2(String, String) // TS2559
  ObjectLiteralMayOnlySpecifyKnownProperties // TS2561
  PropertyHasNoInitializer(String) // TS2564
  PropertyUsedBeforeAssigned(String) // TS2565
  RestElementCannotContainBindingPattern // TS2566
  ObjectIsOfTypeUnknown // TS2571
  RestElementTypeMustBeArray // TS2574
  NoOverloadExpectsArguments(Int) // TS2575
  PropertyDoesNotExistOnType2(String, String) // TS2576
  UnusedTsExpectError // TS2578
  CannotFindNameNeedTypeDefinitions(String) // TS2579
  CannotFindNameNeedTargetLibrary(String) // TS2580
  CannotFindNameNeedTarget(String) // TS2584
  TypeInstantiationTooDeep // TS2589
  UnionTypeTooComplex // TS2590
  CannotImportTypeDeclarationFiles // TS2591
  CannotAugmentNonModule(String) // TS2593
  MergedDeclarationMustAllBeExported // TS2595
  JSXElementImplicitlyHasTypeAny // TS2602
  JSXElementTypeNoSignatures(String) // TS2604
  JSXElementClassDoesNotSupportAttributes // TS2607
  CannotUseJSXWithoutFlag // TS2608
  ComputedPropertyValueNotAssignable(String, String) // TS2615
  DeclarationEmitRequiresTypeResolution // TS2617
  CannotAssignAbstractConstructorToNonAbstract // TS2630
  ConditionAlwaysReturns(String) // TS2631
  TypeHasSeparatePrivatePropertyDeclarations(String) // TS2632
  TypeHasOrUsesPrivateName(String) // TS2633
  DuplicateIdentifierCompilerReserves(String, String) // TS2637
  CannotAugmentModuleWithValueExports(String) // TS2649
  EnumMemberCannotReferencePrecedingMembers // TS2651
  DuplicateIdentifierAsyncHelper(String) // TS2652
  ExpressionResolvesToCompilerDeclaration(String) // TS2653
  CallSignaturesIncompatible // TS2655
  ConstructSignaturesIncompatible // TS2656
  JSXExpressionsMustHaveOneParent // TS2657
  SuperOnlyInObjectLiteral // TS2659
  SuperPropertyAccessOnlyInConstructor // TS2660
  DerivedConstructorMustReturnObjectOrUndefined // TS2673
  VoidTypeNotValidForMappedTypes // TS2674
  CannotInitializeOuterScopedVariable // TS2675
  AssertionsRequireExplicitTypeAnnotation // TS2676
  TypeLiteralPropertyCannotHaveInitializer // TS2677
  DeclareInAmbientContext2 // TS2678
  ConstructorCannotHaveThisParameter // TS2681
  ThisImplicitlyHasTypeAny // TS2683
  ThisContextNotAssignable(String) // TS2684
  ThisTypesOfSignaturesIncompatible // TS2685
  RefersToUMDGlobal(String) // TS2686
  ClassNameCannotBeObject // TS2687
  CannotFindTypeDefinition(String) // TS2688
  CannotExtendInterfaceWithImplements(String) // TS2689
  TypeOnlyRefersToType(String) // TS2690
  ImportPathCannotEndWithTs // TS2691
  TypeCannotBeUsedAsTypeParameter(String) // TS2692
  CannotFindNameNeedTypeAnnotation(String) // TS2693
  NamespaceHasNoExportedMember(String, String) // TS2694
  ForInLeftCannotBeDestructuring // TS2695
  RestTypesOnlyFromObjects // TS2700
  ObjectRestTargetMustBeVariable // TS2701
  ObjectRestCannotBeOptionalPropertyAccess // TS2702
  ObjectRestCannotContainComputedProperty // TS2703
  IteratorMustHaveNextMethod // TS2704
  RequiredTypeParamsMayNotFollowOptional // TS2706
  GenericTypeRequiresTypeArguments(String, Int, Int) // TS2707
  CannotUseNamespaceAsType(String) // TS2709
  CannotUseNamespaceAsValue(String) // TS2710
  ObjectLiteralPropertyDoesNotExist(String) // TS2711
  CannotInvokeExpressionWithoutCallSignature // TS2713
  InstanceofRightMustBeCallable // TS2714
  MappedObjectTypeImplicitlyAny // TS2715
  IndexSignatureParameterTypeMustBeStringOrNumber // TS2716
  TypeCannotBeAssigned(String, String) // TS2717
  SuperCannotBeCalledBeforeSuperCall // TS2718
  CannotInvokePossiblyUndefined // TS2722
  CannotInvokePossiblyNullOrUndefined // TS2723
  PropertyUsedBeforeInitialization(String) // TS2729
  InferKeywordOnlyInExtendsConditional // TS2730
  ThisBasedTypeGuardNotCompatible // TS2732
  PropertyAlsoDeclaredHere(String) // TS2733
  MissingSemicolon // TS2734
  BigIntLiteralsNotAvailable // TS2737
  TypeMissingProperties(String, String, String) // TS2739
  TypeMissingPropertiesAndMore(String, String, String, Int) // TS2740
  PropertyMissingInTypeButRequired(String, String, String) // TS2741
  InferredTypeCannotBeNamed(String) // TS2742
  TypeDoesNotSatisfyConstraint(String, String) // TS2744
  PropertyIncompatibleWithIndexSignature(String) // TS2745
  PropertyHasConflictingDeclarations(String) // TS2746
  BaseClassIncludesPrivateProperty // TS2747
  CannotAccessBeforeInitialization(String) // TS2748
  RefersToValueUsedAsType(String) // TS2749
  BaseClassCannotHaveStaticAbstractMembers // TS2750
  CannotAssignAbstractClassConstructor // TS2751
  CannotUseAsValueExportType(String) // TS2752
  CannotUseAsValueImportType(String) // TS2753
  AsyncFunctionReturnTypeMustBePromise // TS2754
  InferredTypeExceedsMaxLength // TS2755
  TypeNotAssignableDifferentNames(String, String) // TS2757
  PropertyTypesIncompatible2(String) // TS2758
  DuplicateIdentifier(String) // TS2761
  SpreadTypesOnlyFromObjects // TS2762
  YieldExpressionImplicitlyAny // TS2764
  ParameterNameNoTypeDidYouMean(String, String) // TS2765
  CannotFindModule2(String) // TS2766
  GetSetCannotDeclareThisParameter // TS2767
  YieldOperandMustBeAwaited // TS2770
  TypeReferencesItselfInAnnotation // TS2771
  CannotUseInOperator(String, String) // TS2772
  ConditionAlwaysTrueNoOverlap // TS2773
  UnionTypeTooComplex2 // TS2774
  ThisCannotBeUsedAsType // TS2775
  CannotReadPrivateMemberOutsideClass(String) // TS2776
  DeleteOperandMustBeOptional // TS2790
  CannotFindModuleNeedResolveJsonModule(String) // TS2792
  FileNotUnderRootDir(String, String) // TS2793
  ExpectedArgumentsDidYouForgetVoid(Int, Int) // TS2794
  NewExpressionWithTypeLackingConstructSignature // TS2795
  NewExpressionCannotBeInvoked // TS2796
  NewExpressionOnlyInValidContext // TS2797
  NewExpressionImplicitlyYieldsAny // TS2799
  OperatorCannotBeApplied(String, String, String) // TS2800
  TypeCanOnlyBeIteratedWithDownlevelIteration(String) // TS2802
  CannotAssignToPrivateMethod(String) // TS2803
  ExpectedTypeArgumentsOverloads(Int, Int) // TS2804
  VoidNotValidDestructuringTarget // TS2806
  OptionalElementCannotFollowRest // TS2807
  RequiredElementCannotFollowOptional // TS2808
  IndexSignatureMustHaveTypeAnnotation // TS2809
  CanOnlyWritePropertyOnThisValue(String) // TS2810
  PrivateIdentifiersCannotBeParameters // TS2813
  SyntaxReservedInMtsCtc // TS2815
  AwaitExpressionRequiresPromise // TS2816
  TypeNotArrayOrHasIterator(String) // TS2817
  ForAwaitOfCannotIterateTypes // TS2820
  CouldNotFindDeclarationFile(String) // TS2821
  IndexSignatureIncompatibleWithOptionalProperty(String) // TS2825
  AssignmentLeftCannotBeOptionalPropertyAccess // TS2832
  CannotAssignToGetOnlyProperty(String) // TS2833
  ExpressionNotCallable // TS2834
  UnionTypeNoMatchingNewSignature(String) // TS2835
  TypeNoNewSignatures(String) // TS2836
  ImportNeverUsedAsValue // TS2839
  DecoratorUsedOnUnknownField // TS2840
  CannotCallSuperFromNonDerivedConstructor // TS2841
  UniqueSymbolPropertyMustBeReadonly // TS2845
  CannotAssignToImport(String) // TS2848
  OperatorCannotBeApplied2(String, String, String) // TS2851
  NoValueExistsForShorthandProperty(String) // TS2855
  ClassesMayNotHaveConstructorField // TS2856
  JSXElementNoClosingTag(String) // TS2857
  SuperCallMustBeRootLevel // TS2859
  // Build/Emit Errors (TS4000-4999)
  ImportDeclarationUsingPrivateName(String, String) // TS4000
  TypeParameterHasCircularDefault(String) // TS4002
  ParameterOfExportedFunctionUsingPrivateName(String, String) // TS4004
  ExtendsClauseUsingPrivateName(String, String) // TS4020
  ImplementsClauseUsingPrivateName(String, String) // TS4022
  ExtendsExpressionNotClassOrInterface(String) // TS4023
  ExportedVariableUsingExternalModuleName(String, String) // TS4025
  PublicPropertyUsingPrivateName(String, String) // TS4030
  PublicStaticPropertyUsingPrivateName(String) // TS4031
  TypeParameterOfExportedFunctionUsingPrivateName(String) // TS4032
  TypeParameterOfPublicStaticMethodUsingPrivateName(String) // TS4033
  ReturnTypeOfPublicGetterUsingPrivateName // TS4043
  ParameterOfPublicSetterUsingPrivateName(String) // TS4044
  ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName // TS4045
  ParameterOfMethodFromExportedInterfaceUsingPrivateName(String) // TS4048
  ReturnTypeOfConstructorSignatureUsingPrivateName // TS4049
  ReturnTypeOfCallSignatureUsingPrivateName // TS4055
  ParameterOfCallSignatureUsingPrivateName(String) // TS4058
  ReturnTypeOfIndexSignatureUsingPrivateName // TS4060
  ParameterOfIndexSignatureUsingPrivateName(String) // TS4063
  DefaultExportUsingPrivateName(String) // TS4064
  TypeParameterOfExportedTypeAliasUsingPrivateName(String) // TS4065
  PropertyOfExportedMappedTypeUsingPrivateName(String) // TS4067
  ExportedTypeAliasUsingPrivateName(String, String) // TS4083
  TypeParameterOfExportedClassExpressionUsingPrivateName(String, String) // TS4084
  CannotFindParameter(String) // TS4090
  RestParameterMustBeArrayType // TS4091
  SetAccessorCannotHaveRestParameter // TS4092
  GetAccessorMustHaveAtMostOneParameter // TS4094
  SetAccessorMustHaveOneParameter // TS4097
} derive(Show, Eq)

///|
/// Get numeric code for error
/// Returns official TypeScript diagnostic codes where applicable
pub fn ParserErrorCode::to_int(self : ParserErrorCode) -> Int {
  match self {
    // ============================================================================
    // Expected Token Errors (TS1005)
    // ============================================================================
    ExpectedSemicolon => 1005
    ExpectedColon => 1005
    ExpectedOpenParen => 1005
    ExpectedCloseParen => 1005
    ExpectedOpenBrace => 1005
    ExpectedCloseBrace => 1005
    ExpectedCloseBracket => 1005
    ExpectedFunctionKeyword => 1005
    ExpectedClassKeyword => 1005
    ExpectedEquals => 1005

    // JSX Errors (TS17xxx)
    JSXClosingTagMismatch => 17004
    JSXExpectedClosingTag => 17008
    JSXExpectedAttributeValue => 17001

    // JSON Errors
    JSONExpectedPropertyName => 1005 // Property name expected
    JSONExpectedValue => 1005 // Value expected
    JSONTrailingComma => 1009 // Trailing comma not allowed

    // ============================================================================
    // Critical Parser Errors - Official TypeScript Error Codes
    // ============================================================================

    // Identifier errors
    IdentifierExpected => 1003 // TS1003: Identifier expected

    // String/Literal errors
    UnterminatedStringLiteral => 1002 // TS1002: Unterminated string literal
    UnterminatedTemplateLiteral => 1160 // TS1160: Unterminated template literal
    UnterminatedRegexLiteral => 1161 // TS1161: Unterminated regular expression literal

    // Trailing comma
    TrailingCommaNotAllowed => 1009 // TS1009: Trailing comma not allowed

    // Rest parameter errors
    RestParameterMustBeLast => 1014 // TS1014: A rest parameter must be last in a parameter list
    RequiredParamAfterOptional => 1016 // TS1016: A required parameter cannot follow an optional parameter
    RestParameterCannotBeOptional => 1048 // TS1048: A rest parameter cannot be optional
    RestParameterCannotHaveInitializer => 1049 // TS1049: A rest parameter cannot have an initializer

    // Ambient context errors
    StatementsNotAllowedInAmbient => 1036 // TS1036: Statements are not allowed in ambient contexts
    DeclareInAmbientContext => 1038 // TS1038: A 'declare' modifier cannot be used in an already ambient context
    InitializerNotAllowedInAmbient => 1039 // TS1039: Initializers are not allowed in ambient contexts
    AmbientEnumInitializerMustBeConstant => 1066 // TS1066: In ambient enum declarations member initializer must be constant

    // Modifier errors
    AsyncModifierNotAllowed => 1042 // TS1042: 'async' modifier cannot be used here
    ModifierCannotAppearOnClassElement(_) => 1044 // TS1044: '{0}' modifier cannot appear on a class element
    ModifierCannotAppearOnConstructor(_) => 1089 // TS1089: '{0}' modifier cannot appear on a constructor declaration
    ModifiersNotAllowedHere => 1184 // TS1184: Modifiers cannot appear here

    // Constructor errors
    TypeParamsOnConstructor => 1092 // TS1092: Type parameters cannot appear on a constructor declaration

    // Accessor errors
    SetAccessorCannotHaveReturnType => 1093 // TS1093: A 'set' accessor cannot have a return type annotation
    GetAccessorCannotHaveParams => 1094 // TS1094: A 'get' accessor cannot have parameters
    SetAccessorMustHaveOneParam => 1095 // TS1095: A 'set' accessor must have exactly one parameter

    // Statement context errors
    ReturnOutsideFunction => 1108 // TS1108: A 'return' statement can only be used within a function body
    ExpressionExpected => 1109 // TS1109: Expression expected
    TypeExpected => 1110 // TS1110: Type expected
    UnexpectedEndOfText => 1126 // TS1126: Unexpected end of text
    DeclarationOrStatementExpected => 1128 // TS1128: Declaration or statement expected
    PropertyOrSignatureExpected => 1131 // TS1131: Property or signature expected
    StringLiteralExpected => 1141 // TS1141: String literal expected
    LineBreakNotPermitted => 1142 // TS1142: Line break not permitted here

    // Declaration errors
    ConstDeclarationMustBeInitialized => 1155 // TS1155: 'const' declarations must be initialized

    // Merge conflict
    MergeConflictMarker => 1185 // TS1185: Merge conflict marker encountered

    // Decorator errors
    DecoratorsNotValidHere => 1206 // TS1206: Decorators are not valid here
    ExperimentalDecoratorsWarning => 1219 // TS1219: Experimental support for decorators
    UnableToResolveClassDecorator => 1239 // TS1239: Unable to resolve signature of class decorator
    UnableToResolveParameterDecorator => 1240 // TS1240: Unable to resolve signature of parameter decorator
    UnableToResolvePropertyDecorator => 1241 // TS1241: Unable to resolve signature of property decorator
    DecoratorReturnTypeMustBeAssignable => 1270 // TS1270: Decorator function return type must be assignable

    // Module/Import errors
    ModuleHasNoDefaultExport(_) => 1192
    ImportAssignmentNotAllowedInESModules => 1202
    IsolatedModulesScriptFile(_) => 1208
    IsolatedModulesConstEnum(_) => 1209
    AmbientConstEnumsNotAllowedWithIsolatedModules => 1211
    ExportAssignmentNotAllowedWithModuleExports => 1218
    TypeAssertionNotAllowedInExponentiation => 1227
    ImportAliasCannotReferenceTypeExport => 1232
    DeleteCannotBeCalledOnIdentifier => 1243
    ClassMemberCannotHaveConst => 1248
    ConstInitializerMustBeLiteral => 1254
    AwaitOnlyAllowedAtTopLevel => 1278
    EqualsOnlyInDestructuring => 1312
    AwaitNotAllowedInParameterInitializer => 1313
    DynamicImportSecondArgOnlyEsnext => 1323
    TopLevelAwaitRequiresEsnext => 1378
    TopLevelForAwaitNotSupported => 1431
    DecoratorsNotAfterExport => 1432
    DecoratorReturnTypeNotAssignable(_) => 1433
    AwaitUsingOnlyInAsyncFunctions => 1437
    ImportPathNotStringLiteral => 1440
    ModifierOnlyInTypeScriptFiles(_) => 1450
    TypeAnnotationsOnlyInTypeScriptFiles => 1451
    VariableDeclarationExpected => 1462
    UsingDeclarationsRequireAwait => 1463
    UsingDeclarationNotInParameter => 1484
    ESMImportExportNotValid => 1486

    // ============================================================================
    // Assignment & Compatibility Errors (TS2307-TS2859)
    // ============================================================================
    CannotFindModule(_) => 2307
    TypeIsNotGeneric(_) => 2315
    CannotFindGlobalType(_) => 2318
    InterfaceCannotExtendConflictingTypes(_, _, _) => 2320
    PropertyMissingInType(_, _) => 2324
    ParameterTypesIncompatible(_, _) => 2326
    PropertyTypesIncompatible(_) => 2328
    IndexSignatureMissingInType(_) => 2329
    ThisCannotBeReferenced => 2332
    ThisCannotBeReferencedInStaticProperty => 2334
    SuperOnlyInDerivedClass => 2335
    SuperCallsNotPermittedOutsideConstructors => 2337
    PropertyDoesNotExistOnType(_, _) => 2339
    PropertyIsPrivate(_, _) => 2341
    ArgumentNotAssignableToParameter(_, _) => 2345
    TypeHasNoPropertiesInCommon(_, _) => 2348
    OnlyVoidFunctionCanBeCalledWithNew => 2350
    ExpressionNotConstructable => 2351
    ConversionMayBeMistake(_, _) => 2352
    ImportedHelperNotFound => 2354
    ArithmeticOperandMustBeNumberOrBigInt => 2356
    IncrementDecrementOperandMustBeVariable => 2357
    InstanceofLeftMustBeObjectType => 2358
    InstanceofRightMustBeFunction => 2359
    ArithmeticLeftMustBeNumber => 2362
    AssignmentLeftMustBeVariable => 2364
    FunctionLacksEndingReturn => 2366
    ComparisonAppearUnintentional => 2367
    TypeParameterNameCannotBe(_) => 2368
    ParameterPropertyOnlyInConstructor => 2369
    ParameterInitializerOnlyInImplementation => 2371
    ParameterCannotReferenceSelf(_) => 2372
    SuperCallMustBeFirst => 2376
    DerivedClassMustHaveSuper => 2377
    GetAccessorMustReturnValue => 2378
    GetSetVisibilityMustAgree => 2379
    GetSetMustHaveSameType => 2380
    FunctionImplementationNameMismatch => 2388
    FunctionSignatureIncompatibleWithOverload => 2389
    ConstructorImplementationMissing => 2390
    DuplicateFunctionImplementation => 2393
    MergedDeclarationExportMismatch => 2395
    SubsequentVariableMustHaveSameType => 2403
    ForInLeftMustBeVariable => 2406
    ForInRightMustBeObject => 2407
    ClassIncorrectlyImplementsInterface(_, _) => 2410
    IndexTypeNotAssignable(_, _, _, _) => 2411
    TypeNotAssignableWithExactOptionalProperties(_, _) => 2412
    ClassIncorrectlyExtendsBase(_, _) => 2415
    PropertyNotAssignableToBaseProperty(_, _) => 2416
    ClassStaticSideIncorrectlyExtendsBase(_, _) => 2417
    ClassIncorrectlyImplementsInterface2(_, _) => 2420
    InterfaceIncorrectlyExtendsInterface(_, _) => 2430
    PropertyIsProtected(_, _) => 2445
    PropertyProtectedNotDerived(_, _, _) => 2446
    BlockScopedVarUsedBeforeDeclaration(_) => 2448
    CannotRedeclareBlockScoped(_) => 2451
    EnumMemberCannotHaveNumericName => 2452
    VariableUsedBeforeAssigned(_) => 2454
    TypeAliasCircularlyReferences(_) => 2456
    TypeHasNoPropertyAndNoIndexSignature(_, _) => 2459
    VoidIsNotArrayType => 2460
    RestElementMustBeLastInDestructuring => 2461
    RestElementCannotHaveInitializer => 2462
    ComputedPropertyMustBeStringOrNumber => 2464
    AwaitOnlyInAsyncFunction => 2465
    YieldOnlyInGenerator => 2466
    CatchVariableMustBeAnyOrUnknown => 2467
    ConstEnumInitializerMustBeLiteral => 2474
    ConstEnumNotAllowedInIsolatedModules => 2475
    ConstEnumMemberOnlyStringLiteral => 2476
    ExportDeclarationConflicts(_) => 2484
    ForOfLeftMustBeVariable => 2487
    TupleHasNoElementAtIndex(_, _, _) => 2493
    UsingPrivateName(_) => 2494
    ArgumentsObjectCannotBeReferenced => 2496
    CannotInvokePossiblyNull => 2497
    CircularBaseExpression(_) => 2502
    NoBaseConstructorWithTypeArguments => 2508
    BaseConstructorsMustHaveSameReturnType => 2510
    NonAbstractClassMissingAbstractMember(_, _) => 2515
    AbstractMethodOnlyInAbstractClass => 2516
    NonAbstractClassCannotHaveAbstractProperty => 2517
    AbstractModifierOnlyOnClassMethodProperty => 2520
    InferredTypeReferencesInaccessible(_, _) => 2527
    ModuleCannotHaveMultipleDefaultExports => 2528
    ObjectPossiblyNull => 2531
    ObjectPossiblyUndefined => 2532
    ObjectPossiblyNullOrUndefined => 2533
    TypeCannotBeUsedToIndex(_, _) => 2536
    TypeCannotBeUsedAsIndex(_) => 2538
    CannotAssignToReadonly(_) => 2540
    IndexSignatureOnlyPermitsReading(_) => 2542
    TypeNotArrayOrString(_) => 2548
    TypeNotArrayOrStringOrIterator(_) => 2549
    ParameterHasNameButNoType => 2550
    PropertyDoesNotExistDidYouMean(_, _, _) => 2551
    CannotFindNameDidYouMean(_, _) => 2552
    ComputedValuesNotPermittedInStringEnum => 2553
    ExpectedAtLeastArguments(_, _) => 2555
    SpreadArgumentMustBeTupleOrRest => 2556
    ExpectedArgumentsButGotMore(_, _) => 2557
    TypeHasNoPropertiesInCommon2(_, _) => 2559
    ObjectLiteralMayOnlySpecifyKnownProperties => 2561
    PropertyHasNoInitializer(_) => 2564
    PropertyUsedBeforeAssigned(_) => 2565
    RestElementCannotContainBindingPattern => 2566
    ObjectIsOfTypeUnknown => 2571
    RestElementTypeMustBeArray => 2574
    NoOverloadExpectsArguments(_) => 2575
    PropertyDoesNotExistOnType2(_, _) => 2576
    UnusedTsExpectError => 2578
    CannotFindNameNeedTypeDefinitions(_) => 2579
    CannotFindNameNeedTargetLibrary(_) => 2580
    CannotFindNameNeedTarget(_) => 2584
    TypeInstantiationTooDeep => 2589
    UnionTypeTooComplex => 2590
    CannotImportTypeDeclarationFiles => 2591
    CannotAugmentNonModule(_) => 2593
    MergedDeclarationMustAllBeExported => 2595
    JSXElementImplicitlyHasTypeAny => 2602
    JSXElementTypeNoSignatures(_) => 2604
    JSXElementClassDoesNotSupportAttributes => 2607
    CannotUseJSXWithoutFlag => 2608
    ComputedPropertyValueNotAssignable(_, _) => 2615
    DeclarationEmitRequiresTypeResolution => 2617
    CannotAssignAbstractConstructorToNonAbstract => 2630
    ConditionAlwaysReturns(_) => 2631
    TypeHasSeparatePrivatePropertyDeclarations(_) => 2632
    TypeHasOrUsesPrivateName(_) => 2633
    DuplicateIdentifierCompilerReserves(_, _) => 2637
    CannotAugmentModuleWithValueExports(_) => 2649
    EnumMemberCannotReferencePrecedingMembers => 2651
    DuplicateIdentifierAsyncHelper(_) => 2652
    ExpressionResolvesToCompilerDeclaration(_) => 2653
    CallSignaturesIncompatible => 2655
    ConstructSignaturesIncompatible => 2656
    JSXExpressionsMustHaveOneParent => 2657
    SuperOnlyInObjectLiteral => 2659
    SuperPropertyAccessOnlyInConstructor => 2660
    DerivedConstructorMustReturnObjectOrUndefined => 2673
    VoidTypeNotValidForMappedTypes => 2674
    CannotInitializeOuterScopedVariable => 2675
    AssertionsRequireExplicitTypeAnnotation => 2676
    TypeLiteralPropertyCannotHaveInitializer => 2677
    DeclareInAmbientContext2 => 2678
    ConstructorCannotHaveThisParameter => 2681
    ThisImplicitlyHasTypeAny => 2683
    ThisContextNotAssignable(_) => 2684
    ThisTypesOfSignaturesIncompatible => 2685
    RefersToUMDGlobal(_) => 2686
    ClassNameCannotBeObject => 2687
    CannotFindTypeDefinition(_) => 2688
    CannotExtendInterfaceWithImplements(_) => 2689
    TypeOnlyRefersToType(_) => 2690
    ImportPathCannotEndWithTs => 2691
    TypeCannotBeUsedAsTypeParameter(_) => 2692
    CannotFindNameNeedTypeAnnotation(_) => 2693
    NamespaceHasNoExportedMember(_, _) => 2694
    ForInLeftCannotBeDestructuring => 2695
    RestTypesOnlyFromObjects => 2700
    ObjectRestTargetMustBeVariable => 2701
    ObjectRestCannotBeOptionalPropertyAccess => 2702
    ObjectRestCannotContainComputedProperty => 2703
    IteratorMustHaveNextMethod => 2704
    RequiredTypeParamsMayNotFollowOptional => 2706
    GenericTypeRequiresTypeArguments(_, _, _) => 2707
    CannotUseNamespaceAsType(_) => 2709
    CannotUseNamespaceAsValue(_) => 2710
    ObjectLiteralPropertyDoesNotExist(_) => 2711
    CannotInvokeExpressionWithoutCallSignature => 2713
    InstanceofRightMustBeCallable => 2714
    MappedObjectTypeImplicitlyAny => 2715
    IndexSignatureParameterTypeMustBeStringOrNumber => 2716
    TypeCannotBeAssigned(_, _) => 2717
    SuperCannotBeCalledBeforeSuperCall => 2718
    CannotInvokePossiblyUndefined => 2722
    CannotInvokePossiblyNullOrUndefined => 2723
    PropertyUsedBeforeInitialization(_) => 2729
    InferKeywordOnlyInExtendsConditional => 2730
    ThisBasedTypeGuardNotCompatible => 2732
    PropertyAlsoDeclaredHere(_) => 2733
    MissingSemicolon => 2734
    BigIntLiteralsNotAvailable => 2737
    TypeMissingProperties(_, _, _) => 2739
    TypeMissingPropertiesAndMore(_, _, _, _) => 2740
    PropertyMissingInTypeButRequired(_, _, _) => 2741
    InferredTypeCannotBeNamed(_) => 2742
    TypeDoesNotSatisfyConstraint(_, _) => 2744
    PropertyIncompatibleWithIndexSignature(_) => 2745
    PropertyHasConflictingDeclarations(_) => 2746
    BaseClassIncludesPrivateProperty => 2747
    CannotAccessBeforeInitialization(_) => 2748
    RefersToValueUsedAsType(_) => 2749
    BaseClassCannotHaveStaticAbstractMembers => 2750
    CannotAssignAbstractClassConstructor => 2751
    CannotUseAsValueExportType(_) => 2752
    CannotUseAsValueImportType(_) => 2753
    AsyncFunctionReturnTypeMustBePromise => 2754
    InferredTypeExceedsMaxLength => 2755
    TypeNotAssignableDifferentNames(_, _) => 2757
    PropertyTypesIncompatible2(_) => 2758
    DuplicateIdentifier(_) => 2761
    SpreadTypesOnlyFromObjects => 2762
    YieldExpressionImplicitlyAny => 2764
    ParameterNameNoTypeDidYouMean(_, _) => 2765
    CannotFindModule2(_) => 2766
    GetSetCannotDeclareThisParameter => 2767
    YieldOperandMustBeAwaited => 2770
    TypeReferencesItselfInAnnotation => 2771
    CannotUseInOperator(_, _) => 2772
    ConditionAlwaysTrueNoOverlap => 2773
    UnionTypeTooComplex2 => 2774
    ThisCannotBeUsedAsType => 2775
    CannotReadPrivateMemberOutsideClass(_) => 2776
    DeleteOperandMustBeOptional => 2790
    CannotFindModuleNeedResolveJsonModule(_) => 2792
    FileNotUnderRootDir(_, _) => 2793
    ExpectedArgumentsDidYouForgetVoid(_, _) => 2794
    NewExpressionWithTypeLackingConstructSignature => 2795
    NewExpressionCannotBeInvoked => 2796
    NewExpressionOnlyInValidContext => 2797
    NewExpressionImplicitlyYieldsAny => 2799
    OperatorCannotBeApplied(_, _, _) => 2800
    TypeCanOnlyBeIteratedWithDownlevelIteration(_) => 2802
    CannotAssignToPrivateMethod(_) => 2803
    ExpectedTypeArgumentsOverloads(_, _) => 2804
    VoidNotValidDestructuringTarget => 2806
    OptionalElementCannotFollowRest => 2807
    RequiredElementCannotFollowOptional => 2808
    IndexSignatureMustHaveTypeAnnotation => 2809
    CanOnlyWritePropertyOnThisValue(_) => 2810
    PrivateIdentifiersCannotBeParameters => 2813
    SyntaxReservedInMtsCtc => 2815
    AwaitExpressionRequiresPromise => 2816
    TypeNotArrayOrHasIterator(_) => 2817
    ForAwaitOfCannotIterateTypes => 2820
    CouldNotFindDeclarationFile(_) => 2821
    IndexSignatureIncompatibleWithOptionalProperty(_) => 2825
    AssignmentLeftCannotBeOptionalPropertyAccess => 2832
    CannotAssignToGetOnlyProperty(_) => 2833
    ExpressionNotCallable => 2834
    UnionTypeNoMatchingNewSignature(_) => 2835
    TypeNoNewSignatures(_) => 2836
    ImportNeverUsedAsValue => 2839
    DecoratorUsedOnUnknownField => 2840
    CannotCallSuperFromNonDerivedConstructor => 2841
    UniqueSymbolPropertyMustBeReadonly => 2845
    CannotAssignToImport(_) => 2848
    OperatorCannotBeApplied2(_, _, _) => 2851
    NoValueExistsForShorthandProperty(_) => 2855
    ClassesMayNotHaveConstructorField => 2856
    JSXElementNoClosingTag(_) => 2857
    SuperCallMustBeRootLevel => 2859
    // Build/Emit Errors (TS4000-4999)
    ImportDeclarationUsingPrivateName(_, _) => 4000
    TypeParameterHasCircularDefault(_) => 4002
    ParameterOfExportedFunctionUsingPrivateName(_, _) => 4004
    ExtendsClauseUsingPrivateName(_, _) => 4020
    ImplementsClauseUsingPrivateName(_, _) => 4022
    ExtendsExpressionNotClassOrInterface(_) => 4023
    ExportedVariableUsingExternalModuleName(_, _) => 4025
    PublicPropertyUsingPrivateName(_, _) => 4030
    PublicStaticPropertyUsingPrivateName(_) => 4031
    TypeParameterOfExportedFunctionUsingPrivateName(_) => 4032
    TypeParameterOfPublicStaticMethodUsingPrivateName(_) => 4033
    ReturnTypeOfPublicGetterUsingPrivateName => 4043
    ParameterOfPublicSetterUsingPrivateName(_) => 4044
    ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName => 4045
    ParameterOfMethodFromExportedInterfaceUsingPrivateName(_) => 4048
    ReturnTypeOfConstructorSignatureUsingPrivateName => 4049
    ReturnTypeOfCallSignatureUsingPrivateName => 4055
    ParameterOfCallSignatureUsingPrivateName(_) => 4058
    ReturnTypeOfIndexSignatureUsingPrivateName => 4060
    ParameterOfIndexSignatureUsingPrivateName(_) => 4063
    DefaultExportUsingPrivateName(_) => 4064
    TypeParameterOfExportedTypeAliasUsingPrivateName(_) => 4065
    PropertyOfExportedMappedTypeUsingPrivateName(_) => 4067
    ExportedTypeAliasUsingPrivateName(_, _) => 4083
    TypeParameterOfExportedClassExpressionUsingPrivateName(_, _) => 4084
    CannotFindParameter(_) => 4090
    RestParameterMustBeArrayType => 4091
    SetAccessorCannotHaveRestParameter => 4092
    GetAccessorMustHaveAtMostOneParameter => 4094
    SetAccessorMustHaveOneParameter => 4097
  }
}

///|
/// Get the human-readable error message for this error code
/// Messages are aligned with official TypeScript diagnostic messages
pub fn ParserErrorCode::to_message(self : ParserErrorCode) -> String {
  match self {
    // ============================================================================
    // Expected Token Errors (TS1005)
    // ============================================================================
    ExpectedSemicolon => "';' expected."
    ExpectedColon => "':' expected."
    ExpectedOpenParen => "'(' expected."
    ExpectedCloseParen => "')' expected."
    ExpectedOpenBrace => "'{' expected."
    ExpectedCloseBrace => "'}' expected."
    ExpectedCloseBracket => "']' expected."
    ExpectedFunctionKeyword => "'function' expected."
    ExpectedClassKeyword => "'class' expected."
    ExpectedEquals => "'=' expected."

    // JSX Errors
    JSXClosingTagMismatch => "Expected corresponding JSX closing tag."
    JSXExpectedClosingTag => "JSX element has no corresponding closing tag."
    JSXExpectedAttributeValue => "JSX attribute expected."

    // JSON Errors
    JSONExpectedPropertyName => "Property name expected."
    JSONExpectedValue => "Value expected."
    JSONTrailingComma => "Trailing comma not allowed."

    // ============================================================================
    // Critical Parser Errors - Official TypeScript Error Messages
    // ============================================================================

    // Identifier errors
    IdentifierExpected => "Identifier expected."

    // String/Literal errors
    UnterminatedStringLiteral => "Unterminated string literal."
    UnterminatedTemplateLiteral => "Unterminated template literal."
    UnterminatedRegexLiteral => "Unterminated regular expression literal."

    // Trailing comma
    TrailingCommaNotAllowed => "Trailing comma not allowed."

    // Rest parameter errors
    RestParameterMustBeLast =>
      "A rest parameter must be last in a parameter list."
    RequiredParamAfterOptional =>
      "A required parameter cannot follow an optional parameter."
    RestParameterCannotBeOptional => "A rest parameter cannot be optional."
    RestParameterCannotHaveInitializer =>
      "A rest parameter cannot have an initializer."

    // Ambient context errors
    StatementsNotAllowedInAmbient =>
      "Statements are not allowed in ambient contexts."
    DeclareInAmbientContext =>
      "A 'declare' modifier cannot be used in an already ambient context."
    InitializerNotAllowedInAmbient =>
      "Initializers are not allowed in ambient contexts."
    AmbientEnumInitializerMustBeConstant =>
      "In ambient enum declarations member initializer must be constant expression."

    // Modifier errors
    AsyncModifierNotAllowed => "'async' modifier cannot be used here."
    ModifierCannotAppearOnClassElement(modifier) =>
      "'" + modifier + "' modifier cannot appear on a class element."
    ModifierCannotAppearOnConstructor(modifier) =>
      "'" + modifier + "' modifier cannot appear on a constructor declaration."
    ModifiersNotAllowedHere => "Modifiers cannot appear here."

    // Constructor errors
    TypeParamsOnConstructor =>
      "Type parameters cannot appear on a constructor declaration."

    // Accessor errors
    SetAccessorCannotHaveReturnType =>
      "A 'set' accessor cannot have a return type annotation."
    GetAccessorCannotHaveParams => "An accessor cannot have parameters."
    SetAccessorMustHaveOneParam =>
      "A 'set' accessor must have exactly one parameter."

    // Statement context errors
    ReturnOutsideFunction =>
      "A 'return' statement can only be used within a function body."
    ExpressionExpected => "Expression expected."
    TypeExpected => "Type expected."
    UnexpectedEndOfText => "Unexpected end of text."
    DeclarationOrStatementExpected => "Declaration or statement expected."
    PropertyOrSignatureExpected => "Property or signature expected."
    StringLiteralExpected => "String literal expected."
    LineBreakNotPermitted => "Line break not permitted here."

    // Declaration errors
    ConstDeclarationMustBeInitialized =>
      "'const' declarations must be initialized."

    // Merge conflict
    MergeConflictMarker => "Merge conflict marker encountered."

    // Decorator errors
    DecoratorsNotValidHere => "Decorators are not valid here."
    ExperimentalDecoratorsWarning =>
      "Experimental support for decorators is a feature that is subject to change in a future release."
    UnableToResolveClassDecorator =>
      "Unable to resolve signature of class decorator when called as an expression."
    UnableToResolveParameterDecorator =>
      "Unable to resolve signature of parameter decorator when called as an expression."
    UnableToResolvePropertyDecorator =>
      "Unable to resolve signature of property decorator when called as an expression."
    DecoratorReturnTypeMustBeAssignable =>
      "Decorator function return type is not assignable to type of the decorated target."

    // Module/Import errors
    ModuleHasNoDefaultExport(module_name) =>
      "Module '\{module_name}' has no default export."
    ImportAssignmentNotAllowedInESModules =>
      "Import assignment cannot be used when targeting ECMAScript modules. Consider using 'import * as ns from \"mod\"', 'import {a} from \"mod\"', 'import d from \"mod\"', or another module format instead."
    IsolatedModulesScriptFile(name) =>
      "'\{name}' cannot be compiled under '--isolatedModules' because it is considered a global script file. Add an import, export, or an empty 'export {}' statement to make it a module."
    IsolatedModulesConstEnum(name) =>
      "'\{name}' cannot be compiled under '--isolatedModules' because it is considered a global script file. Add an import, export, or an empty 'export {}' statement to make it a module."
    AmbientConstEnumsNotAllowedWithIsolatedModules =>
      "Ambient const enums are not allowed when the '--isolatedModules' flag is provided."
    ExportAssignmentNotAllowedWithModuleExports =>
      "An export assignment cannot be used in a module with other exported elements."
    TypeAssertionNotAllowedInExponentiation =>
      "A type assertion expression is not allowed in the left-hand side of an exponentiation expression. Consider enclosing the expression in parentheses."
    ImportAliasCannotReferenceTypeExport =>
      "An import alias cannot reference a declaration that was exported using 'export type'."
    DeleteCannotBeCalledOnIdentifier =>
      "'delete' cannot be called on an identifier in strict mode."
    ClassMemberCannotHaveConst =>
      "A class member cannot have the 'const' keyword."
    ConstInitializerMustBeLiteral =>
      "A 'const' initializer in an ambient context must be a string or numeric literal or literal enum reference."
    AwaitOnlyAllowedAtTopLevel =>
      "'await' expressions are only allowed at the top level of a file when that file is a module, but this file has no imports or exports. Consider adding an empty 'export {}' to make this file a module."
    EqualsOnlyInDestructuring =>
      "'=' can only be used in an object literal property inside a destructuring assignment."
    AwaitNotAllowedInParameterInitializer =>
      "'await' expressions cannot be used in a parameter initializer."
    DynamicImportSecondArgOnlyEsnext =>
      "Dynamic imports only support a second argument when the '--module' option is set to 'esnext', 'node16', or 'nodenext'."
    TopLevelAwaitRequiresEsnext =>
      "Top-level 'await' expressions are only allowed when the 'module' option is set to 'es2022', 'esnext', 'system', 'node16', or 'nodenext', and the 'target' option is set to 'es2017' or higher."
    TopLevelForAwaitNotSupported =>
      "Top-level 'for await' statements are only allowed when the 'module' option is set to 'es2022', 'esnext', 'system', 'node16', or 'nodenext', and the 'target' option is set to 'es2017' or higher."
    DecoratorsNotAfterExport =>
      "Decorators must precede the name and all keywords of property declarations."
    DecoratorReturnTypeNotAssignable(type_name) =>
      "Decorator function return type '\{type_name}' is not assignable to type of decorated declaration."
    AwaitUsingOnlyInAsyncFunctions =>
      "'await using' statements are only allowed within async functions and at the top levels of modules."
    ImportPathNotStringLiteral =>
      "The 'import' path must be a string literal."
    ModifierOnlyInTypeScriptFiles(modifier) =>
      "The '\{modifier}' modifier can only be used in TypeScript files."
    TypeAnnotationsOnlyInTypeScriptFiles =>
      "Type annotations can only be used in TypeScript files."
    VariableDeclarationExpected =>
      "Variable declaration expected."
    UsingDeclarationsRequireAwait =>
      "'using' declarations may not have a binding pattern, and must have an initializer."
    UsingDeclarationNotInParameter =>
      "A 'using' declaration may not be declared in a parameter."
    ESMImportExportNotValid =>
      "This file has an import or export that cannot be used outside of ECMAScript modules."

    // ============================================================================
    // Assignment & Compatibility Errors (TS2307-TS2859)
    // ============================================================================
    CannotFindModule(module) => "Cannot find module '\{module}'."
    TypeIsNotGeneric(t) => "Type '\{t}' is not generic."
    CannotFindGlobalType(t) => "Cannot find global type '\{t}'."
    InterfaceCannotExtendConflictingTypes(iface, t1, t2) =>
      "Interface '\{iface}' cannot simultaneously extend types '\{t1}' and '\{t2}'."
    PropertyMissingInType(prop, t) => "Property '\{prop}' is missing in type '\{t}'."
    ParameterTypesIncompatible(p1, p2) =>
      "Types of parameters '\{p1}' and '\{p2}' are incompatible."
    PropertyTypesIncompatible(prop) => "Types of property '\{prop}' are incompatible."
    IndexSignatureMissingInType(t) => "Index signature is missing in type '\{t}'."
    ThisCannotBeReferenced => "'this' cannot be referenced in current location."
    ThisCannotBeReferencedInStaticProperty =>
      "'this' cannot be referenced in a static property initializer."
    SuperOnlyInDerivedClass => "'super' can only be referenced in a derived class."
    SuperCallsNotPermittedOutsideConstructors =>
      "Super calls are not permitted outside constructors."
    PropertyDoesNotExistOnType(prop, t) =>
      "Property '\{prop}' does not exist on type '\{t}'."
    PropertyIsPrivate(prop, cls) =>
      "Property '\{prop}' is private and only accessible within class '\{cls}'."
    ArgumentNotAssignableToParameter(arg, param) =>
      "Argument of type '\{arg}' is not assignable to parameter of type '\{param}'."
    TypeHasNoPropertiesInCommon(t1, t2) =>
      "Value of type '\{t1}' has no properties in common with type '\{t2}'."
    OnlyVoidFunctionCanBeCalledWithNew =>
      "Only 'void' function can be called with 'new' keyword."
    ExpressionNotConstructable => "This expression is not constructable."
    ConversionMayBeMistake(t1, t2) =>
      "Conversion of type '\{t1}' to type '\{t2}' may be a mistake."
    ImportedHelperNotFound =>
      "This syntax requires an imported helper but none found."
    ArithmeticOperandMustBeNumberOrBigInt =>
      "An arithmetic operand must be of type 'any', 'number', 'bigint' or enum."
    IncrementDecrementOperandMustBeVariable =>
      "The operand of an increment or decrement operator must be a variable."
    InstanceofLeftMustBeObjectType =>
      "The left-hand side of an 'instanceof' expression must be 'any', object type, or type parameter."
    InstanceofRightMustBeFunction =>
      "The right-hand side of an 'instanceof' expression must be 'any' or of type 'Function'."
    ArithmeticLeftMustBeNumber =>
      "The left-hand side of an arithmetic operation must be 'any', 'number', 'bigint' or enum."
    AssignmentLeftMustBeVariable =>
      "The left-hand side of an assignment expression must be a variable."
    FunctionLacksEndingReturn => "Function lacks ending return statement."
    ComparisonAppearUnintentional =>
      "This comparison appears to be unintentional (always true/false)."
    TypeParameterNameCannotBe(name) => "Type parameter name cannot be '\{name}'."
    ParameterPropertyOnlyInConstructor =>
      "A parameter property is only allowed in a constructor implementation."
    ParameterInitializerOnlyInImplementation =>
      "A parameter initializer is only allowed in a function/constructor implementation."
    ParameterCannotReferenceSelf(name) => "Parameter '\{name}' cannot reference itself."
    SuperCallMustBeFirst =>
      "A 'super' call must be the first statement in the constructor."
    DerivedClassMustHaveSuper =>
      "Constructors for derived classes must contain a 'super' call."
    GetAccessorMustReturnValue => "A 'get' accessor must return a value."
    GetSetVisibilityMustAgree =>
      "Getter and setter accessors do not agree in visibility."
    GetSetMustHaveSameType => "'get' and 'set' accessor must have the same type."
    FunctionImplementationNameMismatch =>
      "Function implementation name must match function name."
    FunctionSignatureIncompatibleWithOverload =>
      "Function implementation signature must be compatible with overload."
    ConstructorImplementationMissing => "Constructor implementation is missing."
    DuplicateFunctionImplementation => "Duplicate function implementation."
    MergedDeclarationExportMismatch =>
      "Individual declarations in merged declaration must be all exported or not."
    SubsequentVariableMustHaveSameType =>
      "Subsequent variable declarations must have the same type."
    ForInLeftMustBeVariable =>
      "The left-hand side of a 'for...in' statement must be a variable."
    ForInRightMustBeObject =>
      "The right-hand side of a 'for...in' statement must be an object."
    ClassIncorrectlyImplementsInterface(cls, iface) =>
      "Class '\{cls}' incorrectly implements interface '\{iface}'."
    IndexTypeNotAssignable(idx1, t1, idx2, t2) =>
      "'\{idx1}' index type '\{t1}' is not assignable to '\{idx2}' index type '\{t2}'."
    TypeNotAssignableWithExactOptionalProperties(t1, t2) =>
      "Type '\{t1}' is not assignable to type '\{t2}' with 'exactOptionalPropertyTypes'."
    ClassIncorrectlyExtendsBase(cls, base) =>
      "Class '\{cls}' incorrectly extends base class '\{base}'."
    PropertyNotAssignableToBaseProperty(prop, base) =>
      "Property '\{prop}' in type is not assignable to same property in base type '\{base}'."
    ClassStaticSideIncorrectlyExtendsBase(cls, base) =>
      "Class static side '\{cls}' incorrectly extends base class static side '\{base}'."
    ClassIncorrectlyImplementsInterface2(cls, iface) =>
      "Class '\{cls}' incorrectly implements interface '\{iface}'."
    InterfaceIncorrectlyExtendsInterface(iface1, iface2) =>
      "Interface '\{iface1}' incorrectly extends interface '\{iface2}'."
    PropertyIsProtected(prop, cls) =>
      "Property '\{prop}' is protected and only accessible within class '\{cls}'."
    PropertyProtectedNotDerived(prop, t, base) =>
      "Property '\{prop}' is protected but type '\{t}' is not derived from '\{base}'."
    BlockScopedVarUsedBeforeDeclaration(name) =>
      "Block-scoped variable '\{name}' used before its declaration."
    CannotRedeclareBlockScoped(name) =>
      "Cannot redeclare block-scoped variable '\{name}'."
    EnumMemberCannotHaveNumericName =>
      "An enum member cannot have a numeric name."
    VariableUsedBeforeAssigned(name) =>
      "Variable '\{name}' is used before being assigned."
    TypeAliasCircularlyReferences(name) =>
      "Type alias '\{name}' circularly references itself."
    TypeHasNoPropertyAndNoIndexSignature(t, prop) =>
      "Type '\{t}' has no property '\{prop}' and no string index signature."
    VoidIsNotArrayType => "Type 'void' is not an array type."
    RestElementMustBeLastInDestructuring =>
      "A rest element must be last in a destructuring pattern."
    RestElementCannotHaveInitializer => "A rest element cannot have an initializer."
    ComputedPropertyMustBeStringOrNumber =>
      "A computed property name must be of type 'string', 'number', 'symbol', or 'any'."
    AwaitOnlyInAsyncFunction =>
      "'await' expression is only allowed within async function."
    YieldOnlyInGenerator =>
      "'yield' expression is only allowed within a generator body."
    CatchVariableMustBeAnyOrUnknown =>
      "The type of a 'catch' clause variable must be 'any' or 'unknown'."
    ConstEnumInitializerMustBeLiteral =>
      "const enum member initializers can only contain literal values."
    ConstEnumNotAllowedInIsolatedModules =>
      "'const' enum not allowed in isolatedModules."
    ConstEnumMemberOnlyStringLiteral =>
      "A const enum member can only be accessed using string literal."
    ExportDeclarationConflicts(name) =>
      "Export declaration conflicts with exported declaration of '\{name}'."
    ForOfLeftMustBeVariable =>
      "The left-hand side of a 'for...of' statement must be a variable."
    TupleHasNoElementAtIndex(tuple, len, idx) =>
      "Tuple type '\{tuple}' of length '\{len}' has no element at index '\{idx}'."
    UsingPrivateName(name) => "Using private name '\{name}'."
    ArgumentsObjectCannotBeReferenced =>
      "The 'arguments' object cannot be referenced."
    CannotInvokePossiblyNull =>
      "Cannot invoke an object which is possibly 'null'."
    CircularBaseExpression(name) =>
      "'\{name}' is referenced directly or indirectly in its own base expression."
    NoBaseConstructorWithTypeArguments =>
      "No base constructor has the specified number of type arguments."
    BaseConstructorsMustHaveSameReturnType =>
      "Base constructors must all have the same return type."
    NonAbstractClassMissingAbstractMember(cls, member) =>
      "Non-abstract class '\{cls}' does not implement inherited abstract member '\{member}'."
    AbstractMethodOnlyInAbstractClass =>
      "Abstract methods can only appear within an abstract class."
    NonAbstractClassCannotHaveAbstractProperty =>
      "A non-abstract class cannot have an abstract property."
    AbstractModifierOnlyOnClassMethodProperty =>
      "'abstract' modifier can only appear on a class, method, or property."
    InferredTypeReferencesInaccessible(name, t) =>
      "The inferred type of '\{name}' references an inaccessible '\{t}' type."
    ModuleCannotHaveMultipleDefaultExports =>
      "A module cannot have multiple default exports."
    ObjectPossiblyNull => "Object is possibly 'null'."
    ObjectPossiblyUndefined => "Object is possibly 'undefined'."
    ObjectPossiblyNullOrUndefined => "Object is possibly 'null' or 'undefined'."
    TypeCannotBeUsedToIndex(t1, t2) =>
      "Type '\{t1}' cannot be used to index type '\{t2}'."
    TypeCannotBeUsedAsIndex(t) => "Type '\{t}' cannot be used as an index type."
    CannotAssignToReadonly(prop) =>
      "Cannot assign to '\{prop}' because it is a read-only property."
    IndexSignatureOnlyPermitsReading(t) =>
      "Index signature in type '\{t}' only permits reading."
    TypeNotArrayOrString(t) => "Type '\{t}' is not an array type or a string type."
    TypeNotArrayOrStringOrIterator(t) =>
      "Type '\{t}' is not an array type or a string type or does not have '[Symbol.iterator]'."
    ParameterHasNameButNoType => "Parameter has a name but no type."
    PropertyDoesNotExistDidYouMean(prop, t, suggestion) =>
      "Property '\{prop}' does not exist on type '\{t}'. Did you mean '\{suggestion}'?"
    CannotFindNameDidYouMean(name, suggestion) =>
      "Cannot find name '\{name}'. Did you mean '\{suggestion}'?"
    ComputedValuesNotPermittedInStringEnum =>
      "Computed values are not permitted in enum with string members."
    ExpectedAtLeastArguments(expected, got) =>
      "Expected at least \{expected} arguments, but got \{got}."
    SpreadArgumentMustBeTupleOrRest =>
      "A spread argument must either have a tuple type or be passed to a rest parameter."
    ExpectedArgumentsButGotMore(expected, got) =>
      "Expected \{expected} arguments, but got \{got} or more."
    TypeHasNoPropertiesInCommon2(t1, t2) =>
      "Type '\{t1}' has no properties in common with type '\{t2}'."
    ObjectLiteralMayOnlySpecifyKnownProperties =>
      "Object literal may only specify known properties."
    PropertyHasNoInitializer(prop) =>
      "Property '\{prop}' has no initializer and is not definitely assigned."
    PropertyUsedBeforeAssigned(prop) =>
      "Property '\{prop}' is used before being assigned."
    RestElementCannotContainBindingPattern =>
      "A rest element cannot contain a binding pattern."
    ObjectIsOfTypeUnknown => "Object is of type 'unknown'."
    RestElementTypeMustBeArray => "A rest element type must be an array type."
    NoOverloadExpectsArguments(count) => "No overload expects \{count} arguments."
    PropertyDoesNotExistOnType2(prop, t) =>
      "Property '\{prop}' does not exist on type '\{t}'..."
    UnusedTsExpectError => "Unused '@ts-expect-error' directive."
    CannotFindNameNeedTypeDefinitions(name) =>
      "Cannot find name '\{name}'. Do you need to install type definitions?"
    CannotFindNameNeedTargetLibrary(name) =>
      "Cannot find name '\{name}'. Do you need to change target library?"
    CannotFindNameNeedTarget(name) =>
      "Cannot find name '\{name}'. Do you need to change target?"
    TypeInstantiationTooDeep =>
      "Type instantiation is excessively deep and possibly infinite."
    UnionTypeTooComplex =>
      "Expression produces a union type that is too complex to represent."
    CannotImportTypeDeclarationFiles => "Cannot import type declaration files."
    CannotAugmentNonModule(module) =>
      "Cannot augment module '\{module}' with value exports because it resolves to a non-module."
    MergedDeclarationMustAllBeExported =>
      "Individual declarations in merged declaration must be all exported."
    JSXElementImplicitlyHasTypeAny => "JSX element implicitly has type 'any'."
    JSXElementTypeNoSignatures(t) =>
      "JSX element type '\{t}' does not have any construct/call signatures."
    JSXElementClassDoesNotSupportAttributes =>
      "JSX element class does not support attributes."
    CannotUseJSXWithoutFlag =>
      "Cannot use JSX unless '--jsx' flag is provided."
    ComputedPropertyValueNotAssignable(t1, t2) =>
      "Type of computed property's value is '\{t1}' which is not assignable to type '\{t2}'."
    DeclarationEmitRequiresTypeResolution =>
      "Declaration emit for this file requires type resolution."
    CannotAssignAbstractConstructorToNonAbstract =>
      "Cannot assign an abstract constructor type to a non-abstract constructor."
    ConditionAlwaysReturns(val) =>
      "This condition will always return '\{val}'."
    TypeHasSeparatePrivatePropertyDeclarations(prop) =>
      "Type has separate declarations of private property '\{prop}'."
    TypeHasOrUsesPrivateName(name) =>
      "Type has or is using private name '\{name}'."
    DuplicateIdentifierCompilerReserves(id, reserved) =>
      "Duplicate identifier '\{id}'. Compiler reserves name '\{reserved}' in top level scope."
    CannotAugmentModuleWithValueExports(module) =>
      "Cannot augment module '\{module}' with value exports."
    EnumMemberCannotReferencePrecedingMembers =>
      "A member initializer in a enum declaration cannot reference members."
    DuplicateIdentifierAsyncHelper(id) =>
      "Duplicate identifier '\{id}'. Compiler uses declaration for async helper."
    ExpressionResolvesToCompilerDeclaration(decl) =>
      "Expression resolves to variable declaration '\{decl}' that compiler uses."
    CallSignaturesIncompatible => "Types of call signatures are incompatible."
    ConstructSignaturesIncompatible =>
      "Types of construct signatures are incompatible."
    JSXExpressionsMustHaveOneParent =>
      "JSX expressions must have one parent element."
    SuperOnlyInObjectLiteral =>
      "'super' is only allowed in members of an object literal."
    SuperPropertyAccessOnlyInConstructor =>
      "'super' property access is permitted only within a constructor."
    DerivedConstructorMustReturnObjectOrUndefined =>
      "Constructor of derived class must return object or undefined."
    VoidTypeNotValidForMappedTypes =>
      "'void' type is not valid as type argument for mapped types."
    CannotInitializeOuterScopedVariable =>
      "Cannot initialize outer scoped variable in nested function."
    AssertionsRequireExplicitTypeAnnotation =>
      "Assertions require every name to have an explicit type annotation."
    TypeLiteralPropertyCannotHaveInitializer =>
      "A type literal property cannot have an initializer."
    DeclareInAmbientContext2 =>
      "A 'declare' modifier cannot be used in an already ambient context."
    ConstructorCannotHaveThisParameter =>
      "A constructor cannot have a 'this' parameter."
    ThisImplicitlyHasTypeAny =>
      "'this' implicitly has type 'any' because it does not have a type annotation."
    ThisContextNotAssignable(t) =>
      "'this' context of type '\{t}' is not assignable."
    ThisTypesOfSignaturesIncompatible =>
      "The 'this' types of each signature are incompatible."
    RefersToUMDGlobal(name) => "'\{name}' refers to a UMD global."
    ClassNameCannotBeObject =>
      "Class name cannot be 'Object' when targeting ES5."
    CannotFindTypeDefinition(name) =>
      "Cannot find type definition file for '\{name}'."
    CannotExtendInterfaceWithImplements(iface) =>
      "Cannot extend interface '\{iface}' which is used with 'implements'."
    TypeOnlyRefersToType(name) =>
      "'\{name}' only refers to a type, but is used as a value here."
    ImportPathCannotEndWithTs =>
      "An import path cannot end with '.ts' extension."
    TypeCannotBeUsedAsTypeParameter(t) =>
      "Type '\{t}' cannot be used as type parameter."
    CannotFindNameNeedTypeAnnotation(name) =>
      "Cannot find name '\{name}'. A type annotation is necessary."
    NamespaceHasNoExportedMember(ns, member) =>
      "Namespace '\{ns}' has no exported member '\{member}'."
    ForInLeftCannotBeDestructuring =>
      "The left-hand side of a 'for...in' statement cannot be a destructuring pattern."
    RestTypesOnlyFromObjects =>
      "Rest types may only be created from object types."
    ObjectRestTargetMustBeVariable =>
      "The target of an object rest assignment must be a variable."
    ObjectRestCannotBeOptionalPropertyAccess =>
      "The target of an object rest assignment may not be an optional property access."
    ObjectRestCannotContainComputedProperty =>
      "An object rest element cannot contain the computed property name of a named signature."
    IteratorMustHaveNextMethod =>
      "An iterator must have a 'next()' method."
    RequiredTypeParamsMayNotFollowOptional =>
      "Required type parameters may not follow optional type parameters."
    GenericTypeRequiresTypeArguments(t, min, max) =>
      "Generic type '\{t}' requires between \{min} and \{max} type arguments."
    CannotUseNamespaceAsType(ns) =>
      "Cannot use namespace '\{ns}' as a type."
    CannotUseNamespaceAsValue(ns) =>
      "Cannot use namespace '\{ns}' as a value."
    ObjectLiteralPropertyDoesNotExist(prop) =>
      "Object literal may only specify known properties, but '\{prop}' does not exist."
    CannotInvokeExpressionWithoutCallSignature =>
      "Cannot invoke an expression whose type lacks a call signature."
    InstanceofRightMustBeCallable =>
      "The right-hand side of an 'instanceof' expression must be of type 'any' or callable."
    MappedObjectTypeImplicitlyAny =>
      "Mapped object type implicitly has an 'any' type."
    IndexSignatureParameterTypeMustBeStringOrNumber =>
      "Index signature parameter type must be 'string', 'number', 'symbol' or template literal."
    TypeCannotBeAssigned(t1, t2) =>
      "Type '\{t1}' cannot be assigned to type '\{t2}'."
    SuperCannotBeCalledBeforeSuperCall =>
      "'super' cannot be called or accessed before the 'super()' call."
    CannotInvokePossiblyUndefined =>
      "Cannot invoke an object which is possibly 'undefined'."
    CannotInvokePossiblyNullOrUndefined =>
      "Cannot invoke an object which is possibly 'null' or 'undefined'."
    PropertyUsedBeforeInitialization(prop) =>
      "Property '\{prop}' is used before its initialization."
    InferKeywordOnlyInExtendsConditional =>
      "The 'infer' keyword can only be used within 'extends' conditional type."
    ThisBasedTypeGuardNotCompatible =>
      "A 'this' based type guard is not compatible with target type."
    PropertyAlsoDeclaredHere(prop) =>
      "Property '\{prop}' was also declared here."
    MissingSemicolon => "Are you missing a semicolon?"
    BigIntLiteralsNotAvailable =>
      "BigInt literals are not available when targeting lower than ES2020."
    TypeMissingProperties(t1, t2, props) =>
      "Type '\{t1}' is missing the following properties from type '\{t2}': \{props}."
    TypeMissingPropertiesAndMore(t1, t2, props, more) =>
      "Type '\{t1}' is missing the following properties from type '\{t2}': \{props}, and \{more} more."
    PropertyMissingInTypeButRequired(prop, t1, t2) =>
      "Property '\{prop}' is missing in type '\{t1}' but required in type '\{t2}'."
    InferredTypeCannotBeNamed(name) =>
      "The inferred type of '\{name}' cannot be named without a reference."
    TypeDoesNotSatisfyConstraint(t, constraint) =>
      "Type '\{t}' does not satisfy constraint '\{constraint}'."
    PropertyIncompatibleWithIndexSignature(prop) =>
      "Property '\{prop}' is incompatible with index signature."
    PropertyHasConflictingDeclarations(prop) =>
      "Property '\{prop}' has conflicting declarations in the same merge target."
    BaseClassIncludesPrivateProperty =>
      "Base class includes private property."
    CannotAccessBeforeInitialization(name) =>
      "Cannot access '\{name}' before initialization."
    RefersToValueUsedAsType(name) =>
      "'\{name}' refers to a value, but is being used as a type here."
    BaseClassCannotHaveStaticAbstractMembers =>
      "Base class cannot have static abstract members."
    CannotAssignAbstractClassConstructor =>
      "Cannot assign an abstract class constructor type."
    CannotUseAsValueExportType(name) =>
      "'\{name}' cannot be used as a value because it was exported using 'export type'."
    CannotUseAsValueImportType(name) =>
      "'\{name}' cannot be used as a value because it was imported using 'import type'."
    AsyncFunctionReturnTypeMustBePromise =>
      "The return type of an async function must either be 'void' or 'Promise<T>'."
    InferredTypeExceedsMaxLength =>
      "The inferred type of this node exceeds the maximum length."
    TypeNotAssignableDifferentNames(t1, t2) =>
      "Type '\{t1}' is not assignable to type '\{t2}'. Two different types with same name."
    PropertyTypesIncompatible2(prop) =>
      "Types of property '\{prop}' are incompatible."
    DuplicateIdentifier(id) => "Duplicate identifier '\{id}'."
    SpreadTypesOnlyFromObjects =>
      "Spread types may only be created from object types."
    YieldExpressionImplicitlyAny =>
      "'yield' expression implicitly results in an 'any' type."
    ParameterNameNoTypeDidYouMean(name, suggestion) =>
      "Parameter has a name but no type. Did you mean '\{name}: \{suggestion}'?"
    CannotFindModule2(module) => "Cannot find module '\{module}'."
    GetSetCannotDeclareThisParameter =>
      "'get' and 'set' accessors cannot declare 'this' parameters."
    YieldOperandMustBeAwaited =>
      "Type of 'yield' operand in an async generator must be 'Awaited'."
    TypeReferencesItselfInAnnotation =>
      "Type is referenced directly or indirectly in its own type annotation."
    CannotUseInOperator(name, t) =>
      "Cannot use 'in' operator to search for '\{name}' in '\{t}'."
    ConditionAlwaysTrueNoOverlap =>
      "This condition will always return true since the types have no overlap."
    UnionTypeTooComplex2 =>
      "Expression produces a union type that is too complex to represent."
    ThisCannotBeUsedAsType =>
      "'this' cannot be used as type, only 'this' with typeof can."
    CannotReadPrivateMemberOutsideClass(member) =>
      "Cannot read private member '\{member}' outside of its defining class."
    DeleteOperandMustBeOptional =>
      "The operand of a 'delete' operator must be optional."
    CannotFindModuleNeedResolveJsonModule(module) =>
      "Cannot find module '\{module}'. Consider using '--resolveJsonModule'."
    FileNotUnderRootDir(file, rootDir) =>
      "File '\{file}' is not under 'rootDir' '\{rootDir}'. 'rootDir' is expected to contain all source files."
    ExpectedArgumentsDidYouForgetVoid(expected, got) =>
      "Expected \{expected} arguments, but got \{got}. Did you forget to include 'void'?"
    NewExpressionWithTypeLackingConstructSignature =>
      "'new' expression with type lacking construct signature."
    NewExpressionCannotBeInvoked =>
      "'new' expression cannot be invoked."
    NewExpressionOnlyInValidContext =>
      "'new' expression can only be invoked in a valid context."
    NewExpressionImplicitlyYieldsAny =>
      "'new' expression implicitly yields an 'any' type."
    OperatorCannotBeApplied(op, t1, t2) =>
      "Operator '\{op}' cannot be applied to types '\{t1}' and '\{t2}'."
    TypeCanOnlyBeIteratedWithDownlevelIteration(t) =>
      "Type '\{t}' can only be iterated through when using '--downlevelIteration'."
    CannotAssignToPrivateMethod(method) =>
      "Cannot assign to private method '\{method}'."
    ExpectedTypeArgumentsOverloads(expected, got) =>
      "Expected \{expected} type arguments, but got \{got}. Overloads have multiple forms."
    VoidNotValidDestructuringTarget =>
      "Type 'void' is not a valid type for a destructuring assignment target."
    OptionalElementCannotFollowRest =>
      "An optional element cannot follow a rest element."
    RequiredElementCannotFollowOptional =>
      "A required element cannot follow an optional element."
    IndexSignatureMustHaveTypeAnnotation =>
      "Index signature must have a type annotation."
    CanOnlyWritePropertyOnThisValue(prop) =>
      "Can only write property '\{prop}' when accessing 'this' value of class."
    PrivateIdentifiersCannotBeParameters =>
      "Private identifiers cannot be used as parameters."
    SyntaxReservedInMtsCtc =>
      "This syntax is reserved in files with '.mts' or '.cts' extension."
    AwaitExpressionRequiresPromise =>
      "'await' expression requires an argument that is a Promise."
    TypeNotArrayOrHasIterator(t) =>
      "Type '\{t}' is not an array type or does not have a '[Symbol.iterator]' method."
    ForAwaitOfCannotIterateTypes =>
      "'for await...of' loops cannot iterate types without '@@asyncIterator'."
    CouldNotFindDeclarationFile(module) =>
      "Could not find a declaration file for module '\{module}'."
    IndexSignatureIncompatibleWithOptionalProperty(idx) =>
      "Index signature '\{idx}' is incompatible with an optional property signature."
    AssignmentLeftCannotBeOptionalPropertyAccess =>
      "The left-hand side of an assignment expression may not be an optional property access."
    CannotAssignToGetOnlyProperty(prop) =>
      "Cannot assign to property '\{prop}' because it is a get-only property."
    ExpressionNotCallable => "This expression is not callable."
    UnionTypeNoMatchingNewSignature(t) =>
      "Each member of the union type '\{t}' has signature 'new' but none match."
    TypeNoNewSignatures(t) =>
      "Type '\{t}' has no signatures for 'new' operation."
    ImportNeverUsedAsValue =>
      "This import is never used as a value."
    DecoratorUsedOnUnknownField =>
      "Decorator used on unknown class field."
    CannotCallSuperFromNonDerivedConstructor =>
      "Cannot call 'super' from non-derived class constructor."
    UniqueSymbolPropertyMustBeReadonly =>
      "A property of an interface or type literal whose type is 'unique symbol' must be 'readonly'."
    CannotAssignToImport(name) =>
      "Cannot assign to '\{name}' because it is an import."
    OperatorCannotBeApplied2(op, t1, t2) =>
      "Operator '\{op}' cannot be applied to '\{t1}' and '\{t2}'."
    NoValueExistsForShorthandProperty(prop) =>
      "No value exists in scope for shorthand property '\{prop}'."
    ClassesMayNotHaveConstructorField =>
      "Classes may not have a field named 'constructor'."
    JSXElementNoClosingTag(tag) =>
      "JSX element '\{tag}' has no corresponding closing tag."
    SuperCallMustBeRootLevel =>
      "A 'super' call must be a root-level statement."
    // Build/Emit Errors (TS4000-4999)
    ImportDeclarationUsingPrivateName(decl, name) =>
      "Import declaration '\{decl}' is using private name '\{name}'."
    TypeParameterHasCircularDefault(param) =>
      "Type parameter '\{param}' has a circular default."
    ParameterOfExportedFunctionUsingPrivateName(func, name) =>
      "Parameter of exported function '\{func}' is using private name '\{name}'."
    ExtendsClauseUsingPrivateName(cls, name) =>
      "Extends clause of '\{cls}' is using private name '\{name}'."
    ImplementsClauseUsingPrivateName(cls, name) =>
      "Implements clause of '\{cls}' is using private name '\{name}'."
    ExtendsExpressionNotClassOrInterface(name) =>
      "'\{name}' expression is not a class or interface."
    ExportedVariableUsingExternalModuleName(var_name, mod_name) =>
      "Exported variable '\{var_name}' is using name '\{mod_name}' from external module."
    PublicPropertyUsingPrivateName(prop, name) =>
      "Public property '\{prop}' is using private name '\{name}'."
    PublicStaticPropertyUsingPrivateName(name) =>
      "Public static property is using private name '\{name}'."
    TypeParameterOfExportedFunctionUsingPrivateName(name) =>
      "Type parameter of exported function is using private name '\{name}'."
    TypeParameterOfPublicStaticMethodUsingPrivateName(name) =>
      "Type parameter of public static method is using private name '\{name}'."
    ReturnTypeOfPublicGetterUsingPrivateName =>
      "Return type of public getter is using private name."
    ParameterOfPublicSetterUsingPrivateName(name) =>
      "Parameter of public setter is using private name '\{name}'."
    ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName =>
      "Return type of method from exported interface is using private name."
    ParameterOfMethodFromExportedInterfaceUsingPrivateName(name) =>
      "Parameter '\{name}' of method from exported interface is using private name."
    ReturnTypeOfConstructorSignatureUsingPrivateName =>
      "Return type of constructor signature is using private name."
    ReturnTypeOfCallSignatureUsingPrivateName =>
      "Return type of call signature is using private name."
    ParameterOfCallSignatureUsingPrivateName(name) =>
      "Parameter '\{name}' of call signature is using private name."
    ReturnTypeOfIndexSignatureUsingPrivateName =>
      "Return type of index signature is using private name."
    ParameterOfIndexSignatureUsingPrivateName(name) =>
      "Parameter '\{name}' of index signature is using private name."
    DefaultExportUsingPrivateName(name) =>
      "Default export is using private name '\{name}'."
    TypeParameterOfExportedTypeAliasUsingPrivateName(name) =>
      "Type parameter of exported type alias is using private name '\{name}'."
    PropertyOfExportedMappedTypeUsingPrivateName(name) =>
      "Property of exported mapped type is using private name '\{name}'."
    ExportedTypeAliasUsingPrivateName(alias, name) =>
      "Exported type alias '\{alias}' is using private name '\{name}'."
    TypeParameterOfExportedClassExpressionUsingPrivateName(cls, name) =>
      "Type parameter of exported class expression '\{cls}' is using private name '\{name}'."
    CannotFindParameter(name) => "Cannot find parameter '\{name}'."
    RestParameterMustBeArrayType =>
      "A rest parameter must be of an array type."
    SetAccessorCannotHaveRestParameter =>
      "A 'set' accessor cannot have a rest parameter."
    GetAccessorMustHaveAtMostOneParameter =>
      "A 'get' accessor must have at most one parameter."
    SetAccessorMustHaveOneParameter =>
      "A 'set' accessor must have exactly one parameter."
  }
}

// ============================================================================
// Public test helper functions for ParserErrorCode
// These allow external tests to verify error codes without constructing enum variants
// ============================================================================

///|
/// Get the integer error code for a parser error by name
/// Used by external tests to verify error code mappings
pub fn get_parser_error_int(name : String) -> Int {
  get_parser_error_int_with_arg(name, None)
}

///|
/// Get the integer error code for a parser error by name with optional argument
pub fn get_parser_error_int_with_arg(name : String, arg : String?) -> Int {
  match name {
    "UnterminatedStringLiteral" => UnterminatedStringLiteral.to_int()
    "UnterminatedTemplateLiteral" => UnterminatedTemplateLiteral.to_int()
    "UnterminatedRegexLiteral" => UnterminatedRegexLiteral.to_int()
    "TrailingCommaNotAllowed" => TrailingCommaNotAllowed.to_int()
    "RestParameterMustBeLast" => RestParameterMustBeLast.to_int()
    "RequiredParamAfterOptional" => RequiredParamAfterOptional.to_int()
    "RestParameterCannotBeOptional" => RestParameterCannotBeOptional.to_int()
    "RestParameterCannotHaveInitializer" =>
      RestParameterCannotHaveInitializer.to_int()
    "StatementsNotAllowedInAmbient" => StatementsNotAllowedInAmbient.to_int()
    "DeclareInAmbientContext" => DeclareInAmbientContext.to_int()
    "InitializerNotAllowedInAmbient" => InitializerNotAllowedInAmbient.to_int()
    "AmbientEnumInitializerMustBeConstant" =>
      AmbientEnumInitializerMustBeConstant.to_int()
    "AsyncModifierNotAllowed" => AsyncModifierNotAllowed.to_int()
    "ModifierCannotAppearOnClassElement" =>
      ModifierCannotAppearOnClassElement(arg.unwrap_or("")).to_int()
    "ModifierCannotAppearOnConstructor" =>
      ModifierCannotAppearOnConstructor(arg.unwrap_or("")).to_int()
    "ModifiersNotAllowedHere" => ModifiersNotAllowedHere.to_int()
    "TypeParamsOnConstructor" => TypeParamsOnConstructor.to_int()
    "SetAccessorCannotHaveReturnType" =>
      SetAccessorCannotHaveReturnType.to_int()
    "GetAccessorCannotHaveParams" => GetAccessorCannotHaveParams.to_int()
    "SetAccessorMustHaveOneParam" => SetAccessorMustHaveOneParam.to_int()
    "ReturnOutsideFunction" => ReturnOutsideFunction.to_int()
    "TypeExpected" => TypeExpected.to_int()
    "DeclarationOrStatementExpected" => DeclarationOrStatementExpected.to_int()
    "PropertyOrSignatureExpected" => PropertyOrSignatureExpected.to_int()
    "StringLiteralExpected" => StringLiteralExpected.to_int()
    "LineBreakNotPermitted" => LineBreakNotPermitted.to_int()
    "ConstDeclarationMustBeInitialized" =>
      ConstDeclarationMustBeInitialized.to_int()
    "MergeConflictMarker" => MergeConflictMarker.to_int()
    // Decorator errors
    "DecoratorsNotValidHere" => DecoratorsNotValidHere.to_int()
    "ExperimentalDecoratorsWarning" => ExperimentalDecoratorsWarning.to_int()
    "UnableToResolveClassDecorator" => UnableToResolveClassDecorator.to_int()
    "UnableToResolveParameterDecorator" =>
      UnableToResolveParameterDecorator.to_int()
    "UnableToResolvePropertyDecorator" =>
      UnableToResolvePropertyDecorator.to_int()
    "DecoratorReturnTypeMustBeAssignable" =>
      DecoratorReturnTypeMustBeAssignable.to_int()
    // Module/Import errors
    "ModuleHasNoDefaultExport" =>
      ModuleHasNoDefaultExport(arg.unwrap_or("")).to_int()
    "ImportAssignmentNotAllowedInESModules" =>
      ImportAssignmentNotAllowedInESModules.to_int()
    "IsolatedModulesScriptFile" =>
      IsolatedModulesScriptFile(arg.unwrap_or("")).to_int()
    "IsolatedModulesConstEnum" =>
      IsolatedModulesConstEnum(arg.unwrap_or("")).to_int()
    "AmbientConstEnumsNotAllowedWithIsolatedModules" =>
      AmbientConstEnumsNotAllowedWithIsolatedModules.to_int()
    "ExportAssignmentNotAllowedWithModuleExports" =>
      ExportAssignmentNotAllowedWithModuleExports.to_int()
    "TypeAssertionNotAllowedInExponentiation" =>
      TypeAssertionNotAllowedInExponentiation.to_int()
    "ImportAliasCannotReferenceTypeExport" =>
      ImportAliasCannotReferenceTypeExport.to_int()
    "DeleteCannotBeCalledOnIdentifier" => DeleteCannotBeCalledOnIdentifier.to_int()
    "ClassMemberCannotHaveConst" => ClassMemberCannotHaveConst.to_int()
    "ConstInitializerMustBeLiteral" => ConstInitializerMustBeLiteral.to_int()
    "AwaitOnlyAllowedAtTopLevel" => AwaitOnlyAllowedAtTopLevel.to_int()
    "EqualsOnlyInDestructuring" => EqualsOnlyInDestructuring.to_int()
    "AwaitNotAllowedInParameterInitializer" =>
      AwaitNotAllowedInParameterInitializer.to_int()
    "DynamicImportSecondArgOnlyEsnext" => DynamicImportSecondArgOnlyEsnext.to_int()
    "TopLevelAwaitRequiresEsnext" => TopLevelAwaitRequiresEsnext.to_int()
    "TopLevelForAwaitNotSupported" => TopLevelForAwaitNotSupported.to_int()
    "DecoratorsNotAfterExport" => DecoratorsNotAfterExport.to_int()
    "DecoratorReturnTypeNotAssignable" =>
      DecoratorReturnTypeNotAssignable(arg.unwrap_or("")).to_int()
    "AwaitUsingOnlyInAsyncFunctions" => AwaitUsingOnlyInAsyncFunctions.to_int()
    "ImportPathNotStringLiteral" => ImportPathNotStringLiteral.to_int()
    "ModifierOnlyInTypeScriptFiles" =>
      ModifierOnlyInTypeScriptFiles(arg.unwrap_or("")).to_int()
    "TypeAnnotationsOnlyInTypeScriptFiles" =>
      TypeAnnotationsOnlyInTypeScriptFiles.to_int()
    "VariableDeclarationExpected" => VariableDeclarationExpected.to_int()
    "UsingDeclarationsRequireAwait" => UsingDeclarationsRequireAwait.to_int()
    "UsingDeclarationNotInParameter" => UsingDeclarationNotInParameter.to_int()
    "ESMImportExportNotValid" => ESMImportExportNotValid.to_int()
    // Assignment & Compatibility error codes (TS2307-TS2859)
    "CannotFindModule" => CannotFindModule(arg.unwrap_or("")).to_int()
    "TypeIsNotGeneric" => TypeIsNotGeneric(arg.unwrap_or("")).to_int()
    "CannotFindGlobalType" => CannotFindGlobalType(arg.unwrap_or("")).to_int()
    "PropertyDoesNotExistOnType" =>
      PropertyDoesNotExistOnType(arg.unwrap_or(""), "").to_int()
    "PropertyIsPrivate" => PropertyIsPrivate(arg.unwrap_or(""), "").to_int()
    "ArgumentNotAssignableToParameter" =>
      ArgumentNotAssignableToParameter(arg.unwrap_or(""), "").to_int()
    "ThisCannotBeReferenced" => ThisCannotBeReferenced.to_int()
    "SuperOnlyInDerivedClass" => SuperOnlyInDerivedClass.to_int()
    "ObjectPossiblyNull" => ObjectPossiblyNull.to_int()
    "ObjectPossiblyUndefined" => ObjectPossiblyUndefined.to_int()
    "ObjectPossiblyNullOrUndefined" => ObjectPossiblyNullOrUndefined.to_int()
    "CannotAssignToReadonly" => CannotAssignToReadonly(arg.unwrap_or("")).to_int()
    "AwaitOnlyInAsyncFunction" => AwaitOnlyInAsyncFunction.to_int()
    "YieldOnlyInGenerator" => YieldOnlyInGenerator.to_int()
    "DuplicateIdentifier" => DuplicateIdentifier(arg.unwrap_or("")).to_int()
    "BlockScopedVarUsedBeforeDeclaration" =>
      BlockScopedVarUsedBeforeDeclaration(arg.unwrap_or("")).to_int()
    "CannotRedeclareBlockScoped" =>
      CannotRedeclareBlockScoped(arg.unwrap_or("")).to_int()
    "VariableUsedBeforeAssigned" =>
      VariableUsedBeforeAssigned(arg.unwrap_or("")).to_int()
    "ObjectIsOfTypeUnknown" => ObjectIsOfTypeUnknown.to_int()
    "TypeInstantiationTooDeep" => TypeInstantiationTooDeep.to_int()
    "UnionTypeTooComplex" => UnionTypeTooComplex.to_int()
    "TypeAliasCircularlyReferences" =>
      TypeAliasCircularlyReferences(arg.unwrap_or("")).to_int()
    "ExpressionNotCallable" => ExpressionNotCallable.to_int()
    "ExpressionNotConstructable" => ExpressionNotConstructable.to_int()
    "ThisImplicitlyHasTypeAny" => ThisImplicitlyHasTypeAny.to_int()
    "PropertyHasNoInitializer" =>
      PropertyHasNoInitializer(arg.unwrap_or("")).to_int()
    "PropertyUsedBeforeAssigned" =>
      PropertyUsedBeforeAssigned(arg.unwrap_or("")).to_int()
    "AssignmentLeftMustBeVariable" => AssignmentLeftMustBeVariable.to_int()
    "FunctionLacksEndingReturn" => FunctionLacksEndingReturn.to_int()
    "DerivedClassMustHaveSuper" => DerivedClassMustHaveSuper.to_int()
    "SuperCallMustBeFirst" => SuperCallMustBeFirst.to_int()
    "AbstractMethodOnlyInAbstractClass" => AbstractMethodOnlyInAbstractClass.to_int()
    "NonAbstractClassMissingAbstractMember" =>
      NonAbstractClassMissingAbstractMember(arg.unwrap_or(""), "").to_int()
    // Build/Emit Errors (TS4000-4999)
    "ImportDeclarationUsingPrivateName" =>
      ImportDeclarationUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "TypeParameterHasCircularDefault" =>
      TypeParameterHasCircularDefault(arg.unwrap_or("")).to_int()
    "ParameterOfExportedFunctionUsingPrivateName" =>
      ParameterOfExportedFunctionUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "ExtendsClauseUsingPrivateName" =>
      ExtendsClauseUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "ImplementsClauseUsingPrivateName" =>
      ImplementsClauseUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "ExtendsExpressionNotClassOrInterface" =>
      ExtendsExpressionNotClassOrInterface(arg.unwrap_or("")).to_int()
    "ExportedVariableUsingExternalModuleName" =>
      ExportedVariableUsingExternalModuleName(arg.unwrap_or(""), "").to_int()
    "PublicPropertyUsingPrivateName" =>
      PublicPropertyUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "PublicStaticPropertyUsingPrivateName" =>
      PublicStaticPropertyUsingPrivateName(arg.unwrap_or("")).to_int()
    "TypeParameterOfExportedFunctionUsingPrivateName" =>
      TypeParameterOfExportedFunctionUsingPrivateName(arg.unwrap_or("")).to_int()
    "TypeParameterOfPublicStaticMethodUsingPrivateName" =>
      TypeParameterOfPublicStaticMethodUsingPrivateName(arg.unwrap_or("")).to_int()
    "ReturnTypeOfPublicGetterUsingPrivateName" =>
      ReturnTypeOfPublicGetterUsingPrivateName.to_int()
    "ParameterOfPublicSetterUsingPrivateName" =>
      ParameterOfPublicSetterUsingPrivateName(arg.unwrap_or("")).to_int()
    "ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName" =>
      ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName.to_int()
    "ParameterOfMethodFromExportedInterfaceUsingPrivateName" =>
      ParameterOfMethodFromExportedInterfaceUsingPrivateName(arg.unwrap_or("")).to_int()
    "ReturnTypeOfConstructorSignatureUsingPrivateName" =>
      ReturnTypeOfConstructorSignatureUsingPrivateName.to_int()
    "ReturnTypeOfCallSignatureUsingPrivateName" =>
      ReturnTypeOfCallSignatureUsingPrivateName.to_int()
    "ParameterOfCallSignatureUsingPrivateName" =>
      ParameterOfCallSignatureUsingPrivateName(arg.unwrap_or("")).to_int()
    "ReturnTypeOfIndexSignatureUsingPrivateName" =>
      ReturnTypeOfIndexSignatureUsingPrivateName.to_int()
    "ParameterOfIndexSignatureUsingPrivateName" =>
      ParameterOfIndexSignatureUsingPrivateName(arg.unwrap_or("")).to_int()
    "DefaultExportUsingPrivateName" =>
      DefaultExportUsingPrivateName(arg.unwrap_or("")).to_int()
    "TypeParameterOfExportedTypeAliasUsingPrivateName" =>
      TypeParameterOfExportedTypeAliasUsingPrivateName(arg.unwrap_or("")).to_int()
    "PropertyOfExportedMappedTypeUsingPrivateName" =>
      PropertyOfExportedMappedTypeUsingPrivateName(arg.unwrap_or("")).to_int()
    "ExportedTypeAliasUsingPrivateName" =>
      ExportedTypeAliasUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "TypeParameterOfExportedClassExpressionUsingPrivateName" =>
      TypeParameterOfExportedClassExpressionUsingPrivateName(arg.unwrap_or(""), "").to_int()
    "CannotFindParameter" => CannotFindParameter(arg.unwrap_or("")).to_int()
    "RestParameterMustBeArrayType" => RestParameterMustBeArrayType.to_int()
    "SetAccessorCannotHaveRestParameter" =>
      SetAccessorCannotHaveRestParameter.to_int()
    "GetAccessorMustHaveAtMostOneParameter" =>
      GetAccessorMustHaveAtMostOneParameter.to_int()
    "SetAccessorMustHaveOneParameter" => SetAccessorMustHaveOneParameter.to_int()
    _ => -1
  }
}

///|
/// Get the error message for a parser error by name
pub fn get_parser_error_message(name : String) -> String {
  get_parser_error_message_with_arg(name, None)
}

///|
/// Get the error message for a parser error by name with optional argument
pub fn get_parser_error_message_with_arg(name : String, arg : String?) -> String {
  match name {
    "UnterminatedStringLiteral" => UnterminatedStringLiteral.to_message()
    "UnterminatedTemplateLiteral" => UnterminatedTemplateLiteral.to_message()
    "UnterminatedRegexLiteral" => UnterminatedRegexLiteral.to_message()
    "TrailingCommaNotAllowed" => TrailingCommaNotAllowed.to_message()
    "RestParameterMustBeLast" => RestParameterMustBeLast.to_message()
    "RequiredParamAfterOptional" => RequiredParamAfterOptional.to_message()
    "RestParameterCannotBeOptional" => RestParameterCannotBeOptional.to_message()
    "RestParameterCannotHaveInitializer" =>
      RestParameterCannotHaveInitializer.to_message()
    "StatementsNotAllowedInAmbient" => StatementsNotAllowedInAmbient.to_message()
    "DeclareInAmbientContext" => DeclareInAmbientContext.to_message()
    "InitializerNotAllowedInAmbient" =>
      InitializerNotAllowedInAmbient.to_message()
    "AmbientEnumInitializerMustBeConstant" =>
      AmbientEnumInitializerMustBeConstant.to_message()
    "AsyncModifierNotAllowed" => AsyncModifierNotAllowed.to_message()
    "ModifierCannotAppearOnClassElement" =>
      ModifierCannotAppearOnClassElement(arg.unwrap_or("")).to_message()
    "ModifierCannotAppearOnConstructor" =>
      ModifierCannotAppearOnConstructor(arg.unwrap_or("")).to_message()
    "ModifiersNotAllowedHere" => ModifiersNotAllowedHere.to_message()
    "TypeParamsOnConstructor" => TypeParamsOnConstructor.to_message()
    "SetAccessorCannotHaveReturnType" =>
      SetAccessorCannotHaveReturnType.to_message()
    "GetAccessorCannotHaveParams" => GetAccessorCannotHaveParams.to_message()
    "SetAccessorMustHaveOneParam" => SetAccessorMustHaveOneParam.to_message()
    "ReturnOutsideFunction" => ReturnOutsideFunction.to_message()
    "TypeExpected" => TypeExpected.to_message()
    "DeclarationOrStatementExpected" =>
      DeclarationOrStatementExpected.to_message()
    "PropertyOrSignatureExpected" => PropertyOrSignatureExpected.to_message()
    "StringLiteralExpected" => StringLiteralExpected.to_message()
    "LineBreakNotPermitted" => LineBreakNotPermitted.to_message()
    "ConstDeclarationMustBeInitialized" =>
      ConstDeclarationMustBeInitialized.to_message()
    "MergeConflictMarker" => MergeConflictMarker.to_message()
    // Decorator errors
    "DecoratorsNotValidHere" => DecoratorsNotValidHere.to_message()
    "ExperimentalDecoratorsWarning" => ExperimentalDecoratorsWarning.to_message()
    "UnableToResolveClassDecorator" => UnableToResolveClassDecorator.to_message()
    "UnableToResolveParameterDecorator" =>
      UnableToResolveParameterDecorator.to_message()
    "UnableToResolvePropertyDecorator" =>
      UnableToResolvePropertyDecorator.to_message()
    "DecoratorReturnTypeMustBeAssignable" =>
      DecoratorReturnTypeMustBeAssignable.to_message()
    // Module/Import errors
    "ModuleHasNoDefaultExport" =>
      ModuleHasNoDefaultExport(arg.unwrap_or("")).to_message()
    "ImportAssignmentNotAllowedInESModules" =>
      ImportAssignmentNotAllowedInESModules.to_message()
    "IsolatedModulesScriptFile" =>
      IsolatedModulesScriptFile(arg.unwrap_or("")).to_message()
    "IsolatedModulesConstEnum" =>
      IsolatedModulesConstEnum(arg.unwrap_or("")).to_message()
    "AmbientConstEnumsNotAllowedWithIsolatedModules" =>
      AmbientConstEnumsNotAllowedWithIsolatedModules.to_message()
    "ExportAssignmentNotAllowedWithModuleExports" =>
      ExportAssignmentNotAllowedWithModuleExports.to_message()
    "TypeAssertionNotAllowedInExponentiation" =>
      TypeAssertionNotAllowedInExponentiation.to_message()
    "ImportAliasCannotReferenceTypeExport" =>
      ImportAliasCannotReferenceTypeExport.to_message()
    "DeleteCannotBeCalledOnIdentifier" =>
      DeleteCannotBeCalledOnIdentifier.to_message()
    "ClassMemberCannotHaveConst" => ClassMemberCannotHaveConst.to_message()
    "ConstInitializerMustBeLiteral" => ConstInitializerMustBeLiteral.to_message()
    "AwaitOnlyAllowedAtTopLevel" => AwaitOnlyAllowedAtTopLevel.to_message()
    "EqualsOnlyInDestructuring" => EqualsOnlyInDestructuring.to_message()
    "AwaitNotAllowedInParameterInitializer" =>
      AwaitNotAllowedInParameterInitializer.to_message()
    "DynamicImportSecondArgOnlyEsnext" =>
      DynamicImportSecondArgOnlyEsnext.to_message()
    "TopLevelAwaitRequiresEsnext" => TopLevelAwaitRequiresEsnext.to_message()
    "TopLevelForAwaitNotSupported" => TopLevelForAwaitNotSupported.to_message()
    "DecoratorsNotAfterExport" => DecoratorsNotAfterExport.to_message()
    "DecoratorReturnTypeNotAssignable" =>
      DecoratorReturnTypeNotAssignable(arg.unwrap_or("")).to_message()
    "AwaitUsingOnlyInAsyncFunctions" =>
      AwaitUsingOnlyInAsyncFunctions.to_message()
    "ImportPathNotStringLiteral" => ImportPathNotStringLiteral.to_message()
    "ModifierOnlyInTypeScriptFiles" =>
      ModifierOnlyInTypeScriptFiles(arg.unwrap_or("")).to_message()
    "TypeAnnotationsOnlyInTypeScriptFiles" =>
      TypeAnnotationsOnlyInTypeScriptFiles.to_message()
    "VariableDeclarationExpected" => VariableDeclarationExpected.to_message()
    "UsingDeclarationsRequireAwait" => UsingDeclarationsRequireAwait.to_message()
    "UsingDeclarationNotInParameter" =>
      UsingDeclarationNotInParameter.to_message()
    "ESMImportExportNotValid" => ESMImportExportNotValid.to_message()
    // Assignment & Compatibility error codes (TS2307-TS2859)
    "CannotFindModule" => CannotFindModule(arg.unwrap_or("")).to_message()
    "TypeIsNotGeneric" => TypeIsNotGeneric(arg.unwrap_or("")).to_message()
    "CannotFindGlobalType" => CannotFindGlobalType(arg.unwrap_or("")).to_message()
    "PropertyDoesNotExistOnType" =>
      PropertyDoesNotExistOnType(arg.unwrap_or(""), "").to_message()
    "PropertyIsPrivate" => PropertyIsPrivate(arg.unwrap_or(""), "").to_message()
    "ArgumentNotAssignableToParameter" =>
      ArgumentNotAssignableToParameter(arg.unwrap_or(""), "").to_message()
    "ThisCannotBeReferenced" => ThisCannotBeReferenced.to_message()
    "SuperOnlyInDerivedClass" => SuperOnlyInDerivedClass.to_message()
    "ObjectPossiblyNull" => ObjectPossiblyNull.to_message()
    "ObjectPossiblyUndefined" => ObjectPossiblyUndefined.to_message()
    "ObjectPossiblyNullOrUndefined" => ObjectPossiblyNullOrUndefined.to_message()
    "CannotAssignToReadonly" =>
      CannotAssignToReadonly(arg.unwrap_or("")).to_message()
    "AwaitOnlyInAsyncFunction" => AwaitOnlyInAsyncFunction.to_message()
    "YieldOnlyInGenerator" => YieldOnlyInGenerator.to_message()
    "DuplicateIdentifier" => DuplicateIdentifier(arg.unwrap_or("")).to_message()
    "BlockScopedVarUsedBeforeDeclaration" =>
      BlockScopedVarUsedBeforeDeclaration(arg.unwrap_or("")).to_message()
    "CannotRedeclareBlockScoped" =>
      CannotRedeclareBlockScoped(arg.unwrap_or("")).to_message()
    "VariableUsedBeforeAssigned" =>
      VariableUsedBeforeAssigned(arg.unwrap_or("")).to_message()
    "ObjectIsOfTypeUnknown" => ObjectIsOfTypeUnknown.to_message()
    "TypeInstantiationTooDeep" => TypeInstantiationTooDeep.to_message()
    "UnionTypeTooComplex" => UnionTypeTooComplex.to_message()
    "TypeAliasCircularlyReferences" =>
      TypeAliasCircularlyReferences(arg.unwrap_or("")).to_message()
    "ExpressionNotCallable" => ExpressionNotCallable.to_message()
    "ExpressionNotConstructable" => ExpressionNotConstructable.to_message()
    "ThisImplicitlyHasTypeAny" => ThisImplicitlyHasTypeAny.to_message()
    "PropertyHasNoInitializer" =>
      PropertyHasNoInitializer(arg.unwrap_or("")).to_message()
    "PropertyUsedBeforeAssigned" =>
      PropertyUsedBeforeAssigned(arg.unwrap_or("")).to_message()
    "AssignmentLeftMustBeVariable" => AssignmentLeftMustBeVariable.to_message()
    "FunctionLacksEndingReturn" => FunctionLacksEndingReturn.to_message()
    "DerivedClassMustHaveSuper" => DerivedClassMustHaveSuper.to_message()
    "SuperCallMustBeFirst" => SuperCallMustBeFirst.to_message()
    "AbstractMethodOnlyInAbstractClass" =>
      AbstractMethodOnlyInAbstractClass.to_message()
    "NonAbstractClassMissingAbstractMember" =>
      NonAbstractClassMissingAbstractMember(arg.unwrap_or(""), "").to_message()
    // Build/Emit Errors (TS4000-4999)
    "ImportDeclarationUsingPrivateName" =>
      ImportDeclarationUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "TypeParameterHasCircularDefault" =>
      TypeParameterHasCircularDefault(arg.unwrap_or("")).to_message()
    "ParameterOfExportedFunctionUsingPrivateName" =>
      ParameterOfExportedFunctionUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "ExtendsClauseUsingPrivateName" =>
      ExtendsClauseUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "ImplementsClauseUsingPrivateName" =>
      ImplementsClauseUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "ExtendsExpressionNotClassOrInterface" =>
      ExtendsExpressionNotClassOrInterface(arg.unwrap_or("")).to_message()
    "ExportedVariableUsingExternalModuleName" =>
      ExportedVariableUsingExternalModuleName(arg.unwrap_or(""), "").to_message()
    "PublicPropertyUsingPrivateName" =>
      PublicPropertyUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "PublicStaticPropertyUsingPrivateName" =>
      PublicStaticPropertyUsingPrivateName(arg.unwrap_or("")).to_message()
    "TypeParameterOfExportedFunctionUsingPrivateName" =>
      TypeParameterOfExportedFunctionUsingPrivateName(arg.unwrap_or("")).to_message()
    "TypeParameterOfPublicStaticMethodUsingPrivateName" =>
      TypeParameterOfPublicStaticMethodUsingPrivateName(arg.unwrap_or("")).to_message()
    "ReturnTypeOfPublicGetterUsingPrivateName" =>
      ReturnTypeOfPublicGetterUsingPrivateName.to_message()
    "ParameterOfPublicSetterUsingPrivateName" =>
      ParameterOfPublicSetterUsingPrivateName(arg.unwrap_or("")).to_message()
    "ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName" =>
      ReturnTypeOfMethodFromExportedInterfaceUsingPrivateName.to_message()
    "ParameterOfMethodFromExportedInterfaceUsingPrivateName" =>
      ParameterOfMethodFromExportedInterfaceUsingPrivateName(arg.unwrap_or("")).to_message()
    "ReturnTypeOfConstructorSignatureUsingPrivateName" =>
      ReturnTypeOfConstructorSignatureUsingPrivateName.to_message()
    "ReturnTypeOfCallSignatureUsingPrivateName" =>
      ReturnTypeOfCallSignatureUsingPrivateName.to_message()
    "ParameterOfCallSignatureUsingPrivateName" =>
      ParameterOfCallSignatureUsingPrivateName(arg.unwrap_or("")).to_message()
    "ReturnTypeOfIndexSignatureUsingPrivateName" =>
      ReturnTypeOfIndexSignatureUsingPrivateName.to_message()
    "ParameterOfIndexSignatureUsingPrivateName" =>
      ParameterOfIndexSignatureUsingPrivateName(arg.unwrap_or("")).to_message()
    "DefaultExportUsingPrivateName" =>
      DefaultExportUsingPrivateName(arg.unwrap_or("")).to_message()
    "TypeParameterOfExportedTypeAliasUsingPrivateName" =>
      TypeParameterOfExportedTypeAliasUsingPrivateName(arg.unwrap_or("")).to_message()
    "PropertyOfExportedMappedTypeUsingPrivateName" =>
      PropertyOfExportedMappedTypeUsingPrivateName(arg.unwrap_or("")).to_message()
    "ExportedTypeAliasUsingPrivateName" =>
      ExportedTypeAliasUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "TypeParameterOfExportedClassExpressionUsingPrivateName" =>
      TypeParameterOfExportedClassExpressionUsingPrivateName(arg.unwrap_or(""), "").to_message()
    "CannotFindParameter" => CannotFindParameter(arg.unwrap_or("")).to_message()
    "RestParameterMustBeArrayType" => RestParameterMustBeArrayType.to_message()
    "SetAccessorCannotHaveRestParameter" =>
      SetAccessorCannotHaveRestParameter.to_message()
    "GetAccessorMustHaveAtMostOneParameter" =>
      GetAccessorMustHaveAtMostOneParameter.to_message()
    "SetAccessorMustHaveOneParameter" =>
      SetAccessorMustHaveOneParameter.to_message()
    _ => "Unknown error"
  }
}

///|
/// Add error with specific error code
fn add_error_with_code(
  parser : Parser,
  message : String,
  location : SourceLocation,
  code : ParserErrorCode,
) -> Parser {
  add_error_checked(parser, message, location, code.to_int())
}

///|
/// Check if token is a statement start (synchronization point)
fn is_statement_start(token : Token) -> Bool {
  match token {
    KeywordLet(_)
    | KeywordConst(_)
    | KeywordVar(_)
    | KeywordFunction(_)
    | KeywordClass(_)
    | KeywordInterface(_)
    | KeywordType(_)
    | KeywordEnum(_)
    | KeywordIf(_)
    | KeywordFor(_)
    | KeywordWhile(_)
    | KeywordDo(_)
    | KeywordReturn(_)
    | KeywordThrow(_)
    | KeywordTry(_)
    | KeywordSwitch(_)
    | KeywordBreak(_)
    | KeywordContinue(_)
    | KeywordImport(_)
    | KeywordExport(_)
    | OpenBrace(_)
    | Semicolon(_)
    | KeywordDebugger(_) => true
    _ => false
  }
}

///|
/// Synchronize to next statement (enhanced version)
fn synchronize_to_statement(parser : Parser) -> Parser {
  let mut parser = parser
  while !is_at_end(parser) {
    // Check if current token is a statement start
    if is_statement_start(current_token(parser)) {
      return parser
    }

    // Check if previous token ended a statement
    match current_token(parser) {
      Semicolon(_) => return advance_parser(parser)
      CloseBrace(_) => return parser
      _ => parser = advance_parser(parser)
    }
  }
  parser
}

///|
/// Synchronize to expression end
fn synchronize_to_expression_end(parser : Parser) -> Parser {
  let mut parser = parser
  let mut paren_depth = 0
  let mut bracket_depth = 0
  let mut brace_depth = 0
  while !is_at_end(parser) {
    match current_token(parser) {
      OpenParen(_) => paren_depth = paren_depth + 1
      CloseParen(_) => {
        if paren_depth == 0 {
          return parser
        }
        paren_depth = paren_depth - 1
      }
      OpenBracket(_) => bracket_depth = bracket_depth + 1
      CloseBracket(_) => {
        if bracket_depth == 0 {
          return parser
        }
        bracket_depth = bracket_depth - 1
      }
      OpenBrace(_) => brace_depth = brace_depth + 1
      CloseBrace(_) => {
        if brace_depth == 0 {
          return parser
        }
        brace_depth = brace_depth - 1
      }
      Semicolon(_) | Comma(_) =>
        if paren_depth == 0 && bracket_depth == 0 && brace_depth == 0 {
          return parser
        }
      _ => ()
    }
    parser = advance_parser(parser)
  }
  parser
}

///|
/// Parse a complete source file
pub fn parse_source_file(
  tokens : Array[Token],
  file_path : String,
) -> ParseResult[SourceFile] {
  // Extract triple-slash directive tokens, hashbang, and filter out comment tokens
  let directive_tokens : Array[(String, SourceLocation)] = []
  let filtered_tokens : Array[Token] = []
  let mut hashbang : String? = None
  for i = 0; i < tokens.length(); i = i + 1 {
    match tokens[i] {
      Hashbang(content, _) => hashbang = Some(content)  // Extract hashbang
      CommentDirective(TripleSlashRef, content, loc) => {
        directive_tokens.push((content, loc))
        // Don't add to filtered_tokens - skip directive tokens during parsing
      }
      CommentDirective(_, _, _) => ()  // Skip other comment directives
      JSDocComment(_, _) => ()  // Skip JSDoc comments - handled separately
      token => filtered_tokens.push(token)
    }
  }

  let parser = Parser::new(filtered_tokens)
  // Enable JSX mode for .tsx and .jsx files
  let parser = if file_path.has_suffix(".tsx") || file_path.has_suffix(".jsx") {
    { ..parser, context: { ..parser.context, in_jsx: true } }
  } else {
    parser
  }
  let (statements, parser) = parse_statements(parser)
  let eof_token = current_token(parser)
  if parser.diagnostics.length() > 0 {
    Err(parser.diagnostics)
  } else {
    Ok(SourceFile::{
      file_path,
      statements,
      end_of_file_token: eof_token,
      has_no_default_lib: false,
      directive_tokens,
      hashbang,
    })
  }
}

///|
/// Parse all statements until EOF
fn parse_statements(parser : Parser) -> (Array[Node], Parser) {
  parse_statements_aux(parser, [])
}

///|
/// Tail-recursive helper for parse_statements with accumulator
fn parse_statements_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  if is_at_end(parser) {
    (acc, parser)
  } else {
    let current_position = parser.position
    match parse_statement(parser) {
      Ok((stmt, next_parser)) => {
        acc.push(stmt)
        // Safeguard: ensure parser advanced
        if next_parser.position == current_position {
          // Parser stuck - force advance to prevent infinite loop
          parse_statements_aux(advance_parser(next_parser), acc)
        } else {
          parse_statements_aux(next_parser, acc)
        }
      }
      Err(next_parser) => {
        // Error recovery: skip to next statement
        let recovered_parser = skip_to_next_statement(next_parser)
        // Safeguard: ensure error recovery advanced parser
        if recovered_parser.position == current_position {
          // Still stuck - force advance and stop parsing to prevent infinite loop
          (acc, advance_parser(recovered_parser))
        } else {
          parse_statements_aux(recovered_parser, acc)
        }
      }
    }
  }
}

///|
/// Parse a single statement
fn parse_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let token = current_token(parser)
  match token {
    // Variable declarations
    KeywordLet(_) | KeywordVar(_) => parse_variable_statement(parser)

    // Function declaration
    KeywordFunction(_) => parse_function_declaration(parser, false, false)

    // Async function
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordFunction(_) => parse_function_declaration(parser, true, false)
        _ => parse_expression_statement(parser)
      }
    }

    // Decorator(s) followed by class/function declaration
    At(_) => {
      let (decorators, parser) = parse_decorators(parser)
      match current_token(parser) {
        KeywordClass(_) =>
          parse_class_declaration_with_decorators(parser, false, decorators)
        KeywordAbstract(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            KeywordClass(_) =>
              parse_class_declaration_with_decorators(parser, true, decorators)
            _ => {
              let loc = current_token(parser).location()
              Err(
                add_error_with_code(
                  parser,
                  ExpectedClassKeyword.to_message(),
                  loc,
                  ExpectedClassKeyword,
                ),
              )
            }
          }
        }
        KeywordFunction(_) => parse_function_declaration(parser, false, false)
        KeywordAsync(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            KeywordFunction(_) =>
              parse_function_declaration(parser, true, false)
            _ => {
              let loc = current_token(parser).location()
              Err(
                add_error_with_code(
                  parser,
                  ExpectedFunctionKeyword.to_message(),
                  loc,
                  ExpectedFunctionKeyword,
                ),
              )
            }
          }
        }
        // @decorator export class ... - handle decorated exports
        KeywordExport(_) =>
          parse_export_declaration_with_decorators(parser, decorators)
        // Decorators not valid on these declarations - TS1206
        KeywordInterface(_)
        | KeywordType(_)
        | KeywordEnum(_)
        | KeywordConst(_)
        | KeywordLet(_)
        | KeywordVar(_) => {
          let loc = get_location(decorators[0])
          Err(
            add_error_with_code(
              parser,
              DecoratorsNotValidHere.to_message(),
              loc,
              DecoratorsNotValidHere,
            ),
          )
        }
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error_with_code(
              parser, DecoratorsNotValidHere.to_message(),
              loc,
              DecoratorsNotValidHere,
            ),
          )
        }
      }
    }

    // Class declaration
    KeywordClass(_) =>
      parse_class_declaration_with_decorators(parser, false, [])

    // Abstract class declaration
    KeywordAbstract(_) => {
      let parser = advance_parser(parser) // consume 'abstract'
      match current_token(parser) {
        KeywordClass(_) =>
          parse_class_declaration_with_decorators(parser, true, [])
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error_with_code(
              parser,
              ExpectedClassKeyword.to_message(),
              loc,
              ExpectedClassKeyword,
            ),
          )
        }
      }
    }

    // Interface declaration
    KeywordInterface(_) => parse_interface_declaration(parser)

    // Type alias
    KeywordType(_) => parse_type_alias_declaration(parser)

    // Enum declaration (check for const enum)
    KeywordConst(_) => {
      // Look ahead for enum keyword
      let next_token = peek_token(parser)
      match next_token {
        KeywordEnum(_) => {
          // const enum
          let parser = advance_parser(parser) // consume 'const'
          parse_enum_declaration(parser, true) // is_const = true
        }
        _ =>
          // Regular const declaration
          parse_variable_statement(parser)
      }
    }
    KeywordEnum(_) => parse_enum_declaration(parser, false)

    // Namespace/module declaration
    KeywordNamespace(_) | KeywordModule(_) => parse_module_declaration(parser)

    // Import declaration or dynamic import expression
    KeywordImport(_) => {
      // Check if this is a dynamic import (import followed by open paren)
      if parser.position + 1 < parser.tokens.length() {
        match parser.tokens[parser.position + 1] {
          OpenParen(_) => parse_expression_statement(parser) // Dynamic import
          _ => parse_import_declaration(parser)
        }
      } else {
        parse_import_declaration(parser)
      }
    }

    // Export declaration
    KeywordExport(_) => parse_export_declaration(parser)

    // Declare (ambient) declaration
    KeywordDeclare(_) => parse_declare_declaration(parser)

    // Using statement (TS 5.2+): using x = expr;
    KeywordUsing(start_loc) => parse_using_statement(parser, start_loc, false)

    // Await using statement (TS 5.2+): await using x = expr;
    KeywordAwait(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordUsing(loc) => parse_using_statement(parser, loc, true)
        _ => parse_expression_statement(parser)
      }
    }

    // Control flow
    KeywordIf(_) => parse_if_statement(parser)
    KeywordSwitch(_) => parse_switch_statement(parser)
    KeywordFor(_) => parse_for_statement(parser)
    KeywordWhile(_) => parse_while_statement(parser)
    KeywordDo(_) => parse_do_while_statement(parser)
    KeywordBreak(_) => parse_break_statement(parser)
    KeywordContinue(_) => parse_continue_statement(parser)
    KeywordReturn(_) => parse_return_statement(parser)
    KeywordThrow(_) => parse_throw_statement(parser)
    KeywordTry(_) => parse_try_statement(parser)
    KeywordDebugger(loc) => {
      let parser = advance_parser(parser)
      // Optional semicolon
      let parser = match current_token(parser) {
        Semicolon(_) => advance_parser(parser)
        _ => parser
      }
      Ok(
        (Node::DebuggerStatement(DebuggerStatement::{ location: loc }), parser),
      )
    }

    // Block statement
    OpenBrace(_) => parse_block_statement(parser)

    // Empty statement
    Semicolon(_) => {
      let loc = token.location()
      Ok(
        (
          Node::EmptyStatement(EmptyStatement::{ location: loc }),
          advance_parser(parser),
        ),
      )
    }

    // Check for labeled statement: identifier followed by colon
    Identifier(name, loc) => {
      let next_token = peek_token(parser)
      match next_token {
        Colon(_) => {
          // This is a labeled statement
          let parser = advance_parser(parser) // consume identifier
          let parser = advance_parser(parser) // consume colon
          match parse_statement(parser) {
            Ok((stmt, parser)) =>
              Ok(
                (
                  Node::LabeledStatement(LabeledStatement::{
                    label: name,
                    statement: stmt,
                    location: loc,
                  }),
                  parser,
                ),
              )
            Err(parser) => Err(parser)
          }
        }
        _ => parse_expression_statement(parser)
      }
    }

    // Expression statement (default)
    _ => parse_expression_statement(parser)
  }
}

///|
/// Helper: Parse variable declarations without consuming trailing semicolon
/// Used in contexts like for-loops where semicolon is handled separately
fn parse_variable_declaration_list(
  parser : Parser,
  consume_keyword : Bool,
) -> Result[
  (Array[VariableDeclaration], Bool, Bool, SourceLocation, Parser),
  Parser,
] {
  let start_token = current_token(parser)
  let is_const = match start_token {
    KeywordConst(_) => true
    _ => false
  }
  let is_let = match start_token {
    KeywordLet(_) => true
    _ => false
  }
  let parser = if consume_keyword { advance_parser(parser) } else { parser }

  // Parse variable declarations
  let declarations : Array[VariableDeclaration] = []
  let mut parser = parser
  let mut should_continue = true
  while should_continue {
    match parse_variable_declaration(parser) {
      Ok((decl, next_parser)) => {
        declarations.push(decl)
        parser = next_parser

        // Check for comma (multiple declarations)
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          // Continue loop
          _ => should_continue = false
        }
      }
      Err(err_parser) => return Err(err_parser)
    }
  }

  let location = start_token.location()
  Ok((declarations, is_const, is_let, location, parser))
}

///|
/// Validate that const declarations have initializers
fn validate_const_initializers(
  parser : Parser,
  declarations : Array[VariableDeclaration],
) -> Parser {
  let mut parser = parser
  for decl in declarations {
    if decl.initializer.is_empty() {
      parser = add_error_with_code(
        parser,
        ConstDeclarationMustBeInitialized.to_message(),
        decl.location,
        ConstDeclarationMustBeInitialized,
      )
    }
  }
  parser
}

///|
/// Parse variable statement (let/const/var)
fn parse_variable_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  match parse_variable_declaration_list(parser, true) {
    Ok((declarations, is_const, is_let, location, parser)) => {
      // Note: TS1155 (const must be initialized) is checked in the checker
      // because we need to know if 'declare' modifier is present
      // (declare const doesn't require initializer)
      // Expect semicolon for standalone variable statements
      let parser = expect_semicolon(parser)
      Ok(
        (
          Node::VariableStatement(VariableStatement::{
            declarations,
            is_const,
            is_let,
            modifiers: [],
            location,
          }),
          parser,
        ),
      )
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse using statement (TS 5.2+)
/// `using x = expr;` or `await using x = expr;`
fn parse_using_statement(
  parser : Parser,
  start_loc : SourceLocation,
  is_await : Bool,
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume 'using'

  // Parse declarations
  let declarations : Array[VariableDeclaration] = []
  let mut parser = parser
  let mut first = true

  while true {
    if not(first) {
      // Check for comma to continue
      match current_token(parser) {
        Comma(_) => parser = advance_parser(parser)
        _ => break
      }
    }
    first = false

    // Parse identifier
    match parse_identifier(parser) {
      Ok((id, p)) => {
        parser = p
        let name = Node::Identifier(id)

        // Optional type annotation
        let (type_annotation, p2) = match current_token(parser) {
          Colon(_) => {
            let p = advance_parser(parser)
            match parse_type(p) {
              Ok((ty, p3)) => (Some(ty), p3)
              Err(p3) => (None, p3)
            }
          }
          _ => (None, parser)
        }
        parser = p2

        // Initializer (required for using)
        let (initializer, p3) = match current_token(parser) {
          Equals(_) => {
            let p = advance_parser(parser)
            match parse_assignment_expression(p) {
              Ok((expr, p4)) => (Some(expr), p4)
              Err(p4) => (None, p4)
            }
          }
          _ => (None, parser)
        }
        parser = p3

        declarations.push(VariableDeclaration::{
          name,
          type_annotation,
          initializer,
          location: id.location,
        })
      }
      Err(p) => {
        parser = p
        break
      }
    }
  }

  // Consume semicolon
  let parser = expect_semicolon(parser)

  Ok(
    (
      Node::UsingStatement(UsingStatement::{
        declarations,
        is_await,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse a single variable declaration
fn parse_variable_declaration(
  parser : Parser,
) -> Result[(VariableDeclaration, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Parse name (identifier or binding pattern)
  let (name, parser) = match current_token(parser) {
    OpenBracket(_) =>
      // Array destructuring pattern
      match parse_array_binding_pattern(parser) {
        Ok((pattern, p)) => (pattern, p)
        Err(p) => return Err(p)
      }
    OpenBrace(_) =>
      // Object destructuring pattern
      match parse_object_binding_pattern(parser) {
        Ok((pattern, p)) => (pattern, p)
        Err(p) => return Err(p)
      }
    _ =>
      // Regular identifier
      match parse_identifier(parser) {
        Ok((id, p)) => (Node::Identifier(id), p)
        Err(p) =>
          return Err(
            add_error(
              p, "Identifier expected", start_loc,
            ),
          )
      }
  }

  // Optional type annotation
  let (type_annotation, parser) = match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Optional initializer
  let (initializer, parser) = match current_token(parser) {
    Equals(_) => {
      let parser = advance_parser(parser)
      match parse_assignment_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }
  Ok(
    (
      VariableDeclaration::{
        name,
        type_annotation,
        initializer,
        location: start_loc,
      },
      parser,
    ),
  )
}

///|
/// Parse array binding pattern: [a, b] or [a, , c]
fn parse_array_binding_pattern(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume '['
  let elements = []
  let mut parser = parser
  while true {
    match current_token(parser) {
      CloseBracket(_) => {
        parser = advance_parser(parser)
        break
      }
      Comma(_) => {
        // Hole in array pattern
        elements.push(None)
        parser = advance_parser(parser)
      }
      Identifier(name, loc) => {
        elements.push(
          Some(Node::Identifier(Identifier::{ name, location: loc })),
        )
        parser = advance_parser(parser)

        // Optional comma
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          _ => ()
        }
      }
      OpenBracket(_) =>
        // Nested array pattern
        match parse_array_binding_pattern(parser) {
          Ok((pattern, p)) => {
            elements.push(Some(pattern))
            parser = p
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          Err(p) => return Err(p)
        }
      OpenBrace(_) =>
        // Nested object pattern
        match parse_object_binding_pattern(parser) {
          Ok((pattern, p)) => {
            elements.push(Some(pattern))
            parser = p
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          Err(p) => return Err(p)
        }
      _ => break
    }
  }
  Ok(
    (
      Node::ArrayBindingPattern(ArrayBindingPattern::{
        elements,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse object binding pattern: { x, y } or { x: a, y: b }
fn parse_object_binding_pattern(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume '{'
  let properties = []
  let mut parser = parser
  while true {
    match current_token(parser) {
      CloseBrace(_) => {
        parser = advance_parser(parser)
        break
      }
      Identifier(prop_name, prop_loc) => {
        parser = advance_parser(parser)

        // Check for colon (renaming: { x: a })
        let (name, p2) = match current_token(parser) {
          Colon(_) => {
            let p2 = advance_parser(parser)

            // Parse the binding name (can be identifier or nested pattern)
            match current_token(p2) {
              Identifier(bind_name, bind_loc) =>
                (
                  Node::Identifier(Identifier::{
                    name: bind_name,
                    location: bind_loc,
                  }),
                  advance_parser(p2),
                )
              OpenBracket(_) =>
                match parse_array_binding_pattern(p2) {
                  Ok((pattern, p)) => (pattern, p)
                  Err(p) => return Err(p)
                }
              OpenBrace(_) =>
                match parse_object_binding_pattern(p2) {
                  Ok((pattern, p)) => (pattern, p)
                  Err(p) => return Err(p)
                }
              _ =>
                return Err(
                  add_error(
                    p2,
                    "Identifier expected",
                    prop_loc,
                  ),
                )
            }
          }
          _ =>
            // Shorthand: { x } means { x: x }
            (
              Node::Identifier(Identifier::{
                name: prop_name,
                location: prop_loc,
              }),
              parser,
            )
        }
        parser = p2
        properties.push(BindingElement::{
          property_name: prop_name,
          name,
          location: prop_loc,
        })

        // Optional comma
        match current_token(parser) {
          Comma(_) => parser = advance_parser(parser)
          _ => ()
        }
      }
      _ => break
    }
  }
  Ok(
    (
      Node::ObjectBindingPattern(ObjectBindingPattern::{
        properties,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse return type with type predicate support
/// Handles: regular types, "x is Type", "asserts x", "asserts x is Type"
fn parse_return_type(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // Check for "asserts" keyword (contextual)
  match current_token(parser) {
    Identifier(name, _) if name == "asserts" => {
      let parser = advance_parser(parser)
      // Expect parameter name
      match current_token(parser) {
        Identifier(param_name, _) => {
          let parser = advance_parser(parser)
          // Check for "is" keyword
          match current_token(parser) {
            Identifier(is_name, _) if is_name == "is" => {
              let parser = advance_parser(parser)
              // Parse the type
              match parse_type(parser) {
                Ok((type_node, p)) =>
                  Ok(
                    (
                      Node::TypePredicate(TypePredicate::{
                        parameter_name: param_name,
                        type_node: Some(type_node),
                        is_asserts: true,
                        location: start_loc,
                      }),
                      p,
                    ),
                  )
                Err(p) => Err(p)
              }
            }
            _ =>
              // Just "asserts x" without type
              Ok(
                (
                  Node::TypePredicate(TypePredicate::{
                    parameter_name: param_name,
                    type_node: None,
                    is_asserts: true,
                    location: start_loc,
                  }),
                  parser,
                ),
              )
          }
        }
        _ =>
          return Err(
            add_error_with_code(
              parser,
              "Identifier expected",
              current_token(parser).location(),
              IdentifierExpected,
            ),
          )
      }
    }
    Identifier(param_name, _) => {
      // Peek ahead to see if this is "x is Type" pattern
      let parser2 = advance_parser(parser)
      match current_token(parser2) {
        Identifier(is_name, _) if is_name == "is" => {
          let parser = advance_parser(parser2)
          // Parse the type
          match parse_type(parser) {
            Ok((type_node, p)) =>
              Ok(
                (
                  Node::TypePredicate(TypePredicate::{
                    parameter_name: param_name,
                    type_node: Some(type_node),
                    is_asserts: false,
                    location: start_loc,
                  }),
                  p,
                ),
              )
            Err(p) => Err(p)
          }
        }
        _ =>
          // Not a type predicate, parse as regular type
          parse_type(parser)
      }
    }
    _ =>
      // Regular type
      parse_type(parser)
  }
}

///|
/// Parse function declaration
fn parse_function_declaration(
  parser : Parser,
  is_async : Bool,
  is_generator : Bool,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip 'function'

  // Optional generator *
  let (is_generator, parser) = match current_token(parser) {
    Star(_) => (true, advance_parser(parser))
    _ => (is_generator, parser)
  }

  // Function name (optional for function expressions and export default)
  let (name, parser) = match current_token(parser) {
    Identifier(id_name, loc) =>
      (
        Some(Node::Identifier(Identifier::{ name: id_name, location: loc })),
        advance_parser(parser),
      )
    _ => (None, parser) // Anonymous function - no error, name is optional
  }

  // Type parameters
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Parameters
  let (parameters, parser) = match
    expect(parser, fn(t) { matches_open_paren(t) }) {
    Ok(p) => {
      let p = advance_parser(p)
      parse_parameter_list(p)
    }
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedOpenParen.to_message(),
          start_loc,
          ExpectedOpenParen,
        ),
      )
  }

  // Return type (with type predicate support)
  let (return_type, parser) = match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_return_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Body (use parse_function_body to set in_function context)
  let (body, parser) = match current_token(parser) {
    OpenBrace(_) =>
      match parse_function_body(parser) {
        Ok((block, p)) => (Some(block), p)
        Err(p) => (None, p)
      }
    Semicolon(_) =>
      // Function declaration without body (overload signature)
      (None, advance_parser(parser))
    _ => (None, parser)
  }
  Ok(
    (
      Node::FunctionDeclaration(FunctionDeclaration::{
        name,
        type_parameters,
        parameters,
        return_type,
        body,
        is_async,
        is_generator,
        modifiers: [],
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse parameter list
fn parse_parameter_list(parser : Parser) -> (Array[Node], Parser) {
  // Check for empty parameter list
  match current_token(parser) {
    CloseParen(_) => ([], advance_parser(parser))
    _ => parse_parameter_list_aux(parser, [], false, false)
  }
}

///|
/// Tail-recursive helper for parse_parameter_list with accumulator
/// Tracks whether we've seen an optional parameter and a rest parameter for validation
fn parse_parameter_list_aux(
  parser : Parser,
  acc : Array[Node],
  seen_optional : Bool,
  seen_rest : Bool,
) -> (Array[Node], Parser) {
  match parse_parameter(parser) {
    Ok((param, next_parser)) => {
      // Validate parameter order
      let next_parser = validate_parameter_order(
        next_parser,
        param,
        seen_optional,
        seen_rest,
      )

      // Check if this parameter is optional or rest
      let (is_optional, is_rest) = match param {
        Node::Parameter(p) =>
          (p.is_optional || (p.initializer is Some(_)), p.is_rest)
        _ => (false, false)
      }

      acc.push(param)
      match current_token(next_parser) {
        Comma(_) =>
          parse_parameter_list_aux(
            advance_parser(next_parser),
            acc,
            seen_optional || is_optional,
            seen_rest || is_rest,
          )
        CloseParen(_) => (acc, advance_parser(next_parser))
        _ => (acc, next_parser)
      }
    }
    Err(_) => (acc, parser)
  }
}

///|
/// Validate parameter order constraints
fn validate_parameter_order(
  parser : Parser,
  param : Node,
  seen_optional : Bool,
  seen_rest : Bool,
) -> Parser {
  match param {
    Node::Parameter(p) => {
      let mut parser = parser

      // TS1014: A rest parameter must be last in a parameter list
      // If we've already seen a rest parameter and this is another parameter
      if seen_rest {
        parser = add_error_with_code(
          parser,
          RestParameterMustBeLast.to_message(),
          p.location,
          RestParameterMustBeLast,
        )
      }

      // TS1016: A required parameter cannot follow an optional parameter
      // A parameter is required if it's not optional and has no initializer
      let is_required = not(p.is_optional) &&
        p.initializer.is_empty() &&
        not(p.is_rest)
      if seen_optional && is_required {
        parser = add_error_with_code(
          parser,
          RequiredParamAfterOptional.to_message(),
          p.location,
          RequiredParamAfterOptional,
        )
      }

      parser
    }
    _ => parser
  }
}

///|
/// Parse a parameter
fn parse_parameter(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let mut parser = parser

  // Parse parameter decorators (@decorator)
  let decorators : Array[Node] = []
  while true {
    match current_token(parser) {
      At(dec_loc) => {
        parser = advance_parser(parser) // consume @
        match parse_expression(parser) {
          Ok((expr, p)) => {
            decorators.push(
              Node::Decorator(Decorator::{ expression: expr, location: dec_loc }),
            )
            parser = p
          }
          Err(_) => break
        }
      }
      _ => break
    }
  }

  // Parse parameter property modifiers (public, private, protected, readonly)
  let modifiers : Array[Modifier] = []
  while true {
    match current_token(parser) {
      KeywordPublic(_) => {
        modifiers.push(Modifier::Public)
        parser = advance_parser(parser)
      }
      KeywordPrivate(_) => {
        modifiers.push(Modifier::Private)
        parser = advance_parser(parser)
      }
      KeywordProtected(_) => {
        modifiers.push(Modifier::Protected)
        parser = advance_parser(parser)
      }
      KeywordReadonly(_) => {
        modifiers.push(Modifier::Readonly)
        parser = advance_parser(parser)
      }
      _ => break
    }
  }

  // Check for rest parameter
  let (is_rest, parser) = match current_token(parser) {
    DotDotDot(_) => (true, advance_parser(parser))
    _ => (false, parser)
  }

  // Check for `this` parameter: function foo(this: SomeType, ...)
  let (is_this_parameter, name, parser) = match current_token(parser) {
    KeywordThis(loc) => {
      let parser = advance_parser(parser)
      (
        true,
        Node::Identifier(Identifier::{ name: "this", location: loc }),
        parser,
      )
    }
    _ =>
      // Check for destructuring patterns: { page } or [ a, b ]
      match current_token(parser) {
        OpenBrace(_) =>
          match parse_object_binding_pattern(parser) {
            Ok((pattern, p)) => (false, pattern, p)
            Err(p) => return Err(p)
          }
        OpenBracket(_) =>
          match parse_array_binding_pattern(parser) {
            Ok((pattern, p)) => (false, pattern, p)
            Err(p) => return Err(p)
          }
        _ =>
          match parse_identifier(parser) {
            Ok((id, p)) => (false, Node::Identifier(id), p)
            Err(p) => return Err(p)
          }
      }
  }

  // Optional parameter
  let (is_optional, parser) = match current_token(parser) {
    Question(_) => (true, advance_parser(parser))
    _ => (false, parser)
  }

  // Type annotation
  let (type_annotation, parser) = match current_token(parser) {
    Colon(_) => {
      let parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => (Some(ty), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Default value (not allowed for `this` parameter, but parse anyway for error recovery)
  let (initializer, parser) = match current_token(parser) {
    Equals(_) => {
      let parser = advance_parser(parser)
      match parse_assignment_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }

  // Validate rest parameter constraints
  let parser = if is_rest {
    // TS1048: A rest parameter cannot be optional
    let parser = if is_optional {
      add_error_with_code(
        parser,
        RestParameterCannotBeOptional.to_message(),
        start_loc,
        RestParameterCannotBeOptional,
      )
    } else {
      parser
    }
    // TS1049: A rest parameter cannot have an initializer
    match initializer {
      Some(_) =>
        add_error_with_code(
          parser,
          RestParameterCannotHaveInitializer.to_message(),
          start_loc,
          RestParameterCannotHaveInitializer,
        )
      None => parser
    }
  } else {
    parser
  }

  Ok(
    (
      Node::Parameter(Parameter::{
        name,
        type_annotation,
        initializer,
        is_optional,
        is_rest,
        is_this_parameter,
        decorators,
        modifiers,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse block statement
fn parse_block_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  match expect(parser, fn(t) { matches_open_brace(t) }) {
    Ok(parser) => {
      let parser = advance_parser(parser)
      let statements : Array[Node] = []
      let mut parser = parser
      while !matches_close_brace(current_token(parser)) && !is_at_end(parser) {
        match parse_statement(parser) {
          Ok((stmt, next_parser)) => {
            statements.push(stmt)
            parser = next_parser
          }
          Err(next_parser) => parser = skip_to_next_statement(next_parser)
        }
      }
      match expect(parser, fn(t) { matches_close_brace(t) }) {
        Ok(parser) => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::BlockStatement(BlockStatement::{
                statements,
                location: start_loc,
              }),
              parser,
            ),
          )
        }
        Err(parser) =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              start_loc,
              ExpectedCloseBrace,
            ),
          )
      }
    }
    Err(parser) =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          start_loc,
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
/// Parse function body (block statement with in_function context)
/// Sets in_function: true to allow return statements
fn parse_function_body(parser : Parser) -> Result[(Node, Parser), Parser] {
  // Set in_function context
  let old_context = parser.context
  let new_context = { ..old_context, in_function: true }
  let parser = { ..parser, context: new_context }

  // Parse the block
  match parse_block_statement(parser) {
    Ok((block, parser)) => {
      // Restore old context
      let parser = { ..parser, context: old_context }
      Ok((block, parser))
    }
    Err(parser) => {
      // Restore old context even on error
      let parser = { ..parser, context: old_context }
      Err(parser)
    }
  }
}

///|
/// Parse if statement
fn parse_if_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // Skip 'if'

  // Expect '('
  let parser = match expect(parser, fn(t) { matches_open_paren(t) }) {
    Ok(p) => advance_parser(p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedOpenParen.to_message(),
          start_loc,
          ExpectedOpenParen,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match expect(parser, fn(t) { matches_close_paren(t) }) {
    Ok(p) => advance_parser(p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedCloseParen.to_message(),
          start_loc,
          ExpectedCloseParen,
        ),
      )
  }

  // Parse then statement
  let (then_statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }

  // Optional else clause
  let (else_statement, parser) = match current_token(parser) {
    KeywordElse(_) => {
      let parser = advance_parser(parser)
      match parse_statement(parser) {
        Ok((stmt, p)) => (Some(stmt), p)
        Err(p) => (None, p)
      }
    }
    _ => (None, parser)
  }
  Ok(
    (
      Node::IfStatement(IfStatement::{
        condition,
        then_statement,
        else_statement,
        location: start_loc,
      }),
      parser,
    ),
  )
}

///|
/// Parse return statement
fn parse_return_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()

  // TS1108: A 'return' statement can only be used within a function body
  let parser = if not(parser.context.in_function) {
    add_error_with_code(
      parser,
      ReturnOutsideFunction.to_message(),
      start_loc,
      ReturnOutsideFunction,
    )
  } else {
    parser
  }

  let parser = advance_parser(parser) // Skip 'return'

  // Check if there's an expression
  let (expression, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }
  let parser = expect_semicolon(parser)
  Ok(
    (
      Node::ReturnStatement(ReturnStatement::{ expression, location: start_loc }),
      parser,
    ),
  )
}

///|
/// Parse expression statement
fn parse_expression_statement(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  let start_loc = current_token(parser).location()
  match parse_expression(parser) {
    Ok((expr, parser)) => {
      let parser = expect_semicolon(parser)
      Ok(
        (
          Node::ExpressionStatement(ExpressionStatement::{
            expression: expr,
            location: start_loc,
          }),
          parser,
        ),
      )
    }
    Err(parser) => Err(parser)
  }
}

///|
/// Parse type (enhanced with union support)

///|
/// Parse identifier
fn parse_identifier(parser : Parser) -> Result[(Identifier, Parser), Parser] {
  match current_token(parser) {
    Identifier(name, loc) =>
      Ok((Identifier::{ name, location: loc }, advance_parser(parser)))
    _ => {
      let loc = current_token(parser).location()
      Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          loc,
          IdentifierExpected,
        ),
      )
    }
  }
}

///|
/// Parse an entity name (qualified name like M, M.N, M.N.O)
/// Used for import equals declarations: import X = M.N
fn parse_entity_name(parser : Parser) -> (Node, Parser) {
  // Start with an identifier
  match current_token(parser) {
    Identifier(name, loc) => {
      let mut parser = advance_parser(parser)
      let mut result : Node = Node::Identifier(Identifier::{ name, location: loc })
      // Parse any following .identifier chains
      while true {
        match current_token(parser) {
          Dot(_) => {
            parser = advance_parser(parser) // consume '.'
            match current_token(parser) {
              Identifier(prop_name, prop_loc) => {
                parser = advance_parser(parser)
                let start_loc = get_node_location(result)
                result = Node::PropertyAccessExpression(PropertyAccessExpression::{
                  expression: result,
                  name: prop_name,
                  location: SourceLocation::new(
                    start_loc.file_path,
                    start_loc.start,
                    prop_loc.end,
                  ),
                })
              }
              _ => break
            }
          }
          _ => break
        }
      }
      (result, parser)
    }
    _ => {
      // Return empty identifier as fallback
      let loc = current_token(parser).location()
      (
        Node::Identifier(Identifier::{ name: "", location: loc }),
        parser,
      )
    }
  }
}

// ============================================================================
// Stub implementations for declarations (to be implemented)
// ============================================================================

///|
/// Parse a list of decorators (@decorator)
fn parse_decorators(parser : Parser) -> (Array[Node], Parser) {
  let decorators : Array[Node] = []
  let mut parser = parser
  while true {
    match current_token(parser) {
      At(start_loc) => {
        parser = advance_parser(parser) // consume '@'
        // Parse the decorator expression (can be identifier, property access, or call)
        match parse_expression(parser) {
          Ok((expr, p)) => {
            decorators.push(
              Node::Decorator(Decorator::{
                expression: expr,
                location: start_loc,
              }),
            )
            parser = p
          }
          Err(_) => break
        }
      }
      _ => break
    }
  }
  (decorators, parser)
}

///|
fn parse_class_declaration_with_decorators(
  parser : Parser,
  is_abstract : Bool,
  decorators : Array[Node],
) -> Result[(Node, Parser), Parser] {
  // [abstract] class Name [extends Super] [implements I1, I2] { members }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'class'

  // Parse class name
  let (name, parser) = match current_token(parser) {
    Identifier(n, loc) =>
      (
        Some(Node::Identifier(Identifier::{ name: n, location: loc })),
        advance_parser(parser),
      )
    _ => (None, parser) // Anonymous class allowed in expressions
  }

  // Parse type parameters if present (e.g., class Box<T>)
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Parse heritage clauses (extends, implements)
  let (heritage_clauses, parser) = parse_heritage_clauses(parser)

  // Parse class body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (members, parser) = parse_class_members(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          Ok(
            (
              Node::ClassDeclaration(ClassDeclaration::{
                name,
                type_parameters,
                heritage_clauses,
                members,
                is_abstract,
                decorators,
                modifiers: [],
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
/// Parse heritage clauses (extends, implements)
fn parse_heritage_clauses(parser : Parser) -> (Array[HeritageClause], Parser) {
  parse_heritage_clauses_aux(parser, [])
}

///|
fn parse_heritage_clauses_aux(
  parser : Parser,
  acc : Array[HeritageClause],
) -> (Array[HeritageClause], Parser) {
  match current_token(parser) {
    KeywordExtends(_) => {
      let start_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      let (types, parser) = parse_heritage_types(parser)
      acc.push(HeritageClause::{
        kind: HeritageKind::Extends,
        types,
        location: start_loc,
      })
      parse_heritage_clauses_aux(parser, acc)
    }
    KeywordImplements(_) => {
      let start_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      let (types, parser) = parse_heritage_types(parser)
      acc.push(HeritageClause::{
        kind: HeritageKind::Implements,
        types,
        location: start_loc,
      })
      parse_heritage_clauses_aux(parser, acc)
    }
    _ => (acc, parser)
  }
}

///|
/// Parse comma-separated list of types (for extends/implements)
fn parse_heritage_types(parser : Parser) -> (Array[Node], Parser) {
  parse_heritage_types_aux(parser, [])
}

///|
fn parse_heritage_types_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Parse property access chain (e.g., cdk.Stack, aws.lambda.Function)
      let (full_name, parser, end_loc) = parse_heritage_type_name(
        parser,
        name,
        loc,
      )
      // Parse generic type arguments if present (e.g., Stack<Props>)
      let (type_arguments, parser) = match current_token(parser) {
        LessThan(_) => parse_heritage_type_arguments(parser)
        _ => ([], parser)
      }
      acc.push(
        Node::TypeReference(TypeReference::{
          type_name: full_name,
          type_arguments,
          location: end_loc,
        }),
      )
      match current_token(parser) {
        Comma(_) => parse_heritage_types_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
    _ => (acc, parser)
  }
}

///|
/// Parse a heritage type name with property access (e.g., cdk.Stack -> "cdk.Stack")
fn parse_heritage_type_name(
  parser : Parser,
  base_name : String,
  start_loc : SourceLocation,
) -> (String, Parser, SourceLocation) {
  match current_token(parser) {
    Dot(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(prop_name, prop_loc) => {
          let parser = advance_parser(parser)
          let combined_name = base_name + "." + prop_name
          parse_heritage_type_name(parser, combined_name, prop_loc)
        }
        _ => (base_name, parser, start_loc)
      }
    }
    _ => (base_name, parser, start_loc)
  }
}

///|
/// Parse type arguments in heritage clause (e.g., <Props, Options>)
fn parse_heritage_type_arguments(parser : Parser) -> (Array[Node], Parser) {
  // Expect <
  let parser = match current_token(parser) {
    LessThan(_) => advance_parser(parser)
    _ => return ([], parser)
  }
  let type_args : Array[Node] = []
  let mut parser = parser
  // Parse comma-separated types until >
  while true {
    match current_token(parser) {
      GreaterThan(_) => {
        parser = advance_parser(parser)
        break
      }
      _ =>
        match parse_type(parser) {
          Ok((ty, p)) => {
            type_args.push(ty)
            parser = p
            match current_token(parser) {
              Comma(_) => parser = advance_parser(parser)
              GreaterThan(_) => {
                parser = advance_parser(parser)
                break
              }
              _ => break // Error recovery
            }
          }
          Err(p) => {
            parser = p
            break
          }
        }
    }
  }
  (type_args, parser)
}

///|
/// Parse class members
fn parse_class_members(parser : Parser) -> (Array[Node], Parser) {
  parse_class_members_aux(parser, [])
}

///|
fn parse_class_members_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  // First check for member decorators
  match current_token(parser) {
    At(_) => {
      let (decorators, parser) = parse_decorators(parser)
      parse_class_member_with_decorators(parser, acc, decorators)
    }
    _ => parse_class_member_with_decorators(parser, acc, [])
  }
}

///|
/// Parse a single class member with optional decorators
fn parse_class_member_with_decorators(
  parser : Parser,
  acc : Array[Node],
  decorators : Array[Node],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)

    // Static modifier or static block
    KeywordStatic(start_loc) => {
      let parser = advance_parser(parser)
      // Check for static block: static { ... }
      match current_token(parser) {
        // Static initialization block
        OpenBrace(_) => {
          match parse_block_statement(parser) {
            Ok((body, parser)) => {
              acc.push(
                Node::StaticBlock(StaticBlock::{
                  body,
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            Err(p) => parse_class_members_aux(p, acc)
          }
        }
        // Static member with identifier
        Identifier(name, loc) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            // Static method
            OpenParen(_) => {
              let parser = advance_parser(parser)
              let (parameters, parser) = parse_parameter_list(parser)
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::MethodDeclaration(MethodDeclaration::{
                  name,
                  type_parameters: [],
                  parameters,
                  return_type,
                  body,
                  decorators,
                  modifiers: [Modifier::Static],
                  is_async: false,
                  is_generator: false,
                  is_optional: false,
                  location: loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Static property
            _ => {
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::PropertyDeclaration(PropertyDeclaration::{
                  name,
                  type_annotation,
                  initializer,
                  is_optional: false,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
          }
        }
        // Static accessor: static accessor name = value;
        KeywordAccessor(accessor_loc) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(name, _) => {
              let parser = advance_parser(parser)
              // Optional type annotation
              let (type_annotation, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              // Optional initializer
              let (initializer, parser) = match current_token(parser) {
                Equals(_) => {
                  let parser = advance_parser(parser)
                  match parse_assignment_expression(parser) {
                    Ok((expr, p)) => (Some(expr), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              acc.push(
                Node::AutoAccessor(AutoAccessor::{
                  name,
                  type_annotation,
                  initializer,
                  decorators,
                  modifiers: [Modifier::Static],
                  location: accessor_loc,
                }),
              )
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              parse_class_members_aux(parser, acc)
            }
            _ => parse_class_members_aux(parser, acc)
          }
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Constructor
    Identifier("constructor", loc) => {
      let parser = advance_parser(parser)
      // TS1092: Type parameters cannot appear on a constructor declaration
      let parser = match current_token(parser) {
        LessThan(_) => {
          let parser = add_error_with_code(
            parser,
            TypeParamsOnConstructor.to_message(),
            loc,
            TypeParamsOnConstructor,
          )
          // Parse and discard the type parameters for error recovery
          match parse_type_parameters(parser) {
            (_, p) => p
          }
        }
        _ => parser
      }
      match current_token(parser) {
        OpenParen(_) => {
          // Consume the OpenParen, then parse parameters
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          // Parse body (use parse_function_body for return statement validation)
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::ConstructorDeclaration(ConstructorDeclaration::{
              parameters,
              body,
              decorators,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Getter: get name() { ... }
    Identifier("get", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              // Parse any parameters (should be none for getter)
              let (params, parser) = parse_parameter_list(parser)
              // TS1094: A 'get' accessor cannot have parameters
              let parser = if params.length() > 0 {
                add_error_with_code(
                  parser,
                  GetAccessorCannotHaveParams.to_message(),
                  start_loc,
                  GetAccessorCannotHaveParams,
                )
              } else {
                parser
              }
              // Optional return type
              let (return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((ty, p)) => (Some(ty), p)
                    Err(p) => (None, p)
                  }
                }
                _ => (None, parser)
              }
              // Body
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::GetAccessor(GetAccessor::{
                  name,
                  return_type,
                  body,
                  decorators,
                  modifiers: [],
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            // Not a getter, treat "get" as property/method name
            _ => {
              // Backtrack - treat "get" as the name
              let name = "get"
              let loc = start_loc
              match current_token(parser) {
                OpenParen(_) => {
                  let parser = advance_parser(parser)
                  let (parameters, parser) = parse_parameter_list(parser)
                  let (return_type, parser) = match current_token(parser) {
                    Colon(_) => {
                      let parser = advance_parser(parser)
                      match parse_type(parser) {
                        Ok((ty, p)) => (Some(ty), p)
                        Err(p) => (None, p)
                      }
                    }
                    _ => (None, parser)
                  }
                  let (body, parser) = match current_token(parser) {
                    OpenBrace(_) =>
                      match parse_function_body(parser) {
                        Ok((b, p)) => (Some(b), p)
                        Err(p) => (None, p)
                      }
                    _ => (None, parser)
                  }
                  acc.push(
                    Node::MethodDeclaration(MethodDeclaration::{
                      name,
                      type_parameters: [],
                      parameters,
                      return_type,
                      body,
                      decorators,
                      modifiers: [],
                      is_async: false,
                      is_generator: false,
                      is_optional: false,
                      location: loc,
                    }),
                  )
                  parse_class_members_aux(parser, acc)
                }
                _ => parse_class_members_aux(parser, acc)
              }
            }
          }
        }
        // "get" followed by non-identifier - treat as property/method named "get"
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Setter: set name(value) { ... }
    Identifier("set", start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            OpenParen(_) => {
              let parser = advance_parser(parser)
              // Parse parameters (should be exactly one for setter)
              let (params, parser) = parse_parameter_list(parser)
              // TS1095: A 'set' accessor must have exactly one parameter
              let parser = if params.length() != 1 {
                add_error_with_code(
                  parser,
                  SetAccessorMustHaveOneParam.to_message(),
                  start_loc,
                  SetAccessorMustHaveOneParam,
                )
              } else {
                parser
              }
              // Get the parameter (or create a dummy one)
              let parameter = if params.length() > 0 {
                params[0]
              } else {
                Node::Identifier(Identifier::{
                  name: "value",
                  location: start_loc,
                })
              }
              // Optional return type (usually void) - but should not be specified
              let (has_return_type, parser) = match current_token(parser) {
                Colon(_) => {
                  let parser = advance_parser(parser)
                  match parse_type(parser) {
                    Ok((_, p)) => (true, p)
                    Err(p) => (true, p)
                  }
                }
                _ => (false, parser)
              }
              // TS1093: A 'set' accessor cannot have a return type annotation
              let parser = if has_return_type {
                add_error_with_code(
                  parser,
                  SetAccessorCannotHaveReturnType.to_message(),
                  start_loc,
                  SetAccessorCannotHaveReturnType,
                )
              } else {
                parser
              }
              // Body
              let (body, parser) = match current_token(parser) {
                OpenBrace(_) =>
                  match parse_function_body(parser) {
                    Ok((b, p)) => (Some(b), p)
                    Err(p) => (None, p)
                  }
                _ => (None, parser)
              }
              acc.push(
                Node::SetAccessor(SetAccessor::{
                  name,
                  parameter,
                  body,
                  decorators,
                  modifiers: [],
                  location: start_loc,
                }),
              )
              parse_class_members_aux(parser, acc)
            }
            _ => parse_class_members_aux(parser, acc)
          }
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Auto-accessor: accessor name = value;
    KeywordAccessor(start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          // Optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          // Optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          acc.push(
            Node::AutoAccessor(AutoAccessor::{
              name,
              type_annotation,
              initializer,
              decorators,
              modifiers: [],
              location: start_loc,
            }),
          )
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }

    // Private modifier
    KeywordPrivate(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Private])
    }

    // Protected modifier
    KeywordProtected(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Protected])
    }

    // Public modifier
    KeywordPublic(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Public])
    }

    // Static modifier
    KeywordStatic(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Static])
    }

    // Readonly modifier
    KeywordReadonly(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Readonly])
    }

    // Abstract modifier
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Abstract])
    }

    // Async modifier
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      parse_class_member_with_modifiers(parser, acc, decorators, [Modifier::Async])
    }

    // TS1248: A class member cannot have the 'const' keyword
    KeywordConst(loc) => {
      let parser = add_error_with_code(
        parser,
        ClassMemberCannotHaveConst.to_message(),
        loc,
        ClassMemberCannotHaveConst,
      )
      let parser = advance_parser(parser)
      // Skip to next member
      parse_class_members_aux(parser, acc)
    }

    // Property or method
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)

          // Parse optional return type
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }

        // Property with initializer or type annotation
        _ => {
          // Parse optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Parse optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Private class field with # syntax (ES2022)
    PrivateIdentifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Private method
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)

          // Parse optional return type
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers: [],
              is_async: false,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }

        // Private property with initializer or type annotation
        _ => {
          // Parse optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Parse optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }

          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers: [],
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }

    // Skip other tokens
    _ => parse_class_members_aux(advance_parser(parser), acc)
  }
}

///|
/// Parse class member with modifiers (private/protected/public/static/readonly/abstract/async)
fn parse_class_member_with_modifiers(
  parser : Parser,
  acc : Array[Node],
  decorators : Array[Node],
  modifiers : Array[Modifier],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    // Handle chained modifiers
    KeywordPublic(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Public)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordPrivate(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Private)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordProtected(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Protected)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordStatic(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Static)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordReadonly(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Readonly)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Abstract)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    KeywordAsync(_) => {
      let parser = advance_parser(parser)
      modifiers.push(Modifier::Async)
      parse_class_member_with_modifiers(parser, acc, decorators, modifiers)
    }
    // Auto-accessor with modifiers: static accessor name = value;
    KeywordAccessor(start_loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        Identifier(name, _) => {
          let parser = advance_parser(parser)
          // Optional type annotation
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          // Optional initializer
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          acc.push(
            Node::AutoAccessor(AutoAccessor::{
              name,
              type_annotation,
              initializer,
              decorators,
              modifiers,
              location: start_loc,
            }),
          )
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          parse_class_members_aux(parser, acc)
        }
        _ => parse_class_members_aux(parser, acc)
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        // Method
        OpenParen(_) => {
          let parser = advance_parser(parser)
          let (parameters, parser) = parse_parameter_list(parser)
          let (return_type, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (body, parser) = match current_token(parser) {
            OpenBrace(_) =>
              match parse_function_body(parser) {
                Ok((b, p)) => (Some(b), p)
                Err(p) => (None, p)
              }
            _ => (None, parser)
          }
          // Check if Async modifier is present
          let mut is_async = false
          for modifier in modifiers {
            if modifier == Modifier::Async {
              is_async = true
              break
            }
          }
          acc.push(
            Node::MethodDeclaration(MethodDeclaration::{
              name,
              type_parameters: [],
              parameters,
              return_type,
              body,
              decorators,
              modifiers,
              is_async,
              is_generator: false,
              is_optional: false,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
        // Property
        _ => {
          let (type_annotation, parser) = match current_token(parser) {
            Colon(_) => {
              let parser = advance_parser(parser)
              match parse_type(parser) {
                Ok((ty, p)) => (Some(ty), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let (initializer, parser) = match current_token(parser) {
            Equals(_) => {
              let parser = advance_parser(parser)
              match parse_assignment_expression(parser) {
                Ok((expr, p)) => (Some(expr), p)
                Err(p) => (None, p)
              }
            }
            _ => (None, parser)
          }
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          acc.push(
            Node::PropertyDeclaration(PropertyDeclaration::{
              name,
              type_annotation,
              initializer,
              is_optional: false,
              decorators,
              modifiers,
              location: loc,
            }),
          )
          parse_class_members_aux(parser, acc)
        }
      }
    }
    _ => parse_class_members_aux(parser, acc)
  }
}

///|
/// Helper: Skip tokens until predicate is true
fn skip_until_token(parser : Parser, predicate : (Token) -> Bool) -> Parser {
  if is_at_end(parser) || predicate(current_token(parser)) {
    parser
  } else {
    skip_until_token(advance_parser(parser), predicate)
  }
}

///|
fn parse_interface_declaration(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  // interface Name [extends I1, I2] { members }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'interface'

  // Parse interface name
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Parse type parameters if present
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Parse heritage clauses (extends only for interfaces)
  let (heritage_clauses, parser) = parse_heritage_clauses(parser)

  // Parse interface body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let members = []
      let mut parser = parser

      // Parse property signatures
      while true {
        match current_token(parser) {
          CloseBrace(loc) => {
            parser = advance_parser(parser)
            return Ok(
              (
                Node::InterfaceDeclaration(InterfaceDeclaration::{
                  name,
                  type_parameters,
                  heritage_clauses,
                  members,
                  modifiers: [],
                  location: SourceLocation::new(
                    start_loc.file_path,
                    start_loc.start,
                    loc.end,
                  ),
                }),
                parser,
              ),
            )
          }
          // Index signature: [key: string]: value
          OpenBracket(_) => {
            let bracket_loc = current_token(parser).location()
            parser = advance_parser(parser)
            // Parse index parameter name
            let index_name = match current_token(parser) {
              Identifier(n, _) => {
                parser = advance_parser(parser)
                n
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    "Identifier expected",
                    current_token(parser).location(),
                    IdentifierExpected,
                  ),
                )
            }
            // Expect colon
            match current_token(parser) {
              Colon(_) => parser = advance_parser(parser)
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedColon.to_message(),
                    current_token(parser).location(),
                    ExpectedColon,
                  ),
                )
            }
            // Parse index type (string or number)
            let index_type = match parse_type(parser) {
              Ok((t, p)) => {
                parser = p
                t
              }
              Err(p) => return Err(p)
            }
            // Expect closing bracket
            match current_token(parser) {
              CloseBracket(_) => parser = advance_parser(parser)
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedCloseBracket.to_message(),
                    current_token(parser).location(),
                    ExpectedCloseBracket,
                  ),
                )
            }
            // Expect colon for value type
            match current_token(parser) {
              Colon(_) => parser = advance_parser(parser)
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedColon.to_message(),
                    current_token(parser).location(),
                    ExpectedColon,
                  ),
                )
            }
            // Parse value type
            let value_type = match parse_type(parser) {
              Ok((t, p)) => {
                parser = p
                t
              }
              Err(p) => return Err(p)
            }
            // Create index signature
            members.push(
              Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
                parameter_name: index_name,
                parameter_type: index_type,
                return_type: value_type,
                is_readonly: false,
                location: bracket_loc,
              }),
            )
            // Optional semicolon or comma
            match current_token(parser) {
              Semicolon(_) | Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          // Readonly modifier
          KeywordReadonly(_) => {
            let readonly_loc = current_token(parser).location()
            parser = advance_parser(parser)
            // Check for readonly index signature: readonly [key: type]: type
            match current_token(parser) {
              OpenBracket(_) => {
                parser = advance_parser(parser)
                // Parse index parameter name
                let index_name = match current_token(parser) {
                  Identifier(n, _) => {
                    parser = advance_parser(parser)
                    n
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        "Identifier expected",
                        current_token(parser).location(),
                        IdentifierExpected,
                      ),
                    )
                }
                // Expect colon
                match current_token(parser) {
                  Colon(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedColon.to_message(),
                        current_token(parser).location(),
                        ExpectedColon,
                      ),
                    )
                }
                // Parse index type (string or number)
                let index_type = match parse_type(parser) {
                  Ok((t, p)) => {
                    parser = p
                    t
                  }
                  Err(p) => return Err(p)
                }
                // Expect closing bracket
                match current_token(parser) {
                  CloseBracket(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedCloseBracket.to_message(),
                        current_token(parser).location(),
                        ExpectedCloseBracket,
                      ),
                    )
                }
                // Expect colon for value type
                match current_token(parser) {
                  Colon(_) => parser = advance_parser(parser)
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedColon.to_message(),
                        current_token(parser).location(),
                        ExpectedColon,
                      ),
                    )
                }
                // Parse value type
                let value_type = match parse_type(parser) {
                  Ok((t, p)) => {
                    parser = p
                    t
                  }
                  Err(p) => return Err(p)
                }
                // Create readonly index signature
                members.push(
                  Node::IndexSignatureDeclaration(IndexSignatureDeclaration::{
                    parameter_name: index_name,
                    parameter_type: index_type,
                    return_type: value_type,
                    is_readonly: true,
                    location: readonly_loc,
                  }),
                )
                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              Identifier(n, loc) => {
                // Readonly property
                parser = advance_parser(parser)
                let prop_name = n
                let prop_loc = loc
                // Check for optional marker (?)
                let is_optional = match current_token(parser) {
                  Question(_) => {
                    parser = advance_parser(parser)
                    true
                  }
                  _ => false
                }
                // Must be followed by colon (readonly properties, not methods)
                match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((prop_type, p)) => {
                        parser = p
                        members.push(
                          Node::PropertyDeclaration(PropertyDeclaration::{
                            name: prop_name,
                            type_annotation: Some(prop_type),
                            initializer: None,
                            is_optional,
                            decorators: [],
                            modifiers: [Modifier::Readonly],
                            location: prop_loc,
                          }),
                        )
                        match current_token(parser) {
                          Semicolon(_) | Comma(_) =>
                            parser = advance_parser(parser)
                          _ => ()
                        }
                      }
                      Err(p) => return Err(p)
                    }
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser,
                        ExpectedColon.to_message(),
                        current_token(parser).location(),
                        ExpectedColon,
                      ),
                    )
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    "Identifier expected",
                    current_token(parser).location(),
                    IdentifierExpected,
                  ),
                )
            }
          }
          // Call signature: (): returnType
          OpenParen(_) => {
            let call_loc = current_token(parser).location()
            parser = advance_parser(parser) // consume '('

            // Parse parameters
            let (params, p) = parse_parameter_list(parser)
            parser = p

            // Parse return type
            let return_type = match current_token(parser) {
              Colon(_) => {
                parser = advance_parser(parser)
                match parse_type(parser) {
                  Ok((t, p)) => {
                    parser = p
                    Some(t)
                  }
                  Err(_) => None
                }
              }
              _ => None
            }

            // Create call signature as a method with empty name (call signature)
            members.push(
              Node::MethodDeclaration(MethodDeclaration::{
                name: "",
                type_parameters: [],
                parameters: params,
                return_type,
                body: None,
                decorators: [],
                modifiers: [],
                is_async: false,
                is_generator: false,
                is_optional: false,
                location: call_loc,
              }),
            )

            // Optional semicolon or comma
            match current_token(parser) {
              Semicolon(_) | Comma(_) => parser = advance_parser(parser)
              _ => ()
            }
          }
          // Construct signature: new(): returnType
          KeywordNew(_) => {
            let new_loc = current_token(parser).location()
            parser = advance_parser(parser) // consume 'new'
            match current_token(parser) {
              OpenParen(_) => {
                parser = advance_parser(parser)
                let (params, p) = parse_parameter_list(parser)
                parser = p

                // Parse return type
                let return_type = match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        parser = p
                        Some(t)
                      }
                      Err(_) => None
                    }
                  }
                  _ => None
                }

                // Create construct signature as a method with "new" name
                members.push(
                  Node::MethodDeclaration(MethodDeclaration::{
                    name: "new",
                    type_parameters: [],
                    parameters: params,
                    return_type,
                    body: None,
                    decorators: [],
                    modifiers: [],
                    is_async: false,
                    is_generator: false,
                    is_optional: false,
                    location: new_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser,
                    ExpectedOpenParen.to_message(),
                    current_token(parser).location(),
                    ExpectedOpenParen,
                  ),
                )
            }
          }
          Identifier(prop_name, prop_loc) => {
            parser = advance_parser(parser)

            // Check for optional marker (?)
            let is_optional = match current_token(parser) {
              Question(_) => {
                parser = advance_parser(parser)
                true
              }
              _ => false
            }

            // Check if it's a method (has parentheses) or property (has colon)
            match current_token(parser) {
              OpenParen(_) => {
                // Method signature: name(params): returnType
                parser = advance_parser(parser) // consume '('

                // Parse parameters properly
                let (params, p) = parse_parameter_list(parser)
                parser = p

                // Parse return type
                let return_type = match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        parser = p
                        Some(t)
                      }
                      Err(_) => None
                    }
                  }
                  _ => None
                }

                // Create method declaration
                members.push(
                  Node::MethodDeclaration(MethodDeclaration::{
                    name: prop_name,
                    type_parameters: [],
                    parameters: params,
                    return_type,
                    body: None,
                    decorators: [],
                    modifiers: [],
                    is_async: false,
                    is_generator: false,
                    is_optional,
                    location: prop_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              Colon(_) => {
                // Property signature: name: type
                parser = advance_parser(parser)

                // Parse property type
                match parse_type(parser) {
                  Ok((prop_type, p)) => {
                    parser = p

                    // Create property declaration
                    members.push(
                      Node::PropertyDeclaration(PropertyDeclaration::{
                        name: prop_name,
                        type_annotation: Some(prop_type),
                        initializer: None,
                        is_optional,
                        decorators: [],
                        modifiers: [],
                        location: prop_loc,
                      }),
                    )

                    // Optional semicolon or comma
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  Err(p) => return Err(p)
                }
              }
              LessThan(_) => {
                // Generic method signature: name<T>(params): returnType
                let (type_params, p) = parse_type_parameters(parser)
                parser = p

                // Must have '(' after type parameters
                match current_token(parser) {
                  OpenParen(_) => {
                    parser = advance_parser(parser)
                    let (params, p) = parse_parameter_list(parser)
                    parser = p

                    // Parse return type
                    let return_type = match current_token(parser) {
                      Colon(_) => {
                        parser = advance_parser(parser)
                        match parse_type(parser) {
                          Ok((t, p)) => {
                            parser = p
                            Some(t)
                          }
                          Err(_) => None
                        }
                      }
                      _ => None
                    }

                    // Create generic method declaration
                    members.push(
                      Node::MethodDeclaration(MethodDeclaration::{
                        name: prop_name,
                        type_parameters: type_params,
                        parameters: params,
                        return_type,
                        body: None,
                        decorators: [],
                        modifiers: [],
                        is_async: false,
                        is_generator: false,
                        is_optional,
                        location: prop_loc,
                      }),
                    )

                    // Optional semicolon or comma
                    match current_token(parser) {
                      Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                      _ => ()
                    }
                  }
                  _ =>
                    return Err(
                      add_error_with_code(
                        parser, ExpectedOpenParen.to_message(), current_token(parser).location(),
                        ExpectedOpenParen,
                      ),
                    )
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser, ExpectedColon.to_message(), prop_loc,
                    ExpectedColon,
                  ),
                )
            }
          }
          // Generic call signature: <T>(x: T): void
          LessThan(_) => {
            let call_loc = current_token(parser).location()
            let (type_params, p) = parse_type_parameters(parser)
            parser = p

            // Must have '(' after type parameters
            match current_token(parser) {
              OpenParen(_) => {
                parser = advance_parser(parser)
                let (params, p) = parse_parameter_list(parser)
                parser = p

                // Parse return type
                let return_type = match current_token(parser) {
                  Colon(_) => {
                    parser = advance_parser(parser)
                    match parse_type(parser) {
                      Ok((t, p)) => {
                        parser = p
                        Some(t)
                      }
                      Err(_) => None
                    }
                  }
                  _ => None
                }

                // Create generic call signature as a method with empty name
                members.push(
                  Node::MethodDeclaration(MethodDeclaration::{
                    name: "",
                    type_parameters: type_params,
                    parameters: params,
                    return_type,
                    body: None,
                    decorators: [],
                    modifiers: [],
                    is_async: false,
                    is_generator: false,
                    is_optional: false,
                    location: call_loc,
                  }),
                )

                // Optional semicolon or comma
                match current_token(parser) {
                  Semicolon(_) | Comma(_) => parser = advance_parser(parser)
                  _ => ()
                }
              }
              _ =>
                return Err(
                  add_error_with_code(
                    parser, ExpectedOpenParen.to_message(), current_token(parser).location(),
                    ExpectedOpenParen,
                  ),
                )
            }
          }
          _ => break
        }
      }
      Err(
        add_error_with_code(
          parser,
          ExpectedCloseBrace.to_message(),
          current_token(parser).location(),
          ExpectedCloseBrace,
        ),
      )
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
fn parse_type_alias_declaration(
  parser : Parser,
) -> Result[(Node, Parser), Parser] {
  // type Name = Type
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'type'

  // Parse type name
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Optional type parameters
  let (type_parameters, parser) = match current_token(parser) {
    LessThan(_) => parse_type_parameters(parser)
    _ => ([], parser)
  }

  // Expect '='
  let parser = match current_token(parser) {
    Equals(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedEquals.to_message(),
          current_token(parser).location(),
          ExpectedEquals,
        ),
      )
  }

  // Parse type
  let (type_node, parser) = match parse_type(parser) {
    Ok((t, p)) => (t, p)
    Err(p) => return Err(p)
  }
  let end_loc = get_location(type_node)

  // Consume optional semicolon
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::TypeAliasDeclaration(TypeAliasDeclaration::{
        name,
        type_parameters,
        type_node,
        modifiers: [],
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_enum_declaration(
  parser : Parser,
  is_const : Bool,
) -> Result[(Node, Parser), Parser] {
  // enum Name { A, B = 1, C } or const enum Name { A, B }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'enum'

  // Parse enum name
  let (name, parser) = match current_token(parser) {
    Identifier(n, _) => (n, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Parse enum body
  match current_token(parser) {
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (members, parser) = parse_enum_members(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          let modifiers : Array[Modifier] = if is_const {
            [Modifier::Const]
          } else {
            []
          }
          Ok(
            (
              Node::EnumDeclaration(EnumDeclaration::{
                name,
                members,
                is_const,
                modifiers,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }
    _ =>
      Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }
}

///|
/// Parse enum members
fn parse_enum_members(parser : Parser) -> (Array[EnumMember], Parser) {
  parse_enum_members_aux(parser, [])
}

///|
fn parse_enum_members_aux(
  parser : Parser,
  acc : Array[EnumMember],
) -> (Array[EnumMember], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for initializer (use parse_assignment_expression to not consume commas)
      let (initializer, parser) = match current_token(parser) {
        Equals(_) => {
          let parser = advance_parser(parser)
          match parse_assignment_expression(parser) {
            Ok((expr, p)) => (Some(expr), p)
            Err(p) => (None, p)
          }
        }
        _ => (None, parser)
      }
      acc.push(EnumMember::{ name, initializer, location: loc })
      // Check for comma
      match current_token(parser) {
        Comma(_) => parse_enum_members_aux(advance_parser(parser), acc)
        _ => (acc, parser)
      }
    }
    _ => (acc, parser)
  }
}

///|
/// Parse namespace or module declaration
fn parse_module_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // namespace Name { statements }
  // module Name { statements }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'namespace' or 'module'
  parse_module_declaration_body(parser, start_loc)
}

///|
/// Parse the body of a module declaration (after the keyword)
/// This handles dotted names like A.B.C
fn parse_module_declaration_body(
  parser : Parser,
  start_loc : SourceLocation,
) -> Result[(Node, Parser), Parser] {
  // Parse namespace/module name
  let (name, is_ambient, parser) = match current_token(parser) {
    Identifier(n, _) => (n, false, advance_parser(parser))
    StringLiteral(s, _) => (s, true, advance_parser(parser)) // For ambient modules like declare module "fs"
    _ =>
      return Err(
        add_error_with_code(
          parser,
          "Identifier expected",
          current_token(parser).location(),
          IdentifierExpected,
        ),
      )
  }

  // Parse body
  match current_token(parser) {
    OpenBrace(_) =>
      // Parse block body
      match parse_block_statement(parser) {
        Ok((body, parser)) => {
          let end_loc = get_location(body)
          Ok(
            (
              Node::ModuleDeclaration(ModuleDeclaration::{
                name,
                body: Some(body),
                is_ambient,
                is_global_augmentation: false,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        Err(p) => Err(p)
      }
    Dot(_) => {
      // Dotted name like namespace A.B.C - recurse to parse B.C
      let parser = advance_parser(parser)
      let nested_start_loc = current_token(parser).location()
      match parse_module_declaration_body(parser, nested_start_loc) {
        Ok((nested, parser)) => {
          let end_loc = get_location(nested)
          Ok(
            (
              Node::ModuleDeclaration(ModuleDeclaration::{
                name,
                body: Some(nested),
                is_ambient: false, // Dotted names are not ambient
                is_global_augmentation: false,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        Err(p) => Err(p)
      }
    }
    _ => {
      // Empty module/namespace (declaration only)
      let parser = expect_semicolon(parser)
      Ok(
        (
          Node::ModuleDeclaration(ModuleDeclaration::{
            name,
            body: None,
            is_ambient,
            is_global_augmentation: false,
            location: start_loc,
          }),
          parser,
        ),
      )
    }
  }
}

///|
fn parse_import_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // import [importClause] from 'module'
  // import 'module'
  // import type { ... } from 'module'  (type-only import)
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'import'

  // Check for type-only import: import type ...
  let (is_type_only, parser) = match current_token(parser) {
    KeywordType(_) => {
      // Peek ahead to see if this is "import type X" or just "import type" as a name
      // If the next token is an identifier, '{', or '*', it's a type-only import
      let next = peek_token(parser)
      match next {
        Identifier(_, _) | OpenBrace(_) | Star(_) => (true, advance_parser(parser))
        _ => (false, parser) // Not a type-only import, 'type' might be a binding name
      }
    }
    _ => (false, parser)
  }

  // Check for side-effect only import: import 'module'
  match current_token(parser) {
    StringLiteral(module_specifier, _) => {
      let parser = advance_parser(parser)
      // Consume optional semicolon
      let parser = match current_token(parser) {
        Semicolon(_) => advance_parser(parser)
        _ => parser
      }
      let end_loc = current_token(parser).location()
      return Ok(
        (
          Node::ImportDeclaration(ImportDeclaration::{
            import_clause: None,
            module_specifier,
            is_type_only,
            location: SourceLocation::new(
              start_loc.file_path,
              start_loc.start,
              end_loc.end,
            ),
          }),
          parser,
        ),
      )
    }
    _ => ()
  }

  // Parse import clause (default and/or named imports)
  // First, check for import equals declaration: import X = M.N
  let (default_import, parser) = match current_token(parser) {
    Identifier(name, _) => {
      let parser = advance_parser(parser)
      // Check for import equals declaration: import X = M.N
      match current_token(parser) {
        Equals(_) => {
          // This is an import equals declaration
          let parser = advance_parser(parser) // consume '='
          let (module_reference, parser) = parse_entity_name(parser)
          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          let end_loc = current_token(parser).location()
          return Ok(
            (
              Node::ImportEqualsDeclaration(ImportEqualsDeclaration::{
                name,
                module_reference,
                is_export: false,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        Comma(_) => {
          // Mixed import: import foo, { bar } from 'mod'
          let parser = advance_parser(parser)
          (Some(name), parser)
        }
        _ => (Some(name), parser)
      }
    }
    _ => (None, parser)
  }

  // Parse named bindings (namespace or named imports)
  let (named_bindings, parser) = match current_token(parser) {
    Star(_) => {
      // Namespace import: * as name
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(name, loc) => {
              let parser = advance_parser(parser)
              (Some(NamedImports::NamespaceImport(name, loc)), parser)
            }
            _ =>
              return Err(
                add_error_with_code(
                  parser,
                  "Identifier expected",
                  current_token(parser).location(),
                  IdentifierExpected,
                ),
              )
          }
        }
        _ =>
          return Err(
            add_error(
              parser,
              "Unexpected token",
              current_token(parser).location(),
            ),
          )
      }
    }
    OpenBrace(_) => {
      // Named imports: { a, b, c as d }
      let parser = advance_parser(parser)
      let (specifiers, parser) = parse_import_specifiers(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          (Some(NamedImports::NamedImports(specifiers, loc)), parser)
        }
        _ =>
          return Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }
    _ => (None, parser)
  }

  // Expect 'from' keyword
  let parser = match current_token(parser) {
    KeywordFrom(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error(
          parser,
          "Unexpected token",
          current_token(parser).location(),
        ),
      )
  }

  // Parse module specifier (string literal)
  // TS1440: The 'import' path must be a string literal
  let (module_specifier, parser) = match current_token(parser) {
    StringLiteral(spec, _) => (spec, advance_parser(parser))
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ImportPathNotStringLiteral.to_message(),
          current_token(parser).location(),
          ImportPathNotStringLiteral,
        ),
      )
  }
  let end_loc = current_token(parser).location()

  // Build import clause if we have default or named imports
  let import_clause = if default_import is None && named_bindings is None {
    None
  } else {
    Some(ImportClause::{
      name: default_import,
      named_bindings,
      location: SourceLocation::new(
        start_loc.file_path,
        start_loc.start,
        end_loc.end,
      ),
    })
  }

  // Consume optional semicolon
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::ImportDeclaration(ImportDeclaration::{
        import_clause,
        module_specifier,
        is_type_only,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
/// Helper: Parse import specifiers { a, b as c, d }
fn parse_import_specifiers(parser : Parser) -> (Array[ImportSpecifier], Parser) {
  parse_import_specifiers_aux(parser, [])
}

///|
/// Tail-recursive helper for parsing import specifiers
fn parse_import_specifiers_aux(
  parser : Parser,
  acc : Array[ImportSpecifier],
) -> (Array[ImportSpecifier], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    // Check for inline type import: { type Foo }
    KeywordType(_) => {
      let parser = advance_parser(parser) // consume 'type'
      match current_token(parser) {
        Identifier(name, loc) => {
          let parser = advance_parser(parser)
          // Check for 'as' renaming
          match current_token(parser) {
            KeywordAs(_) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                Identifier(local_name, _) => {
                  let parser = advance_parser(parser)
                  acc.push(ImportSpecifier::{
                    property_name: Some(name),
                    name: local_name,
                    is_type_only: true, // inline type import
                    location: loc,
                  })
                  // Check for comma
                  match current_token(parser) {
                    Comma(_) =>
                      parse_import_specifiers_aux(advance_parser(parser), acc)
                    _ => (acc, parser)
                  }
                }
                _ => (acc, parser) // Error, but continue
              }
            }
            _ => {
              // No renaming
              acc.push(ImportSpecifier::{
                property_name: None,
                name,
                is_type_only: true, // inline type import
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_import_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
          }
        }
        _ => (acc, parser) // Error, but continue
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for 'as' renaming
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(local_name, _) => {
              let parser = advance_parser(parser)
              acc.push(ImportSpecifier::{
                property_name: Some(name),
                name: local_name,
                is_type_only: false,
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_import_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
            _ => (acc, parser) // Error, but continue
          }
        }
        _ => {
          // No renaming
          acc.push(ImportSpecifier::{
            property_name: None,
            name,
            is_type_only: false,
            location: loc,
          })
          // Check for comma
          match current_token(parser) {
            Comma(_) => parse_import_specifiers_aux(advance_parser(parser), acc)
            _ => (acc, parser)
          }
        }
      }
    }
    _ => (acc, parser)
  }
}

///|
/// Parse export declaration with decorators: @decorator export class ...
fn parse_export_declaration_with_decorators(
  parser : Parser,
  decorators : Array[Node],
) -> Result[(Node, Parser), Parser] {
  let parser = advance_parser(parser) // consume 'export'

  match current_token(parser) {
    // @decorator export default class ...
    KeywordDefault(_) => {
      let parser = advance_parser(parser)
      match current_token(parser) {
        KeywordClass(_) =>
          match parse_class_declaration_with_decorators(parser, false, decorators) {
            Ok((decl, parser)) => {
              let decl_with_modifiers = add_export_default_modifiers(decl)
              Ok((decl_with_modifiers, parser))
            }
            Err(p) => Err(p)
          }
        KeywordAbstract(_) => {
          let parser = advance_parser(parser)
          match parse_class_declaration_with_decorators(parser, true, decorators) {
            Ok((decl, parser)) => {
              let decl_with_modifiers = add_export_default_modifiers(decl)
              Ok((decl_with_modifiers, parser))
            }
            Err(p) => Err(p)
          }
        }
        _ => {
          let loc = current_token(parser).location()
          Err(
            add_error_with_code(
              parser,
              DecoratorsNotValidHere.to_message(),
              loc,
              DecoratorsNotValidHere,
            ),
          )
        }
      }
    }
    // @decorator export class ...
    KeywordClass(_) =>
      match parse_class_declaration_with_decorators(parser, false, decorators) {
        Ok((decl, parser)) => {
          let decl_with_export = add_export_modifier(decl)
          Ok((decl_with_export, parser))
        }
        Err(p) => Err(p)
      }
    // @decorator export abstract class ...
    KeywordAbstract(_) => {
      let parser = advance_parser(parser)
      match parse_class_declaration_with_decorators(parser, true, decorators) {
        Ok((decl, parser)) => {
          let decl_with_export = add_export_modifier(decl)
          Ok((decl_with_export, parser))
        }
        Err(p) => Err(p)
      }
    }
    _ => {
      let loc = get_location(decorators[0])
      Err(
        add_error_with_code(
          parser,
          DecoratorsNotValidHere.to_message(),
          loc,
          DecoratorsNotValidHere,
        ),
      )
    }
  }
}

///|
fn parse_export_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // export { a, b }
  // export { a, b } from 'module'
  // export * from 'module'
  // export default expression
  // export const/let/var/function/class ...
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'export'

  // TS1432: Check if decorator appears after 'export' - add error but continue
  let (decorators_after_export, parser) = match current_token(parser) {
    At(loc) => {
      let parser = add_error_with_code(
        parser,
        DecoratorsNotAfterExport.to_message(),
        loc,
        DecoratorsNotAfterExport,
      )
      // Parse the decorators so we can continue
      let (decorators, parser) = parse_decorators(parser)
      (decorators, parser)
    }
    _ => ([], parser)
  }

  match current_token(parser) {
    // export default expression/declaration
    KeywordDefault(_) => {
      let parser = advance_parser(parser)
      // Check if it's a declaration (function or class)
      match current_token(parser) {
        KeywordFunction(_) | KeywordClass(_) =>
          // Parse as declaration and add Export + Default modifiers
          match parse_statement(parser) {
            Ok((declaration, parser)) => {
              let decl_with_modifiers = add_export_default_modifiers(
                declaration,
              )
              Ok((decl_with_modifiers, parser))
            }
            Err(p) => Err(p)
          }
        _ =>
          // Parse as expression - use ExportAssignment
          match parse_expression(parser) {
            Ok((expression, parser)) => {
              let end_loc = get_location(expression)
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              Ok(
                (
                  Node::ExportAssignment(ExportAssignment::{
                    expression,
                    is_export_equals: false,
                    location: SourceLocation::new(
                      start_loc.file_path,
                      start_loc.start,
                      end_loc.end,
                    ),
                  }),
                  parser,
                ),
              )
            }
            Err(p) => Err(p)
          }
      }
    }

    // export * from 'module' OR export * as ns from 'module'
    Star(_) => {
      let star_loc = current_token(parser).location()
      let parser = advance_parser(parser)
      match current_token(parser) {
        // export * as ns from 'module'
        KeywordAs(_) => {
          let parser = advance_parser(parser) // consume 'as'
          match current_token(parser) {
            Identifier(ns_name, _) => {
              let parser = advance_parser(parser) // consume namespace name
              match current_token(parser) {
                KeywordFrom(_) => {
                  let parser = advance_parser(parser) // consume 'from'
                  match current_token(parser) {
                    StringLiteral(module_specifier, _) => {
                      let parser = advance_parser(parser)
                      // Consume optional semicolon
                      let parser = match current_token(parser) {
                        Semicolon(_) => advance_parser(parser)
                        _ => parser
                      }
                      let end_loc = current_token(parser).location()
                      Ok(
                        (
                          Node::ExportDeclaration(ExportDeclaration::{
                            export_clause: Some(
                              NamedExports::NamespaceExport(ns_name, star_loc),
                            ),
                            module_specifier: Some(module_specifier),
                            is_type_only: false,
                            location: SourceLocation::new(
                              start_loc.file_path,
                              start_loc.start,
                              end_loc.end,
                            ),
                          }),
                          parser,
                        ),
                      )
                    }
                    _ =>
                      Err(
                        add_error(
                          parser,
                          "Unexpected token",
                          current_token(parser).location(),
                        ),
                      )
                  }
                }
                _ =>
                  Err(
                    add_error(
                      parser,
                      "Unexpected token",
                      current_token(parser).location(),
                    ),
                  )
              }
            }
            _ =>
              Err(
                add_error_with_code(
                  parser,
                  "Identifier expected",
                  current_token(parser).location(),
                  IdentifierExpected,
                ),
              )
          }
        }
        // export * from 'module'
        KeywordFrom(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            StringLiteral(module_specifier, _) => {
              let parser = advance_parser(parser)
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              let end_loc = current_token(parser).location()
              Ok(
                (
                  Node::ExportDeclaration(ExportDeclaration::{
                    export_clause: None,
                    module_specifier: Some(module_specifier),
                    is_type_only: false,
                    location: SourceLocation::new(
                      start_loc.file_path,
                      start_loc.start,
                      end_loc.end,
                    ),
                  }),
                  parser,
                ),
              )
            }
            _ =>
              Err(
                add_error(
                  parser,
                  "Unexpected token",
                  current_token(parser).location(),
                ),
              )
          }
        }
        _ =>
          Err(
            add_error(
              parser,
              "Unexpected token",
              current_token(parser).location(),
            ),
          )
      }
    }

    // export type { a, b } [from 'module'] OR export type Foo = ...
    KeywordType(_) => {
      // Look ahead to determine if this is `export type { ... }` or `export type Foo = ...`
      let parser_after_type = advance_parser(parser) // consume 'type'
      match current_token(parser_after_type) {
        // export type { a, b } [from 'module']
        OpenBrace(_) => {
          let parser = advance_parser(parser_after_type)
          let (specifiers, parser) = parse_export_specifiers(parser)
          match current_token(parser) {
            CloseBrace(loc) => {
              let parser = advance_parser(parser)
              // Check for 'from' clause
              let (module_specifier, parser) = match current_token(parser) {
                KeywordFrom(_) => {
                  let parser = advance_parser(parser)
                  match current_token(parser) {
                    StringLiteral(spec, _) =>
                      (Some(spec), advance_parser(parser))
                    _ =>
                      return Err(
                        add_error(
                          parser,
                          "Unexpected token",
                          current_token(parser).location(),
                        ),
                      )
                  }
                }
                _ => (None, parser)
              }
              // Consume optional semicolon
              let parser = match current_token(parser) {
                Semicolon(_) => advance_parser(parser)
                _ => parser
              }
              let end_loc = current_token(parser).location()
              Ok(
                (
                  Node::ExportDeclaration(ExportDeclaration::{
                    export_clause: Some(
                      NamedExports::NamedExports(specifiers, loc),
                    ),
                    module_specifier,
                    is_type_only: true,
                    location: SourceLocation::new(
                      start_loc.file_path,
                      start_loc.start,
                      end_loc.end,
                    ),
                  }),
                  parser,
                ),
              )
            }
            _ =>
              Err(
                add_error_with_code(
                  parser,
                  ExpectedCloseBrace.to_message(),
                  current_token(parser).location(),
                  ExpectedCloseBrace,
                ),
              )
          }
        }
        // export type Foo = ... (type alias declaration with export)
        _ =>
          // Parse as type alias declaration (parser is still at 'type' keyword) and add Export modifier
          match parse_type_alias_declaration(parser) {
            Ok((type_alias, parser)) => {
              let type_alias_with_export = add_export_modifier(type_alias)
              Ok((type_alias_with_export, parser))
            }
            Err(p) => Err(p)
          }
      }
    }

    // export { a, b } [from 'module']
    OpenBrace(_) => {
      let parser = advance_parser(parser)
      let (specifiers, parser) = parse_export_specifiers(parser)
      match current_token(parser) {
        CloseBrace(loc) => {
          let parser = advance_parser(parser)
          // Check for 'from' clause
          let (module_specifier, parser) = match current_token(parser) {
            KeywordFrom(_) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                StringLiteral(spec, _) => (Some(spec), advance_parser(parser))
                _ =>
                  return Err(
                    add_error(
                      parser,
                      "Unexpected token",
                      current_token(parser).location(),
                    ),
                  )
              }
            }
            _ => (None, parser)
          }
          // Consume optional semicolon
          let parser = match current_token(parser) {
            Semicolon(_) => advance_parser(parser)
            _ => parser
          }
          let end_loc = current_token(parser).location()
          Ok(
            (
              Node::ExportDeclaration(ExportDeclaration::{
                export_clause: Some(NamedExports::NamedExports(specifiers, loc)),
                module_specifier,
                is_type_only: false,
                location: SourceLocation::new(
                  start_loc.file_path,
                  start_loc.start,
                  end_loc.end,
                ),
              }),
              parser,
            ),
          )
        }
        _ =>
          Err(
            add_error_with_code(
              parser,
              ExpectedCloseBrace.to_message(),
              current_token(parser).location(),
              ExpectedCloseBrace,
            ),
          )
      }
    }

    // export declaration (const, let, var, function, class, etc.)
    _ =>
      // If we parsed decorators after export (TS1432), use them
      if decorators_after_export.length() > 0 {
        match current_token(parser) {
          KeywordClass(_) =>
            match parse_class_declaration_with_decorators(
              parser, false, decorators_after_export,
            ) {
              Ok((decl, parser)) => {
                let decl_with_export = add_export_modifier(decl)
                Ok((decl_with_export, parser))
              }
              Err(p) => Err(p)
            }
          KeywordAbstract(_) => {
            let parser = advance_parser(parser)
            match parse_class_declaration_with_decorators(
              parser, true, decorators_after_export,
            ) {
              Ok((decl, parser)) => {
                let decl_with_export = add_export_modifier(decl)
                Ok((decl_with_export, parser))
              }
              Err(p) => Err(p)
            }
          }
          _ =>
            // Parse normally, decorators will be lost
            match parse_statement(parser) {
              Ok((stmt, parser)) => {
                let stmt_with_export = add_export_modifier(stmt)
                Ok((stmt_with_export, parser))
              }
              Err(p) => Err(p)
            }
        }
      } else {
        // Normal case - no decorators after export
        match parse_statement(parser) {
          Ok((stmt, parser)) => {
            // Add Export modifier to the declaration
            let stmt_with_export = add_export_modifier(stmt)
            Ok((stmt_with_export, parser))
          }
          Err(p) => Err(p)
        }
      }
  }
}

///|
/// Helper: Add Export modifier to a declaration
fn add_export_modifier(node : Node) -> Node {
  match node {
    VariableStatement(vs) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in vs.modifiers {
        new_modifiers.push(m)
      }
      Node::VariableStatement(VariableStatement::{
        declarations: vs.declarations,
        is_const: vs.is_const,
        is_let: vs.is_let,
        modifiers: new_modifiers,
        location: vs.location,
      })
    }
    FunctionDeclaration(fd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in fd.modifiers {
        new_modifiers.push(m)
      }
      Node::FunctionDeclaration(FunctionDeclaration::{
        name: fd.name,
        type_parameters: fd.type_parameters,
        parameters: fd.parameters,
        return_type: fd.return_type,
        body: fd.body,
        is_async: fd.is_async,
        is_generator: fd.is_generator,
        modifiers: new_modifiers,
        location: fd.location,
      })
    }
    ClassDeclaration(cd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in cd.modifiers {
        new_modifiers.push(m)
      }
      Node::ClassDeclaration(ClassDeclaration::{
        name: cd.name,
        type_parameters: cd.type_parameters,
        heritage_clauses: cd.heritage_clauses,
        members: cd.members,
        is_abstract: cd.is_abstract,
        decorators: cd.decorators,
        modifiers: new_modifiers,
        location: cd.location,
      })
    }
    InterfaceDeclaration(id) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in id.modifiers {
        new_modifiers.push(m)
      }
      Node::InterfaceDeclaration(InterfaceDeclaration::{
        name: id.name,
        type_parameters: id.type_parameters,
        heritage_clauses: id.heritage_clauses,
        members: id.members,
        modifiers: new_modifiers,
        location: id.location,
      })
    }
    TypeAliasDeclaration(ta) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in ta.modifiers {
        new_modifiers.push(m)
      }
      Node::TypeAliasDeclaration(TypeAliasDeclaration::{
        name: ta.name,
        type_parameters: ta.type_parameters,
        type_node: ta.type_node,
        modifiers: new_modifiers,
        location: ta.location,
      })
    }
    EnumDeclaration(ed) => {
      let new_modifiers : Array[Modifier] = [Modifier::Export]
      for m in ed.modifiers {
        new_modifiers.push(m)
      }
      Node::EnumDeclaration(EnumDeclaration::{
        name: ed.name,
        members: ed.members,
        is_const: ed.is_const,
        modifiers: new_modifiers,
        location: ed.location,
      })
    }
    ImportEqualsDeclaration(ied) =>
      Node::ImportEqualsDeclaration(ImportEqualsDeclaration::{
        name: ied.name,
        module_reference: ied.module_reference,
        is_export: true,
        location: ied.location,
      })
    _ => node // For other nodes, return as-is
  }
}

///|
/// Helper: Add Export and Default modifiers to a declaration
fn add_export_default_modifiers(node : Node) -> Node {
  match node {
    FunctionDeclaration(fd) => {
      let new_modifiers : Array[Modifier] = [
        Modifier::Export,
        Modifier::Default,
      ]
      for m in fd.modifiers {
        new_modifiers.push(m)
      }
      Node::FunctionDeclaration(FunctionDeclaration::{
        name: fd.name,
        type_parameters: fd.type_parameters,
        parameters: fd.parameters,
        return_type: fd.return_type,
        body: fd.body,
        is_async: fd.is_async,
        is_generator: fd.is_generator,
        modifiers: new_modifiers,
        location: fd.location,
      })
    }
    ClassDeclaration(cd) => {
      let new_modifiers : Array[Modifier] = [
        Modifier::Export,
        Modifier::Default,
      ]
      for m in cd.modifiers {
        new_modifiers.push(m)
      }
      Node::ClassDeclaration(ClassDeclaration::{
        name: cd.name,
        type_parameters: cd.type_parameters,
        heritage_clauses: cd.heritage_clauses,
        members: cd.members,
        is_abstract: cd.is_abstract,
        decorators: cd.decorators,
        modifiers: new_modifiers,
        location: cd.location,
      })
    }
    _ => node // For other nodes, return as-is
  }
}

///|
/// Parse declare (ambient) declaration
fn parse_declare_declaration(parser : Parser) -> Result[(Node, Parser), Parser] {
  // declare const/let/var/function/class/enum/module/namespace/global
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'declare'

  // Check for 'declare global { }' - global augmentation
  match current_token(parser) {
    Identifier(name, _) if name == "global" => {
      let parser = advance_parser(parser) // consume 'global'
      // Parse block statement { ... }
      match parse_block_statement(parser) {
        Ok((body, parser)) => {
          let end_loc = get_location(body)
          let location = SourceLocation::new(start_loc.file_path, start_loc.start, end_loc.end)
          // Create ModuleDeclaration with is_global_augmentation=true
          Ok((Node::ModuleDeclaration(ModuleDeclaration::{
            name: "global",
            body: Some(body),
            is_ambient: false,
            is_global_augmentation: true,
            location,
          }), parser))
        }
        Err(p) => Err(p)
      }
    }
    _ => {
      match parse_statement(parser) {
        Ok((stmt, parser)) => {
          // Add Declare modifier to the declaration
          let stmt_with_declare = add_declare_modifier(stmt)
          Ok((stmt_with_declare, parser))
        }
        Err(p) => Err(p)
      }
    }
  }
}

///|
/// Helper: Add Declare modifier to a declaration
fn add_declare_modifier(node : Node) -> Node {
  match node {
    VariableStatement(vs) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in vs.modifiers {
        new_modifiers.push(m)
      }
      Node::VariableStatement(VariableStatement::{
        declarations: vs.declarations,
        is_const: vs.is_const,
        is_let: vs.is_let,
        modifiers: new_modifiers,
        location: vs.location,
      })
    }
    FunctionDeclaration(fd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in fd.modifiers {
        new_modifiers.push(m)
      }
      Node::FunctionDeclaration(FunctionDeclaration::{
        name: fd.name,
        type_parameters: fd.type_parameters,
        parameters: fd.parameters,
        return_type: fd.return_type,
        body: fd.body,
        is_async: fd.is_async,
        is_generator: fd.is_generator,
        modifiers: new_modifiers,
        location: fd.location,
      })
    }
    ClassDeclaration(cd) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in cd.modifiers {
        new_modifiers.push(m)
      }
      Node::ClassDeclaration(ClassDeclaration::{
        name: cd.name,
        type_parameters: cd.type_parameters,
        heritage_clauses: cd.heritage_clauses,
        members: cd.members,
        is_abstract: cd.is_abstract,
        decorators: cd.decorators,
        modifiers: new_modifiers,
        location: cd.location,
      })
    }
    InterfaceDeclaration(id) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in id.modifiers {
        new_modifiers.push(m)
      }
      Node::InterfaceDeclaration(InterfaceDeclaration::{
        name: id.name,
        type_parameters: id.type_parameters,
        heritage_clauses: id.heritage_clauses,
        members: id.members,
        modifiers: new_modifiers,
        location: id.location,
      })
    }
    TypeAliasDeclaration(ta) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in ta.modifiers {
        new_modifiers.push(m)
      }
      Node::TypeAliasDeclaration(TypeAliasDeclaration::{
        name: ta.name,
        type_parameters: ta.type_parameters,
        type_node: ta.type_node,
        modifiers: new_modifiers,
        location: ta.location,
      })
    }
    EnumDeclaration(ed) => {
      let new_modifiers : Array[Modifier] = [Modifier::Declare]
      for m in ed.modifiers {
        new_modifiers.push(m)
      }
      Node::EnumDeclaration(EnumDeclaration::{
        name: ed.name,
        members: ed.members,
        is_const: ed.is_const,
        modifiers: new_modifiers,
        location: ed.location,
      })
    }
    _ => node // For other nodes, return as-is
  }
}

///|
/// Helper: Parse export specifiers { a, b as c, d }
fn parse_export_specifiers(parser : Parser) -> (Array[ExportSpecifier], Parser) {
  parse_export_specifiers_aux(parser, [])
}

///|
/// Tail-recursive helper for parsing export specifiers
fn parse_export_specifiers_aux(
  parser : Parser,
  acc : Array[ExportSpecifier],
) -> (Array[ExportSpecifier], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)
    // Check for inline type export: { type Foo }
    KeywordType(_) => {
      let parser = advance_parser(parser) // consume 'type'
      match current_token(parser) {
        Identifier(name, loc) => {
          let parser = advance_parser(parser)
          // Check for 'as' renaming
          match current_token(parser) {
            KeywordAs(_) => {
              let parser = advance_parser(parser)
              match current_token(parser) {
                Identifier(export_name, _) => {
                  let parser = advance_parser(parser)
                  acc.push(ExportSpecifier::{
                    property_name: Some(name),
                    name: export_name,
                    is_type_only: true, // inline type export
                    location: loc,
                  })
                  // Check for comma
                  match current_token(parser) {
                    Comma(_) =>
                      parse_export_specifiers_aux(advance_parser(parser), acc)
                    _ => (acc, parser)
                  }
                }
                _ => (acc, parser) // Error, but continue
              }
            }
            _ => {
              // No renaming
              acc.push(ExportSpecifier::{
                property_name: None,
                name,
                is_type_only: true, // inline type export
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_export_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
          }
        }
        _ => (acc, parser) // Error, but continue
      }
    }
    Identifier(name, loc) => {
      let parser = advance_parser(parser)
      // Check for 'as' renaming
      match current_token(parser) {
        KeywordAs(_) => {
          let parser = advance_parser(parser)
          match current_token(parser) {
            Identifier(export_name, _) => {
              let parser = advance_parser(parser)
              acc.push(ExportSpecifier::{
                property_name: Some(name),
                name: export_name,
                is_type_only: false,
                location: loc,
              })
              // Check for comma
              match current_token(parser) {
                Comma(_) =>
                  parse_export_specifiers_aux(advance_parser(parser), acc)
                _ => (acc, parser)
              }
            }
            _ => (acc, parser) // Error, but continue
          }
        }
        _ => {
          // No renaming
          acc.push(ExportSpecifier::{
            property_name: None,
            name,
            is_type_only: false,
            location: loc,
          })
          // Check for comma
          match current_token(parser) {
            Comma(_) => parse_export_specifiers_aux(advance_parser(parser), acc)
            _ => (acc, parser)
          }
        }
      }
    }
    _ => (acc, parser)
  }
}

///|
fn parse_switch_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // switch (expression) { case value: statements; default: statements; }
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'switch'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse expression
  let (expression, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Expect '{'
  let parser = match current_token(parser) {
    OpenBrace(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenBrace.to_message(),
          current_token(parser).location(),
          ExpectedOpenBrace,
        ),
      )
  }

  // Parse case clauses
  let (cases, parser) = parse_case_clauses(parser)

  // Expect '}'
  let end_loc = match current_token(parser) {
    CloseBrace(loc) => loc
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseBrace.to_message(),
          current_token(parser).location(),
          ExpectedCloseBrace,
        ),
      )
  }
  let parser = advance_parser(parser)
  Ok(
    (
      Node::SwitchStatement(SwitchStatement::{
        expression,
        cases,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
/// Parse case clauses
fn parse_case_clauses(parser : Parser) -> (Array[CaseClause], Parser) {
  parse_case_clauses_aux(parser, [])
}

///|
fn parse_case_clauses_aux(
  parser : Parser,
  acc : Array[CaseClause],
) -> (Array[CaseClause], Parser) {
  match current_token(parser) {
    CloseBrace(_) | EOF(_) => (acc, parser)

    // case expression:
    KeywordCase(loc) => {
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
      // Expect ':'
      let parser = match current_token(parser) {
        Colon(_) => advance_parser(parser)
        _ => parser // Continue anyway
      }
      // Parse statements until next case/default or close brace
      let (statements, parser) = parse_case_statements(parser)
      acc.push(CaseClause::{ expression, statements, location: loc })
      parse_case_clauses_aux(parser, acc)
    }

    // default:
    KeywordDefault(loc) => {
      let parser = advance_parser(parser)
      // Expect ':'
      let parser = match current_token(parser) {
        Colon(_) => advance_parser(parser)
        _ => parser // Continue anyway
      }
      // Parse statements until next case or close brace
      let (statements, parser) = parse_case_statements(parser)
      acc.push(CaseClause::{ expression: None, statements, location: loc })
      parse_case_clauses_aux(parser, acc)
    }
    _ => (acc, parser)
  }
}

///|
/// Parse statements within a case clause
fn parse_case_statements(parser : Parser) -> (Array[Node], Parser) {
  parse_case_statements_aux(parser, [])
}

///|
fn parse_case_statements_aux(
  parser : Parser,
  acc : Array[Node],
) -> (Array[Node], Parser) {
  match current_token(parser) {
    KeywordCase(_) | KeywordDefault(_) | CloseBrace(_) | EOF(_) => (acc, parser)
    _ =>
      match parse_statement(parser) {
        Ok((stmt, p)) => {
          acc.push(stmt)
          parse_case_statements_aux(p, acc)
        }
        Err(p) => (acc, p)
      }
  }
}

///|
fn parse_for_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // for ([init]; [condition]; [incrementor]) statement
  // for (variable in object) statement
  // for (variable of iterable) statement
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'for'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse initializer (or for-in/for-of variable)
  let (initializer, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    KeywordLet(_) | KeywordConst(_) | KeywordVar(_) =>
      // Use parse_variable_declaration_list to avoid consuming the semicolon
      // The semicolon belongs to the for-loop syntax, not the variable declaration
      match parse_variable_declaration_list(parser, true) {
        Ok((declarations, is_const, is_let, location, p)) => {
          let stmt = Node::VariableStatement(VariableStatement::{
            declarations,
            is_const,
            is_let,
            modifiers: [],
            location,
          })
          (Some(stmt), p)
        }
        Err(p) => (None, p)
      }
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }

  // Check for for-in or for-of
  match current_token(parser) {
    KeywordIn(_) => {
      // for-in loop
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpressionExpected.to_message(),
              current_token(p).location(),
              ExpressionExpected,
            ),
          )
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error_with_code(
              parser,
              ExpectedCloseParen.to_message(),
              current_token(parser).location(),
              ExpectedCloseParen,
            ),
          )
      }
      let (statement, parser) = match parse_statement(parser) {
        Ok((stmt, p)) => (stmt, p)
        Err(p) => return Err(p)
      }
      let end_loc = get_location(statement)
      return Ok(
        (
          Node::ForInStatement(ForInStatement::{
            initializer: initializer.unwrap_or(
              Node::EmptyStatement(EmptyStatement::{ location: start_loc }),
            ),
            expression,
            statement,
            location: SourceLocation::new(
              start_loc.file_path,
              start_loc.start,
              end_loc.end,
            ),
          }),
          parser,
        ),
      )
    }
    KeywordOf(_) => {
      // for-of loop
      let parser = advance_parser(parser)
      let (expression, parser) = match parse_expression(parser) {
        Ok((expr, p)) => (expr, p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpressionExpected.to_message(),
              current_token(p).location(),
              ExpressionExpected,
            ),
          )
      }
      let parser = match current_token(parser) {
        CloseParen(_) => advance_parser(parser)
        _ =>
          return Err(
            add_error_with_code(
              parser,
              ExpectedCloseParen.to_message(),
              current_token(parser).location(),
              ExpectedCloseParen,
            ),
          )
      }
      let (statement, parser) = match parse_statement(parser) {
        Ok((stmt, p)) => (stmt, p)
        Err(p) => return Err(p)
      }
      let end_loc = get_location(statement)
      return Ok(
        (
          Node::ForOfStatement(ForOfStatement::{
            initializer: initializer.unwrap_or(
              Node::EmptyStatement(EmptyStatement::{ location: start_loc }),
            ),
            expression,
            statement,
            await_modifier: false,
            location: SourceLocation::new(
              start_loc.file_path,
              start_loc.start,
              end_loc.end,
            ),
          }),
          parser,
        ),
      )
    }
    _ => ()
  }

  // Regular for loop: for (init; condition; incrementor) statement
  // Expect semicolon after initializer
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedSemicolon.to_message(),
          current_token(parser).location(),
          ExpectedSemicolon,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match current_token(parser) {
    Semicolon(_) => (None, parser)
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }

  // Expect semicolon after condition
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedSemicolon.to_message(),
          current_token(parser).location(),
          ExpectedSemicolon,
        ),
      )
  }

  // Parse incrementor
  let (incrementor, parser) = match current_token(parser) {
    CloseParen(_) => (None, parser)
    _ =>
      match parse_expression(parser) {
        Ok((expr, p)) => (Some(expr), p)
        Err(p) => (None, p)
      }
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }
  let end_loc = get_location(statement)
  Ok(
    (
      Node::ForStatement(ForStatement::{
        initializer,
        condition,
        incrementor,
        statement,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_while_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // while (condition) statement
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'while'

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }
  let end_loc = get_location(statement)
  Ok(
    (
      Node::WhileStatement(WhileStatement::{
        condition,
        statement,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_do_while_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // do statement while (condition);
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'do'

  // Parse statement
  let (statement, parser) = match parse_statement(parser) {
    Ok((stmt, p)) => (stmt, p)
    Err(p) => return Err(p)
  }

  // Expect 'while'
  let parser = match current_token(parser) {
    KeywordWhile(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error(
          parser,
          "Unexpected token",
          current_token(parser).location(),
        ),
      )
  }

  // Expect '('
  let parser = match current_token(parser) {
    OpenParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedOpenParen.to_message(),
          current_token(parser).location(),
          ExpectedOpenParen,
        ),
      )
  }

  // Parse condition
  let (condition, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) => return Err(p)
  }

  // Expect ')'
  let parser = match current_token(parser) {
    CloseParen(_) => advance_parser(parser)
    _ =>
      return Err(
        add_error_with_code(
          parser,
          ExpectedCloseParen.to_message(),
          current_token(parser).location(),
          ExpectedCloseParen,
        ),
      )
  }

  // Expect ';'
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser // Semicolon is optional in some contexts
  }
  Ok(
    (
      Node::DoWhileStatement(DoWhileStatement::{
        statement,
        condition,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_break_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // break [label];
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'break'

  // Optional label
  let (label, parser) = match current_token(parser) {
    Identifier(name, _loc) => (Some(name), advance_parser(parser))
    _ => (None, parser)
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::BreakStatement(BreakStatement::{
        label,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_continue_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // continue [label];
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'continue'

  // Optional label
  let (label, parser) = match current_token(parser) {
    Identifier(name, _loc) => (Some(name), advance_parser(parser))
    _ => (None, parser)
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = current_token(parser).location()
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::ContinueStatement(ContinueStatement::{
        label,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_throw_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // throw expression;
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'throw'

  // Parse expression
  let (expression, parser) = match parse_expression(parser) {
    Ok((expr, p)) => (expr, p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpressionExpected.to_message(),
          current_token(p).location(),
          ExpressionExpected,
        ),
      )
  }

  // Expect semicolon (optional due to ASI)
  let end_loc = get_location(expression)
  let parser = match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser
  }
  Ok(
    (
      Node::ThrowStatement(ThrowStatement::{
        expression,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
fn parse_try_statement(parser : Parser) -> Result[(Node, Parser), Parser] {
  // try block catch (variable) block finally block
  let start_loc = current_token(parser).location()
  let parser = advance_parser(parser) // consume 'try'

  // Parse try block
  let (try_block, parser) = match parse_block_statement(parser) {
    Ok((block, p)) => (block, p)
    Err(p) =>
      return Err(
        add_error_with_code(
          p,
          ExpectedOpenBrace.to_message(),
          current_token(p).location(),
          ExpectedOpenBrace,
        ),
      )
  }

  // Parse optional catch clause
  let (catch_clause, parser) = match current_token(parser) {
    KeywordCatch(_) => {
      let catch_start = current_token(parser).location()
      let parser = advance_parser(parser) // consume 'catch'

      // Optional parameter (can be identifier, array pattern, or object pattern)
      let (parameter, parser) = match current_token(parser) {
        OpenParen(_) => {
          let parser = advance_parser(parser)
          // Parse catch parameter: identifier, array pattern, or object pattern
          let (param, parser) = match current_token(parser) {
            OpenBracket(_) =>
              // Array destructuring pattern: catch ([a, b])
              match parse_array_binding_pattern(parser) {
                Ok((pattern, p)) => (Some(pattern), p)
                Err(p) => (None, p)
              }
            OpenBrace(_) =>
              // Object destructuring pattern: catch ({ message, name })
              match parse_object_binding_pattern(parser) {
                Ok((pattern, p)) => (Some(pattern), p)
                Err(p) => (None, p)
              }
            CloseParen(_) =>
              // Empty catch: catch ()
              (None, parser)
            _ =>
              // Regular identifier: catch (e)
              match parse_identifier(parser) {
                Ok((id, p)) => (Some(Node::Identifier(id)), p)
                Err(p) => (None, p)
              }
          }
          // Optional type annotation: catch (e: unknown)
          let (param, parser) = match (param, current_token(parser)) {
            (Some(p), Colon(_)) => {
              let parser = advance_parser(parser)
              // Parse the type but we don't store it in catch clause yet
              // The type annotation is parsed but the catch variable binding
              // will still work with the identifier/pattern
              match parse_type(parser) {
                Ok((_, parser)) => (Some(p), parser)
                Err(parser) => (Some(p), parser)
              }
            }
            (p, _) => (p, parser)
          }
          let parser = match current_token(parser) {
            CloseParen(_) => advance_parser(parser)
            _ =>
              return Err(
                add_error_with_code(
                  parser,
                  ExpectedCloseParen.to_message(),
                  current_token(parser).location(),
                  ExpectedCloseParen,
                ),
              )
          }
          (param, parser)
        }
        _ => (None, parser)
      }

      // Parse catch block
      let (catch_block, parser) = match parse_block_statement(parser) {
        Ok((block, p)) => (block, p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpectedOpenBrace.to_message(),
              current_token(p).location(),
              ExpectedOpenBrace,
            ),
          )
      }
      let catch_end = get_location(catch_block)
      let clause = CatchClause::{
        variable_declaration: parameter,
        block: catch_block,
        location: SourceLocation::new(
          catch_start.file_path,
          catch_start.start,
          catch_end.end,
        ),
      }
      (Some(clause), parser)
    }
    _ => (None, parser)
  }

  // Parse optional finally clause
  let (finally_block, parser) = match current_token(parser) {
    KeywordFinally(_) => {
      let parser = advance_parser(parser) // consume 'finally'
      match parse_block_statement(parser) {
        Ok((block, p)) => (Some(block), p)
        Err(p) =>
          return Err(
            add_error_with_code(
              p,
              ExpectedOpenBrace.to_message(),
              current_token(p).location(),
              ExpectedOpenBrace,
            ),
          )
      }
    }
    _ => (None, parser)
  }

  // Must have either catch or finally
  if catch_clause is None && finally_block is None {
    return Err(
      add_error(
        parser,
        "Unexpected token",
        current_token(parser).location(),
      ),
    )
  }
  let end_loc = match finally_block {
    Some(block) => get_location(block)
    None =>
      match catch_clause {
        Some(clause) => clause.location
        None => get_location(try_block)
      }
  }
  Ok(
    (
      Node::TryStatement(TryStatement::{
        try_block,
        catch_clause,
        finally_block,
        location: SourceLocation::new(
          start_loc.file_path,
          start_loc.start,
          end_loc.end,
        ),
      }),
      parser,
    ),
  )
}

///|
/// Helper to parse constraint and default for type parameters
fn parse_type_param_constraint_and_default(
  parser : Parser,
) -> (Node?, Node?, Parser) {
  let mut parser = parser

  // Optional constraint (extends)
  let constraint = match current_token(parser) {
    KeywordExtends(_) => {
      parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => {
          parser = p
          Some(ty)
        }
        Err(p) => {
          parser = p
          None
        }
      }
    }
    _ => None
  }

  // Optional default
  let default_type = match current_token(parser) {
    Equals(_) => {
      parser = advance_parser(parser)
      match parse_type(parser) {
        Ok((ty, p)) => {
          parser = p
          Some(ty)
        }
        Err(p) => {
          parser = p
          None
        }
      }
    }
    _ => None
  }

  (constraint, default_type, parser)
}

///|
fn parse_type_parameters(parser : Parser) -> (Array[TypeParameter], Parser) {
  // Expect <
  let parser = match current_token(parser) {
    LessThan(_) => advance_parser(parser)
    _ => return ([], parser)
  }
  let type_params = []
  let mut parser = parser

  // Parse type parameter list
  while true {
    match current_token(parser) {
      GreaterThan(_) => {
        parser = advance_parser(parser)
        break
      }
      // Check for `const` type parameter modifier (TS 5.0+)
      KeywordConst(_) => {
        parser = advance_parser(parser)
        match current_token(parser) {
          Identifier(name, loc) => {
            parser = advance_parser(parser)
            let (constraint, default_type, p) = parse_type_param_constraint_and_default(
              parser,
            )
            parser = p
            type_params.push(
              TypeParameter::{
                name,
                constraint,
                default: default_type,
                is_const: true,
                location: loc,
              },
            )
            match current_token(parser) {
              Comma(_) => {
                parser = advance_parser(parser)
                continue
              }
              GreaterThan(_) => continue
              _ => break
            }
          }
          _ => break
        }
      }
      Identifier(name, loc) => {
        // Parse type parameter name
        parser = advance_parser(parser)

        let (constraint, default_type, p) = parse_type_param_constraint_and_default(
          parser,
        )
        parser = p
        type_params.push(
          TypeParameter::{
            name,
            constraint,
            default: default_type,
            is_const: false,
            location: loc,
          },
        )

        // Check for comma
        match current_token(parser) {
          Comma(_) => {
            parser = advance_parser(parser)
            continue
          }
          GreaterThan(_) => continue
          _ => break
        }
      }
      _ => break
    }
  }
  (type_params, parser)
}

///|
/// Check if current token is a greater-than (or starts with one) in type context
/// Returns true if token is >, >>, or >>>
fn is_greater_than_in_type_context(parser : Parser) -> Bool {
  match current_token(parser) {
    GreaterThan(_) => true
    GreaterThanGreaterThan(_) => true
    GreaterThanGreaterThanGreaterThan(_) => true
    _ => false
  }
}

///|
/// Consume a single > in type context, handling >> and >>> tokens
/// For >>: replaces token with single > and doesn't advance (leaves one > for outer context)
/// For >>>: replaces token with >> and doesn't advance
fn consume_greater_than_in_type_context(parser : Parser) -> Parser {
  match current_token(parser) {
    GreaterThan(_) => advance_parser(parser)
    GreaterThanGreaterThan(loc) => {
      // Replace >> with > at current position (consume one >)
      parser.tokens[parser.position] = GreaterThan(loc)
      parser
    }
    GreaterThanGreaterThanGreaterThan(loc) => {
      // Replace >>> with >> at current position (consume one >)
      parser.tokens[parser.position] = GreaterThanGreaterThan(loc)
      parser
    }
    _ => parser
  }
}

///|
/// Parse type argument list (for generic function/type usage)
fn parse_type_argument_list(
  parser : Parser,
) -> Result[(Array[Node], Parser), Parser] {
  // Save diagnostics length for backtracking
  let initial_diag_length = parser.diagnostics.length()

  // Expect <
  let parser = match current_token(parser) {
    LessThan(_) => advance_parser(parser)
    _ => return Err(parser)
  }
  let type_args = []
  let mut parser = parser

  // Parse type argument list
  while true {
    // Check for closing > (also handles >> and >>> for nested generics)
    if is_greater_than_in_type_context(parser) {
      parser = consume_greater_than_in_type_context(parser)
      break
    }
    match parse_type(parser) {
      Ok((ty, p)) => {
        type_args.push(ty)
        parser = p

        // Check for comma or closing >
        match current_token(parser) {
          Comma(_) => {
            parser = advance_parser(parser)
            continue
          }
          _ => {
            // Check for > or >> or >>> (closing bracket)
            if is_greater_than_in_type_context(parser) {
              continue
            }
            // Failed to parse - restore diagnostics and return error
            while parser.diagnostics.length() > initial_diag_length {
              let _ = parser.diagnostics.pop()

            }
            return Err(parser)
          }
        }
      }
      Err(p) => {
        // Failed to parse type - restore diagnostics and return error
        while p.diagnostics.length() > initial_diag_length {
          let _ = p.diagnostics.pop()

        }
        return Err(p)
      }
    }
  }
  Ok((type_args, parser))
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
/// Get current token
fn current_token(parser : Parser) -> Token {
  if parser.position < parser.tokens.length() {
    match parser.tokens.get(parser.position) {
      Some(token) => token
      None =>
        EOF(
          SourceLocation::new(
            "",
            Position::new(0, 0, 0),
            Position::new(0, 0, 0),
          ),
        )
    }
  } else {
    EOF(SourceLocation::new("", Position::new(0, 0, 0), Position::new(0, 0, 0)))
  }
}

///|
/// Advance parser position
fn advance_parser(parser : Parser) -> Parser {
  if parser.position < parser.tokens.length() {
    { ..parser, position: parser.position + 1 }
  } else {
    parser
  }
}

///|
/// Peek at the next token without advancing the parser
fn peek_token(parser : Parser) -> Token {
  let next_pos = parser.position + 1
  if next_pos < parser.tokens.length() {
    match parser.tokens.get(next_pos) {
      Some(token) => token
      None =>
        EOF(
          SourceLocation::new(
            "",
            Position::new(0, 0, 0),
            Position::new(0, 0, 0),
          ),
        )
    }
  } else {
    EOF(SourceLocation::new("", Position::new(0, 0, 0), Position::new(0, 0, 0)))
  }
}

///|
/// Increment parser depth (for expression parsing)
fn increment_depth(parser : Parser) -> Parser {
  { ..parser, depth: parser.depth + 1 }
}

///|
/// Decrement parser depth (for expression parsing)
fn decrement_depth(parser : Parser) -> Parser {
  { ..parser, depth: parser.depth - 1 }
}

///|
/// Check if recursion depth exceeds limit
fn check_depth(parser : Parser) -> Result[Parser, Parser] {
  if parser.depth > max_expression_depth {
    let loc = current_token(parser).location()
    Err(
      add_error(
        parser,
        "Expression too deeply nested (stack overflow prevention)",
        loc,
      ),
    )
  } else {
    Ok(parser)
  }
}

///|
/// Check if at end of tokens
fn is_at_end(parser : Parser) -> Bool {
  match current_token(parser) {
    EOF(_) => true
    _ => false
  }
}

///|
/// Expect a specific token
fn expect(
  parser : Parser,
  predicate : (Token) -> Bool,
) -> Result[Parser, Parser] {
  if predicate(current_token(parser)) {
    Ok(parser)
  } else {
    Err(parser)
  }
}

///|
/// Expect semicolon (with ASI)
fn expect_semicolon(parser : Parser) -> Parser {
  match current_token(parser) {
    Semicolon(_) => advance_parser(parser)
    _ => parser // Automatic semicolon insertion
  }
}

///|
/// Add error to diagnostics
fn add_error(
  parser : Parser,
  message : String,
  location : SourceLocation,
) -> Parser {
  let diagnostic = Diagnostic::error(message, location, 1000)
  let diagnostics = parser.diagnostics
  diagnostics.push(diagnostic)
  { ..parser, diagnostics, }
}

///|
/// Skip to next statement (error recovery)
fn skip_to_next_statement(parser : Parser) -> Parser {
  let mut parser = parser
  while !is_at_end(parser) {
    match current_token(parser) {
      Semicolon(_) => return advance_parser(parser)
      CloseBrace(_) => return parser
      _ => parser = advance_parser(parser)
    }
  }
  parser
}

///|
/// Get binary operator from token
fn get_binary_operator(token : Token) -> BinaryOperator? {
  match token {
    Plus(_) => Some(BinaryOperator::Add)
    Minus(_) => Some(BinaryOperator::Subtract)
    Star(_) => Some(BinaryOperator::Multiply)
    Slash(_) => Some(BinaryOperator::Divide)
    Percent(_) => Some(BinaryOperator::Remainder)
    StarStar(_) => Some(BinaryOperator::Exponentiate)
    LessThan(_) => Some(BinaryOperator::LessThan)
    GreaterThan(_) => Some(BinaryOperator::GreaterThan)
    LessThanEquals(_) => Some(BinaryOperator::LessThanEquals)
    GreaterThanEquals(_) => Some(BinaryOperator::GreaterThanEquals)
    EqualsEquals(_) => Some(BinaryOperator::Equals)
    ExclamationEquals(_) => Some(BinaryOperator::NotEquals)
    EqualsEqualsEquals(_) => Some(BinaryOperator::StrictEquals)
    ExclamationEqualsEquals(_) => Some(BinaryOperator::StrictNotEquals)
    AmpersandAmpersand(_) => Some(BinaryOperator::LogicalAnd)
    BarBar(_) => Some(BinaryOperator::LogicalOr)
    QuestionQuestion(_) => Some(BinaryOperator::NullishCoalescing)
    Ampersand(_) => Some(BinaryOperator::BitwiseAnd)
    Bar(_) => Some(BinaryOperator::BitwiseOr)
    Caret(_) => Some(BinaryOperator::BitwiseXor)
    LessThanLessThan(_) => Some(BinaryOperator::LeftShift)
    GreaterThanGreaterThan(_) => Some(BinaryOperator::RightShift)
    GreaterThanGreaterThanGreaterThan(_) =>
      Some(BinaryOperator::UnsignedRightShift)
    KeywordIn(_) => Some(BinaryOperator::In)
    KeywordInstanceOf(_) => Some(BinaryOperator::InstanceOf)
    // Compound assignment operators
    PlusEquals(_) => Some(BinaryOperator::AddAssign)
    MinusEquals(_) => Some(BinaryOperator::SubtractAssign)
    StarEquals(_) => Some(BinaryOperator::MultiplyAssign)
    SlashEquals(_) => Some(BinaryOperator::DivideAssign)
    PercentEquals(_) => Some(BinaryOperator::RemainderAssign)
    AmpersandEquals(_) => Some(BinaryOperator::BitwiseAndAssign)
    BarEquals(_) => Some(BinaryOperator::BitwiseOrAssign)
    CaretEquals(_) => Some(BinaryOperator::BitwiseXorAssign)
    StarStarEquals(_) => Some(BinaryOperator::ExponentiateAssign)
    LessThanLessThanEquals(_) => Some(BinaryOperator::LeftShiftAssign)
    GreaterThanGreaterThanEquals(_) => Some(BinaryOperator::RightShiftAssign)
    GreaterThanGreaterThanGreaterThanEquals(_) =>
      Some(BinaryOperator::UnsignedRightShiftAssign)
    AmpersandAmpersandEquals(_) => Some(BinaryOperator::LogicalAndAssign)
    BarBarEquals(_) => Some(BinaryOperator::LogicalOrAssign)
    QuestionQuestionEquals(_) => Some(BinaryOperator::NullishCoalescingAssign)
    // Note: Comma operator is context-sensitive and handled separately in parenthesized expressions
    _ => None
  }
}

///|
/// Get unary operator from token
fn get_unary_operator(token : Token) -> UnaryOperator? {
  match token {
    Plus(_) => Some(UnaryOperator::Plus)
    Minus(_) => Some(UnaryOperator::Minus)
    Exclamation(_) => Some(UnaryOperator::LogicalNot)
    Tilde(_) => Some(UnaryOperator::BitwiseNot)
    PlusPlus(_) => Some(UnaryOperator::Increment)
    MinusMinus(_) => Some(UnaryOperator::Decrement)
    KeywordTypeOf(_) => Some(UnaryOperator::TypeOf)
    KeywordVoid(_) => Some(UnaryOperator::Void)
    KeywordDelete(_) => Some(UnaryOperator::Delete)
    _ => None
  }
}

///|
/// Get operator precedence
fn get_precedence(op : BinaryOperator) -> Int {
  match op {
    BinaryOperator::Comma => 1
    BinaryOperator::LogicalOr => 3
    BinaryOperator::LogicalAnd => 4
    BinaryOperator::BitwiseOr => 5
    BinaryOperator::BitwiseXor => 6
    BinaryOperator::BitwiseAnd => 7
    BinaryOperator::Equals
    | BinaryOperator::NotEquals
    | BinaryOperator::StrictEquals
    | BinaryOperator::StrictNotEquals => 8
    BinaryOperator::LessThan
    | BinaryOperator::GreaterThan
    | BinaryOperator::LessThanEquals
    | BinaryOperator::GreaterThanEquals
    | BinaryOperator::In
    | BinaryOperator::InstanceOf => 9
    BinaryOperator::LeftShift
    | BinaryOperator::RightShift
    | BinaryOperator::UnsignedRightShift => 10
    BinaryOperator::Add | BinaryOperator::Subtract => 11
    BinaryOperator::Multiply
    | BinaryOperator::Divide
    | BinaryOperator::Remainder => 12
    BinaryOperator::Exponentiate => 13
    BinaryOperator::NullishCoalescing => 2
    _ => 0
  }
}

// Token matching helpers

///|
fn matches_open_paren(token : Token) -> Bool {
  match token {
    OpenParen(_) => true
    _ => false
  }
}

///|
fn matches_close_paren(token : Token) -> Bool {
  match token {
    CloseParen(_) => true
    _ => false
  }
}

///|
fn matches_open_brace(token : Token) -> Bool {
  match token {
    OpenBrace(_) => true
    _ => false
  }
}

///|
fn matches_close_brace(token : Token) -> Bool {
  match token {
    CloseBrace(_) => true
    _ => false
  }
}

///|
fn matches_close_bracket(token : Token) -> Bool {
  match token {
    CloseBracket(_) => true
    _ => false
  }
}

///|
fn matches_colon(token : Token) -> Bool {
  match token {
    Colon(_) => true
    _ => false
  }
}

///|
fn matches_arrow(token : Token) -> Bool {
  match token {
    Arrow(_) => true
    _ => false
  }
}
