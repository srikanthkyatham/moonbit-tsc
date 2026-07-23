// T21: Assignability relation for call/construct signatures, including
// generic signatures (TS2322).
//
// Follows the tsc algorithm (checker.ts signaturesRelatedTo /
// compareSignaturesRelated):
// - When both sides have exactly one signature, signatures compare
//   strictly: the source signature's type parameters are instantiated by
//   inferring from the target's parameter types, the target's type
//   parameters stay opaque, then parameters compare contravariantly and
//   return types covariantly.
// - When either side is overloaded (multiple signatures), every target
//   signature must be matched by some source signature with generics
//   ERASED (type parameters replaced by `any`).
// - A generic source type parameter whose inferred type does not satisfy
//   its constraint is instantiated with the constraint instead.
// - Opaque target type parameters are alpha-renamed to unique marker
//   names registered in `signature_relation_markers`; `is_assignable`
//   treats a registered marker like a tsc type parameter: assignable to
//   itself and (via its constraint) to the constraint's supertypes, and
//   nothing concrete is assignable to it.

///|
/// Opaque type-parameter markers registered while a strict generic
/// signature comparison is in progress: marker name -> optional constraint
let signature_relation_markers : Map[String, Type?] = Map([])

///|
/// Recursion depth guard for the signature relation (signature comparison
/// recurses through is_assignable into nested object/signature types)
let signature_relation_depth : Array[Int] = [0]

///|
/// Counter used to mint unique marker names
let signature_marker_counter : Array[Int] = [0]

///|
/// Class name -> parent class name (None when the class has no extends
/// clause); populated by check_class_declaration and consulted for nominal
/// constraint checks where the general TypeReference relation is
/// deliberately lenient
let class_parent_registry : Map[String, String?] = Map([])

///|
/// Is `name` (transitively) a subclass of `parent` in the registry?
fn registered_subclass_of(name : String, parent : String) -> Bool {
  let mut current = name
  let mut steps = 0
  while steps < 100 {
    match class_parent_registry.get(current) {
      Some(Some(p)) => {
        if p == parent {
          return true
        }
        current = p
      }
      _ => return false
    }
    steps = steps + 1
  }
  false
}

///|
/// Assignability used inside signature comparison: like is_assignable but
/// nominal for known classes (the general TypeReference relation defers
/// different-name comparisons to structural checking done elsewhere and
/// would accept e.g. Base where Derived is required)
fn signature_types_assignable(source : Type, target : Type) -> Bool {
  match (source, target) {
    (TypeReference(s_ref), TypeReference(t_ref)) if s_ref.type_arguments.is_empty() &&
      t_ref.type_arguments.is_empty() &&
      s_ref.name != t_ref.name &&
      class_parent_registry.contains(s_ref.name) &&
      class_parent_registry.contains(t_ref.name) =>
      registered_subclass_of(s_ref.name, t_ref.name)
    (Type::Array(s_arr), Type::Array(t_arr)) =>
      signature_types_assignable(s_arr.element_type, t_arr.element_type)
    _ => is_assignable(source, target)
  }
}

///|
/// Does a candidate type satisfy a generic constraint?
fn signature_constraint_satisfied(candidate : Type, constraint : Type) -> Bool {
  signature_types_assignable(candidate, constraint)
}

///|
/// Maximum recursion depth before assuming assignability (coinductive
/// termination for self-referential signature types)
const SIGNATURE_RELATION_MAX_DEPTH : Int = 24

///|
/// Placeholder type info for types synthesized during signature relation
/// (ids are not used by the assignability relation)
fn signature_relation_type_info() -> TypeInfo {
  { id: -1, flags: TypeFlags::default() }
}

///|
/// View a plain function type as a (non-generic) signature
fn signature_of_function(f : CheckerFunctionType) -> CheckerSignature {
  { parameters: f.parameters, return_type: f.return_type, type_parameters: [] }
}

