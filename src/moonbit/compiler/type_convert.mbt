// Type Conversion Layer - Converts between old Type and new TypeV2
// This layer allows gradual migration while maintaining API compatibility

///|
/// Convert from old Type to new TypeV2
pub fn type_to_v2(ty : Type) -> TypeV2 {
  match ty {
    // Primitives - strip TypeInfo wrapper
    Number(_) => TNumber
    String(_) => TString
    Boolean(_) => TBoolean
    Void(_) => TVoid
    Undefined(_) => TUndefined
    Null(_) => TNull
    Symbol(_) => TSymbol
    BigInt(_) => TBigInt
    Any(_) => TAny
    Unknown(_) => TUnknown
    Never(_) => TNever
    Error(_) => TError

    // Literals
    NumberLiteral(val, _) => TLiteralNumber(val)
    StringLiteral(val, _) => TLiteralString(val)
    BooleanLiteral(val, _) => TLiteralBool(val)

    // Object type
    Object(obj) => TObject(object_type_to_v2(obj))

    // Function type
    Function(func) => TFunction(function_type_to_v2(func))

    // Union type
    Union(union_ty) => {
      let v2_types = union_ty.types.map(type_to_v2)
      make_union(v2_types)
    }

    // Intersection type
    Intersection(inter) => {
      let v2_types = inter.types.map(type_to_v2)
      make_intersection(v2_types)
    }

    // Array type
    Array(arr) => TArray(type_to_v2(arr.element_type))

    // Tuple type
    Tuple(tup) => {
      let elems = tup.element_types.map(fn(e) {
        TupleElementV2::{
          ty: type_to_v2(e.element_type),
          optional: e.is_optional,
          is_rest: e.is_rest,
          label: e.label,
        }
      })
      TTuple(elems)
    }

    // Type reference -> Generic instance
    TypeReference(ref_ty) => {
      let args = ref_ty.type_arguments.map(type_to_v2)
      TGenericInstance(ref_ty.name, args)
    }

    // Conditional type
    Conditional(cond) =>
      TConditional(ConditionalTypeV2::{
        check_type: type_to_v2(cond.check_type),
        extends_type: type_to_v2(cond.extends_type),
        true_type: type_to_v2(cond.true_type),
        false_type: type_to_v2(cond.false_type),
      })

    // Mapped type
    Mapped(mapped) =>
      TMapped(MappedTypeV2::{
        type_param: type_param_to_v2(mapped.type_parameter),
        constraint: TAny, // Constraint is usually in the type parameter
        name_type: match mapped.name_type {
          Some(t) => Some(type_to_v2(t))
          None => None
        },
        template_type: type_to_v2(mapped.template_type),
        readonly_modifier: mapped_modifier_to_v2(mapped.readonly_modifier),
        optional_modifier: mapped_modifier_to_v2(mapped.optional_modifier),
        source_type: None, // Not available from old Type system
      })

    // Template literal type
    TemplateLiteral(tl) =>
      TTemplateLiteral(TemplateLiteralTypeV2::{
        texts: tl.texts,
        types: tl.types.map(type_to_v2),
      })

    // Index access type
    IndexAccess(ia) =>
      TIndexAccess(IndexAccessTypeV2::{
        object_type: type_to_v2(ia.object_type),
        index_type: type_to_v2(ia.index_type),
      })

    // Infer type
    Infer(inf) => TInfer(inf.type_parameter_name)
  }
}

///|
/// Convert ObjectType to ObjectTypeV2
fn object_type_to_v2(obj : ObjectType) -> ObjectTypeV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  for kv in obj.properties {
    let name = kv.0
    let prop = kv.1
    fields.set(name, FieldInfoV2::{
      ty: type_to_v2(prop.prop_type),
      optional: prop.is_optional,
      is_readonly: prop.is_readonly,
    })
  }
  let call_sigs = obj.call_signatures.map(signature_to_function_v2)
  let construct_sigs = obj.construct_signatures.map(signature_to_function_v2)
  let index_sig : IndexSignatureV2? = if obj.index_signatures.is_empty() {
    None
  } else {
    let first_sig = obj.index_signatures[0]
    Some(IndexSignatureV2::{
      key_type: type_to_v2(first_sig.parameter_type),
      value_type: type_to_v2(first_sig.return_type),
      is_readonly: first_sig.is_readonly,
    })
  }
  ObjectTypeV2::{
    fields,
    symbol_fields: [],
    call_signatures: call_sigs,
    construct_signatures: construct_sigs,
    index_signature: index_sig,
    is_class: false,
    class_name: None,
  }
}

