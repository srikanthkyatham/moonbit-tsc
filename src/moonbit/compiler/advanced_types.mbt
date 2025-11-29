// Advanced Types - Conditional, Mapped, and Index Access Type Evaluation
// Implements Phase 3 of the TypeScript compiler feature gap:
// 1. Conditional type evaluation (T extends U ? X : Y)
// 2. Mapped type resolution ({ [K in keyof T]: T[K] })
// 3. Index access type evaluation (T[K])
// 4. Utility type helpers

// ============================================================================
// Conditional Type Evaluation
// ============================================================================

///|
/// Evaluate a conditional type: T extends U ? X : Y
/// This implements TypeScript's conditional type semantics including:
/// - Distributive conditional types over unions
/// - Type parameter resolution
/// - Subtype checking
pub fn evaluate_conditional_type_v2(
  env : TypeEnv,
  cond : ConditionalTypeV2,
) -> TypeV2 {
  let check_type = resolve_type(env, cond.check_type)
  let extends_type = resolve_type(env, cond.extends_type)

  // Distributive conditional types: if check_type is a union, distribute
  match check_type {
    TUnion(types) =>
      // Distribute: (A | B) extends U ? X : Y becomes (A extends U ? X : Y) | (B extends U ? X : Y)
      make_union(
        types.map(fn(t) {
          evaluate_conditional_single(env, t, extends_type, cond.true_type, cond.false_type)
        }),
      )
    TTypeParam(name, _) =>
      // Type parameter - check if we can resolve it
      match env.lookup_type_param(name) {
        Some(param) =>
          match param.constraint {
            Some(_) =>
              // Has constraint, evaluate with resolved type
              evaluate_conditional_single(
                env,
                check_type,
                extends_type,
                cond.true_type,
                cond.false_type,
              )
            None =>
              // Unresolved type param - defer evaluation (return conditional as-is)
              TConditional(cond)
          }
        None =>
          // Unknown type param - defer
          TConditional(cond)
      }
    _ =>
      // Non-union, non-type-param - evaluate directly
      evaluate_conditional_single(
        env,
        check_type,
        extends_type,
        cond.true_type,
        cond.false_type,
      )
  }
}

///|
/// Evaluate a single conditional type check (non-distributive)
fn evaluate_conditional_single(
  env : TypeEnv,
  check_type : TypeV2,
  extends_type : TypeV2,
  true_type : TypeV2,
  false_type : TypeV2,
) -> TypeV2 {
  // Check if check_type extends extends_type
  if is_subtype_check(env, check_type, extends_type) {
    // Extract any inferred types and substitute
    let inferred = extract_inferred_types(check_type, extends_type)
    substitute_inferred(env, true_type, inferred)
  } else {
    resolve_type(env, false_type)
  }
}

///|
/// Check if source extends target (simplified subtype check for conditionals)
fn is_subtype_check(_env : TypeEnv, source : TypeV2, target : TypeV2) -> Bool {
  // Same type
  if source == target {
    return true
  }

  match (source, target) {
    // Any extends anything except never
    (TAny, TNever) => false
    (TAny, _) => true
    (_, TAny) => true
    (_, TUnknown) => true
    (TNever, _) => true

    // Literal types extend their base types
    (TLiteralString(_), TString) => true
    (TLiteralNumber(_), TNumber) => true
    (TLiteralBool(_), TBoolean) => true
    (TLiteralBigInt(_), TBigInt) => true

    // Union: source extends target if all members extend target
    (TUnion(source_types), tgt) =>
      source_types.iter().all(fn(s) { is_subtype_check_simple(s, tgt) })

    // Target union: source extends if it extends any member
    (src, TUnion(target_types)) =>
      target_types.iter().any(fn(t) { is_subtype_check_simple(src, t) })

    // Arrays
    (TArray(src_elem), TArray(tgt_elem)) =>
      is_subtype_check_simple(src_elem, tgt_elem)

    // Tuples
    (TTuple(src_elems), TTuple(tgt_elems)) =>
      check_tuple_extends(src_elems, tgt_elems)

    // Objects - structural
    (TObject(src), TObject(tgt)) => check_object_extends(src, tgt)

    // Functions
    (TFunction(src), TFunction(tgt)) => check_function_extends(src, tgt)

    // Generic instances
    (TGenericInstance(src_name, src_args), TGenericInstance(tgt_name, tgt_args)) =>
      src_name == tgt_name && check_type_args_extend(src_args, tgt_args)

    // Type params with constraints
    (TTypeParam(_, Some(constraint)), target) =>
      is_subtype_check_simple(constraint, target)

    _ => false
  }
}