///|
/// Substitute type parameters in a type without threading the checker
/// (purely structural; reuses existing TypeInfo where types are rebuilt).
/// Signature-own type parameters shadow outer substitutions.
fn subst_signature_type(t : Type, map : Map[String, Type]) -> Type {
  if map.is_empty() {
    return t
  }
  match t {
    TypeReference(type_ref) =>
      match map.get(type_ref.name) {
        Some(replacement) if type_ref.type_arguments.is_empty() => replacement
        _ => {
          let new_args = type_ref.type_arguments.map(fn(arg) {
            subst_signature_type(arg, map)
          })
          TypeReference({
            name: type_ref.name,
            type_arguments: new_args,
            info: type_ref.info,
          })
        }
      }
    Type::Function(func) =>
      Type::Function({
        parameters: subst_signature_params(func.parameters, map),
        return_type: subst_signature_type(func.return_type, map),
        info: func.info,
      })
    Type::Array(arr) =>
      Type::Array({
        element_type: subst_signature_type(arr.element_type, map),
        info: arr.info,
      })
    Union(union) =>
      Union({
        types: union.types.map(fn(member) { subst_signature_type(member, map) }),
        info: union.info,
      })
    Intersection(intersection) =>
      Intersection({
        types: intersection.types.map(fn(member) {
          subst_signature_type(member, map)
        }),
        info: intersection.info,
      })
    Type::Tuple(tuple) =>
      Type::Tuple({
        element_types: tuple.element_types.map(fn(elem) {
          {
            element_type: subst_signature_type(elem.element_type, map),
            is_optional: elem.is_optional,
            is_rest: elem.is_rest,
            label: elem.label,
          }
        }),
        info: tuple.info,
      })
    Type::Object(obj) => {
      let new_props : Map[String, PropertySignature] = Map([])
      for entry in obj.properties {
        let (name, prop) = entry
        new_props.set(name, {
          name: prop.name,
          prop_type: subst_signature_type(prop.prop_type, map),
          is_optional: prop.is_optional,
          is_readonly: prop.is_readonly,
          is_method: prop.is_method,
        })
      }
      Type::Object({
        properties: new_props,
        call_signatures: obj.call_signatures.map(fn(sig) {
          subst_in_signature(sig, map)
        }),
        construct_signatures: obj.construct_signatures.map(fn(sig) {
          subst_in_signature(sig, map)
        }),
        index_signatures: obj.index_signatures.map(fn(idx) {
          {
            parameter_name: idx.parameter_name,
            parameter_type: subst_signature_type(idx.parameter_type, map),
            return_type: subst_signature_type(idx.return_type, map),
            is_readonly: idx.is_readonly,
          }
        }),
        info: obj.info,
        class_name: obj.class_name,
      })
    }
    _ => t
  }
}

///|
fn subst_signature_params(
  params : Array[CheckerParameter],
  map : Map[String, Type],
) -> Array[CheckerParameter] {
  params.map(fn(param) {
    {
      name: param.name,
      param_type: subst_signature_type(param.param_type, map),
      is_optional: param.is_optional,
      is_rest: param.is_rest,
    }
  })
}

///|
/// Substitute inside a nested signature; the signature's own type
/// parameters shadow the outer substitution
fn subst_in_signature(
  sig : CheckerSignature,
  map : Map[String, Type],
) -> CheckerSignature {
  let mut effective = map
  for tp in sig.type_parameters {
    if map.contains(tp.name) {
      // Shadowed: rebuild the map without the shadowed names
      let filtered : Map[String, Type] = Map([])
      for entry in map {
        let (name, value) = entry
        let mut shadowed = false
        for own_tp in sig.type_parameters {
          if own_tp.name == name {
            shadowed = true
            break
          }
        }
        if !shadowed {
          filtered.set(name, value)
        }
      }
      effective = filtered
      break
    }
  }
  {
    parameters: subst_signature_params(sig.parameters, effective),
    return_type: subst_signature_type(sig.return_type, effective),
    type_parameters: sig.type_parameters,
  }
}

///|
/// Erase a signature's type parameters to `any` (tsc getErasedSignature)
fn erase_signature(sig : CheckerSignature) -> CheckerSignature {
  if sig.type_parameters.is_empty() {
    return sig
  }
  let map : Map[String, Type] = Map([])
  for tp in sig.type_parameters {
    map.set(tp.name, Any(signature_relation_type_info()))
  }
  {
    parameters: subst_signature_params(sig.parameters, map),
    return_type: subst_signature_type(sig.return_type, map),
    type_parameters: [],
  }
}

