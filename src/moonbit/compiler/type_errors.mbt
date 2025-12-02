// Type Error System - Rich Error Types and Formatting
// Provides detailed error messages with path tracking and suggestions
// Inspired by Elm's friendly compiler and Rust's helpful diagnostics

// ============================================================================
// Documentation Links - TypeScript Error Reference
// ============================================================================

///|
/// Get the documentation URL for a TypeScript error code
pub fn get_error_doc_url(code : Int) -> String {
  "https://typescript.tv/errors/#TS" + code.to_string()
}

///|
/// Get the TypeScript handbook URL for common topics
pub fn get_handbook_url(topic : String) -> String {
  "https://www.typescriptlang.org/docs/handbook/" + topic + ".html"
}

// ============================================================================
// Detailed Error Structure - Elm/Rust Inspired
// ============================================================================

///|
/// A detailed, user-friendly error message inspired by Elm and Rust compilers.
///
/// Elm's philosophy: "Compiler errors should be a dialogue, not a wall of text"
/// Rust's philosophy: "Every error should tell you what, where, why, and how to fix"
pub struct DetailedError {
  /// The main error title (short, actionable)
  title : String
  /// Error code for lookup (e.g., TS2322)
  code : Int
  /// Where the error occurred (file, line, column)
  location : String
  /// The problematic code snippet with highlighting
  code_snippet : String
  /// What went wrong - clear explanation of the issue
  what_went_wrong : String
  /// Why this is an error - educational context
  why_error : String
  /// How to fix it - actionable suggestions with examples
  how_to_fix : Array[String]
  /// Link to documentation
  doc_link : String
  /// Related errors (for complex type mismatches)
  related : Array[DetailedError]
} derive(Show)

///|
/// Rich error type with path tracking, nested errors, and suggestions
pub struct TypeMismatchError {
  path : TypePath
  expected : TypeV2
  actual : TypeV2
  reason : MismatchReason
  children : Array[TypeMismatchError]
  suggestions : Array[String]
} derive(Show)

///|
/// Specific reason for type mismatch
pub enum MismatchReason {
  // Basic mismatches
  IncompatibleTypes
  MissingProperty(String)
  ExcessProperty(String)
  PropertyTypeMismatch(String)

  // Function mismatches
  ParamCountMismatch(Int, Int) // expected, actual
  ParamTypeMismatch(Int, String) // index, name
  ReturnTypeMismatch

  // Union/intersection
  NoUnionMemberMatches
  IntersectionNotSatisfied(Int)

  // Generics
  TypeArgMismatch(String, Int) // param_name, index
  ConstraintNotSatisfied(String, TypeV2) // param_name, constraint
  CannotInfer(String) // type param name

  // Object specifics
  ReadonlyMutation(String)
  OptionalToRequired(String)
  IndexSignatureMismatch

  // Literal types
  LiteralMismatch(String, String) // expected_literal, actual_literal
  LiteralToWide // literal being assigned to wide type

  // Special
  CircularReference
  ExcessiveDepth
  NotCallable
  NotConstructable
  UnboundVariable(String)
  UnboundType(String)

  // Overloads
  NoOverloadMatches(Int) // number of overloads tried
  OverloadCandidateFailed(Int) // index of failed overload
  OverloadNotCompatibleWithImpl(Int) // TS2394: overload index not compatible with implementation
  OverloadMissingImplementation(String) // TS2391: function name missing implementation
  OverloadAmbientMismatch(String) // TS2383: ambient/non-ambient mismatch

  // Class/OOP
  PrivateMemberAccess(String, String) // member_name, declared_in_class
  ProtectedMemberAccess(String, String) // member_name, declared_in_class
  AbstractClassInstantiation(String) // class_name
  AbstractMemberNotImplemented(String, String) // member_name, base_class
  OverrideReturnTypeMismatch(String, String) // method_name, base_class
  OverrideParamCountMismatch(String, Int, Int) // method_name, base_required, derived_required
  OverrideParamTypeMismatch(String, Int, String) // method_name, param_index, param_name
  OverrideAccessibilityMismatch(String, String, String) // member_name, base_accessibility, derived_accessibility

  // Super call validation (TS17009, TS2337)
  ThisBeforeSuperCall // TS17009: 'super' must be called before accessing 'this'
  SuperCallRequired(String) // TS2377: Constructors for derived classes must contain a 'super' call
  SuperCallOutsideConstructor // TS2337: 'super' can only be called in a constructor
  SuperPropertyOutsideClass // TS2335: 'super' can only be referenced in a derived class
  SuperCallInStaticMethod // Super call in static method
  SuperPropertyAccess(String) // TS2339: Property does not exist on type 'super'

  // BigInt errors (TS2365, TS2736)
  BigIntNumberMixing(String) // TS2365: Operator cannot be applied to bigint and number
  UnaryPlusBigInt // TS2736: Operator '+' cannot be applied to type 'bigint'

  // Module/Import resolution errors
  FileIsNotModule(String) // TS2306: File '{0}' is not a module
  CannotFindModule(String) // TS2307: Cannot find module '{0}'
  CannotFindGlobalType(String) // TS2318: Cannot find global type '{0}'
  ImportPathCannotEndWithExtension(String, String) // TS2691: Import path '{0}' cannot end with '{1}' extension
  CannotFindModuleOrTypeDeclarations(String) // TS2692: Cannot find module '{0}' or its corresponding type declarations
  NamespaceHasNoExportedMember(String, String) // TS2694: Namespace '{0}' has no exported member '{1}'
  CannotUseNamespaceAsType(String) // TS2709: Cannot use namespace '{0}' as a type
  CannotUseNamespaceAsValue(String) // TS2710: Cannot use namespace '{0}' as a value
  CannotFindModuleSetModuleResolution(String) // TS2766: Cannot find module '{0}'. Did you mean to set 'moduleResolution' to 'node'?
  ModuleHasNoExportedMember(String, String) // TS2305: Module '{0}' has no exported member '{1}'

  // Type Assignment & Compatibility errors
  InterfaceCannotExtendTypes(String, Array[String]) // TS2320: Interface '{0}' cannot simultaneously extend types '{1}'
  PropertyMissingInType(String, String) // TS2324: Property '{0}' is missing in type '{1}'
  ParamTypesIncompatible(String, String, String) // TS2326: Types of parameters '{0}' and '{1}' are incompatible
  PropertyTypesIncompatible(String, String, String) // TS2328: Types of property '{0}' are incompatible between '{1}' and '{2}'
  IndexSignatureMissing(String, String) // TS2329: Index signature is missing in type '{0}' (expected from '{1}')
  ThisInStaticProperty(String) // TS2334: 'this' cannot be referenced in a static property initializer
  TypeDoesNotSatisfyConstraint(String, String) // TS2344: Type '{0}' does not satisfy the constraint '{1}'
  ValueNoPropertiesInCommon(String, String) // TS2348: Value of type '{0}' has no properties in common with type '{1}'
  OnlyVoidFunctionCanBeCalledWithNew(String) // TS2350: Only a void function can be called with the 'new' keyword
  ConversionMayBeMistake(String, String) // TS2352: Conversion of type '{0}' to type '{1}' may be a mistake
  TypeCannotBeAssignedToType(String, String) // TS2717: Type '{0}' is not assignable to type '{1}'
  TypeMissingPropertiesFromType(String, String, Array[String]) // TS2739: Type '{0}' is missing the following properties from type '{1}': {2}
  TypeMissingPropertiesAndMore(String, String, Array[String], Int) // TS2740: Type '{0}' is missing properties from type '{1}': {2} and {3} more
  TypeDoesNotSatisfyConstraintAlt(String, String) // TS2744: Type '{0}' does not satisfy constraint '{1}'
  TypeNotAssignableSameNameDifferentTypes(String, String, String) // TS2752: Type '{0}' is not assignable to type '{1}'. Two different types with this name exist, but they are unrelated.
  TypeNotAssignableGeneric(String, String) // TS2757: Type '{0}' is not assignable to type '{1}'
  PropertyTypesIncompatibleAlt(String, String, String) // TS2758: Types of property '{0}' are incompatible

  // Operator & Expression errors
  InstanceofLeftNotObject(String) // TS2358: The left-hand side of an 'instanceof' expression must be of type 'any', an object type or a type parameter
  InstanceofRightNotFunction(String) // TS2359: The right-hand side of an 'instanceof' expression must be of type 'any' or of a type assignable to the 'Function' interface type
  ConditionAlwaysSameValue(String, String) // TS2367: This condition will always return '{0}' since the types '{1}' have no overlap
  LeftSideCommaUnused(String) // TS2695: Left side of comma operator is unused and has no side effects
  CannotUseInOperator(String, String) // TS2772: The right-hand side of an 'in' expression must be an object type, not '{0}'
  ConditionAlwaysTrueFunction(String) // TS2773: This condition will always return true since this function is always defined. Did you mean to call it instead?
  ConditionAlwaysTrue(String) // TS2774: This condition will always return true since this '{0}' is always defined
  OperatorCannotBeApplied(String, String, String) // TS2800: Operator '{0}' cannot be applied to types '{1}' and '{2}'
  BigIntLiteralsNotAvailable // TS2737: BigInt literals are not available when targeting lower than ES2020

  // Function & Parameter errors
  TypeParamNameCannotBe(String) // TS2368: Type parameter name cannot be '{0}'
  ParamPropertyOnlyInConstructor(String) // TS2369: A parameter property is only allowed in a constructor implementation
  RestParamMustBeArray // TS2370: A rest parameter must be of an array type
  ParamInitializerOnlyInFunctionOrConstructor(String) // TS2371: A parameter initializer is only allowed in a function or constructor implementation
  ParamCannotReferenceSelf(String) // TS2372: Parameter '{0}' cannot reference itself
  OverloadSignaturesAmbientMismatch(String) // TS2383: Overload signatures must all be ambient or non-ambient
  FunctionOverloadMustNotBeStatic(String) // TS2388: Function overload must not be static
  FunctionImplSignatureNotAssignable(String) // TS2389: The signature of the function implementation is not assignable to the overload signature
  ConstructorImplMissing(String) // TS2390: Constructor implementation is missing
  IndividualDeclarationsMustMatch(String, String) // TS2395: Individual declarations in merged declaration '{0}' must be all exported or all local
  RequiredTypeParamAfterOptional(String) // TS2706: Required type parameters may not follow optional type parameters
  GenericTypeRequiresTypeArgs(String, Int, Int) // TS2707: Generic type '{0}' requires between {1} and {2} type arguments

  // For-in/For-of errors
  ForInLeftMustBeVariable(String) // TS2406: The left-hand side of a 'for...in' statement must be a variable or a property access
  ForInRightMustBeObject(String) // TS2407: The right-hand side of a 'for...in' statement must be of type 'any', an object type or a type parameter
  ForOfLeftMustBeVariable(String) // TS2487: The left-hand side of a 'for...of' statement must be a variable or a property access

  // Property & Index errors
  TypeHasNoPropertyAndNoStringIndex(String, String) // TS2459: Type '{0}' has no property '{1}' and no string index signature
  TypeIsNotArrayType(String) // TS2460: Type '{0}' is not an array type
  TypeCannotBeUsedAsIndex(String) // TS2538: Type '{0}' cannot be used as an index type
  IndexSignatureOnlyPermitsReading(String) // TS2542: Index signature in type '{0}' only permits reading
  IndexSignatureParamTypeMustBe(String) // TS2716: An index signature parameter type must be 'string', 'number', 'symbol', or a template literal type
  PropertyUsedBeforeInit(String) // TS2729: Property '{0}' is used before being assigned
  PropertyIncompatibleWithIndexSig(String, String, String) // TS2745: Property '{0}' of type '{1}' is not assignable to '{2}' index type '{3}'
  PropertyHasConflictingDeclarations(String) // TS2746: Property '{0}' has conflicting declarations and is inaccessible in type
  NewExprTargetLacksConstructSig(String) // TS2747: 'new' expression, whose target lacks a construct signature, implicitly has an 'any' type
  CannotAccessBeforeInit(String) // TS2748: '{0}' cannot be accessed before initialization
  PropertyCanOnlyBeAssignedWithThis(String) // TS2810: Property '{0}' can only be assigned using 'this' access

  // Array & Iteration errors
  TypeNotArrayOrString(String) // TS2548: Type '{0}' is not an array type or a string type
  TypeNotArrayOrStringDownlevel(String) // TS2549: Type '{0}' is not an array type or a string type. Use compiler option '--downlevelIteration'
  PropertyDoesNotExistDidYouMean(String, String, String) // TS2551: Property '{0}' does not exist on type '{1}'. Did you mean '{2}'?
  CannotFindNameDidYouMean(String, String) // TS2552: Cannot find name '{0}'. Did you mean '{1}'?
  ExpectedNArgsButGotMore(Int, Int) // TS2557: Expected at least {0} arguments, but got {1}
  RestElementTypeMustBeArray(String) // TS2574: A rest element type must be an array type
  NoOverloadExpectsNArgs(Int) // TS2575: No overload expects {0} arguments
  TypeCanOnlyBeIteratedWithDownlevel(String) // TS2802: Type '{0}' can only be iterated through when using '--downlevelIteration'

  // Spread & Rest errors
  PropertyUsedBeforeAssigned(String) // TS2565: Property '{0}' is used before being assigned
  RestElementCannotContainBindingPattern // TS2566: A rest element cannot contain a binding pattern
  RestTypesMustBeFromObjectTypes(String) // TS2700: Rest types may only be created from object types
  ObjectRestAssignmentMustBeVariable(String) // TS2701: The target of an object rest assignment must be a variable or a property access
  ObjectRestAssignmentNotOptional(String) // TS2702: A rest element cannot have a property name and cannot be optional
  SpreadTypesMustBeFromObjectTypes(String) // TS2762: Spread types may only be created from object types

  // Async/Generator/Yield errors
  YieldExpressionImplicitlyAny // TS2764: 'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation
  YieldOperandTypeInAsyncGenerator(String, String) // TS2770: Type of 'yield' operand in an async generator must either be a valid promise or must not contain a callable 'then' member
  TypeReferencedInThenMethod(String) // TS2771: Type '{0}' referenced when attempting to get type of 'then' method in a promise

  // Enum & Catch Clause errors
  CatchClauseVariableMustBeAnyOrUnknown(String) // TS2467: Catch clause variable type annotation must be 'any' or 'unknown' if specified
  ConstEnumUsageRestriction(String) // TS2475: A const enum member can only be accessed using a string literal
  ConstEnumMemberAccessRestriction(String) // TS2476: A const enum member can only be accessed using a string literal
  UsingPrivateName(String, String) // TS2494: Using private name '{0}' as the type of '{1}'
  MemberInitializerForwardReference(String, String) // TS2651: A member initializer in a enum declaration cannot reference members declared after it, including members defined in other enums

  // Module & Export errors
  ExportDeclarationConflicts(String, String) // TS2484: Export declaration conflicts with exported declaration of '{0}'
  ArgumentsObjectCannotBeReferenced(String) // TS2496: The 'arguments' object cannot be referenced in an arrow function
  ModuleCanOnlyBeReferencedWithESImport(String) // TS2497: Module '{0}' can only be referenced with a default import when using esModuleInterop
  ReferencedInOwnBaseExpression(String) // TS2502: '{0}' is referenced directly or indirectly in its own base expression
  InferredTypeReferencesInaccessible(String, String) // TS2527: The inferred type of '{0}' references an inaccessible '{1}' type
  CannotAugmentModule(String) // TS2649: Cannot augment module '{0}' with value exports because it resolves to a non-module entity
  RefersToUMDGlobal(String) // TS2686: '{0}' refers to a UMD global, but the current file is a module
  DeclarationsMustHaveIdenticalModifiers(String) // TS2687: All declarations of '{0}' must have identical modifiers
  CannotFindTypeDefinitionFile(String) // TS2688: Cannot find type definition file for '{0}'

  // Type Complexity & Inference errors
  PropertyIsStaticMemberOfType(String, String) // TS2576: Property '{0}' is a static member of type '{1}'
  UnusedTsExpectErrorDirective // TS2578: Unused '@ts-expect-error' directive
  CannotFindNameTestRunner(String) // TS2579: Cannot find name '{0}'. Do you need to install type definitions for a test runner?
  CannotFindNameTargetLibrary(String, String) // TS2580: Cannot find name '{0}'. Do you need to change your target library?
  CannotFindNameTargetLibraryAlt(String, String) // TS2584: Cannot find name '{0}'. Do you need to change your target library?
  ExpressionProducesUnionTooComplex // TS2590: Expression produces a union type that is too complex to represent
  CannotImportTypeDeclarationFiles(String) // TS2591: Cannot import type declaration files. Consider importing '{0}' instead
  InferredTypeCannotBeNamed(String, String) // TS2742: The inferred type of '{0}' cannot be named without a reference to '{1}'
} derive(Show, Eq)

// ============================================================================
// Error Construction Helpers
// ============================================================================

///|
/// Create a basic type mismatch error
pub fn type_mismatch(
  path : TypePath,
  actual : TypeV2,
  expected : TypeV2,
) -> TypeMismatchError {
  {
    path,
    expected,
    actual,
    reason: IncompatibleTypes,
    children: [],
    suggestions: generate_suggestions(actual, expected),
  }
}

///|
/// Create an error with specific reason
pub fn type_mismatch_with_reason(
  path : TypePath,
  actual : TypeV2,
  expected : TypeV2,
  reason : MismatchReason,
) -> TypeMismatchError {
  {
    path,
    expected,
    actual,
    reason,
    children: [],
    suggestions: generate_suggestions(actual, expected),
  }
}

///|
/// Create a missing property error
pub fn missing_property_error(
  path : TypePath,
  prop_name : String,
  suggestions : Array[String],
) -> TypeMismatchError {
  {
    path,
    expected: TObject(ObjectTypeV2::empty()),
    actual: TUndefined,
    reason: MissingProperty(prop_name),
    children: [],
    suggestions,
  }
}

///|
/// Create an excess property error
pub fn excess_property_error(
  path : TypePath,
  prop_name : String,
) -> TypeMismatchError {
  {
    path,
    expected: TObject(ObjectTypeV2::empty()),
    actual: TObject(ObjectTypeV2::empty()),
    reason: ExcessProperty(prop_name),
    children: [],
    suggestions: [
      "Object literal may only specify known properties", "Consider using a type assertion or adding an index signature",
    ],
  }
}

///|
/// Create a property type mismatch error
pub fn property_mismatch_error(
  prop_name : String,
  child_error : TypeMismatchError,
) -> TypeMismatchError {
  {
    path: child_error.path,
    expected: child_error.expected,
    actual: child_error.actual,
    reason: PropertyTypeMismatch(prop_name),
    children: [child_error],
    suggestions: [],
  }
}

///|
/// Create a param count mismatch error
pub fn param_count_mismatch(
  path : TypePath,
  expected : Int,
  actual : Int,
) -> TypeMismatchError {
  {
    path,
    expected: TFunction(FunctionTypeV2::any()),
    actual: TFunction(FunctionTypeV2::any()),
    reason: ParamCountMismatch(expected, actual),
    children: [],
    suggestions: [
      "Target accepts " +
      expected.to_string() +
      " argument(s), but source requires " +
      actual.to_string(),
    ],
  }
}

///|
/// Create a param type mismatch error
pub fn param_type_mismatch_error(
  path : TypePath,
  index : Int,
  name : String,
  actual : TypeV2,
  expected : TypeV2,
) -> TypeMismatchError {
  {
    path,
    expected,
    actual,
    reason: ParamTypeMismatch(index, name),
    children: [],
    suggestions: [],
  }
}

///|
/// Create a return type mismatch error
pub fn return_type_mismatch_error(
  path : TypePath,
  actual : TypeV2,
  expected : TypeV2,
) -> TypeMismatchError {
  {
    path,
    expected,
    actual,
    reason: ReturnTypeMismatch,
    children: [],
    suggestions: [],
  }
}

///|
/// Create a literal mismatch error
pub fn literal_mismatch_error(
  path : TypePath,
  expected_literal : String,
  actual_literal : String,
) -> TypeMismatchError {
  {
    path,
    expected: TLiteralString(expected_literal),
    actual: TLiteralString(actual_literal),
    reason: LiteralMismatch(expected_literal, actual_literal),
    children: [],
    suggestions: ["Did you mean to use the base type instead of a literal?"],
  }
}

///|
/// Create a no union member matches error
pub fn no_union_member_matches_error(
  path : TypePath,
  actual : TypeV2,
  members : Array[TypeV2],
) -> TypeMismatchError {
  {
    path,
    expected: make_union(members),
    actual,
    reason: NoUnionMemberMatches,
    children: [],
    suggestions: find_closest_union_member(actual, members),
  }
}

///|
/// Create an unbound variable error
pub fn unbound_variable_error(name : String) -> TypeMismatchError {
  {
    path: PRoot,
    expected: TAny,
    actual: TError,
    reason: UnboundVariable(name),
    children: [],
    suggestions: [],
  }
}

///|
/// Create an unbound type error
pub fn unbound_type_error(name : String) -> TypeMismatchError {
  {
    path: PRoot,
    expected: TAny,
    actual: TError,
    reason: UnboundType(name),
    children: [],
    suggestions: [],
  }
}

///|
/// Create a not callable error
pub fn not_callable_error(
  path : TypePath,
  actual : TypeV2,
) -> TypeMismatchError {
  {
    path,
    expected: TFunction(FunctionTypeV2::any()),
    actual,
    reason: NotCallable,
    children: [],
    suggestions: ["This type is not callable. Did you mean to access a method?"],
  }
}

///|
/// Aggregate multiple errors into one
pub fn aggregate_errors(
  path : TypePath,
  actual : TypeV2,
  expected : TypeV2,
  errors : Array[TypeMismatchError],
) -> TypeMismatchError {
  let reason = if errors.length() > 0 {
    errors[0].reason
  } else {
    IncompatibleTypes
  }
  { path, expected, actual, reason, children: errors, suggestions: [] }
}

// ============================================================================
// BigInt Type Errors (TS2365, TS2736)
// ============================================================================

///|
/// Create an error for BigInt/number mixing in arithmetic operations (TS2365)
pub fn bigint_number_mixing_error(
  operator : String,
  left_type : TypeV2,
  right_type : TypeV2,
) -> TypeMismatchError {
  {
    path: PRoot,
    expected: TBigInt, // or TNumber depending on context
    actual: make_union([left_type, right_type]),
    reason: BigIntNumberMixing(operator),
    children: [],
    suggestions: [
      "Convert one operand to match the other type", "Use BigInt(n) to convert number to bigint",
      "Use Number(n) to convert bigint to number (may lose precision)",
    ],
  }
}