///|
/// Simple subtype check (no env)
fn is_subtype_check_simple(source : TypeV2, target : TypeV2) -> Bool {
  if source == target {
    return true
  }
  match (source, target) {
    (TAny, _) => true
    (_, TAny) => true
    (_, TUnknown) => true
    (TNever, _) => true
    (TLiteralString(_), TString) => true
    (TLiteralNumber(_), TNumber) => true
    (TLiteralBool(_), TBoolean) => true
    (TLiteralBigInt(_), TBigInt) => true
    (TUnion(types), tgt) =>
      types.iter().all(fn(t) { is_subtype_check_simple(t, tgt) })
    (src, TUnion(types)) =>
      types.iter().any(fn(t) { is_subtype_check_simple(src, t) })
    _ => false
  }
}

///|
/// Check if tuple extends another tuple
fn check_tuple_extends(
  source : Array[TupleElementV2],
  target : Array[TupleElementV2],
) -> Bool {
  // Source must have at least as many elements as target's required elements
  let required_count = target.filter(fn(e) { not(e.optional) }).length()
  if source.length() < required_count {
    return false
  }
  // Check each corresponding element
  for i, tgt_elem in target {
    if i < source.length() {
      if not(is_subtype_check_simple(source[i].ty, tgt_elem.ty)) {
        return false
      }
    } else if not(tgt_elem.optional) {
      return false
    }
  }
  true
}

///|
/// Check if object type extends another
fn check_object_extends(source : ObjectTypeV2, target : ObjectTypeV2) -> Bool {
  // All required fields in target must exist in source with compatible types
  for kv in target.fields {
    let name = kv.0
    let tgt_field = kv.1
    match source.fields.get(name) {
      None =>
        if not(tgt_field.optional) {
          return false
        }
      Some(src_field) =>
        if not(is_subtype_check_simple(src_field.ty, tgt_field.ty)) {
          return false
        }
    }
  }
  true
}

///|
/// Check if function type extends another
fn check_function_extends(
  source : FunctionTypeV2,
  target : FunctionTypeV2,
) -> Bool {
  // Return type is covariant
  if not(is_subtype_check_simple(source.return_type, target.return_type)) {
    return false
  }
  // Parameters are contravariant
  for i, tgt_param in target.params {
    if i >= source.params.length() {
      if not(tgt_param.optional) {
        return false
      }
    } else {
      let src_param = source.params[i]
      // Contravariance: target param must be subtype of source param
      if not(is_subtype_check_simple(tgt_param.ty, src_param.ty)) {
        return false
      }
    }
  }
  true
}

///|
/// Check if type arguments extend
fn check_type_args_extend(
  source : Array[TypeV2],
  target : Array[TypeV2],
) -> Bool {
  if source.length() != target.length() {
    return false
  }
  for i, src in source {
    if not(is_subtype_check_simple(src, target[i])) {
      return false
    }
  }
  true
}

///|
/// Extract inferred types from a conditional type check (for `infer` keyword)
fn extract_inferred_types(
  check_type : TypeV2,
  extends_type : TypeV2,
) -> Map[String, TypeV2] {
  let inferred : Map[String, TypeV2] = Map::new()
  do_extract_inferred(check_type, extends_type, inferred)
  inferred
}

