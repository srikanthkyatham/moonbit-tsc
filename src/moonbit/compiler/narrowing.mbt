// Narrowing - Control Flow Type Narrowing
// Extracts and applies type narrowings from conditions in if statements, etc.

///|
/// Compositional narrowing representation
/// Represents how a condition can narrow the types of variables
pub enum Narrowing {
  NTypeof(String, String) // typeof x === "string" (variable_name, type_string)
  NInstanceof(String, TypeV2) // x instanceof Class
  NTruthy(String) // if (x) - truthy check
  NEquality(String, TypeV2) // x === value
  NInequality(String, TypeV2) // x !== value
  NHasProperty(String, String) // "prop" in obj
  NAnd(Narrowing, Narrowing) // && - both narrowings apply
  NOr(Narrowing, Narrowing) // || - either narrowing applies
  NNot(Narrowing) // ! - invert narrowing
  NNullCheck(String, Bool) // x === null or x !== null (true = is null)
  NUndefinedCheck(String, Bool) // x === undefined or x !== undefined
  NNone // No narrowing possible
} derive(Show, Eq)

///|
/// Check if narrowing is None
pub fn Narrowing::is_none(self : Narrowing) -> Bool {
  match self {
    NNone => true
    _ => false
  }
}

///|
/// Invert narrowing for else branch
/// For if(cond) { ... } else { ... }, the else branch gets the inverted narrowing
pub fn invert_narrowing(narrowing : Narrowing) -> Narrowing {
  match narrowing {
    NNone => NNone
    NNot(inner) => inner // Double negation
    NAnd(a, b) => NOr(invert_narrowing(a), invert_narrowing(b)) // De Morgan
    NOr(a, b) => NAnd(invert_narrowing(a), invert_narrowing(b)) // De Morgan
    NTypeof(name, ty) => NNot(NTypeof(name, ty))
    NInstanceof(name, ty) => NNot(NInstanceof(name, ty))
    NTruthy(name) => NNot(NTruthy(name))
    NEquality(name, ty) => NInequality(name, ty)
    NInequality(name, ty) => NEquality(name, ty)
    NHasProperty(name, prop) => NNot(NHasProperty(name, prop))
    NNullCheck(name, is_null) => NNullCheck(name, not(is_null))
    NUndefinedCheck(name, is_undef) => NUndefinedCheck(name, not(is_undef))
  }
}

///|
/// Combine two narrowings with AND
pub fn combine_and(a : Narrowing, b : Narrowing) -> Narrowing {
  match (a, b) {
    (NNone, x) | (x, NNone) => x
    (a, b) => NAnd(a, b)
  }
}

///|
/// Combine two narrowings with OR
pub fn combine_or(a : Narrowing, b : Narrowing) -> Narrowing {
  match (a, b) {
    (NNone, _) | (_, NNone) => NNone // OR with unknown narrows to nothing
    (a, b) => NOr(a, b)
  }
}

// ============================================================================
// Type Narrowing Application
// ============================================================================

///|
/// Get the narrowed type for a typeof check
pub fn typeof_narrowed_type(type_str : String) -> TypeV2? {
  match type_str {
    "string" => Some(TString)
    "number" => Some(TNumber)
    "boolean" => Some(TBoolean)
    "undefined" => Some(TUndefined)
    "symbol" => Some(TSymbol)
    "bigint" => Some(TBigInt)
    "function" => Some(TFunction(FunctionTypeV2::any()))
    "object" => Some(TObject(ObjectTypeV2::empty())) // Note: includes null!
    _ => None
  }
}

