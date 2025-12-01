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
  class_name : String? // For class instances, the name of the class they came from
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
  local_scopes : Array[LocalScope] // Stack of local scopes (innermost last)
  current_this_type : Type? // Type of 'this' in current scope (for class methods/constructors)
  no_unchecked_indexed_access : Bool // Adds undefined to indexed access types
  resolving_symbols : Map[Int, Bool] // Symbol IDs currently being resolved (for cycle detection)
  arrow_function_depth : Int // Tracks nesting depth in arrow functions (> 0 means inside arrow)
  async_function_depth : Int // Tracks nesting depth in async functions (> 0 means inside async)
  block_scoped_decls : Map[String, Int] // Variable name -> declaration line (for TS2448 TDZ check)
} derive(Show)

///|
/// Local scope for tracking variable types in function bodies
pub struct LocalScope {
  variables : Map[String, Type] // Variable name -> Type
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
  TypeChecker::new_with_options(file_path, global_scope, false)
}

///|
/// Create a new type checker with options
pub fn TypeChecker::new_with_options(
  file_path : String,
  global_scope : Scope?,
  no_unchecked_indexed_access : Bool,
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
    local_scopes: [],
    current_this_type: None,
    no_unchecked_indexed_access,
    resolving_symbols: Map::new(),
    arrow_function_depth: 0,
    async_function_depth: 0,
    block_scoped_decls: Map::new(),
  }
}

///|
/// Get next type ID
fn next_type_id(checker : TypeChecker) -> (Int, TypeChecker) {
  let id = checker.next_type_id
  (id, { ..checker, next_type_id: id + 1 })
}

///|
/// Push a new local scope onto the scope stack
fn push_local_scope(checker : TypeChecker) -> TypeChecker {
  let scopes = checker.local_scopes
  scopes.push(LocalScope::{ variables: Map::new() })
  { ..checker, local_scopes: scopes }
}

///|
/// Pop the current local scope from the scope stack
fn pop_local_scope(checker : TypeChecker) -> TypeChecker {
  let scopes = checker.local_scopes
  if scopes.length() > 0 {
    let _ = scopes.pop()
  }
  { ..checker, local_scopes: scopes }
}

///|
/// Enter arrow function context (increment depth)
fn enter_arrow_function(checker : TypeChecker) -> TypeChecker {
  { ..checker, arrow_function_depth: checker.arrow_function_depth + 1 }
}

///|
/// Exit arrow function context (decrement depth)
fn exit_arrow_function(checker : TypeChecker) -> TypeChecker {
  { ..checker, arrow_function_depth: checker.arrow_function_depth - 1 }
}

///|
/// Check if currently inside an arrow function
fn is_in_arrow_function(checker : TypeChecker) -> Bool {
  checker.arrow_function_depth > 0
}

///|
/// Enter async function context (increment depth)
fn enter_async_function(checker : TypeChecker) -> TypeChecker {
  { ..checker, async_function_depth: checker.async_function_depth + 1 }
}

///|
/// Exit async function context (decrement depth)
fn exit_async_function(checker : TypeChecker) -> TypeChecker {
  { ..checker, async_function_depth: checker.async_function_depth - 1 }
}

///|
/// Check if currently inside an async function
fn is_in_async_function(checker : TypeChecker) -> Bool {
  checker.async_function_depth > 0
}

///|
/// Add a variable to the current local scope
fn add_local_variable(
  checker : TypeChecker,
  name : String,
  var_type : Type,
) -> TypeChecker {
  let scopes = checker.local_scopes
  if scopes.length() > 0 {
    scopes[scopes.length() - 1].variables.set(name, var_type)
  }
  { ..checker, local_scopes: scopes }
}

///|
/// Look up a variable type in local scopes (innermost first)
fn lookup_local_variable(checker : TypeChecker, name : String) -> Type? {
  // Search from innermost scope to outermost
  let scopes = checker.local_scopes
  for i = scopes.length() - 1; i >= 0; i = i - 1 {
    match scopes[i].variables.get(name) {
      Some(t) => return Some(t)
      None => ()
    }
  }
  None
}

///|
/// Add a function parameter to the current local scope
fn add_parameter_to_scope(checker : TypeChecker, param : Node) -> TypeChecker {
  match param {
    Parameter(p) => {
      // Get the parameter name
      let name = match p.name {
        Identifier(id) => Some(id.name)
        _ => None // Binding patterns would need recursive handling
      }
      match name {
        Some(n) => {
          // Get the parameter type from type annotation, or any if not specified
          let (param_type, checker) = match p.type_annotation {
            Some(type_node) =>
              match get_type_from_type_node(checker, type_node) {
                (Some(t), c) => (t, c)
                (None, c) => any_type(c)
              }
            None => any_type(checker)
          }
          add_local_variable(checker, n, param_type)
        }
        None => checker
      }
    }
    _ => checker
  }
}

///|
/// Check if a type is array-like (array, tuple, or has numeric index signature)
fn is_array_like_type(t : Type) -> Bool {
  match t {
    Array(_) => true
    Tuple(_) => true
    String(_) => true // Strings are iterable in TypeScript
    Any(_) | Unknown(_) => true // Any/unknown can be array-like
    Union(union_type) =>
      // All members of union must be array-like
      union_type.types.iter().all(fn(member) { is_array_like_type(member) })
    Object(obj_type) =>
      // Check if has numeric index signature
      obj_type.index_signatures.iter().any(fn(idx_sig) {
        match idx_sig.parameter_type {
          Number(_) => true
          _ => false
        }
      })
    TypeReference(_) => true // Type references might be arrays
    _ => false
  }
}

///|
/// Add array binding pattern elements to local scope
fn add_array_binding_elements_to_scope(
  checker : TypeChecker,
  arr_pat : ArrayBindingPattern,
  _arr_type : Type,
) -> TypeChecker {
  let mut checker = checker
  for elem in arr_pat.elements {
    match elem {
      Some(element) =>
        match element {
          Identifier(id) => {
            // Get the element type from array, or any if unknown
            let (elem_type, c) = any_type(checker)
            checker = add_local_variable(c, id.name, elem_type)
          }
          _ => ()
        }
      None => () // Hole in array pattern
    }
  }
  checker
}

///|
/// Add object binding pattern elements to local scope
fn add_object_binding_elements_to_scope(
  checker : TypeChecker,
  obj_pat : ObjectBindingPattern,
  _obj_type : Type,
) -> TypeChecker {
  let mut checker = checker
  for prop in obj_pat.properties {
    // property_name is empty string if shorthand, otherwise the aliased name
    let name : String = if prop.property_name == "" {
      match prop.name {
        Identifier(id) => id.name
        _ => ""
      }
    } else {
      prop.property_name
    }
    if name != "" {
      let (prop_type, c) = any_type(checker)
      checker = add_local_variable(c, name, prop_type)
    }
  }
  checker
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
  type_args : Array[Type],
) -> (Type, TypeChecker) {
  // Get type parameters from the generic type (if available)
  // For now, we'll create placeholder type parameters based on common conventions
  let type_params = get_type_parameters_from_type(generic_type)
  if type_params.is_empty() {
    return (generic_type, checker)
  }

  // Use substitute_type_parameters to perform the actual substitution
  substitute_type_parameters(checker, generic_type, type_params, type_args)
}

