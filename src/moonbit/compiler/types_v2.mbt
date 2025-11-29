// TypeV2 - Simplified Type System for Bidirectional Type Checking
// This is the new, cleaner type representation matching the guide's design.
// Used internally by the v2 checker, with conversion to/from the original Type at API boundaries.

///|
/// Simplified Type enum without TypeInfo wrappers on primitives
pub enum TypeV2 {
  // Primitives (no wrapper, cleaner representation)
  TNumber
  TString
  TBoolean
  TNull
  TUndefined
  TVoid
  TNever
  TAny
  TUnknown
  TSymbol
  TBigInt

  // Compound types
  TUnion(Array[TypeV2])
  TIntersection(Array[TypeV2])
  TArray(TypeV2)
  TTuple(Array[TupleElementV2])
  TObject(ObjectTypeV2)
  TFunction(FunctionTypeV2)

  // Generics
  TTypeParam(String, TypeV2?) // name, constraint
  TGenericInstance(String, Array[TypeV2]) // e.g., Array<number>, Map<string, number>

  // Literals (for narrowing and precise typing)
  TLiteralString(String)
  TLiteralNumber(Double)
  TLiteralBool(Bool)
  TLiteralBigInt(String)

  // Advanced types
  TConditional(ConditionalTypeV2) // T extends U ? X : Y
  TMapped(MappedTypeV2) // { [K in keyof T]: T[K] }
  TIndexAccess(IndexAccessTypeV2) // T[K]
  TTemplateLiteral(TemplateLiteralTypeV2) // `${string}-${number}`
  TInfer(String) // infer R

  // Error type (for type errors during checking)
  TError
} derive(Show, Eq)

///|
/// Object type (interfaces, classes, object literals)
pub struct ObjectTypeV2 {
  fields : Map[String, FieldInfoV2]
  call_signatures : Array[FunctionTypeV2]
  construct_signatures : Array[FunctionTypeV2]
  index_signature : IndexSignatureV2?
  is_class : Bool
  class_name : String?
} derive(Show, Eq)

///|
/// Default empty object type
pub fn ObjectTypeV2::empty() -> ObjectTypeV2 {
  {
    fields: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signature: None,
    is_class: false,
    class_name: None,
  }
}

// ============================================================================
// Factory Functions for Type Creation (for testing and external use)
// ============================================================================

///|
/// Create a string type
pub fn create_string_type() -> TypeV2 {
  TString
}

///|
/// Create a number type
pub fn create_number_type() -> TypeV2 {
  TNumber
}

///|
/// Create a boolean type
pub fn create_boolean_type() -> TypeV2 {
  TBoolean
}

///|
/// Create an any type
pub fn create_any_type() -> TypeV2 {
  TAny
}

///|
/// Create a void type
pub fn create_void_type() -> TypeV2 {
  TVoid
}

///|
/// Create a null type
pub fn create_null_type() -> TypeV2 {
  TNull
}

///|
/// Create an undefined type
pub fn create_undefined_type() -> TypeV2 {
  TUndefined
}

///|
/// Create an empty object type
pub fn create_empty_object_type() -> TypeV2 {
  TObject(ObjectTypeV2::empty())
}

///|
/// Create an error type (for invalid types)
pub fn create_error_type() -> TypeV2 {
  TError
}

///|
/// Create a literal string type
pub fn create_literal_string_type(value : String) -> TypeV2 {
  TLiteralString(value)
}

///|
/// Create a literal number type
pub fn create_literal_number_type(value : Double) -> TypeV2 {
  TLiteralNumber(value)
}

///|
/// Create a literal boolean type
pub fn create_literal_bool_type(value : Bool) -> TypeV2 {
  TLiteralBool(value)
}

///|
/// Create a union type from an array of types
pub fn create_union_type(types : Array[TypeV2]) -> TypeV2 {
  TUnion(types)
}

///|
/// Create an array type
pub fn create_array_type(element_type : TypeV2) -> TypeV2 {
  TArray(element_type)
}

