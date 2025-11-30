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

  // ========================================================================
  // Conditional Type Simplifications
  // ========================================================================

  // 1. Never check type simplification:
  // never extends T ? X : Y => never (distribution over empty union is never)
  // This is TypeScript's behavior: never distributes to an empty result
  if check_type == TNever {
    return TNever
  }

  // 2. Reflexive simplification:
  // T extends T ? X : Y => X (type always extends itself)
  if check_type == extends_type {
    return resolve_type(env, cond.true_type)
  }

  // 3. Extends never simplification:
  // T extends never ? X : Y => Y (for non-never T)
  // Only never extends never, all other types don't
  if extends_type == TNever {
    return resolve_type(env, cond.false_type)
  }

  // 4. Any check type simplification:
  // any extends T ? X : Y => X | Y (any can be both true and false)
  if check_type == TAny && extends_type != TAny && extends_type != TUnknown {
    let true_result = resolve_type(env, cond.true_type)
    let false_result = resolve_type(env, cond.false_type)
    return make_union([true_result, false_result])
  }

  // 5. Unknown check type with specific extends:
  // unknown extends T ? X : Y => Y (for T other than unknown/any)
  // unknown only extends unknown and any
  match check_type {
    TUnknown =>
      match extends_type {
        TUnknown | TAny => return resolve_type(env, cond.true_type)
        _ => return resolve_type(env, cond.false_type)
      }
    _ => ()
  }

  // ========================================================================
  // Distribution over unions
  // ========================================================================

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
        type_predicate: f.type_predicate,
        this_type: f.this_type.map(fn(t) { substitute_inferred(env, t, inferred) }),
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
    // Handle generic instances (e.g., DeepReadonly<T[K]> for recursive mapped types)
    TGenericInstance(name, args) => {
      // Resolve all type arguments first
      let resolved_args = args.map(fn(a) { resolve_type(env, a) })
      // Try to resolve the type alias with the resolved arguments
      match env.resolve_type_alias(name, resolved_args) {
        Some(resolved) => resolve_type(env, resolved) // Recursively resolve
        None => TGenericInstance(name, resolved_args)
      }
    }
    // Handle union and intersection types recursively
    TUnion(types) => {
      let resolved = types.map(fn(t) { resolve_type(env, t) })
      make_union(resolved)
    }
    TIntersection(types) => {
      let resolved = types.map(fn(t) { resolve_type(env, t) })
      make_intersection(resolved)
    }
    // Handle array types
    TArray(elem) => TArray(resolve_type(env, elem))
    // Handle tuple types
    TTuple(elems) =>
      TTuple(
        elems.map(fn(e) {
          TupleElementV2::{
            ty: resolve_type(env, e.ty),
            optional: e.optional,
            is_rest: e.is_rest,
            label: e.label,
          }
        }),
      )
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

  // Resolve source type for homomorphic mapped types
  let source_obj = match mapped.source_type {
    Some(st) =>
      match resolve_type(env, st) {
        TObject(obj) => Some(obj)
        _ => None
      }
    None => None
  }

  // Get the keys to iterate over
  let keys = match source_obj {
    Some(obj) => {
      // Use keys from source object for homomorphic mapped types
      let ks : Array[TypeV2] = []
      for kv in obj.fields {
        ks.push(TLiteralString(kv.0))
      }
      ks
    }
    None => get_keys_from_constraint(constraint)
  }

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

    // Get original field info for homomorphic mapped types
    let original_field = match source_obj {
      Some(obj) => obj.fields.get(key_name)
      None => None
    }

    // Apply modifiers (preserving original modifiers for homomorphic mapped types)
    let is_optional = match mapped.optional_modifier {
      Add => true
      Remove => false
      Unchanged =>
        // Homomorphic: preserve original modifier
        match original_field {
          Some(f) => f.optional
          None => false
        }
    }

    let is_readonly = match mapped.readonly_modifier {
      Add => true
      Remove => false
      Unchanged =>
        // Homomorphic: preserve original modifier
        match original_field {
          Some(f) => f.is_readonly
          None => false
        }
    }

    fields.set(actual_key, FieldInfoV2::{
      ty: resolved_value,
      optional: is_optional,
      is_readonly,
    })
  }

  TObject(ObjectTypeV2::{
    fields,
    symbol_fields: [],
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
        type_predicate: f.type_predicate,
        this_type: f.this_type.map(fn(t) { apply_substitution(t, subst) }),
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
/// This handles:
/// - Promise<T> -> T (recursively)
/// - PromiseLike<T> -> T (recursively)
/// - Union types (distribute across union)
/// - Thenable objects with 'then' method
pub fn get_awaited_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TGenericInstance(name, args) =>
      if (name == "Promise" || name == "PromiseLike") && args.length() > 0 {
        // Recursively unwrap nested Promises
        get_awaited_type(args[0])
      } else {
        ty
      }
    TUnion(types) => make_union(types.map(get_awaited_type))
    TObject(obj) => {
      // Check if it's a thenable (has 'then' method)
      match obj.fields.get("then") {
        Some(then_field) =>
          match then_field.ty {
            TFunction(f) =>
              if f.params.length() > 0 {
                // Extract the type from the first callback's first parameter
                // then(onfulfilled: (value: T) => ...) -> T
                match f.params[0].ty {
                  TFunction(callback_f) =>
                    if callback_f.params.length() > 0 {
                      get_awaited_type(callback_f.params[0].ty)
                    } else {
                      ty
                    }
                  _ => ty
                }
              } else {
                ty
              }
            _ => ty
          }
        None => ty
      }
    }
    _ => ty
  }
}