///|
/// Extract type parameters from a type (helper for instantiation)
fn get_type_parameters_from_type(t : Type) -> Array[CheckerTypeParameter] {
  // For now, return empty - full implementation would track type parameters
  // on function/class/interface types
  []
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
      class_name: None,
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
          class_name: None,
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
/// Add undefined to a type (creates T | undefined union)
/// Used for noUncheckedIndexedAccess to indicate that indexed access
/// may return undefined if the index doesn't exist
fn add_undefined_to_type(
  checker : TypeChecker,
  t : Type,
) -> (Type, TypeChecker) {
  // Don't add undefined if it's already there
  match t {
    Undefined(_) => (t, checker)
    Union(ut) => {
      // Check if union already contains undefined
      let mut has_undefined = false
      for i = 0; i < ut.types.length(); i = i + 1 {
        match ut.types[i] {
          Undefined(_) => {
            has_undefined = true
            break
          }
          _ => continue
        }
      }
      if has_undefined {
        (t, checker)
      } else {
        let (undef_t, checker) = undefined_type(checker)
        union_type(checker, [t, undef_t])
      }
    }
    Any(_) => (t, checker) // any already includes undefined
    Unknown(_) => (t, checker) // unknown already includes undefined conceptually
    _ => {
      let (undef_t, checker) = undefined_type(checker)
      union_type(checker, [t, undef_t])
    }
  }
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
  check_source_file_with_options(bound, false)
}

///|
/// Check a bound source file with compiler options
pub fn check_source_file_with_options(
  bound : BoundSourceFile,
  no_unchecked_indexed_access : Bool,
) -> CheckResult {
  let checker = TypeChecker::new_with_options(
    bound.file_path,
    Some(bound.global_scope),
    no_unchecked_indexed_access,
  )
  // Push a top-level scope for the source file so local variables are tracked
  let checker = push_local_scope(checker)
  let checker = check_statements(checker, bound.statements)
  // Pop the top-level scope
  let checker = pop_local_scope(checker)

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
    ForInStatement(for_in_stmt) => check_for_in_statement(checker, for_in_stmt)
    ForOfStatement(for_of_stmt) => check_for_of_statement(checker, for_of_stmt)
    BlockStatement(block) => check_block_statement(checker, block)
    ClassDeclaration(class_decl) => check_class_declaration(checker, class_decl)
    InterfaceDeclaration(iface_decl) =>
      check_interface_declaration(checker, iface_decl)
    EnumDeclaration(enum_decl) => check_enum_declaration(checker, enum_decl)
    TypeAliasDeclaration(type_alias) =>
      check_type_alias_declaration(checker, type_alias)
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

  // Check compatibility if both are present using check_assignment_compatibility
  let checker = match (declared_type, init_type) {
    (Some(decl_t), Some(init_t)) =>
      check_assignment_compatibility(checker, init_t, decl_t, decl.location)
    _ => checker
  }

  // Check for array destructuring on non-array type (TS2461)
  let checker = match (decl.name, init_type) {
    (ArrayBindingPattern(_), Some(init_t)) =>
      if not(is_array_like_type(init_t)) {
        add_diagnostic_with_code(
          checker,
          "Type is not an array type",
          decl.location,
          TS2461,
        )
      } else {
        checker
      }
    _ => checker
  }

  // Add variable to local scope if we're in a local scope
  // Determine the final type: declared type takes precedence, then inferred type, then any
  let var_type = match declared_type {
    Some(t) => t
    None =>
      match init_type {
        Some(t) => t
        None => {
          let (t, _) = any_type(checker)
          t
        }
      }
  }

  // Get the variable name and add to local scope
  let checker = match decl.name {
    Identifier(id) => add_local_variable(checker, id.name, var_type)
    ArrayBindingPattern(arr_pat) =>
      // For array destructuring, add each element's name to scope
      add_array_binding_elements_to_scope(checker, arr_pat, var_type)
    ObjectBindingPattern(obj_pat) =>
      // For object destructuring, add each property to scope
      add_object_binding_elements_to_scope(checker, obj_pat, var_type)
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
    // JSX elements
    JsxElement(je) => infer_jsx_element_type(checker, je)
    JsxSelfClosingElement(jsce) => infer_jsx_self_closing_type(checker, jsce)
    JsxFragment(jf) => infer_jsx_fragment_type(checker, jf)
    _ => any_type(checker) // Fallback for unhandled expressions
  }
}

///|
/// Infer identifier type by looking up symbol in scope chain
fn infer_identifier_type(
  checker : TypeChecker,
  id : Identifier,
) -> (Type, TypeChecker) {
  // TS2496: Check for 'arguments' in arrow function
  if id.name == "arguments" && is_in_arrow_function(checker) {
    let checker = add_diagnostic_with_code(
      checker,
      "The 'arguments' object cannot be referenced in an arrow function in ES3 and ES5. Consider using a standard function expression.",
      id.location,
      TS2496,
    )
    return any_type(checker)
  }

  // TS2448: Check for block-scoped variable used before declaration (TDZ)
  match checker.block_scoped_decls.get(id.name) {
    Some(decl_line) =>
      if id.location.start.line < decl_line {
        let checker = add_diagnostic_with_code(
          checker,
          "Block-scoped variable '\{id.name}' used before its declaration.",
          id.location,
          TS2448,
        )
        return any_type(checker)
      }
    None => ()
  }

  // First check for narrowed type (from type guards in if statements)
  match get_narrowed_type(checker, id.name) {
    Some(narrowed) => (narrowed, checker)
    None =>
      // Check local scopes first (for local variables and function parameters)
      match lookup_local_variable(checker, id.name) {
        Some(local_type) => (local_type, checker)
        None =>
          // Fall back to global scope lookup
          match lookup_symbol(checker, id.name) {
            Some(symbol) =>
              // Get type from symbol
              match get_symbol_type(checker, symbol) {
                (Some(t), c) => (t, c)
                (None, c) =>
                  // Symbol exists but type not yet computed - infer from declaration
                  infer_symbol_type(c, symbol)
              }
            None => {
              // Check for built-in globals before emitting error
              match get_builtin_global_type(checker, id.name) {
                Some((builtin_type, c)) => (builtin_type, c)
                None => {
                  // Variable not found - try to find a similar name for suggestion
                  let suggestion = find_similar_name_in_scope(checker, id.name)
                  let checker = match suggestion {
                    Some(similar_name) =>
                      add_diagnostic_with_code(
                        checker,
                        "Cannot find name '\{id.name}'. Did you mean '\{similar_name}'?",
                        id.location,
                        TS2552,
                      )
                    None =>
                      // No similar name found - emit TS2304
                      add_diagnostic_with_code(
                        checker,
                        "Cannot find name '" + id.name + "'",
                        id.location,
                        TS2304,
                      )
                  }
                  any_type(checker)
                }
              }
            }
          }
      }
  }
}

///|
/// Get type for built-in globals like console, JSON, Math, etc.
fn get_builtin_global_type(
  checker : TypeChecker,
  name : String,
) -> ((Type, TypeChecker))? {
  if name == "console" {
    Some(get_console_type(checker))
  } else if name == "JSON" {
    Some(get_json_type(checker))
  } else if name == "Math" {
    Some(get_math_type(checker))
  } else if name == "Promise" {
    Some(get_promise_type(checker))
  } else if name == "Date" {
    Some(get_date_type(checker))
  } else if name == "String" {
    Some(get_string_constructor_type(checker))
  } else if name == "Symbol" {
    Some(get_symbol_constructor_type(checker))
  } else if name == "Error" {
    Some(get_error_constructor_type(checker))
  } else if name == "Array" {
    Some(get_array_constructor_type(checker))
  } else if name == "Object" {
    Some(get_object_constructor_type(checker))
  } else if name == "Number" {
    Some(get_number_constructor_type(checker))
  } else if name == "Boolean" {
    Some(get_boolean_constructor_type(checker))
  } else if name == "require" {
    Some(get_require_type(checker))
  } else {
    None
  }
}

///|
/// Get the type for the console global object
fn get_console_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let console_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let void_info = TypeInfo::{ id: 0, flags: default_flags }

  // Console methods accept any number of any type arguments via rest parameter
  let rest_param = CheckerParameter::{
    name: "data",
    param_type: Type::Any(void_info),
    is_optional: false,
    is_rest: true,
  }

  // Add common console methods (all accept any args and return void)
  let log_method = PropertySignature::{
    name: "log",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [rest_param],
      return_type: Type::Void(void_info),
      info: void_info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  console_methods.set("log", log_method)

  let warn_method = PropertySignature::{
    name: "warn",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [rest_param],
      return_type: Type::Void(void_info),
      info: void_info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  console_methods.set("warn", warn_method)

  let error_method = PropertySignature::{
    name: "error",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [rest_param],
      return_type: Type::Void(void_info),
      info: void_info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  console_methods.set("error", error_method)

  let info_method = PropertySignature::{
    name: "info",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [rest_param],
      return_type: Type::Void(void_info),
      info: void_info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  console_methods.set("info", info_method)

  let debug_method = PropertySignature::{
    name: "debug",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [rest_param],
      return_type: Type::Void(void_info),
      info: void_info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  console_methods.set("debug", debug_method)

  let console_type = Type::Object(ObjectType::{
    properties: console_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (console_type, checker)
}

///|
/// Get the type for the JSON global object
fn get_json_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let json_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // JSON.parse
  let parse_method = PropertySignature::{
    name: "parse",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "text",
        param_type: Type::String(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Any(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  json_methods.set("parse", parse_method)

  // JSON.stringify
  let stringify_method = PropertySignature::{
    name: "stringify",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "value",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::String(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  json_methods.set("stringify", stringify_method)

  let json_type = Type::Object(ObjectType::{
    properties: json_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (json_type, checker)
}

///|
/// Get the type for the Math global object
fn get_math_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let math_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Math.abs
  let abs_method = PropertySignature::{
    name: "abs",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "x",
        param_type: Type::Number(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  math_methods.set("abs", abs_method)

  // Math.floor
  let floor_method = PropertySignature::{
    name: "floor",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "x",
        param_type: Type::Number(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  math_methods.set("floor", floor_method)

  // Math.ceil
  let ceil_method = PropertySignature::{
    name: "ceil",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "x",
        param_type: Type::Number(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  math_methods.set("ceil", ceil_method)

  // Math.random
  let random_method = PropertySignature::{
    name: "random",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  math_methods.set("random", random_method)

  // Math.sqrt
  let sqrt_method = PropertySignature::{
    name: "sqrt",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "x",
        param_type: Type::Number(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  math_methods.set("sqrt", sqrt_method)

  // Math.PI
  let pi_prop = PropertySignature::{
    name: "PI",
    prop_type: Type::Number(info),
    is_optional: false,
    is_readonly: true,
  }
  math_methods.set("PI", pi_prop)

  let math_type = Type::Object(ObjectType::{
    properties: math_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (math_type, checker)
}

///|
/// Get the type for the Promise global constructor
fn get_promise_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let promise_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Promise.resolve
  let resolve_method = PropertySignature::{
    name: "resolve",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "value",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      }],
      return_type: Type::Any(info), // Returns Promise<T>
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  promise_methods.set("resolve", resolve_method)

  // Promise.reject
  let reject_method = PropertySignature::{
    name: "reject",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "reason",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      }],
      return_type: Type::Any(info), // Returns Promise<never>
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  promise_methods.set("reject", reject_method)

  // Promise.all
  let all_method = PropertySignature::{
    name: "all",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "values",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Any(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  promise_methods.set("all", all_method)

  let promise_type = Type::Object(ObjectType::{
    properties: promise_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (promise_type, checker)
}

///|
/// Get the type for the Date global constructor
fn get_date_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let date_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Date.now
  let now_method = PropertySignature::{
    name: "now",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  date_methods.set("now", now_method)

  // Date.parse
  let parse_method = PropertySignature::{
    name: "parse",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "s",
        param_type: Type::String(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  date_methods.set("parse", parse_method)

  // Create Date instance type with methods like getTime, getFullYear, etc.
  let (instance_id, checker) = next_type_id(checker)
  let instance_methods : Map[String, PropertySignature] = Map::new()
  instance_methods.set(
    "getTime",
    PropertySignature::{
      name: "getTime",
      prop_type: Type::Function(CheckerFunctionType::{
        parameters: [],
        return_type: Type::Number(info),
        info,
      }),
      is_optional: false,
      is_readonly: false,
    },
  )
  let date_instance_type = Type::Object(ObjectType::{
    properties: instance_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id: instance_id, flags: default_flags },
    class_name: Some("Date"),
  })

  // Construct signature: new Date() => Date
  let construct_sig = CheckerSignature::{
    parameters: [],
    return_type: date_instance_type,
    type_parameters: [],
  }

  // Construct signature with value: new Date(value) => Date
  let construct_sig_value = CheckerSignature::{
    parameters: [CheckerParameter::{
      name: "value",
      param_type: Type::Any(info),
      is_optional: true,
      is_rest: false,
    }],
    return_type: date_instance_type,
    type_parameters: [],
  }

  let date_type = Type::Object(ObjectType::{
    properties: date_methods,
    call_signatures: [],
    construct_signatures: [construct_sig, construct_sig_value],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (date_type, checker)
}

///|
/// Get the type for the String global constructor
fn get_string_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let string_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // String.fromCharCode
  let from_char_code = PropertySignature::{
    name: "fromCharCode",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "codes",
        param_type: Type::Number(info),
        is_optional: false,
        is_rest: true,
      }],
      return_type: Type::String(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  string_methods.set("fromCharCode", from_char_code)

  let string_type = Type::Object(ObjectType::{
    properties: string_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (string_type, checker)
}

///|
/// Get the type for the Symbol global constructor
fn get_symbol_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let symbol_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Symbol.for
  let for_method = PropertySignature::{
    name: "for",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "key",
        param_type: Type::String(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Symbol(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  symbol_methods.set("for", for_method)

  // Symbol.iterator
  let iterator_prop = PropertySignature::{
    name: "iterator",
    prop_type: Type::Symbol(info),
    is_optional: false,
    is_readonly: true,
  }
  symbol_methods.set("iterator", iterator_prop)

  let symbol_type = Type::Object(ObjectType::{
    properties: symbol_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (symbol_type, checker)
}

///|
/// Get the type for the Error global constructor
fn get_error_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Error instance type - returned when constructed
  let error_instance_properties : Map[String, PropertySignature] = Map::new()
  error_instance_properties.set(
    "message",
    PropertySignature::{
      name: "message",
      prop_type: Type::String(info),
      is_optional: false,
      is_readonly: false,
    },
  )
  error_instance_properties.set(
    "name",
    PropertySignature::{
      name: "name",
      prop_type: Type::String(info),
      is_optional: false,
      is_readonly: false,
    },
  )
  error_instance_properties.set(
    "stack",
    PropertySignature::{
      name: "stack",
      prop_type: Type::String(info),
      is_optional: true,
      is_readonly: false,
    },
  )

  let (instance_id, checker) = next_type_id(checker)
  let error_instance_type = Type::Object(ObjectType::{
    properties: error_instance_properties,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id: instance_id, flags: default_flags },
    class_name: Some("Error"),
  })

  // Construct signature: new Error(message?: string) => Error
  let construct_sig = CheckerSignature::{
    parameters: [
      CheckerParameter::{
        name: "message",
        param_type: Type::String(info),
        is_optional: true,
        is_rest: false,
      },
    ],
    return_type: error_instance_type,
    type_parameters: [],
  }

  // Error constructor type with construct signature
  let error_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [construct_sig],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (error_type, checker)
}

///|
/// Get the type for the Array global constructor
fn get_array_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let array_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Array.isArray
  let is_array_method = PropertySignature::{
    name: "isArray",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "arg",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Boolean(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  array_methods.set("isArray", is_array_method)

  // Array.from
  let from_method = PropertySignature::{
    name: "from",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "arrayLike",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Any(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  array_methods.set("from", from_method)

  let array_type = Type::Object(ObjectType::{
    properties: array_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (array_type, checker)
}

///|
/// Get the type for the Object global constructor
fn get_object_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let object_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Object.keys
  let keys_method = PropertySignature::{
    name: "keys",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "o",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Any(info), // string[]
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  object_methods.set("keys", keys_method)

  // Object.values
  let values_method = PropertySignature::{
    name: "values",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "o",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Any(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  object_methods.set("values", values_method)

  // Object.entries
  let entries_method = PropertySignature::{
    name: "entries",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "o",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Any(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  object_methods.set("entries", entries_method)

  // Object.assign
  let assign_method = PropertySignature::{
    name: "assign",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "target",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }, CheckerParameter::{
        name: "sources",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: true,
      }],
      return_type: Type::Any(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  object_methods.set("assign", assign_method)

  let object_type = Type::Object(ObjectType::{
    properties: object_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (object_type, checker)
}

///|
/// Get the type for the Number global constructor
fn get_number_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let number_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Number.isNaN
  let is_nan_method = PropertySignature::{
    name: "isNaN",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "number",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Boolean(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  number_methods.set("isNaN", is_nan_method)

  // Number.isFinite
  let is_finite_method = PropertySignature::{
    name: "isFinite",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "number",
        param_type: Type::Any(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Boolean(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  number_methods.set("isFinite", is_finite_method)

  // Number.parseInt
  let parse_int_method = PropertySignature::{
    name: "parseInt",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [CheckerParameter::{
        name: "string",
        param_type: Type::String(info),
        is_optional: false,
        is_rest: false,
      }],
      return_type: Type::Number(info),
      info,
    }),
    is_optional: false,
    is_readonly: false,
  }
  number_methods.set("parseInt", parse_int_method)

  let number_type = Type::Object(ObjectType::{
    properties: number_methods,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (number_type, checker)
}

///|
/// Get the type for the Boolean global constructor
fn get_boolean_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()

  let boolean_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })

  (boolean_type, checker)
}

///|
/// Get the type for the require function (Node.js CommonJS require)
fn get_require_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // require(id: string) => any
  let require_type = Type::Function(CheckerFunctionType::{
    parameters: [
      CheckerParameter::{
        name: "id",
        param_type: Type::String(info),
        is_optional: false,
        is_rest: false,
      },
    ],
    return_type: Type::Any(info),
    info: TypeInfo::{ id, flags: default_flags },
  })

  (require_type, checker)
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
  // Check if this is an overloaded function (multiple declarations)
  if symbol.declarations.length() > 1 {
    // Create an Object type with multiple call signatures
    return infer_overloaded_function_type(checker, symbol)
  }

  // Single declaration - create simple Function type
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
/// Infer type for overloaded function (multiple declarations)
fn infer_overloaded_function_type(
  checker : TypeChecker,
  symbol : Symbol,
) -> (Type, TypeChecker) {
  let mut checker = checker
  let call_signatures : Array[CheckerSignature] = []

  // Process each declaration to create a call signature
  for decl in symbol.declarations {
    match decl {
      FunctionDeclaration(func) => {
        // Build parameter list for this overload
        let parameters : Array[CheckerParameter] = []
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

        // Get return type for this overload
        let (return_type, c) = match func.return_type {
          Some(type_node) =>
            match get_type_from_type_node(checker, type_node) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
          None => any_type(checker)
        }
        checker = c

        // Only add overload signatures (those without body), not the implementation
        if func.body.is_none() {
          call_signatures.push({
            parameters,
            return_type,
            type_parameters: [],
          })
        }
      }
      _ => ()
    }
  }

  // Create Object type with call signatures
  let (info, checker) = create_type_info(checker)
  let func_type = Type::Object({
    properties: Map::new(),
    call_signatures,
    construct_signatures: [],
    index_signatures: [],
    info,
    class_name: None,
  })

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
  // Check if already cached
  match checker.symbol_types.get(symbol.id) {
    Some(cached_type) => return (cached_type, checker)
    None => ()
  }

  // Check for circular reference (class referring to itself in initializer)
  if checker.resolving_symbols.get(symbol.id).is_some() {
    // Circular reference detected - return 'any' type to allow property access
    // This allows `static origin = new Point(0, 0)` and `static ref = X.data` to work
    return any_type(checker)
  }

  // Mark symbol as being resolved
  let resolving = checker.resolving_symbols
  resolving.set(symbol.id, true)
  let mut checker = { ..checker, resolving_symbols: resolving }

  // Build object type for the class - separating static and instance properties
  // Static properties go on the class constructor type (for X.staticProp)
  // Instance properties go on the instance type (for new X().instanceProp)
  let static_properties : Map[String, PropertySignature] = Map::new()
  let instance_properties : Map[String, PropertySignature] = Map::new()

  // Inherit static properties from parent class (if extends clause exists)
  for heritage_clause in class_decl.heritage_clauses {
    if heritage_clause.kind == Extends {
      for type_node in heritage_clause.types {
        // Get the type of the parent class by looking up the class name
        let (parent_type, c) = match type_node {
          TypeReference(type_ref) => {
            // Look up the class by name
            match lookup_symbol(checker, type_ref.type_name) {
              Some(parent_symbol) => {
                match get_symbol_type(checker, parent_symbol) {
                  (Some(t), c) => (t, c)
                  (None, c) => infer_symbol_type(c, parent_symbol)
                }
              }
              None => any_type(checker)
            }
          }
          _ => infer_type(checker, type_node)
        }
        checker = c
        // If parent is an object type, copy its static properties
        match parent_type {
          Object(parent_obj) => {
            for entry in parent_obj.properties.iter() {
              static_properties.set(entry.0, entry.1)
            }
          }
          _ => ()
        }
      }
    }
  }

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
        let is_static = has_modifier(prop.modifiers, Modifier::Static)
        let prop_sig = PropertySignature::{
          name: prop.name,
          prop_type,
          is_optional: false,
          is_readonly: has_readonly,
        }
        if is_static {
          static_properties.set(prop.name, prop_sig)
        } else {
          instance_properties.set(prop.name, prop_sig)
        }
      }
      MethodDeclaration(method_decl) => {
        let (method_type, c) = infer_method_type(checker, method_decl)
        checker = c
        let is_static = has_modifier(method_decl.modifiers, Modifier::Static)
        let prop_sig = PropertySignature::{
          name: method_decl.name,
          prop_type: method_type,
          is_optional: false,
          is_readonly: false,
        }
        if is_static {
          static_properties.set(method_decl.name, prop_sig)
        } else {
          instance_properties.set(method_decl.name, prop_sig)
        }
      }
      _ => ()
    }
  }

  // Unmark symbol as being resolved
  let resolving = checker.resolving_symbols
  resolving.remove(symbol.id)
  checker = { ..checker, resolving_symbols: resolving }

  // Get class name from symbol for tracking instance types
  let class_name_str = symbol.name

  // Create instance type (used when instantiating with 'new')
  let (instance_info, checker) = create_type_info(checker)
  let instance_type = Type::Object(ObjectType::{
    properties: instance_properties,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: instance_info,
    class_name: Some(class_name_str), // Track which class this instance came from
  })

  // Create construct signature for 'new Class()'
  let construct_sig = CheckerSignature::{
    parameters: [], // TODO: extract constructor parameters
    return_type: instance_type,
    type_parameters: [],
  }

  // Create class constructor type (the type of the class name as a value)
  // This includes static properties and a construct signature
  let (class_info, checker) = create_type_info(checker)
  let class_type = Type::Object(ObjectType::{
    properties: static_properties,
    call_signatures: [],
    construct_signatures: [construct_sig],
    index_signatures: [],
    info: class_info,
    class_name: None, // Constructor type doesn't need class_name tracking
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
  // Push a local scope for method body checking
  let checker = push_local_scope(checker)

  // Track async function context for TS2465
  let checker = if method_decl.is_async {
    enter_async_function(checker)
  } else {
    checker
  }

  // Build parameter list and add parameters to local scope
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
        let param_name = get_parameter_name(p.name)
        parameters.push({
          name: param_name,
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
        // Add parameter to local scope for body checking
        checker = add_local_variable(checker, param_name, param_type)
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

  // Check method body for errors (including await expressions)
  let checker = match method_decl.body {
    Some(body) =>
      match body {
        BlockStatement(block) => check_block_statement(checker, block)
        _ => checker
      }
    None => checker
  }

  // Exit async function context if needed
  let checker = if method_decl.is_async {
    exit_async_function(checker)
  } else {
    checker
  }

  // Pop the local scope
  let checker = pop_local_scope(checker)

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
    // instanceof operator: obj instanceof Constructor -> boolean
    InstanceOf => {
      let checker = check_instanceof_operands(
        checker,
        left_type,
        right_type,
        bin_expr,
      )
      boolean_type(checker)
    }
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
      // Check if trying to assign to a const variable using check_const_assignment
      // Also remove any type narrowing for the variable being assigned
      // For identifiers, we need to get the declared type (not narrowed type) for assignment checking
      let (checker, target_type) = match bin_expr.left {
        Identifier(id) => {
          let (checker, declared_type_opt) = match
            lookup_symbol(checker, id.name) {
            Some(symbol) => {
              let c = check_const_assignment(
                checker,
                id.name,
                symbol,
                get_node_location(BinaryExpression(bin_expr)),
              )
              // Get the declared type (not narrowed) for assignment checking
              match get_symbol_type(c, symbol) {
                (Some(t), c2) => (c2, Some(t))
                (None, c2) => (c2, None)
              }
            }
            None => (checker, None) // Can't find symbol, skip type check
          }
          // Assignment invalidates type narrowing for this variable
          let checker = remove_narrowed_type(checker, id.name)
          // Use declared type if available, otherwise use any (to skip check)
          let target = match declared_type_opt {
            Some(t) => t
            None => {
              let (any, _) = any_type(checker)
              any
            }
          }
          (checker, target)
        }
        ElementAccessExpression(elem) => {
          // Check for readonly index signature (TS2542)
          let (object_type, c) = infer_type(checker, elem.expression)
          let checker = match object_type {
            Object(obj_type) => {
              // Check if any index signature is readonly
              let has_readonly_index = obj_type.index_signatures.iter().any(fn(
                idx_sig
              ) { idx_sig.is_readonly })
              if has_readonly_index {
                add_diagnostic_with_code(
                  c,
                  "Index signature in type '\{type_to_string(object_type)}' only permits reading",
                  get_node_location(BinaryExpression(bin_expr)),
                  TS2542,
                )
              } else {
                c
              }
            }
            _ => c
          }
          (checker, left_type)
        }
        ObjectLiteralExpression(obj) => {
          // Check for TS2701: rest element in destructuring assignment must be simple variable
          let mut checker = checker
          for prop in obj.properties {
            match prop {
              SpreadAssignment(spread_expr, loc) =>
                // Rest element must be an identifier (simple variable)
                match spread_expr {
                  Identifier(_) => () // Valid - simple variable
                  _ => {
                    // TS2701: The target of an object rest assignment must be a variable or a property access.
                    // In destructuring contexts, only simple identifiers are allowed
                    checker = add_diagnostic_with_code(
                      checker,
                      "The target of an object rest assignment must be a variable or a property access.",
                      loc,
                      TS2701,
                    )
                  }
                }
              _ => ()
            }
          }
          (checker, left_type)
        }
        PropertyAccessExpression(prop) => {
          // Check for readonly property assignment (TS2540)
          let (object_type, c) = infer_type(checker, prop.expression)
          let checker = check_readonly_property_assignment(
            c,
            object_type,
            prop.name,
            get_node_location(BinaryExpression(bin_expr)),
          )
          (checker, left_type)
        }
        _ => (checker, left_type)
      }
      // Check type compatibility for assignments (using declared type for identifiers, inferred type for others)
      // Only check if we have a valid target type (not any type for undeclared identifiers)
      let checker = match target_type {
        Any(_) => checker // Skip check for any type (undeclared variables, unresolved parameters)
        _ =>
          check_assignment_compatibility(
            checker,
            right_type,
            target_type,
            get_node_location(BinaryExpression(bin_expr)),
          )
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
        // Check arguments against parameter types
        check_function_call_args(checker, func, arg_types, call.location)
      Any(_) | Unknown(_) | TypeReference(_) | Error(_) =>
        // Any, unknown, type references (might be classes), and error types
        // are treated as callable and return any
        any_type(checker)
      Number(_)
      | String(_)
      | Boolean(_)
      | Void(_)
      | Null(_)
      | Undefined(_)
      | NumberLiteral(_, _)
      | StringLiteral(_, _)
      | BooleanLiteral(_, _)
      | Never(_)
      | Symbol(_) => {
        // Primitive types are not callable
        let checker = add_diagnostic_with_code(
          checker,
          "This expression is not callable. Type '\{type_to_string(func_type)}' has no call signatures.",
          call.location,
          TS2349,
        )
        any_type(checker)
      }
      _ =>
        // For other types (objects without call signatures, etc.),
        // be permissive and return any without error
        any_type(checker)
    }
  } else {
    // Resolve which overload matches
    match resolve_call_overload(checker, signatures, arg_types) {
      Some((return_type, c)) => (return_type, c)
      None => {
        // No overload matches - add diagnostic and return error type
        let checker = add_diagnostic_with_code(
          checker,
          "No overload matches this call. Arguments: (\{format_arg_types(arg_types)})",
          call.location,
          TS2769,
        )
        let (err_t, checker) = error_type(checker)
        (err_t, checker)
      }
    }
  }
}

///|
/// Check function call arguments and return result type
fn check_function_call_args(
  checker : TypeChecker,
  func : CheckerFunctionType,
  arg_types : Array[Type],
  location : SourceLocation,
) -> (Type, TypeChecker) {
  let mut checker = checker

  // Check if function has rest parameter
  let has_rest = func.parameters.length() > 0 &&
    func.parameters[func.parameters.length() - 1].is_rest

  // Check argument count
  let min_params = count_required_params(func.parameters)
  let max_params = if has_rest { -1 } else { func.parameters.length() }
  if arg_types.length() < min_params {
    checker = add_diagnostic_with_code(
      checker,
      "Expected \{min_params} arguments, but got \{arg_types.length()}",
      location,
      TS2554,
    )
  } else if max_params >= 0 && arg_types.length() > max_params {
    // Too many arguments (TS2554)
    checker = add_diagnostic_with_code(
      checker,
      "Expected \{max_params} arguments, but got \{arg_types.length()}",
      location,
      TS2554,
    )
  }

  // Check each argument type
  for i = 0; i < arg_types.length() && i < func.parameters.length(); i = i + 1 {
    let param = func.parameters[i]
    if not(is_assignable(arg_types[i], param.param_type)) {
      checker = add_diagnostic_with_code(
        checker,
        "Argument of type '\{type_to_string(arg_types[i])}' is not assignable to parameter '\{param.name}' of type '\{type_to_string(param.param_type)}'",
        location,
        TS2345,
      )
    }
  }
  (func.return_type, checker)
}

///|
/// Format argument types for error messages
fn format_arg_types(arg_types : Array[Type]) -> String {
  let parts : Array[String] = []
  for t in arg_types {
    parts.push(type_to_string(t))
  }
  parts.join(", ")
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

  // If the signature has type parameters, infer them from arguments
  let (effective_params, return_type, checker, constraint_ok) = if signature.type_parameters.length() >
    0 {
    // Infer type arguments from actual arguments
    let param_types : Array[Type] = []
    for param in signature.parameters {
      param_types.push(param.param_type)
    }
    let (inferred_type_args, checker) = infer_type_arguments(
      checker,
      signature.type_parameters,
      param_types,
      arg_types,
    )
    // Check type arguments against constraints (returns false if any constraint violated)
    let (checker, constraints_satisfied) = check_type_arguments_strict(
      checker,
      signature.type_parameters,
      inferred_type_args,
    )
    // Substitute type parameters in parameter types and return type
    let mut checker = checker
    let new_params : Array[CheckerParameter] = []
    for param in signature.parameters {
      let (subst_type, c) = substitute_type_parameters(
        checker,
        param.param_type,
        signature.type_parameters,
        inferred_type_args,
      )
      checker = c
      new_params.push({
        name: param.name,
        param_type: subst_type,
        is_optional: param.is_optional,
        is_rest: param.is_rest,
      })
    }
    let (subst_return, checker) = substitute_type_parameters(
      checker,
      signature.return_type,
      signature.type_parameters,
      inferred_type_args,
    )
    (new_params, subst_return, checker, constraints_satisfied)
  } else {
    (signature.parameters, signature.return_type, checker, true)
  }

  // If constraints were violated, this signature doesn't match
  if not(constraint_ok) {
    return None
  }

  // Check each argument against corresponding parameter type
  for i = 0; i < arg_types.length(); i = i + 1 {
    let param_idx = if i < effective_params.length() {
      i
    } else {
      effective_params.length() - 1
    }
    let param = effective_params[param_idx]
    // For rest parameters, check against the element type of the array
    let expected_type = if param.is_rest {
      get_array_element_type(param.param_type)
    } else {
      param.param_type
    }
    if not(is_assignable(arg_types[i], expected_type)) {
      return None
    }
  }
  Some((return_type, checker))
}

///|
/// Get the element type of an array type (for rest parameters)
fn get_array_element_type(array_type : Type) -> Type {
  match array_type {
    Array(arr) => arr.element_type
    TypeReference(ref_type) =>
      // Handle Array<T> type reference
      if ref_type.name == "Array" && ref_type.type_arguments.length() > 0 {
        ref_type.type_arguments[0]
      } else {
        array_type
      }
    _ => array_type // Fall back to the original type
  }
}

///|
/// Check type arguments against constraints, return bool indicating if all satisfied
fn check_type_arguments_strict(
  checker : TypeChecker,
  type_params : Array[CheckerTypeParameter],
  type_args : Array[Type],
) -> (TypeChecker, Bool) {
  let mut all_satisfied = true

  // Check constraints
  for i = 0; i < type_args.length() && i < type_params.length(); i = i + 1 {
    match type_params[i].constraint {
      Some(constraint) =>
        if not(is_assignable(type_args[i], constraint)) {
          all_satisfied = false
        }
      None => ()
    }
  }
  (checker, all_satisfied)
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
          class_name: obj.class_name,
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
    add_diagnostic_with_code(
      checker,
      "Type does not satisfy the constraint",
      location,
      DiagnosticCode::TS2344,
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
    checker = add_diagnostic_with_code(
      checker,
      "Generic type requires more type arguments",
      location,
      DiagnosticCode::TS2314,
    )
  }
  if type_args.length() > type_params.length() {
    checker = add_diagnostic_with_code(
      checker,
      "Too many type arguments provided",
      location,
      DiagnosticCode::TS2558,
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
    if param.default_type is None {
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
          class_name: None,
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
pub fn create_narrowed_type(
  original_type : Type,
  narrowed_type : Type,
) -> NarrowedType {
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
fn remove_narrowed_type(
  checker : TypeChecker,
  variable_name : String,
) -> TypeChecker {
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
    Some(t) =>
      // If original is a union type and narrowed type is specified,
      // use narrow_union to exclude non-matching types
      match original_type {
        Union(union) =>
          // For the true branch, keep only types matching the narrowed type
          // For the false branch, exclude the narrowed type from the union
          if is_true_branch {
            // Keep only types that are assignable to the narrowed type
            let kept_types : Array[Type] = []
            for union_member in union.types {
              if types_are_identical(union_member, t) ||
                is_assignable(union_member, t) {
                kept_types.push(union_member)
              }
            }
            if kept_types.length() == 1 {
              kept_types[0]
            } else if kept_types.is_empty() {
              t // Fall back to the narrowed type
            } else {
              Union({ types: kept_types, info: union.info })
            }
          } else {
            // Exclude the type from the union
            narrow_union(union, [t])
          }
        _ => t
      }
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
  // Get original type from symbol lookup or any type as fallback
  let (original, checker) = match
    lookup_symbol(checker, type_guard_info.parameter_name) {
    Some(symbol) =>
      match checker.symbol_types.get(symbol.id) {
        Some(t) => (t, checker)
        None => any_type(checker)
      }
    None => any_type(checker)
  }

  // Apply type narrowing using the apply_type_narrowing function
  let narrowed = apply_type_narrowing(original, type_guard_info, is_true_branch)

  // Check if narrowing was effective (different from original)
  if not(types_are_identical(original, narrowed)) {
    add_narrowed_type(
      checker,
      type_guard_info.parameter_name,
      original,
      narrowed,
    )
  } else {
    checker
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
      checker = add_diagnostic_with_code(
        checker,
        "Unreachable code detected.",
        get_node_location(stmt),
        DiagnosticCode::TS7027,
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
    add_diagnostic_with_code(
      checker,
      "Cannot create an instance of an abstract class.",
      get_node_location(NewExpression(new_expr)),
      DiagnosticCode::TS2511,
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
    add_diagnostic_with_code(
      checker,
      "Cannot assign to '" + var_name + "' because it is a constant.",
      location,
      DiagnosticCode::TS2588,
    )
  } else {
    checker
  }
}

///|
/// Check assignment to readonly property (TS2540)
fn check_readonly_property_assignment(
  checker : TypeChecker,
  object_type : Type,
  prop_name : String,
  location : SourceLocation,
) -> TypeChecker {
  match object_type {
    Object(obj_type) => {
      // Check if the property exists and is readonly
      match obj_type.properties.get(prop_name) {
        Some(prop_sig) =>
          if prop_sig.is_readonly {
            add_diagnostic_with_code(
              checker,
              "Cannot assign to '\{prop_name}' because it is a readonly property.",
              location,
              DiagnosticCode::TS2540,
            )
          } else {
            checker
          }
        None => checker // Property not found, will be caught by other checks
      }
    }
    TypeReference(type_ref) => {
      // Resolve the type reference and check
      match lookup_symbol(checker, type_ref.name) {
        Some(symbol) =>
          match get_symbol_type(checker, symbol) {
            (Some(resolved), c) =>
              check_readonly_property_assignment(c, resolved, prop_name, location)
            (None, _) => checker
          }
        None => checker
      }
    }
    _ => checker
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
                  checker = add_diagnostic_with_code(
                    checker,
                    "Type is not assignable to the declared return type.",
                    get_node_location(expr),
                    DiagnosticCode::TS2322,
                  )
                }
              }
              None =>
                // void return - check if compatible
                match declared_return {
                  Void(_) | Any(_) => ()
                  _ =>
                    checker = add_diagnostic_with_code(
                      checker,
                      "A function whose declared return type is not void must return a value.",
                      ret.location,
                      DiagnosticCode::TS2355,
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
/// Look up a property in a type, handling various type kinds
fn lookup_property_in_type(
  checker : TypeChecker,
  t : Type,
  prop_name : String,
) -> (Type?, TypeChecker) {
  match t {
    Object(obj_type) =>
      match obj_type.properties.get(prop_name) {
        Some(property) => (Some(property.prop_type), checker)
        None =>
          // Check index signatures for string indexer
          match find_string_index_signature(obj_type.index_signatures) {
            Some(sig) => (Some(sig.return_type), checker)
            None => (None, checker)
          }
      }
    TypeReference(type_ref) => {
      // Resolve the type reference and look up property in resolved type
      let (resolved, checker) = resolve_type_reference(checker, type_ref)
      match resolved {
        TypeReference(_) =>
          // Could not resolve further, check if it's a class with properties
          match lookup_symbol(checker, type_ref.name) {
            Some(symbol) =>
              match get_class_property_type(checker, symbol, prop_name) {
                (Some(prop_type), checker) => (Some(prop_type), checker)
                (None, checker) => (None, checker)
              }
            None => (None, checker)
          }
        _ => lookup_property_in_type(checker, resolved, prop_name)
      }
    }
    Union(ut) => {
      // Property must exist in all union members
      // Return union of property types from all members
      let mut checker = checker
      let prop_types : Array[Type] = []
      let mut all_have_property = true
      for i = 0; i < ut.types.length(); i = i + 1 {
        let (prop_type_opt, c) = lookup_property_in_type(
          checker,
          ut.types[i],
          prop_name,
        )
        checker = c
        match prop_type_opt {
          Some(prop_type) => prop_types.push(prop_type)
          None => {
            all_have_property = false
            break
          }
        }
      }
      if all_have_property && prop_types.length() > 0 {
        if prop_types.length() == 1 {
          (Some(prop_types[0]), checker)
        } else {
          // Create union of property types
          let (union_prop_type, checker) = union_type(checker, prop_types)
          (Some(union_prop_type), checker)
        }
      } else {
        (None, checker)
      }
    }
    Intersection(intersection_type) => {
      // Property can be from any intersection member
      let mut checker = checker
      for i = 0; i < intersection_type.types.length(); i = i + 1 {
        let (prop_type_opt, c) = lookup_property_in_type(
          checker,
          intersection_type.types[i],
          prop_name,
        )
        checker = c
        match prop_type_opt {
          Some(prop_type) => return (Some(prop_type), checker)
          None => continue
        }
      }
      (None, checker)
    }
    Array(_) =>
      // Handle built-in array properties
      match prop_name {
        "length" => {
          let (num_type, checker) = number_type(checker)
          (Some(num_type), checker)
        }
        _ => (None, checker)
      }
    String(_) =>
      // Handle built-in string properties
      match prop_name {
        "length" => {
          let (num_type, checker) = number_type(checker)
          (Some(num_type), checker)
        }
        _ => (None, checker)
      }
    Function(_) =>
      // Handle built-in function properties
      match prop_name {
        "length" => {
          let (num_type, checker) = number_type(checker)
          (Some(num_type), checker)
        }
        "name" => {
          let (str_type, checker) = string_type(checker)
          (Some(str_type), checker)
        }
        _ => (None, checker)
      }
    Any(_) => {
      // Any type has any property
      let (any_t, checker) = any_type(checker)
      (Some(any_t), checker)
    }
    _ => (None, checker)
  }
}

///|
/// Find a string index signature in an array of index signatures
fn find_string_index_signature(
  signatures : Array[IndexSignature],
) -> IndexSignature? {
  for i = 0; i < signatures.length(); i = i + 1 {
    match signatures[i].parameter_type {
      String(_) => return Some(signatures[i])
      _ => continue
    }
  }
  None
}

///|
/// Get property type from a class symbol
fn get_class_property_type(
  checker : TypeChecker,
  class_symbol : Symbol,
  prop_name : String,
) -> (Type?, TypeChecker) {
  match class_symbol.value_declaration {
    Some(ClassDeclaration(class_decl)) => {
      let mut checker = checker
      for i = 0; i < class_decl.members.length(); i = i + 1 {
        match class_decl.members[i] {
          PropertyDeclaration(prop) =>
            if prop.name == prop_name {
              match prop.type_annotation {
                Some(type_node) =>
                  match get_type_from_type_node(checker, type_node) {
                    (Some(t), c) => return (Some(t), c)
                    (None, c) => {
                      checker = c
                      // No explicit type, try initializer
                      match prop.initializer {
                        Some(init) => {
                          let (init_type, c) = infer_type(checker, init)
                          return (Some(init_type), c)
                        }
                        None => {
                          let (any_t, c) = any_type(checker)
                          return (Some(any_t), c)
                        }
                      }
                    }
                  }
                None =>
                  match prop.initializer {
                    Some(init) => {
                      let (init_type, c) = infer_type(checker, init)
                      return (Some(init_type), c)
                    }
                    None => {
                      let (any_t, c) = any_type(checker)
                      return (Some(any_t), c)
                    }
                  }
              }
            }
          MethodDeclaration(method_decl) =>
            if method_decl.name == prop_name {
              // Return function type for method
              let (func_type, c) = infer_method_type(checker, method_decl)
              return (Some(func_type), c)
            }
          _ => continue
        }
      }
      (None, checker)
    }
    _ => (None, checker)
  }
}

///|
/// Visibility enum for class members
enum MemberVisibility {
  Public
  Private
  Protected
}

///|
/// Get the visibility of a class member (property or method)
fn get_class_member_visibility(
  checker : TypeChecker,
  class_name : String,
  member_name : String,
) -> MemberVisibility {
  match lookup_symbol(checker, class_name) {
    Some(symbol) =>
      match symbol.value_declaration {
        Some(ClassDeclaration(class_decl)) => {
          for member in class_decl.members {
            match member {
              PropertyDeclaration(prop) =>
                if prop.name == member_name {
                  return get_visibility_from_modifiers(prop.modifiers)
                }
              MethodDeclaration(method) =>
                if method.name == member_name {
                  return get_visibility_from_modifiers(method.modifiers)
                }
              GetAccessor(getter) =>
                if getter.name == member_name {
                  return get_visibility_from_modifiers(getter.modifiers)
                }
              SetAccessor(setter) =>
                if setter.name == member_name {
                  return get_visibility_from_modifiers(setter.modifiers)
                }
              _ => continue
            }
          }
          MemberVisibility::Public // Not found, assume public
        }
        _ => MemberVisibility::Public
      }
    None => MemberVisibility::Public
  }
}

///|
/// Get visibility from modifiers array
fn get_visibility_from_modifiers(modifiers : Array[Modifier]) -> MemberVisibility {
  for modifier in modifiers {
    match modifier {
      Modifier::Private => return MemberVisibility::Private
      Modifier::Protected => return MemberVisibility::Protected
      _ => continue
    }
  }
  MemberVisibility::Public
}

///|
/// Get the current class name from checker's this type
fn get_current_class_name(checker : TypeChecker) -> String? {
  match checker.current_this_type {
    Some(Object(obj_type)) => obj_type.class_name
    Some(TypeReference(type_ref)) => Some(type_ref.name)
    _ => None
  }
}

///|
/// Check if we're inside a class that inherits from the given class
fn is_inside_class_or_subclass(
  checker : TypeChecker,
  target_class_name : String,
) -> Bool {
  match get_current_class_name(checker) {
    Some(current_name) =>
      if current_name == target_class_name {
        true
      } else {
        // Check if current class extends target class (for protected access)
        is_subclass_of(checker, current_name, target_class_name)
      }
    None => false
  }
}

///|
/// Check if class_name is a subclass of parent_name
fn is_subclass_of(
  checker : TypeChecker,
  class_name : String,
  parent_name : String,
) -> Bool {
  match lookup_symbol(checker, class_name) {
    Some(symbol) =>
      match symbol.value_declaration {
        Some(ClassDeclaration(class_decl)) => {
          // Find the extends clause in heritage clauses
          for heritage in class_decl.heritage_clauses {
            if heritage.kind == HeritageKind::Extends {
              for type_node in heritage.types {
                // Extract the class name from the heritage type
                let base_name = get_name_from_heritage_node(type_node)
                match base_name {
                  Some(name) =>
                    if name == parent_name {
                      return true
                    } else {
                      if is_subclass_of(checker, name, parent_name) {
                        return true
                      }
                    }
                  None => ()
                }
              }
            }
          }
          false
        }
        _ => false
      }
    None => false
  }
}

///|
/// Extract a name from a Node (used for heritage clauses)
fn get_name_from_heritage_node(node : Node) -> String? {
  match node {
    Identifier(id) => Some(id.name)
    TypeReference(type_ref) => Some(type_ref.type_name)
    CallExpression(call) =>
      // For extends SomeClass<T>()
      get_name_from_heritage_node(call.expression)
    _ => None
  }
}

///|
/// Check member visibility and emit TS2341 (private) or TS2445 (protected) errors
fn check_member_visibility(
  checker : TypeChecker,
  object_type : Type,
  member_name : String,
  location : SourceLocation,
) -> TypeChecker {
  // Get the class name from the object type
  let class_name_opt = match object_type {
    Object(obj_type) => obj_type.class_name
    TypeReference(type_ref) => Some(type_ref.name)
    _ => None
  }
  match class_name_opt {
    Some(class_name) => {
      let visibility = get_class_member_visibility(checker, class_name, member_name)
      match visibility {
        MemberVisibility::Private => {
          // Check if we're inside the same class
          match get_current_class_name(checker) {
            Some(current_class) =>
              if current_class == class_name {
                checker // Access allowed - inside same class
              } else {
                // TS2341: Property 'x' is private and only accessible within class 'ClassName'.
                add_diagnostic_with_code(
                  checker,
                  "Property '\{member_name}' is private and only accessible within class '\{class_name}'.",
                  location,
                  TS2341,
                )
              }
            None =>
              // Not inside any class - private access not allowed
              add_diagnostic_with_code(
                checker,
                "Property '\{member_name}' is private and only accessible within class '\{class_name}'.",
                location,
                TS2341,
              )
          }
        }
        MemberVisibility::Protected => {
          // Check if we're inside the same class or a subclass
          if is_inside_class_or_subclass(checker, class_name) {
            checker // Access allowed
          } else {
            // TS2445: Property 'x' is protected and only accessible within class 'ClassName' and its subclasses.
            add_diagnostic_with_code(
              checker,
              "Property '\{member_name}' is protected and only accessible within class '\{class_name}' and its subclasses.",
              location,
              TS2445,
            )
          }
        }
        MemberVisibility::Public => checker // Public access is always allowed
      }
    }
    None => checker // No class name, can't check visibility
  }
}

///|
/// Unwrap parenthesized expressions to get the inner expression
fn unwrap_parenthesized_expression(expr : Node) -> Node {
  match expr {
    ParenthesizedExpression(paren) => unwrap_parenthesized_expression(paren.expression)
    _ => expr
  }
}

///|
/// Check if a class has a static member with the given name
fn class_has_static_member(
  checker : TypeChecker,
  class_name : String,
  prop_name : String,
) -> Bool {
  // Look up the class symbol
  let symbol = match lookup_symbol(checker, class_name) {
    Some(s) => s
    None => return false
  }

  // Check if it's a class
  match symbol.kind {
    Class => ()
    _ => return false
  }

  // Get the class declaration and check for static members
  match symbol.value_declaration {
    Some(ClassDeclaration(class_decl)) => {
      for i = 0; i < class_decl.members.length(); i = i + 1 {
        match class_decl.members[i] {
          PropertyDeclaration(prop) =>
            if prop.name == prop_name && is_static_modifier(prop.modifiers) {
              return true
            }
          MethodDeclaration(method) =>
            if method.name == prop_name && is_static_modifier(method.modifiers) {
              return true
            }
          GetAccessor(ga) =>
            if ga.name == prop_name && is_static_modifier(ga.modifiers) {
              return true
            }
          SetAccessor(sa) =>
            if sa.name == prop_name && is_static_modifier(sa.modifiers) {
              return true
            }
          _ => continue
        }
      }
      false
    }
    _ => false
  }
}

///|
/// Find a similar property name from an object type
/// Returns Some(name) if a similar property is found, None otherwise
fn find_similar_property(object_type : Type, prop_name : String) -> String? {
  let properties = match object_type {
    Object(obj_type) => obj_type.properties
    _ => return None
  }

  let mut best_match : String? = None
  let mut best_distance = 3 // Maximum distance threshold for suggestions

  for entry in properties.iter() {
    let candidate = entry.0
    // Skip if the candidate is too different in length
    let len_diff = if candidate.length() > prop_name.length() {
      candidate.length() - prop_name.length()
    } else {
      prop_name.length() - candidate.length()
    }
    if len_diff > 2 {
      continue
    }

    let distance = levenshtein_distance(prop_name, candidate)
    if distance < best_distance && distance > 0 {
      best_distance = distance
      best_match = Some(candidate)
    }
  }

  best_match
}

///|
/// Find a similar name in scope for "Did you mean" suggestions
fn find_similar_name_in_scope(checker : TypeChecker, name : String) -> String? {
  let mut best_match : String? = None
  let mut best_distance = 3 // Maximum distance threshold for suggestions

  // Search local scopes first (innermost to outermost)
  let scopes = checker.local_scopes
  for i = scopes.length() - 1; i >= 0; i = i - 1 {
    for entry in scopes[i].variables.iter() {
      let candidate = entry.0
      // Skip if the candidate is too different in length
      let len_diff = if candidate.length() > name.length() {
        candidate.length() - name.length()
      } else {
        name.length() - candidate.length()
      }
      if len_diff <= 2 {
        let distance = levenshtein_distance(name, candidate)
        if distance < best_distance && distance > 0 {
          best_distance = distance
          best_match = Some(candidate)
        }
      }
    }
  }

  // Search global scope
  match checker.global_scope {
    Some(global) => {
      for entry in global.symbols.iter() {
        let candidate = entry.0
        let len_diff = if candidate.length() > name.length() {
          candidate.length() - name.length()
        } else {
          name.length() - candidate.length()
        }
        if len_diff <= 2 {
          let distance = levenshtein_distance(name, candidate)
          if distance < best_distance && distance > 0 {
            best_distance = distance
            best_match = Some(candidate)
          }
        }
      }
    }
    None => ()
  }

  best_match
}

///|
/// Check if a property is a static member of a class
/// Returns (is_static, class_name) if the property is a static member
/// Checks both TypeReference types and Object types with class_name tracking
fn check_is_static_member_of_class(
  checker : TypeChecker,
  object_type : Type,
  prop_name : String,
  expr : Node,
) -> (Bool, String) {
  // First check if the object type has class tracking info
  let class_name = match object_type {
    TypeReference(type_ref) => type_ref.name
    Object(obj_type) => {
      // Check if Object has class_name tracking (instance of a class)
      match obj_type.class_name {
        Some(name) => name
        None => {
          // Fall back to expression tracing for parenthesized new expressions
          let unwrapped = unwrap_parenthesized_expression(expr)
          match unwrapped {
            NewExpression(new_expr) =>
              // Direct new expression like (new MyClass()).staticProp
              match new_expr.expression {
                Identifier(class_id) => class_id.name
                _ => return (false, "")
              }
            _ => return (false, "")
          }
        }
      }
    }
    _ => return (false, "")
  }

  // Check if this class has a static member with the property name
  if class_has_static_member(checker, class_name, prop_name) {
    (true, class_name)
  } else {
    (false, "")
  }
}

///|
/// Helper to get class name from a symbol's declarations
/// Looks for NewExpression initializers in variable statements
fn get_class_name_from_symbol_declarations(sym : Symbol) -> String {
  for i = 0; i < sym.declarations.length(); i = i + 1 {
    match sym.declarations[i] {
      VariableStatement(var_stmt) => {
        for j = 0; j < var_stmt.declarations.length(); j = j + 1 {
          let decl = var_stmt.declarations[j]
          match decl.initializer {
            Some(NewExpression(new_expr)) =>
              match new_expr.expression {
                Identifier(class_id) => return class_id.name
                _ => continue
              }
            _ => continue
          }
        }
      }
      _ => continue
    }
  }
  ""
}

///|
/// Infer property access type
fn infer_property_access_type(
  checker : TypeChecker,
  prop : PropertyAccessExpression,
) -> (Type, TypeChecker) {
  let (object_type, checker) = infer_type(checker, prop.expression)
  let (prop_type_opt, checker) = lookup_property_in_type(
    checker,
    object_type,
    prop.name,
  )
  match prop_type_opt {
    Some(prop_type) => {
      // Check visibility (TS2341: private, TS2445: protected)
      let checker = check_member_visibility(
        checker,
        object_type,
        prop.name,
        prop.location,
      )
      (prop_type, checker)
    }
    None => {
      // TS2459: Type has no property and no string index signature
      // Only emit if the object type is a concrete type (not any/unknown)
      // Also don't error for 'this' expressions - TypeScript allows implicit property assignment
      let is_this_expr = match prop.expression {
        ThisExpression(_) => true
        _ => false
      }

      // Check if this is a static member being accessed on an instance (TS2576)
      let (is_static_member, class_name) = check_is_static_member_of_class(
        checker,
        object_type,
        prop.name,
        prop.expression,
      )

      let checker = match object_type {
        Any(_) | Unknown(_) => checker // Don't error for any/unknown
        Object(_) | TypeReference(_) =>
          if is_this_expr {
            checker // Don't error for property access on 'this' - allows implicit property assignment
          } else if is_static_member {
            // TS2576: Property 'X' is a static member of type 'Y'
            add_diagnostic_with_code(
              checker,
              "Property '\{prop.name}' is a static member of type '\{class_name}'",
              get_node_location(prop.expression),
              TS2576,
            )
          } else {
            // Check for similar property names to provide "Did you mean?" suggestions
            match find_similar_property(object_type, prop.name) {
              Some(suggestion) =>
                add_diagnostic_with_code(
                  checker,
                  "Property '\{prop.name}' does not exist on type '\{type_to_string(object_type)}'. Did you mean '\{suggestion}'?",
                  get_node_location(prop.expression),
                  TS2551, // TS2551: Property does not exist, did you mean?
                )
              None =>
                add_diagnostic_with_code(
                  checker,
                  "Property '\{prop.name}' does not exist on type '\{type_to_string(object_type)}'",
                  get_node_location(prop.expression),
                  TS2339, // TS2339 is the standard "property does not exist" error
                )
            }
          }
        _ => checker // Don't error for other types yet
      }
      any_type(checker)
    }
  }
}

///|
/// Infer element access type (bracket notation)
/// When noUncheckedIndexedAccess is enabled, adds undefined to the result type
/// for array access and index signature access (but not for known property access)
fn infer_element_access_type(
  checker : TypeChecker,
  elem : ElementAccessExpression,
) -> (Type, TypeChecker) {
  let (object_type, checker) = infer_type(checker, elem.expression)
  let (index_type, checker) = infer_type(checker, elem.argument_expression)
  let no_unchecked = checker.no_unchecked_indexed_access
  match object_type {
    Array(arr_type) => {
      // Check if index type is valid (number or string for arrays)
      let checker = match index_type {
        Number(_) | NumberLiteral(_, _) | String(_) | StringLiteral(_, _) |
        Any(_) | Unknown(_) => checker
        Boolean(_) | BooleanLiteral(_, _) | Object(_) | Void(_) | Null(_) |
        Undefined(_) => {
          // TS2538: Type cannot be used as an index type
          add_diagnostic_with_code(
            checker,
            "Type '\{type_to_string(index_type)}' cannot be used as an index type",
            get_node_location(elem.argument_expression),
            TS2538,
          )
        }
        _ => checker
      }
      // Array access - add undefined if noUncheckedIndexedAccess is enabled
      // because the index might be out of bounds
      let element_type = arr_type.element_type
      if no_unchecked {
        add_undefined_to_type(checker, element_type)
      } else {
        (element_type, checker)
      }
    }
    Object(obj_type) =>
      // Handle object element access based on argument type
      match elem.argument_expression {
        // String literal index: obj["prop"] - look up property by name
        StringLiteral(str_lit) =>
          match obj_type.properties.get(str_lit.value) {
            // Known property - don't add undefined (property exists)
            Some(property) => (property.prop_type, checker)
            None =>
              // Check string index signature
              match find_string_index_signature(obj_type.index_signatures) {
                Some(sig) =>
                  // Index signature access - add undefined if noUncheckedIndexedAccess
                  if no_unchecked {
                    add_undefined_to_type(checker, sig.return_type)
                  } else {
                    (sig.return_type, checker)
                  }
                None => any_type(checker)
              }
          }
        _ =>
          // Dynamic index: check based on index type
          match index_type {
            Number(_) | NumberLiteral(_, _) =>
              // Number index: look for number index signature
              match find_number_index_signature(obj_type.index_signatures) {
                Some(sig) =>
                  if no_unchecked {
                    add_undefined_to_type(checker, sig.return_type)
                  } else {
                    (sig.return_type, checker)
                  }
                None =>
                  // Fall back to string index signature
                  match find_string_index_signature(obj_type.index_signatures) {
                    Some(sig) =>
                      if no_unchecked {
                        add_undefined_to_type(checker, sig.return_type)
                      } else {
                        (sig.return_type, checker)
                      }
                    None => any_type(checker)
                  }
              }
            String(_) | StringLiteral(_, _) =>
              // String index: look for string index signature
              match find_string_index_signature(obj_type.index_signatures) {
                Some(sig) =>
                  if no_unchecked {
                    add_undefined_to_type(checker, sig.return_type)
                  } else {
                    (sig.return_type, checker)
                  }
                None => any_type(checker)
              }
            Boolean(_) | BooleanLiteral(_, _) | Object(_) | Array(_) | Void(_) |
            Null(_) | Undefined(_) => {
              // TS2538: Type cannot be used as an index type
              let checker = add_diagnostic_with_code(
                checker,
                "Type '\{type_to_string(index_type)}' cannot be used as an index type",
                get_node_location(elem.argument_expression),
                TS2538,
              )
              any_type(checker)
            }
            _ =>
              // Unknown index type: try string index signature, then any
              match find_string_index_signature(obj_type.index_signatures) {
                Some(sig) =>
                  if no_unchecked {
                    add_undefined_to_type(checker, sig.return_type)
                  } else {
                    (sig.return_type, checker)
                  }
                None => any_type(checker)
              }
          }
      }
    // Handle type references that might resolve to objects
    TypeReference(_) => {
      let (prop_type_opt, checker) = lookup_element_access_in_type(
        checker,
        object_type,
        index_type,
        elem.argument_expression,
      )
      match prop_type_opt {
        Some(prop_type) =>
          // For TypeReference, we need to add undefined for index signature access
          // The lookup function doesn't distinguish, so we add undefined conservatively
          if no_unchecked {
            add_undefined_to_type(checker, prop_type)
          } else {
            (prop_type, checker)
          }
        None => any_type(checker)
      }
    }
    // Handle union types - element must be accessible in all members
    Union(ut) => {
      let mut checker = checker
      let element_types : Array[Type] = []
      let mut all_accessible = true
      for i = 0; i < ut.types.length(); i = i + 1 {
        let (elem_type_opt, c) = lookup_element_access_in_type(
          checker,
          ut.types[i],
          index_type,
          elem.argument_expression,
        )
        checker = c
        match elem_type_opt {
          Some(elem_type) => element_types.push(elem_type)
          None => {
            all_accessible = false
            break
          }
        }
      }
      if all_accessible && element_types.length() > 0 {
        let result_type = if element_types.length() == 1 {
          element_types[0]
        } else {
          let (union_elem_type, c) = union_type(checker, element_types)
          checker = c
          union_elem_type
        }
        if no_unchecked {
          add_undefined_to_type(checker, result_type)
        } else {
          (result_type, checker)
        }
      } else {
        any_type(checker)
      }
    }
    // Handle intersection types - element can be from any member
    Intersection(intersection_type) => {
      let mut checker = checker
      for i = 0; i < intersection_type.types.length(); i = i + 1 {
        let (elem_type_opt, c) = lookup_element_access_in_type(
          checker,
          intersection_type.types[i],
          index_type,
          elem.argument_expression,
        )
        checker = c
        match elem_type_opt {
          Some(elem_type) =>
            if no_unchecked {
              return add_undefined_to_type(checker, elem_type)
            } else {
              return (elem_type, checker)
            }
          None => continue
        }
      }
      any_type(checker)
    }
    Any(_) => any_type(checker)
    _ => any_type(checker)
  }
}

///|
/// Find a number index signature in an array of index signatures
fn find_number_index_signature(
  signatures : Array[IndexSignature],
) -> IndexSignature? {
  for i = 0; i < signatures.length(); i = i + 1 {
    match signatures[i].parameter_type {
      Number(_) => return Some(signatures[i])
      _ => continue
    }
  }
  None
}

///|
/// Look up element access type in a type (helper for element access)
fn lookup_element_access_in_type(
  checker : TypeChecker,
  t : Type,
  index_type : Type,
  argument_expr : Node,
) -> (Type?, TypeChecker) {
  match t {
    Array(arr_type) => (Some(arr_type.element_type), checker)
    Object(obj_type) =>
      match argument_expr {
        StringLiteral(str_lit) =>
          match obj_type.properties.get(str_lit.value) {
            Some(property) => (Some(property.prop_type), checker)
            None =>
              match find_string_index_signature(obj_type.index_signatures) {
                Some(sig) => (Some(sig.return_type), checker)
                None => (None, checker)
              }
          }
        _ =>
          match index_type {
            Number(_) | NumberLiteral(_, _) =>
              match find_number_index_signature(obj_type.index_signatures) {
                Some(sig) => (Some(sig.return_type), checker)
                None =>
                  match find_string_index_signature(obj_type.index_signatures) {
                    Some(sig) => (Some(sig.return_type), checker)
                    None => (None, checker)
                  }
              }
            String(_) | StringLiteral(_, _) =>
              match find_string_index_signature(obj_type.index_signatures) {
                Some(sig) => (Some(sig.return_type), checker)
                None => (None, checker)
              }
            _ =>
              match find_string_index_signature(obj_type.index_signatures) {
                Some(sig) => (Some(sig.return_type), checker)
                None => (None, checker)
              }
          }
      }
    TypeReference(type_ref) => {
      let (resolved, checker) = resolve_type_reference(checker, type_ref)
      match resolved {
        TypeReference(_) => (None, checker)
        _ =>
          lookup_element_access_in_type(
            checker, resolved, index_type, argument_expr,
          )
      }
    }
    Any(_) => {
      let (any_t, checker) = any_type(checker)
      (Some(any_t), checker)
    }
    _ => (None, checker)
  }
}

///|
/// Infer new expression type (constructor call)
fn infer_new_expression_type(
  checker : TypeChecker,
  new_expr : NewExpression,
) -> (Type, TypeChecker) {
  let (expr_type, checker) = infer_type(checker, new_expr.expression)

  // Check if trying to instantiate an abstract class
  let checker = match new_expr.expression {
    Identifier(id) =>
      match lookup_symbol(checker, id.name) {
        Some(class_symbol) =>
          check_abstract_instantiation(checker, new_expr, class_symbol)
        None => checker
      }
    _ => checker
  }

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

  // Check if the target has a construct signature (TS2747)
  // Skip check for class types (lookup symbol to determine)
  let is_class_type = match new_expr.expression {
    Identifier(id) =>
      match lookup_symbol(checker, id.name) {
        Some(symbol) =>
          match symbol.kind {
            Class => true
            _ => false
          }
        None => false
      }
    _ => false
  }
  let checker = if not(is_class_type) {
    match expr_type {
      Object(obj_type) =>
        if obj_type.construct_signatures.length() == 0 {
          // No construct signatures - emit TS2747
          add_diagnostic_with_code(
            checker,
            "'new' expression, whose target lacks a construct signature, implicitly has an 'any' type",
            get_node_location(new_expr.expression),
            TS2747,
          )
        } else {
          checker
        }
      Function(_) =>
        // Plain function type without construct signature
        add_diagnostic_with_code(
          checker,
          "'new' expression, whose target lacks a construct signature, implicitly has an 'any' type",
          get_node_location(new_expr.expression),
          TS2747,
        )
      // Primitive types are not constructable - emit TS2351
      Number(_)
      | String(_)
      | Boolean(_)
      | Void(_)
      | Null(_)
      | Undefined(_)
      | NumberLiteral(_, _)
      | StringLiteral(_, _)
      | BooleanLiteral(_, _)
      | Never(_)
      | Symbol(_) =>
        add_diagnostic_with_code(
          checker,
          "This expression is not constructable. Type '\{type_to_string(expr_type)}' has no construct signatures.",
          get_node_location(new_expr.expression),
          TS2351,
        )
      _ => checker
    }
  } else {
    checker
  }

  // Return the constructed instance type from the construct signature
  // For a class constructor, we need to get the return type of the construct signature
  let result_type = match expr_type {
    Object(obj_type) =>
      if obj_type.construct_signatures.length() > 0 {
        // Return the instance type from the first construct signature
        obj_type.construct_signatures[0].return_type
      } else {
        expr_type
      }
    _ => expr_type
  }
  (result_type, checker)
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
  match checker.current_this_type {
    Some(this_type) => (this_type, checker)
    None => any_type(checker)
  }
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
  // TS2465: 'await' expressions are only allowed within async functions
  let checker = if not(is_in_async_function(checker)) {
    add_diagnostic_with_code(
      checker,
      "'await' expressions are only allowed within async functions and at the top levels of modules.",
      ae.location,
      TS2465,
    )
  } else {
    checker
  }
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

      // TS2770: Check if yield operand type has a problematic 'then' member
      // In an async generator, the yield operand must either be a valid promise
      // or must not contain a callable 'then' member
      let checker = check_yield_operand_then_member(checker, expr_type, ye.location)

      // For yield*, should iterate over the expression
      // For plain yield, return the expression type
      (expr_type, checker)
    }
    None => {
      // TS2764: 'yield' expression implicitly results in an 'any' type
      // because its containing generator lacks a return-type annotation
      // Note: Full implementation requires tracking enclosing function context
      undefined_type(checker)
    }
  }
}

///|
/// Check if the yield operand type has a problematic 'then' member (TS2770)
/// Type of 'yield' operand in an async generator must either be a valid promise
/// or must not contain a callable 'then' member
fn check_yield_operand_then_member(
  checker : TypeChecker,
  operand_type : Type,
  location : SourceLocation,
) -> TypeChecker {
  // Check if the type has a 'then' property that is callable but not a proper promise
  // In an async generator, the yield operand must either be a valid promise
  // or must not contain a callable 'then' member (TS2770)
  // Full implementation would check enclosing async generator context
  // For now, this is a placeholder for the check
  ignore(operand_type)
  ignore(location)
  checker
}

///|
/// Check for circular type reference in promise 'then' method (TS2771)
/// Type '{0}' referenced when attempting to get type of 'then' method in a promise
fn check_promise_then_circular_reference(
  checker : TypeChecker,
  type_name : String,
  location : SourceLocation,
) -> TypeChecker {
  // This check is for detecting circular references when resolving promise types
  // It's typically triggered when a type refers to itself through the 'then' callback
  // Full implementation requires cycle detection during promise type resolution
  checker
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
  // Push a local scope for function body checking
  let checker = push_local_scope(checker)

  // Track async function context for TS2465
  let checker = if fe.is_async {
    enter_async_function(checker)
  } else {
    checker
  }

  // Build a function type from the function expression and add parameters to local scope
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
        let param_name = match p.name {
          Identifier(id) => id.name
          _ => ""
        }
        params.push({
          name: param_name,
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
        // Add parameter to local scope for body checking
        checker = add_local_variable(checker, param_name, param_type)
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

  // Check function body for errors (including await expressions)
  let checker = match fe.body {
    BlockStatement(block) => check_block_statement(checker, block)
    _ => checker
  }

  // Exit async function context if needed
  let checker = if fe.is_async {
    exit_async_function(checker)
  } else {
    checker
  }

  // Pop the local scope
  let checker = pop_local_scope(checker)

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
        // Check for spread expressions - they must spread iterable types (TS2548)
        match elem {
          SpreadExpression(spread) => {
            let (spread_type, c) = infer_type(checker, spread.expression)
            checker = c
            // Check if type is iterable (array, string, or has Symbol.iterator)
            let is_iterable = match spread_type {
              Array(_) => true
              String(_) => true
              TypeReference(ref_type) => ref_type.name == "Array" || ref_type.name == "String"
              _ => false
            }
            if not(is_iterable) {
              checker = add_diagnostic_with_code(
                checker,
                "Type is not an array type or a string type. Use a spread only on iterable types",
                get_node_location(spread.expression),
                TS2548,
              )
            }
            // For arrays, extract element type
            match spread_type {
              Array(arr_type) => element_types.push(arr_type.element_type)
              String(_) => {
                let (info, c) = create_type_info(checker)
                checker = c
                element_types.push(String(info))
              }
              _ => element_types.push(spread_type)
            }
          }
          _ => {
            let (elem_type, c) = infer_type(checker, elem)
            element_types.push(elem_type)
            checker = c
          }
        }
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
        // For computed properties, try to get the property name from string/identifier
        let key = get_property_name(name_expr)
        let key = if key == "" { "[computed]" } else { key }
        let (_, c) = infer_type(checker, name_expr)
        let (prop_type, c) = infer_type(c, value)
        properties.set(key, {
          name: key,
          prop_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      ShorthandProperty(name, _) => {
        // Shorthand property - get type from identifier in scope
        let (prop_type, c) = match lookup_symbol(checker, name) {
          Some(symbol) =>
            match checker.symbol_types.get(symbol.id) {
              Some(t) => (t, checker)
              None => any_type(checker)
            }
          None => any_type(checker)
        }
        properties.set(name, {
          name,
          prop_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      SpreadAssignment(spread_expr, loc) => {
        let (spread_type, c) = infer_type(checker, spread_expr)
        checker = c
        // Check if spread type is an object type
        match spread_type {
          Object(obj_type) =>
            // Merge properties from spread object
            for entry in obj_type.properties {
              let (prop_name, prop_info) = entry
              properties.set(prop_name, prop_info)
            }
          Any(_) | Unknown(_) => () // Allow spreading any/unknown
          Intersection(_) => () // Allow spreading intersections (may contain objects)
          Union(_) => () // Allow spreading unions (may contain objects)
          TypeReference(_) => {
            // TS2762: Spread types may only be created from object types
            // Type parameter T might not be an object type
            checker = add_diagnostic_with_code(
              checker,
              "Spread types may only be created from object types",
              loc,
              TS2762,
            )
          }
          _ => {
            // TS2762: Spread types may only be created from object types
            checker = add_diagnostic_with_code(
              checker,
              "Spread types may only be created from object types",
              loc,
              TS2762,
            )
          }
        }
      }
      MethodDeclaration(name, func_expr, _) => {
        // Shorthand method declaration: { method() { ... } }
        let (method_type, c) = infer_function_expression_type(checker, func_expr)
        properties.set(name, {
          name,
          prop_type: method_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      GetAccessor(name, func_expr, _) => {
        // Getter accessor: { get prop() { ... } }
        let (getter_type, c) = infer_function_expression_type(checker, func_expr)
        // The property type is the return type of the getter
        let prop_type = match getter_type {
          Function(func_type) => func_type.return_type
          _ => getter_type
        }
        properties.set(name, {
          name,
          prop_type,
          is_optional: false,
          is_readonly: true, // Getters are read-only unless there's also a setter
        })
        checker = c
      }
      SetAccessor(name, func_expr, _) => {
        // Setter accessor: { set prop(value) { ... } }
        let (setter_type, c) = infer_function_expression_type(checker, func_expr)
        // The property type is the parameter type of the setter
        let prop_type = match setter_type {
          Function(func_type) =>
            if func_type.parameters.length() > 0 {
              func_type.parameters[0].param_type
            } else {
              let (t, _) = any_type(checker)
              t
            }
          _ => {
            let (t, _) = any_type(checker)
            t
          }
        }
        // Check if property already exists (from a getter)
        match properties.get(name) {
          Some(_) => () // Setter adds to existing getter, keep the getter's type
          None =>
            properties.set(name, {
              name,
              prop_type,
              is_optional: false,
              is_readonly: false,
            })
        }
        checker = c
      }
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
      class_name: None,
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
  // Push a new local scope for the arrow function
  let checker = push_local_scope(checker)

  // Enter arrow function context (for arguments check)
  let checker = enter_arrow_function(checker)

  // Track async function context for TS2465
  let checker = if arrow.is_async {
    enter_async_function(checker)
  } else {
    checker
  }

  // Build parameter list and add parameters to local scope
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
        // Add parameter to local scope
        let param_name = get_parameter_name(param.name)
        checker = add_local_variable(checker, param_name, param_type)
      }
      _ => ()
    }
  }

  // Get return type and check body
  let (return_type, checker) = match arrow.return_type {
    Some(type_node) => {
      // With explicit return type, still check the body for errors
      let checker = match arrow.body {
        BlockStatement(block) => check_block_statement(checker, block)
        _ => {
          let (_, c) = infer_type(checker, arrow.body)
          c
        }
      }
      match get_type_from_type_node(checker, type_node) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    }
    None =>
      // Infer from body
      match arrow.body {
        BlockStatement(block) => {
          // Check block body statements for errors
          let checker = check_block_statement(checker, block)
          void_type(checker) // Block returns void unless explicitly returning
        }
        _ => infer_type(checker, arrow.body)
      }
  }

  // Exit async function context if needed
  let checker = if arrow.is_async {
    exit_async_function(checker)
  } else {
    checker
  }

  // Exit arrow function context
  let checker = exit_arrow_function(checker)

  // Pop the local scope
  let checker = pop_local_scope(checker)

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
/// Check assignment compatibility with detailed error messages
fn check_assignment_compatibility(
  checker : TypeChecker,
  source : Type,
  target : Type,
  location : SourceLocation,
) -> TypeChecker {
  // Use detailed checking that produces specific error messages
  check_assignment_detailed(checker, source, target, location, "")
}

///|
/// Check assignment with detailed error reporting
fn check_assignment_detailed(
  checker : TypeChecker,
  source : Type,
  target : Type,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  // Handle special cases first
  match (source, target) {
    // Any is assignable to/from anything
    (Any(_), _) | (_, Any(_)) => return checker
    // Never is assignable to everything
    (Never(_), _) => return checker
    // Error type assignable to anything (to prevent cascading errors)
    (Error(_), _) | (_, Error(_)) => return checker
    // Unknown is only assignable to unknown or any
    (_, Unknown(_)) => return checker
    (Unknown(_), Unknown(_)) => return checker
    // Nothing is assignable to never
    (_, Never(_)) =>
      return add_diagnostic_with_code(
        checker,
        "Type '\{type_to_string(source)}' is not assignable to type 'never'",
        location,
        TS2322,
      )
    _ => ()
  }

  // Check object types with detailed property checking
  match (source, target) {
    (Object(source_obj), Object(target_obj)) =>
      return check_object_assignability_detailed(
        checker, source_obj, target_obj, location, path,
      )
    _ => ()
  }

  // Check union types with discriminant checking
  match target {
    Union(union) =>
      return check_union_assignability_detailed(
        checker, source, union, location, path,
      )
    _ => ()
  }

  // Check intersection types
  match target {
    Intersection(intersection) =>
      return check_intersection_assignability_detailed(
        checker, source, intersection, location, path,
      )
    _ => ()
  }

  // Check array types with element checking
  match (source, target) {
    (Type::Array(source_arr), Type::Array(target_arr)) =>
      return check_array_assignability_detailed(
        checker, source_arr, target_arr, location, path,
      )
    _ => ()
  }

  // Check function types
  match (source, target) {
    (Type::Function(source_fn), Type::Function(target_fn)) =>
      return check_function_assignability_detailed(
        checker, source_fn, target_fn, location, path,
      )
    _ => ()
  }

  // Check tuple types
  match (source, target) {
    (Tuple(source_tuple), Tuple(target_tuple)) =>
      return check_tuple_assignability_detailed(
        checker, source_tuple, target_tuple, location, path,
      )
    _ => ()
  }

  // Fall back to simple assignability check
  if is_assignable(source, target) {
    checker
  } else {
    let msg = if path == "" {
      "Type '\{type_to_string(source)}' is not assignable to type '\{type_to_string(target)}'"
    } else {
      "Type '\{type_to_string(source)}' is not assignable to type '\{type_to_string(target)}' at \{path}"
    }
    add_diagnostic_with_code(checker, msg, location, TS2322)
  }
}

///|
/// Check object assignability with detailed property error reporting
fn check_object_assignability_detailed(
  checker : TypeChecker,
  source : ObjectType,
  target : ObjectType,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  let mut checker = checker

  // Check that all required properties in target exist in source with compatible types
  for entry in target.properties {
    let (prop_name, target_prop) = entry
    let prop_path = if path == "" { prop_name } else { "\{path}.\{prop_name}" }
    match source.properties.get(prop_name) {
      Some(source_prop) =>
        // Check property type compatibility recursively
        checker = check_assignment_detailed(
          checker,
          source_prop.prop_type,
          target_prop.prop_type,
          location,
          prop_path,
        )
      None =>
        // Property missing
        if not(target_prop.is_optional) {
          checker = add_diagnostic_with_code(
            checker,
            "Property '\{prop_name}' is missing in type '\{type_to_string(Object(source))}' but required in type '\{type_to_string(Object(target))}'",
            location,
            TS2322,
          )
        }
    }
  }

  // Check index signatures if target has one
  for index_sig in target.index_signatures {
    // All source properties must conform to target index signature
    for entry in source.properties {
      let (prop_name, source_prop) = entry
      // Skip properties already defined in target (they have their own types)
      if target.properties.get(prop_name) is None {
        if not(is_assignable(source_prop.prop_type, index_sig.return_type)) {
          checker = add_diagnostic_with_code(
            checker,
            "Property '\{prop_name}' of type '\{type_to_string(source_prop.prop_type)}' is not assignable to index signature type '\{type_to_string(index_sig.return_type)}'",
            location,
            TS2322,
          )
        }
      }
    }
  }
  checker
}

///|
/// Check union assignability with discriminant analysis
fn check_union_assignability_detailed(
  checker : TypeChecker,
  source : Type,
  union : CheckerUnionType,
  location : SourceLocation,
  _path : String,
) -> TypeChecker {
  // Check if source is assignable to any member of the union
  for union_type in union.types {
    if is_assignable(source, union_type) {
      return checker
    }
  }

  // If source is an object, try discriminated union checking
  match source {
    Object(source_obj) => {
      // Look for discriminant properties (literal type properties like "kind")
      let discriminants = find_discriminant_properties(union)
      for discriminant in discriminants {
        match source_obj.properties.get(discriminant) {
          Some(source_prop) => {
            // Check if source's discriminant value matches any union member
            let matching = find_union_members_by_discriminant(
              union,
              discriminant,
              source_prop.prop_type,
            )
            if matching.is_empty() {
              return add_diagnostic_with_code(
                checker,
                "Type '\{type_to_string(source_prop.prop_type)}' is not assignable to discriminant property '\{discriminant}'. Expected one of: \{format_discriminant_values(union, discriminant)}",
                location,
                TS2322,
              )
            }
          }
          None => ()
        }
      }
    }
    _ => ()
  }

  // No union member matches
  add_diagnostic_with_code(
    checker,
    "Type '\{type_to_string(source)}' is not assignable to type '\{type_to_string(Union(union))}'",
    location,
    TS2322,
  )
}

///|
/// Find discriminant properties in a union (properties that are literal types)
fn find_discriminant_properties(union : CheckerUnionType) -> Array[String] {
  let result : Array[String] = []
  let candidates : Map[String, Int] = Map::new()

  // Find properties that appear in all object members with literal types
  for union_type in union.types {
    match union_type {
      Object(obj) =>
        for entry in obj.properties {
          let (name, prop) = entry
          // Check if property has a literal type
          match prop.prop_type {
            StringLiteral(_, _) | NumberLiteral(_, _) | BooleanLiteral(_, _) => {
              let count = candidates.get(name).unwrap_or(0)
              candidates.set(name, count + 1)
            }
            _ => ()
          }
        }
      _ => ()
    }
  }

  // Properties that appear in multiple members are good discriminants
  for entry in candidates {
    let (name, count) = entry
    if count >= 2 {
      result.push(name)
    }
  }
  result
}

///|
/// Find union members that have a specific discriminant value
fn find_union_members_by_discriminant(
  union : CheckerUnionType,
  prop_name : String,
  value : Type,
) -> Array[Type] {
  let result : Array[Type] = []
  for union_type in union.types {
    match union_type {
      Object(obj) =>
        match obj.properties.get(prop_name) {
          Some(prop) =>
            if is_assignable(value, prop.prop_type) {
              result.push(union_type)
            }
          None => ()
        }
      _ => ()
    }
  }
  result
}

///|
/// Format expected discriminant values for error message
fn format_discriminant_values(
  union : CheckerUnionType,
  prop_name : String,
) -> String {
  let values : Array[String] = []
  for union_type in union.types {
    match union_type {
      Object(obj) =>
        match obj.properties.get(prop_name) {
          Some(prop) => values.push(type_to_string(prop.prop_type))
          None => ()
        }
      _ => ()
    }
  }
  values.join(" | ")
}

///|
/// Check intersection assignability
fn check_intersection_assignability_detailed(
  checker : TypeChecker,
  source : Type,
  intersection : CheckerIntersectionType,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  let mut checker = checker

  // Source must be assignable to ALL members of the intersection
  for i = 0; i < intersection.types.length(); i = i + 1 {
    let intersect_type = intersection.types[i]
    checker = check_assignment_detailed(
      checker, source, intersect_type, location, path,
    )
  }
  checker
}

///|
/// Check array assignability with element type checking
fn check_array_assignability_detailed(
  checker : TypeChecker,
  source : CheckerArrayType,
  target : CheckerArrayType,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  let elem_path = if path == "" { "[element]" } else { "\{path}[element]" }
  check_assignment_detailed(
    checker,
    source.element_type,
    target.element_type,
    location,
    elem_path,
  )
}

///|
/// Check function assignability with parameter and return type checking
fn check_function_assignability_detailed(
  checker : TypeChecker,
  source : CheckerFunctionType,
  target : CheckerFunctionType,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  let mut checker = checker

  // Return type must be assignable (covariant)
  let ret_path = if path == "" { "return" } else { "\{path}.return" }
  checker = check_assignment_detailed(
    checker,
    source.return_type,
    target.return_type,
    location,
    ret_path,
  )

  // Parameters are contravariant - target params must be assignable to source
  if source.parameters.length() < target.parameters.length() {
    checker = add_diagnostic_with_code(
      checker,
      "Function has fewer parameters (\{source.parameters.length()}) than required (\{target.parameters.length()})",
      location,
      TS2322,
    )
  }
  for i = 0; i < target.parameters.length(); i = i + 1 {
    if i < source.parameters.length() {
      let param_path = if path == "" {
        "parameter '\{target.parameters[i].name}'"
      } else {
        "\{path}.parameter '\{target.parameters[i].name}'"
      }
      // Contravariant: target param type must be assignable to source param type
      checker = check_assignment_detailed(
        checker,
        target.parameters[i].param_type,
        source.parameters[i].param_type,
        location,
        param_path,
      )
    }
  }
  checker
}

///|
/// Check tuple assignability
fn check_tuple_assignability_detailed(
  checker : TypeChecker,
  source : CheckerTupleType,
  target : CheckerTupleType,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  let mut checker = checker

  // Count required elements in target
  let mut target_required = 0
  for elem in target.element_types {
    if not(elem.is_optional) && not(elem.is_rest) {
      target_required = target_required + 1
    }
  }

  // Source must have at least as many elements as target required
  if source.element_types.length() < target_required {
    checker = add_diagnostic_with_code(
      checker,
      "Tuple has fewer elements (\{source.element_types.length()}) than required (\{target_required})",
      location,
      TS2322,
    )
    return checker
  }

  // Check element-wise assignability
  for i = 0; i < target.element_types.length(); i = i + 1 {
    if i < source.element_types.length() {
      let elem_path = if path == "" { "[\{i}]" } else { "\{path}[\{i}]" }
      checker = check_assignment_detailed(
        checker,
        source.element_types[i].element_type,
        target.element_types[i].element_type,
        location,
        elem_path,
      )
    }
  }
  checker
}

///|
/// Convert binary operator to string for error messages
fn binary_operator_to_string(op : BinaryOperator) -> String {
  match op {
    Add => "+"
    Subtract => "-"
    Multiply => "*"
    Divide => "/"
    Remainder => "%"
    Exponentiate => "**"
    BitwiseAnd => "&"
    BitwiseOr => "|"
    BitwiseXor => "^"
    LeftShift => "<<"
    RightShift => ">>"
    UnsignedRightShift => ">>>"
    LogicalAnd => "&&"
    LogicalOr => "||"
    _ => "operator"
  }
}

///|
/// Check numeric operands
/// Emits TS2365: Operator 'X' cannot be applied to types 'Y' and 'Z'
fn check_numeric_operands(
  checker : TypeChecker,
  left : Type,
  right : Type,
  operator : BinaryOperator,
  location : SourceLocation,
) -> TypeChecker {
  let left_is_numeric = is_numeric_type(left)
  let right_is_numeric = is_numeric_type(right)

  // If both operands are non-numeric or one is non-numeric, emit TS2365
  if not(left_is_numeric) || not(right_is_numeric) {
    let op_str = binary_operator_to_string(operator)
    let left_str = type_to_string(left)
    let right_str = type_to_string(right)
    add_diagnostic_with_code(
      checker,
      "Operator '\{op_str}' cannot be applied to types '\{left_str}' and '\{right_str}'",
      location,
      TS2365,
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
    add_diagnostic_with_code(
      checker,
      "Operand must be of type 'number'",
      location,
      TS2363,
    )
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
/// Check instanceof operands (TS2358, TS2359)
fn check_instanceof_operands(
  checker : TypeChecker,
  left_type : Type,
  right_type : Type,
  bin_expr : BinaryExpression,
) -> TypeChecker {
  // TS2358: Left-hand side must be of type 'any', an object type or a type parameter
  let checker = match left_type {
    Any(_) | Unknown(_) | Object(_) | TypeReference(_) | Array(_) | Null(_) =>
      checker
    Number(_) | Boolean(_) | String(_) | Void(_) | Undefined(_) | NumberLiteral(
      _,
      _,
    ) | StringLiteral(_, _) | BooleanLiteral(_, _) =>
      add_diagnostic_with_code(
        checker,
        "The left-hand side of an 'instanceof' expression must be of type 'any', an object type or a type parameter, but here has type '\{type_to_string(left_type)}'",
        get_node_location(bin_expr.left),
        TS2358,
      )
    _ => checker // Allow other types that might be object-like
  }

  // TS2359: Right-hand side must be of type 'any' or Function type
  match right_type {
    Any(_) | Function(_) | TypeReference(_) => checker
    Number(_) | Boolean(_) | String(_) | Void(_) | Undefined(_) | Null(_) | NumberLiteral(
      _,
      _,
    ) | StringLiteral(_, _) | BooleanLiteral(_, _) =>
      add_diagnostic_with_code(
        checker,
        "The right-hand side of an 'instanceof' expression must be of type 'any' or of a type assignable to the 'Function' interface type, but here has type '\{type_to_string(right_type)}'",
        get_node_location(bin_expr.right),
        TS2359,
      )
    _ => checker // Allow other types that might be constructors
  }
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
  // Clear any narrowed types from outer scope before entering function body
  let saved_narrowed_types = checker.narrowed_types
  let checker = clear_narrowed_types(checker)

  // Push a new local scope for the function
  let checker = push_local_scope(checker)

  // Add function parameters to the local scope
  // Also check rest parameters have array type (TS2370)
  let mut checker = checker
  for param in func.parameters {
    checker = add_parameter_to_scope(checker, param)
    // Check TS2370: rest parameter must have array type
    match param {
      Parameter(p) =>
        if p.is_rest {
          match p.type_annotation {
            Some(type_node) =>
              match get_type_from_type_node(checker, type_node) {
                (Some(param_type), c) => {
                  checker = c
                  // Check if type is array
                  let is_array = match param_type {
                    Array(_) => true
                    TypeReference(ref_type) => ref_type.name == "Array"
                    _ => false
                  }
                  if not(is_array) {
                    checker = add_diagnostic_with_code(
                      checker,
                      "A rest parameter must be of an array type",
                      p.location,
                      TS2370,
                    )
                  }
                }
                (None, c) => checker = c
              }
            None => ()
          }
        }
      _ => ()
    }
  }

  // Track async function context for TS2465
  let checker = if func.is_async {
    enter_async_function(checker)
  } else {
    checker
  }

  // Check function body first (so variables are declared in scope)
  let checker = match func.body {
    Some(body) => check_statement(checker, body)
    None => checker
  }

  // Exit async function context
  let checker = if func.is_async {
    exit_async_function(checker)
  } else {
    checker
  }

  // Check return type consistency if a return type is declared
  // This must happen AFTER body is checked so variables are in scope
  let checker = match func.return_type {
    Some(return_type_node) =>
      match get_type_from_type_node(checker, return_type_node) {
        (Some(declared_return), c) =>
          check_return_type_consistency(c, func, declared_return)
        (None, c) => c
      }
    None => checker
  }

  // Pop the local scope
  let checker = pop_local_scope(checker)

  // Restore narrowed types after exiting function
  { ..checker, narrowed_types: saved_narrowed_types }
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
/// Check for-in statement
/// Validates TS2406: Left-hand side must be a variable
/// Validates TS2407: Right-hand side must be an object type
fn check_for_in_statement(
  checker : TypeChecker,
  for_in_stmt : ForInStatement,
) -> TypeChecker {
  // Check the right-hand side expression type (TS2407)
  let (expr_type, checker) = infer_type(checker, for_in_stmt.expression)
  let checker = match expr_type {
    Any(_) | Unknown(_) | Object(_) | TypeReference(_) | Array(_) => checker // Valid types for for...in
    _ =>
      add_diagnostic_with_code(
        checker,
        "The right-hand side of a 'for...in' statement must be of type 'any', an object type or a type parameter, but here has type '\{type_to_string(expr_type)}'",
        get_node_location(for_in_stmt.expression),
        TS2407,
      )
  }

  // Push scope for loop variable
  let checker = push_local_scope(checker)

  // Add the loop variable to scope - for-in keys are always strings
  let checker = add_for_in_variable_to_scope(checker, for_in_stmt.initializer)

  // Check the body statement
  let checker = check_statement(checker, for_in_stmt.statement)

  // Pop the loop scope
  pop_local_scope(checker)
}

///|
/// Add the for-in loop variable to scope with string type
fn add_for_in_variable_to_scope(
  checker : TypeChecker,
  initializer : Node,
) -> TypeChecker {
  let (str_type, checker) = string_type(checker)
  match initializer {
    VariableStatement(var_stmt) => {
      // Handle: for (const key in obj)
      if var_stmt.declarations.length() > 0 {
        let decl = var_stmt.declarations[0]
        match decl.name {
          Identifier(id) => add_local_variable(checker, id.name, str_type)
          _ => checker
        }
      } else {
        checker
      }
    }
    Identifier(_) =>
      // Handle: for (key in obj) where key was previously declared
      checker
    _ => checker
  }
}

///|
/// Check for-of statement
/// Validates that right-hand side is iterable (array, string, or has [Symbol.iterator])
fn check_for_of_statement(
  checker : TypeChecker,
  for_of_stmt : ForOfStatement,
) -> TypeChecker {
  // Infer the type of the iterable expression
  let (iterable_type, checker) = infer_type(checker, for_of_stmt.expression)

  // Push scope for loop variable
  let checker = push_local_scope(checker)

  // Add the loop variable to scope with the element type
  let checker = add_for_of_variable_to_scope(
    checker,
    for_of_stmt.initializer,
    iterable_type,
  )

  // Check the body statement
  let checker = check_statement(checker, for_of_stmt.statement)

  // Pop the loop scope
  pop_local_scope(checker)
}

///|
/// Add the for-of loop variable to scope with the element type
fn add_for_of_variable_to_scope(
  checker : TypeChecker,
  initializer : Node,
  iterable_type : Type,
) -> TypeChecker {
  // Get the element type from the iterable
  let (elem_type, checker) = get_for_of_element_type(checker, iterable_type)
  match initializer {
    VariableStatement(var_stmt) => {
      // Handle: for (const item of arr)
      if var_stmt.declarations.length() > 0 {
        let decl = var_stmt.declarations[0]
        match decl.name {
          Identifier(id) => add_local_variable(checker, id.name, elem_type)
          _ => checker
        }
      } else {
        checker
      }
    }
    Identifier(_) =>
      // Handle: for (item of arr) where item was previously declared
      checker
    _ => checker
  }
}

///|
/// Get the element type of an iterable for for-of loops
fn get_for_of_element_type(
  checker : TypeChecker,
  iterable_type : Type,
) -> (Type, TypeChecker) {
  match iterable_type {
    Array(arr) => (arr.element_type, checker)
    String(_) => string_type(checker) // Iterating string produces strings
    _ => any_type(checker) // Fallback to any
  }
}

///|
/// Scan statements for block-scoped (let/const) declarations
/// Returns a map of variable name -> declaration line number
fn scan_block_scoped_declarations(statements : Array[Node]) -> Map[String, Int] {
  let decls : Map[String, Int] = Map::new()
  for stmt in statements {
    match stmt {
      VariableStatement(vs) =>
        // Check if this is let or const (block-scoped)
        if vs.is_let || vs.is_const {
          for vd in vs.declarations {
            match vd.name {
              Identifier(id) => decls.set(id.name, vd.location.start.line)
              _ => () // Skip destructuring for now
            }
          }
        }
      _ => ()
    }
  }
  decls
}

///|
/// Check block statement
fn check_block_statement(
  checker : TypeChecker,
  block : BlockStatement,
) -> TypeChecker {
  // Check for unreachable code first
  let checker = check_unreachable_code(checker, block.statements)

  // Scan for block-scoped declarations (TS2448 TDZ check)
  let block_decls = scan_block_scoped_declarations(block.statements)

  // Save old block_scoped_decls and set new ones for this block
  let old_decls = checker.block_scoped_decls
  let checker = { ..checker, block_scoped_decls: block_decls }

  // Then check all statements
  let checker = check_statements(checker, block.statements)

  // Restore old block_scoped_decls
  { ..checker, block_scoped_decls: old_decls }
}

///|
/// Check if a class is a derived class (has extends clause)
fn is_derived_class(class_decl : ClassDeclaration) -> Bool {
  for clause in class_decl.heritage_clauses {
    if clause.kind == Extends {
      return true
    }
  }
  false
}

///|
/// Check if a constructor body contains a super() call
fn contains_super_call(node : Node) -> Bool {
  match node {
    CallExpression(ce) =>
      match ce.expression {
        SuperExpression(_) => true
        _ => {
          // Check arguments and expression
          if contains_super_call(ce.expression) {
            return true
          }
          for arg in ce.arguments {
            if contains_super_call(arg) {
              return true
            }
          }
          false
        }
      }
    BlockStatement(bs) => {
      for stmt in bs.statements {
        if contains_super_call(stmt) {
          return true
        }
      }
      false
    }
    ExpressionStatement(es) => contains_super_call(es.expression)
    IfStatement(if_stmt) => {
      if contains_super_call(if_stmt.then_statement) {
        return true
      }
      match if_stmt.else_statement {
        Some(else_stmt) => contains_super_call(else_stmt)
        None => false
      }
    }
    ReturnStatement(rs) =>
      match rs.expression {
        Some(expr) => contains_super_call(expr)
        None => false
      }
    _ => false
  }
}

///|
/// Check for super() call requirement in derived class constructor (TS2377)
fn check_super_call_in_constructor(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
  body : Node,
  location : SourceLocation,
) -> TypeChecker {
  // Only check if this is a derived class (has extends clause)
  if not(is_derived_class(class_decl)) {
    return checker
  }

  // Check if constructor body contains super() call
  if contains_super_call(body) {
    return checker
  }

  // Emit TS2377 error
  add_diagnostic_with_code(
    checker,
    "Constructors for derived classes must contain a 'super' call.",
    location,
    TS2377,
  )
}

///|
/// Check class declaration
fn check_class_declaration(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
) -> TypeChecker {
  // Build the class type so we can set current_this_type
  let (class_type, checker) = build_class_type_for_this(checker, class_decl)

  // Save previous this type and set current_this_type to class type
  let prev_this_type = checker.current_this_type
  let mut checker = { ..checker, current_this_type: Some(class_type) }

  // Collect uninitialized properties for definite assignment checking
  let uninitialized_props : Map[String, SourceLocation] = Map::new()
  for mem in class_decl.members {
    match mem {
      PropertyDeclaration(prop) =>
        if prop.initializer.is_none() {
          // Property without initializer - needs to be assigned in constructor
          uninitialized_props.set(prop.name, prop.location)
        }
      _ => ()
    }
  }

  // Check class members (constructors, methods, properties)
  for i = 0; i < class_decl.members.length(); i = i + 1 {
    checker = match class_decl.members[i] {
      ConstructorDeclaration(ctor) =>
        match ctor.body {
          Some(body) => {
            // Push local scope for constructor
            let checker = push_local_scope(checker)
            // Add constructor parameters to scope
            let mut checker = checker
            for param in ctor.parameters {
              checker = add_parameter_to_scope(checker, param)
            }
            // Check for property use before assignment (TS2565)
            let checker = check_property_use_before_assignment(
              checker,
              body,
              uninitialized_props,
            )
            let checker = check_statement(checker, body)
            // Check for super() call in derived class constructor (TS2377)
            let checker = check_super_call_in_constructor(
              checker,
              class_decl,
              body,
              ctor.location,
            )
            // Pop local scope
            pop_local_scope(checker)
          }
          None => checker
        }
      MethodDeclaration(method_dec) =>
        match method_dec.body {
          Some(body) => {
            // Push local scope for method
            let checker = push_local_scope(checker)
            // Track async function context for TS2465
            let checker = if method_dec.is_async {
              enter_async_function(checker)
            } else {
              checker
            }
            // Add method parameters to scope
            let mut checker = checker
            for param in method_dec.parameters {
              checker = add_parameter_to_scope(checker, param)
            }
            let checker = check_statement(checker, body)
            // Exit async function context if needed
            let checker = if method_dec.is_async {
              exit_async_function(checker)
            } else {
              checker
            }
            // Pop local scope
            pop_local_scope(checker)
          }
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

  // Restore previous this type
  { ..checker, current_this_type: prev_this_type }
}

///|
/// Check for property use before assignment in constructor (TS2565)
fn check_property_use_before_assignment(
  checker : TypeChecker,
  body : Node,
  uninitialized_props : Map[String, SourceLocation],
) -> TypeChecker {
  // Track which properties have been assigned
  let assigned_props : Map[String, Bool] = Map::new()

  // Scan the constructor body for this.prop accesses
  check_this_property_accesses(checker, body, uninitialized_props, assigned_props)
}

///|
/// Recursively check for this.prop accesses and track assignments
fn check_this_property_accesses(
  checker : TypeChecker,
  node : Node,
  uninitialized_props : Map[String, SourceLocation],
  assigned_props : Map[String, Bool],
) -> TypeChecker {
  let mut checker = checker
  match node {
    // Assignment to this.prop
    BinaryExpression(bin) =>
      if bin.operator == BinaryOperator::Assign {
        match bin.left {
          PropertyAccessExpression(pa) =>
            match pa.expression {
              ThisExpression(_) => {
                // This is an assignment: this.prop = value
                // First check the right side (may read properties)
                checker = check_this_property_accesses(
                  checker,
                  bin.right,
                  uninitialized_props,
                  assigned_props,
                )
                // Then mark the property as assigned
                assigned_props.set(pa.name, true)
                checker
              }
              _ => {
                // Not a this.prop assignment, check both sides
                checker = check_this_property_accesses(
                  checker,
                  bin.left,
                  uninitialized_props,
                  assigned_props,
                )
                check_this_property_accesses(
                  checker,
                  bin.right,
                  uninitialized_props,
                  assigned_props,
                )
              }
            }
          _ => {
            checker = check_this_property_accesses(
              checker,
              bin.left,
              uninitialized_props,
              assigned_props,
            )
            check_this_property_accesses(
              checker,
              bin.right,
              uninitialized_props,
              assigned_props,
            )
          }
        }
      } else {
        // Non-assignment binary expression
        checker = check_this_property_accesses(
          checker,
          bin.left,
          uninitialized_props,
          assigned_props,
        )
        check_this_property_accesses(
          checker,
          bin.right,
          uninitialized_props,
          assigned_props,
        )
      }
    // Read of this.prop
    PropertyAccessExpression(pa) =>
      match pa.expression {
        ThisExpression(_) => {
          // Reading this.prop - check if it's assigned
          if uninitialized_props.contains(pa.name) &&
            not(assigned_props.get(pa.name).unwrap_or(false)) {
            // Property is used before being assigned
            add_diagnostic_with_code(
              checker,
              "Property '" + pa.name + "' is used before being assigned.",
              pa.location,
              TS2565,
            )
          } else {
            checker
          }
        }
        _ =>
          // Check the expression part
          check_this_property_accesses(
            checker,
            pa.expression,
            uninitialized_props,
            assigned_props,
          )
      }
    // Call expression - check all arguments and the callee
    CallExpression(call) => {
      checker = check_this_property_accesses(
        checker,
        call.expression,
        uninitialized_props,
        assigned_props,
      )
      for arg in call.arguments {
        checker = check_this_property_accesses(
          checker,
          arg,
          uninitialized_props,
          assigned_props,
        )
      }
      checker
    }
    // Expression statement
    ExpressionStatement(es) =>
      check_this_property_accesses(
        checker,
        es.expression,
        uninitialized_props,
        assigned_props,
      )
    // Block - process statements in order
    BlockStatement(block) => {
      for stmt in block.statements {
        checker = check_this_property_accesses(
          checker,
          stmt,
          uninitialized_props,
          assigned_props,
        )
      }
      checker
    }
    // Variable declaration
    VariableStatement(vs) => {
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) =>
            checker = check_this_property_accesses(
              checker,
              init,
              uninitialized_props,
              assigned_props,
            )
          None => ()
        }
      }
      checker
    }
    // Return statement
    ReturnStatement(ret) =>
      match ret.expression {
        Some(expr) =>
          check_this_property_accesses(
            checker,
            expr,
            uninitialized_props,
            assigned_props,
          )
        None => checker
      }
    // If statement
    IfStatement(if_stmt) => {
      checker = check_this_property_accesses(
        checker,
        if_stmt.condition,
        uninitialized_props,
        assigned_props,
      )
      checker = check_this_property_accesses(
        checker,
        if_stmt.then_statement,
        uninitialized_props,
        assigned_props,
      )
      match if_stmt.else_statement {
        Some(else_stmt) =>
          check_this_property_accesses(
            checker,
            else_stmt,
            uninitialized_props,
            assigned_props,
          )
        None => checker
      }
    }
    _ => checker
  }
}

///|
/// Simple type compatibility check (without detailed error messages)
fn is_simple_type_compatible(source : Type, target : Type) -> Bool {
  match (source, target) {
    // Any is compatible with anything
    (Any(_), _) | (_, Any(_)) => true
    // Never is compatible with everything
    (Never(_), _) => true
    // Unknown is compatible with unknown
    (Unknown(_), Unknown(_)) => true
    // Same primitive types
    (Number(_), Number(_)) => true
    (String(_), String(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Void(_), Void(_)) => true
    (Undefined(_), Undefined(_)) => true
    (Null(_), Null(_)) => true
    (Symbol(_), Symbol(_)) => true
    // Literal types compatible with their base types
    (NumberLiteral(_, _), Number(_)) => true
    (StringLiteral(_, _), String(_)) => true
    (BooleanLiteral(_, _), Boolean(_)) => true
    // Same literal values
    (NumberLiteral(v1, _), NumberLiteral(v2, _)) => v1 == v2
    (StringLiteral(v1, _), StringLiteral(v2, _)) => v1 == v2
    (BooleanLiteral(v1, _), BooleanLiteral(v2, _)) => v1 == v2
    // Union target: source is compatible if it's compatible with any union member
    (_, Union(union_type)) => {
      for t in union_type.types {
        if is_simple_type_compatible(source, t) {
          return true
        }
      }
      false
    }
    // Objects are loosely compatible (avoid false positives)
    (Object(_), Object(_)) => true
    // Different types
    _ => false
  }
}

///|
/// Check interface declaration - validates index signature parameter types
/// and property compatibility with index signatures
fn check_interface_declaration(
  checker : TypeChecker,
  iface_decl : InterfaceDeclaration,
) -> TypeChecker {
  let mut checker = checker
  // First pass: collect index signature return types and validate param types
  let string_index_type : Ref[Type?] = { val: None }
  for interface_member in iface_decl.members {
    match interface_member {
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
        // TS2716: Validate that param_type is string, number, or symbol
        checker = match param_type {
          String(_) | Number(_) | Symbol(_) => checker
          _ =>
            add_diagnostic_with_code(
              checker,
              "An index signature parameter type must be 'string', 'number', 'symbol', or a template literal type",
              idx_sig.location,
              TS2716,
            )
        }
        // Get the return type (value type) for property compatibility check
        let (ret_type, c) = match
          get_type_from_type_node(checker, idx_sig.return_type) {
          (Some(t), c2) => (t, c2)
          (None, c2) => {
            let (t, c3) = any_type(c2)
            (t, c3)
          }
        }
        checker = c
        // Store string index signature type for property checking
        match param_type {
          String(_) => string_index_type.val = Some(ret_type)
          _ => ()
        }
      }
      _ => ()
    }
  }
  // Second pass: check property types against index signature
  match string_index_type.val {
    Some(idx_ret_type) => {
      for interface_member in iface_decl.members {
        match interface_member {
          PropertyDeclaration(prop) => {
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
            // TS2745: Check if property type is assignable to index signature type
            let is_compatible = is_simple_type_compatible(prop_type, idx_ret_type)
            if not(is_compatible) {
              checker = add_diagnostic_with_code(
                checker,
                "Property '\{prop.name}' of type '\{type_to_string(prop_type)}' is not assignable to '\{type_to_string(idx_ret_type)}' index type '\{type_to_string(idx_ret_type)}'",
                prop.location,
                TS2745,
              )
            }
          }
          _ => ()
        }
      }
    }
    None => ()
  }
  // TS2746: Check for conflicting property declarations in extended interfaces
  checker = check_interface_heritage_conflicts(checker, iface_decl)
  checker
}

///|
/// Check for conflicting property declarations in interface extends clause
fn check_interface_heritage_conflicts(
  checker : TypeChecker,
  iface_decl : InterfaceDeclaration,
) -> TypeChecker {
  let mut checker = checker
  // Collect properties from all base interfaces
  let base_properties : Map[String, (Type, String)] = Map::new() // name -> (type, source_interface)
  for heritage_clause in iface_decl.heritage_clauses {
    if heritage_clause.kind == Extends {
      for base_type_node in heritage_clause.types {
        // Get the interface name from the type node
        let base_name = match base_type_node {
          Identifier(id) => Some(id.name)
          TypeReference(type_ref) => Some(type_ref.type_name)
          _ => None
        }
        match base_name {
          Some(name) => {
            // Look up the interface symbol
            match lookup_symbol(checker, name) {
              Some(symbol) => {
                // Resolve the interface type
                let (base_type_opt, c) = resolve_interface_type(checker, symbol)
                checker = c
                match base_type_opt {
                  Some(Object(obj_type)) => {
                    // Check each property against already collected properties
                    for prop_entry in obj_type.properties {
                      let (prop_name, prop_sig) = prop_entry
                      match base_properties.get(prop_name) {
                        Some((existing_type, existing_source)) => {
                          // Check if types are compatible
                          if not(is_simple_type_compatible(prop_sig.prop_type, existing_type)) &&
                            not(is_simple_type_compatible(existing_type, prop_sig.prop_type)) {
                            checker = add_diagnostic_with_code(
                              checker,
                              "Property '\{prop_name}' has conflicting declarations and is inaccessible in type '\{iface_decl.name}' (from '\{existing_source}' and '\{name}')",
                              iface_decl.location,
                              TS2746,
                            )
                          }
                        }
                        None => {
                          // First time seeing this property
                          base_properties.set(
                            prop_name,
                            (prop_sig.prop_type, name),
                          )
                        }
                      }
                    }
                  }
                  _ => ()
                }
              }
              None => ()
            }
          }
          None => ()
        }
      }
    }
  }
  checker
}

///|
/// Check type alias declaration for TS2700 (rest types may only be from object types)
fn check_type_alias_declaration(
  checker : TypeChecker,
  type_alias : TypeAliasDeclaration,
) -> TypeChecker {
  check_type_node_for_rest_errors(checker, type_alias.type_node)
}

///|
/// Recursively check type nodes for rest/spread type errors
fn check_type_node_for_rest_errors(checker : TypeChecker, node : Node) -> TypeChecker {
  match node {
    TypeLiteral(tl) => {
      let mut checker = checker
      for type_member in tl.members {
        match type_member {
          SpreadExpression(spread_expr) => {
            // Check if spread target is an object type
            let (spread_type, c) = get_type_from_type_node(checker, spread_expr.expression)
            checker = c
            match spread_type {
              Some(Object(_)) | Some(Any(_)) | Some(Unknown(_)) | None => ()
              Some(_) =>
                checker = add_diagnostic_with_code(
                  checker,
                  "Rest types may only be created from object types",
                  spread_expr.location,
                  TS2700,
                )
            }
          }
          _ => ()
        }
      }
      checker
    }
    _ => checker
  }
}

///|
/// Build class type for 'this' context (without symbol caching)
fn build_class_type_for_this(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
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
  // Extract the class name from the name node
  let class_name_str = match class_decl.name {
    Some(Identifier(id)) => Some(id.name)
    _ => None
  }
  let class_type = Type::Object({
    properties,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info,
    class_name: class_name_str,
  })
  (class_type, checker)
}

///|
/// Check enum declaration
/// Validates enum members and their initializers
fn check_enum_declaration(
  checker : TypeChecker,
  enum_decl : EnumDeclaration,
) -> TypeChecker {
  check_enum_members(checker, enum_decl.members, enum_decl.is_const, 0)
}

///|
/// Check enum members recursively
fn check_enum_members(
  checker : TypeChecker,
  members : Array[EnumMember],
  is_const : Bool,
  index : Int,
) -> TypeChecker {
  if index >= members.length() {
    checker
  } else {
    let e_member = members[index]
    let checker = check_enum_member(checker, e_member, is_const)
    check_enum_members(checker, members, is_const, index + 1)
  }
}

///|
/// Check a single enum member
/// Validates that the initializer (if present) is a valid enum initializer
fn check_enum_member(
  checker : TypeChecker,
  member : EnumMember,
  is_const : Bool,
) -> TypeChecker {
  match member.initializer {
    Some(init) => {
      // Infer the type of the initializer
      let (init_type, checker) = infer_type(checker, init)
      // Validate the initializer type
      validate_enum_initializer(
        checker,
        init_type,
        init,
        member.location,
        is_const,
      )
    }
    None => checker // No initializer is valid (auto-incremented)
  }
}

///|
/// Validate that an enum initializer has a valid type
/// For const enums: must be a numeric or string literal
/// For regular enums: must be a number or string type
fn validate_enum_initializer(
  checker : TypeChecker,
  init_type : Type,
  init : Node,
  location : SourceLocation,
  is_const : Bool,
) -> TypeChecker {
  // Check if the initializer type is valid for an enum member
  if is_valid_enum_initializer_type(init_type) {
    // For const enums, we need to ensure the initializer is a compile-time constant
    if is_const {
      if is_const_enum_initializer(init) {
        checker
      } else {
        add_diagnostic_with_code(
          checker,
          "const enum member initializers can only contain literal values and other computed enum values",
          location,
          TS2474,
        )
      }
    } else {
      checker
    }
  } else {
    add_diagnostic_with_code(
      checker,
      "Type '\{type_to_string(init_type)}' is not assignable to type 'number' or 'string' for enum member",
      location,
      TS2322,
    )
  }
}

///|
/// Check if a type is valid for an enum initializer
/// Valid types are: number, string, or literal types
fn is_valid_enum_initializer_type(t : Type) -> Bool {
  match t {
    Number(_) => true
    String(_) => true
    NumberLiteral(_) => true
    StringLiteral(_) => true
    Any(_) => true // Allow any for flexibility
    _ => false
  }
}

///|
/// Check if an expression is a valid const enum initializer
/// Must be a literal value or reference to another enum member
fn is_const_enum_initializer(expr : Node) -> Bool {
  match expr {
    NumericLiteral(_) => true
    StringLiteral(_) => true
    UnaryExpression(un) =>
      // Allow unary minus on numeric literals (e.g., -1)
      match un.operator {
        Minus | Plus => is_const_enum_initializer(un.operand)
        _ => false
      }
    PropertyAccessExpression(_) => true // Allow references to other enum members
    Identifier(_) => true // Allow references to other enum members
    BinaryExpression(bin) =>
      // Allow binary expressions with literals (e.g., 1 + 2, 1 << 2)
      is_const_enum_initializer(bin.left) &&
      is_const_enum_initializer(bin.right)
    ParenthesizedExpression(paren) =>
      is_const_enum_initializer(paren.expression)
    _ => false
  }
}

///|
/// Check try statement
fn check_try_statement(
  checker : TypeChecker,
  try_stmt : TryStatement,
) -> TypeChecker {
  let checker = check_statement(checker, try_stmt.try_block)
  let checker = match try_stmt.catch_clause {
    Some(catch_clause) => {
      // Push a local scope for the catch block
      let checker = push_local_scope(checker)

      // Check type annotation if present (TS2467)
      let (catch_type, checker) = match catch_clause.type_annotation {
        Some(type_node) => {
          // Validate the type annotation is 'any' or 'unknown'
          match get_type_from_type_node(checker, type_node) {
            (Some(t), checker) => {
              let is_valid = match t {
                Any(_) | Unknown(_) => true
                _ => false
              }
              if is_valid {
                (t, checker)
              } else {
                // TS2467: Catch clause variable type must be 'any' or 'unknown'
                let var_name = match catch_clause.variable_declaration {
                  Some(Identifier(id)) => id.name
                  _ => "e"
                }
                let checker = add_diagnostic_with_code(
                  checker,
                  "Catch clause variable type annotation must be 'any' or 'unknown' if specified.",
                  get_node_location(type_node),
                  TS2467,
                )
                any_type(checker)
              }
            }
            (None, checker) => any_type(checker)
          }
        }
        None =>
          // No type annotation - default to 'any'
          any_type(checker)
      }

      // Add the catch clause variable to scope if present
      let checker = match catch_clause.variable_declaration {
        Some(var_decl) => {
          // The variable_declaration is typically an Identifier or BindingPattern
          match var_decl {
            Identifier(id) => add_local_variable(checker, id.name, catch_type)
            _ => checker
          }
        }
        None => checker
      }
      let checker = check_statement(checker, catch_clause.block)
      // Pop the local scope
      pop_local_scope(checker)
    }
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
                class_name: None,
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
    TypeLiteral(type_literal) => {
      // Handle object type literals: { prop: type; }
      let mut checker = checker
      let properties : Map[String, PropertySignature] = Map::new()
      let call_signatures : Array[CheckerSignature] = []
      let construct_signatures : Array[CheckerSignature] = []
      let index_signatures : Array[IndexSignature] = []

      for member in type_literal.members {
        match member {
          TypeLiteralProperty(tl_prop) => {
            // Get property type
            let (prop_type, c) = match tl_prop.type_node {
              Some(type_node) =>
                match get_type_from_type_node(checker, type_node) {
                  (Some(t), c2) => (t, c2)
                  (None, c2) => any_type(c2)
                }
              None => any_type(checker)
            }
            checker = c
            properties.set(tl_prop.name, {
              name: tl_prop.name,
              prop_type,
              is_optional: tl_prop.is_optional,
              is_readonly: tl_prop.is_readonly,
            })
          }
          PropertyDeclaration(prop_decl) => {
            // Get property type
            let (prop_type, c) = match prop_decl.type_annotation {
              Some(type_node) =>
                match get_type_from_type_node(checker, type_node) {
                  (Some(t), c2) => (t, c2)
                  (None, c2) => any_type(c2)
                }
              None => any_type(checker)
            }
            checker = c
            // Check if readonly modifier is present
            let is_readonly = prop_decl.modifiers.contains(Modifier::Readonly)
            properties.set(prop_decl.name, {
              name: prop_decl.name,
              prop_type,
              is_optional: prop_decl.is_optional,
              is_readonly,
            })
          }
          IndexSignatureDeclaration(idx_sig) => {
            // Get parameter type (string or number)
            let (param_type, c) = match get_type_from_type_node(checker, idx_sig.parameter_type) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
            checker = c
            // Get return type (return_type is Node, not Node?)
            let (return_type, c) = match get_type_from_type_node(checker, idx_sig.return_type) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
            checker = c
            index_signatures.push({
              parameter_name: idx_sig.parameter_name,
              parameter_type: param_type,
              return_type,
              is_readonly: idx_sig.is_readonly,
            })
          }
          MethodDeclaration(method_decl) => {
            // Handle method signatures
            let (method_type, c) = get_method_signature_type(checker, method_decl)
            checker = c
            properties.set(method_decl.name, {
              name: method_decl.name,
              prop_type: method_type,
              is_optional: method_decl.is_optional,
              is_readonly: false,
            })
          }
          _ => ()
        }
      }

      let (info, checker) = create_type_info(checker)
      (
        Some(
          Object({
            properties,
            call_signatures,
            construct_signatures,
            index_signatures,
            info,
            class_name: None,
          }),
        ),
        checker,
      )
    }
    FunctionType(func_type) => {
      // Handle function type annotations: (x: number) => string
      let mut checker = checker
      let parameters : Array[CheckerParameter] = []

      // Convert each parameter
      for param in func_type.parameters {
        match param {
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
      let (return_type, checker) = match get_type_from_type_node(
        checker,
        func_type.return_type,
      ) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }

      let (info, checker) = create_type_info(checker)
      (Some(Type::Function({ parameters, return_type, info })), checker)
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
/// Get type for a method signature in type literal
fn get_method_signature_type(
  checker : TypeChecker,
  method_decl : MethodDeclaration,
) -> (Type, TypeChecker) {
  // Build parameters
  let mut checker = checker
  let parameters : Array[CheckerParameter] = []

  for param in method_decl.parameters {
    match param {
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
    Some(rt) =>
      match get_type_from_type_node(checker, rt) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    None => any_type(checker)
  }

  let (info, checker) = create_type_info(checker)
  (Function({ parameters, return_type, info }), checker)
}

///|
/// Add a diagnostic with DiagnosticCode enum
fn add_diagnostic_with_code(
  checker : TypeChecker,
  message : String,
  location : SourceLocation,
  code : DiagnosticCode,
) -> TypeChecker {
  let diag = Diagnostic::error_with_code(message, location, code)
  let new_diagnostics = checker.diagnostics
  new_diagnostics.push(diag)
  { ..checker, diagnostics: new_diagnostics }
}

///|
/// Get node location
fn get_node_location(node : Node) -> SourceLocation {
  get_location(node)
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
/// Handles qualified names like Foo.Bar.Baz by resolving step by step
fn lookup_symbol(checker : TypeChecker, name : String) -> Symbol? {
  // Check if this is a qualified name (contains dots)
  if name.contains(".") {
    // Split by dots and resolve step by step
    lookup_qualified_symbol(checker, name)
  } else {
    // Simple name lookup
    match checker.global_scope {
      Some(scope) => scope.symbols.get(name)
      None => None
    }
  }
}

///|
/// Split a string by dots into parts
pub fn split_by_dot(name : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current = ""
  for c in name {
    if c == '.' {
      if current.length() > 0 {
        parts.push(current)
        current = ""
      }
    } else {
      current = current + c.to_string()
    }
  }
  if current.length() > 0 {
    parts.push(current)
  }
  parts
}

///|
/// Look up a qualified symbol like Foo.Bar.Baz
/// First looks up Foo, then Bar in Foo's exports/members, etc.
fn lookup_qualified_symbol(checker : TypeChecker, qualified_name : String) -> Symbol? {
  let parts = split_by_dot(qualified_name)
  if parts.length() == 0 {
    return None
  }

  // Look up the first part in global scope
  let first_part = parts[0]
  let mut current_symbol : Symbol? = match checker.global_scope {
    Some(scope) => scope.symbols.get(first_part)
    None => None
  }

  // Resolve remaining parts
  for i = 1; i < parts.length(); i = i + 1 {
    match current_symbol {
      None => return None
      Some(sym) => {
        let part = parts[i]
        // Try exports first (for namespaces/modules)
        current_symbol = match sym.exports {
          Some(exports) =>
            match exports.get(part) {
              Some(s) => Some(s)
              None =>
                // Try members (for classes/interfaces)
                match sym.members {
                  Some(members) => members.get(part)
                  None => None
                }
            }
          None =>
            // Try members (for classes/interfaces)
            match sym.members {
              Some(members) => members.get(part)
              None => None
            }
        }
      }
    }
  }

  current_symbol
}

///|
/// Resolve an interface symbol to an Object type with its property types
fn resolve_interface_type(
  checker : TypeChecker,
  interface_symbol : Symbol,
) -> (Type?, TypeChecker) {
  // Check for circular reference (interface referring to itself in members)
  if checker.resolving_symbols.get(interface_symbol.id) is Some(_) {
    // Circular reference detected - return a placeholder empty Object type
    let (info, checker) = create_type_info(checker)
    return (
      Some(
        Type::Object({
          properties: Map::new(),
          call_signatures: [],
          construct_signatures: [],
          index_signatures: [],
          info,
          class_name: None,
        }),
      ),
      checker,
    )
  }

  // Mark symbol as being resolved
  let resolving = checker.resolving_symbols
  resolving.set(interface_symbol.id, true)
  let mut checker = { ..checker, resolving_symbols: resolving }

  // Get the interface declaration from the symbol
  let result = match interface_symbol.value_declaration {
    Some(InterfaceDeclaration(interface_decl)) => {
      // Build property map from interface members
      let properties : Map[String, PropertySignature] = Map::new()
      let index_signatures : Array[IndexSignature] = []
      let call_signatures : Array[CheckerSignature] = []
      let construct_signatures : Array[CheckerSignature] = []
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
            // Check if property has readonly modifier
            let has_readonly = has_modifier(prop.modifiers, Modifier::Readonly)
            properties.set(prop.name, {
              name: prop.name,
              prop_type,
              is_optional: prop.is_optional,
              is_readonly: has_readonly,
            })
          }
          MethodDeclaration(meth) => {
            // Convert method parameters to CheckerParameter array
            let parameters : Array[CheckerParameter] = []
            for param_node in meth.parameters {
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
            let (return_type, c) = match meth.return_type {
              Some(type_node) =>
                match get_type_from_type_node(checker, type_node) {
                  (Some(t), c2) => (t, c2)
                  (None, c2) => any_type(c2)
                }
              None => any_type(checker)
            }
            checker = c
            let func_sig : CheckerSignature = { parameters, return_type, type_parameters: [] }
            // Check if this is a construct signature (name "new") or call signature (name "")
            if meth.name == "new" {
              construct_signatures.push(func_sig)
            } else if meth.name == "" {
              call_signatures.push(func_sig)
            } else {
              // Regular method - add as property with function type
              let (info, c) = create_type_info(checker)
              checker = c
              properties.set(meth.name, {
                name: meth.name,
                prop_type: Type::Function({ parameters, return_type, info }),
                is_optional: meth.is_optional,
                is_readonly: false,
              })
            }
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
            // TS2716: Validate that param_type is string, number, or symbol
            checker = match param_type {
              String(_) | Number(_) | Symbol(_) => checker
              _ =>
                add_diagnostic_with_code(
                  checker,
                  "An index signature parameter type must be 'string', 'number', 'symbol', or a template literal type",
                  idx_sig.location,
                  TS2716,
                )
            }
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
      let (info, c) = create_type_info(checker)
      checker = c
      Some(
        Type::Object({
          properties,
          call_signatures,
          construct_signatures,
          index_signatures,
          info,
          class_name: None,
        }),
      )
    }
    _ => None
  }

  // Unmark symbol as being resolved
  let resolving = checker.resolving_symbols
  resolving.remove(interface_symbol.id)
  checker = { ..checker, resolving_symbols: resolving }

  (result, checker)
}

// ============================================================================
// V2 Type Checker Integration
// ============================================================================

///|
/// Create a TypeEnv from the TypeChecker's current scope
fn type_env_from_checker(checker : TypeChecker) -> TypeEnv {
  let mut env = TypeEnv::with_builtins()

  // Add narrowed types from control flow analysis
  for kv in checker.narrowed_types {
    let var_name = kv.0
    let narrowed = kv.1
    // narrowed_type is always present (not Option)
    let type_v2 = type_to_v2(narrowed.narrowed_type)
    env = env.with_narrowing(var_name, type_v2)
  }
  env
}

///|
/// Infer type using the v2 bidirectional type checker
/// This provides richer error messages and control flow narrowing
pub fn infer_type_v2_integrated(
  checker : TypeChecker,
  expr : Node,
) -> (Type, TypeChecker, Array[TypeMismatchError]) {
  // Create TypeEnv from checker state
  let env = type_env_from_checker(checker)

  // Use v2 bidirectional type checker
  let result = infer_expr_v2(env, expr)

  // Convert result type back to old Type format
  let convert_result = v2_to_type(checker, result.ty)
  let old_type = convert_result.0
  let updated_checker = convert_result.1
  (old_type, updated_checker, result.errors)
}

///|
/// Check expression against expected type using v2 checker
pub fn check_type_v2_integrated(
  checker : TypeChecker,
  expr : Node,
  expected : Type,
) -> (Type, TypeChecker, Array[TypeMismatchError]) {
  // Create TypeEnv from checker state
  let env = type_env_from_checker(checker)

  // Convert expected type to v2 format
  let expected_v2 = type_to_v2(expected)

  // Use v2 bidirectional type checker in Check mode
  let result = check_expr_v2(env, expr, Check(expected_v2))

  // Convert result type back to old Type format
  let convert_result = v2_to_type(checker, result.ty)
  let old_type = convert_result.0
  let updated_checker = convert_result.1
  (old_type, updated_checker, result.errors)
}

// ============================================================================
// Isolated Modules Validation
// ============================================================================

///|
/// Validate isolatedModules constraints
/// When isolatedModules is enabled, each file must be able to be transpiled
/// independently without knowledge of other files.
///
/// Errors reported:
/// - TS1208: File is not a module (no import/export statements)
/// - TS1209: const enum declarations are not allowed
pub fn validate_isolated_modules(
  bound : BoundSourceFile,
  file_path : String,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []

  // TS1208: File must be a module (have import/export statements)
  if not(bound.module_info.is_external_module) {
    let location = SourceLocation::{
      file_path,
      start: Position::{ line: 1, column: 1, offset: 0 },
      end: Position::{ line: 1, column: 1, offset: 0 },
    }
    diagnostics.push(
      Diagnostic::{
        code: 1208,
        category: DiagnosticCategory::Error,
        message: "'isolatedModules' requires all files to be modules (have import or export statements).",
        location,
      },
    )
  }

  // TS1209: const enum declarations are not allowed
  for stmt in bound.statements {
    match stmt {
      EnumDeclaration(enum_decl) =>
        if enum_decl.is_const {
          diagnostics.push(
            Diagnostic::{
              code: 1209,
              category: DiagnosticCategory::Error,
              message: "const enums are not allowed when 'isolatedModules' is enabled. Use regular enums instead.",
              location: enum_decl.location,
            },
          )
        }
      _ => ()
    }
  }

  diagnostics
}

///|
/// Validate verbatimModuleSyntax constraints
/// TS1485: 'X' is a type and must be imported using a type-only import when 'verbatimModuleSyntax' is enabled.
/// TS1486: 'X' is a type and must be exported using a type-only export when 'verbatimModuleSyntax' is enabled.
pub fn validate_verbatim_module_syntax(
  bound : BoundSourceFile,
  file_path : String,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []

  // Collect all type-only symbols (interfaces, type aliases) from the source file
  let type_only_symbols : Map[String, Bool] = Map::new()
  for stmt in bound.statements {
    match stmt {
      InterfaceDeclaration(iface) => type_only_symbols.set(iface.name, true)
      TypeAliasDeclaration(type_alias) =>
        type_only_symbols.set(type_alias.name, true)
      _ => ()
    }
  }

  // Check imports
  for stmt in bound.statements {
    match stmt {
      ImportDeclaration(import_decl) => {
        // Skip if the entire import is type-only
        if import_decl.is_type_only {
          continue
        }

        // Check named imports
        match import_decl.import_clause {
          Some(clause) =>
            match clause.named_bindings {
              Some(NamedImports::NamedImports(specifiers, _)) => {
                for specifier in specifiers {
                  // Skip if the specifier is type-only
                  if specifier.is_type_only {
                    continue
                  }

                  // The local name is the name used in the file
                  let local_name = specifier.name

                  // Check if this symbol is a type-only symbol in the local scope
                  // Since we can't resolve cross-file imports, we check local declarations
                  if type_only_symbols.get(local_name).or(false) {
                    diagnostics.push(
                      Diagnostic::{
                        code: 1485,
                        category: DiagnosticCategory::Error,
                        message: "'\{local_name}' is a type and must be imported using a type-only import when 'verbatimModuleSyntax' is enabled.",
                        location: specifier.location,
                      },
                    )
                  }
                }
              }
              _ => ()
            }
          None => ()
        }
      }
      _ => ()
    }
  }

  // Check exports
  for stmt in bound.statements {
    match stmt {
      ExportDeclaration(export_decl) => {
        // Skip if the entire export is type-only
        if export_decl.is_type_only {
          continue
        }

        // Check named exports
        match export_decl.export_clause {
          Some(NamedExports::NamedExports(specifiers, _)) => {
            for specifier in specifiers {
              // Skip if the specifier is type-only
              if specifier.is_type_only {
                continue
              }

              // The property name is the local name (what we're exporting from)
              // If no property_name, the name is used for both
              let local_name = match specifier.property_name {
                Some(pn) => pn
                None => specifier.name
              }

              // Check if this symbol is a type-only symbol
              if type_only_symbols.get(local_name).or(false) {
                diagnostics.push(
                  Diagnostic::{
                    code: 1486,
                    category: DiagnosticCategory::Error,
                    message: "'\{local_name}' is a type and must be exported using a type-only export when 'verbatimModuleSyntax' is enabled.",
                    location: specifier.location,
                  },
                )
              }
            }
          }
          Some(NamedExports::NamespaceExport(_, _)) =>
            () // Namespace exports (export * as ns) don't need type-only checking
          None => ()
        }
      }
      _ => ()
    }
  }

  diagnostics
}

///|
/// Helper function to check if a type node includes undefined
fn exact_opt_type_includes_undefined(type_node : Node) -> Bool {
  match type_node {
    KeywordType(kt) => kt.kind == TypeKeyword::Undefined
    UnionType(ut) => {
      for i = 0; i < ut.types.length(); i = i + 1 {
        if exact_opt_type_includes_undefined(ut.types[i]) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
/// Helper to check if an expression is the undefined keyword
fn exact_opt_is_undefined_literal(expr : Node) -> Bool {
  match expr {
    Identifier(id) => id.name == "undefined"
    _ => false
  }
}

///|
/// Property info for exactOptionalPropertyTypes checking
struct ExactOptPropertyInfo {
  is_optional : Bool
  type_node : Node?
}

///|
/// Helper to find the target interface type from a type annotation
fn exact_opt_find_interface_properties(
  bound : BoundSourceFile,
  type_name : String,
) -> Map[String, ExactOptPropertyInfo] {
  // Returns map of property name -> property info
  let props : Map[String, ExactOptPropertyInfo] = Map::new()

  for stmt in bound.statements {
    match stmt {
      InterfaceDeclaration(iface) =>
        if iface.name == type_name {
          for member in iface.members {
            match member {
              PropertyDeclaration(prop_decl) =>
                props.set(
                  prop_decl.name,
                  {
                    is_optional: prop_decl.is_optional,
                    type_node: prop_decl.type_annotation,
                  },
                )
              _ => ()
            }
          }
        }
      TypeAliasDeclaration(type_alias) =>
        if type_alias.name == type_name {
          // Handle type alias to object type
          match type_alias.type_node {
            TypeLiteral(tl) =>
              for member in tl.members {
                match member {
                  PropertyDeclaration(prop_decl) =>
                    props.set(
                      prop_decl.name,
                      {
                        is_optional: prop_decl.is_optional,
                        type_node: prop_decl.type_annotation,
                      },
                    )
                  _ => ()
                }
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  props
}

///|
/// Validate exactOptionalPropertyTypes constraints
/// TS2412: Type 'undefined' is not assignable to type 'X' with
/// 'exactOptionalPropertyTypes' enabled.
pub fn validate_exact_optional_property_types(
  bound : BoundSourceFile,
  _file_path : String,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []

  // Check variable declarations with object literal initializers
  for stmt in bound.statements {
    match stmt {
      VariableStatement(vs) =>
        for decl in vs.declarations {
          match (decl.type_annotation, decl.initializer) {
            (Some(TypeReference(type_ref)), Some(ObjectLiteralExpression(obj))) => {
              // Get the interface properties
              let interface_props = exact_opt_find_interface_properties(
                bound, type_ref.type_name,
              )

              // Check each property in the object literal
              for prop in obj.properties {
                match prop {
                  PropertyAssignment(prop_name, value, location) =>
                    if exact_opt_is_undefined_literal(value) {
                      // Check if this is an optional property
                      match interface_props.get(prop_name) {
                        Some(prop_info) =>
                          if prop_info.is_optional {
                            // Check if the type includes undefined
                            let includes_undefined = match prop_info.type_node {
                              Some(tn) => exact_opt_type_includes_undefined(tn)
                              None => false
                            }
                            if not(includes_undefined) {
                              diagnostics.push(
                                Diagnostic::{
                                  code: 2412,
                                  category: DiagnosticCategory::Error,
                                  message: "Type 'undefined' is not assignable to type with 'exactOptionalPropertyTypes' enabled. Consider adding 'undefined' to the type of the target.",
                                  location,
                                },
                              )
                            }
                          }
                        None => ()
                      }
                    }
                  _ => ()
                }
              }
            }
            _ => ()
          }
        }
      _ => ()
    }
  }

  diagnostics
}