///|
/// Create an error for unary + on bigint (TS2736)
pub fn unary_plus_bigint_error() -> TypeMismatchError {
  {
    path: PRoot,
    expected: TNumber,
    actual: TBigInt,
    reason: UnaryPlusBigInt,
    children: [],
    suggestions: [
      "Unary '+' cannot be applied to bigint", "Use Number(value) if you need to convert to number",
      "Use 0n + value or just value for bigint",
    ],
  }
}

// ============================================================================
// Error Formatting
// ============================================================================

///|
/// Format error to human-readable string
pub fn format_type_error(error : TypeMismatchError, depth : Int) -> String {
  let indent = make_indent(depth)
  let mut output = ""

  // Main error message
  output = output +
    indent +
    "Type '" +
    format_type_v2(error.actual) +
    "' is not assignable to type '" +
    format_type_v2(error.expected) +
    "'\n"

  // Path information
  if not(error.path.is_root()) {
    output = output + indent + "  at: " + error.path.to_string() + "\n"
  }

  // Specific reason
  match error.reason {
    MissingProperty(name) =>
      output = output +
        indent +
        "  Property '" +
        name +
        "' is missing in type '" +
        format_type_v2(error.actual) +
        "'\n"
    ExcessProperty(name) =>
      output = output +
        indent +
        "  Object literal may only specify known properties, and '" +
        name +
        "' does not exist in type '" +
        format_type_v2(error.expected) +
        "'\n"
    PropertyTypeMismatch(name) =>
      output = output +
        indent +
        "  Types of property '" +
        name +
        "' are incompatible:\n"
    ParamCountMismatch(expected, actual) =>
      output = output +
        indent +
        "  Target signature has " +
        expected.to_string() +
        " parameter(s), source has " +
        actual.to_string() +
        "\n"
    ParamTypeMismatch(index, name) =>
      output = output +
        indent +
        "  Type of parameter '" +
        name +
        "' (at index " +
        index.to_string() +
        ") is incompatible:\n"
    ReturnTypeMismatch =>
      output = output + indent + "  Return types are incompatible:\n"
    NoUnionMemberMatches =>
      output = output +
        indent +
        "  Type is not assignable to any member of the union\n"
    TypeArgMismatch(param_name, index) =>
      output = output +
        indent +
        "  Type argument '" +
        param_name +
        "' (at position " +
        index.to_string() +
        ") is incompatible:\n"
    ConstraintNotSatisfied(param_name, constraint) =>
      output = output +
        indent +
        "  Type '" +
        format_type_v2(error.actual) +
        "' does not satisfy constraint '" +
        format_type_v2(constraint) +
        "' for type parameter '" +
        param_name +
        "'\n"
    OptionalToRequired(name) =>
      output = output +
        indent +
        "  Property '" +
        name +
        "' is optional in source but required in target\n"
    ReadonlyMutation(name) =>
      output = output +
        indent +
        "  Cannot assign to '" +
        name +
        "' because it is a read-only property\n"
    NotCallable => output = output + indent + "  This type is not callable\n"
    UnboundVariable(name) =>
      output = output + indent + "  Cannot find name '" + name + "' in scope\n"
    UnboundType(name) =>
      output = output + indent + "  Cannot find type '" + name + "' in scope\n"
    LiteralMismatch(expected, actual) =>
      output = output +
        indent +
        "  Literal '" +
        actual +
        "' is not assignable to literal '" +
        expected +
        "'\n"
    NoOverloadMatches(count) =>
      output = output +
        indent +
        "  No overload matches this call. Tried " +
        count.to_string() +
        " overload(s).\n"
    OverloadCandidateFailed(index) =>
      output = output +
        indent +
        "  Overload " +
        index.to_string() +
        " gave the following error:\n"
    _ => ()
  }

  // Child errors (nested mismatches) - limit depth
  if error.children.length() > 0 && depth < 5 {
    for child in error.children {
      output = output + format_type_error(child, depth + 1)
    }
  }

  // Suggestions
  for suggestion in error.suggestions {
    output = output + indent + "  [Suggestion] " + suggestion + "\n"
  }
  output
}

///|
/// Create indentation string
fn make_indent(depth : Int) -> String {
  let mut result = ""
  for _ in 0..<depth {
    result = result + "  "
  }
  result
}

// ============================================================================
// Suggestion Generation
// ============================================================================

///|
/// Generate suggestions based on type mismatch
fn generate_suggestions(actual : TypeV2, expected : TypeV2) -> Array[String] {
  let suggestions : Array[String] = []
  match (actual, expected) {
    // String vs string literal
    (TString, TLiteralString(s)) =>
      suggestions.push(
        "Consider using 'as const' or a type assertion: value as \"" + s + "\"",
      )

    // null/undefined issues
    (TNull, t) =>
      if t != TNull {
        suggestions.push(
          "Value might be null. Consider optional chaining (?.) or null check",
        )
      }
    (TUndefined, t) =>
      if t != TUndefined {
        suggestions.push(
          "Value might be undefined. Add a check or use nullish coalescing (??)",
        )
      }
    (TUnion(types), _) =>
      if types
        .iter()
        .any(fn(t) {
          match t {
            TNull | TUndefined => true
            _ => false
          }
        }) {
        suggestions.push(
          "Type includes null/undefined. Use non-null assertion (!) if you're sure, or add a null check",
        )
      }

    // Promise issues
    (TGenericInstance(name, inner), target) =>
      if name == "Promise" && inner.length() > 0 {
        // Could check if inner type matches expected
        suggestions.push("Did you forget to await a Promise?")
      }

    // Array vs element
    (TArray(_), _) =>
      suggestions.push(
        "Did you mean to access an array element? Try [0] or use array methods",
      )
    (_, TArray(_)) =>
      suggestions.push(
        "Expected an array but got a single value. Wrap in array: [value]",
      )

    // Object vs function
    (TObject(_), TFunction(_)) =>
      suggestions.push(
        "Object is not callable. Did you mean to access a method?",
      )
    _ => ()
  }
  suggestions
}

///|
/// Find the closest matching union member to suggest
fn find_closest_union_member(
  actual : TypeV2,
  members : Array[TypeV2],
) -> Array[String] {
  let suggestions : Array[String] = []

  // Simple heuristic: if actual is one of the primitive types, suggest similar
  match actual {
    TNumber | TLiteralNumber(_) =>
      if members
        .iter()
        .any(fn(m) {
          match m {
            TString | TLiteralString(_) => true
            _ => false
          }
        }) {
        suggestions.push("Did you mean to convert to string? Use .toString()")
      }
    TString | TLiteralString(_) =>
      if members
        .iter()
        .any(fn(m) {
          match m {
            TNumber | TLiteralNumber(_) => true
            _ => false
          }
        }) {
        suggestions.push(
          "Did you mean to parse as number? Use parseInt() or parseFloat()",
        )
      }
    _ => ()
  }
  suggestions
}

///|
/// Find similar property names for "did you mean" suggestions
pub fn find_similar_properties(
  target : String,
  available : Array[String],
) -> Array[String] {
  let similar : Array[String] = []
  for prop in available {
    let dist = levenshtein_distance(prop, target)
    if dist <= 2 {
      similar.push(prop)
    }
    if similar.length() >= 3 {
      break
    }
  }
  if similar.is_empty() {
    []
  } else {
    ["Did you mean: " + similar.join(", ") + "?"]
  }
}

///|
/// Helper to get minimum of two integers
fn min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// Simple Levenshtein distance for typo detection
fn levenshtein_distance(a : String, b : String) -> Int {
  let m = a.length()
  let n = b.length()
  if m == 0 {
    return n
  }
  if n == 0 {
    return m
  }

  // Simple O(n*m) implementation
  let prev : Array[Int] = Array::make(n + 1, 0)
  let curr : Array[Int] = Array::make(n + 1, 0)

  // Initialize first row
  for j in 0..<(n + 1) {
    prev[j] = j
  }

  // Fill the matrix
  for i in 1..<(m + 1) {
    curr[0] = i
    for j in 1..<(n + 1) {
      let cost = if a[i - 1] == b[j - 1] { 0 } else { 1 }
      let del = prev[j] + 1
      let ins = curr[j - 1] + 1
      let sub = prev[j - 1] + cost
      curr[j] = min_int(del, min_int(ins, sub))
    }
    // Swap prev and curr
    for k in 0..<(n + 1) {
      let tmp = prev[k]
      prev[k] = curr[k]
      curr[k] = tmp
    }
  }
  prev[n]
}

// ============================================================================
// Elm/Rust-Inspired Error Explanations
// ============================================================================

///|
/// Get a friendly error title based on the mismatch reason (Elm-style)
pub fn get_friendly_title(reason : MismatchReason) -> String {
  match reason {
    IncompatibleTypes => "TYPE MISMATCH"
    MissingProperty(name) => "MISSING PROPERTY '" + name + "'"
    ExcessProperty(name) => "UNEXPECTED PROPERTY '" + name + "'"
    PropertyTypeMismatch(name) => "WRONG TYPE FOR '" + name + "'"
    ParamCountMismatch(_, _) => "WRONG NUMBER OF ARGUMENTS"
    ParamTypeMismatch(_, name) => "WRONG TYPE FOR PARAMETER '" + name + "'"
    ReturnTypeMismatch => "RETURN TYPE MISMATCH"
    NoUnionMemberMatches => "NO MATCHING UNION MEMBER"
    TypeArgMismatch(name, _) => "TYPE ARGUMENT MISMATCH: " + name
    ConstraintNotSatisfied(name, _) => "CONSTRAINT NOT SATISFIED: " + name
    CannotInfer(name) => "CANNOT INFER TYPE: " + name
    ReadonlyMutation(name) => "CANNOT MODIFY READONLY '" + name + "'"
    OptionalToRequired(name) => "OPTIONAL VS REQUIRED: '" + name + "'"
    IndexSignatureMismatch => "INDEX SIGNATURE MISMATCH"
    LiteralMismatch(_, _) => "LITERAL TYPE MISMATCH"
    LiteralToWide => "LITERAL TYPE TOO WIDE"
    CircularReference => "CIRCULAR TYPE REFERENCE"
    ExcessiveDepth => "TYPE TOO DEEPLY NESTED"
    NotCallable => "TYPE IS NOT CALLABLE"
    NotConstructable => "TYPE IS NOT CONSTRUCTABLE"
    UnboundVariable(name) => "CANNOT FIND NAME '" + name + "'"
    UnboundType(name) => "CANNOT FIND TYPE '" + name + "'"
    IntersectionNotSatisfied(_) => "INTERSECTION TYPE NOT SATISFIED"
    NoOverloadMatches(count) =>
      "NO OVERLOAD MATCHES (" + count.to_string() + " tried)"
    OverloadCandidateFailed(index) =>
      "OVERLOAD " + index.to_string() + " FAILED"
    OverloadNotCompatibleWithImpl(index) =>
      "OVERLOAD " + index.to_string() + " NOT COMPATIBLE WITH IMPLEMENTATION"
    OverloadMissingImplementation(name) =>
      "FUNCTION '" + name + "' MISSING IMPLEMENTATION"
    OverloadAmbientMismatch(name) =>
      "OVERLOAD AMBIENT MISMATCH FOR '" + name + "'"
    PrivateMemberAccess(name, _) => "PRIVATE MEMBER '" + name + "'"
    ProtectedMemberAccess(name, _) => "PROTECTED MEMBER '" + name + "'"
    AbstractClassInstantiation(name) =>
      "CANNOT INSTANTIATE ABSTRACT CLASS '" + name + "'"
    AbstractMemberNotImplemented(name, _) =>
      "ABSTRACT MEMBER '" + name + "' NOT IMPLEMENTED"
    OverrideReturnTypeMismatch(name, _) =>
      "OVERRIDE RETURN TYPE MISMATCH '" + name + "'"
    OverrideParamCountMismatch(name, _, _) =>
      "OVERRIDE PARAMETER COUNT MISMATCH '" + name + "'"
    OverrideParamTypeMismatch(name, _, _) =>
      "OVERRIDE PARAMETER TYPE MISMATCH '" + name + "'"
    OverrideAccessibilityMismatch(name, _, _) =>
      "OVERRIDE ACCESSIBILITY MISMATCH '" + name + "'"
    // Super call validation
    ThisBeforeSuperCall => "'THIS' BEFORE 'SUPER' CALL"
    SuperCallRequired(class_name) =>
      "MISSING 'SUPER' CALL IN '" + class_name + "'"
    SuperCallOutsideConstructor => "'SUPER' CALL OUTSIDE CONSTRUCTOR"
    SuperPropertyOutsideClass => "'SUPER' OUTSIDE DERIVED CLASS"
    SuperCallInStaticMethod => "'SUPER' CALL IN STATIC METHOD"
    SuperPropertyAccess(name) => "PROPERTY '" + name + "' NOT ON 'SUPER'"
    // BigInt errors
    BigIntNumberMixing(op) => "CANNOT MIX BIGINT AND NUMBER WITH '" + op + "'"
    UnaryPlusBigInt => "UNARY '+' CANNOT BE APPLIED TO BIGINT"
    // Module/Import resolution errors
    FileIsNotModule(file) => "FILE '" + file + "' IS NOT A MODULE"
    CannotFindModule(mod_name) => "CANNOT FIND MODULE '" + mod_name + "'"
    CannotFindGlobalType(name) => "CANNOT FIND GLOBAL TYPE '" + name + "'"
    ImportPathCannotEndWithExtension(path, ext) =>
      "IMPORT PATH '" + path + "' CANNOT END WITH '" + ext + "'"
    CannotFindModuleOrTypeDeclarations(mod_name) =>
      "CANNOT FIND MODULE '" + mod_name + "' OR TYPE DECLARATIONS"
    NamespaceHasNoExportedMember(ns, mem) =>
      "NAMESPACE '" + ns + "' HAS NO EXPORTED MEMBER '" + mem + "'"
    CannotUseNamespaceAsType(ns) =>
      "CANNOT USE NAMESPACE '" + ns + "' AS A TYPE"
    CannotUseNamespaceAsValue(ns) =>
      "CANNOT USE NAMESPACE '" + ns + "' AS A VALUE"
    CannotFindModuleSetModuleResolution(mod_name) =>
      "CANNOT FIND MODULE '" + mod_name + "' - CHECK MODULE RESOLUTION"
    ModuleHasNoExportedMember(mod_name, mem) =>
      "MODULE '" + mod_name + "' HAS NO EXPORTED MEMBER '" + mem + "'"
    // Type Assignment & Compatibility errors
    InterfaceCannotExtendTypes(iface, _) =>
      "INTERFACE '" + iface + "' CANNOT EXTEND INCOMPATIBLE TYPES"
    PropertyMissingInType(prop, typ) =>
      "PROPERTY '" + prop + "' IS MISSING IN TYPE '" + typ + "'"
    ParamTypesIncompatible(param1, param2, _) =>
      "PARAMETER TYPES '" + param1 + "' AND '" + param2 + "' ARE INCOMPATIBLE"
    PropertyTypesIncompatible(prop, _, _) =>
      "PROPERTY '" + prop + "' TYPES ARE INCOMPATIBLE"
    IndexSignatureMissing(typ, _) =>
      "INDEX SIGNATURE MISSING IN TYPE '" + typ + "'"
    ThisInStaticProperty(prop) =>
      "'THIS' CANNOT BE REFERENCED IN STATIC PROPERTY '" + prop + "'"
    TypeDoesNotSatisfyConstraint(typ, constraint) =>
      "TYPE '" + typ + "' DOES NOT SATISFY CONSTRAINT '" + constraint + "'"
    ValueNoPropertiesInCommon(typ1, typ2) =>
      "TYPE '" + typ1 + "' HAS NO PROPERTIES IN COMMON WITH '" + typ2 + "'"
    OnlyVoidFunctionCanBeCalledWithNew(typ) =>
      "ONLY VOID FUNCTION CAN BE CALLED WITH 'NEW' (GOT '" + typ + "')"
    ConversionMayBeMistake(from, to) =>
      "CONVERSION FROM '" + from + "' TO '" + to + "' MAY BE A MISTAKE"
    TypeCannotBeAssignedToType(from, to) =>
      "TYPE '" + from + "' CANNOT BE ASSIGNED TO TYPE '" + to + "'"
    TypeMissingPropertiesFromType(typ, target, _) =>
      "TYPE '" + typ + "' IS MISSING PROPERTIES FROM '" + target + "'"
    TypeMissingPropertiesAndMore(typ, target, _, _) =>
      "TYPE '" + typ + "' IS MISSING PROPERTIES FROM '" + target + "'"
    TypeDoesNotSatisfyConstraintAlt(typ, constraint) =>
      "TYPE '" + typ + "' DOES NOT SATISFY CONSTRAINT '" + constraint + "'"
    TypeNotAssignableSameNameDifferentTypes(typ1, typ2, _) =>
      "TYPE '" +
      typ1 +
      "' NOT ASSIGNABLE TO '" +
      typ2 +
      "' (DIFFERENT TYPES SAME NAME)"
    TypeNotAssignableGeneric(from, to) =>
      "TYPE '" + from + "' IS NOT ASSIGNABLE TO TYPE '" + to + "'"
    PropertyTypesIncompatibleAlt(prop, _, _) =>
      "PROPERTY '" + prop + "' TYPES ARE INCOMPATIBLE"
    // Operator & Expression errors
    InstanceofLeftNotObject(typ) =>
      "INVALID 'INSTANCEOF' LEFT-HAND SIDE (TYPE '" + typ + "')"
    InstanceofRightNotFunction(typ) =>
      "INVALID 'INSTANCEOF' RIGHT-HAND SIDE (TYPE '" + typ + "')"
    ConditionAlwaysSameValue(result, _) =>
      "CONDITION ALWAYS RETURNS '" + result + "'"
    LeftSideCommaUnused(_) => "LEFT SIDE OF COMMA OPERATOR UNUSED"
    CannotUseInOperator(_, typ) =>
      "CANNOT USE 'IN' OPERATOR WITH TYPE '" + typ + "'"
    ConditionAlwaysTrueFunction(name) =>
      "CONDITION ALWAYS TRUE (FUNCTION '" + name + "' NOT CALLED)"
    ConditionAlwaysTrue(typ) =>
      "CONDITION ALWAYS TRUE ('" + typ + "' IS ALWAYS DEFINED)"
    OperatorCannotBeApplied(op, left, right) =>
      "OPERATOR '" +
      op +
      "' CANNOT BE APPLIED TO '" +
      left +
      "' AND '" +
      right +
      "'"
    BigIntLiteralsNotAvailable => "BIGINT LITERALS NOT AVAILABLE"
    // Function & Parameter errors
    TypeParamNameCannotBe(name) =>
      "TYPE PARAMETER NAME CANNOT BE '" + name + "'"
    ParamPropertyOnlyInConstructor(param) =>
      "PARAMETER PROPERTY '" + param + "' ONLY ALLOWED IN CONSTRUCTOR"
    RestParamMustBeArray => "A rest parameter must be of an array type"
    ParamInitializerOnlyInFunctionOrConstructor(param) =>
      "PARAMETER INITIALIZER FOR '" + param + "' ONLY IN FUNCTION/CONSTRUCTOR"
    ParamCannotReferenceSelf(param) =>
      "PARAMETER '" + param + "' CANNOT REFERENCE ITSELF"
    OverloadSignaturesAmbientMismatch(name) =>
      "OVERLOAD SIGNATURES FOR '" +
      name +
      "' MUST ALL BE AMBIENT OR NON-AMBIENT"
    FunctionOverloadMustNotBeStatic(name) =>
      "FUNCTION OVERLOAD '" + name + "' MUST NOT BE STATIC"
    FunctionImplSignatureNotAssignable(name) =>
      "FUNCTION '" + name + "' IMPLEMENTATION SIGNATURE NOT ASSIGNABLE"
    ConstructorImplMissing(class_name) =>
      "CONSTRUCTOR IMPLEMENTATION MISSING FOR '" + class_name + "'"
    IndividualDeclarationsMustMatch(name, _) =>
      "DECLARATIONS IN '" + name + "' MUST ALL BE EXPORTED OR LOCAL"
    RequiredTypeParamAfterOptional(param) =>
      "REQUIRED TYPE PARAMETER '" + param + "' AFTER OPTIONAL"
    GenericTypeRequiresTypeArgs(name, min, max) =>
      "GENERIC TYPE '" +
      name +
      "' REQUIRES " +
      min.to_string() +
      "-" +
      max.to_string() +
      " TYPE ARGS"
    // For-in/For-of errors
    ForInLeftMustBeVariable(expr) =>
      "FOR...IN LEFT-HAND SIDE MUST BE VARIABLE (GOT '" + expr + "')"
    ForInRightMustBeObject(typ) =>
      "FOR...IN RIGHT-HAND SIDE MUST BE OBJECT (GOT '" + typ + "')"
    ForOfLeftMustBeVariable(expr) =>
      "FOR...OF LEFT-HAND SIDE MUST BE VARIABLE (GOT '" + expr + "')"
    // Property & Index errors
    TypeHasNoPropertyAndNoStringIndex(typ, prop) =>
      "TYPE '" + typ + "' HAS NO PROPERTY '" + prop + "' AND NO STRING INDEX"
    TypeIsNotArrayType(typ) => "TYPE '" + typ + "' IS NOT AN ARRAY TYPE"
    TypeCannotBeUsedAsIndex(typ) =>
      "TYPE '" + typ + "' CANNOT BE USED AS INDEX TYPE"
    IndexSignatureOnlyPermitsReading(typ) =>
      "INDEX SIGNATURE IN '" + typ + "' ONLY PERMITS READING"
    IndexSignatureParamTypeMustBe(typ) =>
      "INDEX SIGNATURE PARAM TYPE '" + typ + "' MUST BE STRING/NUMBER/SYMBOL"
    PropertyUsedBeforeInit(prop) =>
      "PROPERTY '" + prop + "' USED BEFORE INITIALIZATION"
    PropertyIncompatibleWithIndexSig(prop, prop_type, index_type) =>
      "PROPERTY '" +
      prop +
      "' OF TYPE '" +
      prop_type +
      "' INCOMPATIBLE WITH INDEX TYPE '" +
      index_type +
      "'"
    PropertyHasConflictingDeclarations(prop) =>
      "PROPERTY '" + prop + "' HAS CONFLICTING DECLARATIONS"
    NewExprTargetLacksConstructSig(typ) =>
      "'NEW' EXPRESSION TARGET '" + typ + "' LACKS CONSTRUCT SIGNATURE"
    CannotAccessBeforeInit(name) =>
      "'" + name + "' CANNOT BE ACCESSED BEFORE INITIALIZATION"
    PropertyCanOnlyBeAssignedWithThis(prop) =>
      "PROPERTY '" + prop + "' CAN ONLY BE ASSIGNED USING 'THIS'"
    // Array & Iteration errors
    TypeNotArrayOrString(typ) =>
      "TYPE '" + typ + "' IS NOT AN ARRAY OR STRING TYPE"
    TypeNotArrayOrStringDownlevel(typ) =>
      "TYPE '" + typ + "' IS NOT ARRAY OR STRING (USE --DOWNLEVELITERATION)"
    PropertyDoesNotExistDidYouMean(prop, typ, suggestion) =>
      "PROPERTY '" +
      prop +
      "' DOES NOT EXIST ON '" +
      typ +
      "' - DID YOU MEAN '" +
      suggestion +
      "'?"
    CannotFindNameDidYouMean(name, suggestion) =>
      "CANNOT FIND NAME '" + name + "' - DID YOU MEAN '" + suggestion + "'?"
    ExpectedNArgsButGotMore(expected, actual) =>
      "EXPECTED " + expected.to_string() + " ARGS BUT GOT " + actual.to_string()
    RestElementTypeMustBeArray(typ) =>
      "REST ELEMENT TYPE '" + typ + "' MUST BE AN ARRAY TYPE"
    NoOverloadExpectsNArgs(n) =>
      "NO OVERLOAD EXPECTS " + n.to_string() + " ARGUMENTS"
    TypeCanOnlyBeIteratedWithDownlevel(typ) =>
      "TYPE '" + typ + "' CAN ONLY BE ITERATED WITH --DOWNLEVELITERATION"
    // Spread & Rest errors
    PropertyUsedBeforeAssigned(prop) =>
      "PROPERTY '" + prop + "' USED BEFORE BEING ASSIGNED"
    RestElementCannotContainBindingPattern =>
      "REST ELEMENT CANNOT CONTAIN A BINDING PATTERN"
    RestTypesMustBeFromObjectTypes(typ) =>
      "REST TYPES MAY ONLY BE CREATED FROM OBJECT TYPES (GOT '" + typ + "')"
    ObjectRestAssignmentMustBeVariable(target) =>
      "OBJECT REST ASSIGNMENT TARGET '" + target + "' MUST BE A VARIABLE"
    ObjectRestAssignmentNotOptional(prop) =>
      "OBJECT REST ASSIGNMENT PROPERTY '" + prop + "' CANNOT BE OPTIONAL"
    SpreadTypesMustBeFromObjectTypes(typ) =>
      "SPREAD TYPES MAY ONLY BE CREATED FROM OBJECT TYPES (GOT '" + typ + "')"
    // Async/Generator/Yield errors
    YieldExpressionImplicitlyAny =>
      "'YIELD' EXPRESSION IMPLICITLY HAS 'ANY' TYPE"
    YieldOperandTypeInAsyncGenerator(operand_type, _) =>
      "YIELD OPERAND TYPE '" + operand_type + "' IN ASYNC GENERATOR"
    TypeReferencedInThenMethod(type_name) =>
      "TYPE '" + type_name + "' REFERENCED IN 'THEN' METHOD"
    // Enum & Catch Clause errors
    CatchClauseVariableMustBeAnyOrUnknown(var_name) =>
      "CATCH CLAUSE VARIABLE '" + var_name + "' MUST BE 'any' OR 'unknown'"
    ConstEnumUsageRestriction(enum_name) =>
      "CONST ENUM '" + enum_name + "' USAGE RESTRICTION"
    ConstEnumMemberAccessRestriction(mem) =>
      "CONST ENUM MEMBER '" + mem + "' ACCESS RESTRICTION"
    UsingPrivateName(private_name, context) =>
      "USING PRIVATE NAME '" + private_name + "' IN '" + context + "'"
    MemberInitializerForwardReference(mem, referenced) =>
      "MEMBER '" + mem + "' CANNOT REFERENCE '" + referenced + "'"
    // Module & Export errors
    ExportDeclarationConflicts(name, _) =>
      "EXPORT DECLARATION CONFLICTS WITH '" + name + "'"
    ArgumentsObjectCannotBeReferenced(context) =>
      "'ARGUMENTS' CANNOT BE REFERENCED IN " + context
    ModuleCanOnlyBeReferencedWithESImport(module_name) =>
      "MODULE '" + module_name + "' REQUIRES ES IMPORT"
    ReferencedInOwnBaseExpression(name) =>
      "'" + name + "' REFERENCED IN ITS OWN BASE EXPRESSION"
    InferredTypeReferencesInaccessible(name, inaccessible) =>
      "INFERRED TYPE OF '" +
      name +
      "' REFERENCES INACCESSIBLE '" +
      inaccessible +
      "'"
    CannotAugmentModule(module_name) =>
      "CANNOT AUGMENT MODULE '" + module_name + "'"
    RefersToUMDGlobal(name) => "'" + name + "' REFERS TO UMD GLOBAL"
    DeclarationsMustHaveIdenticalModifiers(name) =>
      "DECLARATIONS OF '" + name + "' MUST HAVE IDENTICAL MODIFIERS"
    CannotFindTypeDefinitionFile(name) =>
      "CANNOT FIND TYPE DEFINITION FILE FOR '" + name + "'"
    // Type Complexity & Inference errors
    PropertyIsStaticMemberOfType(prop, type_name) =>
      "PROPERTY '" + prop + "' IS A STATIC MEMBER OF TYPE '" + type_name + "'"
    UnusedTsExpectErrorDirective => "UNUSED '@ts-expect-error' DIRECTIVE"
    CannotFindNameTestRunner(name) =>
      "CANNOT FIND NAME '" + name + "' (TEST RUNNER TYPES)"
    CannotFindNameTargetLibrary(name, _) =>
      "CANNOT FIND NAME '" + name + "' (TARGET LIBRARY)"
    CannotFindNameTargetLibraryAlt(name, _) =>
      "CANNOT FIND NAME '" + name + "' (TARGET LIBRARY)"
    ExpressionProducesUnionTooComplex => "EXPRESSION PRODUCES UNION TOO COMPLEX"
    CannotImportTypeDeclarationFiles(file) =>
      "CANNOT IMPORT TYPE DECLARATION FILE '" + file + "'"
    InferredTypeCannotBeNamed(name, reference) =>
      "INFERRED TYPE OF '" +
      name +
      "' CANNOT BE NAMED WITHOUT '" +
      reference +
      "'"
  }
}