///|
/// Wrap a type in Promise<T>
pub fn wrap_in_promise(ty : TypeV2) -> TypeV2 {
  // Don't double-wrap if already a Promise
  match ty {
    TGenericInstance(name, _) if name == "Promise" => ty
    _ => TGenericInstance("Promise", [ty])
  }
}

///|
/// Get the return type for an async function
/// Async functions always return Promise<T> where T is the inner return type
pub fn get_async_return_type(inner_return_type : TypeV2) -> TypeV2 {
  wrap_in_promise(inner_return_type)
}

///|
/// Get the element type from an async iterator
/// AsyncIterable<T> or AsyncIterator<T> -> T
/// Used for `for await...of` loops
pub fn get_async_iterator_element_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TGenericInstance(name, args) =>
      if (name == "AsyncIterable" || name == "AsyncIterator" ||
          name == "AsyncIterableIterator" || name == "AsyncGenerator") &&
         args.length() > 0 {
        args[0]
      } else {
        ty
      }
    TObject(obj) => {
      // Check for Symbol.asyncIterator method
      match obj.fields.get("[Symbol.asyncIterator]") {
        Some(field) =>
          match field.ty {
            TFunction(f) => get_async_iterator_return_element(f.return_type)
            _ => ty
          }
        None => ty
      }
    }
    _ => ty
  }
}

///|
/// Extract element type from AsyncIterator return type
fn get_async_iterator_return_element(ty : TypeV2) -> TypeV2 {
  match ty {
    TGenericInstance(name, args) =>
      if (name == "AsyncIterator" || name == "AsyncIterableIterator") &&
         args.length() > 0 {
        args[0]
      } else {
        ty
      }
    _ => ty
  }
}

///|
/// Get the element type from a regular iterator
/// Iterable<T> or Iterator<T> -> T
/// Used for `for...of` loops
pub fn get_iterator_element_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TArray(elem) => elem
    TGenericInstance(name, args) =>
      if (name == "Array" || name == "Iterable" || name == "Iterator" ||
          name == "IterableIterator" || name == "Generator" || name == "Set" ||
          name == "Map" || name == "ReadonlyArray") &&
         args.length() > 0 {
        args[0]
      } else if name == "String" {
        TString
      } else {
        ty
      }
    TString => TString // Each character is a string
    TObject(obj) => {
      // Check for Symbol.iterator method
      match obj.fields.get("[Symbol.iterator]") {
        Some(field) =>
          match field.ty {
            TFunction(f) => get_iterator_return_element(f.return_type)
            _ => ty
          }
        None => ty
      }
    }
    _ => ty
  }
}

