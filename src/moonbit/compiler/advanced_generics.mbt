// Advanced Generics - Const Type Parameters, Variance Analysis, Recursive Resolution, Higher-Order Generics
// Implements missing TypeScript compiler features for advanced generic type support

// ============================================================================
// Const Type Parameters (TypeScript 5.0+)
// ============================================================================
// With `const` type parameters, the compiler infers literal types instead of widening
// Example: function foo<const T>(arg: T) => with foo([1, 2, 3]) infers T as [1, 2, 3]

///|
/// Narrow a type to its literal form if the type parameter is const
/// This implements TypeScript 5.0+ const type parameters
pub fn narrow_to_literal_for_const(
  type_param : TypeParamV2,
  inferred_type : TypeV2,
) -> TypeV2 {
  if not(type_param.is_const) {
    return inferred_type
  }

  // For const type parameters, preserve literal types and readonly arrays/tuples
  narrow_to_const_type(inferred_type)
}

///|
/// Recursively narrow a type to its const form
fn narrow_to_const_type(ty : TypeV2) -> TypeV2 {
  match ty {
    // Primitives already inferred as literals stay as literals
    TLiteralString(_) => ty
    TLiteralNumber(_) => ty
    TLiteralBool(_) => ty
    TLiteralBigInt(_) => ty

    // Arrays become readonly tuples with literal elements
    TArray(elem_ty) => {
      // For const, arrays should become readonly tuples
      // But we can't know the length, so we keep array with narrowed element type
      TArray(narrow_to_const_type(elem_ty))
    }

    // Tuples get narrowed element types
    TTuple(elements) =>
      TTuple(elements.map(fn(elem) {
        TupleElementV2::{
          ty: narrow_to_const_type(elem.ty),
          optional: elem.optional,
          is_rest: elem.is_rest,
          label: elem.label,
        }
      }))

    // Objects get narrowed field types
    TObject(obj) => {
      let new_fields : Map[String, FieldInfoV2] = Map::new()
      obj.fields.each(fn(name, field) {
        new_fields.set(name, FieldInfoV2::{
          ty: narrow_to_const_type(field.ty),
          optional: field.optional,
          is_readonly: true, // const makes everything readonly
        })
      })
      TObject(ObjectTypeV2::{
        fields: new_fields,
        symbol_fields: obj.symbol_fields,
        call_signatures: obj.call_signatures,
        construct_signatures: obj.construct_signatures,
        index_signature: obj.index_signature,
        is_class: obj.is_class,
        class_name: obj.class_name,
      })
    }

    // Unions get narrowed member types
    TUnion(types) => make_union(types.map(narrow_to_const_type))

    // Other types pass through
    _ => ty
  }
}

///|
/// Create a readonly version of an array type
pub fn make_readonly_array(elem_ty : TypeV2) -> TypeV2 {
  // In TypeScript, readonly T[] is represented as ReadonlyArray<T>
  TGenericInstance("ReadonlyArray", [elem_ty])
}

///|
/// Create a readonly version of a tuple type
pub fn make_readonly_tuple(elements : Array[TupleElementV2]) -> TypeV2 {
  // For tuples, readonly doesn't change the structure, just the mutability
  TTuple(elements)
}

// ============================================================================
// Variance Analysis
// ============================================================================
// Determines how type parameters vary in generic types
// - Covariant (out): T -> T, can only appear in output positions
// - Contravariant (in): T -> T, can only appear in input positions
// - Invariant (in out): T -> T, appears in both positions
// - Bivariant: Both covariant and contravariant (special case for method params)

///|
/// Position where a type parameter appears
#valtype
pub enum TypePosition {
  Output // Return types, property values (read)
  Input // Parameter types, property values (write)
} derive(Show, Eq)

///|
/// Analyze the variance of a type parameter in a given type
pub fn analyze_variance(param_name : String, ty : TypeV2) -> Variance {
  let result = analyze_variance_recursive(param_name, ty, Output)
  result
}