///|
/// Create a tuple type
pub fn create_tuple_type(elements : Array[TupleElementV2]) -> TypeV2 {
  TTuple(elements)
}

///|
/// Create a type parameter type
pub fn create_type_param(name : String, constraint : TypeV2?) -> TypeV2 {
  TTypeParam(name, constraint)
}

///|
/// Create a generic instance type
pub fn create_generic_instance(name : String, type_args : Array[TypeV2]) -> TypeV2 {
  TGenericInstance(name, type_args)
}

///|
/// Create a function type wrapper
pub fn create_function_type(func : FunctionTypeV2) -> TypeV2 {
  TFunction(func)
}

///|
/// Create an object type wrapper
pub fn create_object_type(obj : ObjectTypeV2) -> TypeV2 {
  TObject(obj)
}

///|
/// Field/property information
pub struct FieldInfoV2 {
  ty : TypeV2
  optional : Bool
  is_readonly : Bool
} derive(Show, Eq)

///|
/// Create a required field
pub fn FieldInfoV2::required(ty : TypeV2) -> FieldInfoV2 {
  { ty, optional: false, is_readonly: false }
}

///|
/// Create an optional field
pub fn FieldInfoV2::optional(ty : TypeV2) -> FieldInfoV2 {
  { ty, optional: true, is_readonly: false }
}

///|
/// Create a readonly field
pub fn FieldInfoV2::make_readonly(ty : TypeV2) -> FieldInfoV2 {
  { ty, optional: false, is_readonly: true }
}

///|
/// Type predicate for user-defined type guards
/// Represents "x is Type" or "asserts x is Type"
pub struct TypePredicateV2 {
  parameter_name : String // The parameter being narrowed
  predicate_type : TypeV2 // The type to narrow to
  is_asserts : Bool // True for assertion functions (asserts x is Type)
} derive(Show, Eq)

///|
/// Function type
pub struct FunctionTypeV2 {
  type_params : Array[TypeParamV2]
  params : Array[ParamInfoV2]
  rest_param : ParamInfoV2?
  return_type : TypeV2
  type_predicate : TypePredicateV2? // For type guards (x is Type, asserts x is Type)
} derive(Show, Eq)

///|
/// Default function type (any => any)
pub fn FunctionTypeV2::any() -> FunctionTypeV2 {
  { type_params: [], params: [], rest_param: None, return_type: TAny, type_predicate: None }
}

///|
/// Create a simple function type
pub fn FunctionTypeV2::simple(
  params : Array[TypeV2],
  return_type : TypeV2,
) -> FunctionTypeV2 {
  {
    type_params: [],
    params: params.mapi(fn(i, ty) {
      { name: "arg" + i.to_string(), ty, optional: false, is_rest: false }
    }),
    rest_param: None,
    return_type,
    type_predicate: None,
  }
}

///|
/// Parameter information
pub struct ParamInfoV2 {
  name : String
  ty : TypeV2
  optional : Bool
  is_rest : Bool
} derive(Show, Eq)

///|
/// Create a required parameter
pub fn ParamInfoV2::required(name : String, ty : TypeV2) -> ParamInfoV2 {
  { name, ty, optional: false, is_rest: false }
}

///|
/// Create an optional parameter
pub fn ParamInfoV2::optional(name : String, ty : TypeV2) -> ParamInfoV2 {
  { name, ty, optional: true, is_rest: false }
}

///|
/// Create a rest parameter
pub fn ParamInfoV2::rest(name : String, ty : TypeV2) -> ParamInfoV2 {
  { name, ty, optional: false, is_rest: true }
}

///|
/// Variance of a type parameter
/// Determines how type parameters behave in subtyping relationships
#valtype
pub enum Variance {
  Covariant // out - can only appear in output positions (return types)
  Contravariant // in - can only appear in input positions (parameters)
  Invariant // in out - appears in both input and output positions
  Bivariant // special case - both covariant and contravariant
} derive(Show, Eq)