///|
/// Extract element type from Iterator return type
fn get_iterator_return_element(ty : TypeV2) -> TypeV2 {
  match ty {
    TGenericInstance(name, args) =>
      if (name == "Iterator" || name == "IterableIterator") && args.length() > 0 {
        args[0]
      } else {
        ty
      }
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

// ============================================================================
// Template Literal Type Evaluation
// ============================================================================

///|
/// Evaluate a template literal type: `prefix${T}suffix`
/// This implements TypeScript's template literal type semantics including:
/// - Distribution over unions
/// - Intrinsic string manipulation types (Uppercase, Lowercase, Capitalize, Uncapitalize)
/// - Reduction to string when types are too broad
pub fn evaluate_template_literal_type_v2(
  env : TypeEnv,
  tl : TemplateLiteralTypeV2,
) -> TypeV2 {
  // Resolve all interpolated types
  let resolved_types = tl.types.map(fn(t) { resolve_type(env, t) })

  // Check if any interpolation contains a broad type (string, number)
  // that would make the result too broad to enumerate
  for ty in resolved_types {
    if is_broad_string_type(ty) {
      return TString
    }
  }

  // Get all literal combinations from each interpolation position
  let all_combos = get_literal_combinations(resolved_types)

  // If no valid combinations, return string type
  if all_combos.is_empty() {
    return TString
  }

  // Build all possible template strings
  let results : Array[TypeV2] = []
  for combo in all_combos {
    let result = build_template_string(tl.texts, combo)
    results.push(TLiteralString(result))
  }

  // Return union of all combinations or single literal
  if results.length() == 1 {
    results[0]
  } else {
    make_union(results)
  }
}

///|
/// Check if a type is too broad to enumerate (string, number, any)
fn is_broad_string_type(ty : TypeV2) -> Bool {
  match ty {
    TString | TNumber | TAny => true
    TUnion(types) => types.iter().any(is_broad_string_type)
    _ => false
  }
}

///|
/// Get all literal string combinations from array of types
/// Each type position can have multiple literal values (from unions)
fn get_literal_combinations(types : Array[TypeV2]) -> Array[Array[String]] {
  if types.is_empty() {
    return [[]]
  }

  // Get literals for first type
  let first_literals = extract_literal_strings(types[0])
  if first_literals.is_empty() {
    return []
  }

  // Recursively get combinations for rest
  let rest_types : Array[TypeV2] = []
  for i = 1; i < types.length(); i = i + 1 {
    rest_types.push(types[i])
  }
  let rest_combos = get_literal_combinations(rest_types)

  // Combine first with rest (cartesian product)
  let results : Array[Array[String]] = []
  for first in first_literals {
    for rest in rest_combos {
      let combo : Array[String] = [first]
      for r in rest {
        combo.push(r)
      }
      results.push(combo)
    }
  }
  results
}

///|
/// Extract literal strings from a type
/// Handles string literals, number literals, boolean literals, and unions
fn extract_literal_strings(ty : TypeV2) -> Array[String] {
  match ty {
    TLiteralString(s) => [s]
    TLiteralNumber(n) => [format_number_literal(n)]
    TLiteralBool(b) => [if b { "true" } else { "false" }]
    TNull => ["null"]
    TUndefined => ["undefined"]
    TUnion(types) => {
      let results : Array[String] = []
      for t in types {
        let literals = extract_literal_strings(t)
        for lit in literals {
          if not(results.contains(lit)) {
            results.push(lit)
          }
        }
      }
      results
    }
    _ => []
  }
}

///|
/// Format a number literal for template string
fn format_number_literal(n : Double) -> String {
  // Check if it's an integer
  let int_val = n.to_int()
  if int_val.to_double() == n {
    int_val.to_string()
  } else {
    n.to_string()
  }
}

///|
/// Build a template string from texts and interpolated values
fn build_template_string(texts : Array[String], values : Array[String]) -> String {
  let mut result = ""
  for i in 0..<texts.length() {
    result = result + texts[i]
    if i < values.length() {
      result = result + values[i]
    }
  }
  result
}

// ============================================================================
// Intrinsic String Manipulation Types
// ============================================================================

///|
/// Evaluate Uppercase<T> intrinsic type
pub fn evaluate_uppercase_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TLiteralString(s) => TLiteralString(string_to_uppercase(s))
    TUnion(types) => make_union(types.map(evaluate_uppercase_type))
    TString => TString // Can't uppercase unknown string
    _ => ty
  }
}

///|
/// Evaluate Lowercase<T> intrinsic type
pub fn evaluate_lowercase_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TLiteralString(s) => TLiteralString(string_to_lowercase(s))
    TUnion(types) => make_union(types.map(evaluate_lowercase_type))
    TString => TString
    _ => ty
  }
}

///|
/// Evaluate Capitalize<T> intrinsic type
pub fn evaluate_capitalize_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TLiteralString(s) => TLiteralString(string_capitalize(s))
    TUnion(types) => make_union(types.map(evaluate_capitalize_type))
    TString => TString
    _ => ty
  }
}