///|
/// Recursively extract inferred types
fn do_extract_inferred(
  check_type : TypeV2,
  extends_type : TypeV2,
  inferred : Map[String, TypeV2],
) -> Unit {
  match extends_type {
    // infer R - capture the type
    TInfer(name) => inferred.set(name, check_type)

    // Recursively check compound types
    TArray(elem_extends) =>
      match check_type {
        TArray(elem_check) => do_extract_inferred(elem_check, elem_extends, inferred)
        _ => ()
      }

    TTuple(elems_extends) =>
      match check_type {
        TTuple(elems_check) =>
          for i, ext_elem in elems_extends {
            if i < elems_check.length() {
              do_extract_inferred(elems_check[i].ty, ext_elem.ty, inferred)
            }
          }
        _ => ()
      }

    TFunction(func_extends) =>
      match check_type {
        TFunction(func_check) => {
          // Extract from return type
          do_extract_inferred(
            func_check.return_type,
            func_extends.return_type,
            inferred,
          )
          // Extract from parameters
          for i, ext_param in func_extends.params {
            if i < func_check.params.length() {
              do_extract_inferred(
                func_check.params[i].ty,
                ext_param.ty,
                inferred,
              )
            }
          }
        }
        _ => ()
      }

    TObject(obj_extends) =>
      match check_type {
        TObject(obj_check) =>
          for kv in obj_extends.fields {
            let name = kv.0
            let ext_field = kv.1
            match obj_check.fields.get(name) {
              Some(chk_field) =>
                do_extract_inferred(chk_field.ty, ext_field.ty, inferred)
              None => ()
            }
          }
        _ => ()
      }

    _ => ()
  }
}

///|
/// Substitute inferred types into a type
fn substitute_inferred(
  env : TypeEnv,
  ty : TypeV2,
  inferred : Map[String, TypeV2],
) -> TypeV2 {
  if inferred.is_empty() {
    return resolve_type(env, ty)
  }

  match ty {
    TInfer(name) =>
      match inferred.get(name) {
        Some(resolved) => resolved
        None => TUnknown // Infer not matched
      }

    TTypeParam(name, constraint) =>
      match inferred.get(name) {
        Some(resolved) => resolved
        None => TTypeParam(name, constraint)
      }

    TArray(elem) => TArray(substitute_inferred(env, elem, inferred))

    TTuple(elems) =>
      TTuple(
        elems.map(fn(e) {
          TupleElementV2::{
            ty: substitute_inferred(env, e.ty, inferred),
            optional: e.optional,
            is_rest: e.is_rest,
            label: e.label,
          }
        }),
      )

    TUnion(types) =>
      make_union(types.map(fn(t) { substitute_inferred(env, t, inferred) }))

    TIntersection(types) =>
      make_intersection(types.map(fn(t) { substitute_inferred(env, t, inferred) }))

    TFunction(f) =>
      TFunction(FunctionTypeV2::{
        type_params: f.type_params,
        params: f.params.map(fn(p) {
          ParamInfoV2::{
            name: p.name,
            ty: substitute_inferred(env, p.ty, inferred),
            optional: p.optional,
            is_rest: p.is_rest,
          }
        }),
        rest_param: match f.rest_param {
          None => None
          Some(r) =>
            Some(ParamInfoV2::{
              name: r.name,
              ty: substitute_inferred(env, r.ty, inferred),
              optional: r.optional,
              is_rest: r.is_rest,
            })
        },
        return_type: substitute_inferred(env, f.return_type, inferred),
      })

    TConditional(c) =>
      // Recursively evaluate the conditional with substituted types
      evaluate_conditional_type_v2(
        env,
        ConditionalTypeV2::{
          check_type: substitute_inferred(env, c.check_type, inferred),
          extends_type: substitute_inferred(env, c.extends_type, inferred),
          true_type: substitute_inferred(env, c.true_type, inferred),
          false_type: substitute_inferred(env, c.false_type, inferred),
        },
      )

    _ => resolve_type(env, ty)
  }
}

///|
/// Resolve type references and evaluate advanced types
fn resolve_type(env : TypeEnv, ty : TypeV2) -> TypeV2 {
  match ty {
    TConditional(c) => evaluate_conditional_type_v2(env, c)
    TMapped(m) => evaluate_mapped_type_v2(env, m)
    TIndexAccess(ia) => evaluate_index_access_type_v2(env, ia)
    TTypeParam(name, _) =>
      // Try to resolve from environment
      match env.lookup_type_param(name) {
        Some(_param) => ty // Keep as type param for now
        None =>
          // Check if it's a type alias
          match env.resolve_type_alias(name, []) {
            Some(resolved) => resolved
            None => ty
          }
      }
    _ => ty
  }
}

// ============================================================================
// Mapped Type Evaluation
// ============================================================================

