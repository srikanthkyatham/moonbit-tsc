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
    OverloadCandidateFailed(index) => "OVERLOAD " + index.to_string() + " FAILED"
    PrivateMemberAccess(name, _) => "PRIVATE MEMBER '" + name + "'"
    ProtectedMemberAccess(name, _) => "PROTECTED MEMBER '" + name + "'"
    AbstractClassInstantiation(name) => "CANNOT INSTANTIATE ABSTRACT CLASS '" + name + "'"
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
    SuperCallRequired(class_name) => "MISSING 'SUPER' CALL IN '" + class_name + "'"
    SuperCallOutsideConstructor => "'SUPER' CALL OUTSIDE CONSTRUCTOR"
    SuperPropertyOutsideClass => "'SUPER' OUTSIDE DERIVED CLASS"
    SuperCallInStaticMethod => "'SUPER' CALL IN STATIC METHOD"
    SuperPropertyAccess(name) => "PROPERTY '" + name + "' NOT ON 'SUPER'"
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
      fixes.push("Option 2: Use a type assertion if you're certain the types are compatible:")
      fixes.push("          value as ExpectedType")
      fixes.push(
        "Option 3: Check if there's a type mismatch in your function parameters or return values.",
      )
    }
    MissingProperty(name) => {
      fixes.push(
        "Add the missing property '" + name + "' to your object:",
      )
      fixes.push(
        "    { ...existingObj, " + name + ": /* value */ }",
      )
      fixes.push("")
      fixes.push(
        "Or mark the property as optional in the target type using '?':",
      )
      fixes.push("    interface Target { " + name + "?: SomeType; }")
    }
    ExcessProperty(name) => {
      fixes.push(
        "Option 1: Remove the extra property '" + name + "' from your object literal.",
      )
      fixes.push("")
      fixes.push(
        "Option 2: If you need the property, add it to the target type definition.",
      )
      fixes.push("")
      fixes.push("Option 3: Use a type assertion to bypass excess property checking:")
      fixes.push("    const obj = { " + name + ": value } as TargetType;")
      fixes.push("")
      fixes.push("Option 4: Add an index signature to allow additional properties:")
      fixes.push("    interface Target { [key: string]: unknown; }")
    }
    PropertyTypeMismatch(name) => {
      fixes.push(
        "Fix the type of property '" + name + "' in your source value to match the expected type.",
      )
      fixes.push("")
      fixes.push("If you're certain the types are compatible, use a type assertion:")
      fixes.push(
        "    { " + name + ": value as ExpectedPropertyType }",
      )
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
        "Fix the type of argument at position " + index.to_string() + " ('" + name + "').",
      )
      fixes.push("")
      fixes.push("Example:")
      fixes.push("    // Instead of: fn(wrongValue)")
      fixes.push("    // Use:        fn(correctValue as ExpectedType)")
    }
    ReturnTypeMismatch => {
      fixes.push(
        "Ensure your function returns a value of the expected type.",
      )
      fixes.push("")
      fixes.push("Example fix:")
      fixes.push("    function example(): ExpectedType {")
      fixes.push("        return correctValue; // Make sure this matches ExpectedType")
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
        "Ensure the type argument for '" + name + "' is consistent throughout your code.",
      )
      fixes.push("")
      fixes.push("Example:")
      fixes.push(
        "    // If you have: const arr: Array<number> = [1, 2, 3];",
      )
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
      fixes.push("Or ensure the context provides enough information for inference.")
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
      fixes.push("2. Remove 'readonly' from the property definition if mutation is needed.")
    }
    OptionalToRequired(name) => {
      fixes.push(
        "Ensure '" + name + "' is always defined before using it as a required value:",
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
      fixes.push("Either change your value or update the type to accept both literals:")
      fixes.push(
        "    type AllowedValues = '" + expected_lit + "' | '" + actual_lit + "';",
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
      fixes.push("Break the circular reference by using a type alias or interface:")
      fixes.push("    type Node = { next?: Node };  // OK: optional breaks cycle")
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
          fixes.push("If this is an object, check if you meant to access a method:")
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
        "None of the " +
        count.to_string() +
        " overload(s) match your call.",
      )
      fixes.push("")
      fixes.push("Options to fix:")
      fixes.push(
        "1. Check the argument types and count match one of the overloads",
      )
      fixes.push("2. Check for typos in the function name")
      fixes.push("3. Add a type annotation to help TypeScript select the right overload:")
      fixes.push("       functionName<ExplicitType>(...args)")
    }
    OverloadCandidateFailed(_) => {
      fixes.push("This overload candidate didn't match. Check the error above for details.")
      fixes.push("")
      fixes.push(
        "If you expected this overload to match, ensure argument types are compatible.",
      )
    }
    PrivateMemberAccess(name, declared_in) => {
      fixes.push(
        "Property '" + name + "' is private to class '" + declared_in + "'.",
      )
      fixes.push("")
      fixes.push("Options to fix:")
      fixes.push("1. Access this property from within the class methods only")
      fixes.push("2. Add a public getter method:")
      fixes.push("       public get" + name + "() { return this." + name + "; }")
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
        "Abstract member '" + name + "' from '" + base_class + "' must be implemented.",
      )
      fixes.push("")
      fixes.push("Add the implementation in your class:")
      fixes.push("       " + name + "(...) { /* implementation */ }")
    }
    OverrideReturnTypeMismatch(name, _) => {
      fixes.push("Override method '" + name + "' has incompatible return type.")
      fixes.push("")
      fixes.push("Ensure the return type is assignable to the base method's return type.")
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
      fixes.push("Override method '" + name + "' has incompatible parameter type.")
      fixes.push("")
      fixes.push("Ensure parameter types are compatible with the base method.")
    }
    OverrideAccessibilityMismatch(name, base_acc, _) => {
      fixes.push("Override member '" + name + "' is more restrictive than base.")
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
      fixes.push("Add a 'super()' call to the constructor of '" + class_name + "':")
      fixes.push("    constructor() {")
      fixes.push("        super();  // Required in derived classes")
      fixes.push("        // ... rest of constructor")
      fixes.push("    }")
    }
    SuperCallOutsideConstructor => {
      fixes.push("Move the 'super()' call inside the constructor.")
      fixes.push("")
      fixes.push("If you meant to call a parent method, use 'super.methodName()' instead:")
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
      fixes.push("Static methods cannot use 'super()' because they don't have instance context.")
      fixes.push("If you need parent class static methods, call them by name:")
      fixes.push("    static method() {")
      fixes.push("        ParentClass.staticMethod();")
      fixes.push("    }")
    }
    SuperPropertyAccess(name) => {
      fixes.push("The property '" + name + "' doesn't exist on the parent class.")
      fixes.push("")
      fixes.push("Options:")
      fixes.push("1. Check the property name for typos")
      fixes.push("2. Add the property/method to the base class")
      fixes.push("3. Use 'this." + name + "' if accessing a property defined in this class")
    }
  }
  fixes
}

///|
/// Get the appropriate TypeScript error code for a mismatch reason
pub fn get_error_code(reason : MismatchReason) -> Int {
  match reason {
    IncompatibleTypes | PropertyTypeMismatch(_) | LiteralMismatch(_, _) | LiteralToWide =>
      2322
    MissingProperty(_) | ExcessProperty(_) | OptionalToRequired(_) | IndexSignatureMismatch =>
      2322
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
  output = output +
    "    Expected: " +
    format_type_v2(error.expected) +
    "\n"
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
      output = output +
        "    - " +
        get_friendly_title(child.reason) +
        "\n"
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
  output = output + "    Error TS" + code.to_string() + ": " + get_error_doc_url(code) + "\n"
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
    related.push(
      to_detailed_error(child, file_path, line, column, ""),
    )
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