///|
/// Evaluate Uncapitalize<T> intrinsic type
pub fn evaluate_uncapitalize_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TLiteralString(s) => TLiteralString(string_uncapitalize(s))
    TUnion(types) => make_union(types.map(evaluate_uncapitalize_type))
    TString => TString
    _ => ty
  }
}

///|
/// Convert string to uppercase
fn string_to_uppercase(s : String) -> String {
  let chars : Array[Char] = s.to_array()
  let result : Array[Char] = []
  for c in chars {
    result.push(char_to_uppercase(c))
  }
  String::from_array(result)
}

///|
/// Convert string to lowercase
fn string_to_lowercase(s : String) -> String {
  let chars : Array[Char] = s.to_array()
  let result : Array[Char] = []
  for c in chars {
    result.push(char_to_lowercase(c))
  }
  String::from_array(result)
}

///|
/// Capitalize first character
fn string_capitalize(s : String) -> String {
  if s.length() == 0 {
    return s
  }
  let chars : Array[Char] = s.to_array()
  chars[0] = char_to_uppercase(chars[0])
  String::from_array(chars)
}

///|
/// Uncapitalize first character
fn string_uncapitalize(s : String) -> String {
  if s.length() == 0 {
    return s
  }
  let chars : Array[Char] = s.to_array()
  chars[0] = char_to_lowercase(chars[0])
  String::from_array(chars)
}

///|
/// Convert a character to uppercase
fn char_to_uppercase(c : Char) -> Char {
  let code = c.to_int()
  if code >= 97 && code <= 122 {
    // 'a' to 'z' -> 'A' to 'Z'
    (code - 32).unsafe_to_char()
  } else {
    c
  }
}

///|
/// Convert a character to lowercase
fn char_to_lowercase(c : Char) -> Char {
  let code = c.to_int()
  if code >= 65 && code <= 90 {
    // 'A' to 'Z' -> 'a' to 'z'
    (code + 32).unsafe_to_char()
  } else {
    c
  }
}

///|
/// Evaluate intrinsic string manipulation type by name
pub fn evaluate_intrinsic_string_type(
  name : String,
  type_arg : TypeV2,
) -> TypeV2? {
  match name {
    "Uppercase" => Some(evaluate_uppercase_type(type_arg))
    "Lowercase" => Some(evaluate_lowercase_type(type_arg))
    "Capitalize" => Some(evaluate_capitalize_type(type_arg))
    "Uncapitalize" => Some(evaluate_uncapitalize_type(type_arg))
    _ => None
  }
}

// ============================================================================
// Template Literal Pattern Matching
// ============================================================================

///|
/// Result of matching a string against a template literal pattern
pub struct TemplateLiteralMatchResult {
  matched : Bool
  inferred_types : Map[String, TypeV2] // infer variable name -> inferred type
} derive(Show)

///|
/// Match a literal string against a template literal pattern
/// Used for type inference in conditional types like:
///   T extends `${infer First}_${infer Rest}` ? [First, Rest] : never
///
/// Returns matched=true and the inferred types if the string matches the pattern
pub fn match_template_literal_pattern(
  value : String,
  pattern : TemplateLiteralTypeV2,
  infer_names : Array[String], // Names of infer type variables at each position
) -> TemplateLiteralMatchResult {
  let inferred : Map[String, TypeV2] = Map::new()

  // Simple case: no interpolations, just match the static text
  if pattern.types.is_empty() {
    if pattern.texts.length() == 1 && value == pattern.texts[0] {
      return { matched: true, inferred_types: inferred }
    } else {
      return { matched: false, inferred_types: inferred }
    }
  }

  // Try to match the pattern against the value
  let match_result = try_match_template_pattern(
    value,
    pattern.texts,
    pattern.types,
    infer_names,
  )

  match match_result {
    Some(inferred_values) => {
      for i, name in infer_names {
        if i < inferred_values.length() {
          inferred.set(name, TLiteralString(inferred_values[i]))
        }
      }
      { matched: true, inferred_types: inferred }
    }
    None => { matched: false, inferred_types: inferred }
  }
}