///|
/// Effective parameter type at argument position `i`, unwrapping a rest
/// parameter's array type to its element type. None when the parameter
/// list cannot receive an argument at that position.
fn signature_param_type_at(
  params : Array[CheckerParameter],
  i : Int,
) -> Type? {
  let mut idx = 0
  for p in params {
    if p.is_rest {
      return match p.param_type {
        Type::Array(arr) => Some(arr.element_type)
        other => Some(other)
      }
    }
    if idx == i {
      return Some(p.param_type)
    }
    idx = idx + 1
  }
  None
}

///|
/// Count fixed (non-rest) parameters and whether a rest parameter exists
fn signature_param_counts(params : Array[CheckerParameter]) -> (Int, Bool) {
  let mut fixed = 0
  let mut has_rest = false
  for p in params {
    if p.is_rest {
      has_rest = true
    } else {
      fixed = fixed + 1
    }
  }
  (fixed, has_rest)
}

///|
/// Structural comparison of two signatures whose type parameters have
/// already been instantiated/erased: contravariant parameters (with the
/// global wrapper-object bivariance exception), covariant return types,
/// tsc arity rules (a source may not require more arguments than the
/// target can supply)
fn compare_signature_shapes(
  source : CheckerSignature,
  target : CheckerSignature,
) -> Bool {
  let sp = expand_function_parameters(source.parameters)
  let tp = expand_function_parameters(target.parameters)
  let mut source_required = 0
  for p in sp {
    if !p.is_rest && !p.is_optional {
      source_required = source_required + 1
    }
  }
  let (target_fixed, target_has_rest) = signature_param_counts(tp)
  if !target_has_rest && source_required > target_fixed {
    return false
  }
  let (source_fixed, source_has_rest) = signature_param_counts(sp)
  let mut positions = if source_fixed > target_fixed {
    source_fixed
  } else {
    target_fixed
  }
  if source_has_rest && target_has_rest {
    positions = positions + 1
  }
  for i = 0; i < positions; i = i + 1 {
    match (signature_param_type_at(sp, i), signature_param_type_at(tp, i)) {
      (Some(source_param), Some(target_param)) =>
        // Contravariant: target param must be assignable to source param
        if !signature_types_assignable(target_param, source_param) {
          // Global wrapper object params compare bivariantly (see
          // is_function_assignable)
          let wrapper_involved = is_wrapper_type_reference(target_param) ||
            is_wrapper_type_reference(source_param)
          if !(wrapper_involved &&
            signature_types_assignable(source_param, target_param)) {
            return false
          }
        }
      _ => ()
    }
  }
  // Return types are covariant; a void/any-returning target accepts any
  // source return type
  match target.return_type {
    Void(_) | Any(_) => true
    _ => signature_types_assignable(source.return_type, target.return_type)
  }
}

