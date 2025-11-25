// Type Checker for TypeScript
// Performs type inference and type checking on bound AST

///|
/// Type represents a TypeScript type
pub enum Type {
  // Primitive types
  Number(TypeInfo)
  String(TypeInfo)
  Boolean(TypeInfo)
  Void(TypeInfo)
  Undefined(TypeInfo)
  Null(TypeInfo)
  Symbol(TypeInfo)
  Any(TypeInfo)
  Unknown(TypeInfo)
  Never(TypeInfo)

  // Object types
  Object(ObjectType)

  // Function types
  Function(CheckerFunctionType)

  // Union types
  Union(CheckerUnionType)

  // Array types
  Array(CheckerArrayType)

  // Literal types
  NumberLiteral(Double, TypeInfo)
  StringLiteral(String, TypeInfo)
  BooleanLiteral(Bool, TypeInfo)

  // Type references
  TypeReference(TypeReferenceType)

  // Intersection types (A & B)
  Intersection(CheckerIntersectionType)

  // Tuple types ([T1, T2, T3])
  Tuple(CheckerTupleType)

  // Conditional types (T extends U ? X : Y)
  Conditional(CheckerConditionalType)

  // Mapped types ({ [K in keyof T]: T[K] })
  Mapped(CheckerMappedType)

  // Template literal types (`${string}-${number}`)
  TemplateLiteral(CheckerTemplateLiteralType)

  // Index access types (T[K])
  IndexAccess(CheckerIndexAccessType)

  // Infer types (infer R)
  Infer(CheckerInferType)

  // Error type (for type errors)
  Error(TypeInfo)
} derive(Show)

///|
/// Type information (common to all types)
pub struct TypeInfo {
  id : Int
  flags : TypeFlags
} derive(Show)

///|
/// Type flags
pub struct TypeFlags {
  is_readonly : Bool
  is_optional : Bool
} derive(Show)

///|
/// Create default type flags
pub fn TypeFlags::default() -> TypeFlags {
  { is_readonly: false, is_optional: false }
}

///|
/// Object type (interfaces, classes, object literals)
pub struct ObjectType {
  properties : Map[String, PropertySignature]
  call_signatures : Array[CheckerSignature]
  construct_signatures : Array[CheckerSignature]
  index_signatures : Array[IndexSignature]
  info : TypeInfo
} derive(Show)

///|
/// Property signature
pub struct PropertySignature {
  name : String
  prop_type : Type
  is_optional : Bool
  is_readonly : Bool
} derive(Show)

///|
/// Function type (for type checking)
pub struct CheckerFunctionType {
  parameters : Array[CheckerParameter]
  return_type : Type
  info : TypeInfo
} derive(Show)

///|
/// Function parameter (for type checking)
pub struct CheckerParameter {
  name : String
  param_type : Type
  is_optional : Bool
  is_rest : Bool
} derive(Show)

///|
/// Signature (for call/construct signatures)
pub struct CheckerSignature {
  parameters : Array[CheckerParameter]
  return_type : Type
  type_parameters : Array[CheckerTypeParameter]
} derive(Show)

///|
/// Index signature
pub struct IndexSignature {
  parameter_name : String
  parameter_type : Type
  return_type : Type
  is_readonly : Bool
} derive(Show)

///|
/// Type parameter (generic) - for type checking
pub struct CheckerTypeParameter {
  name : String
  constraint : Type?
  default_type : Type?
} derive(Show)

///|
/// Union type info
pub struct CheckerUnionType {
  types : Array[Type]
  info : TypeInfo
} derive(Show)

///|
/// Array type info
pub struct CheckerArrayType {
  element_type : Type
  info : TypeInfo
} derive(Show)

///|
/// Type reference (references to named types)
pub struct TypeReferenceType {
  name : String
  type_arguments : Array[Type]
  info : TypeInfo
} derive(Show)

///|
/// Intersection type info (A & B)
pub struct CheckerIntersectionType {
  types : Array[Type]
  info : TypeInfo
} derive(Show)

///|
/// Tuple type info ([T1, T2, T3])
pub struct CheckerTupleType {
  element_types : Array[TupleElement]
  info : TypeInfo
} derive(Show)

///|
/// Tuple element (can be optional or rest)
pub struct TupleElement {
  element_type : Type
  is_optional : Bool
  is_rest : Bool
  label : String? // Named tuple elements
} derive(Show)

///|
/// Conditional type info (T extends U ? X : Y)
pub struct CheckerConditionalType {
  check_type : Type
  extends_type : Type
  true_type : Type
  false_type : Type
  info : TypeInfo
} derive(Show)

///|
/// Mapped type info ({ [K in keyof T]: T[K] })
pub struct CheckerMappedType {
  type_parameter : CheckerTypeParameter
  name_type : Type? // For key remapping: as NewKey
  template_type : Type
  readonly_modifier : MappedModifier
  optional_modifier : MappedModifier
  info : TypeInfo
} derive(Show)

///|
/// Modifier for mapped types (+, -, or none)
pub enum MappedModifier {
  Unchanged // No modifier
  Add // +readonly, +?
  Remove // -readonly, -?
} derive(Show, Eq)

///|
/// Template literal type info (`${string}-${number}`)
pub struct CheckerTemplateLiteralType {
  texts : Array[String] // Static text parts
  types : Array[Type] // Interpolated types
  info : TypeInfo
} derive(Show)

///|
/// Index access type info (T[K])
pub struct CheckerIndexAccessType {
  object_type : Type
  index_type : Type
  info : TypeInfo
} derive(Show)

///|
/// Infer type placeholder (infer R)
pub struct CheckerInferType {
  type_parameter_name : String
  info : TypeInfo
} derive(Show)

///|
/// Type narrowing information for a variable
pub struct NarrowedType {
  original_type : Type
  narrowed_type : Type
} derive(Show)

///|
/// Type guard information
pub struct TypeGuardInfo {
  parameter_name : String
  type_when_true : Type?
  type_when_false : Type?
} derive(Show)

///|
/// Type checker state
pub struct TypeChecker {
  next_type_id : Int
  type_cache : Map[String, Type]
  symbol_types : Map[Int, Type] // Symbol ID -> Type
  node_types : Map[String, Type] // Node identifier -> Type
  narrowed_types : Map[String, NarrowedType] // Variable name -> NarrowedType (for control flow narrowing)
  diagnostics : Array[Diagnostic]
  file_path : String
  global_scope : Scope? // Global scope for symbol lookup
} derive(Show)

///|
/// Result of type checking
pub type CheckResult = Result[TypedFile, Array[Diagnostic]]

///|
/// Typed file (result of type checking)
pub struct TypedFile {
  file_path : String
  statements : Array[Node]
  types : Map[String, Type]
  diagnostics : Array[Diagnostic]
} derive(Show)

///|
/// Create a new type checker
pub fn TypeChecker::new(
  file_path : String,
  global_scope : Scope?,
) -> TypeChecker {
  {
    next_type_id: 0,
    type_cache: Map::new(),
    symbol_types: Map::new(),
    node_types: Map::new(),
    narrowed_types: Map::new(),
    diagnostics: [],
    file_path,
    global_scope,
  }
}

///|
/// Get next type ID
fn next_type_id(checker : TypeChecker) -> (Int, TypeChecker) {
  let id = checker.next_type_id
  (id, { ..checker, next_type_id: id + 1 })
}

///|
/// Create type info
fn create_type_info(checker : TypeChecker) -> (TypeInfo, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  ({ id, flags: TypeFlags::default() }, checker)
}

// ============================================================================
// Built-in Types
// ============================================================================

///|
/// Get the number type
pub fn number_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Number(info), checker)
}

///|
/// Get the string type
pub fn string_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (String(info), checker)
}

///|
/// Get the boolean type
pub fn boolean_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Boolean(info), checker)
}

///|
/// Get the void type
pub fn void_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Void(info), checker)
}

///|
/// Get the any type
pub fn any_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Any(info), checker)
}

///|
/// Get the undefined type
pub fn undefined_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Undefined(info), checker)
}

///|
/// Get the null type
pub fn null_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Null(info), checker)
}

///|
/// Get the never type
pub fn never_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Never(info), checker)
}

///|
/// Get the unknown type
pub fn unknown_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Unknown(info), checker)
}

///|
/// Get the symbol type
pub fn symbol_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Symbol(info), checker)
}

///|
/// Get the error type (used for type errors)
pub fn error_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Error(info), checker)
}

// ============================================================================
// Literal Types
// ============================================================================

///|
/// Create a number literal type
pub fn number_literal_type(
  checker : TypeChecker,
  value : Double,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (NumberLiteral(value, info), checker)
}

///|
/// Create a string literal type
pub fn string_literal_type(
  checker : TypeChecker,
  value : String,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (StringLiteral(value, info), checker)
}

///|
/// Create a boolean literal type
pub fn boolean_literal_type(
  checker : TypeChecker,
  value : Bool,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (BooleanLiteral(value, info), checker)
}

// ============================================================================
// Type Reference Resolution
// ============================================================================

///|
/// Create a type reference
pub fn type_reference_type(
  checker : TypeChecker,
  name : String,
  type_arguments : Array[Type],
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (TypeReference({ name, type_arguments, info }), checker)
}

///|
/// Resolve a type reference to its actual type
pub fn resolve_type_reference(
  checker : TypeChecker,
  type_ref : TypeReferenceType,
) -> (Type, TypeChecker) {
  // Look up the type name in the type cache or scope
  match checker.type_cache.get(type_ref.name) {
    Some(resolved) =>
      // If the type has type arguments, instantiate it
      if type_ref.type_arguments.length() > 0 {
        instantiate_generic_type(checker, resolved, type_ref.type_arguments)
      } else {
        (resolved, checker)
      }
    None =>
      // Look up in scope for interface/class/type alias
      match lookup_symbol(checker, type_ref.name) {
        Some(symbol) =>
          match symbol.kind {
            Interface => {
              let (resolved, checker) = resolve_interface_type(checker, symbol)
              match resolved {
                Some(t) => (t, checker)
                None =>
                  // Return the type reference as-is
                  (TypeReference(type_ref), checker)
              }
            }
            Class =>
              // Return type reference for class types
              (TypeReference(type_ref), checker)
            Type =>
              // Would need type alias resolution
              (TypeReference(type_ref), checker)
            _ =>
              // Return type reference as-is
              (TypeReference(type_ref), checker)
          }
        None =>
          // Unknown type reference
          (TypeReference(type_ref), checker)
      }
  }
}

///|
/// Instantiate a generic type with type arguments
fn instantiate_generic_type(
  checker : TypeChecker,
  generic_type : Type,
  _type_args : Array[Type],
) -> (Type, TypeChecker) {
  match generic_type {
    Type::Function(func_type) =>
      // Substitute type parameters in function type
      // TODO: Full implementation would substitute type params with type args
      (Type::Function(func_type), checker)
    Object(obj) =>
      // Substitute type parameters in object type properties
      // TODO: Full implementation would substitute type params with type args
      (Object(obj), checker)
    _ => (generic_type, checker)
  }
}

// ============================================================================
// Intersection Type Support
// ============================================================================

///|
/// Create an intersection type
pub fn intersection_type(
  checker : TypeChecker,
  types : Array[Type],
) -> (Type, TypeChecker) {
  // Flatten nested intersections
  let flattened : Array[Type] = []
  for i = 0; i < types.length(); i = i + 1 {
    match types[i] {
      Intersection(inner) =>
        for j = 0; j < inner.types.length(); j = j + 1 {
          flattened.push(inner.types[j])
        }
      other => flattened.push(other)
    }
  }
  // Single type doesn't need intersection
  if flattened.length() == 1 {
    return (flattened[0], checker)
  }
  let (info, checker) = create_type_info(checker)
  (Intersection({ types: flattened, info }), checker)
}

///|
/// Merge intersection types into a combined object type
pub fn merge_intersection(
  checker : TypeChecker,
  intersection : CheckerIntersectionType,
) -> (Type, TypeChecker) {
  let merged_props : Map[String, PropertySignature] = Map::new()
  let merged_call_sigs : Array[CheckerSignature] = []
  let merged_construct_sigs : Array[CheckerSignature] = []
  let merged_index_sigs : Array[IndexSignature] = []
  // Merge all object types in the intersection
  for i = 0; i < intersection.types.length(); i = i + 1 {
    match intersection.types[i] {
      Object(obj) => {
        // Merge properties
        let props_iter = obj.properties.iter()
        for entry in props_iter {
          let (name, prop) = entry
          merged_props.set(name, prop)
        }
        // Merge call signatures
        for j = 0; j < obj.call_signatures.length(); j = j + 1 {
          merged_call_sigs.push(obj.call_signatures[j])
        }
        // Merge construct signatures
        for j = 0; j < obj.construct_signatures.length(); j = j + 1 {
          merged_construct_sigs.push(obj.construct_signatures[j])
        }
        // Merge index signatures
        for j = 0; j < obj.index_signatures.length(); j = j + 1 {
          merged_index_sigs.push(obj.index_signatures[j])
        }
      }
      _ => () // Non-object types remain in the intersection
    }
  }
  let (info, checker) = create_type_info(checker)
  (
    Object({
      properties: merged_props,
      call_signatures: merged_call_sigs,
      construct_signatures: merged_construct_sigs,
      index_signatures: merged_index_sigs,
      info,
    }),
    checker,
  )
}