///|
/// Intersect two types (narrow from current to narrowed)
pub fn intersect_types(current : TypeV2, narrowed : TypeV2) -> TypeV2 {
  match (current, narrowed) {
    // Any can be narrowed to anything
    (TAny, t) | (TUnknown, t) => t

    // Same types stay the same
    (t1, t2) if types_v2_equal(t1, t2) => t1

    // Union narrowing: filter members
    (TUnion(types), narrowed) => {
      let filtered = types.filter(fn(t) { is_type_assignable_to(t, narrowed) })
      simplify_union(filtered)
    }

    // Narrow union by excluding types
    (current, TUnion(targets)) =>
      if targets.iter().any(fn(t) { is_type_assignable_to(current, t) }) {
        current
      } else {
        TNever
      }

    // Object narrowing
    (TObject(o1), TObject(_)) => TObject(o1) // Keep source object with narrowed understanding

    // Function narrowing
    (TFunction(f), TFunction(_)) => TFunction(f)

    // Default: if compatible, keep current; otherwise never
    _ => if is_type_assignable_to(current, narrowed) { current } else { TNever }
  }
}

///|
/// Exclude a type from a union (for negative narrowing like !== null)
pub fn exclude_type(current : TypeV2, excluded : TypeV2) -> TypeV2 {
  match current {
    TUnion(types) => {
      let filtered = types.filter(fn(t) { not(types_v2_equal(t, excluded)) })
      simplify_union(filtered)
    }
    t => if types_v2_equal(t, excluded) { TNever } else { t }
  }
}

///|
/// Apply truthy narrowing - remove null, undefined, false, 0, ""
pub fn apply_truthy_narrowing(ty : TypeV2) -> TypeV2 {
  match ty {
    TNull | TUndefined => TNever
    TLiteralBool(false) => TNever
    TLiteralNumber(n) if n == 0.0 => TNever
    TLiteralString(s) if s == "" => TNever
    TUnion(types) => {
      let filtered = types.filter(fn(t) {
        match t {
          TNull | TUndefined | TLiteralBool(false) => false
          TLiteralNumber(n) => n != 0.0
          TLiteralString(s) => s != ""
          _ => true
        }
      })
      simplify_union(filtered)
    }
    other => other
  }
}

///|
/// Apply falsy narrowing - keep only null, undefined, false, 0, ""
pub fn apply_falsy_narrowing(ty : TypeV2) -> TypeV2 {
  match ty {
    TNull | TUndefined | TLiteralBool(false) => ty
    TLiteralNumber(n) if n == 0.0 => ty
    TLiteralString(s) if s == "" => ty
    TUnion(types) => {
      let filtered = types.filter(fn(t) {
        match t {
          TNull | TUndefined | TLiteralBool(false) => true
          TLiteralNumber(n) => n == 0.0
          TLiteralString(s) => s == ""
          _ => false
        }
      })
      simplify_union(filtered)
    }
    TBoolean => TLiteralBool(false)
    TNumber => TLiteralNumber(0.0)
    TString => TLiteralString("")
    _ => TNever
  }
}

///|
/// Apply has-property narrowing to union type
pub fn apply_has_property_narrowing(ty : TypeV2, prop : String) -> TypeV2 {
  match ty {
    TUnion(types) => {
      let filtered = types.filter(fn(t) {
        match t {
          TObject(obj) => obj.fields.contains(prop)
          _ => false
        }
      })
      simplify_union(filtered)
    }
    TObject(obj) => if obj.fields.contains(prop) { ty } else { TNever }
    _ => ty // Can't narrow non-objects
  }
}

// ============================================================================
// Simple Assignability Check (for narrowing purposes)
// ============================================================================