///|
/// Convert CheckerFunctionType to FunctionTypeV2
fn function_type_to_v2(func : CheckerFunctionType) -> FunctionTypeV2 {
  let params : Array[ParamInfoV2] = []
  let mut rest_param : ParamInfoV2? = None
  for p in func.parameters {
    if p.is_rest {
      rest_param = Some(ParamInfoV2::{
        name: p.name,
        ty: type_to_v2(p.param_type),
        optional: p.is_optional,
        is_rest: true,
      })
    } else {
      params.push(ParamInfoV2::{
        name: p.name,
        ty: type_to_v2(p.param_type),
        optional: p.is_optional,
        is_rest: false,
      })
    }
  }
  FunctionTypeV2::{
    type_params: [],
    params,
    rest_param,
    return_type: type_to_v2(func.return_type),
    type_predicate: None,
    this_type: None,
  }
}

///|
/// Convert CheckerSignature to FunctionTypeV2
fn signature_to_function_v2(sig : CheckerSignature) -> FunctionTypeV2 {
  let params : Array[ParamInfoV2] = []
  let mut rest_param : ParamInfoV2? = None
  for p in sig.parameters {
    if p.is_rest {
      rest_param = Some(ParamInfoV2::{
        name: p.name,
        ty: type_to_v2(p.param_type),
        optional: p.is_optional,
        is_rest: true,
      })
    } else {
      params.push(ParamInfoV2::{
        name: p.name,
        ty: type_to_v2(p.param_type),
        optional: p.is_optional,
        is_rest: false,
      })
    }
  }
  FunctionTypeV2::{
    type_params: sig.type_parameters.map(type_param_to_v2),
    params,
    rest_param,
    return_type: type_to_v2(sig.return_type),
    type_predicate: None,
    this_type: None,
  }
}

///|
/// Convert CheckerTypeParameter to TypeParamV2
fn type_param_to_v2(tp : CheckerTypeParameter) -> TypeParamV2 {
  TypeParamV2::{
    name: tp.name,
    constraint: match tp.constraint {
      Some(c) => Some(type_to_v2(c))
      None => None
    },
    default_type: match tp.default_type {
      Some(d) => Some(type_to_v2(d))
      None => None
    },
    is_const: false, // CheckerTypeParameter doesn't track this yet
    variance: None,
  }
}

///|
/// Convert MappedModifier to MappedModifierV2
fn mapped_modifier_to_v2(m : MappedModifier) -> MappedModifierV2 {
  match m {
    Unchanged => MappedModifierV2::Unchanged
    Add => MappedModifierV2::Add
    Remove => MappedModifierV2::Remove
  }
}

// ============================================================================
// Convert from TypeV2 back to Type (for API compatibility)
// ============================================================================