// ============================================================================
// Tuple Type Support
// ============================================================================

///|
/// Create a tuple type
pub fn tuple_type(
  checker : TypeChecker,
  elements : Array[TupleElement],
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Tuple({ element_types: elements, info }), checker)
}

///|
/// Create a tuple element
pub fn tuple_element(
  element_type : Type,
  is_optional : Bool,
  is_rest : Bool,
  label : String?,
) -> TupleElement {
  { element_type, is_optional, is_rest, label }
}

///|
/// Get the element type at a specific index in a tuple
pub fn get_tuple_element_type(tuple : CheckerTupleType, index : Int) -> Type? {
  if index >= 0 && index < tuple.element_types.length() {
    Some(tuple.element_types[index].element_type)
  } else {
    // Check for rest element
    for i = 0; i < tuple.element_types.length(); i = i + 1 {
      if tuple.element_types[i].is_rest {
        return Some(tuple.element_types[i].element_type)
      }
    }
    None
  }
}

// ============================================================================
// Conditional Type Support
// ============================================================================

///|
/// Create a conditional type
pub fn conditional_type(
  checker : TypeChecker,
  check_type : Type,
  extends_type : Type,
  true_type : Type,
  false_type : Type,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (
    Conditional({ check_type, extends_type, true_type, false_type, info }),
    checker,
  )
}

///|
/// Evaluate a conditional type
pub fn evaluate_conditional_type(
  checker : TypeChecker,
  cond : CheckerConditionalType,
) -> (Type, TypeChecker) {
  // Check if check_type extends extends_type
  if is_assignable(cond.check_type, cond.extends_type) {
    (cond.true_type, checker)
  } else {
    // Check for distributive conditional types over unions
    match cond.check_type {
      Union(union) => {
        // Distribute over union members
        let result_types : Array[Type] = []
        for i = 0; i < union.types.length(); i = i + 1 {
          let union_member = union.types[i]
          if is_assignable(union_member, cond.extends_type) {
            result_types.push(cond.true_type)
          } else {
            result_types.push(cond.false_type)
          }
        }
        // Create union of results
        union_type(checker, result_types)
      }
      _ => (cond.false_type, checker)
    }
  }
}

// ============================================================================
// Mapped Type Support
// ============================================================================

///|
/// Create a mapped type
pub fn mapped_type(
  checker : TypeChecker,
  type_parameter : CheckerTypeParameter,
  name_type : Type?,
  template_type : Type,
  readonly_modifier : MappedModifier,
  optional_modifier : MappedModifier,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (
    Mapped({
      type_parameter,
      name_type,
      template_type,
      readonly_modifier,
      optional_modifier,
      info,
    }),
    checker,
  )
}

///|
/// Evaluate a mapped type over a source object type
pub fn evaluate_mapped_type(
  checker : TypeChecker,
  mapped : CheckerMappedType,
  source_type : Type,
) -> (Type, TypeChecker) {
  match source_type {
    Object(obj) => {
      // Map over each property in the source
      let result_props : Map[String, PropertySignature] = Map::new()
      let props_iter = obj.properties.iter()
      for entry in props_iter {
        let (name, prop) = entry
        // Apply readonly modifier
        let is_readonly = match mapped.readonly_modifier {
          Add => true
          Remove => false
          Unchanged => prop.is_readonly
        }
        // Apply optional modifier
        let is_optional = match mapped.optional_modifier {
          Add => true
          Remove => false
          Unchanged => prop.is_optional
        }
        // Apply template type (simplified - would need type substitution)
        result_props.set(name, {
          name,
          prop_type: mapped.template_type,
          is_optional,
          is_readonly,
        })
      }
      let (info, checker) = create_type_info(checker)
      (
        Object({
          properties: result_props,
          call_signatures: [],
          construct_signatures: [],
          index_signatures: [],
          info,
        }),
        checker,
      )
    }
    _ =>
      // Can't evaluate mapped type over non-object
      (Mapped(mapped), checker)
  }
}

// ============================================================================
// Template Literal Type Support
// ============================================================================

///|
/// Create a template literal type
pub fn template_literal_type(
  checker : TypeChecker,
  texts : Array[String],
  types : Array[Type],
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (TemplateLiteral({ texts, types, info }), checker)
}

///|
/// Check if a string matches a template literal pattern
pub fn matches_template_literal(
  value : String,
  template : CheckerTemplateLiteralType,
) -> Bool {
  // Simple implementation: check if string starts with first text
  if template.texts.length() == 0 {
    return true
  }
  let first_text = template.texts[0]
  if not(value.has_prefix(first_text)) {
    return false
  }
  // For full implementation, would need regex-like matching
  // For now, accept if starts correctly
  true
}

///|
/// Evaluate a template literal type to possible string values
pub fn evaluate_template_literal(
  _checker : TypeChecker,
  template : CheckerTemplateLiteralType,
) -> Array[String] {
  // Simplified: just return the static parts concatenated
  let mut result = ""
  for i = 0; i < template.texts.length(); i = i + 1 {
    result = result + template.texts[i]
    if i < template.types.length() {
      // Add placeholder for interpolated types
      result = result + "*"
    }
  }
  [result]
}

// ============================================================================
// Index Access Type Support
// ============================================================================

///|
/// Create an index access type
pub fn index_access_type(
  checker : TypeChecker,
  object_type : Type,
  index_type : Type,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (IndexAccess({ object_type, index_type, info }), checker)
}

///|
/// Resolve an index access type to its result type
pub fn resolve_index_access(
  checker : TypeChecker,
  index_access : CheckerIndexAccessType,
) -> (Type, TypeChecker) {
  match index_access.object_type {
    Object(obj) =>
      // Access by string literal
      match index_access.index_type {
        StringLiteral(key, _) =>
          match obj.properties.get(key) {
            Some(prop) => (prop.prop_type, checker)
            None =>
              // Check index signatures
              resolve_via_index_signature(checker, obj.index_signatures)
          }
        Number(_) =>
          // Numeric index - check index signatures
          resolve_via_index_signature(checker, obj.index_signatures)
        _ =>
          // Unknown index type
          any_type(checker)
      }
    Type::Array(arr) =>
      // Array access returns element type
      match index_access.index_type {
        Number(_) | NumberLiteral(_, _) => (arr.element_type, checker)
        _ => any_type(checker)
      }
    Tuple(tuple) =>
      // Tuple access by literal number
      match index_access.index_type {
        NumberLiteral(idx, _) => {
          let index = idx.to_int()
          match get_tuple_element_type(tuple, index) {
            Some(t) => (t, checker)
            None => any_type(checker)
          }
        }
        Number(_) => {
          // Union of all tuple element types
          let elem_types : Array[Type] = []
          for i = 0; i < tuple.element_types.length(); i = i + 1 {
            elem_types.push(tuple.element_types[i].element_type)
          }
          union_type(checker, elem_types)
        }
        _ => any_type(checker)
      }
    _ =>
      // Can't resolve index access on this type
      any_type(checker)
  }
}

///|
/// Resolve type via index signature
fn resolve_via_index_signature(
  checker : TypeChecker,
  index_sigs : Array[IndexSignature],
) -> (Type, TypeChecker) {
  if index_sigs.length() > 0 {
    // Return first matching index signature's return type
    (index_sigs[0].return_type, checker)
  } else {
    any_type(checker)
  }
}

// ============================================================================
// Infer Type Support
// ============================================================================

///|
/// Create an infer type placeholder
pub fn infer_type_placeholder(
  checker : TypeChecker,
  name : String,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (Infer({ type_parameter_name: name, info }), checker)
}

///|
/// Infer type parameters from conditional type matching
pub fn infer_type_parameters(
  checker : TypeChecker,
  check_type : Type,
  extends_type : Type,
) -> (Map[String, Type], TypeChecker) {
  let inferred : Map[String, Type] = Map::new()
  let checker = infer_type_parameters_recursive(
    checker, check_type, extends_type, inferred,
  )
  (inferred, checker)
}

///|
/// Recursively infer type parameters
fn infer_type_parameters_recursive(
  checker : TypeChecker,
  source : Type,
  target : Type,
  inferred : Map[String, Type],
) -> TypeChecker {
  match target {
    Infer(inf) => {
      // Found an infer placeholder - record the inferred type
      inferred.set(inf.type_parameter_name, source)
      checker
    }
    Type::Array(target_arr) =>
      match source {
        Type::Array(source_arr) =>
          infer_type_parameters_recursive(
            checker,
            source_arr.element_type,
            target_arr.element_type,
            inferred,
          )
        _ => checker
      }
    Tuple(target_tuple) =>
      match source {
        Tuple(source_tuple) => {
          let mut checker = checker
          let min_len = if source_tuple.element_types.length() <
            target_tuple.element_types.length() {
            source_tuple.element_types.length()
          } else {
            target_tuple.element_types.length()
          }
          for i = 0; i < min_len; i = i + 1 {
            checker = infer_type_parameters_recursive(
              checker,
              source_tuple.element_types[i].element_type,
              target_tuple.element_types[i].element_type,
              inferred,
            )
          }
          checker
        }
        _ => checker
      }
    Type::Function(target_fn) =>
      match source {
        Type::Function(source_fn) => {
          // Infer from return type
          let checker = infer_type_parameters_recursive(
            checker,
            source_fn.return_type,
            target_fn.return_type,
            inferred,
          )
          // Infer from parameters
          let mut checker = checker
          let min_len = if source_fn.parameters.length() <
            target_fn.parameters.length() {
            source_fn.parameters.length()
          } else {
            target_fn.parameters.length()
          }
          for i = 0; i < min_len; i = i + 1 {
            checker = infer_type_parameters_recursive(
              checker,
              source_fn.parameters[i].param_type,
              target_fn.parameters[i].param_type,
              inferred,
            )
          }
          checker
        }
        _ => checker
      }
    _ => checker
  }
}

// ============================================================================
// Union Type Helper
// ============================================================================

///|
/// Create a union type from an array of types
pub fn union_type(
  checker : TypeChecker,
  types : Array[Type],
) -> (Type, TypeChecker) {
  // Flatten nested unions and remove duplicates
  let flattened : Array[Type] = []
  for i = 0; i < types.length(); i = i + 1 {
    match types[i] {
      Union(inner) =>
        for j = 0; j < inner.types.length(); j = j + 1 {
          if not(contains_type(flattened, inner.types[j])) {
            flattened.push(inner.types[j])
          }
        }
      other => if not(contains_type(flattened, other)) { flattened.push(other) }
    }
  }
  // Single type doesn't need union
  if flattened.length() == 1 {
    return (flattened[0], checker)
  }
  // Empty union is never
  if flattened.length() == 0 {
    return never_type(checker)
  }
  let (info, checker) = create_type_info(checker)
  (Union({ types: flattened, info }), checker)
}

///|
/// Check if array contains a type (by structure)
fn contains_type(types : Array[Type], target : Type) -> Bool {
  for i = 0; i < types.length(); i = i + 1 {
    if types_equal(types[i], target) {
      return true
    }
  }
  false
}