///|
/// Simple check if source type is assignable to target type
/// Used for narrowing decisions (not full type checking)
fn is_type_assignable_to(source : TypeV2, target : TypeV2) -> Bool {
  match (source, target) {
    (_, TAny) | (TAny, _) => true
    (_, TUnknown) => true
    (TNever, _) => true

    // Same types
    (TNumber, TNumber)
    | (TString, TString)
    | (TBoolean, TBoolean)
    | (TNull, TNull)
    | (TUndefined, TUndefined)
    | (TVoid, TVoid)
    | (TSymbol, TSymbol)
    | (TBigInt, TBigInt) => true

    // Literal widening
    (TLiteralString(_), TString)
    | (TLiteralNumber(_), TNumber)
    | (TLiteralBool(_), TBoolean)
    | (TLiteralBigInt(_), TBigInt) => true

    // Literal equality
    (TLiteralString(a), TLiteralString(b)) => a == b
    (TLiteralNumber(a), TLiteralNumber(b)) => a == b
    (TLiteralBool(a), TLiteralBool(b)) => a == b

    // Union: source assignable to at least one target member
    (source, TUnion(targets)) =>
      targets.iter().any(fn(t) { is_type_assignable_to(source, t) })

    // Union source: all members must be assignable
    (TUnion(sources), target) =>
      sources.iter().all(fn(s) { is_type_assignable_to(s, target) })

    // Arrays
    (TArray(s), TArray(t)) => is_type_assignable_to(s, t)

    // Functions (simplified - just check return type)
    (TFunction(sf), TFunction(tf)) =>
      is_type_assignable_to(sf.return_type, tf.return_type)

    // Objects (simplified)
    (TObject(_), TObject(_)) => true // Detailed check done elsewhere

    // Generic instances (simplified)
    (TGenericInstance(a, _), TGenericInstance(b, _)) => a == b
    _ => false
  }
}

// ============================================================================
// Narrowing Extraction Helpers
// ============================================================================

///|
/// Check if expression is a typeof check and extract info
pub fn is_typeof_binary_check(
  op : BinaryOperator,
  left : Node,
  right : Node,
) -> (String, String)? {
  match op {
    StrictEquals | StrictNotEquals | Equals | NotEquals => ()
    _ => return None
  }

  // Check for: typeof x === "string"
  match (left, right) {
    (UnaryExpression(un), StringLiteral(lit)) =>
      if un.operator == TypeOf {
        match un.operand {
          Identifier(id) => Some((id.name, lit.value))
          _ => None
        }
      } else {
        None
      }
    // Check for: "string" === typeof x (reversed)
    (StringLiteral(lit), UnaryExpression(un)) =>
      if un.operator == TypeOf {
        match un.operand {
          Identifier(id) => Some((id.name, lit.value))
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
/// Check if expression is a null check
pub fn is_null_check(
  op : BinaryOperator,
  left : Node,
  right : Node,
) -> (String, Bool)? {
  // Returns (variable_name, is_equals) where is_equals means === null
  match op {
    StrictEquals | Equals =>
      match (left, right) {
        (Identifier(id), NullLiteral(_)) | (NullLiteral(_), Identifier(id)) =>
          Some((id.name, true))
        _ => None
      }
    StrictNotEquals | NotEquals =>
      match (left, right) {
        (Identifier(id), NullLiteral(_)) | (NullLiteral(_), Identifier(id)) =>
          Some((id.name, false))
        _ => None
      }
    _ => None
  }
}

///|
/// Check if expression is an undefined check
pub fn is_undefined_check(
  op : BinaryOperator,
  left : Node,
  right : Node,
) -> (String, Bool)? {
  match op {
    StrictEquals | Equals =>
      match (left, right) {
        (Identifier(id), Identifier(undef)) if undef.name == "undefined" =>
          Some((id.name, true))
        (Identifier(undef), Identifier(id)) if undef.name == "undefined" =>
          Some((id.name, true))
        _ => None
      }
    StrictNotEquals | NotEquals =>
      match (left, right) {
        (Identifier(id), Identifier(undef)) if undef.name == "undefined" =>
          Some((id.name, false))
        (Identifier(undef), Identifier(id)) if undef.name == "undefined" =>
          Some((id.name, false))
        _ => None
      }
    _ => None
  }
}

///|
/// Check if expression is an "in" check: "prop" in obj
pub fn is_in_check(left : Node, right : Node) -> (String, String)? {
  match (left, right) {
    (StringLiteral(prop), Identifier(obj)) => Some((obj.name, prop.value))
    _ => None
  }
}

///|
/// Check if expression is an instanceof check: x instanceof Foo
pub fn is_instanceof_check(left : Node, right : Node) -> (String, String)? {
  match (left, right) {
    (Identifier(obj), Identifier(ctor)) => Some((obj.name, ctor.name))
    _ => None
  }
}