///|
/// Structural inference: walk source/target types in parallel and record
/// the first target type found for each source type parameter name
fn unify_types_for_inference(
  source_t : Type,
  target_t : Type,
  tp_names : Map[String, Bool],
  candidates : Map[String, Type],
  depth : Int,
) -> Unit {
  if depth > 12 {
    return
  }
  match (source_t, target_t) {
    (TypeReference(source_ref), _) if tp_names.contains(source_ref.name) &&
      source_ref.type_arguments.is_empty() =>
      if !candidates.contains(source_ref.name) {
        candidates.set(source_ref.name, target_t)
      }
    (Type::Array(source_arr), Type::Array(target_arr)) =>
      unify_types_for_inference(
        source_arr.element_type,
        target_arr.element_type,
        tp_names,
        candidates,
        depth + 1,
      )
    (Type::Array(source_arr), TypeReference(target_ref)) if target_ref.name ==
      "Array" &&
      target_ref.type_arguments.length() == 1 =>
      unify_types_for_inference(
        source_arr.element_type,
        target_ref.type_arguments[0],
        tp_names,
        candidates,
        depth + 1,
      )
    (TypeReference(source_ref), Type::Array(target_arr)) if source_ref.name ==
      "Array" &&
      source_ref.type_arguments.length() == 1 =>
      unify_types_for_inference(
        source_ref.type_arguments[0],
        target_arr.element_type,
        tp_names,
        candidates,
        depth + 1,
      )
    (TypeReference(source_ref), TypeReference(target_ref)) if source_ref.name ==
      target_ref.name &&
      source_ref.type_arguments.length() == target_ref.type_arguments.length() =>
      for i = 0; i < source_ref.type_arguments.length(); i = i + 1 {
        unify_types_for_inference(
          source_ref.type_arguments[i],
          target_ref.type_arguments[i],
          tp_names,
          candidates,
          depth + 1,
        )
      }
    (Type::Function(source_fn), Type::Function(target_fn)) => {
      unify_signature_params_for_inference(
        source_fn.parameters,
        target_fn.parameters,
        tp_names,
        candidates,
        depth + 1,
      )
      unify_types_for_inference(
        source_fn.return_type,
        target_fn.return_type,
        tp_names,
        candidates,
        depth + 1,
      )
    }
    (Type::Tuple(source_tuple), Type::Tuple(target_tuple)) => {
      let n = if source_tuple.element_types.length() <
        target_tuple.element_types.length() {
        source_tuple.element_types.length()
      } else {
        target_tuple.element_types.length()
      }
      for i = 0; i < n; i = i + 1 {
        unify_types_for_inference(
          source_tuple.element_types[i].element_type,
          target_tuple.element_types[i].element_type,
          tp_names,
          candidates,
          depth + 1,
        )
      }
    }
    (Type::Object(source_obj), Type::Object(target_obj)) => {
      for entry in source_obj.properties {
        let (name, source_prop) = entry
        match target_obj.properties.get(name) {
          Some(target_prop) =>
            unify_types_for_inference(
              source_prop.prop_type,
              target_prop.prop_type,
              tp_names,
              candidates,
              depth + 1,
            )
          None => ()
        }
      }
      unify_signature_lists_for_inference(
        source_obj.call_signatures,
        target_obj.call_signatures,
        tp_names,
        candidates,
        depth + 1,
      )
      unify_signature_lists_for_inference(
        source_obj.construct_signatures,
        target_obj.construct_signatures,
        tp_names,
        candidates,
        depth + 1,
      )
    }
    _ => ()
  }
}

///|
fn unify_signature_params_for_inference(
  source_params : Array[CheckerParameter],
  target_params : Array[CheckerParameter],
  tp_names : Map[String, Bool],
  candidates : Map[String, Type],
  depth : Int,
) -> Unit {
  let sp = expand_function_parameters(source_params)
  let tp = expand_function_parameters(target_params)
  let (source_fixed, source_has_rest) = signature_param_counts(sp)
  let (target_fixed, target_has_rest) = signature_param_counts(tp)
  let mut positions = if source_fixed > target_fixed {
    source_fixed
  } else {
    target_fixed
  }
  if source_has_rest && target_has_rest {
    positions = positions + 1
  }
  for i = 0; i < positions; i = i + 1 {
    match (signature_param_type_at(sp, i), signature_param_type_at(tp, i)) {
      (Some(source_param), Some(target_param)) =>
        unify_types_for_inference(
          source_param,
          target_param,
          tp_names,
          candidates,
          depth,
        )
      _ => ()
    }
  }
}

///|
fn unify_signature_lists_for_inference(
  source_sigs : Array[CheckerSignature],
  target_sigs : Array[CheckerSignature],
  tp_names : Map[String, Bool],
  candidates : Map[String, Type],
  depth : Int,
) -> Unit {
  let n = if source_sigs.length() < target_sigs.length() {
    source_sigs.length()
  } else {
    target_sigs.length()
  }
  for i = 0; i < n; i = i + 1 {
    unify_signature_params_for_inference(
      source_sigs[i].parameters,
      target_sigs[i].parameters,
      tp_names,
      candidates,
      depth,
    )
    unify_types_for_inference(
      source_sigs[i].return_type,
      target_sigs[i].return_type,
      tp_names,
      candidates,
      depth,
    )
  }
}