///|
/// Convert from new TypeV2 to old Type
/// Used at API boundaries to maintain compatibility
pub fn v2_to_type(checker : TypeChecker, ty : TypeV2) -> (Type, TypeChecker) {
  let (info, checker) = checker.create_type_info()
  match ty {
    // Primitives
    TNumber => (Number(info), checker)
    TString => (String(info), checker)
    TBoolean => (Boolean(info), checker)
    TVoid => (Void(info), checker)
    TUndefined => (Undefined(info), checker)
    TNull => (Null(info), checker)
    TSymbol => (Symbol(info), checker)
    TUniqueSymbol(_) => (Symbol(info), checker) // Unique symbol maps to symbol in old type system
    TAny => (Any(info), checker)
    TUnknown => (Unknown(info), checker)
    TNever => (Never(info), checker)
    TError => (Error(info), checker)

    // Literals
    TLiteralNumber(val) => (NumberLiteral(val, info), checker)
    TLiteralString(val) => (StringLiteral(val, info), checker)
    TLiteralBool(val) => (BooleanLiteral(val, info), checker)
    TLiteralBigInt(_) =>
      // BigInt literals get converted to number 0 for now (simplification)
      (NumberLiteral(0.0, info), checker)
    TBigInt => (Number(info), checker) // BigInt maps to number for now

    // Object type
    TObject(obj) => {
      let (obj_ty, checker) = object_v2_to_type(checker, obj)
      (Object(obj_ty), checker)
    }

    // Function type
    TFunction(func) => {
      let (func_ty, checker) = function_v2_to_type(checker, func)
      (Function(func_ty), checker)
    }

    // Union type
    TUnion(types) => {
      let (converted, checker) = convert_types_array(checker, types)
      (Union(CheckerUnionType::{ types: converted, info }), checker)
    }

    // Intersection type
    TIntersection(types) => {
      let (converted, checker) = convert_types_array(checker, types)
      (
        Intersection(CheckerIntersectionType::{ types: converted, info }),
        checker,
      )
    }

    // Array type
    TArray(elem) => {
      let (elem_ty, checker) = v2_to_type(checker, elem)
      (Array(CheckerArrayType::{ element_type: elem_ty, info }), checker)
    }

    // Tuple type
    TTuple(elems) => {
      let (elements, checker) = convert_tuple_elements(checker, elems)
      (Tuple(CheckerTupleType::{ element_types: elements, info }), checker)
    }

    // Type parameter -> Type reference with no args
    TTypeParam(name, _) =>
      (
        TypeReference(TypeReferenceType::{ name, type_arguments: [], info }),
        checker,
      )

    // Generic instance -> Type reference
    TGenericInstance(name, args) => {
      let (converted_args, checker) = convert_types_array(checker, args)
      (
        TypeReference(TypeReferenceType::{
          name,
          type_arguments: converted_args,
          info,
        }),
        checker,
      )
    }

    // Conditional type
    TConditional(cond) => {
      let (check_ty, checker) = v2_to_type(checker, cond.check_type)
      let (extends_ty, checker) = v2_to_type(checker, cond.extends_type)
      let (true_ty, checker) = v2_to_type(checker, cond.true_type)
      let (false_ty, checker) = v2_to_type(checker, cond.false_type)
      (
        Conditional(CheckerConditionalType::{
          check_type: check_ty,
          extends_type: extends_ty,
          true_type: true_ty,
          false_type: false_ty,
          info,
        }),
        checker,
      )
    }

    // Mapped type
    TMapped(mapped) => {
      let (template_ty, checker) = v2_to_type(checker, mapped.template_type)
      let (name_ty, checker) = match mapped.name_type {
        Some(t) => {
          let (converted, c) = v2_to_type(checker, t)
          (Some(converted), c)
        }
        None => (None, checker)
      }
      (
        Mapped(CheckerMappedType::{
          type_parameter: type_param_v2_to_checker(mapped.type_param),
          name_type: name_ty,
          template_type: template_ty,
          readonly_modifier: mapped_modifier_v2_to_old(mapped.readonly_modifier),
          optional_modifier: mapped_modifier_v2_to_old(mapped.optional_modifier),
          info,
        }),
        checker,
      )
    }

    // Template literal type
    TTemplateLiteral(tl) => {
      let (converted_types, checker) = convert_types_array(checker, tl.types)
      (
        TemplateLiteral(CheckerTemplateLiteralType::{
          texts: tl.texts,
          types: converted_types,
          info,
        }),
        checker,
      )
    }

    // Index access type
    TIndexAccess(ia) => {
      let (obj_ty, checker) = v2_to_type(checker, ia.object_type)
      let (idx_ty, checker) = v2_to_type(checker, ia.index_type)
      (
        IndexAccess(CheckerIndexAccessType::{
          object_type: obj_ty,
          index_type: idx_ty,
          info,
          is_keyof: false,
        }),
        checker,
      )
    }

    // Infer type
    TInfer(name) =>
      (Infer(CheckerInferType::{ type_parameter_name: name, info }), checker)
  }
}