///|
/// Type parameter (generic)
pub struct TypeParamV2 {
  name : String
  constraint : TypeV2?
  default_type : TypeV2?
  is_const : Bool // const type parameter (TS 5.0+): function foo<const T>()
  variance : Variance? // Optional variance annotation
} derive(Show, Eq)

///|
/// Create a simple type parameter (no constraint)
pub fn TypeParamV2::simple(name : String) -> TypeParamV2 {
  { name, constraint: None, default_type: None, is_const: false, variance: None }
}

///|
/// Create a constrained type parameter
pub fn TypeParamV2::constrained(
  name : String,
  constraint : TypeV2,
) -> TypeParamV2 {
  {
    name,
    constraint: Some(constraint),
    default_type: None,
    is_const: false,
    variance: None,
  }
}

///|
/// Create a const type parameter (TS 5.0+)
pub fn TypeParamV2::const_param(name : String) -> TypeParamV2 {
  { name, constraint: None, default_type: None, is_const: true, variance: None }
}

///|
/// Create a const type parameter with constraint
pub fn TypeParamV2::const_constrained(
  name : String,
  constraint : TypeV2,
) -> TypeParamV2 {
  {
    name,
    constraint: Some(constraint),
    default_type: None,
    is_const: true,
    variance: None,
  }
}

///|
/// Create a type parameter with explicit variance
pub fn TypeParamV2::with_variance(
  name : String,
  variance : Variance,
) -> TypeParamV2 {
  {
    name,
    constraint: None,
    default_type: None,
    is_const: false,
    variance: Some(variance),
  }
}

///|
/// Create a full type parameter with all options
pub fn TypeParamV2::full(
  name : String,
  constraint : TypeV2?,
  default_type : TypeV2?,
  is_const : Bool,
  variance : Variance?,
) -> TypeParamV2 {
  { name, constraint, default_type, is_const, variance }
}

///|
/// Tuple element (can be optional, rest, or labeled)
pub struct TupleElementV2 {
  ty : TypeV2
  optional : Bool
  is_rest : Bool
  label : String?
} derive(Show, Eq)

///|
/// Create a required tuple element
pub fn TupleElementV2::required(ty : TypeV2) -> TupleElementV2 {
  { ty, optional: false, is_rest: false, label: None }
}

///|
/// Create an optional tuple element
pub fn TupleElementV2::optional(ty : TypeV2) -> TupleElementV2 {
  { ty, optional: true, is_rest: false, label: None }
}

///|
/// Create a labeled tuple element
pub fn TupleElementV2::labeled(label : String, ty : TypeV2) -> TupleElementV2 {
  { ty, optional: false, is_rest: false, label: Some(label) }
}

///|
/// Create a rest tuple element
pub fn TupleElementV2::rest(ty : TypeV2) -> TupleElementV2 {
  { ty, optional: false, is_rest: true, label: None }
}

///|
/// Index signature for objects
pub struct IndexSignatureV2 {
  key_type : TypeV2
  value_type : TypeV2
  is_readonly : Bool
} derive(Show, Eq)

///|
/// Conditional type (T extends U ? X : Y)
pub struct ConditionalTypeV2 {
  check_type : TypeV2
  extends_type : TypeV2
  true_type : TypeV2
  false_type : TypeV2
} derive(Show, Eq)

///|
/// Mapped type ({ [K in keyof T]: T[K] })
pub struct MappedTypeV2 {
  type_param : TypeParamV2
  constraint : TypeV2 // Usually keyof T
  name_type : TypeV2? // For key remapping (as NewKey)
  template_type : TypeV2
  readonly_modifier : MappedModifierV2
  optional_modifier : MappedModifierV2
  source_type : TypeV2? // Original object type for homomorphic mapped types
} derive(Show, Eq)

///|
/// Modifier for mapped types
pub enum MappedModifierV2 {
  Unchanged // No modifier
  Add // +readonly, +?
  Remove // -readonly, -?
} derive(Show, Eq)