///|
/// Try to match a string against template pattern parts
/// Returns the inferred string values for each interpolation position
fn try_match_template_pattern(
  value : String,
  texts : Array[String],
  types : Array[TypeV2],
  infer_names : Array[String],
) -> Array[String]? {
  let mut remaining = value
  let inferred_values : Array[String] = []

  // Process each text segment and interpolation
  for i in 0..<texts.length() {
    let text = texts[i]

    // First text segment must be a prefix
    if i == 0 {
      if not(tl_string_starts_with(remaining, text)) {
        return None
      }
      remaining = tl_string_substring(remaining, text.length())
    } else {
      // Find where the text segment occurs in the remaining string
      let text_pos = tl_string_index_of(remaining, text)
      if text_pos < 0 {
        return None
      }

      // The inferred value is everything before the text segment
      let inferred = tl_string_substring_range(remaining, 0, text_pos)

      // Check if the inferred value matches the expected type constraint
      if i - 1 < types.length() {
        if not(inferred_value_matches_type(inferred, types[i - 1])) {
          return None
        }
      }

      inferred_values.push(inferred)
      remaining = tl_string_substring(remaining, text_pos + text.length())
    }
  }

  // Handle the final interpolation (after the last text segment)
  if texts.length() <= types.length() {
    // There's still an interpolation to match
    // The rest of the string is the inferred value
    if types.length() > 0 {
      let last_idx = types.length() - 1
      if inferred_value_matches_type(remaining, types[last_idx]) {
        inferred_values.push(remaining)
      } else {
        return None
      }
    }
  }

  // Verify we have the right number of inferred values
  if inferred_values.length() != infer_names.length() {
    // If we have fewer inferred values, the match failed
    if inferred_values.length() < infer_names.length() {
      return None
    }
  }

  Some(inferred_values)
}

///|
/// Check if an inferred string value matches the expected type constraint
fn inferred_value_matches_type(value : String, ty : TypeV2) -> Bool {
  match ty {
    TString => true // string matches any string
    TInfer(_) => true // infer matches any string
    TLiteralString(expected) => value == expected
    TNumber => is_numeric_string(value)
    TUnion(types) => types.iter().any(fn(t) { inferred_value_matches_type(value, t) })
    _ => true // Be permissive for other types
  }
}

///|
/// Check if a string represents a valid number
fn is_numeric_string(s : String) -> Bool {
  if s.length() == 0 {
    return false
  }
  let mut has_digit = false
  let mut has_dot = false
  let mut i = 0

  // Handle leading minus
  if s.length() > 0 && s[0] == '-' {
    i = 1
  }

  while i < s.length() {
    let c = s[i].unsafe_to_char()
    if c >= '0' && c <= '9' {
      has_digit = true
    } else if c == '.' && not(has_dot) {
      has_dot = true
    } else {
      return false
    }
    i = i + 1
  }
  has_digit
}

// ============================================================================
// Template Literal Assignment Compatibility
// ============================================================================

///|
/// Check if a string literal type is assignable to a template literal type
/// For example: "hello_world" assignable to `hello_${string}`
pub fn is_assignable_to_template_literal(
  source : TypeV2,
  target : TemplateLiteralTypeV2,
) -> Bool {
  match source {
    TLiteralString(value) => matches_template_literal_pattern(value, target)
    TString =>
      // string is only assignable if template reduces to string
      is_template_literal_broad(target)
    TUnion(types) =>
      // All union members must be assignable
      types.iter().all(fn(t) { is_assignable_to_template_literal(t, target) })
    _ => false
  }
}

///|
/// Check if a template literal type is "broad" (equivalent to string)
fn is_template_literal_broad(tl : TemplateLiteralTypeV2) -> Bool {
  // A template is broad if any interpolation is string/number/any
  for ty in tl.types {
    match ty {
      TString | TNumber | TAny => return true
      _ => ()
    }
  }
  false
}