///|
/// Evaluate a mapped type: { [K in keyof T]: T[K] }
/// This implements TypeScript's mapped type semantics including:
/// - Key iteration over object keys
/// - Template type application
/// - Readonly/optional modifiers
pub fn evaluate_mapped_type_v2(env : TypeEnv, mapped : MappedTypeV2) -> TypeV2 {
  // Resolve the constraint to get the keys
  let constraint = resolve_type(env, mapped.constraint)

  // Get the keys to iterate over
  let keys = get_keys_from_constraint(constraint)

  if keys.is_empty() {
    // Can't evaluate without concrete keys
    return TMapped(mapped)
  }

  // Build the result object type
  let fields : Map[String, FieldInfoV2] = Map::new()

  for key in keys {
    // Get the key name
    let key_name = match key {
      TLiteralString(s) => s
      _ => continue // Skip non-string keys for now
    }

    // Apply key remapping if present
    let actual_key = match mapped.name_type {
      Some(name_ty) => {
        // Substitute K with the current key
        let subst : Map[String, TypeV2] = Map::new()
        subst.set(mapped.type_param.name, key)
        let remapped = apply_substitution(name_ty, subst)
        match remapped {
          TLiteralString(s) => s
          TNever => continue // Skip filtered keys
          _ => key_name
        }
      }
      None => key_name
    }

    // Substitute the type parameter in the template
    let subst : Map[String, TypeV2] = Map::new()
    subst.set(mapped.type_param.name, key)
    let value_type = apply_substitution(mapped.template_type, subst)
    let resolved_value = resolve_type(env, value_type)

    // Apply modifiers
    let is_optional = match mapped.optional_modifier {
      Add => true
      Remove => false
      Unchanged => false // Default to required
    }

    let is_readonly = match mapped.readonly_modifier {
      Add => true
      Remove => false
      Unchanged => false // Default to mutable
    }

    fields.set(actual_key, FieldInfoV2::{
      ty: resolved_value,
      optional: is_optional,
      is_readonly,
    })
  }

  TObject(ObjectTypeV2::{
    fields,
    call_signatures: [],
    construct_signatures: [],
    index_signature: None,
    is_class: false,
    class_name: None,
  })
}

///|
/// Get keys from a constraint type (usually keyof T or a union of literals)
fn get_keys_from_constraint(constraint : TypeV2) -> Array[TypeV2] {
  match constraint {
    // Union of literal strings
    TUnion(types) =>
      types.filter(fn(t) {
        match t {
          TLiteralString(_) => true
          TLiteralNumber(_) => true
          _ => false
        }
      })

    // Single literal
    TLiteralString(_) => [constraint]
    TLiteralNumber(_) => [constraint]

    // String or number type (infinite keys)
    TString | TNumber => []

    // Object type - get its keys
    TObject(obj) => {
      let keys : Array[TypeV2] = []
      for kv in obj.fields {
        keys.push(TLiteralString(kv.0))
      }
      keys
    }

    _ => []
  }
}

///|
/// Apply type substitution
fn apply_substitution(ty : TypeV2, subst : Map[String, TypeV2]) -> TypeV2 {
  match ty {
    TTypeParam(name, _) =>
      match subst.get(name) {
        Some(replacement) => replacement
        None => ty
      }

    TArray(elem) => TArray(apply_substitution(elem, subst))

    TTuple(elems) =>
      TTuple(
        elems.map(fn(e) {
          TupleElementV2::{
            ty: apply_substitution(e.ty, subst),
            optional: e.optional,
            is_rest: e.is_rest,
            label: e.label,
          }
        }),
      )

    TUnion(types) => make_union(types.map(fn(t) { apply_substitution(t, subst) }))

    TIntersection(types) =>
      make_intersection(types.map(fn(t) { apply_substitution(t, subst) }))

    TFunction(f) =>
      TFunction(FunctionTypeV2::{
        type_params: f.type_params,
        params: f.params.map(fn(p) {
          ParamInfoV2::{
            name: p.name,
            ty: apply_substitution(p.ty, subst),
            optional: p.optional,
            is_rest: p.is_rest,
          }
        }),
        rest_param: match f.rest_param {
          None => None
          Some(r) =>
            Some(ParamInfoV2::{
              name: r.name,
              ty: apply_substitution(r.ty, subst),
              optional: r.optional,
              is_rest: r.is_rest,
            })
        },
        return_type: apply_substitution(f.return_type, subst),
      })

    TGenericInstance(name, args) =>
      TGenericInstance(name, args.map(fn(a) { apply_substitution(a, subst) }))

    TConditional(c) =>
      TConditional(ConditionalTypeV2::{
        check_type: apply_substitution(c.check_type, subst),
        extends_type: apply_substitution(c.extends_type, subst),
        true_type: apply_substitution(c.true_type, subst),
        false_type: apply_substitution(c.false_type, subst),
      })

    TIndexAccess(ia) =>
      TIndexAccess(IndexAccessTypeV2::{
        object_type: apply_substitution(ia.object_type, subst),
        index_type: apply_substitution(ia.index_type, subst),
      })

    _ => ty
  }
}