///|
/// Get a "why this happens" explanation (educational context like Elm provides)
pub fn get_why_explanation(reason : MismatchReason) -> String {
  match reason {
    IncompatibleTypes =>
      "TypeScript uses structural typing, which means types are compatible based on their structure (properties and methods), not their names. I found that the structure of these two types doesn't match."
    MissingProperty(name) =>
      "The target type requires a property named '" +
      name +
      "', but it's not present in the source type. TypeScript needs all required properties to be defined."
    ExcessProperty(_) =>
      "When using object literals, TypeScript performs 'excess property checking' to catch typos and unintended properties. This is stricter than normal structural typing because object literals are more likely to contain mistakes."
    PropertyTypeMismatch(name) =>
      "The property '" +
      name +
      "' exists in both types, but with different types. For structural compatibility, matching properties must have compatible types."
    ParamCountMismatch(expected, actual) =>
      "The function expects " +
      expected.to_string() +
      " argument(s), but " +
      actual.to_string() +
      " were provided. Function calls must pass the correct number of arguments."
    ParamTypeMismatch(index, name) =>
      "Parameter '" +
      name +
      "' (at position " +
      index.to_string() +
      ") has an incompatible type. Function parameters must match the expected types."
    ReturnTypeMismatch =>
      "The function's return type doesn't match what's expected. When a function is used in a context expecting a specific return type, the actual return must be compatible."
    NoUnionMemberMatches =>
      "Union types (A | B | C) require the value to match at least one member. I checked each member but none were compatible with the provided type."
    TypeArgMismatch(name, _) =>
      "Generic type parameter '" +
      name +
      "' was instantiated with incompatible types. When using generics, the type arguments must be consistent throughout."
    ConstraintNotSatisfied(name, _) =>
      "Generic type parameter '" +
      name +
      "' has a constraint that must be satisfied. The provided type doesn't meet this requirement."
    CannotInfer(name) =>
      "I couldn't automatically determine what type '" +
      name +
      "' should be. This usually happens when there's not enough context to infer the type."
    ReadonlyMutation(_) =>
      "Properties marked as 'readonly' cannot be reassigned after initialization. This is a TypeScript feature to prevent accidental mutations."
    OptionalToRequired(_) =>
      "Optional properties (with ?) may be undefined, but required properties must always have a value. Assigning an optional to a required property could cause runtime errors."
    IndexSignatureMismatch =>
      "Index signatures define the types of properties accessed by index (like obj[key]). The source and target have incompatible index signatures."
    LiteralMismatch(expected, actual) =>
      "Literal types are exact values, not just their primitive type. The literal '" +
      actual +
      "' is different from the expected literal '" +
      expected +
      "'."
    LiteralToWide =>
      "A literal type is being assigned where a more general type is expected. This might cause the literal type information to be lost."
    CircularReference =>
      "I detected a circular reference in the type definition. The type refers to itself in a way that creates an infinite loop."
    ExcessiveDepth =>
      "The type nesting is too deep for me to analyze safely. This might indicate an overly complex type or a bug in the type definition."
    NotCallable =>
      "You're trying to call something as a function, but it doesn't have a call signature. Only functions, methods, and callable objects can be called with ()."
    NotConstructable =>
      "You're trying to use 'new' on something that isn't a constructor. Only classes and constructor functions can be instantiated with 'new'."
    UnboundVariable(name) =>
      "I cannot find any variable, function, or value named '" +
      name +
      "' in the current scope. This could be a typo or the value might need to be imported/declared."
    UnboundType(name) =>
      "I cannot find any type named '" +
      name +
      "' in the current scope. This could be a typo or the type might need to be imported/declared."
    IntersectionNotSatisfied(_) =>
      "Intersection types (A & B) require the value to satisfy all member types simultaneously. The provided value doesn't meet all requirements."
    NoOverloadMatches(count) =>
      "I tried to match " +
      count.to_string() +
      " overload signature(s) for this function call, but none of them matched the arguments you provided. Each overload has specific parameter types it expects."
    OverloadCandidateFailed(index) =>
      "Overload candidate " +
      index.to_string() +
      " didn't match because the argument types weren't compatible with its parameter types."
    OverloadNotCompatibleWithImpl(index) =>
      "Overload signature " +
      index.to_string() +
      " is not compatible with the function implementation. The implementation must be able to handle all cases defined by the overload signatures."
    OverloadMissingImplementation(name) =>
      "Function '" +
      name +
      "' has overload signatures but no implementation. An overloaded function must have an implementation body that follows the overload signatures."
    OverloadAmbientMismatch(name) =>
      "Overload signatures for '" +
      name +
      "' mix ambient and non-ambient declarations. All overload signatures must either all be ambient (in a .d.ts file or declare context) or all be non-ambient."
    PrivateMemberAccess(name, declared_in) =>
      "The property '" +
      name +
      "' is marked as private in class '" +
      declared_in +
      "'. Private members can only be accessed from within the class where they are declared."
    ProtectedMemberAccess(name, declared_in) =>
      "The property '" +
      name +
      "' is marked as protected in class '" +
      declared_in +
      "'. Protected members can only be accessed from within the class and its subclasses."
    AbstractClassInstantiation(name) =>
      "Class '" +
      name +
      "' is abstract and cannot be instantiated directly. Abstract classes are meant to be extended by concrete classes that implement their abstract members."
    AbstractMemberNotImplemented(name, base_class) =>
      "The abstract member '" +
      name +
      "' from base class '" +
      base_class +
      "' must be implemented by the derived class. Abstract members define a contract that derived classes must fulfill."
    OverrideReturnTypeMismatch(name, base_class) =>
      "The override of method '" +
      name +
      "' has a return type that is not compatible with the base method in '" +
      base_class +
      "'. Override methods must have a return type that is assignable to the base method's return type (covariance)."
    OverrideParamCountMismatch(name, base_required, derived_required) =>
      "The override of method '" +
      name +
      "' requires " +
      derived_required.to_string() +
      " parameters, but the base method requires only " +
      base_required.to_string() +
      ". Override methods cannot require more parameters than the base method."
    OverrideParamTypeMismatch(name, param_idx, param_name) =>
      "Parameter '" +
      param_name +
      "' at position " +
      param_idx.to_string() +
      " in override method '" +
      name +
      "' has an incompatible type. Parameter types in override methods must be compatible with the base method (contravariance)."
    OverrideAccessibilityMismatch(name, base_acc, derived_acc) =>
      "The override of member '" +
      name +
      "' changes accessibility from " +
      base_acc +
      " to " +
      derived_acc +
      ". Override members cannot be more restrictive than the base member's accessibility."
    // Super call validation
    ThisBeforeSuperCall =>
      "In TypeScript, when a derived class constructor uses 'this', it must first call 'super()' to initialize the base class. This ensures the parent class properties are set up before the child class accesses them."
    SuperCallRequired(class_name) =>
      "Class '" +
      class_name +
      "' extends a base class but its constructor doesn't call 'super()'. TypeScript requires derived class constructors to call their parent constructor."
    SuperCallOutsideConstructor =>
      "'super()' can only be called inside a constructor. If you want to access parent class methods, use 'super.methodName()' instead of 'super()'."
    SuperPropertyOutsideClass =>
      "'super' can only be used inside a class that extends another class. It refers to the parent class's prototype and is not available outside of derived classes."
    SuperCallInStaticMethod =>
      "'super()' cannot be called in a static method because static methods don't have access to instance-level inheritance. Static methods belong to the class itself, not to instances."
    SuperPropertyAccess(name) =>
      "The property '" +
      name +
      "' doesn't exist on the parent class. Check that the parent class defines this property or method."
    // BigInt errors
    BigIntNumberMixing(op) =>
      "TypeScript doesn't allow mixing 'bigint' and 'number' in arithmetic operations because they are fundamentally different types. BigInt can represent arbitrarily large integers, while number is a 64-bit floating point. The '" +
      op +
      "' operator requires both operands to be of the same numeric type."
    UnaryPlusBigInt =>
      "The unary '+' operator is not supported for bigint because it would be ambiguous - in JavaScript, '+x' typically converts to number, but bigint cannot be implicitly converted to number without potential precision loss."
    // Module/Import resolution errors
    FileIsNotModule(file) =>
      "The file '" +
      file +
      "' does not contain any exports (export statements) and therefore cannot be imported as a module. In TypeScript, a file is only considered a module if it has at least one import or export statement."
    CannotFindModule(mod_name) =>
      "TypeScript cannot locate the module '" +
      mod_name +
      "'. This could be because the module path is incorrect, the module doesn't exist, or the module resolution settings don't include this path."
    CannotFindGlobalType(name) =>
      "The global type '" +
      name +
      "' is not available. Global types like 'Array', 'Promise', etc. are typically provided by the TypeScript lib files based on your target setting."
    ImportPathCannotEndWithExtension(_, ext) =>
      "Import paths in TypeScript should not include the file extension '" +
      ext +
      "'. TypeScript will automatically resolve the correct file based on your module resolution settings."
    CannotFindModuleOrTypeDeclarations(mod_name) =>
      "TypeScript cannot find the module '" +
      mod_name +
      "' or its corresponding type declarations (.d.ts file). For npm packages, you may need to install @types/" +
      mod_name +
      " for type information."
    NamespaceHasNoExportedMember(ns, mem) =>
      "The namespace '" +
      ns +
      "' exists but does not export a member named '" +
      mem +
      "'. Check the namespace definition to see what members are available."
    CannotUseNamespaceAsType(ns) =>
      "'" +
      ns +
      "' refers to a namespace, not a type. Namespaces are containers for values and types but cannot be used directly as types."
    CannotUseNamespaceAsValue(ns) =>
      "'" +
      ns +
      "' refers to a namespace, but you're trying to use it as a value. You need to access a specific member of the namespace."
    CannotFindModuleSetModuleResolution(mod_name) =>
      "TypeScript cannot find the module '" +
      mod_name +
      "'. This might be because your moduleResolution setting doesn't match how modules are installed in your project."
    ModuleHasNoExportedMember(mod_name, mem) =>
      "The module '" +
      mod_name +
      "' exists but does not export a member named '" +
      mem +
      "'. Check the module's exports or look at its type definitions."
    // Type Assignment & Compatibility errors
    InterfaceCannotExtendTypes(iface, types) =>
      "Interface '" +
      iface +
      "' is trying to extend multiple types that have conflicting members: " +
      types.join(", ") +
      ". When an interface extends multiple types, all their members must be compatible."
    PropertyMissingInType(prop, typ) =>
      "The property '" +
      prop +
      "' is required but not present in the type '" +
      typ +
      "'. TypeScript's structural typing requires all non-optional properties to exist."
    ParamTypesIncompatible(param1, param2, context) =>
      "The parameter types '" +
      param1 +
      "' and '" +
      param2 +
      "' are not compatible in " +
      context +
      ". Function parameters must match in both type and position for assignment."
    PropertyTypesIncompatible(prop, type1, type2) =>
      "The property '" +
      prop +
      "' has type '" +
      type1 +
      "' in one type and '" +
      type2 +
      "' in another. For types to be compatible, corresponding properties must have compatible types."
    IndexSignatureMissing(typ, expected) =>
      "Type '" +
      typ +
      "' is missing an index signature that exists in '" +
      expected +
      "'. Index signatures like [key: string]: T allow accessing properties by computed keys."
    ThisInStaticProperty(prop) =>
      "'this' refers to the instance of a class, but static property '" +
      prop +
      "' belongs to the class itself, not instances. Static members are initialized before any instance exists."
    TypeDoesNotSatisfyConstraint(typ, constraint) =>
      "The type '" +
      typ +
      "' doesn't meet the requirements specified by the constraint '" +
      constraint +
      "'. Generic constraints ensure type parameters have certain properties or extend certain types."
    ValueNoPropertiesInCommon(typ1, typ2) =>
      "Types '" +
      typ1 +
      "' and '" +
      typ2 +
      "' have no properties in common. This usually means you're comparing completely unrelated types or one is much more specific than the other."
    OnlyVoidFunctionCanBeCalledWithNew(typ) =>
      "The function returns '" +
      typ +
      "', but functions called with 'new' should either return void (letting the constructor create the instance) or return an object type."
    ConversionMayBeMistake(from, to) =>
      "Converting from '" +
      from +
      "' to '" +
      to +
      "' loses type information and may not be what you intended. TypeScript is warning that these types have very different structures."
    TypeCannotBeAssignedToType(from, to) =>
      "Type '" +
      from +
      "' cannot be assigned to type '" +
      to +
      "'. The source type is missing properties or has incompatible property types."
    TypeMissingPropertiesFromType(typ, target, props) =>
      "Type '" +
      typ +
      "' is missing the following required properties from type '" +
      target +
      "': " +
      props.join(", ") +
      "."
    TypeMissingPropertiesAndMore(typ, target, props, more) =>
      "Type '" +
      typ +
      "' is missing properties from type '" +
      target +
      "': " +
      props.join(", ") +
      " and " +
      more.to_string() +
      " more. This indicates significant structural differences between the types."
    TypeDoesNotSatisfyConstraintAlt(typ, constraint) =>
      "Type '" +
      typ +
      "' doesn't satisfy the constraint '" +
      constraint +
      "'. Ensure the type includes all required properties and methods defined by the constraint."
    TypeNotAssignableSameNameDifferentTypes(typ1, typ2, source) =>
      "Type '" +
      typ1 +
      "' is not assignable to type '" +
      typ2 +
      "'. Although they have the same name, they come from different declarations (" +
      source +
      ") and are treated as separate types."
    TypeNotAssignableGeneric(from, to) =>
      "Type '" +
      from +
      "' is not assignable to type '" +
      to +
      "'. Check that all properties and their types match the expected type structure."
    PropertyTypesIncompatibleAlt(prop, type1, type2) =>
      "Property '" +
      prop +
      "' has incompatible types: '" +
      type1 +
      "' vs '" +
      type2 +
      "'. Ensure the property types are compatible in both the source and target types."
    // Operator & Expression errors
    InstanceofLeftNotObject(typ) =>
      "The 'instanceof' operator checks if an object is an instance of a constructor. The left-hand side must be an object type, but you provided '" +
      typ +
      "' which is a primitive or non-object type."
    InstanceofRightNotFunction(typ) =>
      "The right-hand side of 'instanceof' must be a constructor function or class. You provided '" +
      typ +
      "' which is not callable as a constructor."
    ConditionAlwaysSameValue(result, types) =>
      "This comparison will always return '" +
      result +
      "' because the types '" +
      types +
      "' have no overlap. This usually indicates a logic error or incorrect type narrowing."
    LeftSideCommaUnused(expr) =>
      "The left side of a comma operator '" +
      expr +
      "' is evaluated but its result is discarded. This is often a bug unless the left side has side effects."
    CannotUseInOperator(key, typ) =>
      "The 'in' operator checks if a property exists in an object. The right-hand side must be an object type, but '" +
      typ +
      "' is not an object. You're checking for key '" +
      key +
      "'."
    ConditionAlwaysTrueFunction(name) =>
      "You're using function '" +
      name +
      "' directly in a condition without calling it. Functions are always truthy in JavaScript. Did you mean to call the function with '" +
      name +
      "()'?"
    ConditionAlwaysTrue(typ) =>
      "The value of type '" +
      typ +
      "' is always defined (never null or undefined), so this condition will always be true. This may indicate unnecessary null checking."
    OperatorCannotBeApplied(op, left, right) =>
      "The operator '" +
      op +
      "' cannot be used with types '" +
      left +
      "' and '" +
      right +
      "'. TypeScript requires compatible types for this operation."
    BigIntLiteralsNotAvailable =>
      "BigInt literals (like 123n) are only available when targeting ES2020 or later. Your current target doesn't support BigInt syntax."
    // Function & Parameter errors
    TypeParamNameCannotBe(name) =>
      "The name '" +
      name +
      "' is reserved and cannot be used as a type parameter name. TypeScript reserves certain names like primitive types (string, number, boolean, etc.) to avoid confusion."
    ParamPropertyOnlyInConstructor(param) =>
      "Parameter properties (like 'public " +
      param +
      "' or 'private " +
      param +
      "') can only be used in class constructors. They provide a shorthand for declaring and initializing class members directly from constructor parameters."
    RestParamMustBeArray =>
      "Rest parameters must have an array type because they collect multiple arguments into an array. Use '...args: T[]' instead of '...args: T'."
    ParamInitializerOnlyInFunctionOrConstructor(param) =>
      "Default parameter values (like '" +
      param +
      " = value') can only appear in function or constructor implementations, not in type declarations or overload signatures."
    ParamCannotReferenceSelf(param) =>
      "Parameter '" +
      param +
      "' cannot use itself in its own default value or type annotation. This would create a circular reference that TypeScript cannot resolve."
    OverloadSignaturesAmbientMismatch(name) =>
      "The overload signatures for '" +
      name +
      "' mix ambient (declare) and non-ambient declarations. All overloads must consistently be either declared in a .d.ts file / declare context, or be regular function overloads."
    FunctionOverloadMustNotBeStatic(name) =>
      "The function overload '" +
      name +
      "' is marked as static, but function overloads in this context should not use the static modifier. Static is for class members, not standalone functions."
    FunctionImplSignatureNotAssignable(name) =>
      "The implementation signature of function '" +
      name +
      "' is not compatible with all its overload signatures. The implementation must be able to handle all cases defined by the overloads."
    ConstructorImplMissing(class_name) =>
      "Class '" +
      class_name +
      "' has constructor overload signatures but no implementation. After declaring constructor overloads, you must provide a single implementation that handles all cases."
    IndividualDeclarationsMustMatch(name, context) =>
      "The declarations being merged into '" +
      name +
      "' have inconsistent export modifiers in " +
      context +
      ". When merging declarations, they must all be exported or all be local (not exported)."
    RequiredTypeParamAfterOptional(param) =>
      "Required type parameter '" +
      param +
      "' cannot follow an optional type parameter. Like function parameters, required type parameters must come before optional ones (those with defaults)."
    GenericTypeRequiresTypeArgs(name, min, max) =>
      "Generic type '" +
      name +
      "' requires between " +
      min.to_string() +
      " and " +
      max.to_string() +
      " type arguments. You must provide the correct number of type arguments when using this generic type."
    // For-in/For-of errors
    ForInLeftMustBeVariable(expr) =>
      "The left-hand side of a 'for...in' loop must be a variable declaration or a simple variable/property reference. You used '" +
      expr +
      "' which is not a valid assignment target. The 'for...in' loop iterates over the enumerable property names (keys) of an object."
    ForInRightMustBeObject(typ) =>
      "The right-hand side of a 'for...in' loop must be an object type (or 'any'). You provided a value of type '" +
      typ +
      "'. The 'for...in' loop iterates over object properties, so it needs an object to iterate over."
    ForOfLeftMustBeVariable(expr) =>
      "The left-hand side of a 'for...of' loop must be a variable declaration or a simple variable/property reference. You used '" +
      expr +
      "' which is not a valid assignment target. The 'for...of' loop iterates over the values of an iterable (like arrays, strings, etc.)."
    // Property & Index errors
    TypeHasNoPropertyAndNoStringIndex(typ, prop) =>
      "You tried to access property '" +
      prop +
      "' on type '" +
      typ +
      "', but this type doesn't have that property and doesn't have a string index signature that would allow arbitrary property access. TypeScript requires either an explicit property declaration or an index signature like [key: string]: T."
    TypeIsNotArrayType(typ) =>
      "You're trying to use '" +
      typ +
      "' as an array, but it's not an array type. Array destructuring and spread operations require the value to be an array type (T[]) or a tuple type."
    TypeCannotBeUsedAsIndex(typ) =>
      "Type '" +
      typ +
      "' cannot be used as an index type. TypeScript only allows specific types as index types: string, number, symbol, or template literal types. The type you provided doesn't fall into these categories."
    IndexSignatureOnlyPermitsReading(typ) =>
      "The index signature in type '" +
      typ +
      "' is readonly, which means you can read values using index access but cannot write to them. This is a design choice to prevent accidental mutations."
    IndexSignatureParamTypeMustBe(typ) =>
      "Index signature parameter type '" +
      typ +
      "' is not valid. TypeScript requires index signature parameters to be of type 'string', 'number', 'symbol', or a template literal type. These are the only types that can be used as property keys in JavaScript."
    PropertyUsedBeforeInit(prop) =>
      "Property '" +
      prop +
      "' is being used before it has been assigned a value. TypeScript tracks definite assignment to ensure properties have values before they're accessed. This helps prevent runtime errors from accessing undefined values."
    PropertyIncompatibleWithIndexSig(prop, prop_type, index_type) =>
      "Property '" +
      prop +
      "' has type '" +
      prop_type +
      "' which is not assignable to the index signature type '" +
      index_type +
      "'. When an interface has an index signature, all named properties must have types that are assignable to the index signature's type."
    PropertyHasConflictingDeclarations(prop) =>
      "Property '" +
      prop +
      "' has multiple conflicting declarations in the type hierarchy. This typically happens when extending or implementing types that declare the same property with incompatible types. TypeScript cannot determine a single consistent type for this property."
    NewExprTargetLacksConstructSig(typ) =>
      "You're using 'new' with type '" +
      typ +
      "' but it doesn't have a construct signature. The 'new' keyword requires a type with a construct signature (declared using 'new(): T' or by being a class). This means the type can be called as a constructor."
    CannotAccessBeforeInit(name) =>
      "'" +
      name +
      "' is being accessed before it has been initialized. This typically happens with class fields that are accessed in the constructor before they're assigned, or with variables in the temporal dead zone (TDZ) when using 'let' or 'const'."
    PropertyCanOnlyBeAssignedWithThis(prop) =>
      "Property '" +
      prop +
      "' can only be assigned using a 'this.' access. This restriction exists for readonly properties in a class constructor - they can only be assigned using 'this.propertyName = value', not through destructuring or other indirect means."
    // Array & Iteration errors
    TypeNotArrayOrString(typ) =>
      "Type '" +
      typ +
      "' is not an array type or a string type. The spread operator (...) and certain iteration methods require the operand to be an array or string, which can be iterated over character by character or element by element."
    TypeNotArrayOrStringDownlevel(typ) =>
      "Type '" +
      typ +
      "' is not an array type or a string type. When targeting older JavaScript versions, you need to enable '--downlevelIteration' to iterate over types like Set, Map, or other iterables that aren't arrays or strings."
    PropertyDoesNotExistDidYouMean(prop, typ, suggestion) =>
      "Property '" +
      prop +
      "' does not exist on type '" +
      typ +
      "'. TypeScript found a similar property '" +
      suggestion +
      "' - this might be a typo. Property names are case-sensitive in TypeScript."
    CannotFindNameDidYouMean(name, suggestion) =>
      "Cannot find name '" +
      name +
      "'. TypeScript couldn't locate a variable, function, or type with this name. Did you mean '" +
      suggestion +
      "'? Check for typos or missing imports."
    ExpectedNArgsButGotMore(expected, actual) =>
      "Expected at least " +
      expected.to_string() +
      " arguments, but got " +
      actual.to_string() +
      ". When using spread syntax, the resulting number of arguments exceeds what the function can accept."
    RestElementTypeMustBeArray(typ) =>
      "A rest element type must be an array type, but got '" +
      typ +
      "'. Rest parameters (...args) and rest elements in destructuring patterns must be arrays so TypeScript can spread their elements."
    NoOverloadExpectsNArgs(n) =>
      "No overload expects " +
      n.to_string() +
      " arguments. The function has multiple overloaded signatures, but none of them accept this number of arguments. Check the function's type definitions to see valid argument counts."
    TypeCanOnlyBeIteratedWithDownlevel(typ) =>
      "Type '" +
      typ +
      "' can only be iterated through when using the '--downlevelIteration' compiler option. This type implements the iterable protocol but requires special handling when targeting older JavaScript versions."
    // Spread & Rest errors
    PropertyUsedBeforeAssigned(prop) =>
      "Property '" +
      prop +
      "' is being used before it has been assigned a value. TypeScript tracks definite assignment to ensure all properties are initialized before they're accessed. This helps prevent runtime errors."
    RestElementCannotContainBindingPattern =>
      "A rest element cannot contain a binding pattern. When using rest syntax (...rest), the rest variable must be a simple identifier, not a destructuring pattern like { a, b } or [x, y]."
    RestTypesMustBeFromObjectTypes(typ) =>
      "Rest types can only be created from object types, but got '" +
      typ +
      "'. When using spread in a type position (like { ...T }), T must be an object type so its properties can be spread."
    ObjectRestAssignmentMustBeVariable(target) =>
      "The target of an object rest assignment must be a variable or a property access. '" +
      target +
      "' is not a valid assignment target. Rest elements collect the remaining properties into a single variable."
    ObjectRestAssignmentNotOptional(prop) =>
      "Rest element '" +
      prop +
      "' cannot be optional. Rest elements collect all remaining properties, so they always have a value (even if it's an empty object). The '?' modifier is not allowed."
    SpreadTypesMustBeFromObjectTypes(typ) =>
      "Spread types can only be created from object types, but got '" +
      typ +
      "'. When spreading in a type (like { ...T, extra: number }), T must be an object type whose properties can be enumerated."
    // Async/Generator/Yield errors
    YieldExpressionImplicitlyAny =>
      "The 'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation. TypeScript cannot infer the type of values yielded by the generator, so it defaults to 'any'. Adding a return type annotation to the generator function will help TypeScript understand the yielded values."
    YieldOperandTypeInAsyncGenerator(operand_type, _) =>
      "In an async generator, the type '" +
      operand_type +
      "' of the 'yield' operand must either be a valid promise or must not contain a callable 'then' member. This restriction exists because async generators handle promises specially, and a non-promise type with a 'then' method could cause unexpected behavior."
    TypeReferencedInThenMethod(type_name) =>
      "Type '" +
      type_name +
      "' is referenced when attempting to get the type of the 'then' method in a promise. This usually indicates a circular reference where a promise's fulfillment callback references the same type being resolved, creating an infinite type resolution loop."
    // Enum & Catch Clause errors
    CatchClauseVariableMustBeAnyOrUnknown(var_name) =>
      "Catch clause variable '" +
      var_name +
      "' has a type annotation that is not 'any' or 'unknown'. In TypeScript, caught exceptions can be of any type at runtime (not just Error objects), so the type annotation must be either 'any' (allows any operations) or 'unknown' (requires type checking before use)."
    ConstEnumUsageRestriction(enum_name) =>
      "A const enum '" +
      enum_name +
      "' member can only be accessed using a string literal. Const enums are inlined at compile time, meaning the enum object doesn't exist at runtime. This restricts how you can access enum members - only literal member access (like MyEnum.Value) is allowed, not computed access."
    ConstEnumMemberAccessRestriction(mem) =>
      "The const enum member '" +
      mem +
      "' can only be accessed using a string literal. Because const enums are replaced with their literal values during compilation, dynamic property access (like enum[variable]) is not possible. The compiler needs to know at compile time which member is being accessed."
    UsingPrivateName(private_name, context) =>
      "Private name '" +
      private_name +
      "' is being used as the type of '" +
      context +
      "'. Private names (starting with #) are only accessible within the class that defines them. Using a private name in a type annotation exposes implementation details that should remain encapsulated."
    MemberInitializerForwardReference(mem, referenced) =>
      "The initializer of enum member '" +
      mem +
      "' references '" +
      referenced +
      "' which is declared after it. Enum members are evaluated in order, so earlier members cannot reference later ones. This prevents circular dependencies and ensures deterministic initialization order."
    // Module & Export errors
    ExportDeclarationConflicts(name, _) =>
      "There are multiple export declarations for '" +
      name +
      "' that conflict with each other. Each name can only be exported once from a module. This often happens when you have both a named export and a re-export with the same name."
    ArgumentsObjectCannotBeReferenced(context) =>
      "The 'arguments' object cannot be referenced in " +
      context +
      ". Arrow functions don't have their own 'arguments' binding - they inherit it from the enclosing scope. Use rest parameters (...args) instead to capture all arguments."
    ModuleCanOnlyBeReferencedWithESImport(module_name) =>
      "Module '" +
      module_name +
      "' can only be referenced with a default import when using 'esModuleInterop'. This happens when importing a CommonJS module that doesn't have ES module exports. The esModuleInterop flag helps bridge the gap between CommonJS and ES modules."
    ReferencedInOwnBaseExpression(name) =>
      "'" +
      name +
      "' is referenced directly or indirectly in its own base expression. This creates a circular dependency where a class or type is trying to extend or reference itself in its own definition, which is not allowed."
    InferredTypeReferencesInaccessible(name, inaccessible) =>
      "The inferred type of '" +
      name +
      "' references an inaccessible '" +
      inaccessible +
      "' type. This happens when TypeScript infers a type that includes a private or internal type that cannot be used in the public API. You need to explicitly annotate the type with an accessible type."
    CannotAugmentModule(module_name) =>
      "Cannot augment module '" +
      module_name +
      "' with value exports because it resolves to a non-module entity. Module augmentation only works with actual ES modules or namespaces that can be extended. If the target is a non-module (like a script), it cannot be augmented."
    RefersToUMDGlobal(name) =>
      "'" +
      name +
      "' refers to a UMD global, but the current file is a module. When a file has import or export statements, it becomes a module and can no longer access UMD globals directly. You need to import the module explicitly instead."
    DeclarationsMustHaveIdenticalModifiers(name) =>
      "All declarations of '" +
      name +
      "' must have identical modifiers. When a name is declared multiple times (like in declaration merging), the access modifiers (public, private, export, etc.) must be consistent across all declarations."
    CannotFindTypeDefinitionFile(name) =>
      "Cannot find type definition file for '" +
      name +
      "'. TypeScript looks for type definitions in @types packages or .d.ts files. This usually means you need to install the corresponding @types package (npm install @types/" +
      name +
      ") or create a custom type declaration."
    // Type Complexity & Inference errors
    PropertyIsStaticMemberOfType(prop, type_name) =>
      "Property '" +
      prop +
      "' is a static member of type '" +
      type_name +
      "'. Static members belong to the class/type itself, not to instances of that type. You're trying to access it on an instance when you should access it on the class directly."
    UnusedTsExpectErrorDirective =>
      "The '@ts-expect-error' directive was added to suppress an error, but no error was actually produced on the following line. This often happens when the code was fixed but the directive was left behind, or the error occurs on a different line."
    CannotFindNameTestRunner(name) =>
      "Cannot find name '" +
      name +
      "'. This name is typically provided by test runner frameworks like Jest, Mocha, or Jasmine. You may need to install type definitions for your test runner (e.g., @types/jest, @types/mocha)."
    CannotFindNameTargetLibrary(name, target) =>
      "Cannot find name '" +
      name +
      "'. This is a built-in feature that requires a specific target library. Your current compilation target '" +
      target +
      "' doesn't include this feature. Consider changing your target to a newer ECMAScript version."
    CannotFindNameTargetLibraryAlt(name, target) =>
      "Cannot find name '" +
      name +
      "'. This feature is not available in your current target library '" +
      target +
      "'. You may need to include additional lib entries in your tsconfig.json or change your compilation target."
    ExpressionProducesUnionTooComplex =>
      "The expression produces a union type that is too complex to represent. TypeScript has limits on how complex types can be to prevent performance issues. This often happens with recursive types or when combining many conditional types."
    CannotImportTypeDeclarationFiles(file) =>
      "You cannot directly import type declaration files (.d.ts). Declaration files are automatically loaded by TypeScript and should not be imported directly. If you need types from '" +
      file +
      "', import from the corresponding JavaScript module instead."
    InferredTypeCannotBeNamed(name, reference) =>
      "The inferred type of '" +
      name +
      "' cannot be named without a reference to '" +
      reference +
      "'. This usually happens when an exported function returns a type from a module that isn't directly exported. You need to either add an explicit type annotation or ensure the referenced module is accessible."
  }
}