///|
/// Index access type (T[K])
pub struct IndexAccessTypeV2 {
  object_type : TypeV2
  index_type : TypeV2
} derive(Show, Eq)

///|
/// Template literal type (`${string}-${number}`)
pub struct TemplateLiteralTypeV2 {
  pub texts : Array[String] // Static text parts
  pub types : Array[TypeV2] // Interpolated types
} derive(Show, Eq)

///|
/// Create a template literal type
pub fn TemplateLiteralTypeV2::new(
  texts : Array[String],
  types : Array[TypeV2],
) -> TemplateLiteralTypeV2 {
  { texts, types }
}

// ============================================================================
// Type Utilities
// ============================================================================

///|
/// Create a union type, simplifying if possible
pub fn make_union(types : Array[TypeV2]) -> TypeV2 {
  // Remove duplicates
  let unique = remove_duplicate_types(types)

  // Handle special cases
  match unique.length() {
    0 => TNever
    1 => unique[0]
    _ => {
      // Flatten nested unions
      let flattened = flatten_union(unique)
      // Check if contains any/never
      if flattened.iter().any(fn(t) { t == TAny }) {
        TAny
      } else {
        let filtered = flattened.filter(fn(t) { t != TNever })
        match filtered.length() {
          0 => TNever
          1 => filtered[0]
          _ => TUnion(filtered)
        }
      }
    }
  }
}

///|
/// Create an intersection type, simplifying if possible
pub fn make_intersection(types : Array[TypeV2]) -> TypeV2 {
  // Remove duplicates
  let unique = remove_duplicate_types(types)

  // Handle special cases
  match unique.length() {
    0 => TUnknown
    1 => unique[0]
    _ => {
      // Flatten nested intersections
      let flattened = flatten_intersection(unique)
      // Check if contains never
      if flattened.iter().any(fn(t) { t == TNever }) {
        TNever
      } else {
        let filtered = flattened.filter(fn(t) { t != TUnknown && t != TAny })
        match filtered.length() {
          0 => TUnknown
          1 => filtered[0]
          _ => TIntersection(filtered)
        }
      }
    }
  }
}

///|
/// Flatten nested union types
fn flatten_union(types : Array[TypeV2]) -> Array[TypeV2] {
  let result : Array[TypeV2] = []
  for t in types {
    match t {
      TUnion(inner) => result.append(flatten_union(inner))
      other => result.push(other)
    }
  }
  result
}

///|
/// Flatten nested intersection types
fn flatten_intersection(types : Array[TypeV2]) -> Array[TypeV2] {
  let result : Array[TypeV2] = []
  for t in types {
    match t {
      TIntersection(inner) => result.append(flatten_intersection(inner))
      other => result.push(other)
    }
  }
  result
}

///|
/// Remove duplicate types from an array
fn remove_duplicate_types(types : Array[TypeV2]) -> Array[TypeV2] {
  let result : Array[TypeV2] = []
  for t in types {
    if not(result.iter().any(fn(existing) { types_v2_equal(existing, t) })) {
      result.push(t)
    }
  }
  result
}

///|
/// Check if two types are structurally equal
pub fn types_v2_equal(a : TypeV2, b : TypeV2) -> Bool {
  a == b
}

///|
/// Simplify a union type by removing subtypes
pub fn simplify_union(types : Array[TypeV2]) -> TypeV2 {
  make_union(types)
}

///|
/// Check if type is nullable (includes null or undefined)
pub fn is_nullable(ty : TypeV2) -> Bool {
  match ty {
    TNull | TUndefined => true
    TUnion(types) =>
      types
      .iter()
      .any(fn(t) {
        match t {
          TNull | TUndefined => true
          _ => false
        }
      })
    _ => false
  }
}

///|
/// Get non-null type (remove null and undefined from union)
pub fn get_non_null_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TNull | TUndefined => TNever
    TUnion(types) => {
      let filtered = types.filter(fn(t) {
        match t {
          TNull | TUndefined => false
          _ => true
        }
      })
      make_union(filtered)
    }
    other => other
  }
}