///|
/// Check if two types are structurally equal
fn types_equal(a : Type, b : Type) -> Bool {
  match (a, b) {
    (Number(_), Number(_)) => true
    (String(_), String(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Void(_), Void(_)) => true
    (Undefined(_), Undefined(_)) => true
    (Null(_), Null(_)) => true
    (Any(_), Any(_)) => true
    (Unknown(_), Unknown(_)) => true
    (Never(_), Never(_)) => true
    (Symbol(_), Symbol(_)) => true
    (NumberLiteral(v1, _), NumberLiteral(v2, _)) => v1 == v2
    (StringLiteral(v1, _), StringLiteral(v2, _)) => v1 == v2
    (BooleanLiteral(v1, _), BooleanLiteral(v2, _)) => v1 == v2
    (TypeReference(r1), TypeReference(r2)) => r1.name == r2.name
    _ => false
  }
}

// ============================================================================
// Type Checking Entry Point
// ============================================================================

///|
/// Check a bound source file
pub fn check_source_file(bound : BoundSourceFile) -> CheckResult {
  let checker = TypeChecker::new(bound.file_path, Some(bound.global_scope))
  let checker = check_statements(checker, bound.statements)

  // Return result
  let typed_file : TypedFile = {
    file_path: bound.file_path,
    statements: bound.statements,
    types: checker.node_types,
    diagnostics: checker.diagnostics,
  }
  if checker.diagnostics.is_empty() {
    Ok(typed_file)
  } else {
    Err(checker.diagnostics)
  }
}

///|
/// Check an array of statements
fn check_statements(
  checker : TypeChecker,
  statements : Array[Node],
) -> TypeChecker {
  let mut checker = checker
  for i = 0; i < statements.length(); i = i + 1 {
    checker = check_statement(checker, statements[i])
  }
  checker
}

///|
/// Check a single statement
fn check_statement(checker : TypeChecker, node : Node) -> TypeChecker {
  match node {
    VariableStatement(var_stmt) => check_variable_statement(checker, var_stmt)
    ExpressionStatement(expr_stmt) =>
      check_expression_statement(checker, expr_stmt)
    FunctionDeclaration(func) => check_function_declaration(checker, func)
    ReturnStatement(ret) => check_return_statement(checker, ret)
    IfStatement(if_stmt) => check_if_statement(checker, if_stmt)
    WhileStatement(while_stmt) => check_while_statement(checker, while_stmt)
    DoWhileStatement(do_while) => check_do_while_statement(checker, do_while)
    ForStatement(for_stmt) => check_for_statement(checker, for_stmt)
    BlockStatement(block) => check_block_statement(checker, block)
    ClassDeclaration(class_decl) => check_class_declaration(checker, class_decl)
    InterfaceDeclaration(_) => checker // Interfaces don't need runtime checking
    EnumDeclaration(enum_decl) => check_enum_declaration(checker, enum_decl)
    TypeAliasDeclaration(_) => checker // Type aliases don't need runtime checking
    ImportDeclaration(_) => checker // Imports checked separately
    ExportDeclaration(_) => checker // Exports checked separately
    TryStatement(try_stmt) => check_try_statement(checker, try_stmt)
    ThrowStatement(throw_stmt) => check_throw_statement(checker, throw_stmt)
    SwitchStatement(switch_stmt) => check_switch_statement(checker, switch_stmt)
    BreakStatement(_) => checker
    ContinueStatement(_) => checker
    _ => checker // Other statements
  }
}

// ============================================================================
// Variable Statement Checking
// ============================================================================

///|
/// Check variable statement
fn check_variable_statement(
  checker : TypeChecker,
  var_stmt : VariableStatement,
) -> TypeChecker {
  let mut checker = checker
  for i = 0; i < var_stmt.declarations.length(); i = i + 1 {
    checker = check_variable_declaration(checker, var_stmt.declarations[i])
  }
  checker
}

///|
/// Check variable declaration
fn check_variable_declaration(
  checker : TypeChecker,
  decl : VariableDeclaration,
) -> TypeChecker {
  // Get the declared type (if any)
  let (declared_type, checker) = match decl.type_annotation {
    Some(type_node) => get_type_from_type_node(checker, type_node)
    None => (None, checker)
  }

  // Get the initializer type (if any)
  let (init_type, checker) = match decl.initializer {
    Some(init) => {
      let (t, c) = infer_type(checker, init)
      (Some(t), c)
    }
    None => (None, checker)
  }

  // Check compatibility if both are present
  let checker = match (declared_type, init_type) {
    (Some(decl_t), Some(init_t)) =>
      if is_assignable(init_t, decl_t) {
        checker
      } else {
        add_diagnostic(
          checker,
          "Type mismatch in variable declaration",
          decl.location,
          2322,
        )
      }
    _ => checker
  }
  checker
}

// ============================================================================
// Expression Checking
// ============================================================================

///|
/// Check expression statement
fn check_expression_statement(
  checker : TypeChecker,
  expr_stmt : ExpressionStatement,
) -> TypeChecker {
  let (_, checker) = infer_type(checker, expr_stmt.expression)
  checker
}

///|
/// Infer the type of an expression
fn infer_type(checker : TypeChecker, expr : Node) -> (Type, TypeChecker) {
  match expr {
    NumericLiteral(_) => number_type(checker)
    StringLiteral(_) => string_type(checker)
    BooleanLiteral(_) => boolean_type(checker)
    NullLiteral(_) => null_type(checker)
    Identifier(id) =>
      // Check for undefined identifier
      if id.name == "undefined" {
        undefined_type(checker)
      } else {
        infer_identifier_type(checker, id)
      }
    BinaryExpression(bin_expr) =>
      infer_binary_expression_type(checker, bin_expr)
    UnaryExpression(un_expr) => infer_unary_expression_type(checker, un_expr)
    CallExpression(call) => infer_call_expression_type(checker, call)
    PropertyAccessExpression(prop) => infer_property_access_type(checker, prop)
    ElementAccessExpression(elem) => infer_element_access_type(checker, elem)
    ArrayLiteralExpression(arr) => infer_array_literal_type(checker, arr)
    ObjectLiteralExpression(obj) => infer_object_literal_type(checker, obj)
    ArrowFunction(arrow) => infer_arrow_function_type(checker, arrow)
    ConditionalExpression(cond) => infer_conditional_type(checker, cond)
    NewExpression(new_expr) => infer_new_expression_type(checker, new_expr)
    TemplateExpression(template) =>
      infer_template_expression_type(checker, template)
    ThisExpression(_) => infer_this_type(checker)
    SpreadExpression(spread) => infer_type(checker, spread.expression)
    OptionalChain(oc) => infer_optional_chain_type(checker, oc)
    AwaitExpression(ae) => infer_await_expression_type(checker, ae)
    YieldExpression(ye) => infer_yield_expression_type(checker, ye)
    AsExpression(as_expr) => infer_as_expression_type(checker, as_expr)
    NonNullExpression(nne) => infer_non_null_expression_type(checker, nne)
    TypeAssertionExpression(tae) => infer_type_assertion_type(checker, tae)
    ParenthesizedExpression(pe) => infer_type(checker, pe.expression)
    FunctionExpression(fe) => infer_function_expression_type(checker, fe)
    _ => any_type(checker) // Fallback for unhandled expressions
  }
}

///|
/// Infer identifier type by looking up symbol in scope chain
fn infer_identifier_type(
  checker : TypeChecker,
  id : Identifier,
) -> (Type, TypeChecker) {
  // Look up symbol in scope chain
  match lookup_symbol(checker, id.name) {
    Some(symbol) =>
      // Get type from symbol
      match get_symbol_type(checker, symbol) {
        (Some(t), c) => (t, c)
        (None, c) =>
          // Symbol exists but type not yet computed - infer from declaration
          infer_symbol_type(c, symbol)
      }
    None =>
      // Undeclared identifier - return any type without error
      // (error would be too strict for current implementation)
      any_type(checker)
  }
}

///|
/// Get cached type for a symbol
fn get_symbol_type(
  checker : TypeChecker,
  symbol : Symbol,
) -> (Type?, TypeChecker) {
  match checker.symbol_types.get(symbol.id) {
    Some(t) => (Some(t), checker)
    None => (None, checker)
  }
}

///|
/// Infer type from symbol's declaration
fn infer_symbol_type(
  checker : TypeChecker,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  match symbol.value_declaration {
    Some(node) => infer_declaration_type(checker, node, symbol)
    None => any_type(checker)
  }
}

///|
/// Infer type from a declaration node
fn infer_declaration_type(
  checker : TypeChecker,
  node : Node,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  match node {
    VariableStatement(var_stmt) => {
      // Get the first declaration from the statement
      if var_stmt.declarations.is_empty() {
        return any_type(checker)
      }
      let var_decl = var_stmt.declarations[0]
      // Check for explicit type annotation first
      match var_decl.type_annotation {
        Some(type_node) =>
          match get_type_from_type_node(checker, type_node) {
            (Some(t), c) => {
              // Cache the type for future lookups
              let new_symbol_types = c.symbol_types
              new_symbol_types.set(symbol.id, t)
              (t, { ..c, symbol_types: new_symbol_types })
            }
            (None, c) => infer_from_initializer(c, var_decl.initializer, symbol)
          }
        None => infer_from_initializer(checker, var_decl.initializer, symbol)
      }
    }
    FunctionDeclaration(func_decl) =>
      infer_function_declaration_type(checker, func_decl, symbol)
    ClassDeclaration(class_decl) =>
      infer_class_declaration_type(checker, class_decl, symbol)
    Parameter(param) => infer_parameter_type(checker, param, symbol)
    _ => any_type(checker)
  }
}

///|
/// Infer type from initializer expression
fn infer_from_initializer(
  checker : TypeChecker,
  initializer : Node?,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  match initializer {
    Some(init) => {
      let (t, c) = infer_type(checker, init)
      // Cache the type
      let new_symbol_types = c.symbol_types
      new_symbol_types.set(symbol.id, t)
      (t, { ..c, symbol_types: new_symbol_types })
    }
    None => any_type(checker)
  }
}

///|
/// Infer type from function declaration
fn infer_function_declaration_type(
  checker : TypeChecker,
  func : FunctionDeclaration,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  // Build parameter list
  let parameters : Array[CheckerParameter] = []
  let mut checker = checker
  for param_node in func.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c) = match p.type_annotation {
          Some(type_node) =>
            match get_type_from_type_node(checker, type_node) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
          None => any_type(checker)
        }
        checker = c
        parameters.push({
          name: get_parameter_name(p.name),
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }

  // Get return type
  let (return_type, checker) = match func.return_type {
    Some(type_node) =>
      match get_type_from_type_node(checker, type_node) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    None => any_type(checker)
  }
  let (info, checker) = create_type_info(checker)
  let func_type = Type::Function({ parameters, return_type, info })

  // Cache the type
  let new_symbol_types = checker.symbol_types
  new_symbol_types.set(symbol.id, func_type)
  (func_type, { ..checker, symbol_types: new_symbol_types })
}

///|
/// Infer type from class declaration
fn infer_class_declaration_type(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  // Build object type for the class instance
  let properties : Map[String, PropertySignature] = Map::new()
  let mut checker = checker
  for class_member in class_decl.members {
    match class_member {
      PropertyDeclaration(prop) => {
        let (prop_type, c) = match prop.type_annotation {
          Some(type_node) =>
            match get_type_from_type_node(checker, type_node) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
          None =>
            match prop.initializer {
              Some(init) => infer_type(checker, init)
              None => any_type(checker)
            }
        }
        checker = c
        // Check if property has readonly modifier
        let has_readonly = has_modifier(prop.modifiers, Modifier::Readonly)
        properties.set(prop.name, {
          name: prop.name,
          prop_type,
          is_optional: false,
          is_readonly: has_readonly,
        })
      }
      MethodDeclaration(method_decl) => {
        let (method_type, c) = infer_method_type(checker, method_decl)
        checker = c
        properties.set(method_decl.name, {
          name: method_decl.name,
          prop_type: method_type,
          is_optional: false,
          is_readonly: false,
        })
      }
      _ => ()
    }
  }
  let (info, checker) = create_type_info(checker)
  let class_type = Type::Object({
    properties,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info,
  })

  // Cache the type
  let new_symbol_types = checker.symbol_types
  new_symbol_types.set(symbol.id, class_type)
  (class_type, { ..checker, symbol_types: new_symbol_types })
}

///|
/// Infer type from method declaration
fn infer_method_type(
  checker : TypeChecker,
  method_decl : MethodDeclaration,
) -> (Type, TypeChecker) {
  // Build parameter list
  let parameters : Array[CheckerParameter] = []
  let mut checker = checker
  for param_node in method_decl.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c) = match p.type_annotation {
          Some(type_node) =>
            match get_type_from_type_node(checker, type_node) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
          None => any_type(checker)
        }
        checker = c
        parameters.push({
          name: get_parameter_name(p.name),
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }

  // Get return type
  let (return_type, checker) = match method_decl.return_type {
    Some(type_node) =>
      match get_type_from_type_node(checker, type_node) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    None => any_type(checker)
  }
  let (info, checker) = create_type_info(checker)
  (Type::Function({ parameters, return_type, info }), checker)
}

///|
/// Infer type from parameter
fn infer_parameter_type(
  checker : TypeChecker,
  param : Parameter,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  let (param_type, checker) = match param.type_annotation {
    Some(type_node) =>
      match get_type_from_type_node(checker, type_node) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    None => any_type(checker)
  }

  // Cache the type
  let new_symbol_types = checker.symbol_types
  new_symbol_types.set(symbol.id, param_type)
  (param_type, { ..checker, symbol_types: new_symbol_types })
}

///|
/// Infer binary expression type
fn infer_binary_expression_type(
  checker : TypeChecker,
  bin_expr : BinaryExpression,
) -> (Type, TypeChecker) {
  let (left_type, checker) = infer_type(checker, bin_expr.left)
  let (right_type, checker) = infer_type(checker, bin_expr.right)

  // Determine result type based on operator
  match bin_expr.operator {
    // Addition: can be number + number -> number OR string + string -> string
    Add =>
      // Check if either operand is a string
      match (left_type, right_type) {
        (String(_), _) | (_, String(_)) => string_type(checker)
        _ => {
          let checker = check_numeric_operands(
            checker,
            left_type,
            right_type,
            bin_expr.operator,
            get_node_location(BinaryExpression(bin_expr)),
          )
          number_type(checker)
        }
      }
    // Arithmetic operators: number op number -> number
    Subtract | Multiply | Divide | Remainder | Exponentiate => {
      let checker = check_numeric_operands(
        checker,
        left_type,
        right_type,
        bin_expr.operator,
        get_node_location(BinaryExpression(bin_expr)),
      )
      number_type(checker)
    }
    // Bitwise operators: number op number -> number
    BitwiseAnd
    | BitwiseOr
    | BitwiseXor
    | LeftShift
    | RightShift
    | UnsignedRightShift => {
      let checker = check_numeric_operands(
        checker,
        left_type,
        right_type,
        bin_expr.operator,
        get_node_location(BinaryExpression(bin_expr)),
      )
      number_type(checker)
    }
    // Comparison operators: any op any -> boolean
    LessThan
    | GreaterThan
    | LessThanEquals
    | GreaterThanEquals
    | Equals
    | NotEquals
    | StrictEquals
    | StrictNotEquals => boolean_type(checker)
    // instanceof operator: any instanceof any -> boolean
    InstanceOf => boolean_type(checker)
    // in operator: any in any -> boolean
    In => boolean_type(checker)
    // Logical operators: boolean op boolean -> boolean
    LogicalAnd | LogicalOr => {
      let checker = check_boolean_operands(
        checker,
        left_type,
        right_type,
        bin_expr.operator,
        get_node_location(BinaryExpression(bin_expr)),
      )
      boolean_type(checker)
    }
    // Assignment operators: return the type of the right-hand side
    Assign
    | AddAssign
    | SubtractAssign
    | MultiplyAssign
    | DivideAssign
    | RemainderAssign
    | BitwiseAndAssign
    | BitwiseOrAssign
    | BitwiseXorAssign => {
      // Check if trying to assign to a const variable
      let checker = match bin_expr.left {
        Identifier(id) =>
          match lookup_symbol(checker, id.name) {
            Some(symbol) =>
              if symbol.flags.is_const {
                add_diagnostic(
                  checker,
                  "Cannot assign to '\{id.name}' because it is a constant",
                  get_node_location(BinaryExpression(bin_expr)),
                  2588,
                )
              } else {
                checker
              }
            None => checker
          }
        _ => checker
      }
      (right_type, checker)
    }
    _ => any_type(checker)
  }
}

///|
/// Infer unary expression type
fn infer_unary_expression_type(
  checker : TypeChecker,
  un_expr : UnaryExpression,
) -> (Type, TypeChecker) {
  let (operand_type, checker) = infer_type(checker, un_expr.operand)
  match un_expr.operator {
    Plus | Minus | BitwiseNot => {
      let checker = check_numeric_operand(
        checker,
        operand_type,
        un_expr.operator,
        get_node_location(UnaryExpression(un_expr)),
      )
      number_type(checker)
    }
    LogicalNot => boolean_type(checker)
    Increment | Decrement => {
      let checker = check_numeric_operand(
        checker,
        operand_type,
        un_expr.operator,
        get_node_location(UnaryExpression(un_expr)),
      )
      number_type(checker)
    }
    TypeOf => string_type(checker) // typeof always returns a string
    Void => undefined_type(checker) // void operator always returns undefined
    Delete => boolean_type(checker) // delete operator returns boolean
    _ => any_type(checker)
  }
}

///|
/// Infer call expression type with signature matching
fn infer_call_expression_type(
  checker : TypeChecker,
  call : CallExpression,
) -> (Type, TypeChecker) {
  let (func_type, checker) = infer_type(checker, call.expression)

  // Infer argument types
  let mut checker = checker
  let arg_types : Array[Type] = []
  for i = 0; i < call.arguments.length(); i = i + 1 {
    let (arg_type, c) = infer_type(checker, call.arguments[i])
    arg_types.push(arg_type)
    checker = c
  }

  // Get call signatures from function type
  let signatures = get_call_signatures(func_type)
  if signatures.is_empty() {
    // Try to infer from Function type directly
    match func_type {
      Type::Function(func) =>
        // Return the function's return type
        (func.return_type, checker)
      Any(_) =>
        // Any is callable and returns any
        any_type(checker)
      _ =>
        // Not callable - return any for now (could add diagnostic)
        any_type(checker)
    }
  } else {
    // Resolve which overload matches
    match resolve_call_overload(checker, signatures, arg_types) {
      Some((return_type, c)) => (return_type, c)
      None =>
        // No overload matches - return any for now
        any_type(checker)
    }
  }
}

///|
/// Get call signatures from a type
fn get_call_signatures(t : Type) -> Array[CheckerSignature] {
  match t {
    Type::Function(func) => {
      let result : Array[CheckerSignature] = []
      result.push({
        parameters: func.parameters,
        return_type: func.return_type,
        type_parameters: [],
      })
      result
    }
    Type::Object(obj) => obj.call_signatures
    Union(union) => {
      // Collect signatures from union members
      let result : Array[CheckerSignature] = []
      for union_member in union.types {
        let member_sigs = get_call_signatures(union_member)
        for sig in member_sigs {
          result.push(sig)
        }
      }
      result
    }
    _ => []
  }
}

///|
/// Resolve which overload matches the call
fn resolve_call_overload(
  checker : TypeChecker,
  signatures : Array[CheckerSignature],
  arg_types : Array[Type],
) -> (Type, TypeChecker)? {
  // Try each signature in order
  for sig in signatures {
    match try_signature(checker, sig, arg_types) {
      Some((return_type, c)) => return Some((return_type, c))
      None => continue
    }
  }
  None
}

///|
/// Try to apply a signature to arguments
fn try_signature(
  checker : TypeChecker,
  signature : CheckerSignature,
  arg_types : Array[Type],
) -> (Type, TypeChecker)? {
  // Check argument count
  let min_params = count_required_params(signature.parameters)
  let max_params = if has_rest_param(signature.parameters) {
    9999 // Large number to represent unlimited params for rest
  } else {
    signature.parameters.length()
  }
  if arg_types.length() < min_params || arg_types.length() > max_params {
    return None
  }

  // Check each argument against corresponding parameter type
  for i = 0; i < arg_types.length(); i = i + 1 {
    let param_idx = if i < signature.parameters.length() {
      i
    } else {
      signature.parameters.length() - 1
    }
    let param_type = signature.parameters[param_idx].param_type
    if not(is_assignable(arg_types[i], param_type)) {
      return None
    }
  }
  Some((signature.return_type, checker))
}

///|
/// Count required parameters (non-optional, non-rest)
fn count_required_params(params : Array[CheckerParameter]) -> Int {
  let mut count = 0
  for param in params {
    if not(param.is_optional) && not(param.is_rest) {
      count = count + 1
    }
  }
  count
}

///|
/// Check if signature has a rest parameter
fn has_rest_param(params : Array[CheckerParameter]) -> Bool {
  if params.is_empty() {
    return false
  }
  params[params.length() - 1].is_rest
}

// ============================================================================
// Generic Type Instantiation and Constraint Checking
// ============================================================================

///|
/// Substitute type parameters with actual type arguments
fn substitute_type_parameters(
  checker : TypeChecker,
  target_type : Type,
  type_params : Array[CheckerTypeParameter],
  type_args : Array[Type],
) -> (Type, TypeChecker) {
  // Build substitution map
  let substitutions : Map[String, Type] = Map::new()
  for i = 0; i < type_params.length(); i = i + 1 {
    if i < type_args.length() {
      substitutions.set(type_params[i].name, type_args[i])
    } else {
      // Use default type if available
      match type_params[i].default_type {
        Some(default_t) => substitutions.set(type_params[i].name, default_t)
        None => () // Missing type argument
      }
    }
  }

  // Recursively substitute
  substitute_in_type(checker, target_type, substitutions)
}

///|
/// Recursively substitute type parameters in a type
fn substitute_in_type(
  checker : TypeChecker,
  t : Type,
  substitutions : Map[String, Type],
) -> (Type, TypeChecker) {
  match t {
    TypeReference(type_ref) =>
      // Check if this is a type parameter
      match substitutions.get(type_ref.name) {
        Some(substituted) => (substituted, checker)
        None => {
          // Substitute in type arguments
          let mut checker = checker
          let new_args : Array[Type] = []
          for arg in type_ref.type_arguments {
            let (new_arg, c) = substitute_in_type(checker, arg, substitutions)
            new_args.push(new_arg)
            checker = c
          }
          let (info, checker) = create_type_info(checker)
          (
            TypeReference({
              name: type_ref.name,
              type_arguments: new_args,
              info,
            }),
            checker,
          )
        }
      }
    Type::Function(func) => {
      // Substitute in parameters and return type
      let mut checker = checker
      let new_params : Array[CheckerParameter] = []
      for param in func.parameters {
        let (new_type, c) = substitute_in_type(
          checker,
          param.param_type,
          substitutions,
        )
        checker = c
        new_params.push({
          name: param.name,
          param_type: new_type,
          is_optional: param.is_optional,
          is_rest: param.is_rest,
        })
      }
      let (new_return, checker) = substitute_in_type(
        checker,
        func.return_type,
        substitutions,
      )
      let (info, checker) = create_type_info(checker)
      (
        Type::Function({ parameters: new_params, return_type: new_return, info }),
        checker,
      )
    }
    Type::Array(arr) => {
      let (new_elem, checker) = substitute_in_type(
        checker,
        arr.element_type,
        substitutions,
      )
      let (info, checker) = create_type_info(checker)
      (Type::Array({ element_type: new_elem, info }), checker)
    }
    Union(union) => {
      let mut checker = checker
      let new_types : Array[Type] = []
      for union_member in union.types {
        let (new_member, c) = substitute_in_type(
          checker, union_member, substitutions,
        )
        new_types.push(new_member)
        checker = c
      }
      let (info, checker) = create_type_info(checker)
      (Union({ types: new_types, info }), checker)
    }
    Type::Object(obj) => {
      let mut checker = checker
      let new_props : Map[String, PropertySignature] = Map::new()
      for entry in obj.properties {
        let (name, prop) = entry
        let (new_type, c) = substitute_in_type(
          checker,
          prop.prop_type,
          substitutions,
        )
        checker = c
        new_props.set(name, {
          name: prop.name,
          prop_type: new_type,
          is_optional: prop.is_optional,
          is_readonly: prop.is_readonly,
        })
      }
      let (info, checker) = create_type_info(checker)
      (
        Type::Object({
          properties: new_props,
          call_signatures: obj.call_signatures,
          construct_signatures: obj.construct_signatures,
          index_signatures: obj.index_signatures,
          info,
        }),
        checker,
      )
    }
    _ => (t, checker) // Primitives don't need substitution
  }
}

///|
/// Check that type argument satisfies constraint
fn check_type_constraint(
  checker : TypeChecker,
  type_arg : Type,
  constraint : Type,
  location : SourceLocation,
) -> TypeChecker {
  if not(is_assignable(type_arg, constraint)) {
    add_diagnostic(
      checker, "Type does not satisfy the constraint", location, 2344,
    )
  } else {
    checker
  }
}

///|
/// Check all type arguments against their constraints
fn check_type_arguments(
  checker : TypeChecker,
  type_params : Array[CheckerTypeParameter],
  type_args : Array[Type],
  location : SourceLocation,
) -> TypeChecker {
  let mut checker = checker

  // Check arity
  let min_required = count_required_type_params(type_params)
  if type_args.length() < min_required {
    checker = add_diagnostic(
      checker, "Generic type requires more type arguments", location, 2314,
    )
  }
  if type_args.length() > type_params.length() {
    checker = add_diagnostic(
      checker, "Too many type arguments provided", location, 2558,
    )
  }

  // Check constraints
  for i = 0; i < type_args.length() && i < type_params.length(); i = i + 1 {
    match type_params[i].constraint {
      Some(constraint) =>
        checker = check_type_constraint(
          checker,
          type_args[i],
          constraint,
          location,
        )
      None => ()
    }
  }
  checker
}

///|
/// Count required type parameters (those without defaults)
fn count_required_type_params(type_params : Array[CheckerTypeParameter]) -> Int {
  let mut count = 0
  for param in type_params {
    if param.default_type.is_none() {
      count = count + 1
    }
  }
  count
}

///|
/// Infer type arguments from call arguments
fn infer_type_arguments(
  checker : TypeChecker,
  type_params : Array[CheckerTypeParameter],
  param_types : Array[Type],
  arg_types : Array[Type],
) -> (Array[Type], TypeChecker) {
  // Build inference context - maps type param names to candidate types
  let inferences : Map[String, Array[Type]] = Map::new()
  for param in type_params {
    inferences.set(param.name, [])
  }

  // Collect inferences from argument positions
  for i = 0; i < param_types.length() && i < arg_types.length(); i = i + 1 {
    infer_from_types(arg_types[i], param_types[i], inferences)
  }
  let mut checker = checker

  // Resolve inferences
  let result : Array[Type] = []
  for param in type_params {
    match inferences.get(param.name) {
      Some(candidates) =>
        if not(candidates.is_empty()) {
          // Use first candidate (could use best common type)
          result.push(candidates[0])
        } else {
          // Use constraint or default
          match param.default_type {
            Some(default_t) => result.push(default_t)
            None =>
              match param.constraint {
                Some(constraint) => result.push(constraint)
                None => {
                  let (t, c) = any_type(checker)
                  result.push(t)
                  checker = c
                }
              }
          }
        }
      None => {
        let (t, c) = any_type(checker)
        result.push(t)
        checker = c
      }
    }
  }
  (result, checker)
}

///|
/// Infer type parameter from source to target type
fn infer_from_types(
  source : Type,
  target : Type,
  inferences : Map[String, Array[Type]],
) -> Unit {
  match target {
    TypeReference(type_ref) =>
      // Check if target is a type parameter we're inferring
      match inferences.get(type_ref.name) {
        Some(candidates) => candidates.push(source)
        None =>
          // Not a type parameter - recurse into type arguments
          match source {
            TypeReference(source_ref) =>
              for i = 0
                  i < type_ref.type_arguments.length() &&
                 i < source_ref.type_arguments.length()
                  i = i + 1 {
                infer_from_types(
                  source_ref.type_arguments[i],
                  type_ref.type_arguments[i],
                  inferences,
                )
              }
            _ => ()
          }
      }
    Type::Array(arr) =>
      match source {
        Type::Array(source_arr) =>
          infer_from_types(
            source_arr.element_type,
            arr.element_type,
            inferences,
          )
        _ => ()
      }
    Type::Function(func) =>
      match source {
        Type::Function(source_func) => {
          // Infer from return type
          infer_from_types(
            source_func.return_type,
            func.return_type,
            inferences,
          )
          // Infer from parameters (contravariant)
          for i = 0
              i < func.parameters.length() &&
             i < source_func.parameters.length()
              i = i + 1 {
            infer_from_types(
              func.parameters[i].param_type,
              source_func.parameters[i].param_type,
              inferences,
            )
          }
        }
        _ => ()
      }
    _ => ()
  }
}

// ============================================================================
// Type Guards and Narrowing
// ============================================================================

///|
/// Check if expression is a type guard and extract guard info
fn get_type_guard_info(checker : TypeChecker, expr : Node) -> TypeGuardInfo? {
  match expr {
    // typeof x === "string"
    BinaryExpression(bin) => get_binary_type_guard(checker, bin)
    // Truthiness check (just identifier)
    Identifier(id) =>
      // Narrows out null and undefined
      Some({
        parameter_name: id.name,
        type_when_true: None, // Remove null/undefined
        type_when_false: None, // null | undefined
      })
    // !x (negation)
    UnaryExpression(un) =>
      match un.operator {
        LogicalNot =>
          // Flip the narrowing
          match get_type_guard_info(checker, un.operand) {
            Some(tg) =>
              Some({
                parameter_name: tg.parameter_name,
                type_when_true: tg.type_when_false,
                type_when_false: tg.type_when_true,
              })
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Get type guard from binary expression
fn get_binary_type_guard(
  checker : TypeChecker,
  bin : BinaryExpression,
) -> TypeGuardInfo? {
  match bin.operator {
    StrictEquals | Equals =>
      // typeof x === "string" or x === null
      match get_typeof_guard(checker, bin.left, bin.right) {
        Some(tg) => Some(tg)
        None =>
          match get_typeof_guard(checker, bin.right, bin.left) {
            Some(tg) => Some(tg)
            None =>
              match get_null_guard(bin.left, bin.right) {
                Some(tg) => Some(tg)
                None => get_null_guard(bin.right, bin.left)
              }
          }
      }
    StrictNotEquals | NotEquals => {
      // typeof x !== "string" - flip the result
      let maybe_typeof = match get_typeof_guard(checker, bin.left, bin.right) {
        Some(tg) => Some(tg)
        None => get_typeof_guard(checker, bin.right, bin.left)
      }
      match maybe_typeof {
        Some(tg) =>
          Some({
            parameter_name: tg.parameter_name,
            type_when_true: tg.type_when_false,
            type_when_false: tg.type_when_true,
          })
        None => {
          let maybe_null = match get_null_guard(bin.left, bin.right) {
            Some(tg) => Some(tg)
            None => get_null_guard(bin.right, bin.left)
          }
          match maybe_null {
            Some(tg) =>
              Some({
                parameter_name: tg.parameter_name,
                type_when_true: tg.type_when_false,
                type_when_false: tg.type_when_true,
              })
            None => None
          }
        }
      }
    }
    InstanceOf =>
      // x instanceof Class
      get_instanceof_guard(bin.left, bin.right)
    _ => None
  }
}

///|
/// Get typeof guard: typeof x === "string"
fn get_typeof_guard(
  checker : TypeChecker,
  left : Node,
  right : Node,
) -> TypeGuardInfo? {
  match left {
    UnaryExpression(un) =>
      match un.operator {
        TypeOf =>
          match un.operand {
            Identifier(id) =>
              match right {
                StringLiteral(s) => {
                  let narrowed_type = typeof_string_to_type(checker, s.value)
                  Some({
                    parameter_name: id.name,
                    type_when_true: narrowed_type,
                    type_when_false: None,
                  })
                }
                _ => None
              }
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Get null guard: x === null
fn get_null_guard(left : Node, right : Node) -> TypeGuardInfo? {
  match (left, right) {
    (Identifier(id), NullLiteral(_)) =>
      Some({
        parameter_name: id.name,
        type_when_true: None, // Type is null
        type_when_false: None, // Remove null from type
      })
    _ => None
  }
}

///|
/// Get instanceof guard: x instanceof Class
fn get_instanceof_guard(left : Node, right : Node) -> TypeGuardInfo? {
  match (left, right) {
    (Identifier(id), Identifier(_)) =>
      // Return guard info - actual type narrowing would require symbol lookup
      Some({
        parameter_name: id.name,
        type_when_true: None, // Would be the class type
        type_when_false: None,
      })
    _ => None
  }
}

///|
/// Convert typeof string to type
fn typeof_string_to_type(checker : TypeChecker, s : String) -> Type? {
  let (info, _) = create_type_info(checker)
  match s {
    "string" => Some(String(info))
    "number" => Some(Number(info))
    "boolean" => Some(Boolean(info))
    "undefined" => Some(Undefined(info))
    "object" =>
      Some(
        Type::Object({
          properties: Map::new(),
          call_signatures: [],
          construct_signatures: [],
          index_signatures: [],
          info,
        }),
      )
    "function" =>
      Some(Type::Function({ parameters: [], return_type: Any(info), info }))
    "symbol" => Some(Symbol(info))
    _ => None
  }
}

///|
/// Create a NarrowedType from original and narrowed types
pub fn create_narrowed_type(original_type : Type, narrowed_type : Type) -> NarrowedType {
  { original_type, narrowed_type }
}

///|
/// Add a narrowed type to the checker for a variable
fn add_narrowed_type(
  checker : TypeChecker,
  variable_name : String,
  original_type : Type,
  narrowed_type : Type,
) -> TypeChecker {
  let narrowed = create_narrowed_type(original_type, narrowed_type)
  let new_narrowed_types = checker.narrowed_types
  new_narrowed_types.set(variable_name, narrowed)
  { ..checker, narrowed_types: new_narrowed_types }
}

///|
/// Get the narrowed type for a variable, or None if not narrowed
fn get_narrowed_type(checker : TypeChecker, variable_name : String) -> Type? {
  match checker.narrowed_types.get(variable_name) {
    Some(narrowed) => Some(narrowed.narrowed_type)
    None => None
  }
}

///|
/// Remove narrowing for a variable (restore original type)
fn remove_narrowed_type(checker : TypeChecker, variable_name : String) -> TypeChecker {
  let new_narrowed_types = checker.narrowed_types
  new_narrowed_types.remove(variable_name)
  { ..checker, narrowed_types: new_narrowed_types }
}

///|
/// Clear all narrowed types (useful when exiting a narrowing scope)
fn clear_narrowed_types(checker : TypeChecker) -> TypeChecker {
  { ..checker, narrowed_types: Map::new() }
}

///|
/// Apply type narrowing based on type guard
fn apply_type_narrowing(
  original_type : Type,
  type_guard_info : TypeGuardInfo,
  is_true_branch : Bool,
) -> Type {
  let narrowed_type = if is_true_branch {
    type_guard_info.type_when_true
  } else {
    type_guard_info.type_when_false
  }
  match narrowed_type {
    Some(t) => t
    None => original_type // No narrowing available
  }
}

///|
/// Apply type narrowing to checker and return updated checker
fn apply_narrowing_to_checker(
  checker : TypeChecker,
  type_guard_info : TypeGuardInfo,
  is_true_branch : Bool,
) -> TypeChecker {
  let narrowed_type = if is_true_branch {
    type_guard_info.type_when_true
  } else {
    type_guard_info.type_when_false
  }
  match narrowed_type {
    Some(t) => {
      // Get original type from type cache or create a placeholder
      let (original, checker) = any_type(checker)
      add_narrowed_type(checker, type_guard_info.parameter_name, original, t)
    }
    None => checker
  }
}

///|
/// Narrow a union type by removing specified types
fn narrow_union(union : CheckerUnionType, exclude_types : Array[Type]) -> Type {
  let remaining : Array[Type] = []
  for union_member in union.types {
    let should_exclude = exclude_types
      .iter()
      .any(fn(exclude) { types_are_identical(union_member, exclude) })
    if not(should_exclude) {
      remaining.push(union_member)
    }
  }
  if remaining.length() == 1 {
    remaining[0]
  } else if remaining.is_empty() {
    Never(union.info)
  } else {
    Union({ types: remaining, info: union.info })
  }
}

///|
/// Check if two types are identical
fn types_are_identical(t1 : Type, t2 : Type) -> Bool {
  match (t1, t2) {
    (Any(_), Any(_)) => true
    (Unknown(_), Unknown(_)) => true
    (String(_), String(_)) => true
    (Number(_), Number(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Null(_), Null(_)) => true
    (Undefined(_), Undefined(_)) => true
    (Void(_), Void(_)) => true
    (Never(_), Never(_)) => true
    (Symbol(_), Symbol(_)) => true
    _ => false // Simplified - full implementation would be more complex
  }
}

// ============================================================================
// Semantic Validation
// ============================================================================

///|
/// Check for unreachable code in statement list
fn check_unreachable_code(
  checker : TypeChecker,
  statements : Array[Node],
) -> TypeChecker {
  let mut checker = checker
  let mut found_terminator = false
  for stmt in statements {
    if found_terminator {
      checker = add_diagnostic(
        checker,
        "Unreachable code detected.",
        get_node_location(stmt),
        7027,
      )
      break
    }

    // Check if statement is a terminator
    found_terminator = is_terminating_statement(stmt)
  }
  checker
}

///|
/// Check if statement terminates control flow
fn is_terminating_statement(stmt : Node) -> Bool {
  match stmt {
    ReturnStatement(_) => true
    ThrowStatement(_) => true
    BreakStatement(_) => true
    ContinueStatement(_) => true
    IfStatement(if_stmt) => {
      // Both branches must terminate
      let then_terminates = is_block_terminating(if_stmt.then_statement)
      let else_terminates = match if_stmt.else_statement {
        Some(else_stmt) => is_block_terminating(else_stmt)
        None => false
      }
      then_terminates && else_terminates
    }
    _ => false
  }
}

///|
/// Check if block terminates
fn is_block_terminating(stmt : Node) -> Bool {
  match stmt {
    BlockStatement(block) => {
      if block.statements.is_empty() {
        return false
      }
      is_terminating_statement(block.statements[block.statements.length() - 1])
    }
    _ => is_terminating_statement(stmt)
  }
}

///|
/// Check that abstract class cannot be instantiated
fn check_abstract_instantiation(
  checker : TypeChecker,
  new_expr : NewExpression,
  class_symbol : Symbol,
) -> TypeChecker {
  if class_symbol.flags.is_abstract {
    add_diagnostic(
      checker,
      "Cannot create an instance of an abstract class.",
      get_node_location(NewExpression(new_expr)),
      2511,
    )
  } else {
    checker
  }
}

///|
/// Check assignment to const variable
fn check_const_assignment(
  checker : TypeChecker,
  var_name : String,
  symbol : Symbol,
  location : SourceLocation,
) -> TypeChecker {
  if symbol.flags.is_const {
    add_diagnostic(
      checker,
      "Cannot assign to '" + var_name + "' because it is a constant.",
      location,
      2588,
    )
  } else {
    checker
  }
}

///|
/// Validate function return statements
fn check_return_type_consistency(
  checker : TypeChecker,
  func : FunctionDeclaration,
  declared_return : Type,
) -> TypeChecker {
  let mut checker = checker

  // Walk the function body and check all return statements
  match func.body {
    Some(BlockStatement(block)) =>
      for stmt in block.statements {
        match stmt {
          ReturnStatement(ret) =>
            match ret.expression {
              Some(expr) => {
                let (return_type, c) = infer_type(checker, expr)
                checker = c
                if not(is_assignable(return_type, declared_return)) {
                  checker = add_diagnostic(
                    checker,
                    "Type is not assignable to the declared return type.",
                    get_node_location(expr),
                    2322,
                  )
                }
              }
              None =>
                // void return - check if compatible
                match declared_return {
                  Void(_) | Any(_) => ()
                  _ =>
                    checker = add_diagnostic(
                      checker,
                      "A function whose declared return type is not void must return a value.",
                      ret.location,
                      2355,
                    )
                }
            }
          _ => ()
        }
      }
    _ => ()
  }
  checker
}

///|
/// Infer property access type
fn infer_property_access_type(
  checker : TypeChecker,
  prop : PropertyAccessExpression,
) -> (Type, TypeChecker) {
  let (object_type, checker) = infer_type(checker, prop.expression)
  // TODO: Look up property in object type
  match object_type {
    Object(obj_type) =>
      match obj_type.properties.get(prop.name) {
        Some(property) => (property.prop_type, checker)
        None => any_type(checker)
      }
    _ => any_type(checker)
  }
}

///|
/// Infer element access type (bracket notation)
fn infer_element_access_type(
  checker : TypeChecker,
  elem : ElementAccessExpression,
) -> (Type, TypeChecker) {
  let (object_type, checker) = infer_type(checker, elem.expression)
  let (_, checker) = infer_type(checker, elem.argument_expression)
  match object_type {
    Array(arr_type) => (arr_type.element_type, checker)
    Object(_) => any_type(checker) // TODO: Better object property lookup
    _ => any_type(checker)
  }
}

///|
/// Infer new expression type (constructor call)
fn infer_new_expression_type(
  checker : TypeChecker,
  new_expr : NewExpression,
) -> (Type, TypeChecker) {
  let (expr_type, checker) = infer_type(checker, new_expr.expression)

  // Check arguments if present
  let mut checker = checker
  match new_expr.arguments {
    Some(args) =>
      for i = 0; i < args.length(); i = i + 1 {
        let (_, c) = infer_type(checker, args[i])
        checker = c
      }
    None => ()
  }

  // Return the constructed instance type
  // For a class constructor, the expression type should be the class/object type
  (expr_type, checker)
}

///|
/// Infer template expression type
fn infer_template_expression_type(
  checker : TypeChecker,
  template : TemplateExpression,
) -> (Type, TypeChecker) {
  // Check all template spans
  let mut checker = checker
  for i = 0; i < template.template_spans.length(); i = i + 1 {
    let (_, c) = infer_type(checker, template.template_spans[i].expression)
    checker = c
  }

  // Template expressions always result in strings
  string_type(checker)
}

///|
/// Infer this keyword type
fn infer_this_type(checker : TypeChecker) -> (Type, TypeChecker) {
  // TODO: Look up this type from context
  any_type(checker)
}

///|
/// Infer optional chain type (obj?.prop, func?.(), arr?.[0])
fn infer_optional_chain_type(
  checker : TypeChecker,
  oc : OptionalChain,
) -> (Type, TypeChecker) {
  // Get the type of the base expression
  let (base_type, checker) = infer_type(checker, oc.expression)
  // Optional chaining can return undefined if base is null/undefined
  // For now, return the property/call/element type or any
  let _ = base_type // Mark as used
  match oc.chain {
    OptionalChainKind::Property(_) =>
      // Property access returns any for now (should look up property type)
      any_type(checker)
    OptionalChainKind::Call(args) => {
      // Check argument types
      let mut checker = checker
      for arg in args {
        let (_, c) = infer_type(checker, arg)
        checker = c
      }
      // Call returns any for now
      any_type(checker)
    }
    OptionalChainKind::Element(index) => {
      // Check index type
      let (_, checker) = infer_type(checker, index)
      any_type(checker)
    }
  }
}

///|
/// Infer await expression type
fn infer_await_expression_type(
  checker : TypeChecker,
  ae : AwaitExpression,
) -> (Type, TypeChecker) {
  // Get the type of the awaited expression
  let (promise_type, checker) = infer_type(checker, ae.expression)
  // For now, unwrap Promise<T> to T (simplified)
  // In full implementation, check if it's actually a Promise
  match promise_type {
    TypeReference(tr) =>
      if tr.name == "Promise" && tr.type_arguments.length() > 0 {
        (tr.type_arguments[0], checker)
      } else {
        (promise_type, checker)
      }
    _ => (promise_type, checker)
  }
}

///|
/// Infer yield expression type
fn infer_yield_expression_type(
  checker : TypeChecker,
  ye : YieldExpression,
) -> (Type, TypeChecker) {
  // Get the type of the yielded expression if present
  match ye.expression {
    Some(expr) => {
      let (expr_type, checker) = infer_type(checker, expr)
      // For yield*, should iterate over the expression
      // For plain yield, return the expression type
      (expr_type, checker)
    }
    None => undefined_type(checker)
  }
}

///|
/// Infer 'as' expression type (type assertion)
fn infer_as_expression_type(
  checker : TypeChecker,
  as_expr : AsExpression,
) -> (Type, TypeChecker) {
  // Check the expression first
  let (_, checker) = infer_type(checker, as_expr.expression)
  // Return the asserted type
  let (type_opt, checker) = get_type_from_type_node(checker, as_expr.type_node)
  match type_opt {
    Some(t) => (t, checker)
    None => any_type(checker)
  }
}

///|
/// Infer non-null expression type
fn infer_non_null_expression_type(
  checker : TypeChecker,
  nne : NonNullExpression,
) -> (Type, TypeChecker) {
  // Get the type of the expression and remove null/undefined
  let (expr_type, checker) = infer_type(checker, nne.expression)
  // For now, just return the expression type
  // In full implementation, remove null/undefined from union
  (expr_type, checker)
}

///|
/// Infer type assertion expression type
fn infer_type_assertion_type(
  checker : TypeChecker,
  tae : TypeAssertionExpression,
) -> (Type, TypeChecker) {
  // Check the expression first
  let (_, checker) = infer_type(checker, tae.expression)
  // Return the asserted type
  let (type_opt, checker) = get_type_from_type_node(checker, tae.type_node)
  match type_opt {
    Some(t) => (t, checker)
    None => any_type(checker)
  }
}

///|
/// Infer function expression type
fn infer_function_expression_type(
  checker : TypeChecker,
  fe : FunctionExpression,
) -> (Type, TypeChecker) {
  // Build a function type from the function expression
  let params : Array[CheckerParameter] = []
  let mut checker = checker
  for param_node in fe.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c) = match p.type_annotation {
          Some(type_node) => {
            let (type_opt, c) = get_type_from_type_node(checker, type_node)
            match type_opt {
              Some(t) => (t, c)
              None => any_type(c)
            }
          }
          None => any_type(checker)
        }
        checker = c
        params.push({
          name: match p.name {
            Identifier(id) => id.name
            _ => ""
          },
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }
  let (return_type, checker) = match fe.return_type {
    Some(type_node) => {
      let (type_opt, c) = get_type_from_type_node(checker, type_node)
      match type_opt {
        Some(t) => (t, c)
        None => any_type(c)
      }
    }
    None => any_type(checker)
  }
  let (info, checker) = create_type_info(checker)
  (Function({ parameters: params, return_type, info }), checker)
}

///|
/// Infer array literal type
fn infer_array_literal_type(
  checker : TypeChecker,
  arr : ArrayLiteralExpression,
) -> (Type, TypeChecker) {
  // Infer element types and create union
  let mut checker = checker
  let element_types = []
  for i = 0; i < arr.elements.length(); i = i + 1 {
    match arr.elements[i] {
      Some(elem) => {
        let (elem_type, c) = infer_type(checker, elem)
        element_types.push(elem_type)
        checker = c
      }
      None => ()
    }
  }

  // Create array type
  let (elem_union, checker) = if element_types.is_empty() {
    any_type(checker)
  } else if element_types.length() == 1 {
    (element_types[0], checker)
  } else {
    let (info, checker) = create_type_info(checker)
    (Union({ types: element_types, info }), checker)
  }
  let (info, checker) = create_type_info(checker)
  (Array({ element_type: elem_union, info }), checker)
}

///|
/// Infer object literal type
fn infer_object_literal_type(
  checker : TypeChecker,
  obj : ObjectLiteralExpression,
) -> (Type, TypeChecker) {
  let mut checker = checker
  let properties = Map::new()
  for i = 0; i < obj.properties.length(); i = i + 1 {
    match obj.properties[i] {
      PropertyAssignment(name, value, _) => {
        let (prop_type, c) = infer_type(checker, value)
        properties.set(name, {
          name,
          prop_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      ComputedPropertyAssignment(name_expr, value, _) => {
        // For computed properties, we infer the types but use a dynamic key
        let (_, c) = infer_type(checker, name_expr)
        let (prop_type, c) = infer_type(c, value)
        // Use a computed key placeholder - actual key depends on runtime value
        let key = "[computed]"
        properties.set(key, {
          name: key,
          prop_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      _ => ()
    }
  }
  let (info, checker) = create_type_info(checker)
  (
    Object({
      properties,
      call_signatures: [],
      construct_signatures: [],
      index_signatures: [],
      info,
    }),
    checker,
  )
}

///|
/// Infer arrow function type
fn infer_arrow_function_type(
  checker : TypeChecker,
  arrow : ArrowFunction,
) -> (Type, TypeChecker) {
  // Build parameter list
  let parameters = []
  let mut checker = checker
  for i = 0; i < arrow.parameters.length(); i = i + 1 {
    match arrow.parameters[i] {
      Parameter(param) => {
        let (param_type, c) = match param.type_annotation {
          Some(type_node) =>
            match get_type_from_type_node(checker, type_node) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
          None => any_type(checker)
        }
        checker = c
        parameters.push({
          name: get_parameter_name(param.name),
          param_type,
          is_optional: param.is_optional,
          is_rest: param.is_rest,
        })
      }
      _ => ()
    }
  }

  // Get return type
  let (return_type, checker) = match arrow.return_type {
    Some(type_node) =>
      match get_type_from_type_node(checker, type_node) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    None => {
      // Infer from body
      let (t, c) = infer_type(checker, arrow.body)
      (t, c)
    }
  }
  let (info, checker) = create_type_info(checker)
  (Function({ parameters, return_type, info }), checker)
}

///|
/// Infer conditional expression type
fn infer_conditional_type(
  checker : TypeChecker,
  cond : ConditionalExpression,
) -> (Type, TypeChecker) {
  let (condition_type, checker) = infer_type(checker, cond.condition)
  let (then_type, checker) = infer_type(checker, cond.when_true)
  let (else_type, checker) = infer_type(checker, cond.when_false)

  // Return union of then and else types
  let (info, checker) = create_type_info(checker)
  (Union({ types: [then_type, else_type], info }), checker)
}

// ============================================================================
// Type Compatibility Checking
// ============================================================================

///|
/// Check if source type is assignable to target type
fn is_assignable(source : Type, target : Type) -> Bool {
  match (source, target) {
    // Any type is assignable to/from anything
    (Any(_), _) => true
    (_, Any(_)) => true
    // Never is assignable to everything
    (Never(_), _) => true
    // Nothing is assignable to never (except never) - handled by the above case
    // Unknown is only assignable to unknown or any (any handled above)
    (Unknown(_), Unknown(_)) => true
    // Any type is assignable to unknown (unknown is a safe top type)
    (_, Unknown(_)) => true
    // Nothing (except any/never/unknown) is assignable to never
    (_, Never(_)) => false
    // Same primitive types
    (Number(_), Number(_)) => true
    (String(_), String(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Void(_), Void(_)) => true
    (Undefined(_), Undefined(_)) => true
    (Null(_), Null(_)) => true
    (Symbol(_), Symbol(_)) => true
    // Undefined and null are assignable to most types (like TypeScript without strictNullChecks)
    (Undefined(_), Void(_)) => true
    (Undefined(_), Number(_)) => true
    (Undefined(_), String(_)) => true
    (Undefined(_), Boolean(_)) => true
    (Undefined(_), Object(_)) => true
    (Undefined(_), Array(_)) => true
    (Undefined(_), Function(_)) => true
    (Null(_), Number(_)) => true
    (Null(_), String(_)) => true
    (Null(_), Boolean(_)) => true
    (Null(_), Object(_)) => true
    (Null(_), Array(_)) => true
    (Null(_), Function(_)) => true
    // Literal types are assignable to their base types
    (NumberLiteral(_, _), Number(_)) => true
    (StringLiteral(_, _), String(_)) => true
    (BooleanLiteral(_, _), Boolean(_)) => true
    // Same literal types (exact value match)
    (NumberLiteral(v1, _), NumberLiteral(v2, _)) => v1 == v2
    (StringLiteral(v1, _), StringLiteral(v2, _)) => v1 == v2
    (BooleanLiteral(v1, _), BooleanLiteral(v2, _)) => v1 == v2
    // String literal assignable to template literal if it matches
    (StringLiteral(value, _), TemplateLiteral(template)) =>
      matches_template_literal(value, template)
    // Type references - check by name (simplified)
    (TypeReference(ref1), TypeReference(ref2)) =>
      is_type_reference_assignable(ref1, ref2)
    // Union type assignability - source is assignable to union if assignable to any member
    (source, Union(union)) => is_assignable_to_union(source, union)
    // Union source is assignable to target if all members are assignable
    (Union(union), target) => is_union_assignable_to(union, target)
    // Array types
    (Array(source_arr), Array(target_arr)) =>
      is_assignable(source_arr.element_type, target_arr.element_type)
    // Object types - structural typing
    (Object(source_obj), Object(target_obj)) =>
      is_object_assignable(source_obj, target_obj)
    // Function types - check parameter and return types
    (Function(source_fn), Function(target_fn)) =>
      is_function_assignable(source_fn, target_fn)
    // Intersection type assignability - source must be assignable to ALL members
    (source, Intersection(intersection)) =>
      is_assignable_to_intersection(source, intersection)
    // Intersection source is assignable if merged type is assignable
    (Intersection(intersection), target) =>
      is_intersection_assignable_to(intersection, target)
    // Tuple types
    (Tuple(source_tuple), Tuple(target_tuple)) =>
      is_tuple_assignable(source_tuple, target_tuple)
    // Tuple is assignable to array if all elements are assignable to element type
    (Tuple(source_tuple), Array(target_arr)) =>
      is_tuple_assignable_to_array(source_tuple, target_arr)
    // Array is assignable to tuple if length matches and elements are compatible
    (Array(source_arr), Tuple(target_tuple)) =>
      is_array_assignable_to_tuple(source_arr, target_tuple)
    // Index access types - need resolution
    (IndexAccess(ia1), IndexAccess(ia2)) =>
      is_assignable(ia1.object_type, ia2.object_type) &&
      is_assignable(ia1.index_type, ia2.index_type)
    // Conditional types - compare structure
    (Conditional(c1), Conditional(c2)) => is_conditional_assignable(c1, c2)
    // Mapped types
    (Mapped(m1), Mapped(m2)) => is_mapped_assignable(m1, m2)
    // Template literal types
    (TemplateLiteral(t1), TemplateLiteral(t2)) =>
      is_template_literal_assignable(t1, t2)
    // Template literal is assignable to string
    (TemplateLiteral(_), String(_)) => true
    // Infer types - they're placeholders, typically handled during inference
    (Infer(_), _) => true
    (_, Infer(_)) => true
    // Error type assignable to anything (to prevent cascading errors)
    (Error(_), _) => true
    (_, Error(_)) => true
    _ => false
  }
}

///|
/// Check if type reference is assignable
fn is_type_reference_assignable(
  source : TypeReferenceType,
  target : TypeReferenceType,
) -> Bool {
  // Same type name required
  if source.name != target.name {
    return false
  }
  // Check type arguments
  if source.type_arguments.length() != target.type_arguments.length() {
    return false
  }
  for i = 0; i < source.type_arguments.length(); i = i + 1 {
    if not(is_assignable(source.type_arguments[i], target.type_arguments[i])) {
      return false
    }
  }
  true
}

///|
/// Check if array is assignable to tuple
fn is_array_assignable_to_tuple(
  arr : CheckerArrayType,
  tuple : CheckerTupleType,
) -> Bool {
  // Array can be assigned to tuple if all tuple elements accept the array element type
  for i = 0; i < tuple.element_types.length(); i = i + 1 {
    let elem = tuple.element_types[i]
    if not(elem.is_optional) && not(elem.is_rest) {
      // Required element - check if array element type is compatible
      if not(is_assignable(arr.element_type, elem.element_type)) {
        return false
      }
    }
  }
  true
}

///|
/// Check if conditional types are assignable
fn is_conditional_assignable(
  source : CheckerConditionalType,
  target : CheckerConditionalType,
) -> Bool {
  // Simplified: same structure check
  is_assignable(source.check_type, target.check_type) &&
  is_assignable(source.extends_type, target.extends_type) &&
  is_assignable(source.true_type, target.true_type) &&
  is_assignable(source.false_type, target.false_type)
}

///|
/// Check if mapped types are assignable
fn is_mapped_assignable(
  source : CheckerMappedType,
  target : CheckerMappedType,
) -> Bool {
  // Simplified: check template types
  is_assignable(source.template_type, target.template_type)
}

///|
/// Check if template literal types are assignable
fn is_template_literal_assignable(
  source : CheckerTemplateLiteralType,
  target : CheckerTemplateLiteralType,
) -> Bool {
  // Simplified: check if static parts match
  if source.texts.length() != target.texts.length() {
    return false
  }
  for i = 0; i < source.texts.length(); i = i + 1 {
    if source.texts[i] != target.texts[i] {
      return false
    }
  }
  // Check interpolated types
  if source.types.length() != target.types.length() {
    return false
  }
  for i = 0; i < source.types.length(); i = i + 1 {
    if not(is_assignable(source.types[i], target.types[i])) {
      return false
    }
  }
  true
}

///|
/// Check if source is assignable to intersection type
fn is_assignable_to_intersection(
  source : Type,
  intersection : CheckerIntersectionType,
) -> Bool {
  // Source must be assignable to ALL members of the intersection
  for i = 0; i < intersection.types.length(); i = i + 1 {
    if !is_assignable(source, intersection.types[i]) {
      return false
    }
  }
  true
}

///|
/// Check if intersection is assignable to target
fn is_intersection_assignable_to(
  intersection : CheckerIntersectionType,
  target : Type,
) -> Bool {
  // At least one member must be assignable to target
  for i = 0; i < intersection.types.length(); i = i + 1 {
    if is_assignable(intersection.types[i], target) {
      return true
    }
  }
  false
}

///|
/// Check if source tuple is assignable to target tuple
fn is_tuple_assignable(
  source : CheckerTupleType,
  target : CheckerTupleType,
) -> Bool {
  // Count required elements in target
  let mut target_required = 0
  for i = 0; i < target.element_types.length(); i = i + 1 {
    if !target.element_types[i].is_optional && !target.element_types[i].is_rest {
      target_required = target_required + 1
    }
  }

  // Source must have at least as many elements as target required
  if source.element_types.length() < target_required {
    return false
  }

  // Check element-wise assignability
  for i = 0; i < target.element_types.length(); i = i + 1 {
    if i < source.element_types.length() {
      if !is_assignable(
          source.element_types[i].element_type,
          target.element_types[i].element_type,
        ) {
        return false
      }
    } else if !target.element_types[i].is_optional {
      return false
    }
  }
  true
}

///|
/// Check if tuple is assignable to array
fn is_tuple_assignable_to_array(
  tuple : CheckerTupleType,
  arr : CheckerArrayType,
) -> Bool {
  // All tuple elements must be assignable to array element type
  for i = 0; i < tuple.element_types.length(); i = i + 1 {
    if !is_assignable(tuple.element_types[i].element_type, arr.element_type) {
      return false
    }
  }
  true
}

///|
/// Check if source is assignable to union type
fn is_assignable_to_union(source : Type, union : CheckerUnionType) -> Bool {
  let mut assignable = false
  for i = 0; i < union.types.length(); i = i + 1 {
    if is_assignable(source, union.types[i]) {
      assignable = true
      break
    }
  }
  assignable
}

///|
/// Check if union is assignable to target
fn is_union_assignable_to(union : CheckerUnionType, target : Type) -> Bool {
  let mut all_assignable = true
  for i = 0; i < union.types.length(); i = i + 1 {
    if !is_assignable(union.types[i], target) {
      all_assignable = false
      break
    }
  }
  all_assignable
}

///|
/// Check if source object is assignable to target object (structural typing)
fn is_object_assignable(source : ObjectType, target : ObjectType) -> Bool {
  // Check that all required properties in target exist in source
  let target_props = target.properties.iter()
  let mut assignable = true
  for entry in target_props {
    let (prop_name, target_prop) = entry
    match source.properties.get(prop_name) {
      Some(source_prop) =>
        if !is_assignable(source_prop.prop_type, target_prop.prop_type) {
          assignable = false
          break
        }
      None =>
        if !target_prop.is_optional {
          assignable = false
          break
        }
    }
  }
  assignable
}

///|
/// Check if source function is assignable to target function
fn is_function_assignable(
  source : CheckerFunctionType,
  target : CheckerFunctionType,
) -> Bool {
  // Return type must be assignable
  if !is_assignable(source.return_type, target.return_type) {
    return false
  }

  // Parameters are contravariant - target params must be assignable to source
  if source.parameters.length() < target.parameters.length() {
    return false
  }
  let mut assignable = true
  for i = 0; i < target.parameters.length(); i = i + 1 {
    if !is_assignable(
        target.parameters[i].param_type,
        source.parameters[i].param_type,
      ) {
      assignable = false
      break
    }
  }
  assignable
}

///|
/// Check assignment compatibility
fn check_assignment_compatibility(
  checker : TypeChecker,
  source : Type,
  target : Type,
  location : SourceLocation,
) -> TypeChecker {
  if is_assignable(source, target) {
    checker
  } else {
    add_diagnostic(
      checker,
      "Type '\{type_to_string(source)}' is not assignable to type '\{type_to_string(target)}'",
      location,
      2322,
    )
  }
}

///|
/// Check numeric operands
fn check_numeric_operands(
  checker : TypeChecker,
  left : Type,
  right : Type,
  operator : BinaryOperator,
  location : SourceLocation,
) -> TypeChecker {
  let checker = if !is_numeric_type(left) {
    add_diagnostic(
      checker, "Left operand must be of type 'number'", location, 2363,
    )
  } else {
    checker
  }
  if !is_numeric_type(right) {
    add_diagnostic(
      checker, "Right operand must be of type 'number'", location, 2363,
    )
  } else {
    checker
  }
}

///|
/// Check single numeric operand
fn check_numeric_operand(
  checker : TypeChecker,
  operand : Type,
  operator : UnaryOperator,
  location : SourceLocation,
) -> TypeChecker {
  if !is_numeric_type(operand) {
    add_diagnostic(checker, "Operand must be of type 'number'", location, 2363)
  } else {
    checker
  }
}

///|
/// Check boolean operands
fn check_boolean_operands(
  checker : TypeChecker,
  left : Type,
  right : Type,
  operator : BinaryOperator,
  location : SourceLocation,
) -> TypeChecker {
  // Note: In TypeScript, any type can be used in boolean context
  // This is a simplified check
  checker
}

///|
/// Check if type is numeric
fn is_numeric_type(t : Type) -> Bool {
  match t {
    Number(_) => true
    NumberLiteral(_, _) => true
    Any(_) => true
    _ => false
  }
}

// ============================================================================
// Function Declaration Checking
// ============================================================================

///|
/// Check function declaration
fn check_function_declaration(
  checker : TypeChecker,
  func : FunctionDeclaration,
) -> TypeChecker {
  // Check function body
  let checker = match func.body {
    Some(body) => check_statement(checker, body)
    None => checker
  }
  checker
}

// ============================================================================
// Other Statement Checking
// ============================================================================

///|
/// Check return statement
fn check_return_statement(
  checker : TypeChecker,
  ret : ReturnStatement,
) -> TypeChecker {
  match ret.expression {
    Some(expr) => {
      let (_, checker) = infer_type(checker, expr)
      checker
    }
    None => checker
  }
}

///|
/// Check if statement with type narrowing support
fn check_if_statement(
  checker : TypeChecker,
  if_stmt : IfStatement,
) -> TypeChecker {
  // Infer the condition type
  let (_, checker) = infer_type(checker, if_stmt.condition)

  // Save current narrowed types before entering branches
  let saved_narrowed_types = checker.narrowed_types

  // Try to extract type guard information from the condition
  let type_guard = get_type_guard_info(checker, if_stmt.condition)

  // Check then branch with narrowed types (if type guard found)
  let then_checker = match type_guard {
    Some(tg_info) => apply_narrowing_to_checker(checker, tg_info, true)
    None => checker
  }
  let then_checker = check_statement(then_checker, if_stmt.then_statement)

  // Check else branch with opposite narrowing (if type guard found)
  let final_checker = match if_stmt.else_statement {
    Some(else_stmt) => {
      let else_checker = match type_guard {
        Some(tg_info) => apply_narrowing_to_checker(checker, tg_info, false)
        None => checker
      }
      check_statement(else_checker, else_stmt)
    }
    None => then_checker
  }

  // Restore narrowed types after exiting branches (simplified: just restore saved state)
  { ..final_checker, narrowed_types: saved_narrowed_types }
}

///|
/// Check while statement
fn check_while_statement(
  checker : TypeChecker,
  while_stmt : WhileStatement,
) -> TypeChecker {
  let (_, checker) = infer_type(checker, while_stmt.condition)
  check_statement(checker, while_stmt.statement)
}

///|
/// Check do-while statement
fn check_do_while_statement(
  checker : TypeChecker,
  do_while : DoWhileStatement,
) -> TypeChecker {
  let checker = check_statement(checker, do_while.statement)
  let (_, checker) = infer_type(checker, do_while.condition)
  checker
}

///|
/// Check for statement
fn check_for_statement(
  checker : TypeChecker,
  for_stmt : ForStatement,
) -> TypeChecker {
  // Check initializer
  let checker = match for_stmt.initializer {
    Some(VariableStatement(var_stmt)) =>
      check_variable_statement(checker, var_stmt)
    Some(expr) => {
      let (_, c) = infer_type(checker, expr)
      c
    }
    None => checker
  }

  // Check condition
  let checker = match for_stmt.condition {
    Some(cond) => {
      let (_, c) = infer_type(checker, cond)
      c
    }
    None => checker
  }

  // Check incrementor
  let checker = match for_stmt.incrementor {
    Some(inc) => {
      let (_, c) = infer_type(checker, inc)
      c
    }
    None => checker
  }

  // Check body
  check_statement(checker, for_stmt.statement)
}

///|
/// Check block statement
fn check_block_statement(
  checker : TypeChecker,
  block : BlockStatement,
) -> TypeChecker {
  check_statements(checker, block.statements)
}

///|
/// Check class declaration
fn check_class_declaration(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
) -> TypeChecker {
  // Check class members (constructors, methods, properties)
  let mut checker = checker
  for i = 0; i < class_decl.members.length(); i = i + 1 {
    checker = match class_decl.members[i] {
      ConstructorDeclaration(ctor) =>
        match ctor.body {
          Some(body) => check_statement(checker, body)
          None => checker
        }
      MethodDeclaration(method_dec) =>
        match method_dec.body {
          Some(body) => check_statement(checker, body)
          None => checker
        }
      PropertyDeclaration(prop) =>
        match prop.initializer {
          Some(init) => {
            let (_, c) = infer_type(checker, init)
            c
          }
          None => checker
        }
      _ => checker
    }
  }
  checker
}

///|
/// Check enum declaration
fn check_enum_declaration(
  checker : TypeChecker,
  enum_decl : EnumDeclaration,
) -> TypeChecker {
  // TODO: Check enum members
  checker
}

///|
/// Check try statement
fn check_try_statement(
  checker : TypeChecker,
  try_stmt : TryStatement,
) -> TypeChecker {
  let checker = check_statement(checker, try_stmt.try_block)
  let checker = match try_stmt.catch_clause {
    Some(catch_clause) => check_statement(checker, catch_clause.block)
    None => checker
  }
  match try_stmt.finally_block {
    Some(finally_block) => check_statement(checker, finally_block)
    None => checker
  }
}

///|
/// Check throw statement
fn check_throw_statement(
  checker : TypeChecker,
  throw_stmt : ThrowStatement,
) -> TypeChecker {
  let (_, checker) = infer_type(checker, throw_stmt.expression)
  checker
}

///|
/// Check switch statement
fn check_switch_statement(
  checker : TypeChecker,
  switch_stmt : SwitchStatement,
) -> TypeChecker {
  let (_, checker) = infer_type(checker, switch_stmt.expression)
  let mut checker = checker
  for i = 0; i < switch_stmt.cases.length(); i = i + 1 {
    let case_clause = switch_stmt.cases[i]
    match case_clause.expression {
      Some(case_expr) => {
        let (_, c) = infer_type(checker, case_expr)
        checker = check_statements(c, case_clause.statements)
      }
      None =>
        // Default case
        checker = check_statements(checker, case_clause.statements)
    }
  }
  checker
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
/// Get type from type node
fn get_type_from_type_node(
  checker : TypeChecker,
  type_node : Node,
) -> (Type?, TypeChecker) {
  match type_node {
    // Handle keyword types (from parser)
    KeywordType(kw_type) =>
      match kw_type.kind {
        Number => {
          let (t, c) = number_type(checker)
          (Some(t), c)
        }
        String => {
          let (t, c) = string_type(checker)
          (Some(t), c)
        }
        Boolean => {
          let (t, c) = boolean_type(checker)
          (Some(t), c)
        }
        Void => {
          let (t, c) = void_type(checker)
          (Some(t), c)
        }
        Any => {
          let (t, c) = any_type(checker)
          (Some(t), c)
        }
        Unknown => {
          let (t, c) = unknown_type(checker)
          (Some(t), c)
        }
        Never => {
          let (t, c) = never_type(checker)
          (Some(t), c)
        }
        Null => {
          let (t, c) = null_type(checker)
          (Some(t), c)
        }
        Undefined => {
          let (t, c) = undefined_type(checker)
          (Some(t), c)
        }
        Symbol => {
          let (t, c) = symbol_type(checker)
          (Some(t), c)
        }
        Object => {
          // For the object keyword type, create an empty object type
          let (info, c) = create_type_info(checker)
          (
            Some(
              Object({
                properties: Map::new(),
                call_signatures: [],
                construct_signatures: [],
                index_signatures: [],
                info,
              }),
            ),
            c,
          )
        }
        Const => {
          // "as const" assertion - returns any for now (full support would make expressions readonly)
          let (t, c) = any_type(checker)
          (Some(t), c)
        }
      }
    UnionType(union_type) => {
      // Handle union types
      let mut checker = checker
      let types = []
      for i = 0; i < union_type.types.length(); i = i + 1 {
        match get_type_from_type_node(checker, union_type.types[i]) {
          (Some(t), c) => {
            types.push(t)
            checker = c
          }
          (None, c) => checker = c
        }
      }
      let (info, checker) = create_type_info(checker)
      (Some(Union({ types, info })), checker)
    }
    TypeReference(type_ref) =>
      // Look up type reference
      match type_ref.type_name {
        "number" => {
          let (t, c) = number_type(checker)
          (Some(t), c)
        }
        "string" => {
          let (t, c) = string_type(checker)
          (Some(t), c)
        }
        "boolean" => {
          let (t, c) = boolean_type(checker)
          (Some(t), c)
        }
        "void" => {
          let (t, c) = void_type(checker)
          (Some(t), c)
        }
        "any" => {
          let (t, c) = any_type(checker)
          (Some(t), c)
        }
        "unknown" => {
          let (t, c) = unknown_type(checker)
          (Some(t), c)
        }
        "never" => {
          let (t, c) = never_type(checker)
          (Some(t), c)
        }
        "undefined" => {
          let (t, c) = undefined_type(checker)
          (Some(t), c)
        }
        _ =>
          // Try to look up the type name in the symbol table (for interfaces, classes, etc.)
          match lookup_symbol(checker, type_ref.type_name) {
            Some(symbol) =>
              match symbol.kind {
                Interface =>
                  // Resolve interface to an Object type with its properties
                  match resolve_interface_type(checker, symbol) {
                    (Some(t), c) => (Some(t), c)
                    (None, c) => (None, c)
                  }
                _ => (None, checker) // Other symbol kinds not yet supported
              }
            None => (None, checker)
          }
      }
    ArrayType(array_type) =>
      // Handle array types
      match get_type_from_type_node(checker, array_type.element_type) {
        (Some(element_type), c) => {
          let (info, c2) = create_type_info(c)
          (Some(Array({ element_type, info })), c2)
        }
        (None, c) => (None, c)
      }
    MappedType(mapped) => {
      // Convert AST MappedType to checker MappedType
      // First, convert the type parameter
      let mut checker = checker

      // Get constraint type if present
      let (constraint, c) = match mapped.type_parameter.constraint {
        Some(constraint_node) =>
          match get_type_from_type_node(checker, constraint_node) {
            (Some(t), c2) => (Some(t), c2)
            (None, c2) => (None, c2)
          }
        None => (None, checker)
      }
      checker = c

      // Get default type if present
      let (default_type, c) = match mapped.type_parameter.default {
        Some(default_node) =>
          match get_type_from_type_node(checker, default_node) {
            (Some(t), c2) => (Some(t), c2)
            (None, c2) => (None, c2)
          }
        None => (None, checker)
      }
      checker = c

      // Create CheckerTypeParameter
      let type_param : CheckerTypeParameter = {
        name: mapped.type_parameter.name,
        constraint,
        default_type,
      }

      // Get template type
      let (template_type, c) = match mapped.type_node {
        Some(type_node) =>
          match get_type_from_type_node(checker, type_node) {
            (Some(t), c2) => (t, c2)
            (None, c2) => {
              let (t, c3) = any_type(c2)
              (t, c3)
            }
          }
        None => any_type(checker)
      }
      checker = c

      // Convert AST modifiers to checker modifiers
      let readonly_mod = convert_mapped_modifier(mapped.readonly_modifier)
      let optional_mod = convert_mapped_modifier(mapped.optional_modifier)

      // Create the mapped type
      let (t, c) = mapped_type(
        checker,
        type_param,
        None,
        template_type,
        readonly_mod,
        optional_mod,
      )
      (Some(t), c)
    }
    _ => (None, checker)
  }
}

///|
/// Convert AST MappedTypeModifier to checker MappedModifier
fn convert_mapped_modifier(ast_mod : MappedTypeModifier) -> MappedModifier {
  match ast_mod {
    Unchanged => MappedModifier::Unchanged
    Plus => MappedModifier::Add
    Minus => MappedModifier::Remove
  }
}

///|
/// Add a diagnostic
fn add_diagnostic(
  checker : TypeChecker,
  message : String,
  location : SourceLocation,
  code : Int,
) -> TypeChecker {
  let diag = Diagnostic::error(message, location, code)
  let new_diagnostics = checker.diagnostics
  new_diagnostics.push(diag)
  { ..checker, diagnostics: new_diagnostics }
}

///|
/// Get node location (simplified - returns dummy location for now)
fn get_node_location(node : Node) -> SourceLocation {
  // TODO: Extract actual location from node
  {
    file_path: "",
    start: { line: 0, column: 0, offset: 0 },
    end: { line: 0, column: 0, offset: 0 },
  }
}

///|
/// Get property name from node
fn get_property_name(node : Node) -> String {
  match node {
    Identifier(id) => id.name
    StringLiteral(s) => s.value
    _ => ""
  }
}

///|
/// Get parameter name
fn get_parameter_name(param_name : Node) -> String {
  match param_name {
    Identifier(id) => id.name
    _ => ""
  }
}

///|
/// Convert type to string (for error messages)
fn type_to_string(t : Type) -> String {
  match t {
    Number(_) => "number"
    String(_) => "string"
    Boolean(_) => "boolean"
    Void(_) => "void"
    Undefined(_) => "undefined"
    Null(_) => "null"
    Symbol(_) => "symbol"
    Any(_) => "any"
    Unknown(_) => "unknown"
    Never(_) => "never"
    NumberLiteral(n, _) => n.to_string()
    StringLiteral(s, _) => "'\{s}'"
    BooleanLiteral(b, _) => if b { "true" } else { "false" }
    Array(arr) => "\{type_to_string(arr.element_type)}[]"
    Union(u) => {
      let mut result = ""
      for i = 0; i < u.types.length(); i = i + 1 {
        if i > 0 {
          result = result + " | "
        }
        result = result + type_to_string(u.types[i])
      }
      result
    }
    Intersection(inter) => {
      let mut result = ""
      for i = 0; i < inter.types.length(); i = i + 1 {
        if i > 0 {
          result = result + " & "
        }
        result = result + type_to_string(inter.types[i])
      }
      result
    }
    Tuple(tuple) => {
      let mut result = "["
      for i = 0; i < tuple.element_types.length(); i = i + 1 {
        if i > 0 {
          result = result + ", "
        }
        let elem = tuple.element_types[i]
        match elem.label {
          Some(label) => result = result + label + ": "
          None => ()
        }
        result = result + type_to_string(elem.element_type)
        if elem.is_optional {
          result = result + "?"
        }
      }
      result + "]"
    }
    Conditional(cond) =>
      "\{type_to_string(cond.check_type)} extends \{type_to_string(cond.extends_type)} ? \{type_to_string(cond.true_type)} : \{type_to_string(cond.false_type)}"
    Mapped(_) => "{ [K in ...]: ... }"
    TemplateLiteral(_) => "`...`"
    IndexAccess(ia) =>
      "\{type_to_string(ia.object_type)}[\{type_to_string(ia.index_type)}]"
    Infer(inf) => "infer \{inf.type_parameter_name}"
    Function(_) => "function"
    Object(_) => "object"
    TypeReference(ref) => ref.name
    Error(_) => "error"
  }
}

///|
/// Look up a symbol by name in the global scope
fn lookup_symbol(checker : TypeChecker, name : String) -> Symbol? {
  match checker.global_scope {
    Some(scope) => scope.symbols.get(name)
    None => None
  }
}

///|
/// Resolve an interface symbol to an Object type with its property types
fn resolve_interface_type(
  checker : TypeChecker,
  interface_symbol : Symbol,
) -> (Type?, TypeChecker) {
  // Get the interface declaration from the symbol
  match interface_symbol.value_declaration {
    Some(InterfaceDeclaration(interface_decl)) => {
      // Build property map from interface members
      let properties : Map[String, PropertySignature] = Map::new()
      let index_signatures : Array[IndexSignature] = []
      let mut checker = checker
      for i = 0; i < interface_decl.members.length(); i = i + 1 {
        match interface_decl.members[i] {
          PropertyDeclaration(prop) => {
            // Get the property type
            let (prop_type, c) = match prop.type_annotation {
              Some(type_node) =>
                match get_type_from_type_node(checker, type_node) {
                  (Some(t), c2) => (t, c2)
                  (None, c2) => {
                    let (t, c3) = any_type(c2)
                    (t, c3)
                  }
                }
              None => any_type(checker)
            }
            checker = c
            properties.set(prop.name, {
              name: prop.name,
              prop_type,
              is_optional: false,
              is_readonly: false,
            })
          }
          IndexSignatureDeclaration(idx_sig) => {
            // Get the parameter type (key type)
            let (param_type, c) = match
              get_type_from_type_node(checker, idx_sig.parameter_type) {
              (Some(t), c2) => (t, c2)
              (None, c2) => {
                let (t, c3) = any_type(c2)
                (t, c3)
              }
            }
            checker = c
            // Get the return type (value type)
            let (ret_type, c) = match
              get_type_from_type_node(checker, idx_sig.return_type) {
              (Some(t), c2) => (t, c2)
              (None, c2) => {
                let (t, c3) = any_type(c2)
                (t, c3)
              }
            }
            checker = c
            index_signatures.push({
              parameter_name: idx_sig.parameter_name,
              parameter_type: param_type,
              return_type: ret_type,
              is_readonly: idx_sig.is_readonly,
            })
          }
          _ => () // Skip other member types
        }
      }
      let (info, checker) = create_type_info(checker)
      (
        Some(
          Object({
            properties,
            call_signatures: [],
            construct_signatures: [],
            index_signatures,
            info,
          }),
        ),
        checker,
      )
    }
    _ => (None, checker)
  }
}