///|
/// Recursive variance analysis
fn analyze_variance_recursive(
  param_name : String,
  ty : TypeV2,
  position : TypePosition,
) -> Variance {
  match ty {
    // Type parameter directly - variance depends on position
    TTypeParam(name, _) =>
      if name == param_name {
        match position {
          Output => Covariant
          Input => Contravariant
        }
      } else {
        Bivariant // Not our parameter
      }

    // Arrays are covariant in their element type
    TArray(elem_ty) => analyze_variance_recursive(param_name, elem_ty, position)

    // Tuples are covariant in element types
    TTuple(elements) => {
      let mut result = Bivariant
      for elem in elements {
        result = combine_variances(
          result,
          analyze_variance_recursive(param_name, elem.ty, position),
        )
      }
      result
    }

    // Function types: contravariant in params, covariant in return
    TFunction(func) => {
      let mut result = Bivariant

      // Parameters are in contravariant position (flip the position)
      let param_position = flip_position(position)
      for param in func.params {
        result = combine_variances(
          result,
          analyze_variance_recursive(param_name, param.ty, param_position),
        )
      }

      // Return type is in covariant position (same position)
      result = combine_variances(
        result,
        analyze_variance_recursive(param_name, func.return_type, position),
      )

      result
    }

    // Object types: fields can be read (covariant) or written (contravariant)
    TObject(obj) => {
      let mut result = Bivariant
      obj.fields.each(fn(_name, field) {
        // Readonly fields are covariant, writable fields are invariant
        if field.is_readonly {
          result = combine_variances(
            result,
            analyze_variance_recursive(param_name, field.ty, position),
          )
        } else {
          // Non-readonly: both read and write, so invariant
          let covar = analyze_variance_recursive(param_name, field.ty, Output)
          let contravar = analyze_variance_recursive(param_name, field.ty, Input)
          result = combine_variances(result, combine_variances(covar, contravar))
        }
      })
      result
    }

    // Generic instances - need to know variance of the generic's params
    TGenericInstance(_, type_args) => {
      let mut result = Bivariant
      for arg in type_args {
        result = combine_variances(
          result,
          analyze_variance_recursive(param_name, arg, position),
        )
      }
      result
    }

    // Unions and intersections
    TUnion(types) => {
      let mut result = Bivariant
      for t in types {
        result = combine_variances(
          result,
          analyze_variance_recursive(param_name, t, position),
        )
      }
      result
    }

    TIntersection(types) => {
      let mut result = Bivariant
      for t in types {
        result = combine_variances(
          result,
          analyze_variance_recursive(param_name, t, position),
        )
      }
      result
    }

    // Conditional types are complex - check type is contravariant, others covariant
    TConditional(cond) => {
      let check_var = analyze_variance_recursive(
        param_name,
        cond.check_type,
        flip_position(position),
      )
      let extends_var = analyze_variance_recursive(
        param_name,
        cond.extends_type,
        position,
      )
      let true_var = analyze_variance_recursive(
        param_name,
        cond.true_type,
        position,
      )
      let false_var = analyze_variance_recursive(
        param_name,
        cond.false_type,
        position,
      )
      combine_variances(
        check_var,
        combine_variances(extends_var, combine_variances(true_var, false_var)),
      )
    }

    // Other types don't contain our parameter
    _ => Bivariant
  }
}

///|
/// Flip the position (for contravariant contexts)
pub fn flip_position(pos : TypePosition) -> TypePosition {
  match pos {
    Output => Input
    Input => Output
  }
}

///|
/// Combine two variances
pub fn combine_variances(v1 : Variance, v2 : Variance) -> Variance {
  match (v1, v2) {
    // Bivariant with anything is the other thing
    (Bivariant, other) => other
    (other, Bivariant) => other

    // Same variance stays the same
    (Covariant, Covariant) => Covariant
    (Contravariant, Contravariant) => Contravariant
    (Invariant, _) => Invariant
    (_, Invariant) => Invariant

    // Different variances combine to invariant
    (Covariant, Contravariant) => Invariant
    (Contravariant, Covariant) => Invariant
  }
}

///|
/// Check if variance assignment is compatible
pub fn is_variance_compatible(
  actual : Variance,
  expected : Variance,
) -> Bool {
  match (actual, expected) {
    // Same variance is always compatible
    _ if actual == expected => true
    // Bivariant is compatible with everything
    (Bivariant, _) => true
    (_, Bivariant) => true
    // Invariant is only compatible with itself
    (Invariant, _) => false
    (_, Invariant) => false
    // Otherwise incompatible
    _ => false
  }
}

// ============================================================================
// Recursive Generic Type Resolution
// ============================================================================
// Handles recursive type definitions like:
// type Node<T> = { value: T, next: Node<T> | null }

///|
/// State for tracking recursive type resolution
struct RecursiveResolutionState {
  // Types currently being resolved (for cycle detection)
  in_progress : Map[String, Bool]
  // Resolved types cache
  resolved : Map[String, TypeV2]
  // Maximum recursion depth
  max_depth : Int
  // Current depth
  current_depth : Int
}

///|
/// Create a new recursive resolution state
pub fn RecursiveResolutionState::new() -> RecursiveResolutionState {
  {
    in_progress: Map::new(),
    resolved: Map::new(),
    max_depth: 20, // Reasonable limit for recursive types
    current_depth: 0,
  }
}

///|
/// Result of recursive resolution
pub struct RecursiveResolutionResult {
  resolved_type : TypeV2
  has_cycle : Bool
  error : String?
}

