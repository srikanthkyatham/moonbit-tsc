// Generic Type System - Type Argument Inference and Constraint Checking
// Implements Phase 1 of the TypeScript compiler feature gap:
// 1. Generic type instantiation
// 2. Type argument inference from call arguments
// 3. Constraint checking (T extends Base)

// ============================================================================
// AST Type Node to TypeV2 Conversion
// ============================================================================

///|
/// Convert an AST type node to TypeV2
pub fn ast_type_to_v2(env : TypeEnv, node : Node) -> TypeV2 {
  match node {
    // Keyword types (number, string, boolean, etc.)
    KeywordType(kt) =>
      match kt.kind {
        Any => TAny
        Unknown => TUnknown
        Never => TNever
        Void => TVoid
        Undefined => TUndefined
        Null => TNull
        Boolean => TBoolean
        Number => TNumber
        String => TString
        Symbol => TSymbol
        BigInt => TBigInt
        Object => TObject(ObjectTypeV2::empty())
        Const => TAny // as const is handled elsewhere
      }

    // Type reference (e.g., Array<T>, MyType, T)
    TypeReference(tr) => {
      // First check if it's a type parameter in scope
      match env.lookup_type_param(tr.type_name) {
        Some(param) => TTypeParam(param.name, param.constraint)
        None => {
          // Convert type arguments
          let type_args : Array[TypeV2] = tr.type_arguments.map(fn(arg) {
            ast_type_to_v2(env, arg)
          })

          // Check for type alias
          match env.resolve_type_alias(tr.type_name, type_args) {
            Some(resolved) => resolved
            None =>
              // Check for interface
              match env.lookup_interface(tr.type_name) {
                Some(obj) => TObject(obj)
                None =>
                  // Return as generic instance if it has type args, otherwise as type param
                  if type_args.is_empty() {
                    // Could be an unresolved type reference
                    TGenericInstance(tr.type_name, [])
                  } else {
                    TGenericInstance(tr.type_name, type_args)
                  }
              }
          }
        }
      }
    }

    // Union type (A | B | C)
    UnionType(ut) => {
      let types = ut.types.map(fn(t) { ast_type_to_v2(env, t) })
      make_union(types)
    }

    // Intersection type (A & B)
    IntersectionType(it) => {
      let types = it.types.map(fn(t) { ast_type_to_v2(env, t) })
      make_intersection(types)
    }

    // Array type (T[])
    ArrayType(at) => TArray(ast_type_to_v2(env, at.element_type))

    // Tuple type ([A, B, C])
    TupleType(tt) => {
      let elements = tt.element_types.map(fn(elem) {
        match elem {
          NamedTupleMember(ntm) =>
            TupleElementV2::{
              ty: ast_type_to_v2(env, ntm.element_type),
              optional: ntm.is_optional,
              is_rest: false,
              label: Some(ntm.name),
            }
          OptionalType(ot) =>
            TupleElementV2::{
              ty: ast_type_to_v2(env, ot.element_type),
              optional: true,
              is_rest: false,
              label: None,
            }
          RestType(rt) =>
            TupleElementV2::{
              ty: ast_type_to_v2(env, rt.element_type),
              optional: false,
              is_rest: true,
              label: None,
            }
          other =>
            TupleElementV2::{
              ty: ast_type_to_v2(env, other),
              optional: false,
              is_rest: false,
              label: None,
            }
        }
      })
      TTuple(elements)
    }

    // Function type ((a: A, b: B) => R)
    FunctionType(ft) => {
      // Convert type parameters
      let type_params = ft.type_parameters.map(fn(tp) {
        TypeParamV2::{
          name: tp.name,
          constraint: match tp.constraint {
            Some(c) => Some(ast_type_to_v2(env, c))
            None => None
          },
          default_type: match tp.default {
            Some(d) => Some(ast_type_to_v2(env, d))
            None => None
          },
          is_const: tp.is_const,
          variance: None,
        }
      })

      // Create child env with type params in scope
      let child_env = env.with_type_params(type_params)

      // Convert parameters, extracting `this` parameter separately
      let params : Array[ParamInfoV2] = []
      let mut this_type : TypeV2? = None
      for p in ft.parameters {
        match p {
          Parameter(param) => {
            // Check for `this` parameter: function foo(this: SomeType, ...)
            if param.is_this_parameter {
              this_type = match param.type_annotation {
                Some(t) => Some(ast_type_to_v2(child_env, t))
                None => Some(TAny)
              }
            } else {
              params.push(ParamInfoV2::{
                name: get_param_name(param.name),
                ty: match param.type_annotation {
                  Some(t) => ast_type_to_v2(child_env, t)
                  None => TAny
                },
                optional: param.is_optional,
                is_rest: param.is_rest,
              })
            }
          }
          _ => params.push(ParamInfoV2::required("unknown", TAny))
        }
      }

      // Check if return type is a type predicate
      let (return_type, type_predicate) : (TypeV2, TypePredicateV2?) = match ft.return_type {
        TypePredicate(tp) => {
          // Type predicate: "x is Type" or "asserts x is Type"
          let predicate_type = match tp.type_node {
            Some(tn) => ast_type_to_v2(child_env, tn)
            None => TAny // "asserts x" without type
          }
          let tp_v2 : TypePredicateV2 = {
            parameter_name: tp.parameter_name,
            predicate_type,
            is_asserts: tp.is_asserts,
          }
          // Return type is boolean for type guards, void for assertion functions
          let ret_ty = if tp.is_asserts { TVoid } else { TBoolean }
          (ret_ty, Some(tp_v2))
        }
        other => (ast_type_to_v2(child_env, other), None)
      }

      TFunction(FunctionTypeV2::{ type_params, params, rest_param: None, return_type, type_predicate, this_type })
    }

    // Literal type
    LiteralType(lt) =>
      match lt.literal {
        StringLiteral(s) => TLiteralString(s.value)
        NumericLiteral(n) => {
          let num_val = @strconv.parse_double(n.value) catch { _ => 0.0 }
          TLiteralNumber(num_val)
        }
        BooleanLiteral(b) => TLiteralBool(b.value)
        NullLiteral(_) => TNull
        _ => TAny
      }

    // Type literal (object type)
    TypeLiteral(tl) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for mem in tl.members {
        match mem {
          TypeLiteralProperty(prop) => {
            let prop_ty = match prop.type_node {
              Some(t) => ast_type_to_v2(env, t)
              None => TAny
            }
            fields.set(prop.name, FieldInfoV2::{
              ty: prop_ty,
              optional: prop.is_optional,
              is_readonly: prop.is_readonly,
            })
          }
          _ => ()
        }
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

    // Conditional type (T extends U ? X : Y)
    ConditionalType(ct) =>
      TConditional(ConditionalTypeV2::{
        check_type: ast_type_to_v2(env, ct.check_type),
        extends_type: ast_type_to_v2(env, ct.extends_type),
        true_type: ast_type_to_v2(env, ct.true_type),
        false_type: ast_type_to_v2(env, ct.false_type),
      })

    // Indexed access type (T[K])
    IndexedAccessType(ia) =>
      TIndexAccess(IndexAccessTypeV2::{
        object_type: ast_type_to_v2(env, ia.object_type),
        index_type: ast_type_to_v2(env, ia.index_type),
      })

    // Type operator (keyof T, typeof x, etc.)
    TypeOperator(to) =>
      match to.operator {
        KeyOf => {
          let inner = ast_type_to_v2(env, to.type_node)
          // For keyof, we'd need to extract the keys - simplified here
          match inner {
            TObject(obj) => {
              let keys : Array[TypeV2] = []
              for kv in obj.fields {
                keys.push(TLiteralString(kv.0))
              }
              make_union(keys)
            }
            _ => TString // Simplified
          }
        }
        TypeOf => TAny // Would need runtime value resolution
        Unique => {
          // unique symbol creates a distinct unique symbol type
          // For type annotations, we use a generated anonymous name
          TUniqueSymbol(UniqueSymbolV2::new("$unique", generate_unique_symbol_id()))
        }
        Readonly => ast_type_to_v2(env, to.type_node) // TODO: mark as readonly
      }

    // Infer type (infer R)
    InferType(it) => TInfer(it.type_parameter)

    // Template literal type
    TemplateLiteralType(tlt) => {
      let texts : Array[String] = [tlt.head]
      let types : Array[TypeV2] = []
      for span in tlt.spans {
        texts.push(span.literal)
        types.push(ast_type_to_v2(env, span.type_node))
      }
      TTemplateLiteral(TemplateLiteralTypeV2::{ texts, types })
    }

    // Mapped type ({ [K in keyof T]: T[K] })
    MappedType(mt) => {
      // Convert type parameter
      let type_param = TypeParamV2::{
        name: mt.type_parameter.name,
        constraint: match mt.type_parameter.constraint {
          Some(c) => Some(ast_type_to_v2(env, c))
          None => None
        },
        default_type: match mt.type_parameter.default {
          Some(d) => Some(ast_type_to_v2(env, d))
          None => None
        },
        is_const: mt.type_parameter.is_const,
        variance: None,
      }

      // Create child env with type param in scope
      let child_env = env.with_type_params([type_param])

      // Get the constraint type (usually keyof T or a union of keys)
      // Also extract source type for homomorphic mapped types
      let (constraint, source_type) = match mt.type_parameter.constraint {
        Some(c) =>
          match c {
            TypeOperator(to) =>
              match to.operator {
                KeyOf => {
                  // This is a homomorphic mapped type: { [K in keyof T]: ... }
                  let inner = ast_type_to_v2(env, to.type_node)
                  let keys = extract_keyof_type(inner)
                  (keys, Some(inner))
                }
                _ => (ast_type_to_v2(env, c), None)
              }
            _ => (ast_type_to_v2(env, c), None)
          }
        None => (TString, None) // Default to string keys
      }

      // Convert name type (for key remapping: { [K in keyof T as NewKey]: V })
      let name_type = match mt.name_type {
        Some(n) => Some(ast_type_to_v2(child_env, n))
        None => None
      }

      // Convert template type
      let template_type = match mt.type_node {
        Some(t) => ast_type_to_v2(child_env, t)
        None => TAny
      }

      // Convert modifiers
      let readonly_modifier = convert_mapped_modifier_v2(mt.readonly_modifier)
      let optional_modifier = convert_mapped_modifier_v2(mt.optional_modifier)

      TMapped(MappedTypeV2::{
        type_param,
        constraint,
        name_type,
        template_type,
        readonly_modifier,
        optional_modifier,
        source_type,
      })
    }

    // Fallback
    _ => TAny
  }
}

///|
/// Helper to get parameter name from node
fn get_param_name(node : Node) -> String {
  match node {
    Identifier(id) => id.name
    _ => "param"
  }
}

///|
/// Extract keys from a type for keyof operator
/// Returns a union of literal string types for object types, or the original type
fn extract_keyof_type(ty : TypeV2) -> TypeV2 {
  match ty {
    TObject(obj) => {
      let keys : Array[TypeV2] = []
      for kv in obj.fields {
        keys.push(TLiteralString(kv.0))
      }
      make_union(keys)
    }
    TUnion(types) => {
      // keyof (A | B) = keyof A & keyof B
      let all_keys : Array[TypeV2] = []
      for t in types {
        match extract_keyof_type(t) {
          TUnion(ks) => all_keys.append(ks)
          k => all_keys.push(k)
        }
      }
      // For simplicity, return a union of all keys (intersection would be more accurate)
      make_union(all_keys)
    }
    TIntersection(types) => {
      // keyof (A & B) = keyof A | keyof B
      let all_keys : Array[TypeV2] = []
      for t in types {
        match extract_keyof_type(t) {
          TUnion(ks) => all_keys.append(ks)
          k => all_keys.push(k)
        }
      }
      make_union(all_keys)
    }
    TAny => TString // keyof any = string | number | symbol
    TUnknown => TNever // keyof unknown = never
    _ => ty // Can't extract keys, return as-is
  }
}

///|
/// Convert AST mapped type modifier to TypeV2 modifier
fn convert_mapped_modifier_v2(modifier : MappedTypeModifier) -> MappedModifierV2 {
  match modifier {
    Unchanged => MappedModifierV2::Unchanged
    Plus => MappedModifierV2::Add
    Minus => MappedModifierV2::Remove
  }
}

// ============================================================================
// Type Argument Inference
// ============================================================================

///|
/// Result of type argument inference
pub struct InferenceResult {
  inferred_args : Map[String, TypeV2]
  errors : Array[TypeMismatchError]
} derive(Show)

///|
/// Infer type arguments from function call arguments
/// Given a generic function and actual arguments, infer what type arguments should be
pub fn infer_generic_type_args(
  func : FunctionTypeV2,
  arg_types : Array[TypeV2],
  explicit_type_args : Array[TypeV2],
) -> InferenceResult {
  let inferred : Map[String, TypeV2] = Map::new()
  let errors : Array[TypeMismatchError] = []

  // First, use any explicit type arguments
  for i, param in func.type_params {
    if i < explicit_type_args.length() {
      inferred.set(param.name, explicit_type_args[i])
    }
  }

  // Then, try to infer remaining type parameters from argument types
  for i, arg_ty in arg_types {
    if i < func.params.length() {
      let param_ty = func.params[i].ty
      do_infer_from_types(param_ty, arg_ty, inferred)
    }
  }

  // Fill in defaults for any uninferred type parameters
  for param in func.type_params {
    if not(inferred.contains(param.name)) {
      match param.default_type {
        Some(default_ty) => inferred.set(param.name, default_ty)
        None =>
          // Could not infer type - report error
          errors.push(TypeMismatchError::{
            path: PRoot,
            expected: TTypeParam(param.name, param.constraint),
            actual: TUnknown,
            reason: CannotInfer(param.name),
            children: [],
            suggestions: [
              "Provide an explicit type argument: func<" + param.name + ">()",
            ],
          })
      }
    }
  }

  { inferred_args: inferred, errors }
}

///|
/// Infer type parameter bindings by comparing parameter type with argument type
fn do_infer_from_types(
  param_ty : TypeV2,
  arg_ty : TypeV2,
  inferred : Map[String, TypeV2],
) -> Unit {
  match param_ty {
    // Direct type parameter - infer from argument
    TTypeParam(name, _) =>
      if not(inferred.contains(name)) {
        inferred.set(name, arg_ty)
      }

    // Array type - infer from array element
    TArray(elem_ty) =>
      match arg_ty {
        TArray(arg_elem) => do_infer_from_types(elem_ty, arg_elem, inferred)
        _ => ()
      }

    // Tuple type - infer from each element
    TTuple(elems) =>
      match arg_ty {
        TTuple(arg_elems) =>
          for i, elem in elems {
            if i < arg_elems.length() {
              do_infer_from_types(elem.ty, arg_elems[i].ty, inferred)
            }
          }
        _ => ()
      }

    // Object type - infer from matching properties
    TObject(obj) =>
      match arg_ty {
        TObject(arg_obj) =>
          for kv in obj.fields {
            let prop_name = kv.0
            let field = kv.1
            match arg_obj.fields.get(prop_name) {
              Some(arg_field) => do_infer_from_types(field.ty, arg_field.ty, inferred)
              None => ()
            }
          }
        _ => ()
      }

    // Function type - infer from return type and parameters
    TFunction(func) =>
      match arg_ty {
        TFunction(arg_func) => {
          // Infer from return type
          do_infer_from_types(func.return_type, arg_func.return_type, inferred)
          // Infer from parameters (contravariant)
          for i, param in func.params {
            if i < arg_func.params.length() {
              do_infer_from_types(param.ty, arg_func.params[i].ty, inferred)
            }
          }
        }
        _ => ()
      }

    // Generic instance - infer from type arguments
    TGenericInstance(gen_name, args) =>
      match arg_ty {
        TGenericInstance(arg_name, arg_args) if gen_name == arg_name =>
          for i, arg in args {
            if i < arg_args.length() {
              do_infer_from_types(arg, arg_args[i], inferred)
            }
          }
        _ => ()
      }

    // Union type - try each member
    TUnion(types) =>
      match arg_ty {
        TUnion(arg_types) =>
          // For unions, we need to find matching members
          for ty in types {
            for arg in arg_types {
              do_infer_from_types(ty, arg, inferred)
            }
          }
        single =>
          // Argument is a single type that should match one union member
          for ty in types {
            do_infer_from_types(ty, single, inferred)
          }
      }

    // Intersection type - infer from all members
    TIntersection(types) =>
      for ty in types {
        do_infer_from_types(ty, arg_ty, inferred)
      }

    // Other types - no inference needed
    _ => ()
  }
}

// ============================================================================
// Constraint Checking
// ============================================================================

///|
/// Check if type argument satisfies the constraint of a type parameter
pub fn check_constraint(
  type_param : TypeParamV2,
  type_arg : TypeV2,
) -> Array[TypeMismatchError] {
  match type_param.constraint {
    None => [] // No constraint to check
    Some(constraint) =>
      if is_subtype_of(type_arg, constraint) {
        []
      } else {
        [
          TypeMismatchError::{
            path: PRoot,
            expected: constraint,
            actual: type_arg,
            reason: ConstraintNotSatisfied(type_param.name, constraint),
            children: [],
            suggestions: [],
          },
        ]
      }
  }
}

///|
/// Check all type arguments against their constraints
pub fn check_all_constraints(
  type_params : Array[TypeParamV2],
  type_args : Array[TypeV2],
) -> Array[TypeMismatchError] {
  let errors : Array[TypeMismatchError] = []
  for i, param in type_params {
    if i < type_args.length() {
      errors.append(check_constraint(param, type_args[i]))
    }
  }
  errors
}

///|
/// Check if `source` is a subtype of `target` (simplified structural check)
/// Entry point - creates a fresh context for cycle detection
fn is_subtype_of(source : TypeV2, target : TypeV2) -> Bool {
  let ctx = RecursiveComparisonContext::new()
  is_subtype_of_with_ctx(source, target, ctx)
}

///|
/// Check if `source` is a subtype of `target` with cycle detection context
fn is_subtype_of_with_ctx(
  source : TypeV2,
  target : TypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  // Same type
  if source == target {
    return true
  }

  // Check for cycle - if we're already comparing these types, assume true
  if ctx.is_comparing(source, target) {
    return true
  }

  // Check recursion depth
  match ctx.child() {
    None => return true // Depth limit exceeded, assume compatible
    Some(_) => ()
  }

  // Mark as being compared
  let ctx = ctx.start_comparing(source, target)

  // Any is subtype of everything (except never) and everything is subtype of any
  let result = match (source, target) {
    (TAny, _) => true
    (_, TAny) => true
    (_, TUnknown) => true // Everything is subtype of unknown
    (TNever, _) => true // Never is subtype of everything

    // Literal types are subtypes of their base types
    (TLiteralString(_), TString) => true
    (TLiteralNumber(_), TNumber) => true
    (TLiteralBool(_), TBoolean) => true
    (TLiteralBigInt(_), TBigInt) => true

    // Union: source must be subtype of at least one target member
    (src, TUnion(target_types)) =>
      target_types.iter().any(fn(t) { is_subtype_of_with_ctx(src, t, ctx) })

    // Source union: all members must be subtypes of target
    (TUnion(source_types), tgt) =>
      source_types.iter().all(fn(s) { is_subtype_of_with_ctx(s, tgt, ctx) })

    // Intersection target: source must be subtype of all members
    (src, TIntersection(target_types)) =>
      target_types.iter().all(fn(t) { is_subtype_of_with_ctx(src, t, ctx) })

    // Source intersection: at least one member must be subtype of target
    (TIntersection(source_types), tgt) =>
      source_types.iter().any(fn(s) { is_subtype_of_with_ctx(s, tgt, ctx) })

    // Array types - covariant
    (TArray(src_elem), TArray(tgt_elem)) =>
      is_subtype_of_with_ctx(src_elem, tgt_elem, ctx)

    // Object types - structural subtyping
    (TObject(src_obj), TObject(tgt_obj)) =>
      is_object_subtype_with_ctx(src_obj, tgt_obj, ctx)

    // Function types - contravariant params, covariant return
    (TFunction(src_func), TFunction(tgt_func)) =>
      is_function_subtype_with_ctx(src_func, tgt_func, ctx)

    // Generic instances
    (TGenericInstance(src_name, src_args), TGenericInstance(tgt_name, tgt_args)) =>
      if src_name != tgt_name || src_args.length() != tgt_args.length() {
        false
      } else {
        let mut all_match = true
        for i, src_arg in src_args {
          if i < tgt_args.length() {
            if not(is_subtype_of_with_ctx(src_arg, tgt_args[i], ctx)) {
              all_match = false
              break
            }
          }
        }
        all_match
      }

    // Tuple types
    (TTuple(src_elems), TTuple(tgt_elems)) => {
      if src_elems.length() < tgt_elems.length() {
        false
      } else {
        let mut result = true
        for i, tgt_elem in tgt_elems {
          if i >= src_elems.length() {
            if not(tgt_elem.optional) {
              result = false
              break
            }
          } else if not(is_subtype_of_with_ctx(src_elems[i].ty, tgt_elem.ty, ctx)) {
            result = false
            break
          }
        }
        result
      }
    }

    // Default - not a subtype
    _ => false
  }

  result
}

///|
/// Check if source object type is subtype of target
fn is_object_subtype(source : ObjectTypeV2, target : ObjectTypeV2) -> Bool {
  // Use the enhanced index signature aware subtype checking
  is_object_subtype_with_index(source, target)
}

///|
/// Check if source object type is subtype of target with cycle detection context
fn is_object_subtype_with_ctx(
  source : ObjectTypeV2,
  target : ObjectTypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  // All required properties in target must exist in source with compatible types
  for kv in target.fields {
    let name = kv.0
    let tgt_field = kv.1
    match source.fields.get(name) {
      None =>
        // If property is missing and not optional, check index signature
        if not(tgt_field.optional) {
          match source.index_signature {
            Some(src_sig) =>
              match get_index_key_type(src_sig.key_type) {
                Some(StringKey) =>
                  if not(is_subtype_of_with_ctx(src_sig.value_type, tgt_field.ty, ctx)) {
                    return false
                  }
                _ => return false
              }
            None => return false
          }
        }
      Some(src_field) =>
        if not(is_subtype_of_with_ctx(src_field.ty, tgt_field.ty, ctx)) {
          return false
        }
    }
  }

  // Check index signature compatibility
  match (source.index_signature, target.index_signature) {
    (Some(src_sig), Some(tgt_sig)) =>
      if not(is_subtype_of_with_ctx(src_sig.value_type, tgt_sig.value_type, ctx)) {
        return false
      }
    (None, Some(_)) => ()
    _ => ()
  }

  true
}

///|
/// Check if source function type is subtype of target
fn is_function_subtype(source : FunctionTypeV2, target : FunctionTypeV2) -> Bool {
  let ctx = RecursiveComparisonContext::new()
  is_function_subtype_with_ctx(source, target, ctx)
}

///|
/// Check if source function type is subtype of target with cycle detection context
fn is_function_subtype_with_ctx(
  source : FunctionTypeV2,
  target : FunctionTypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  // Return type is covariant
  if not(is_subtype_of_with_ctx(source.return_type, target.return_type, ctx)) {
    return false
  }

  // Parameters are contravariant (target params must be subtypes of source params)
  // Also, source can have fewer required params
  for i, tgt_param in target.params {
    if i >= source.params.length() {
      // Source has fewer params - OK if remaining target params are optional
      if not(tgt_param.optional) {
        return false
      }
    } else {
      let src_param = source.params[i]
      // Contravariance: target param type must be subtype of source param type
      if not(is_subtype_of_with_ctx(tgt_param.ty, src_param.ty, ctx)) {
        return false
      }
    }
  }
  true
}

// ============================================================================
// Generic Function Call Checking
// ============================================================================

///|
/// Result of checking a generic function call
pub struct GenericCallResult {
  return_type : TypeV2
  errors : Array[TypeMismatchError]
} derive(Show)

///|
/// Check a call to a generic function
/// Handles explicit type arguments, inference, and constraint checking
pub fn check_generic_call(
  env : TypeEnv,
  func : FunctionTypeV2,
  explicit_type_args : Array[Node],
  arguments : Array[Node],
) -> GenericCallResult {
  let all_errors : Array[TypeMismatchError] = []

  // If no type parameters, just do regular call checking
  if func.type_params.is_empty() {
    let arg_errors = check_call_arguments(env, func, arguments)
    return { return_type: func.return_type, errors: arg_errors }
  }

  // Convert explicit type arguments from AST
  let explicit_args = explicit_type_args.map(fn(node) {
    ast_type_to_v2(env, node)
  })

  // Check explicit type argument count
  if explicit_args.length() > func.type_params.length() {
    all_errors.push(TypeMismatchError::{
      path: PRoot,
      expected: TFunction(func),
      actual: TAny,
      reason: TypeArgMismatch("type arguments", explicit_args.length()),
      children: [],
      suggestions: [
        "Expected " +
        func.type_params.length().to_string() +
        " type arguments, got " +
        explicit_args.length().to_string(),
      ],
    })
  }

  // Infer argument types
  let arg_types = arguments.map(fn(arg) { infer_expr_type(env, arg) })

  // Infer type arguments
  let inference = infer_generic_type_args(func, arg_types, explicit_args)
  all_errors.append(inference.errors)

  // Build the type argument array for substitution
  let type_args : Array[TypeV2] = func.type_params.map(fn(param) {
    match inference.inferred_args.get(param.name) {
      Some(ty) => ty
      None =>
        match param.default_type {
          Some(d) => d
          None => TAny // Fallback
        }
    }
  })

  // Check constraints
  let constraint_errors = check_all_constraints(func.type_params, type_args)
  all_errors.append(constraint_errors)

  // Substitute type arguments into function type
  let instantiated = instantiate_function(func, type_args)

  // Check arguments against instantiated parameter types
  let arg_errors = check_call_arguments_v2(env, instantiated, arguments)
  all_errors.append(arg_errors)

  { return_type: instantiated.return_type, errors: all_errors }
}

///|
/// Helper to infer expression type (delegates to checker)
fn infer_expr_type(env : TypeEnv, node : Node) -> TypeV2 {
  let result = infer_expr_v2(env, node)
  result.ty
}

///|
/// Instantiate a generic function with type arguments
pub fn instantiate_function(
  func : FunctionTypeV2,
  type_args : Array[TypeV2],
) -> FunctionTypeV2 {
  // Build substitution map
  let subst : Map[String, TypeV2] = Map::new()
  for i, param in func.type_params {
    if i < type_args.length() {
      subst.set(param.name, type_args[i])
    }
  }

  // Apply substitution
  FunctionTypeV2::{
    type_params: [], // Instantiated function has no more type params
    params: func.params.map(fn(p) {
      ParamInfoV2::{
        name: p.name,
        ty: subst_in_type_v2(p.ty, subst),
        optional: p.optional,
        is_rest: p.is_rest,
      }
    }),
    rest_param: match func.rest_param {
      None => None
      Some(r) =>
        Some(ParamInfoV2::{
          name: r.name,
          ty: subst_in_type_v2(r.ty, subst),
          optional: r.optional,
          is_rest: r.is_rest,
        })
    },
    return_type: subst_in_type_v2(func.return_type, subst),
    type_predicate: func.type_predicate,
    this_type: func.this_type.map(fn(t) { subst_in_type_v2(t, subst) }),
  }
}

///|
/// Check call arguments against function parameters
fn check_call_arguments(
  env : TypeEnv,
  func : FunctionTypeV2,
  arguments : Array[Node],
) -> Array[TypeMismatchError] {
  let errors : Array[TypeMismatchError] = []
  for i, arg in arguments {
    if i < func.params.length() {
      let param = func.params[i]
      let result = check_against_v2(env, arg, param.ty)
      for err in result.errors {
        errors.push(TypeMismatchError::{
          path: PParameter(err.path, i, param.name),
          expected: err.expected,
          actual: err.actual,
          reason: err.reason,
          children: err.children,
          suggestions: err.suggestions,
        })
      }
    }
  }
  errors
}

///|
/// Check call arguments against instantiated function parameters (V2)
fn check_call_arguments_v2(
  env : TypeEnv,
  func : FunctionTypeV2,
  arguments : Array[Node],
) -> Array[TypeMismatchError] {
  check_call_arguments(env, func, arguments)
}

// ============================================================================
// Function Overload Resolution
// ============================================================================

///|
/// Result of overload resolution
pub struct OverloadResolutionResult {
  /// The matched overload (if any)
  matched_overload : FunctionTypeV2?
  /// Index of the matched overload in the overloads array
  matched_index : Int
  /// Return type of the matched overload
  return_type : TypeV2
  /// Errors from the resolution process
  errors : Array[TypeMismatchError]
} derive(Show)

///|
/// Resolve function call against multiple overload signatures
/// TypeScript uses first-match semantics: try overloads in order, return first match
pub fn resolve_overload(
  env : TypeEnv,
  overloads : Array[FunctionTypeV2],
  explicit_type_args : Array[Node],
  arguments : Array[Node],
) -> OverloadResolutionResult {
  // If no overloads, return error
  if overloads.is_empty() {
    return {
      matched_overload: None,
      matched_index: -1,
      return_type: TError,
      errors: [
        TypeMismatchError::{
          path: PRoot,
          expected: TFunction(FunctionTypeV2::any()),
          actual: TError,
          reason: NotCallable,
          children: [],
          suggestions: [],
        },
      ],
    }
  }

  // If only one overload, use it directly (with detailed error reporting)
  if overloads.length() == 1 {
    let result = check_generic_call(env, overloads[0], explicit_type_args, arguments)
    return {
      matched_overload: Some(overloads[0]),
      matched_index: 0,
      return_type: result.return_type,
      errors: result.errors,
    }
  }

  // Multiple overloads - try each one in order
  let all_overload_errors : Array[Array[TypeMismatchError]] = []
  let arg_types = arguments.map(fn(arg) { infer_expr_type(env, arg) })

  for i, overload in overloads {
    // Convert explicit type arguments
    let explicit_args = explicit_type_args.map(fn(node) {
      ast_type_to_v2(env, node)
    })

    // Try to match this overload
    let match_result = try_match_overload(env, overload, arg_types, explicit_args)

    if match_result.is_match {
      // Found a matching overload - use it
      let result = check_generic_call(env, overload, explicit_type_args, arguments)
      return {
        matched_overload: Some(overload),
        matched_index: i,
        return_type: result.return_type,
        errors: result.errors,
      }
    } else {
      // Collect errors for this overload attempt
      all_overload_errors.push(match_result.errors)
    }
  }

  // No overload matched - create TS2769 error
  let child_errors = create_overload_error_children(overloads, all_overload_errors)
  {
    matched_overload: None,
    matched_index: -1,
    return_type: TError,
    errors: [
      TypeMismatchError::{
        path: PRoot,
        expected: TFunction(overloads[0]),
        actual: TAny,
        reason: NoOverloadMatches(overloads.length()),
        children: child_errors,
        suggestions: [
          "No overload matches this call.",
          "The call has " + arguments.length().to_string() + " argument(s).",
        ],
      },
    ],
  }
}

///|
/// Result of trying to match a single overload
priv struct OverloadMatchResult {
  is_match : Bool
  errors : Array[TypeMismatchError]
}

///|
/// Try to match arguments against a single overload signature
fn try_match_overload(
  _env : TypeEnv,
  overload : FunctionTypeV2,
  arg_types : Array[TypeV2],
  explicit_type_args : Array[TypeV2],
) -> OverloadMatchResult {
  let errors : Array[TypeMismatchError] = []

  // Check argument count
  let required_params = overload.params.filter(fn(p) { not(p.optional) }).length()
  let max_params = if overload.rest_param is Some(_) {
    2147483647 // Effectively unlimited with rest param
  } else {
    overload.params.length()
  }

  if arg_types.length() < required_params {
    errors.push(TypeMismatchError::{
      path: PRoot,
      expected: TFunction(overload),
      actual: TAny,
      reason: ParamCountMismatch(required_params, arg_types.length()),
      children: [],
      suggestions: [],
    })
    return { is_match: false, errors }
  }

  if arg_types.length() > max_params {
    errors.push(TypeMismatchError::{
      path: PRoot,
      expected: TFunction(overload),
      actual: TAny,
      reason: ParamCountMismatch(max_params, arg_types.length()),
      children: [],
      suggestions: [],
    })
    return { is_match: false, errors }
  }

  // Try to infer type arguments
  let inference = infer_generic_type_args(overload, arg_types, explicit_type_args)
  if not(inference.errors.is_empty()) {
    return { is_match: false, errors: inference.errors }
  }

  // Build type arguments array
  let type_args : Array[TypeV2] = overload.type_params.map(fn(param) {
    match inference.inferred_args.get(param.name) {
      Some(ty) => ty
      None =>
        match param.default_type {
          Some(d) => d
          None => TAny
        }
    }
  })

  // Check constraints
  let constraint_errors = check_all_constraints(overload.type_params, type_args)
  if not(constraint_errors.is_empty()) {
    return { is_match: false, errors: constraint_errors }
  }

  // Instantiate the overload with type arguments
  let instantiated = instantiate_function(overload, type_args)

  // Check each argument against corresponding parameter
  for i, arg_ty in arg_types {
    if i < instantiated.params.length() {
      let param = instantiated.params[i]
      if not(is_assignable_to(arg_ty, param.ty)) {
        errors.push(TypeMismatchError::{
          path: PParameter(PRoot, i, param.name),
          expected: param.ty,
          actual: arg_ty,
          reason: ParamTypeMismatch(i, param.name),
          children: [],
          suggestions: [],
        })
      }
    } else if instantiated.rest_param is Some(_) {
      // Check against rest parameter type
      let rest = instantiated.rest_param.unwrap()
      match rest.ty {
        TArray(elem_ty) =>
          if not(is_assignable_to(arg_ty, elem_ty)) {
            errors.push(TypeMismatchError::{
              path: PParameter(PRoot, i, rest.name),
              expected: elem_ty,
              actual: arg_ty,
              reason: ParamTypeMismatch(i, rest.name),
              children: [],
              suggestions: [],
            })
          }
        _ => ()
      }
    }
  }

  { is_match: errors.is_empty(), errors }
}

///|
/// Check if source type is assignable to target type (simplified)
fn is_assignable_to(source : TypeV2, target : TypeV2) -> Bool {
  // Use the existing subtype check
  is_subtype_of(source, target)
}

///|
/// Create child errors showing why each overload didn't match
fn create_overload_error_children(
  overloads : Array[FunctionTypeV2],
  all_errors : Array[Array[TypeMismatchError]],
) -> Array[TypeMismatchError] {
  let children : Array[TypeMismatchError] = []
  for i, _overload in overloads {
    if i < all_errors.length() && not(all_errors[i].is_empty()) {
      // Take first error from this overload attempt
      let err = all_errors[i][0]
      children.push(TypeMismatchError::{
        path: POverload(i),
        expected: err.expected,
        actual: err.actual,
        reason: OverloadCandidateFailed(i),
        children: all_errors[i],
        suggestions: [],
      })
    }
  }
  children
}