///|
/// Check if a concrete string value matches a template literal pattern
pub fn matches_template_literal_pattern(
  value : String,
  pattern : TemplateLiteralTypeV2,
) -> Bool {
  // Empty pattern (just texts)
  if pattern.types.is_empty() {
    return pattern.texts.length() == 1 && value == pattern.texts[0]
  }

  // Try to match the pattern
  let mut remaining = value

  for i in 0..<pattern.texts.length() {
    let text = pattern.texts[i]

    if i == 0 {
      // First text must be prefix
      if not(tl_string_starts_with(remaining, text)) {
        return false
      }
      remaining = tl_string_substring(remaining, text.length())
    } else {
      // Handle empty text segment at the end specially
      if text.length() == 0 && i == pattern.texts.length() - 1 {
        // Empty suffix means capture everything remaining
        if i - 1 < pattern.types.length() {
          if not(string_matches_interpolation_type(remaining, pattern.types[i - 1])) {
            return false
          }
        }
        remaining = ""
      } else {
        // Find this text segment
        let pos = tl_string_index_of(remaining, text)
        if pos < 0 {
          return false
        }

        // Check that the value before matches the expected type
        if i - 1 < pattern.types.length() {
          let captured = tl_string_substring_range(remaining, 0, pos)
          if not(string_matches_interpolation_type(captured, pattern.types[i - 1])) {
            return false
          }
        }

        remaining = tl_string_substring(remaining, pos + text.length())
      }
    }
  }

  // Check final interpolation if exists
  if pattern.texts.length() <= pattern.types.length() && remaining.length() > 0 {
    let last_type = pattern.types[pattern.types.length() - 1]
    if not(string_matches_interpolation_type(remaining, last_type)) {
      return false
    }
    remaining = ""
  }

  // All remaining string should be consumed
  remaining.length() == 0 || is_template_literal_broad(pattern)
}

///|
/// Check if a captured string matches the expected interpolation type
fn string_matches_interpolation_type(captured : String, ty : TypeV2) -> Bool {
  match ty {
    TString => true
    TNumber => is_numeric_string(captured)
    TAny => true
    TLiteralString(expected) => captured == expected
    TLiteralNumber(n) => captured == format_number_literal(n)
    TLiteralBool(b) => captured == (if b { "true" } else { "false" })
    TNull => captured == "null"
    TUndefined => captured == "undefined"
    TUnion(types) =>
      types.iter().any(fn(t) { string_matches_interpolation_type(captured, t) })
    TInfer(_) => true // Infer matches anything
    _ => true // Be permissive
  }
}

// ============================================================================
// String Utility Functions for Template Literal Pattern Matching
// ============================================================================

///|
/// Check if string starts with prefix (for template literal matching)
fn tl_string_starts_with(s : String, prefix : String) -> Bool {
  if prefix.length() > s.length() {
    return false
  }
  let s_chars = s.to_array()
  let p_chars = prefix.to_array()
  for i in 0..<p_chars.length() {
    if s_chars[i] != p_chars[i] {
      return false
    }
  }
  true
}

///|
/// Get substring from start index to end (for template literal matching)
fn tl_string_substring(s : String, start : Int) -> String {
  if start >= s.length() {
    return ""
  }
  let result = StringBuilder::new()
  for i = start; i < s.length(); i = i + 1 {
    result.write_char(s[i].unsafe_to_char())
  }
  result.to_string()
}

///|
/// Get substring from start to end index (exclusive) (for template literal matching)
fn tl_string_substring_range(s : String, start : Int, end_idx : Int) -> String {
  if start >= s.length() || start >= end_idx {
    return ""
  }
  let actual_end = if end_idx > s.length() { s.length() } else { end_idx }
  let result = StringBuilder::new()
  for i = start; i < actual_end; i = i + 1 {
    result.write_char(s[i].unsafe_to_char())
  }
  result.to_string()
}

///|
/// Find index of substring in string, returns -1 if not found (for template literal matching)
fn tl_string_index_of(s : String, substr : String) -> Int {
  if substr.length() == 0 {
    return 0
  }
  if substr.length() > s.length() {
    return -1
  }

  let s_chars = s.to_array()
  let sub_chars = substr.to_array()
  let max_start = s_chars.length() - sub_chars.length()

  for i in 0..=max_start {
    let mut found = true
    for j in 0..<sub_chars.length() {
      if s_chars[i + j] != sub_chars[j] {
        found = false
        break
      }
    }
    if found {
      return i
    }
  }
  -1
}

// ============================================================================
// Template Literal Type Compatibility in Type Checker
// ============================================================================

///|
/// Check if two template literal types are compatible
/// Source is assignable to target if source produces subset of target's values
pub fn are_template_literals_compatible(
  source : TemplateLiteralTypeV2,
  target : TemplateLiteralTypeV2,
) -> Bool {
  // Same structure check
  if source.texts.length() != target.texts.length() {
    return false
  }
  if source.types.length() != target.types.length() {
    return false
  }

  // Check text segments match
  for i in 0..<source.texts.length() {
    if source.texts[i] != target.texts[i] {
      return false
    }
  }

  // Check interpolation types are compatible
  for i in 0..<source.types.length() {
    if not(is_interpolation_type_assignable(source.types[i], target.types[i])) {
      return false
    }
  }

  true
}