///|
/// Relate a single source signature to a single target signature.
/// erase=true replaces both sides' type parameters with `any` (used for
/// overloaded signature lists, mirroring tsc)
fn is_signature_assignable(
  source : CheckerSignature,
  target : CheckerSignature,
  erase~ : Bool = false,
) -> Bool {
  if signature_relation_depth[0] > SIGNATURE_RELATION_MAX_DEPTH {
    return true
  }
  signature_relation_depth[0] = signature_relation_depth[0] + 1
  let result = if erase {
    compare_signature_shapes(erase_signature(source), erase_signature(target))
  } else {
    is_signature_assignable_strict(source, target)
  }
  signature_relation_depth[0] = signature_relation_depth[0] - 1
  result
}

///|
fn is_signature_assignable_strict(
  source : CheckerSignature,
  target : CheckerSignature,
) -> Bool {
  // Step 1: alpha-rename the target's type parameters to unique opaque
  // markers and register them (with their constraints) so is_assignable
  // treats them like tsc type parameters
  let marker_names : Array[String] = []
  let effective_target = if target.type_parameters.is_empty() {
    target
  } else {
    let rename : Map[String, Type] = Map([])
    for tp in target.type_parameters {
      let marker = "#sig_tp_\{signature_marker_counter[0]}#\{tp.name}"
      signature_marker_counter[0] = signature_marker_counter[0] + 1
      marker_names.push(marker)
      rename.set(
        tp.name,
        TypeReference({
          name: marker,
          type_arguments: [],
          info: signature_relation_type_info(),
        }),
      )
    }
    // Register markers; constraints may reference sibling type parameters,
    // so rename inside constraints too
    for i = 0; i < target.type_parameters.length(); i = i + 1 {
      let tp = target.type_parameters[i]
      let constraint = match tp.constraint {
        Some(c) => Some(subst_signature_type(c, rename))
        None => None
      }
      signature_relation_markers.set(marker_names[i], constraint)
    }
    {
      parameters: subst_signature_params(target.parameters, rename),
      return_type: subst_signature_type(target.return_type, rename),
      type_parameters: [],
    }
  }

  // Step 2: instantiate the source's type parameters by inference from the
  // target's parameter types (tsc instantiateSignatureInContextOf); an
  // inferred type that fails its constraint falls back to the constraint
  let effective_source = if source.type_parameters.is_empty() {
    source
  } else {
    let tp_names : Map[String, Bool] = Map([])
    for tp in source.type_parameters {
      tp_names.set(tp.name, true)
    }
    let candidates : Map[String, Type] = Map([])
    unify_signature_params_for_inference(
      source.parameters,
      effective_target.parameters,
      tp_names,
      candidates,
      0,
    )
    let subst : Map[String, Type] = Map([])
    for tp in source.type_parameters {
      let chosen = match candidates.get(tp.name) {
        Some(candidate) =>
          match tp.constraint {
            Some(constraint) =>
              if signature_constraint_satisfied(candidate, constraint) {
                candidate
              } else {
                constraint
              }
            None => candidate
          }
        None =>
          match tp.constraint {
            Some(constraint) => constraint
            None => Any(signature_relation_type_info())
          }
      }
      subst.set(tp.name, chosen)
    }
    {
      parameters: subst_signature_params(source.parameters, subst),
      return_type: subst_signature_type(source.return_type, subst),
      type_parameters: [],
    }
  }
  let result = compare_signature_shapes(effective_source, effective_target)

  // Unregister markers
  for marker in marker_names {
    signature_relation_markers.remove(marker)
  }
  result
}

///|
/// Relate two signature lists (tsc signaturesRelatedTo): every target
/// signature must be matched. A 1-to-1 comparison is strict (full generic
/// checking); overloaded lists compare with erased type parameters.
/// An empty target list is trivially satisfied; a non-empty target list
/// can never be satisfied by an empty source list.
fn are_signature_lists_assignable(
  source_sigs : Array[CheckerSignature],
  target_sigs : Array[CheckerSignature],
) -> Bool {
  if target_sigs.is_empty() {
    return true
  }
  if source_sigs.is_empty() {
    return false
  }
  if source_sigs.length() == 1 && target_sigs.length() == 1 {
    return is_signature_assignable(source_sigs[0], target_sigs[0])
  }
  for target_sig in target_sigs {
    let mut matched = false
    for source_sig in source_sigs {
      if is_signature_assignable(source_sig, target_sig, erase=true) {
        matched = true
        break
      }
    }
    if !matched {
      return false
    }
  }
  true
}