///|
/// Resolve a potentially recursive type reference
pub fn resolve_recursive_type(
  state : RecursiveResolutionState,
  type_name : String,
  type_args : Array[TypeV2],
  resolve_fn : (String, Array[TypeV2]) -> TypeV2?,
) -> RecursiveResolutionResult {
  // Create a unique key for this type instantiation
  let key = create_type_key(type_name, type_args)

  // Check for cycles
  if state.in_progress.get(key).unwrap_or(false) {
    // We've encountered this type while resolving it - it's recursive
    // Return a placeholder that references back
    return {
      resolved_type: TGenericInstance(type_name, type_args),
      has_cycle: true,
      error: None,
    }
  }

  // Check if already resolved
  match state.resolved.get(key) {
    Some(ty) =>
      return { resolved_type: ty, has_cycle: false, error: None }
    None => ()
  }

  // Check depth limit
  if state.current_depth >= state.max_depth {
    return {
      resolved_type: TAny,
      has_cycle: false,
      error: Some("Maximum recursion depth exceeded when resolving type '" + type_name + "'"),
    }
  }

  // Mark as in progress
  state.in_progress.set(key, true)
  // Note: current_depth is in a struct and we'd need mutable access
  // For now, we'll pass state as is

  // Try to resolve
  match resolve_fn(type_name, type_args) {
    Some(resolved) => {
      // Cache the result
      state.resolved.set(key, resolved)
      state.in_progress.set(key, false)
      { resolved_type: resolved, has_cycle: false, error: None }
    }
    None => {
      state.in_progress.set(key, false)
      {
        resolved_type: TGenericInstance(type_name, type_args),
        has_cycle: false,
        error: None,
      }
    }
  }
}

///|
/// Create a unique key for a type instantiation
fn create_type_key(type_name : String, type_args : Array[TypeV2]) -> String {
  if type_args.is_empty() {
    type_name
  } else {
    let args_str = type_args
      .map(fn(t) { type_to_string_simple(t) })
      .join(", ")
    type_name + "<" + args_str + ">"
  }
}

///|
/// Simple type to string for caching keys
fn type_to_string_simple(ty : TypeV2) -> String {
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
    TLiteralBool(b) => b.to_string()
    TLiteralBigInt(s) => s + "n"
    TArray(elem) => type_to_string_simple(elem) + "[]"
    TGenericInstance(name, args) =>
      if args.is_empty() {
        name
      } else {
        name + "<" + args.map(type_to_string_simple).join(", ") + ">"
      }
    TTypeParam(name, _) => name
    _ => "complex"
  }
}

// ============================================================================
// Higher-Order Generics (Generic Type Constructors)
// ============================================================================
// Support for type parameters that themselves take type parameters
// Example: type Apply<F, A> = F extends (arg: A) => infer R ? R : never

///|
/// Higher-kinded type representation
/// Represents a type constructor that takes type arguments
pub struct HigherKindedType {
  /// Name of the type constructor (e.g., "Array", "Promise")
  name : String
  /// Number of type parameters this type constructor takes
  arity : Int
  /// The type parameters with their constraints
  params : Array[TypeParamV2]
  /// The body of the type when applied
  body : TypeV2?
}

///|
/// Create a simple higher-kinded type
pub fn HigherKindedType::new(
  name : String,
  arity : Int,
) -> HigherKindedType {
  { name, arity, params: [], body: None }
}

///|
/// Create a higher-kinded type with parameters
pub fn HigherKindedType::with_params(
  name : String,
  params : Array[TypeParamV2],
  body : TypeV2,
) -> HigherKindedType {
  { name, arity: params.length(), params, body: Some(body) }
}

///|
/// Apply type arguments to a higher-kinded type
pub fn apply_higher_kinded_type(
  hkt : HigherKindedType,
  type_args : Array[TypeV2],
) -> TypeV2 {
  // Check arity
  if type_args.length() != hkt.arity {
    // Partial application or error - return generic instance
    return TGenericInstance(hkt.name, type_args)
  }

  // If we have a body, substitute the type arguments
  match hkt.body {
    Some(body) => {
      // Build substitution map
      let subst : Map[String, TypeV2] = Map::new()
      for i, param in hkt.params {
        if i < type_args.length() {
          subst.set(param.name, type_args[i])
        }
      }
      subst_in_type_v2(body, subst)
    }
    None =>
      // No body - just create instance
      TGenericInstance(hkt.name, type_args)
  }
}

///|
/// Check if a type is a higher-kinded type (a type constructor)
pub fn is_higher_kinded(ty : TypeV2) -> Bool {
  match ty {
    TGenericInstance(_, _) => true
    TTypeParam(_, _) => true
    _ => false
  }
}