// ============================================================================
// Index Access Type Evaluation
// ============================================================================

///|
/// Evaluate an index access type: T[K]
/// This implements TypeScript's indexed access type semantics
pub fn evaluate_index_access_type_v2(
  env : TypeEnv,
  ia : IndexAccessTypeV2,
) -> TypeV2 {
  let object_type = resolve_type(env, ia.object_type)
  let index_type = resolve_type(env, ia.index_type)

  match (object_type, index_type) {
    // Array[number] => element type
    (TArray(elem), TNumber) => elem
    (TArray(elem), TLiteralNumber(_)) => elem

    // Tuple[number literal] => specific element type
    (TTuple(elems), TLiteralNumber(n)) => {
      let idx = n.to_int()
      if idx >= 0 && idx < elems.length() {
        elems[idx].ty
      } else {
        TUndefined
      }
    }

    // Tuple[number] => union of all element types
    (TTuple(elems), TNumber) =>
      make_union(elems.map(fn(e) { e.ty }))

    // Object[literal key] => property type
    (TObject(obj), TLiteralString(key)) =>
      match obj.fields.get(key) {
        Some(field) =>
          if field.optional {
            make_union([field.ty, TUndefined])
          } else {
            field.ty
          }
        None =>
          // Check index signature
          match obj.index_signature {
            Some(sig) => sig.value_type
            None => TUndefined
          }
      }

    // Object[string] => union of all property types (with index signature)
    (TObject(obj), TString) =>
      match obj.index_signature {
        Some(sig) => sig.value_type
        None => {
          let types : Array[TypeV2] = []
          for kv in obj.fields {
            types.push(kv.1.ty)
          }
          if types.is_empty() {
            TAny
          } else {
            make_union(types)
          }
        }
      }

    // Object[union of keys] => union of corresponding types
    (TObject(obj), TUnion(keys)) => {
      let types : Array[TypeV2] = []
      for key in keys {
        match key {
          TLiteralString(k) =>
            match obj.fields.get(k) {
              Some(field) => types.push(field.ty)
              None => ()
            }
          _ => ()
        }
      }
      if types.is_empty() {
        TUndefined
      } else {
        make_union(types)
      }
    }

    // Generic instance - try to resolve
    (TGenericInstance(name, _args), idx) => {
      // Check for built-in generics like Array
      if name == "Array" {
        match idx {
          TNumber | TLiteralNumber(_) =>
            // Would need to resolve to get element type
            TAny
          _ => TAny
        }
      } else {
        // Can't resolve, return index access as-is
        TIndexAccess(ia)
      }
    }

    // Can't evaluate - keep as index access
    _ => TIndexAccess(ia)
  }
}

// ============================================================================
// Utility Type Helpers
// ============================================================================

///|
/// Implement Partial<T> - makes all properties optional
pub fn make_partial(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for kv in obj.fields {
        fields.set(kv.0, FieldInfoV2::{
          ty: kv.1.ty,
          optional: true,
          is_readonly: kv.1.is_readonly,
        })
      }
      TObject(ObjectTypeV2::{ ..obj, fields })
    }
    _ => ty
  }
}

///|
/// Implement Required<T> - makes all properties required
pub fn make_required(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for kv in obj.fields {
        fields.set(kv.0, FieldInfoV2::{
          ty: kv.1.ty,
          optional: false,
          is_readonly: kv.1.is_readonly,
        })
      }
      TObject(ObjectTypeV2::{ ..obj, fields })
    }
    _ => ty
  }
}