///|
/// Widen literal type to base type
pub fn widen_literal(ty : TypeV2) -> TypeV2 {
  match ty {
    TLiteralString(_) => TString
    TLiteralNumber(_) => TNumber
    TLiteralBool(_) => TBoolean
    TLiteralBigInt(_) => TBigInt
    TUnion(types) => make_union(types.map(widen_literal))
    other => other
  }
}

///|
/// Format type as string (for error messages)
pub fn format_type_v2(ty : TypeV2) -> String {
  match ty {
    TNumber => "number"
    TString => "string"
    TBoolean => "boolean"
    TNull => "null"
    TUndefined => "undefined"
    TVoid => "void"
    TNever => "never"
    TAny => "any"
    TUnknown => "unknown"
    TSymbol => "symbol"
    TBigInt => "bigint"
    TLiteralString(s) => "\"" + s + "\""
    TLiteralNumber(n) => n.to_string()
    TLiteralBool(b) => if b { "true" } else { "false" }
    TLiteralBigInt(s) => s + "n"
    TUnion(types) => types.map(format_type_v2).join(" | ")
    TIntersection(types) => types.map(format_type_v2).join(" & ")
    TArray(elem) => format_type_v2(elem) + "[]"
    TTuple(elems) =>
      "[" + elems.map(fn(e) { format_tuple_element(e) }).join(", ") + "]"
    TObject(obj) => format_object_type(obj)
    TFunction(f) => format_function_type(f)
    TTypeParam(name, _) => name
    TGenericInstance(name, args) =>
      if args.is_empty() {
        name
      } else {
        name + "<" + args.map(format_type_v2).join(", ") + ">"
      }
    TConditional(c) =>
      format_type_v2(c.check_type) +
      " extends " +
      format_type_v2(c.extends_type) +
      " ? " +
      format_type_v2(c.true_type) +
      " : " +
      format_type_v2(c.false_type)
    TMapped(_) => "{ [K in ...]: ... }"
    TIndexAccess(ia) =>
      format_type_v2(ia.object_type) + "[" + format_type_v2(ia.index_type) + "]"
    TTemplateLiteral(tl) => format_template_literal_type(tl)
    TInfer(name) => "infer " + name
    TError => "error"
  }
}

///|
/// Format tuple element
fn format_tuple_element(elem : TupleElementV2) -> String {
  let mut result = ""
  match elem.label {
    Some(label) => result = label + ": "
    None => ()
  }
  if elem.is_rest {
    result = result + "..."
  }
  result = result + format_type_v2(elem.ty)
  if elem.optional {
    result = result + "?"
  }
  result
}

///|
/// Format object type
fn format_object_type(obj : ObjectTypeV2) -> String {
  if obj.fields.is_empty() &&
    obj.call_signatures.is_empty() &&
    obj.construct_signatures.is_empty() {
    return "{}"
  }
  let parts : Array[String] = []
  for kv in obj.fields {
    let k = kv.0
    let v = kv.1
    let opt = if v.optional { "?" } else { "" }
    let ro = if v.is_readonly { "readonly " } else { "" }
    parts.push(ro + k + opt + ": " + format_type_v2(v.ty))
  }
  "{ " + parts.join("; ") + " }"
}

///|
/// Format function type
fn format_function_type(f : FunctionTypeV2) -> String {
  let params_str = f.params.map(fn(p) {
    let opt = if p.optional { "?" } else { "" }
    let rest = if p.is_rest { "..." } else { "" }
    rest + p.name + opt + ": " + format_type_v2(p.ty)
  })
  let params = params_str.join(", ")
  "(" + params + ") => " + format_type_v2(f.return_type)
}

///|
/// Format template literal type
fn format_template_literal_type(tl : TemplateLiteralTypeV2) -> String {
  let mut result = "`"
  for i in 0..<tl.texts.length() {
    result = result + tl.texts[i]
    if i < tl.types.length() {
      result = result + "${" + format_type_v2(tl.types[i]) + "}"
    }
  }
  result + "`"
}