///|
/// Check if source interpolation type is assignable to target
fn is_interpolation_type_assignable(source : TypeV2, target : TypeV2) -> Bool {
  match (source, target) {
    (_, TAny) => true
    (_, TString) => true // Any string-like type is assignable to string position
    (_, TNumber) =>
      match source {
        TNumber | TLiteralNumber(_) => true
        _ => false
      }
    (TLiteralString(s1), TLiteralString(s2)) => s1 == s2
    (TLiteralNumber(n1), TLiteralNumber(n2)) => n1 == n2
    (TUnion(src_types), _) =>
      src_types.iter().all(fn(t) { is_interpolation_type_assignable(t, target) })
    (_, TUnion(tgt_types)) =>
      tgt_types.iter().any(fn(t) { is_interpolation_type_assignable(source, t) })
    _ => source == target
  }
}

// ============================================================================
// Advanced Utility Types
// ============================================================================

///|
/// Implement ConstructorParameters<T> - get parameter types of a constructor as tuple
/// Similar to Parameters<T> but for construct signatures
pub fn get_constructor_parameters_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) =>
      // Check construct signatures
      if not(obj.construct_signatures.is_empty()) {
        let sig = obj.construct_signatures[0]
        let elems = sig.params.map(fn(p) {
          TupleElementV2::{
            ty: p.ty,
            optional: p.optional,
            is_rest: p.is_rest,
            label: Some(p.name),
          }
        })
        TTuple(elems)
      } else {
        TTuple([])
      }
    TFunction(f) => {
      // Treat function as constructor
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
/// Implement ThisParameterType<T> - extract the `this` parameter type from a function
/// Returns `unknown` if the function has no explicit `this` parameter
pub fn get_this_parameter_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TFunction(f) =>
      match f.this_type {
        Some(this_ty) => this_ty
        None => TUnknown
      }
    _ => TUnknown
  }
}

///|
/// Implement OmitThisParameter<T> - remove the `this` parameter from a function type
/// Returns the function type with this_type set to None
pub fn omit_this_parameter(ty : TypeV2) -> TypeV2 {
  match ty {
    TFunction(f) =>
      TFunction({
        type_params: f.type_params,
        params: f.params,
        rest_param: f.rest_param,
        return_type: f.return_type,
        type_predicate: f.type_predicate,
        this_type: None,
      })
    _ => ty
  }
}

///|
/// Resolve a built-in utility type by name with type arguments
/// Returns None if not a recognized utility type
pub fn resolve_builtin_utility_type(
  name : String,
  type_args : Array[TypeV2],
) -> TypeV2? {
  match name {
    "Partial" =>
      if type_args.length() >= 1 {
        Some(make_partial(type_args[0]))
      } else {
        None
      }
    "Required" =>
      if type_args.length() >= 1 {
        Some(make_required(type_args[0]))
      } else {
        None
      }
    "Readonly" =>
      if type_args.length() >= 1 {
        Some(make_readonly_type(type_args[0]))
      } else {
        None
      }
    "Pick" =>
      if type_args.length() >= 2 {
        let keys = extract_literal_strings(type_args[1])
        Some(make_pick(type_args[0], keys))
      } else {
        None
      }
    "Omit" =>
      if type_args.length() >= 2 {
        let keys = extract_literal_strings(type_args[1])
        Some(make_omit(type_args[0], keys))
      } else {
        None
      }
    "Extract" =>
      if type_args.length() >= 2 {
        Some(make_extract(type_args[0], type_args[1]))
      } else {
        None
      }
    "Exclude" =>
      if type_args.length() >= 2 {
        Some(make_exclude(type_args[0], type_args[1]))
      } else {
        None
      }
    "NonNullable" =>
      if type_args.length() >= 1 {
        Some(make_non_nullable(type_args[0]))
      } else {
        None
      }
    "ReturnType" =>
      if type_args.length() >= 1 {
        Some(get_return_type(type_args[0]))
      } else {
        None
      }
    "Parameters" =>
      if type_args.length() >= 1 {
        Some(get_parameters_type(type_args[0]))
      } else {
        None
      }
    "ConstructorParameters" =>
      if type_args.length() >= 1 {
        Some(get_constructor_parameters_type(type_args[0]))
      } else {
        None
      }
    "InstanceType" =>
      if type_args.length() >= 1 {
        Some(get_instance_type(type_args[0]))
      } else {
        None
      }
    "ThisParameterType" =>
      if type_args.length() >= 1 {
        Some(get_this_parameter_type(type_args[0]))
      } else {
        None
      }
    "OmitThisParameter" =>
      if type_args.length() >= 1 {
        Some(omit_this_parameter(type_args[0]))
      } else {
        None
      }
    "Awaited" =>
      if type_args.length() >= 1 {
        Some(get_awaited_type(type_args[0]))
      } else {
        None
      }
    "Uppercase" =>
      if type_args.length() >= 1 {
        Some(evaluate_uppercase_type(type_args[0]))
      } else {
        None
      }
    "Lowercase" =>
      if type_args.length() >= 1 {
        Some(evaluate_lowercase_type(type_args[0]))
      } else {
        None
      }
    "Capitalize" =>
      if type_args.length() >= 1 {
        Some(evaluate_capitalize_type(type_args[0]))
      } else {
        None
      }
    "Uncapitalize" =>
      if type_args.length() >= 1 {
        Some(evaluate_uncapitalize_type(type_args[0]))
      } else {
        None
      }
    _ => None
  }
}