///|
/// Implement Readonly<T> - makes all properties readonly
pub fn make_readonly_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for kv in obj.fields {
        fields.set(kv.0, FieldInfoV2::{
          ty: kv.1.ty,
          optional: kv.1.optional,
          is_readonly: true,
        })
      }
      TObject(ObjectTypeV2::{ ..obj, fields })
    }
    _ => ty
  }
}

///|
/// Implement Pick<T, K> - pick specific properties from T
pub fn make_pick(ty : TypeV2, keys : Array[String]) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for key in keys {
        match obj.fields.get(key) {
          Some(field) => fields.set(key, field)
          None => ()
        }
      }
      TObject(ObjectTypeV2::{ ..obj, fields })
    }
    _ => ty
  }
}

///|
/// Implement Omit<T, K> - omit specific properties from T
pub fn make_omit(ty : TypeV2, keys : Array[String]) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for kv in obj.fields {
        if not(keys.contains(kv.0)) {
          fields.set(kv.0, kv.1)
        }
      }
      TObject(ObjectTypeV2::{ ..obj, fields })
    }
    _ => ty
  }
}

///|
/// Implement Extract<T, U> - extract types from union that are assignable to U
pub fn make_extract(ty : TypeV2, filter_ty : TypeV2) -> TypeV2 {
  match ty {
    TUnion(types) => {
      let filtered = types.filter(fn(t) { is_subtype_check_simple(t, filter_ty) })
      make_union(filtered)
    }
    _ =>
      if is_subtype_check_simple(ty, filter_ty) {
        ty
      } else {
        TNever
      }
  }
}

///|
/// Implement Exclude<T, U> - exclude types from union that are assignable to U
pub fn make_exclude(ty : TypeV2, filter_ty : TypeV2) -> TypeV2 {
  match ty {
    TUnion(types) => {
      let filtered = types.filter(fn(t) {
        not(is_subtype_check_simple(t, filter_ty))
      })
      make_union(filtered)
    }
    _ =>
      if is_subtype_check_simple(ty, filter_ty) {
        TNever
      } else {
        ty
      }
  }
}

///|
/// Implement NonNullable<T> - exclude null and undefined
pub fn make_non_nullable(ty : TypeV2) -> TypeV2 {
  get_non_null_type(ty)
}

///|
/// Implement ReturnType<T> - get return type of a function
pub fn get_return_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TFunction(f) => f.return_type
    _ => TAny
  }
}

///|
/// Implement Parameters<T> - get parameter types as tuple
pub fn get_parameters_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TFunction(f) => {
      let elems = f.params.map(fn(p) {
        TupleElementV2::{
          ty: p.ty,
          optional: p.optional,
          is_rest: p.is_rest,
          label: Some(p.name),
        }
      })
      TTuple(elems)
    }
    _ => TTuple([])
  }
}

///|
/// Implement InstanceType<T> - get instance type of a constructor
pub fn get_instance_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) =>
      // Check construct signatures
      if not(obj.construct_signatures.is_empty()) {
        obj.construct_signatures[0].return_type
      } else {
        TAny
      }
    TFunction(f) =>
      // Treat as constructor
      f.return_type
    _ => TAny
  }
}

///|
/// Implement Awaited<T> - unwrap Promise type
pub fn get_awaited_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TGenericInstance(name, args) =>
      if name == "Promise" && args.length() > 0 {
        // Recursively unwrap nested Promises
        get_awaited_type(args[0])
      } else {
        ty
      }
    TUnion(types) => make_union(types.map(get_awaited_type))
    _ => ty
  }
}

// ============================================================================
// Keyof Operator
// ============================================================================

///|
/// Implement keyof T - get union of property keys
pub fn get_keyof_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let keys : Array[TypeV2] = []
      for kv in obj.fields {
        keys.push(TLiteralString(kv.0))
      }
      if keys.is_empty() {
        TNever
      } else {
        make_union(keys)
      }
    }
    TArray(_) =>
      // Array keys are number + array methods
      TUnion([TNumber, TLiteralString("length")])
    TTuple(elems) => {
      // Tuple keys are numeric indices + length
      let keys : Array[TypeV2] = [TLiteralString("length")]
      for i in 0..<elems.length() {
        keys.push(TLiteralNumber(i.to_double()))
      }
      make_union(keys)
    }
    _ => TString // Default to string for unknown types
  }
}