///|
/// Convert ObjectTypeV2 to ObjectType
fn object_v2_to_type(
  checker : TypeChecker,
  obj : ObjectTypeV2,
) -> (ObjectType, TypeChecker) {
  let info_result = checker.create_type_info()
  let info = info_result.0
  let mut current_checker = info_result.1
  let properties : Map[String, PropertySignature] = Map::new()
  for kv in obj.fields {
    let name = kv.0
    let field = kv.1
    let field_result = v2_to_type(current_checker, field.ty)
    let field_ty = field_result.0
    current_checker = field_result.1
    properties.set(name, PropertySignature::{
      name,
      prop_type: field_ty,
      is_optional: field.optional,
      is_readonly: field.is_readonly,
    })
  }
  let call_result = convert_function_sigs(current_checker, obj.call_signatures)
  let call_sigs = call_result.0
  current_checker = call_result.1
  let construct_result = convert_function_sigs(
    current_checker,
    obj.construct_signatures,
  )
  let construct_sigs = construct_result.0
  current_checker = construct_result.1
  let index_result : (Array[IndexSignature], TypeChecker) = match
    obj.index_signature {
    None => ([], current_checker)
    Some(sig) => {
      let key_result = v2_to_type(current_checker, sig.key_type)
      let key_ty = key_result.0
      let c1 = key_result.1
      let val_result = v2_to_type(c1, sig.value_type)
      let val_ty = val_result.0
      let c2 = val_result.1
      (
        [
          IndexSignature::{
            parameter_name: "key",
            parameter_type: key_ty,
            return_type: val_ty,
            is_readonly: sig.is_readonly,
          },
        ],
        c2,
      )
    }
  }
  let index_sigs = index_result.0
  let final_checker = index_result.1
  (
    ObjectType::{
      properties,
      call_signatures: call_sigs,
      construct_signatures: construct_sigs,
      index_signatures: index_sigs,
      info,
      class_name: None,
    },
    final_checker,
  )
}

///|
/// Convert FunctionTypeV2 to CheckerFunctionType
fn function_v2_to_type(
  checker : TypeChecker,
  func : FunctionTypeV2,
) -> (CheckerFunctionType, TypeChecker) {
  let info_result = checker.create_type_info()
  let info = info_result.0
  let mut current_checker = info_result.1
  let params : Array[CheckerParameter] = []
  for p in func.params {
    let param_result = v2_to_type(current_checker, p.ty)
    let param_ty = param_result.0
    current_checker = param_result.1
    params.push(CheckerParameter::{
      name: p.name,
      param_type: param_ty,
      is_optional: p.optional,
      is_rest: p.is_rest,
    })
  }

  // Add rest param if present
  match func.rest_param {
    Some(r) => {
      let rest_result = v2_to_type(current_checker, r.ty)
      let rest_ty = rest_result.0
      current_checker = rest_result.1
      params.push(CheckerParameter::{
        name: r.name,
        param_type: rest_ty,
        is_optional: r.optional,
        is_rest: true,
      })
    }
    None => ()
  }
  let ret_result = v2_to_type(current_checker, func.return_type)
  let ret_ty = ret_result.0
  let final_checker = ret_result.1
  (
    CheckerFunctionType::{ parameters: params, return_type: ret_ty, info },
    final_checker,
  )
}

///|
/// Convert array of TypeV2 to array of Type
fn convert_types_array(
  checker : TypeChecker,
  types : Array[TypeV2],
) -> (Array[Type], TypeChecker) {
  let result : Array[Type] = []
  let mut c = checker
  for t in types {
    let (converted, new_c) = v2_to_type(c, t)
    c = new_c
    result.push(converted)
  }
  (result, c)
}

///|
/// Convert array of TupleElementV2 to array of TupleElement
fn convert_tuple_elements(
  checker : TypeChecker,
  elems : Array[TupleElementV2],
) -> (Array[TupleElement], TypeChecker) {
  let result : Array[TupleElement] = []
  let mut c = checker
  for e in elems {
    let (elem_ty, new_c) = v2_to_type(c, e.ty)
    c = new_c
    result.push(TupleElement::{
      element_type: elem_ty,
      is_optional: e.optional,
      is_rest: e.is_rest,
      label: e.label,
    })
  }
  (result, c)
}