// ============================================================================
// Declaration Merging Support
// ============================================================================

///|
/// Merge two ObjectTypeV2 types (for interface/namespace declaration merging)
/// This implements TypeScript's declaration merging semantics:
/// - Fields from both objects are combined
/// - Symbol fields from both objects are combined
/// - Call signatures are concatenated
/// - Construct signatures are concatenated
/// - Index signatures are merged (later declaration wins)
pub fn merge_object_types(a : ObjectTypeV2, b : ObjectTypeV2) -> ObjectTypeV2 {
  // Merge fields - b's fields override a's fields with same name
  let merged_fields : Map[String, FieldInfoV2] = Map::new()
  a.fields.each(fn(name, field) { merged_fields.set(name, field) })
  b.fields.each(fn(name, field) { merged_fields.set(name, field) })

  // Merge symbol fields
  let merged_symbol_fields : Array[SymbolPropertyV2] = []
  for sf in a.symbol_fields {
    merged_symbol_fields.push(sf)
  }
  for sf in b.symbol_fields {
    merged_symbol_fields.push(sf)
  }

  // Merge call signatures - concatenate
  let merged_call_signatures : Array[FunctionTypeV2] = []
  for sig in a.call_signatures {
    merged_call_signatures.push(sig)
  }
  for sig in b.call_signatures {
    merged_call_signatures.push(sig)
  }

  // Merge construct signatures - concatenate
  let merged_construct_signatures : Array[FunctionTypeV2] = []
  for sig in a.construct_signatures {
    merged_construct_signatures.push(sig)
  }
  for sig in b.construct_signatures {
    merged_construct_signatures.push(sig)
  }

  // Merge index signatures - prefer b's
  let merged_index_signature = match (a.index_signature, b.index_signature) {
    (_, Some(sig)) => Some(sig)
    (Some(sig), None) => Some(sig)
    (None, None) => None
  }

  ObjectTypeV2::{
    fields: merged_fields,
    symbol_fields: merged_symbol_fields,
    call_signatures: merged_call_signatures,
    construct_signatures: merged_construct_signatures,
    index_signature: merged_index_signature,
    is_class: a.is_class || b.is_class,
    class_name: match (a.class_name, b.class_name) {
      (Some(n), _) => Some(n)
      (None, Some(n)) => Some(n)
      (None, None) => None
    },
  }
}

///|
/// Merge multiple object types into one (for multiple interface declarations)
pub fn merge_multiple_object_types(types : Array[ObjectTypeV2]) -> ObjectTypeV2 {
  if types.length() == 0 {
    return ObjectTypeV2::empty()
  }
  if types.length() == 1 {
    return types[0]
  }
  let mut result = types[0]
  for i = 1; i < types.length(); i = i + 1 {
    result = merge_object_types(result, types[i])
  }
  result
}

///|
/// Merge two TypeV2 types (for declaration merging)
/// This handles merging at the type level, particularly for interfaces
pub fn merge_types(a : TypeV2, b : TypeV2) -> TypeV2 {
  match (a, b) {
    // Merge two object types (interfaces)
    (TObject(obj_a), TObject(obj_b)) => TObject(merge_object_types(obj_a, obj_b))
    // For other types, prefer the second (later declaration)
    (_, other) => other
  }
}