///|
/// Extract the type constructor from a generic instance
pub fn get_type_constructor(ty : TypeV2) -> String? {
  match ty {
    TGenericInstance(name, _) => Some(name)
    _ => None
  }
}

///|
/// Extract the type arguments from a generic instance
pub fn get_type_arguments(ty : TypeV2) -> Array[TypeV2] {
  match ty {
    TGenericInstance(_, args) => args
    _ => []
  }
}

// ============================================================================
// Integration Functions
// ============================================================================

///|
/// Enhanced type argument inference that handles const parameters
pub fn infer_type_args_with_const(
  func : FunctionTypeV2,
  arg_types : Array[TypeV2],
  explicit_type_args : Array[TypeV2],
) -> Map[String, TypeV2] {
  let inferred : Map[String, TypeV2] = Map::new()

  // First, use any explicit type arguments
  for i, param in func.type_params {
    if i < explicit_type_args.length() {
      inferred.set(param.name, explicit_type_args[i])
    }
  }

  // Then, infer from arguments
  for i, arg_ty in arg_types {
    if i < func.params.length() {
      let param_ty = func.params[i].ty
      do_infer_from_types_with_const(param_ty, arg_ty, func.type_params, inferred)
    }
  }

  inferred
}

///|
/// Inference that respects const type parameters
fn do_infer_from_types_with_const(
  param_ty : TypeV2,
  arg_ty : TypeV2,
  type_params : Array[TypeParamV2],
  inferred : Map[String, TypeV2],
) -> Unit {
  match param_ty {
    TTypeParam(name, _) =>
      if not(inferred.contains(name)) {
        // Check if this is a const parameter
        let is_const = type_params.iter().any(fn(p) { p.name == name && p.is_const })
        if is_const {
          inferred.set(name, narrow_to_const_type(arg_ty))
        } else {
          inferred.set(name, arg_ty)
        }
      }

    TArray(elem_ty) =>
      match arg_ty {
        TArray(arg_elem) =>
          do_infer_from_types_with_const(elem_ty, arg_elem, type_params, inferred)
        TTuple(elems) => {
          // Array matched with tuple - infer from elements
          for elem in elems {
            do_infer_from_types_with_const(elem_ty, elem.ty, type_params, inferred)
          }
        }
        _ => ()
      }

    TTuple(elems) =>
      match arg_ty {
        TTuple(arg_elems) =>
          for i, elem in elems {
            if i < arg_elems.length() {
              do_infer_from_types_with_const(
                elem.ty,
                arg_elems[i].ty,
                type_params,
                inferred,
              )
            }
          }
        _ => ()
      }

    TObject(obj) =>
      match arg_ty {
        TObject(arg_obj) =>
          obj.fields.each(fn(name, field) {
            match arg_obj.fields.get(name) {
              Some(arg_field) =>
                do_infer_from_types_with_const(
                  field.ty,
                  arg_field.ty,
                  type_params,
                  inferred,
                )
              None => ()
            }
          })
        _ => ()
      }

    TFunction(func) =>
      match arg_ty {
        TFunction(arg_func) => {
          do_infer_from_types_with_const(
            func.return_type,
            arg_func.return_type,
            type_params,
            inferred,
          )
          for i, param in func.params {
            if i < arg_func.params.length() {
              do_infer_from_types_with_const(
                param.ty,
                arg_func.params[i].ty,
                type_params,
                inferred,
              )
            }
          }
        }
        _ => ()
      }

    _ => ()
  }
}

///|
/// Analyze and attach variance to type parameters
pub fn compute_type_param_variances(
  type_params : Array[TypeParamV2],
  body_type : TypeV2,
) -> Array[TypeParamV2] {
  type_params.map(fn(param) {
    let variance = analyze_variance(param.name, body_type)
    TypeParamV2::{
      name: param.name,
      constraint: param.constraint,
      default_type: param.default_type,
      is_const: param.is_const,
      variance: Some(variance),
    }
  })
}

// ============================================================================
// Constructor Functions for Read-Only Enums (for tests)
// ============================================================================

///|
/// Create Covariant variance
pub fn Variance::covariant() -> Variance {
  Covariant
}

///|
/// Create Contravariant variance
pub fn Variance::contravariant() -> Variance {
  Contravariant
}

///|
/// Create Invariant variance
pub fn Variance::invariant() -> Variance {
  Invariant
}

///|
/// Create Bivariant variance
pub fn Variance::bivariant() -> Variance {
  Bivariant
}

///|
/// Create Output position
pub fn TypePosition::output() -> TypePosition {
  Output
}

///|
/// Create Input position
pub fn TypePosition::input() -> TypePosition {
  Input
}