///|
/// Get detailed "how to fix" suggestions with code examples
pub fn get_how_to_fix(
  reason : MismatchReason,
  actual : TypeV2,
  expected : TypeV2,
) -> Array[String] {
  let fixes : Array[String] = []
  match reason {
    IncompatibleTypes => {
      fixes.push(
        "Option 1: Ensure the source value has the correct structure to match the expected type.",
      )
      fixes.push(
        "Option 2: Use a type assertion if you're certain the types are compatible:",
      )
      fixes.push("          value as ExpectedType")
      fixes.push(
        "Option 3: Check if there's a type mismatch in your function parameters or return values.",
      )
    }
    MissingProperty(name) => {
      fixes.push("Add the missing property '" + name + "' to your object:")
      fixes.push("    { ...existingObj, " + name + ": /* value */ }")
      fixes.push("")
      fixes.push(
        "Or mark the property as optional in the target type using '?':",
      )
      fixes.push("    interface Target { " + name + "?: SomeType; }")
    }
    ExcessProperty(name) => {
      fixes.push(
        "Option 1: Remove the extra property '" +
        name +
        "' from your object literal.",
      )
      fixes.push("")
      fixes.push(
        "Option 2: If you need the property, add it to the target type definition.",
      )
      fixes.push("")
      fixes.push(
        "Option 3: Use a type assertion to bypass excess property checking:",
      )
      fixes.push("    const obj = { " + name + ": value } as TargetType;")
      fixes.push("")
      fixes.push(
        "Option 4: Add an index signature to allow additional properties:",
      )
      fixes.push("    interface Target { [key: string]: unknown; }")
    }
    PropertyTypeMismatch(name) => {
      fixes.push(
        "Fix the type of property '" +
        name +
        "' in your source value to match the expected type.",
      )
      fixes.push("")
      fixes.push(
        "If you're certain the types are compatible, use a type assertion:",
      )
      fixes.push("    { " + name + ": value as ExpectedPropertyType }")
    }
    ParamCountMismatch(expected_count, actual_count) =>
      if actual_count > expected_count {
        fixes.push(
          "You're passing too many arguments. Remove " +
          (actual_count - expected_count).to_string() +
          " argument(s).",
        )
      } else {
        fixes.push(
          "You're passing too few arguments. Add " +
          (expected_count - actual_count).to_string() +
          " more argument(s).",
        )
        fixes.push("")
        fixes.push(
          "Or check if some parameters should be optional in the function definition:",
        )
        fixes.push("    function fn(required: A, optional?: B) { ... }")
      }
    ParamTypeMismatch(index, name) => {
      fixes.push(
        "Fix the type of argument at position " +
        index.to_string() +
        " ('" +
        name +
        "').",
      )
      fixes.push("")
      fixes.push("Example:")
      fixes.push("    // Instead of: fn(wrongValue)")
      fixes.push("    // Use:        fn(correctValue as ExpectedType)")
    }
    ReturnTypeMismatch => {
      fixes.push("Ensure your function returns a value of the expected type.")
      fixes.push("")
      fixes.push("Example fix:")
      fixes.push("    function example(): ExpectedType {")
      fixes.push(
        "        return correctValue; // Make sure this matches ExpectedType",
      )
      fixes.push("    }")
    }
    NoUnionMemberMatches =>
      match expected {
        TUnion(members) => {
          fixes.push("Your value must be one of these types:")
          for m in members {
            fixes.push("  - " + format_type_v2(m))
          }
          fixes.push("")
          fixes.push("Transform your value to match one of the union members.")
        }
        _ =>
          fixes.push(
            "Transform your value to match one of the union's member types.",
          )
      }
    TypeArgMismatch(name, _) => {
      fixes.push(
        "Ensure the type argument for '" +
        name +
        "' is consistent throughout your code.",
      )
      fixes.push("")
      fixes.push("Example:")
      fixes.push("    // If you have: const arr: Array<number> = [1, 2, 3];")
      fixes.push(
        "    // Don't do:   arr.push('string'); // Type argument mismatch!",
      )
    }
    ConstraintNotSatisfied(_, constraint) => {
      fixes.push(
        "Your type must satisfy this constraint: " + format_type_v2(constraint),
      )
      fixes.push("")
      fixes.push(
        "Example: if the constraint is 'extends { id: number }', your type must have an 'id' property of type 'number'.",
      )
    }
    CannotInfer(name) => {
      fixes.push("Provide an explicit type argument for '" + name + "':")
      fixes.push("    genericFunction<ExplicitType>(value)")
      fixes.push("")
      fixes.push(
        "Or ensure the context provides enough information for inference.",
      )
    }
    ReadonlyMutation(name) => {
      fixes.push(
        "The property '" + name + "' is readonly and cannot be changed.",
      )
      fixes.push("")
      fixes.push("Options:")
      fixes.push(
        "1. Create a new object with the updated value instead of mutating:",
      )
      fixes.push(
        "       const updated = { ...original, " + name + ": newValue };",
      )
      fixes.push(
        "2. Remove 'readonly' from the property definition if mutation is needed.",
      )
    }
    OptionalToRequired(name) => {
      fixes.push(
        "Ensure '" +
        name +
        "' is always defined before using it as a required value:",
      )
      fixes.push("    if (obj." + name + " !== undefined) {")
      fixes.push("        useAsRequired(obj." + name + ");")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Or provide a default value:")
      fixes.push("    const value = obj." + name + " ?? defaultValue;")
    }
    IndexSignatureMismatch => {
      fixes.push(
        "Ensure the index signature types match between source and target.",
      )
      fixes.push("")
      fixes.push(
        "If source has [key: string]: A and target expects [key: string]: B,",
      )
      fixes.push("then A must be assignable to B.")
    }
    LiteralMismatch(expected_lit, actual_lit) => {
      fixes.push(
        "The literal value '" +
        actual_lit +
        "' doesn't match the expected '" +
        expected_lit +
        "'.",
      )
      fixes.push("")
      fixes.push(
        "Either change your value or update the type to accept both literals:",
      )
      fixes.push(
        "    type AllowedValues = '" +
        expected_lit +
        "' | '" +
        actual_lit +
        "';",
      )
    }
    LiteralToWide => {
      fixes.push("To preserve the literal type, use 'as const':")
      fixes.push("    const value = 'literal' as const;")
      fixes.push("")
      fixes.push("Or use a const assertion on the whole object:")
      fixes.push("    const obj = { key: 'value' } as const;")
    }
    CircularReference => {
      fixes.push(
        "Break the circular reference by using a type alias or interface:",
      )
      fixes.push(
        "    type Node = { next?: Node };  // OK: optional breaks cycle",
      )
      fixes.push("")
      fixes.push("Or restructure your types to avoid self-reference.")
    }
    ExcessiveDepth => {
      fixes.push("Simplify your type structure. Consider:")
      fixes.push("1. Breaking down deeply nested types into smaller parts")
      fixes.push("2. Using type aliases to reduce repetition")
      fixes.push("3. Checking for accidentally recursive types")
    }
    NotCallable => {
      fixes.push("This value cannot be called as a function.")
      fixes.push("")
      match actual {
        TObject(_) => {
          fixes.push(
            "If this is an object, check if you meant to access a method:",
          )
          fixes.push("    // Instead of: obj()")
          fixes.push("    // Try:        obj.methodName()")
        }
        TUndefined | TNull => {
          fixes.push("The value might be undefined or null. Add a check:")
          fixes.push("    if (fn !== undefined) { fn(); }")
        }
        _ => fixes.push("Verify that you have the correct variable or import.")
      }
    }
    NotConstructable => {
      fixes.push(
        "Only classes and constructor functions can be used with 'new'.",
      )
      fixes.push("")
      fixes.push("If this is a function, call it directly without 'new':")
      fixes.push("    // Instead of: new myFunction()")
      fixes.push("    // Try:        myFunction()")
    }
    UnboundVariable(name) => {
      fixes.push("'" + name + "' is not defined in this scope.")
      fixes.push("")
      fixes.push("Possible solutions:")
      fixes.push("1. Check for typos in the variable name")
      fixes.push("2. Import it from another module:")
      fixes.push("       import { " + name + " } from './module';")
      fixes.push("3. Declare it before use:")
      fixes.push("       const " + name + " = /* value */;")
    }
    UnboundType(name) => {
      fixes.push("Type '" + name + "' is not defined in this scope.")
      fixes.push("")
      fixes.push("Possible solutions:")
      fixes.push("1. Check for typos in the type name")
      fixes.push("2. Import the type from another module:")
      fixes.push("       import type { " + name + " } from './types';")
      fixes.push("3. Define the type:")
      fixes.push("       type " + name + " = { /* properties */ };")
      fixes.push("       // or")
      fixes.push("       interface " + name + " { /* properties */ }")
    }
    IntersectionNotSatisfied(_) => {
      fixes.push(
        "Your value must satisfy all types in the intersection simultaneously.",
      )
      fixes.push("")
      fixes.push("For an intersection type A & B, your value needs:")
      fixes.push("- All properties from type A")
      fixes.push("- All properties from type B")
      fixes.push("- All methods from both types")
    }
    NoOverloadMatches(count) => {
      fixes.push(
        "None of the " + count.to_string() + " overload(s) match your call.",
      )
      fixes.push("")
      fixes.push("Options to fix:")
      fixes.push(
        "1. Check the argument types and count match one of the overloads",
      )
      fixes.push("2. Check for typos in the function name")
      fixes.push(
        "3. Add a type annotation to help TypeScript select the right overload:",
      )
      fixes.push("       functionName<ExplicitType>(...args)")
    }
    OverloadCandidateFailed(_) => {
      fixes.push(
        "This overload candidate didn't match. Check the error above for details.",
      )
      fixes.push("")
      fixes.push(
        "If you expected this overload to match, ensure argument types are compatible.",
      )
    }
    OverloadNotCompatibleWithImpl(index) => {
      fixes.push(
        "Overload signature " +
        index.to_string() +
        " is not compatible with implementation.",
      )
      fixes.push("")
      fixes.push(
        "The implementation must be able to handle all overload signatures.",
      )
      fixes.push(
        "Make sure the implementation's parameter types are supertypes of all overloads':",
      )
      fixes.push("    function foo(x: string): string;       // overload 1")
      fixes.push("    function foo(x: number): number;       // overload 2")
      fixes.push(
        "    function foo(x: string | number): string | number { // impl",
      )
      fixes.push("      return x;")
      fixes.push("    }")
    }
    OverloadMissingImplementation(name) => {
      fixes.push(
        "Function '" + name + "' has overload signatures but no implementation.",
      )
      fixes.push("")
      fixes.push("Add an implementation after the overload signatures:")
      fixes.push("    function " + name + "(x: string): string;  // overload")
      fixes.push("    function " + name + "(x: number): number;  // overload")
      fixes.push(
        "    function " + name + "(x: string | number): string | number {",
      )
      fixes.push("      // implementation goes here")
      fixes.push("      return x;")
      fixes.push("    }")
    }
    OverloadAmbientMismatch(name) => {
      fixes.push(
        "Overload signatures for '" + name + "' mix ambient and non-ambient.",
      )
      fixes.push("")
      fixes.push(
        "Either all overloads should be ambient (in a .d.ts file or declare context):",
      )
      fixes.push("    declare function " + name + "(x: string): string;")
      fixes.push("    declare function " + name + "(x: number): number;")
      fixes.push("")
      fixes.push("Or all should be non-ambient with an implementation:")
      fixes.push("    function " + name + "(x: string): string;")
      fixes.push("    function " + name + "(x: number): number;")
      fixes.push("    function " + name + "(x: string | number) { ... }")
    }
    PrivateMemberAccess(name, declared_in) => {
      fixes.push(
        "Property '" + name + "' is private to class '" + declared_in + "'.",
      )
      fixes.push("")
      fixes.push("Options to fix:")
      fixes.push("1. Access this property from within the class methods only")
      fixes.push("2. Add a public getter method:")
      fixes.push(
        "       public get" + name + "() { return this." + name + "; }",
      )
      fixes.push("3. Change the property to public or protected if appropriate")
    }
    ProtectedMemberAccess(name, declared_in) => {
      fixes.push(
        "Property '" + name + "' is protected in class '" + declared_in + "'.",
      )
      fixes.push("")
      fixes.push("Options to fix:")
      fixes.push("1. Access this property from a subclass or within the class")
      fixes.push("2. Add a public method that exposes the functionality")
      fixes.push("3. Change the property to public if appropriate")
    }
    AbstractClassInstantiation(name) => {
      fixes.push("Cannot instantiate abstract class '" + name + "'.")
      fixes.push("")
      fixes.push("Options to fix:")
      fixes.push("1. Create a concrete class that extends the abstract class:")
      fixes.push("       class Concrete" + name + " extends " + name + " {")
      fixes.push("         // implement abstract members")
      fixes.push("       }")
      fixes.push("2. Instantiate the concrete class instead")
    }
    AbstractMemberNotImplemented(name, base_class) => {
      fixes.push(
        "Abstract member '" +
        name +
        "' from '" +
        base_class +
        "' must be implemented.",
      )
      fixes.push("")
      fixes.push("Add the implementation in your class:")
      fixes.push("       " + name + "(...) { /* implementation */ }")
    }
    OverrideReturnTypeMismatch(name, _) => {
      fixes.push("Override method '" + name + "' has incompatible return type.")
      fixes.push("")
      fixes.push(
        "Ensure the return type is assignable to the base method's return type.",
      )
    }
    OverrideParamCountMismatch(name, base_count, _) => {
      fixes.push(
        "Override method '" +
        name +
        "' requires more parameters than base method.",
      )
      fixes.push("")
      fixes.push(
        "Make extra parameters optional or reduce to " +
        base_count.to_string() +
        " required parameters.",
      )
    }
    OverrideParamTypeMismatch(name, _, _) => {
      fixes.push(
        "Override method '" + name + "' has incompatible parameter type.",
      )
      fixes.push("")
      fixes.push("Ensure parameter types are compatible with the base method.")
    }
    OverrideAccessibilityMismatch(name, base_acc, _) => {
      fixes.push(
        "Override member '" + name + "' is more restrictive than base.",
      )
      fixes.push("")
      fixes.push("Keep or widen accessibility to: " + base_acc)
    }
    // Super call validation
    ThisBeforeSuperCall => {
      fixes.push("Call 'super()' before using 'this' in the constructor:")
      fixes.push("    constructor() {")
      fixes.push("        super();  // Call this first!")
      fixes.push("        this.property = value;  // Now you can use 'this'")
      fixes.push("    }")
    }
    SuperCallRequired(class_name) => {
      fixes.push(
        "Add a 'super()' call to the constructor of '" + class_name + "':",
      )
      fixes.push("    constructor() {")
      fixes.push("        super();  // Required in derived classes")
      fixes.push("        // ... rest of constructor")
      fixes.push("    }")
    }
    SuperCallOutsideConstructor => {
      fixes.push("Move the 'super()' call inside the constructor.")
      fixes.push("")
      fixes.push(
        "If you meant to call a parent method, use 'super.methodName()' instead:",
      )
      fixes.push("    someMethod() {")
      fixes.push("        super.someMethod();  // Call parent's method")
      fixes.push("    }")
    }
    SuperPropertyOutsideClass => {
      fixes.push("'super' can only be used inside a derived class.")
      fixes.push("")
      fixes.push("Make sure your class extends a base class:")
      fixes.push("    class Derived extends Base {")
      fixes.push("        method() { super.method(); }  // OK")
      fixes.push("    }")
    }
    SuperCallInStaticMethod => {
      fixes.push("Remove the 'super()' call from the static method.")
      fixes.push("")
      fixes.push(
        "Static methods cannot use 'super()' because they don't have instance context.",
      )
      fixes.push("If you need parent class static methods, call them by name:")
      fixes.push("    static method() {")
      fixes.push("        ParentClass.staticMethod();")
      fixes.push("    }")
    }
    SuperPropertyAccess(name) => {
      fixes.push(
        "The property '" + name + "' doesn't exist on the parent class.",
      )
      fixes.push("")
      fixes.push("Options:")
      fixes.push("1. Check the property name for typos")
      fixes.push("2. Add the property/method to the base class")
      fixes.push(
        "3. Use 'this." +
        name +
        "' if accessing a property defined in this class",
      )
    }
    // BigInt errors
    BigIntNumberMixing(_) => {
      fixes.push("Convert both operands to the same numeric type:")
      fixes.push("")
      fixes.push("Option 1: Convert to bigint:")
      fixes.push("    const result = bigintValue + BigInt(numberValue);")
      fixes.push("")
      fixes.push(
        "Option 2: Convert to number (may lose precision for large values):",
      )
      fixes.push("    const result = Number(bigintValue) + numberValue;")
    }
    UnaryPlusBigInt => {
      fixes.push("Remove the unary '+' operator from the bigint value:")
      fixes.push("")
      fixes.push("Instead of: +bigintValue")
      fixes.push("Use:        bigintValue")
      fixes.push("")
      fixes.push("If you need to convert to number:")
      fixes.push("    Number(bigintValue)")
    }
    // Module/Import resolution errors
    FileIsNotModule(file) => {
      fixes.push("Add an export to make '" + file + "' a module:")
      fixes.push("    export {};  // Makes file a module")
      fixes.push("")
      fixes.push("Or add actual exports:")
      fixes.push("    export const myValue = ...;")
      fixes.push("    export function myFunction() { ... }")
    }
    CannotFindModule(mod_name) => {
      fixes.push("Check if the module path is correct:")
      fixes.push(
        "    import { something } from './" + mod_name + "';  // Relative path",
      )
      fixes.push("")
      fixes.push("Or install the package if it's from npm:")
      fixes.push("    npm install " + mod_name)
    }
    CannotFindGlobalType(name) => {
      fixes.push("Add the required lib to your tsconfig.json:")
      fixes.push(
        "    { \"compilerOptions\": { \"lib\": [\"ES2015\", \"DOM\"] } }",
      )
      fixes.push("")
      fixes.push("Common libs for global types:")
      fixes.push("    ES2015+ for Promise, Symbol, Map, Set, etc.")
      fixes.push("    DOM for HTMLElement, Document, etc.")
    }
    ImportPathCannotEndWithExtension(_, ext) => {
      fixes.push("Remove the '" + ext + "' extension from your import:")
      fixes.push("    // Instead of: import { x } from './module" + ext + "'")
      fixes.push("    // Use:        import { x } from './module'")
    }
    CannotFindModuleOrTypeDeclarations(mod_name) => {
      fixes.push("Install type definitions for '" + mod_name + "':")
      fixes.push("    npm install --save-dev @types/" + mod_name)
      fixes.push("")
      fixes.push(
        "Or create a type declaration file (.d.ts) if types don't exist.",
      )
    }
    NamespaceHasNoExportedMember(ns, mem) => {
      fixes.push("Check available exports from namespace '" + ns + "'.")
      fixes.push("Verify that '" + mem + "' is spelled correctly.")
      fixes.push("")
      fixes.push(
        "If you want to add this member, export it from the namespace:",
      )
      fixes.push("    namespace " + ns + " {")
      fixes.push("        export const " + mem + " = ...;")
      fixes.push("    }")
    }
    CannotUseNamespaceAsType(ns) => {
      fixes.push("Access a specific type from the namespace:")
      fixes.push("    const x: " + ns + ".SomeType = ...;")
      fixes.push("")
      fixes.push("Or if you want a type alias for the namespace contents:")
      fixes.push("    type MyType = typeof " + ns + ";")
    }
    CannotUseNamespaceAsValue(ns) => {
      fixes.push("Access a specific value from the namespace:")
      fixes.push("    const x = " + ns + ".someValue;")
      fixes.push("    " + ns + ".someFunction();")
    }
    CannotFindModuleSetModuleResolution(mod_name) => {
      fixes.push("Try setting moduleResolution in tsconfig.json:")
      fixes.push(
        "    { \"compilerOptions\": { \"moduleResolution\": \"node\" } }",
      )
      fixes.push("")
      fixes.push("Or for Node.js ESM:")
      fixes.push(
        "    { \"compilerOptions\": { \"moduleResolution\": \"node16\" } }",
      )
      ignore(mod_name)
    }
    ModuleHasNoExportedMember(mod_name, mem) => {
      fixes.push("Check the module's exports for the correct name.")
      fixes.push(
        "The mem '" + mem + "' may not be exported or may be named differently.",
      )
      fixes.push("")
      fixes.push("Try using default import if the module has a default export:")
      fixes.push("    import mod from '" + mod_name + "';")
    }
    // Type Assignment & Compatibility errors
    InterfaceCannotExtendTypes(iface, types) => {
      fixes.push(
        "Option 1: Remove conflicting extends from interface '" + iface + "':",
      )
      fixes.push(
        "    interface " +
        iface +
        " extends " +
        (if types.length() > 0 { types[0] } else { "Type1" }) +
        " { }",
      )
      fixes.push("")
      fixes.push(
        "Option 2: Create a merged interface that resolves the conflicts:",
      )
      fixes.push(
        "    interface Merged { /* resolve conflicting properties */ }",
      )
      fixes.push("    interface " + iface + " extends Merged { }")
    }
    PropertyMissingInType(prop, _) => {
      fixes.push("Add the missing property to your type:")
      fixes.push("    { " + prop + ": /* value */ }")
      fixes.push("")
      fixes.push("Or mark the property as optional in the expected type:")
      fixes.push("    interface Target { " + prop + "?: SomeType; }")
    }
    ParamTypesIncompatible(param1, param2, _) => {
      fixes.push("Ensure parameter types match:")
      fixes.push("    function fn(param: CorrectType) { }")
      fixes.push("")
      fixes.push("Or use a union type to accept both:")
      fixes.push("    function fn(param: " + param1 + " | " + param2 + ") { }")
    }
    PropertyTypesIncompatible(prop, type1, type2) => {
      fixes.push("Change the property type to be compatible:")
      fixes.push("    { " + prop + ": CompatibleType }")
      fixes.push("")
      fixes.push("Or use a union type if both should be valid:")
      fixes.push("    { " + prop + ": " + type1 + " | " + type2 + " }")
    }
    IndexSignatureMissing(_, _) => {
      fixes.push("Add an index signature to your type:")
      fixes.push("    interface MyType {")
      fixes.push("        [key: string]: ValueType;")
      fixes.push("    }")
    }
    ThisInStaticProperty(_) => {
      fixes.push("Option 1: Make the property non-static:")
      fixes.push("    class MyClass { prop = this.value; }")
      fixes.push("")
      fixes.push("Option 2: Use the class name instead of 'this':")
      fixes.push("    class MyClass { static prop = MyClass.staticValue; }")
    }
    TypeDoesNotSatisfyConstraint(typ, constraint) => {
      fixes.push(
        "Ensure type '" +
        typ +
        "' has all required properties from '" +
        constraint +
        "':",
      )
      fixes.push(
        "    interface " +
        typ +
        " extends " +
        constraint +
        " { /* properties */ }",
      )
      fixes.push("")
      fixes.push("Or adjust the generic constraint to be less restrictive.")
    }
    ValueNoPropertiesInCommon(_, _) => {
      fixes.push("Check if you're comparing the correct types.")
      fixes.push("Consider using a type assertion if intentional:")
      fixes.push("    value as TargetType")
      fixes.push("")
      fixes.push("Or add common properties to make types compatible.")
    }
    OnlyVoidFunctionCanBeCalledWithNew(_) => {
      fixes.push("Option 1: Make the function return void or an object:")
      fixes.push("    function Ctor(): void { /* ... */ }")
      fixes.push("")
      fixes.push("Option 2: Use a class instead:")
      fixes.push("    class MyClass { constructor() { } }")
    }
    ConversionMayBeMistake(from, to) => {
      fixes.push(
        "If this conversion is intentional, use 'unknown' as intermediate:",
      )
      fixes.push("    (value as unknown) as " + to)
      fixes.push("")
      fixes.push("Or reconsider if you're converting to the correct type.")
      fixes.push("Current: " + from + " -> " + to)
    }
    TypeCannotBeAssignedToType(_, to) => {
      fixes.push(
        "Ensure the source type has all required properties of '" + to + "'.",
      )
      fixes.push("")
      fixes.push("Or use a type assertion if you're certain:")
      fixes.push("    value as " + to)
    }
    TypeMissingPropertiesFromType(_, _, props) => {
      fixes.push("Add the missing properties to your object:")
      for prop in props {
        fixes.push("    " + prop + ": /* value */,")
      }
    }
    TypeMissingPropertiesAndMore(_, _, props, more) => {
      fixes.push("Add the missing properties. First few:")
      for prop in props {
        fixes.push("    " + prop + ": /* value */,")
      }
      fixes.push("    // ... and " + more.to_string() + " more properties")
    }
    TypeDoesNotSatisfyConstraintAlt(typ, constraint) => {
      fixes.push(
        "Ensure type '" +
        typ +
        "' implements all requirements of '" +
        constraint +
        "'.",
      )
      fixes.push("Check that all required properties and methods exist.")
    }
    TypeNotAssignableSameNameDifferentTypes(_, _, _) => {
      fixes.push(
        "These types have the same name but come from different sources.",
      )
      fixes.push("Options:")
      fixes.push("  1. Import from the same source")
      fixes.push("  2. Use type aliases to distinguish them")
      fixes.push("  3. Consolidate type definitions to a single source")
    }
    TypeNotAssignableGeneric(_, to) => {
      fixes.push("Ensure all properties match the expected type '" + to + "'.")
      fixes.push("")
      fixes.push("Or use a type assertion:")
      fixes.push("    value as " + to)
    }
    PropertyTypesIncompatibleAlt(prop, type1, type2) => {
      fixes.push("Property '" + prop + "' must have compatible types.")
      fixes.push(
        "Change from '" + type1 + "' to '" + type2 + "' or vice versa.",
      )
      fixes.push("")
      fixes.push("Or use a union type: " + type1 + " | " + type2)
    }
    // Operator & Expression errors
    InstanceofLeftNotObject(typ) => {
      fixes.push("The left side of 'instanceof' must be an object type.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("Option 1: Check your type narrowing logic")
      fixes.push("Option 2: Use typeof for primitives:")
      fixes.push("    if (typeof x === 'string') { ... }")
    }
    InstanceofRightNotFunction(typ) => {
      fixes.push("The right side of 'instanceof' must be a constructor.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("Use a class or constructor function:")
      fixes.push("    x instanceof MyClass")
      fixes.push("    x instanceof Array")
    }
    ConditionAlwaysSameValue(_, _) => {
      fixes.push(
        "This comparison can never succeed/fail due to type incompatibility.",
      )
      fixes.push("")
      fixes.push("Options:")
      fixes.push("  1. Check if your types are correct")
      fixes.push("  2. Widen one of the types if needed")
      fixes.push("  3. Remove the unnecessary check")
    }
    LeftSideCommaUnused(expr) => {
      fixes.push("The expression '" + expr + "' has no effect.")
      fixes.push("")
      fixes.push("Options:")
      fixes.push("  1. Remove the left side if it's not needed")
      fixes.push("  2. If it has side effects, use a separate statement")
      fixes.push("  3. Check for missing operators (did you mean &&?)")
    }
    CannotUseInOperator(key, typ) => {
      fixes.push("The 'in' operator requires an object on the right side.")
      fixes.push("You have: '" + key + "' in " + typ)
      fixes.push("")
      fixes.push("Options:")
      fixes.push("  1. Check if the value is an object first")
      fixes.push("  2. Use optional chaining: obj?." + key)
      fixes.push("  3. Use typeof for type checking primitives")
    }
    ConditionAlwaysTrueFunction(name) => {
      fixes.push("You're checking if a function exists, not its return value.")
      fixes.push("")
      fixes.push("Did you mean to call the function?")
      fixes.push("    if (" + name + "()) { ... }")
      fixes.push("")
      fixes.push("Or check the return value:")
      fixes.push("    const result = " + name + "();")
      fixes.push("    if (result) { ... }")
    }
    ConditionAlwaysTrue(_) => {
      fixes.push("This value is always defined, so the check is redundant.")
      fixes.push("")
      fixes.push("Options:")
      fixes.push("  1. Remove the unnecessary null check")
      fixes.push("  2. Check if strictNullChecks is enabled")
      fixes.push(
        "  3. If the type should be nullable, update the type annotation",
      )
    }
    OperatorCannotBeApplied(op, left, right) => {
      fixes.push("Operator '" + op + "' is not valid for these types.")
      fixes.push("Left: " + left + ", Right: " + right)
      fixes.push("")
      fixes.push("Options:")
      fixes.push("  1. Convert operands to compatible types")
      fixes.push("  2. Use a different operator")
      fixes.push("  3. Check if you're using the intended types")
    }
    BigIntLiteralsNotAvailable => {
      fixes.push("BigInt literals require ES2020 or later target.")
      fixes.push("")
      fixes.push("Update your tsconfig.json:")
      fixes.push("    { \"compilerOptions\": { \"target\": \"ES2020\" } }")
      fixes.push("")
      fixes.push("Or use BigInt constructor:")
      fixes.push("    const big = BigInt(123);")
    }
    // Function & Parameter errors
    TypeParamNameCannotBe(name) => {
      fixes.push("Choose a different name for your type parameter.")
      fixes.push("'" + name + "' is reserved.")
      fixes.push("")
      fixes.push("Common conventions:")
      fixes.push("    T, U, V for general types")
      fixes.push("    K for keys, V for values")
      fixes.push("    P for props, S for state")
    }
    ParamPropertyOnlyInConstructor(_) => {
      fixes.push("Move the parameter property to the constructor:")
      fixes.push("    class MyClass {")
      fixes.push("        constructor(public prop: Type) { }")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Or declare the property separately:")
      fixes.push("    class MyClass {")
      fixes.push("        prop: Type;")
      fixes.push("        method(prop: Type) { this.prop = prop; }")
      fixes.push("    }")
    }
    RestParamMustBeArray => {
      fixes.push("Change the rest parameter type to an array type:")
      fixes.push("    function fn(...args: number[]): void { }")
      fixes.push("")
      fixes.push("Or use Array<T> syntax:")
      fixes.push("    function fn(...args: Array<number>): void { }")
    }
    ParamInitializerOnlyInFunctionOrConstructor(_) => {
      fixes.push("Remove the default value from the type declaration.")
      fixes.push("Default values can only appear in implementations.")
      fixes.push("")
      fixes.push("In a type declaration:")
      fixes.push("    function fn(param?: Type): void;")
      fixes.push("")
      fixes.push("In the implementation:")
      fixes.push("    function fn(param: Type = defaultValue) { }")
    }
    ParamCannotReferenceSelf(param) => {
      fixes.push("Parameter '" + param + "' references itself.")
      fixes.push("")
      fixes.push("Options:")
      fixes.push("  1. Use a different variable for the default value")
      fixes.push("  2. Calculate the value inside the function body")
      fixes.push("  3. Use a separate initialization statement")
    }
    OverloadSignaturesAmbientMismatch(name) => {
      fixes.push("Make all overloads for '" + name + "' consistent:")
      fixes.push("")
      fixes.push("Either all ambient (in .d.ts or declare):")
      fixes.push("    declare function " + name + "(x: string): void;")
      fixes.push("    declare function " + name + "(x: number): void;")
      fixes.push("")
      fixes.push("Or all non-ambient with implementation:")
      fixes.push("    function " + name + "(x: string): void;")
      fixes.push("    function " + name + "(x: number): void;")
      fixes.push("    function " + name + "(x: string | number) { }")
    }
    FunctionOverloadMustNotBeStatic(name) => {
      fixes.push("Remove 'static' from the function overload '" + name + "'.")
      fixes.push("")
      fixes.push("For class static methods, use:")
      fixes.push("    class MyClass {")
      fixes.push("        static " + name + "(x: string): void;")
      fixes.push("        static " + name + "(x: number): void;")
      fixes.push("        static " + name + "(x: string | number) { }")
      fixes.push("    }")
    }
    FunctionImplSignatureNotAssignable(name) => {
      fixes.push(
        "Update the implementation of '" + name + "' to handle all overloads.",
      )
      fixes.push("")
      fixes.push("The implementation must accept all parameter combinations:")
      fixes.push("    function " + name + "(x: string): string;")
      fixes.push("    function " + name + "(x: number): number;")
      fixes.push(
        "    function " + name + "(x: string | number): string | number {",
      )
      fixes.push("        return x;")
      fixes.push("    }")
    }
    ConstructorImplMissing(class_name) => {
      fixes.push("Add a constructor implementation for '" + class_name + "':")
      fixes.push("")
      fixes.push("    class " + class_name + " {")
      fixes.push("        constructor(x: string);")
      fixes.push("        constructor(x: number);")
      fixes.push("        constructor(x: string | number) {")
      fixes.push("            // Implementation here")
      fixes.push("        }")
      fixes.push("    }")
    }
    IndividualDeclarationsMustMatch(name, _) => {
      fixes.push("Make all declarations of '" + name + "' consistent:")
      fixes.push("")
      fixes.push("Either all exported:")
      fixes.push("    export interface " + name + " { ... }")
      fixes.push("    export interface " + name + " { ... }")
      fixes.push("")
      fixes.push("Or all local (not exported):")
      fixes.push("    interface " + name + " { ... }")
      fixes.push("    interface " + name + " { ... }")
    }
    RequiredTypeParamAfterOptional(param) => {
      fixes.push("Reorder type parameters so required ones come first:")
      fixes.push("")
      fixes.push("Before: <T = Default, " + param + ">")
      fixes.push("After:  <" + param + ", T = Default>")
      fixes.push("")
      fixes.push("Required parameters must precede optional ones.")
    }
    GenericTypeRequiresTypeArgs(name, min, max) => {
      fixes.push("Provide the correct number of type arguments:")
      fixes.push("")
      if min == max {
        fixes.push(
          "    " +
          name +
          "<Type1" +
          (if max > 1 { ", Type2" } else { "" }) +
          ">",
        )
      } else {
        fixes.push("    " + name + "<Type1>  // minimum " + min.to_string())
        fixes.push(
          "    " + name + "<Type1, Type2, ...>  // up to " + max.to_string(),
        )
      }
    }
    // For-in/For-of errors
    ForInLeftMustBeVariable(_) => {
      fixes.push("Use a variable declaration or simple variable:")
      fixes.push("")
      fixes.push("With let/const:")
      fixes.push("    for (let key in obj) { ... }")
      fixes.push("    for (const key in obj) { ... }")
      fixes.push("")
      fixes.push("With existing variable:")
      fixes.push("    let key: string;")
      fixes.push("    for (key in obj) { ... }")
    }
    ForInRightMustBeObject(typ) => {
      fixes.push("The right side of for...in must be an object.")
      fixes.push("You have type: " + typ)
      fixes.push("")
      fixes.push("Valid examples:")
      fixes.push("    for (const key in myObject) { ... }")
      fixes.push("    for (const key in { a: 1, b: 2 }) { ... }")
      fixes.push("")
      fixes.push("For arrays, consider using for...of instead:")
      fixes.push("    for (const item of myArray) { ... }")
    }
    ForOfLeftMustBeVariable(_) => {
      fixes.push("Use a variable declaration or simple variable:")
      fixes.push("")
      fixes.push("With let/const:")
      fixes.push("    for (let item of array) { ... }")
      fixes.push("    for (const item of array) { ... }")
      fixes.push("")
      fixes.push("With destructuring:")
      fixes.push("    for (const [key, value] of entries) { ... }")
      fixes.push("    for (const { name, age } of people) { ... }")
    }
    // Property & Index errors
    TypeHasNoPropertyAndNoStringIndex(typ, prop) => {
      fixes.push("Option 1: Add the property to the type definition:")
      fixes.push("    interface MyType {")
      fixes.push("        " + prop + ": SomeType;")
      fixes.push("    }")
      fixes.push("")
      fixes.push(
        "Option 2: Add a string index signature to allow arbitrary properties:",
      )
      fixes.push("    interface MyType {")
      fixes.push("        [key: string]: any;")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 3: Check if '" + prop + "' is spelled correctly.")
    }
    TypeIsNotArrayType(typ) => {
      fixes.push("Ensure the value is an array type.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("For array destructuring:")
      fixes.push("    const arr: number[] = [1, 2, 3];")
      fixes.push("    const [first, second] = arr;")
      fixes.push("")
      fixes.push("For spread operations:")
      fixes.push("    const combined = [...arr1, ...arr2];")
    }
    TypeCannotBeUsedAsIndex(typ) => {
      fixes.push("Use a valid index type: string, number, or symbol.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("Convert to a valid index type:")
      fixes.push("    obj[String(value)]  // convert to string")
      fixes.push("    obj[Number(value)]  // convert to number")
      fixes.push("")
      fixes.push("Or use a type assertion if you're certain:")
      fixes.push("    obj[value as string]")
    }
    IndexSignatureOnlyPermitsReading(typ) => {
      fixes.push("The index signature is readonly and cannot be modified.")
      fixes.push("")
      fixes.push("Option 1: Remove 'readonly' from the index signature:")
      fixes.push("    interface Writable {")
      fixes.push("        [key: string]: SomeType;  // without readonly")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 2: Create a mutable copy of the object:")
      fixes.push("    const mutable = { ...readonly };")
    }
    IndexSignatureParamTypeMustBe(typ) => {
      fixes.push("Index signature parameter must be string, number, or symbol.")
      fixes.push("Invalid type: " + typ)
      fixes.push("")
      fixes.push("Valid index signatures:")
      fixes.push("    [key: string]: ValueType")
      fixes.push("    [index: number]: ValueType")
      fixes.push("    [sym: symbol]: ValueType")
      fixes.push("")
      fixes.push("For template literal types:")
      fixes.push("    [key: `prefix_${string}`]: ValueType")
    }
    PropertyUsedBeforeInit(prop) => {
      fixes.push("Initialize the property before using it:")
      fixes.push("")
      fixes.push("In a class constructor:")
      fixes.push("    class MyClass {")
      fixes.push("        " + prop + ": SomeType;")
      fixes.push("        constructor() {")
      fixes.push(
        "            this." + prop + " = initialValue; // Initialize first",
      )
      fixes.push("            this.use" + prop + "(); // Then use")
      fixes.push("        }")
      fixes.push("    }")
      fixes.push("")
      fixes.push(
        "Or use the definite assignment assertion (!) if you're certain:",
      )
      fixes.push("    " + prop + "!: SomeType;")
    }
    PropertyIncompatibleWithIndexSig(prop, prop_type, index_type) => {
      fixes.push(
        "Property '" + prop + "' type must be assignable to index type.",
      )
      fixes.push("")
      fixes.push("Option 1: Change the property type to match the index:")
      fixes.push("    interface Fixed {")
      fixes.push("        [key: string]: " + index_type + ";")
      fixes.push(
        "        " + prop + ": " + index_type + ";  // compatible type",
      )
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 2: Widen the index signature type:")
      fixes.push("    [key: string]: " + prop_type + " | " + index_type + ";")
    }
    PropertyHasConflictingDeclarations(prop) => {
      fixes.push("Resolve the conflicting declarations of '" + prop + "':")
      fixes.push("")
      fixes.push("Ensure all interfaces/types declare the same type:")
      fixes.push("    interface A { " + prop + ": string; }")
      fixes.push(
        "    interface B extends A { " + prop + ": string; }  // same type",
      )
      fixes.push("")
      fixes.push(
        "Or use compatible types (e.g., narrower in derived interface):",
      )
      fixes.push("    interface A { " + prop + ": string | number; }")
      fixes.push(
        "    interface B extends A { " + prop + ": string; }  // narrower OK",
      )
    }
    NewExprTargetLacksConstructSig(_typ) => {
      fixes.push("Ensure the target has a construct signature:")
      fixes.push("")
      fixes.push("Use a class:")
      fixes.push("    class MyClass { }")
      fixes.push("    const instance = new MyClass();")
      fixes.push("")
      fixes.push("Or add a construct signature to the type:")
      fixes.push("    interface Constructor {")
      fixes.push("        new(): SomeType;")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Or call as a function if not a constructor:")
      fixes.push("    const result = myFunc();  // without 'new'")
    }
    CannotAccessBeforeInit(name) => {
      fixes.push("Initialize '" + name + "' before accessing it:")
      fixes.push("")
      fixes.push("For class fields, assign in constructor before use:")
      fixes.push("    class MyClass {")
      fixes.push("        " + name + ": SomeType;")
      fixes.push("        constructor() {")
      fixes.push("            this." + name + " = value;  // assign first")
      fixes.push("        }")
      fixes.push("    }")
      fixes.push("")
      fixes.push("For let/const variables, ensure declaration is before use:")
      fixes.push("    let " + name + " = value;  // initialize")
      fixes.push("    console.log(" + name + ");  // then access")
    }
    PropertyCanOnlyBeAssignedWithThis(prop) => {
      fixes.push("Assign readonly property using 'this' access:")
      fixes.push("")
      fixes.push("In the constructor:")
      fixes.push("    class MyClass {")
      fixes.push("        readonly " + prop + ": SomeType;")
      fixes.push("        constructor(value: SomeType) {")
      fixes.push(
        "            this." + prop + " = value;  // direct 'this' access",
      )
      fixes.push("        }")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Cannot use destructuring for readonly properties:")
      fixes.push("    // This won't work:")
      fixes.push("    // const { " + prop + " } = this; " + prop + " = value;")
    }
    // Array & Iteration errors
    TypeNotArrayOrString(typ) => {
      fixes.push("Ensure the value is an array or string type.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("For spreading into an array:")
      fixes.push("    const arr = [...someArray];  // works with arrays")
      fixes.push("    const chars = [...someString];  // works with strings")
      fixes.push("")
      fixes.push("Convert to array if needed:")
      fixes.push("    Array.from(iterable)")
    }
    TypeNotArrayOrStringDownlevel(typ) => {
      fixes.push("Enable '--downlevelIteration' in tsconfig.json:")
      fixes.push("    {")
      fixes.push("        \"compilerOptions\": {")
      fixes.push("            \"downlevelIteration\": true")
      fixes.push("        }")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Or convert to array first:")
      fixes.push("    Array.from(" + typ + ")  // converts iterable to array")
    }
    PropertyDoesNotExistDidYouMean(prop, _, suggestion) => {
      fixes.push("Did you mean '" + suggestion + "' instead of '" + prop + "'?")
      fixes.push("")
      fixes.push("Check for typos - property names are case-sensitive:")
      fixes.push("    obj." + suggestion + "  // correct")
      fixes.push("    obj." + prop + "  // typo")
      fixes.push("")
      fixes.push("If the property should exist, add it to the type definition.")
    }
    CannotFindNameDidYouMean(name, suggestion) => {
      fixes.push("Did you mean '" + suggestion + "' instead of '" + name + "'?")
      fixes.push("")
      fixes.push("Check for typos in variable/function names:")
      fixes.push("    " + suggestion + "  // correct")
      fixes.push("    " + name + "  // typo")
      fixes.push("")
      fixes.push("Or import the missing name if it's from another module.")
    }
    ExpectedNArgsButGotMore(expected, actual) => {
      fixes.push(
        "The function expects at most " + expected.to_string() + " arguments.",
      )
      fixes.push("You provided " + actual.to_string() + " arguments.")
      fixes.push("")
      fixes.push("Remove extra arguments or use a rest parameter:")
      fixes.push("    function fn(a: number, b: number, ...rest: number[]) { }")
    }
    RestElementTypeMustBeArray(typ) => {
      fixes.push("Rest elements must be array types.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("Change to an array type:")
      fixes.push("    function fn(...args: string[]) { }  // correct")
      fixes.push("    const [first, ...rest]: [number, ...number[]] = tuple;")
      fixes.push("")
      fixes.push("Or convert to array:")
      fixes.push("    const arr = Array.from(iterable);")
    }
    NoOverloadExpectsNArgs(n) => {
      fixes.push(
        "No function overload accepts " + n.to_string() + " arguments.",
      )
      fixes.push("")
      fixes.push("Check the function's type definitions for valid signatures:")
      fixes.push("    function fn(a: string): void;")
      fixes.push("    function fn(a: string, b: number): void;")
      fixes.push("")
      fixes.push("Match one of the available overloads.")
    }
    TypeCanOnlyBeIteratedWithDownlevel(typ) => {
      fixes.push("Enable '--downlevelIteration' in tsconfig.json:")
      fixes.push("    {")
      fixes.push("        \"compilerOptions\": {")
      fixes.push("            \"downlevelIteration\": true")
      fixes.push("        }")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Or target ES2015+ which supports iteration natively:")
      fixes.push("    \"target\": \"ES2015\"")
      fixes.push("")
      fixes.push("Or convert to array: Array.from(" + typ + ")")
    }
    // Spread & Rest errors
    PropertyUsedBeforeAssigned(prop) => {
      fixes.push("Initialize the property before using it:")
      fixes.push("")
      fixes.push("Option 1: Assign in the declaration:")
      fixes.push("    class MyClass {")
      fixes.push("        " + prop + " = initialValue;")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 2: Assign in constructor before use:")
      fixes.push("    constructor() {")
      fixes.push("        this." + prop + " = value;")
      fixes.push("        this.use" + prop + "();  // now safe")
      fixes.push("    }")
    }
    RestElementCannotContainBindingPattern => {
      fixes.push("Use a simple identifier for the rest element:")
      fixes.push("")
      fixes.push("Instead of:")
      fixes.push("    const [first, ...{ a, b }] = arr;  // error")
      fixes.push("")
      fixes.push("Use:")
      fixes.push("    const [first, ...rest] = arr;")
      fixes.push("    const { a, b } = rest;  // separate destructuring")
    }
    RestTypesMustBeFromObjectTypes(typ) => {
      fixes.push("Ensure the type being spread is an object type.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("Rest types require object types:")
      fixes.push("    type Valid = { ...T };  // T must be an object type")
      fixes.push("")
      fixes.push("Use a constraint if needed:")
      fixes.push("    type Spread<T extends object> = { ...T };")
    }
    ObjectRestAssignmentMustBeVariable(target) => {
      fixes.push("Use a variable as the rest target:")
      fixes.push("Invalid target: " + target)
      fixes.push("")
      fixes.push("Valid examples:")
      fixes.push("    const { a, ...rest } = obj;  // rest is a variable")
      fixes.push(
        "    const { a, ...obj.prop } = source;  // property access OK",
      )
      fixes.push("")
      fixes.push("Invalid:")
      fixes.push(
        "    const { a, ...fn() } = obj;  // function call not allowed",
      )
    }
    ObjectRestAssignmentNotOptional(prop) => {
      fixes.push("Remove the optional modifier from the rest element:")
      fixes.push("")
      fixes.push("Instead of:")
      fixes.push("    const { a, ..." + prop + "? } = obj;  // error")
      fixes.push("")
      fixes.push("Use:")
      fixes.push("    const { a, ..." + prop + " } = obj;  // correct")
      fixes.push("")
      fixes.push("Rest elements always collect remaining properties.")
    }
    SpreadTypesMustBeFromObjectTypes(typ) => {
      fixes.push("Ensure the type being spread is an object type.")
      fixes.push("Current type: " + typ)
      fixes.push("")
      fixes.push("Valid spread types:")
      fixes.push("    type A = { x: number };")
      fixes.push("    type B = { ...A, y: string };  // OK")
      fixes.push("")
      fixes.push("Use a constraint for generics:")
      fixes.push("    type Extend<T extends object> = { ...T, extra: number };")
    }
    // Async/Generator/Yield errors
    YieldExpressionImplicitlyAny => {
      fixes.push("Add a return type annotation to your generator function:")
      fixes.push("")
      fixes.push(
        "    function* myGenerator(): Generator<number, void, unknown> {",
      )
      fixes.push("        yield 1;")
      fixes.push("        yield 2;")
      fixes.push("    }")
      fixes.push("")
      fixes.push("The Generator<Y, R, N> type parameters are:")
      fixes.push("    Y = type of yielded values")
      fixes.push("    R = return type of the generator")
      fixes.push("    N = type passed to next() method")
    }
    YieldOperandTypeInAsyncGenerator(operand_type, _) => {
      fixes.push(
        "In an async generator, the yield operand must be a valid promise",
      )
      fixes.push("or not have a callable 'then' member.")
      fixes.push("")
      fixes.push("Current operand type: " + operand_type)
      fixes.push("")
      fixes.push("Option 1: Remove the 'then' member from the type")
      fixes.push("Option 2: Ensure the type is a proper Promise<T>")
      fixes.push("Option 3: Wrap the value: yield Promise.resolve(value)")
    }
    TypeReferencedInThenMethod(type_name) => {
      fixes.push("A circular type reference was detected in the promise chain.")
      fixes.push("Type: " + type_name)
      fixes.push("")
      fixes.push("Check your promise type definitions for self-references:")
      fixes.push("    // Problematic - T references itself through then()")
      fixes.push("    type T = Promise<T>;")
      fixes.push("")
      fixes.push("Option 1: Break the circular reference")
      fixes.push("Option 2: Use a different type structure")
    }
    // Enum & Catch Clause errors
    CatchClauseVariableMustBeAnyOrUnknown(var_name) => {
      fixes.push(
        "Catch clause variable '" +
        var_name +
        "' must have type 'any' or 'unknown'.",
      )
      fixes.push("")
      fixes.push(
        "Option 1: Use 'unknown' (recommended - requires type narrowing):",
      )
      fixes.push("    try { ... } catch (e: unknown) {")
      fixes.push("        if (e instanceof Error) {")
      fixes.push("            console.log(e.message);")
      fixes.push("        }")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 2: Use 'any' (less safe but allows any operations):")
      fixes.push("    try { ... } catch (e: any) { ... }")
      fixes.push("")
      fixes.push("Option 3: Remove the type annotation (defaults to 'any'):")
      fixes.push("    try { ... } catch (e) { ... }")
    }
    ConstEnumUsageRestriction(enum_name) => {
      fixes.push(
        "Const enum '" + enum_name + "' cannot be used with dynamic access.",
      )
      fixes.push("")
      fixes.push(
        "Const enums are inlined at compile time, so they don't exist at runtime.",
      )
      fixes.push("")
      fixes.push("Option 1: Use literal member access:")
      fixes.push("    const value = MyEnum.MemberName;")
      fixes.push("")
      fixes.push("Option 2: Convert to a regular enum (removes const):")
      fixes.push("    enum MyEnum { ... }  // instead of const enum")
      fixes.push("")
      fixes.push(
        "Option 3: Use 'preserveConstEnums' compiler option to keep the enum object",
      )
    }
    ConstEnumMemberAccessRestriction(mem) => {
      fixes.push(
        "Const enum member '" +
        mem +
        "' must be accessed with a string literal.",
      )
      fixes.push("")
      fixes.push(
        "Because const enums are replaced with literal values during compilation,",
      )
      fixes.push("dynamic access like enum[variable] is not possible.")
      fixes.push("")
      fixes.push("Option 1: Use direct member access:")
      fixes.push("    const val = MyEnum.Member;  // ✓ allowed")
      fixes.push("")
      fixes.push("Option 2: Use a regular enum instead of const enum")
      fixes.push("")
      fixes.push("Option 3: Create a lookup object manually:")
      fixes.push("    const lookup = { A: 0, B: 1 } as const;")
    }
    UsingPrivateName(private_name, context) => {
      fixes.push(
        "Private name '#" +
        private_name +
        "' cannot be used as a type for '" +
        context +
        "'.",
      )
      fixes.push("")
      fixes.push(
        "Private class members (starting with #) are implementation details",
      )
      fixes.push("and cannot be exposed in type annotations.")
      fixes.push("")
      fixes.push("Option 1: Use a public type instead:")
      fixes.push("    class MyClass {")
      fixes.push("        private _data: DataType;  // Use TypeScript private")
      fixes.push("        public getData(): DataType { ... }")
      fixes.push("    }")
      fixes.push("")
      fixes.push(
        "Option 2: Extract the type to a separate interface or type alias",
      )
    }
    MemberInitializerForwardReference(mem, referenced) => {
      fixes.push(
        "Enum member '" +
        mem +
        "' cannot reference '" +
        referenced +
        "' declared after it.",
      )
      fixes.push("")
      fixes.push(
        "Enum members are evaluated in declaration order. Earlier members",
      )
      fixes.push("cannot reference later ones because they don't exist yet.")
      fixes.push("")
      fixes.push(
        "Option 1: Reorder enum members so referenced members come first:",
      )
      fixes.push("    enum MyEnum {")
      fixes.push("        " + referenced + " = 1,  // Move this first")
      fixes.push(
        "        " + mem + " = " + referenced + ",  // Now it can reference",
      )
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 2: Use explicit values instead of references:")
      fixes.push("    enum MyEnum {")
      fixes.push("        " + mem + " = 1,  // Use literal value")
      fixes.push("        " + referenced + " = 1,")
      fixes.push("    }")
    }
    // Module & Export errors
    ExportDeclarationConflicts(name, _) => {
      fixes.push(
        "Export declaration for '" + name + "' conflicts with another export.",
      )
      fixes.push("")
      fixes.push("Option 1: Remove the duplicate export:")
      fixes.push("    export { " + name + " };  // Keep only one export")
      fixes.push("")
      fixes.push("Option 2: Rename one of the exports:")
      fixes.push("    export { " + name + " as " + name + "Alt };")
      fixes.push("")
      fixes.push("Option 3: Consolidate exports into a single statement")
    }
    ArgumentsObjectCannotBeReferenced(context) => {
      fixes.push("The 'arguments' object cannot be used in " + context + ".")
      fixes.push("")
      fixes.push("Arrow functions don't have their own 'arguments' binding.")
      fixes.push("")
      fixes.push("Option 1: Use rest parameters instead:")
      fixes.push("    const fn = (...args) => {")
      fixes.push("        console.log(args);  // Array of all arguments")
      fixes.push("    };")
      fixes.push("")
      fixes.push("Option 2: Convert to a regular function:")
      fixes.push("    function fn() {")
      fixes.push("        console.log(arguments);")
      fixes.push("    }")
    }
    ModuleCanOnlyBeReferencedWithESImport(module_name) => {
      fixes.push(
        "Module '" + module_name + "' requires ES module import syntax.",
      )
      fixes.push("")
      fixes.push("Option 1: Use default import with esModuleInterop:")
      fixes.push("    import " + module_name + " from '" + module_name + "';")
      fixes.push("")
      fixes.push("Option 2: Use namespace import:")
      fixes.push(
        "    import * as " + module_name + " from '" + module_name + "';",
      )
      fixes.push("")
      fixes.push("Option 3: Enable esModuleInterop in tsconfig.json:")
      fixes.push("    { \"compilerOptions\": { \"esModuleInterop\": true } }")
    }
    ReferencedInOwnBaseExpression(name) => {
      fixes.push(
        "'" + name + "' cannot reference itself in its base expression.",
      )
      fixes.push("")
      fixes.push("A class or type cannot extend itself directly or indirectly.")
      fixes.push("")
      fixes.push("Option 1: Remove the self-reference:")
      fixes.push("    class " + name + " { /* don't extend " + name + " */ }")
      fixes.push("")
      fixes.push("Option 2: Create a separate base class:")
      fixes.push("    class Base { ... }")
      fixes.push("    class " + name + " extends Base { ... }")
    }
    InferredTypeReferencesInaccessible(name, inaccessible) => {
      fixes.push(
        "The inferred type of '" +
        name +
        "' references inaccessible type '" +
        inaccessible +
        "'.",
      )
      fixes.push("")
      fixes.push(
        "Option 1: Add an explicit type annotation with a public type:",
      )
      fixes.push("    export const " + name + ": PublicType = ...;")
      fixes.push("")
      fixes.push("Option 2: Make the referenced type public/exported:")
      fixes.push("    export type " + inaccessible + " = ...;")
      fixes.push("")
      fixes.push("Option 3: Use a type that doesn't depend on internal types")
    }
    CannotAugmentModule(module_name) => {
      fixes.push(
        "Cannot augment module '" + module_name + "' with value exports.",
      )
      fixes.push("")
      fixes.push(
        "Module augmentation only works with ES modules or namespaces.",
      )
      fixes.push("")
      fixes.push("Option 1: Ensure the target is a proper module:")
      fixes.push("    // The module should have import/export statements")
      fixes.push("")
      fixes.push("Option 2: Use a different augmentation approach:")
      fixes.push("    declare module '" + module_name + "' {")
      fixes.push("        // Only add type declarations, not values")
      fixes.push("    }")
    }
    RefersToUMDGlobal(name) => {
      fixes.push(
        "'" + name + "' refers to a UMD global but this file is a module.",
      )
      fixes.push("")
      fixes.push("In modules, UMD globals must be imported explicitly.")
      fixes.push("")
      fixes.push("Option 1: Import the module:")
      fixes.push("    import " + name + " from '" + name + "';")
      fixes.push("")
      fixes.push("Option 2: Import as namespace:")
      fixes.push("    import * as " + name + " from '" + name + "';")
      fixes.push("")
      fixes.push(
        "Option 3: If you need the global, remove import/export to make this a script",
      )
    }
    DeclarationsMustHaveIdenticalModifiers(name) => {
      fixes.push(
        "All declarations of '" + name + "' must have identical modifiers.",
      )
      fixes.push("")
      fixes.push("When merging declarations, modifiers must be consistent.")
      fixes.push("")
      fixes.push(
        "Option 1: Make all declarations have the same export modifier:",
      )
      fixes.push("    export interface " + name + " { ... }")
      fixes.push("    export interface " + name + " { ... }  // Both exported")
      fixes.push("")
      fixes.push("Option 2: Or make all declarations local:")
      fixes.push("    interface " + name + " { ... }")
      fixes.push("    interface " + name + " { ... }  // Both local")
    }
    CannotFindTypeDefinitionFile(name) => {
      fixes.push("Cannot find type definition file for '" + name + "'.")
      fixes.push("")
      fixes.push("Option 1: Install the @types package:")
      fixes.push("    npm install --save-dev @types/" + name)
      fixes.push("")
      fixes.push("Option 2: Create a custom type declaration file:")
      fixes.push("    // " + name + ".d.ts")
      fixes.push("    declare module '" + name + "' {")
      fixes.push("        // Add type declarations here")
      fixes.push("    }")
      fixes.push("")
      fixes.push("Option 3: Add the types to tsconfig.json typeRoots")
    }
    // Type Complexity & Inference errors
    PropertyIsStaticMemberOfType(prop, type_name) => {
      fixes.push(
        "Property '" + prop + "' is a static member of '" + type_name + "'.",
      )
      fixes.push("")
      fixes.push(
        "Static members are accessed on the class itself, not on instances.",
      )
      fixes.push("")
      fixes.push("Option 1: Access it on the class directly:")
      fixes.push("    " + type_name + "." + prop + "  // ✓ correct")
      fixes.push("")
      fixes.push("Option 2: If you have an instance, use the constructor:")
      fixes.push("    instance.constructor." + prop)
      fixes.push("")
      fixes.push(
        "Option 3: If this should be an instance member, remove 'static' from the declaration",
      )
    }
    UnusedTsExpectErrorDirective => {
      fixes.push(
        "The '@ts-expect-error' directive is unused - no error on the following line.",
      )
      fixes.push("")
      fixes.push("Option 1: Remove the directive if the error was fixed:")
      fixes.push("    // @ts-expect-error  <-- remove this line")
      fixes.push("")
      fixes.push("Option 2: Check if the error is on a different line")
      fixes.push("")
      fixes.push(
        "Option 3: If you're suppressing a potential future error, use @ts-ignore instead",
      )
    }
    CannotFindNameTestRunner(name) => {
      fixes.push(
        "Cannot find name '" +
        name +
        "'. This is typically a test runner global.",
      )
      fixes.push("")
      fixes.push("Option 1: Install type definitions for your test framework:")
      fixes.push("    npm install --save-dev @types/jest      // for Jest")
      fixes.push("    npm install --save-dev @types/mocha     // for Mocha")
      fixes.push("    npm install --save-dev @types/jasmine   // for Jasmine")
      fixes.push("")
      fixes.push("Option 2: Add types to tsconfig.json:")
      fixes.push("    { \"compilerOptions\": { \"types\": [\"jest\"] } }")
    }
    CannotFindNameTargetLibrary(name, target) => {
      fixes.push("Cannot find name '" + name + "'. Current target: " + target)
      fixes.push("")
      fixes.push("Option 1: Change target in tsconfig.json:")
      fixes.push("    { \"compilerOptions\": { \"target\": \"ES2020\" } }")
      fixes.push("")
      fixes.push("Option 2: Add lib entries to include the feature:")
      fixes.push(
        "    { \"compilerOptions\": { \"lib\": [\"ES2020\", \"DOM\"] } }",
      )
      fixes.push("")
      fixes.push("Option 3: Use a polyfill for older targets")
    }
    CannotFindNameTargetLibraryAlt(name, target) => {
      fixes.push(
        "Cannot find name '" + name + "'. Not available in target: " + target,
      )
      fixes.push("")
      fixes.push("Option 1: Update your compilation target:")
      fixes.push("    { \"compilerOptions\": { \"target\": \"ESNext\" } }")
      fixes.push("")
      fixes.push("Option 2: Include additional lib entries:")
      fixes.push("    { \"compilerOptions\": { \"lib\": [\"ESNext\"] } }")
      fixes.push("")
      fixes.push("Option 3: Check if a polyfill is available for this feature")
    }
    ExpressionProducesUnionTooComplex => {
      fixes.push("The union type is too complex for TypeScript to represent.")
      fixes.push("")
      fixes.push(
        "Option 1: Simplify the type by breaking it into smaller parts:",
      )
      fixes.push("    type Part1 = A | B | C;")
      fixes.push("    type Part2 = D | E | F;")
      fixes.push("    type Combined = Part1 | Part2;")
      fixes.push("")
      fixes.push("Option 2: Use a more general type:")
      fixes.push(
        "    type Result = string | number;  // instead of literal unions",
      )
      fixes.push("")
      fixes.push(
        "Option 3: Review recursive types that might expand infinitely",
      )
    }
    CannotImportTypeDeclarationFiles(file) => {
      fixes.push("Cannot import type declaration file '" + file + "' directly.")
      fixes.push("")
      fixes.push("Option 1: Import from the JavaScript module instead:")
      fixes.push("    import { Type } from 'module';  // not 'module.d.ts'")
      fixes.push("")
      fixes.push("Option 2: Use type-only import if you only need types:")
      fixes.push("    import type { Type } from 'module';")
      fixes.push("")
      fixes.push(
        "Option 3: Use triple-slash reference for ambient declarations:",
      )
      fixes.push("    /// <reference types=\"module\" />")
    }
    InferredTypeCannotBeNamed(name, reference) => {
      fixes.push(
        "The inferred type of '" +
        name +
        "' cannot be named without '" +
        reference +
        "'.",
      )
      fixes.push("")
      fixes.push("Option 1: Add an explicit type annotation:")
      fixes.push("    export function " + name + "(): ExplicitType { ... }")
      fixes.push("")
      fixes.push("Option 2: Export the referenced type:")
      fixes.push("    export { " + reference + " } from './module';")
      fixes.push("")
      fixes.push("Option 3: Re-export the module that contains the type")
    }
  }
  fixes
}

///|
/// Get the appropriate TypeScript error code for a mismatch reason
pub fn get_error_code(reason : MismatchReason) -> Int {
  match reason {
    IncompatibleTypes
    | PropertyTypeMismatch(_)
    | LiteralMismatch(_, _)
    | LiteralToWide => 2322
    MissingProperty(_)
    | ExcessProperty(_)
    | OptionalToRequired(_)
    | IndexSignatureMismatch => 2322
    ParamCountMismatch(_, _) => 2554
    ParamTypeMismatch(_, _) => 2345
    ReturnTypeMismatch => 2355
    NoUnionMemberMatches => 2322
    TypeArgMismatch(_, _) => 2344
    ConstraintNotSatisfied(_, _) => 2344
    CannotInfer(_) => 2558
    ReadonlyMutation(_) => 2588
    NotCallable => 2349
    NotConstructable => 2511
    UnboundVariable(_) | UnboundType(_) => 2304
    CircularReference | ExcessiveDepth => 2322
    IntersectionNotSatisfied(_) => 2322
    NoOverloadMatches(_) | OverloadCandidateFailed(_) => 2769 // TS2769: No overload matches this call
    OverloadNotCompatibleWithImpl(_) => 2394 // TS2394: Overload signature is not compatible with function implementation
    OverloadMissingImplementation(_) => 2391 // TS2391: Function implementation is missing or not immediately following the declaration
    OverloadAmbientMismatch(_) => 2383 // TS2383: Overload signatures must all be ambient or non-ambient
    PrivateMemberAccess(_, _) => 2341 // TS2341: Property 'x' is private
    ProtectedMemberAccess(_, _) => 2445 // TS2445: Property 'x' is protected
    AbstractClassInstantiation(_) => 2511 // TS2511: Cannot create an instance of abstract class
    AbstractMemberNotImplemented(_, _) => 2515 // TS2515: Non-abstract class does not implement inherited abstract member
    OverrideReturnTypeMismatch(_, _)
    | OverrideParamTypeMismatch(_, _, _)
    | OverrideParamCountMismatch(_, _, _) => 2416 // TS2416: Property is not assignable to base type
    OverrideAccessibilityMismatch(_, _, _) => 2415 // TS2415: Class incorrectly extends base class
    // Super call validation
    ThisBeforeSuperCall => 17009 // TS17009: 'super' must be called before accessing 'this'
    SuperCallRequired(_) => 2377 // TS2377: Constructors for derived classes must contain a 'super' call
    SuperCallOutsideConstructor => 2337 // TS2337: 'super' can only be called in a constructor
    SuperPropertyOutsideClass => 2335 // TS2335: 'super' can only be referenced in a derived class
    SuperCallInStaticMethod => 2337 // Reuse TS2337
    SuperPropertyAccess(_) => 2339 // TS2339: Property does not exist on type
    // BigInt errors
    BigIntNumberMixing(_) => 2365 // TS2365: Operator cannot be applied to types
    UnaryPlusBigInt => 2736 // TS2736: Operator '+' cannot be applied to type 'bigint'
    // Module/Import resolution errors
    FileIsNotModule(_) => 2306 // TS2306: File is not a module
    CannotFindModule(_) => 2307 // TS2307: Cannot find module
    CannotFindGlobalType(_) => 2318 // TS2318: Cannot find global type
    ImportPathCannotEndWithExtension(_, _) => 2691 // TS2691: Import path cannot end with extension
    CannotFindModuleOrTypeDeclarations(_) => 2692 // TS2692: Cannot find module or type declarations
    NamespaceHasNoExportedMember(_, _) => 2694 // TS2694: Namespace has no exported member
    CannotUseNamespaceAsType(_) => 2709 // TS2709: Cannot use namespace as type
    CannotUseNamespaceAsValue(_) => 2710 // TS2710: Cannot use namespace as value
    CannotFindModuleSetModuleResolution(_) => 2766 // TS2766: Cannot find module (moduleResolution)
    ModuleHasNoExportedMember(_, _) => 2305 // TS2305: Module has no exported member
    // Type Assignment & Compatibility errors
    InterfaceCannotExtendTypes(_, _) => 2320 // TS2320: Interface cannot simultaneously extend types
    PropertyMissingInType(_, _) => 2324 // TS2324: Property is missing in type
    ParamTypesIncompatible(_, _, _) => 2326 // TS2326: Types of parameters are incompatible
    PropertyTypesIncompatible(_, _, _) => 2328 // TS2328: Types of property are incompatible
    IndexSignatureMissing(_, _) => 2329 // TS2329: Index signature is missing in type
    ThisInStaticProperty(_) => 2334 // TS2334: 'this' cannot be referenced in static property initializer
    TypeDoesNotSatisfyConstraint(_, _) => 2344 // TS2344: Type does not satisfy the constraint
    ValueNoPropertiesInCommon(_, _) => 2348 // TS2348: Value has no properties in common with type
    OnlyVoidFunctionCanBeCalledWithNew(_) => 2350 // TS2350: Only a void function can be called with new
    ConversionMayBeMistake(_, _) => 2352 // TS2352: Conversion may be a mistake
    TypeCannotBeAssignedToType(_, _) => 2717 // TS2717: Type cannot be assigned to type
    TypeMissingPropertiesFromType(_, _, _) => 2739 // TS2739: Type is missing properties from type
    TypeMissingPropertiesAndMore(_, _, _, _) => 2740 // TS2740: Type is missing properties (and more)
    TypeDoesNotSatisfyConstraintAlt(_, _) => 2744 // TS2744: Type does not satisfy constraint
    TypeNotAssignableSameNameDifferentTypes(_, _, _) => 2752 // TS2752: Type not assignable (different types same name)
    TypeNotAssignableGeneric(_, _) => 2757 // TS2757: Type not assignable
    PropertyTypesIncompatibleAlt(_, _, _) => 2758 // TS2758: Types of property incompatible
    // Operator & Expression errors
    InstanceofLeftNotObject(_) => 2358 // TS2358: Left-hand side of instanceof must be object type
    InstanceofRightNotFunction(_) => 2359 // TS2359: Right-hand side of instanceof must be Function type
    ConditionAlwaysSameValue(_, _) => 2367 // TS2367: Condition will always return same value
    LeftSideCommaUnused(_) => 2695 // TS2695: Left side of comma operator unused
    CannotUseInOperator(_, _) => 2772 // TS2772: Cannot use 'in' operator
    ConditionAlwaysTrueFunction(_) => 2773 // TS2773: Condition will always return true (function)
    ConditionAlwaysTrue(_) => 2774 // TS2774: Condition will always return true
    OperatorCannotBeApplied(_, _, _) => 2800 // TS2800: Operator cannot be applied to types
    BigIntLiteralsNotAvailable => 2737 // TS2737: BigInt literals not available
    // Function & Parameter errors
    TypeParamNameCannotBe(_) => 2368 // TS2368: Type parameter name cannot be X
    ParamPropertyOnlyInConstructor(_) => 2369 // TS2369: Parameter property only in constructor
    RestParamMustBeArray => 2370 // TS2370: A rest parameter must be of an array type
    ParamInitializerOnlyInFunctionOrConstructor(_) => 2371 // TS2371: Parameter initializer only in function/constructor
    ParamCannotReferenceSelf(_) => 2372 // TS2372: Parameter cannot reference itself
    OverloadSignaturesAmbientMismatch(_) => 2383 // TS2383: Overload signatures must all be ambient or non-ambient
    FunctionOverloadMustNotBeStatic(_) => 2388 // TS2388: Function overload must not be static
    FunctionImplSignatureNotAssignable(_) => 2389 // TS2389: Function implementation signature must be assignable
    ConstructorImplMissing(_) => 2390 // TS2390: Constructor implementation is missing
    IndividualDeclarationsMustMatch(_, _) => 2395 // TS2395: Individual declarations must be all exported/local
    RequiredTypeParamAfterOptional(_) => 2706 // TS2706: Required type parameters may not follow optional
    GenericTypeRequiresTypeArgs(_, _, _) => 2707 // TS2707: Generic type requires between N and M type arguments
    // For-in/For-of errors
    ForInLeftMustBeVariable(_) => 2406 // TS2406: Left-hand side of for...in must be variable
    ForInRightMustBeObject(_) => 2407 // TS2407: Right-hand side of for...in must be object type
    ForOfLeftMustBeVariable(_) => 2487 // TS2487: Left-hand side of for...of must be variable
    // Property & Index errors
    TypeHasNoPropertyAndNoStringIndex(_, _) => 2459 // TS2459: Type has no property and no string index
    TypeIsNotArrayType(_) => 2460 // TS2460: Type is not an array type
    TypeCannotBeUsedAsIndex(_) => 2538 // TS2538: Type cannot be used as index type
    IndexSignatureOnlyPermitsReading(_) => 2542 // TS2542: Index signature only permits reading
    IndexSignatureParamTypeMustBe(_) => 2716 // TS2716: Index signature parameter type must be string/number/symbol
    PropertyUsedBeforeInit(_) => 2729 // TS2729: Property used before initialization
    PropertyIncompatibleWithIndexSig(_, _, _) => 2745 // TS2745: Property incompatible with index signature
    PropertyHasConflictingDeclarations(_) => 2746 // TS2746: Property has conflicting declarations
    NewExprTargetLacksConstructSig(_) => 2747 // TS2747: new expression target lacks construct signature
    CannotAccessBeforeInit(_) => 2748 // TS2748: Cannot access before initialization
    PropertyCanOnlyBeAssignedWithThis(_) => 2810 // TS2810: Property can only be assigned using 'this'
    // Array & Iteration errors
    TypeNotArrayOrString(_) => 2548 // TS2548: Type is not an array type or a string type
    TypeNotArrayOrStringDownlevel(_) => 2549 // TS2549: Type is not an array type or a string type (downlevelIteration)
    PropertyDoesNotExistDidYouMean(_, _, _) => 2551 // TS2551: Property does not exist, did you mean?
    CannotFindNameDidYouMean(_, _) => 2552 // TS2552: Cannot find name, did you mean?
    ExpectedNArgsButGotMore(_, _) => 2557 // TS2557: Expected N arguments but got more
    RestElementTypeMustBeArray(_) => 2574 // TS2574: A rest element type must be an array type
    NoOverloadExpectsNArgs(_) => 2575 // TS2575: No overload expects N arguments
    TypeCanOnlyBeIteratedWithDownlevel(_) => 2802 // TS2802: Type can only be iterated with downlevelIteration
    // Spread & Rest errors
    PropertyUsedBeforeAssigned(_) => 2565 // TS2565: Property used before being assigned
    RestElementCannotContainBindingPattern => 2566 // TS2566: Rest element cannot contain binding pattern
    RestTypesMustBeFromObjectTypes(_) => 2700 // TS2700: Rest types may only be created from object types
    ObjectRestAssignmentMustBeVariable(_) => 2701 // TS2701: Object rest assignment target must be variable
    ObjectRestAssignmentNotOptional(_) => 2702 // TS2702: Object rest assignment may not be optional
    SpreadTypesMustBeFromObjectTypes(_) => 2762 // TS2762: Spread types may only be created from object types
    // Async/Generator/Yield errors
    YieldExpressionImplicitlyAny => 2764 // TS2764: 'yield' expression implicitly results in an 'any' type
    YieldOperandTypeInAsyncGenerator(_, _) => 2770 // TS2770: Type of yield operand in an async generator
    TypeReferencedInThenMethod(_) => 2771 // TS2771: Type is referenced in the type of the 'then' method
    // Enum & Catch Clause errors
    CatchClauseVariableMustBeAnyOrUnknown(_) => 2467 // TS2467: Catch clause variable type annotation must be 'any' or 'unknown'
    ConstEnumUsageRestriction(_) => 2475 // TS2475: A const enum member can only be accessed using a string literal
    ConstEnumMemberAccessRestriction(_) => 2476 // TS2476: A const enum member can only be accessed using a string literal
    UsingPrivateName(_, _) => 2494 // TS2494: Using private name as type
    MemberInitializerForwardReference(_, _) => 2651 // TS2651: A member initializer cannot reference members declared after it
    // Module & Export errors
    ExportDeclarationConflicts(_, _) => 2484 // TS2484: Export declaration conflicts
    ArgumentsObjectCannotBeReferenced(_) => 2496 // TS2496: The 'arguments' object cannot be referenced
    ModuleCanOnlyBeReferencedWithESImport(_) => 2497 // TS2497: Module can only be referenced with ES import
    ReferencedInOwnBaseExpression(_) => 2502 // TS2502: Referenced in its own base expression
    InferredTypeReferencesInaccessible(_, _) => 2527 // TS2527: Inferred type references inaccessible type
    CannotAugmentModule(_) => 2649 // TS2649: Cannot augment module
    RefersToUMDGlobal(_) => 2686 // TS2686: Refers to UMD global
    DeclarationsMustHaveIdenticalModifiers(_) => 2687 // TS2687: All declarations must have identical modifiers
    CannotFindTypeDefinitionFile(_) => 2688 // TS2688: Cannot find type definition file
    // Type Complexity & Inference errors
    PropertyIsStaticMemberOfType(_, _) => 2576 // TS2576: Property is a static member of type
    UnusedTsExpectErrorDirective => 2578 // TS2578: Unused '@ts-expect-error' directive
    CannotFindNameTestRunner(_) => 2579 // TS2579: Cannot find name (test runner types)
    CannotFindNameTargetLibrary(_, _) => 2580 // TS2580: Cannot find name (target library)
    CannotFindNameTargetLibraryAlt(_, _) => 2584 // TS2584: Cannot find name (target library)
    ExpressionProducesUnionTooComplex => 2590 // TS2590: Expression produces union too complex
    CannotImportTypeDeclarationFiles(_) => 2591 // TS2591: Cannot import type declaration files
    InferredTypeCannotBeNamed(_, _) => 2742 // TS2742: Inferred type cannot be named without reference
  }
}

// ============================================================================
// Elm/Rust-Style Error Formatting
// ============================================================================

///|
/// Format error in Elm/Rust style with helpful context
/// This produces human-friendly output that helps developers understand AND fix the issue
pub fn format_detailed_error(
  error : TypeMismatchError,
  file_path : String,
  line : Int,
  column : Int,
  source_line : String,
) -> String {
  let mut output = ""
  let code = get_error_code(error.reason)

  // ── Header (Elm style) ──────────────────────────────────────────────────
  let title = get_friendly_title(error.reason)
  output = output + "-- " + title + " "
  output = output + string_repeat("-", 60 - title.length()) + " "
  output = output + file_path + "\n\n"

  // ── Location & Code Snippet ─────────────────────────────────────────────
  let line_num_str = line.to_string()
  let padding = string_repeat(" ", line_num_str.length())
  output = output + padding + " |\n"
  output = output + line_num_str + " | " + source_line + "\n"
  output = output + padding + " | " + string_repeat(" ", column - 1) + "^"

  // Add wavy underline for multi-character issues
  output = output + "~~~\n\n"

  // ── What Went Wrong (Rust style) ────────────────────────────────────────
  output = output + "I found a type error:\n\n"
  output = output + "    Expected: " + format_type_v2(error.expected) + "\n"
  output = output + "    Found:    " + format_type_v2(error.actual) + "\n\n"

  // ── Why This Happens (Elm educational style) ────────────────────────────
  output = output + "WHY THIS HAPPENS:\n"
  output = output + "    " + get_why_explanation(error.reason) + "\n\n"

  // ── How To Fix (Rust suggestion style) ──────────────────────────────────
  output = output + "HOW TO FIX:\n"
  let fixes = get_how_to_fix(error.reason, error.actual, error.expected)
  for fix in fixes {
    output = output + "    " + fix + "\n"
  }

  // ── Additional Suggestions ──────────────────────────────────────────────
  if error.suggestions.length() > 0 {
    output = output + "\nHINTS:\n"
    for suggestion in error.suggestions {
      output = output + "    - " + suggestion + "\n"
    }
  }

  // ── Child Errors (for nested issues) ────────────────────────────────────
  if error.children.length() > 0 {
    output = output + "\nRELATED ISSUES:\n"
    for child in error.children {
      output = output + "    - " + get_friendly_title(child.reason) + "\n"
      output = output +
        "      " +
        format_type_v2(child.actual) +
        " vs " +
        format_type_v2(child.expected) +
        "\n"
    }
  }

  // ── Documentation Link ──────────────────────────────────────────────────
  output = output + "\nLEARN MORE:\n"
  output = output +
    "    Error TS" +
    code.to_string() +
    ": " +
    get_error_doc_url(code) +
    "\n"
  output = output +
    "    TypeScript Handbook: " +
    get_handbook_url("2/types-from-types") +
    "\n"
  output
}

///|
/// Convert TypeMismatchError to DetailedError for structured error handling
pub fn to_detailed_error(
  error : TypeMismatchError,
  file_path : String,
  line : Int,
  column : Int,
  source_line : String,
) -> DetailedError {
  let code = get_error_code(error.reason)
  let related : Array[DetailedError] = []

  // Convert children recursively
  for child in error.children {
    related.push(to_detailed_error(child, file_path, line, column, ""))
  }
  {
    title: get_friendly_title(error.reason),
    code,
    location: file_path + ":" + line.to_string() + ":" + column.to_string(),
    code_snippet: source_line,
    what_went_wrong: "Expected " +
    format_type_v2(error.expected) +
    ", found " +
    format_type_v2(error.actual),
    why_error: get_why_explanation(error.reason),
    how_to_fix: get_how_to_fix(error.reason, error.actual, error.expected),
    doc_link: get_error_doc_url(code),
    related,
  }
}

///|
/// Format a simple one-line error for compact output (like Rust's short form)
pub fn format_compact_error(
  error : TypeMismatchError,
  file_path : String,
  line : Int,
  column : Int,
) -> String {
  let code = get_error_code(error.reason)
  let title = string_to_lower(get_friendly_title(error.reason))
  "error[TS" +
  code.to_string() +
  "]: " +
  file_path +
  ":" +
  line.to_string() +
  ":" +
  column.to_string() +
  " - " +
  title +
  ": expected `" +
  format_type_v2(error.expected) +
  "`, found `" +
  format_type_v2(error.actual) +
  "`"
}

///|
/// Simple string lowercase helper for error formatting
pub fn string_to_lower(s : String) -> String {
  let result : Array[Char] = []
  for c in s {
    let code = c.to_int()
    if code >= 65 && code <= 90 {
      result.push(Int::unsafe_to_char(code + 32))
    } else {
      result.push(c)
    }
  }
  let mut output = ""
  for ch in result {
    output = output + ch.to_string()
  }
  output
}

///|
/// Simple string repeat helper for error formatting
pub fn string_repeat(s : String, n : Int) -> String {
  let mut result = ""
  for _ in 0..<n {
    result = result + s
  }
  result
}

// ============================================================================
// Decorator Errors
// ============================================================================

///|
/// Error: Decorators are not enabled (TS1219)
/// "Decorators are only available when 'experimentalDecorators' option is set."
pub fn decorator_not_enabled_error(
  location : String,
  decorator_name : String,
) -> DetailedError {
  {
    title: "Decorator Not Enabled",
    code: 1219,
    location,
    code_snippet: "@" + decorator_name,
    what_went_wrong: "Decorators require the 'experimentalDecorators' compiler option to be enabled.",
    why_error: "TypeScript decorators are an experimental feature. They are not part of the standard JavaScript specification yet (though Stage 3 decorators are being finalized). To use decorators, you must explicitly enable them in your tsconfig.json.",
    how_to_fix: [
      "Add \"experimentalDecorators\": true to your tsconfig.json compilerOptions",
      "Example: { \"compilerOptions\": { \"experimentalDecorators\": true } }",
    ],
    doc_link: get_error_doc_url(1219),
    related: [],
  }
}

///|
/// Error: Invalid decorator target (TS1206)
/// "Decorators can only decorate class declarations, class methods, accessors, properties, or parameters."
pub fn invalid_decorator_target_error(
  location : String,
  target : String,
) -> DetailedError {
  {
    title: "Invalid Decorator Target",
    code: 1206,
    location,
    code_snippet: "@decorator on " + target,
    what_went_wrong: "Decorators can only be applied to specific targets: class declarations, methods, accessors, properties, or parameters.",
    why_error: "You've placed a decorator on something that cannot be decorated. In TypeScript, only certain elements can have decorators applied to them.",
    how_to_fix: [
      "Move the decorator to a valid target (class, method, accessor, property, or parameter)",
      "If decorating a function, consider wrapping it in a class method",
    ],
    doc_link: get_error_doc_url(1206),
    related: [],
  }
}

///|
/// Error: Decorator must return value (TS1241)
/// "A decorator must return a value that can be used at runtime."
pub fn decorator_must_return_value_error(
  location : String,
  decorator_name : String,
) -> DetailedError {
  {
    title: "Decorator Must Return Value",
    code: 1241,
    location,
    code_snippet: "@" + decorator_name,
    what_went_wrong: "The decorator function does not return a valid value.",
    why_error: "Decorators are functions that receive the target (class, method, etc.) and optionally return a replacement or modified version. A decorator that returns nothing will have no effect.",
    how_to_fix: [
      "Ensure your decorator function returns a value", "For class decorators, return a class constructor",
      "For method decorators, return a property descriptor or undefined",
    ],
    doc_link: get_error_doc_url(1241),
    related: [],
  }
}

///|
/// Error: Decorator cannot be applied to parameter (TS1239)
/// "Decorators are not valid here."
pub fn decorator_invalid_position_error(
  location : String,
  position : String,
) -> DetailedError {
  {
    title: "Invalid Decorator Position",
    code: 1239,
    location,
    code_snippet: "@decorator in " + position,
    what_went_wrong: "A decorator has been placed in an invalid position.",
    why_error: "Decorators must appear immediately before the declaration they modify. They cannot be placed inside expressions or in other invalid positions.",
    how_to_fix: [
      "Move the decorator directly before the class, method, property, or parameter it should decorate",
    ],
    doc_link: get_error_doc_url(1239),
    related: [],
  }
}

///|
/// Error: Decorator signature mismatch (TS1270)
/// "Decorator function does not match expected signature."
pub fn decorator_signature_mismatch_error(
  location : String,
  decorator_name : String,
  expected : String,
  actual : String,
) -> DetailedError {
  {
    title: "Decorator Signature Mismatch",
    code: 1270,
    location,
    code_snippet: "@" + decorator_name,
    what_went_wrong: "The decorator function signature does not match what's expected for this target.",
    why_error: "Different decorator types have different signatures:\n" +
    "- Class: (target: Function) => Function\n" +
    "- Method: (target: Object, propertyKey: string, descriptor: PropertyDescriptor) => PropertyDescriptor\n" +
    "- Property: (target: Object, propertyKey: string) => void\n" +
    "- Parameter: (target: Object, propertyKey: string, parameterIndex: number) => void",
    how_to_fix: [
      "Expected signature: " + expected,
      "Actual signature: " + actual,
      "Update your decorator to match the expected signature",
    ],
    doc_link: get_error_doc_url(1270),
    related: [],
  }
}

// ============================================================================
// Enum Errors
// ============================================================================

///|
/// Error: Enum member must have initializer (TS1061)
/// "In an enum with computed member values, a member without an initializer must be preceded by a member with a numeric constant."
pub fn enum_member_needs_initializer_error(
  location : String,
  member_name : String,
) -> DetailedError {
  {
    title: "Enum Member Needs Initializer",
    code: 1061,
    location,
    code_snippet: member_name,
    what_went_wrong: "This enum member needs an explicit initializer because it follows a computed or string member.",
    why_error: "In TypeScript enums, auto-incrementing only works for numeric enums. When you have a computed value or string enum member, subsequent members must have explicit initializers because the compiler cannot auto-increment from them.",
    how_to_fix: [
      "Add an explicit value: " + member_name + " = <value>",
      "If using string enums, provide a string value",
      "If using numeric enums, provide a number value",
    ],
    doc_link: get_error_doc_url(1061),
    related: [],
  }
}

///|
/// Error: Const enum member initializer not constant (TS2474)
/// "const enum member initializers can only contain literal values and other computed enum values."
pub fn const_enum_non_constant_error(
  location : String,
  member_name : String,
) -> DetailedError {
  {
    title: "Const Enum Non-Constant Value",
    code: 2474,
    location,
    code_snippet: member_name,
    what_went_wrong: "Const enum members can only have constant initializers.",
    why_error: "Const enums are completely inlined at compile time. This means their values must be computable at compile time - no function calls, variables, or complex expressions are allowed.",
    how_to_fix: [
      "Use only literal values (numbers, strings)", "Use simple arithmetic expressions (1 + 2, 10 * 2)",
      "Reference other const enum members from the same enum",
    ],
    doc_link: get_error_doc_url(2474),
    related: [],
  }
}

///|
/// Error: Ambient enum cannot have computed member (TS1066)
/// "In ambient enum declarations member initializer must be a constant expression."
pub fn ambient_enum_computed_error(
  location : String,
  member_name : String,
) -> DetailedError {
  {
    title: "Ambient Enum Computed Value",
    code: 1066,
    location,
    code_snippet: member_name,
    what_went_wrong: "Ambient (declare) enum members can only have constant initializers.",
    why_error: "Ambient enums describe external values that already exist. Their values must be constant so TypeScript knows what values to expect at runtime.",
    how_to_fix: [
      "Use only literal numbers or strings", "Remove the complex expression",
    ],
    doc_link: get_error_doc_url(1066),
    related: [],
  }
}

///|
/// Error: Heterogeneous enum not allowed (TS2553)
/// "Computed values are not permitted in an enum with string valued members."
pub fn heterogeneous_enum_error(
  location : String,
  enum_name : String,
) -> DetailedError {
  {
    title: "Heterogeneous Enum",
    code: 2553,
    location,
    code_snippet: "enum " + enum_name,
    what_went_wrong: "This enum mixes string and numeric values incorrectly.",
    why_error: "While TypeScript allows heterogeneous enums (mixing strings and numbers), you cannot have auto-incrementing numeric members after string members, and you cannot have computed values in string enums.",
    how_to_fix: [
      "Use only string values throughout the enum", "Use only numeric values throughout the enum",
      "If mixing, ensure all members after string values have explicit initializers",
    ],
    doc_link: get_error_doc_url(2553),
    related: [],
  }
}

///|
/// Error: Enum member cannot reference itself (TS2477)
/// "A const enum member can only be accessed using a string literal."
pub fn enum_circular_reference_error(
  location : String,
  member_name : String,
) -> DetailedError {
  {
    title: "Enum Circular Reference",
    code: 2477,
    location,
    code_snippet: member_name,
    what_went_wrong: "Enum member cannot reference itself or create a circular dependency.",
    why_error: "Enum values are computed in order. A member cannot reference itself or later members because their values haven't been computed yet.",
    how_to_fix: [
      "Only reference members defined earlier in the enum", "Use a literal value instead",
    ],
    doc_link: get_error_doc_url(2477),
    related: [],
  }
}

// ============================================================================
// Index Signature Errors
// ============================================================================

///|
/// Error: Numeric index type not assignable to string index type (TS2413)
/// "Numeric index type 'T1' is not assignable to string index type 'T2'."
pub fn numeric_index_not_assignable_error(
  location : String,
  numeric_type : String,
  string_type : String,
) -> DetailedError {
  {
    title: "Numeric Index Type Mismatch",
    code: 2413,
    location,
    code_snippet: "[key: number]: " + numeric_type,
    what_went_wrong: "Numeric index type '" +
    numeric_type +
    "' is not assignable to string index type '" +
    string_type +
    "'.",
    why_error: "In JavaScript, numeric property keys are converted to strings (e.g., obj[0] is the same as obj['0']). Therefore, the type returned by numeric indexing must be a subtype of the type returned by string indexing.",
    how_to_fix: [
      "Make the numeric index type a subtype of the string index type", "Change: { [n: number]: T1; [s: string]: T2 } where T1 extends T2",
      "Or use a common base type for both index signatures",
    ],
    doc_link: get_error_doc_url(2413),
    related: [],
  }
}

///|
/// Error: Invalid index signature key type (TS1023)
/// "An index signature parameter type must be 'string', 'number', or 'symbol'."
pub fn invalid_index_key_type_error(
  location : String,
  key_type : String,
) -> DetailedError {
  {
    title: "Invalid Index Signature Parameter Type",
    code: 1023,
    location,
    code_snippet: "[key: " + key_type + "]",
    what_went_wrong: "An index signature parameter type must be 'string', 'number', or 'symbol'. Got '" +
    key_type +
    "'.",
    why_error: "TypeScript only supports three types of index signatures: string, number, and symbol. These correspond to JavaScript's property access mechanisms.",
    how_to_fix: [
      "Use 'string' for string key access: [key: string]: T", "Use 'number' for array-like access: [key: number]: T",
      "Use 'symbol' for symbol key access: [key: symbol]: T",
    ],
    doc_link: get_error_doc_url(1023),
    related: [],
  }
}

///|
/// Error: Index signature value type mismatch (TS2411)
/// "Property 'x' of type 'T1' is not assignable to string index type 'T2'."
pub fn property_not_assignable_to_index_error(
  location : String,
  property_name : String,
  property_type : String,
  index_type : String,
) -> DetailedError {
  {
    title: "Property Not Assignable to Index Type",
    code: 2411,
    location,
    code_snippet: property_name + ": " + property_type,
    what_went_wrong: "Property '" +
    property_name +
    "' of type '" +
    property_type +
    "' is not assignable to string index type '" +
    index_type +
    "'.",
    why_error: "When an interface has an index signature, all explicitly declared properties must have types that are assignable to the index signature's value type.",
    how_to_fix: [
      "Change the property type to be compatible with the index signature", "Use a union type in the index signature: [key: string]: T1 | T2",
      "Remove the index signature if not all properties should conform to it",
    ],
    doc_link: get_error_doc_url(2411),
    related: [],
  }
}

///|
/// Error: Missing index signature (TS2536)
/// "Type 'string' cannot be used to index type 'T'."
pub fn missing_index_signature_error(
  location : String,
  key_type : String,
  object_type : String,
) -> DetailedError {
  {
    title: "Missing Index Signature",
    code: 2536,
    location,
    code_snippet: object_type + "[" + key_type + "]",
    what_went_wrong: "Type '" +
    key_type +
    "' cannot be used to index type '" +
    object_type +
    "'.",
    why_error: "The object type doesn't have an index signature that allows accessing properties with the given key type. Index signatures explicitly declare that arbitrary keys of a certain type are allowed.",
    how_to_fix: [
      "Add an index signature: { [key: string]: T }", "Use a specific property name instead of a dynamic key",
      "Cast the object to Record<string, T> if you're sure it has arbitrary string keys",
    ],
    doc_link: get_error_doc_url(2536),
    related: [],
  }
}

///|
/// Error: Readonly index signature assignment (TS2542)
/// "Index signature in type is 'readonly' and cannot be assigned to the mutable index signature in target type."
pub fn readonly_index_mismatch_error(location : String) -> DetailedError {
  {
    title: "Readonly Index Signature Mismatch",
    code: 2542,
    location,
    code_snippet: "readonly [key: string]: T",
    what_went_wrong: "Cannot assign from a mutable index signature to a readonly index signature.",
    why_error: "A readonly index signature guarantees that values cannot be modified through indexing. Allowing assignment from a mutable source would violate this guarantee.",
    how_to_fix: [
      "Make the source index signature readonly as well", "Remove the readonly modifier from the target if mutation is needed",
      "Use a type assertion if you're sure the mutation is safe",
    ],
    doc_link: get_error_doc_url(2542),
    related: [],
  }
}

///|
/// Error: Element implicitly has 'any' type (TS7053)
/// "Element implicitly has an 'any' type because expression of type 'T' can't be used to index type 'U'."
pub fn element_implicit_any_error(
  location : String,
  key_type : String,
  object_type : String,
) -> DetailedError {
  {
    title: "Element Implicitly Has 'any' Type",
    code: 7053,
    location,
    code_snippet: object_type + "[" + key_type + "]",
    what_went_wrong: "Element implicitly has an 'any' type because expression of type '" +
    key_type +
    "' can't be used to index type '" +
    object_type +
    "'.",
    why_error: "With noImplicitAny enabled, TypeScript requires explicit types when accessing properties with dynamic keys. This helps catch potential runtime errors.",
    how_to_fix: [
      "Add an index signature to the type: { [key: string]: T }", "Use keyof typeof obj to ensure the key is valid",
      "Add a type assertion if you're sure the access is valid",
    ],
    doc_link: get_error_doc_url(7053),
    related: [],
  }
}
