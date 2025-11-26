// Type Error System - Rich Error Types and Formatting
// Provides detailed error messages with path tracking and suggestions

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