///|
/// Convert array of FunctionTypeV2 to array of CheckerSignature
fn convert_function_sigs(
  checker : TypeChecker,
  funcs : Array[FunctionTypeV2],
) -> (Array[CheckerSignature], TypeChecker) {
  let result : Array[CheckerSignature] = []
  let mut c = checker
  for f in funcs {
    let params : Array[CheckerParameter] = []
    for p in f.params {
      let (param_ty, new_c) = v2_to_type(c, p.ty)
      c = new_c
      params.push(CheckerParameter::{
        name: p.name,
        param_type: param_ty,
        is_optional: p.optional,
        is_rest: p.is_rest,
      })
    }

    // Add rest param if present
    match f.rest_param {
      Some(r) => {
        let (rest_ty, new_c) = v2_to_type(c, r.ty)
        c = new_c
        params.push(CheckerParameter::{
          name: r.name,
          param_type: rest_ty,
          is_optional: r.optional,
          is_rest: true,
        })
      }
      None => ()
    }
    let (ret_ty, new_c) = v2_to_type(c, f.return_type)
    c = new_c
    result.push(CheckerSignature::{
      parameters: params,
      return_type: ret_ty,
      type_parameters: f.type_params.map(type_param_v2_to_checker),
    })
  }
  (result, c)
}

///|
/// Convert TypeParamV2 to CheckerTypeParameter
fn type_param_v2_to_checker(tp : TypeParamV2) -> CheckerTypeParameter {
  // Note: We can't properly convert constraints here without a checker
  // So we return None for constraints
  CheckerTypeParameter::{ name: tp.name, constraint: None, default_type: None }
}

///|
/// Convert MappedModifierV2 to MappedModifier
fn mapped_modifier_v2_to_old(m : MappedModifierV2) -> MappedModifier {
  match m {
    MappedModifierV2::Unchanged => MappedModifier::Unchanged
    MappedModifierV2::Add => MappedModifier::Add
    MappedModifierV2::Remove => MappedModifier::Remove
  }
}

// ============================================================================
// Helper to create TypeInfo
// ============================================================================

///|
/// Create a new TypeInfo and update the checker's type ID counter
fn TypeChecker::create_type_info(self : TypeChecker) -> (TypeInfo, TypeChecker) {
  let info = TypeInfo::{ id: self.next_type_id, flags: TypeFlags::default() }
  let new_checker = TypeChecker::{
    next_type_id: self.next_type_id + 1,
    type_cache: self.type_cache,
    symbol_types: self.symbol_types,
    node_types: self.node_types,
    narrowed_types: self.narrowed_types,
    diagnostics: self.diagnostics,
    file_path: self.file_path,
    global_scope: self.global_scope,
    local_scopes: self.local_scopes,
    current_this_type: self.current_this_type,
    no_unchecked_indexed_access: self.no_unchecked_indexed_access,
    target: self.target,
    resolving_symbols: self.resolving_symbols,
    arrow_function_depth: self.arrow_function_depth,
    async_function_depth: self.async_function_depth,
    generator_function_depth: self.generator_function_depth,
    regular_function_depth: self.regular_function_depth,
    innermost_function_is_arrow: self.innermost_function_is_arrow,
    generator_has_return_type: self.generator_has_return_type,
    block_scoped_decls: self.block_scoped_decls,
    uninitialized_vars: self.uninitialized_vars,
    in_static_context: self.in_static_context,
    in_constructor: self.in_constructor,
    in_class_body: self.in_class_body,
    in_derived_class: self.in_derived_class,
    in_extends_null_class: self.in_extends_null_class,
    super_called: self.super_called,
    current_location: self.current_location,
    external_registry: self.external_registry,
    import_map: self.import_map,
    namespace_symbols: self.namespace_symbols,
    in_destructuring_pattern: self.in_destructuring_pattern,
  }
  (info, new_checker)
}
