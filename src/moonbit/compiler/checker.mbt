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
  BigInt(TypeInfo)
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
  is_keyof : Bool // True if this represents "keyof T" (T is object_type)
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
  target : Target // ECMAScript target version (affects feature availability)
  resolving_symbols : Map[Int, Bool] // Symbol IDs currently being resolved (for cycle detection)
  arrow_function_depth : Int // Tracks nesting depth in arrow functions (> 0 means inside arrow)
  async_function_depth : Int // Tracks nesting depth in async functions (> 0 means inside async)
  generator_function_depth : Int // Tracks nesting depth in generator functions (> 0 means inside generator)
  regular_function_depth : Int // Tracks nesting depth in regular functions (> 0 means inside regular function)
  innermost_function_is_arrow : Bool // True if the innermost containing function is an arrow function
  generator_has_return_type : Bool // Tracks if current generator has a return type annotation
  generator_yield_type : Type? // Expected yield type from generator return type annotation (e.g., Foo from IterableIterator<Foo>)
  collected_yield_types : Array[Type] // Collected yield types during generator body checking (for type inference)
  block_scoped_decls : Map[String, Int] // Variable name -> declaration line (for TS2448 TDZ check)
  uninitialized_vars : Map[String, Int] // Variable name -> declaration line (for TS2454 definite assignment)
  in_static_context : Bool // Tracks if we're in a static property initializer (for TS2334)
  in_constructor : Bool // Tracks if we're in a constructor (for TS2337 super outside constructor)
  in_class_body : Bool // Tracks if we're in a class body (for TS2335 super outside class)
  in_derived_class : Bool // Tracks if we're in a class that extends another (for TS2335)
  in_extends_null_class : Bool // Tracks if we're in a class that extends null (for TS17005)
  super_called : Bool // Tracks if super() has been called in constructor (for TS17009)
  current_location : SourceLocation // Current location being checked (for TS2590 and similar)
  external_registry : ExternalTypeRegistry? // Registry of types from other modules for cross-file checking
  import_map : Map[String, (String, String)] // Map from local name -> (module_specifier, original_name)
  namespace_symbols : Map[String, Symbol] // Symbols from current namespace for TS2432 enum merging checks
  in_destructuring_pattern : Bool // Tracks if we're inferring type of a destructuring pattern (left side of assignment)
  in_expression_statement : Bool // Tracks if we're in an expression statement (yield result not used)
  no_implicit_any : Bool // Error on expressions and declarations with an implied 'any' type
  implicit_any_array_vars : @hashset.HashSet[String] // Variables with implicit any[] type (for TS7005)
} derive(Show)

///|
/// Local scope for tracking variable types in function bodies
pub struct LocalScope {
  variables : Map[String, Type] // Variable name -> Type
  const_vars : @hashset.HashSet[String] // Set of const variable names
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
  TypeChecker::new_with_options(file_path, global_scope, false, Target::ESNext)
}

///|
/// Create a new type checker with options
pub fn TypeChecker::new_with_options(
  file_path : String,
  global_scope : Scope?,
  no_unchecked_indexed_access : Bool,
  target : Target,
  no_implicit_any? : Bool = false,
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
    target,
    resolving_symbols: Map::new(),
    arrow_function_depth: 0,
    async_function_depth: 0,
    generator_function_depth: 0,
    regular_function_depth: 0,
    innermost_function_is_arrow: false,
    generator_has_return_type: false,
    generator_yield_type: None,
    collected_yield_types: [],
    block_scoped_decls: Map::new(),
    uninitialized_vars: Map::new(),
    in_static_context: false,
    in_constructor: false,
    in_class_body: false,
    in_derived_class: false,
    in_extends_null_class: false,
    super_called: false,
    current_location: SourceLocation::new(
      file_path,
      Position::{ line: 0, column: 0, offset: 0 },
      Position::{ line: 0, column: 0, offset: 0 },
    ),
    external_registry: None,
    import_map: Map::new(),
    namespace_symbols: Map::new(),
    in_destructuring_pattern: false,
    in_expression_statement: false,
    no_implicit_any,
    implicit_any_array_vars: @hashset.new(),
  }
}

///|
/// Get next type ID
fn next_type_id(checker : TypeChecker) -> (Int, TypeChecker) {
  let id = checker.next_type_id
  (id, { ..checker, next_type_id: id + 1 })
}

///|
/// Apply global augmentations to the checker's global scope
/// This merges declarations from `declare global { }` blocks into the global scope
fn apply_global_augmentations_to_checker(
  checker : TypeChecker,
  augmentations : Array[GlobalAugmentation],
) -> TypeChecker {
  match checker.global_scope {
    Some(global_scope) => {
      // Create a new global scope with augmented symbols
      let new_symbols = global_scope.symbols
      // Merge all augmentation declarations into the global scope
      for aug in augmentations {
        aug.declarations.each(fn(name, symbol) {
          // Add or merge the symbol into the global scope
          match new_symbols.get(name) {
            Some(existing_symbol) =>
              // If symbol already exists, we need to merge them
              // For interfaces, this means merging members
              if existing_symbol.kind == Interface && symbol.kind == Interface {
                // Merge interface declarations
                let merged_decls = existing_symbol.declarations
                merged_decls.append(symbol.declarations)
                let merged_symbol = {
                  ..existing_symbol,
                  declarations: merged_decls,
                }
                new_symbols.set(name, merged_symbol)
              } else {
                // For other symbols, keep the existing one
                // (this matches TypeScript's behavior)
                ()
              }
            None =>
              // No existing symbol, add the new one
              new_symbols.set(name, symbol)
          }
        })
      }
      let new_global_scope = { ..global_scope, symbols: new_symbols }
      { ..checker, global_scope: Some(new_global_scope) }
    }
    None => checker
  }
}

///|
/// Push a new local scope onto the scope stack
fn push_local_scope(checker : TypeChecker) -> TypeChecker {
  let scopes = checker.local_scopes
  scopes.push(LocalScope::{ variables: Map::new(), const_vars: @hashset.new() })
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
  {
    ..checker,
    arrow_function_depth: checker.arrow_function_depth + 1,
    innermost_function_is_arrow: true,
  }
}

///|
/// Exit arrow function context (decrement depth)
fn exit_arrow_function(checker : TypeChecker) -> TypeChecker {
  {
    ..checker,
    arrow_function_depth: checker.arrow_function_depth - 1,
    // Restore: innermost is arrow only if we're still inside an arrow
    innermost_function_is_arrow: checker.arrow_function_depth > 1,
  }
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
/// Enter generator function context (increment depth)
/// Returns (updated checker, saved collected yield types for restoration)
fn enter_generator_function(
  checker : TypeChecker,
  has_return_type : Bool,
  yield_type? : Type? = None,
) -> (TypeChecker, Array[Type]) {
  let saved_yield_types = checker.collected_yield_types
  (
    {
      ..checker,
      generator_function_depth: checker.generator_function_depth + 1,
      generator_has_return_type: has_return_type,
      generator_yield_type: yield_type,
      collected_yield_types: [], // Reset for new generator
    },
    saved_yield_types,
  )
}

///|
/// Exit generator function context (decrement depth)
/// Returns (updated checker with collected types, collected yield types from this generator)
fn exit_generator_function(
  checker : TypeChecker,
  saved_yield_types : Array[Type],
) -> (TypeChecker, Array[Type]) {
  let collected = checker.collected_yield_types
  (
    {
      ..checker,
      generator_function_depth: checker.generator_function_depth - 1,
      generator_has_return_type: false,
      generator_yield_type: None,
      collected_yield_types: saved_yield_types, // Restore parent's collected types
    },
    collected,
  )
}

///|
/// Check if currently inside a generator function
fn is_in_generator_function(checker : TypeChecker) -> Bool {
  checker.generator_function_depth > 0
}

///|
/// Collect a yield type for Generator type inference
/// For yield*, we extract the element type from the iterable
/// For plain yield, we use the type directly
fn collect_yield_type(
  checker : TypeChecker,
  yield_type : Type,
  is_delegate : Bool,
) -> TypeChecker {
  // Only collect if we're in a generator function
  if not(is_in_generator_function(checker)) {
    return checker
  }
  // For yield*, extract element type from the iterable
  let type_to_collect = if is_delegate {
    extract_yield_delegate_element_type(yield_type)
  } else {
    yield_type
  }
  // Add to collected types
  let new_collected = checker.collected_yield_types.copy()
  new_collected.push(type_to_collect)
  { ..checker, collected_yield_types: new_collected }
}

///|
/// Extract the element type from an iterable type for yield* collection
/// For yield*, we need to know what type the iterable produces
fn extract_yield_delegate_element_type(t : Type) -> Type {
  match t {
    // Array types - element is the array element type
    Array(arr) => arr.element_type
    // TypeReference - check for known iterable types
    Type::TypeReference(ref_type) =>
      if ref_type.type_arguments.length() > 0 {
        // Array<T>, Set<T>, Map<K,V> (first arg), Generator<T>, Iterator<T>, Iterable<T>, IterableIterator<T>
        if ref_type.name == "Array" ||
          ref_type.name == "Set" ||
          ref_type.name == "Generator" ||
          ref_type.name == "Iterator" ||
          ref_type.name == "Iterable" ||
          ref_type.name == "IterableIterator" {
          ref_type.type_arguments[0]
        } else if ref_type.name == "Map" &&
          ref_type.type_arguments.length() >= 2 {
          // Map yields [K, V] tuples - just use any for now
          t
        } else {
          t
        }
      } else {
        t
      }
    // Object types with Symbol.iterator - check for generator methods
    Object(obj) =>
      // Check if this object has call signatures (generator function type)
      if obj.call_signatures.length() > 0 {
        let sig = obj.call_signatures[0]
        // If the call signature returns a Generator/Iterator, extract its element type
        match sig.return_type {
          Type::TypeReference(ret_ref) =>
            if (
                ret_ref.name == "Generator" ||
                ret_ref.name == "Iterator" ||
                ret_ref.name == "IterableIterator"
              ) &&
              ret_ref.type_arguments.length() > 0 {
              ret_ref.type_arguments[0]
            } else {
              t
            }
          _ => t
        }
      } else {
        // Anonymous object literals with *[Symbol.iterator]() are considered iterables
        // Check if this object has a [Symbol.iterator]() method and extract its element type
        let mut iterator_method_type : Type? = None
        for entry in obj.properties {
          let (prop_name, prop) = entry
          // Check for various representations of Symbol.iterator
          if prop_name.contains("iterator") ||
            prop_name.contains("Iterator") ||
            prop_name == "__@iterator" {
            iterator_method_type = Some(prop.prop_type)
            break
          }
        }

        // If we found the iterator method, extract its return type's element type
        match iterator_method_type {
          Some(Function(func)) =>
            // The iterator method returns an iterator/generator
            // Extract the element type from the return type
            match func.return_type {
              Type::TypeReference(ret_ref) =>
                if (
                    ret_ref.name == "Generator" ||
                    ret_ref.name == "Iterator" ||
                    ret_ref.name == "IterableIterator"
                  ) &&
                  ret_ref.type_arguments.length() > 0 {
                  // Recursively extract in case it's nested
                  extract_yield_delegate_element_type(ret_ref.type_arguments[0])
                } else {
                  ret_ref.type_arguments.get(0).unwrap_or(t)
                }
              _ => t
            }
          Some(Type::TypeReference(ret_ref)) =>
            // The property is already a TypeReference (shouldn't normally happen for methods)
            if (
                ret_ref.name == "Generator" ||
                ret_ref.name == "Iterator" ||
                ret_ref.name == "IterableIterator"
              ) &&
              ret_ref.type_arguments.length() > 0 {
              ret_ref.type_arguments[0]
            } else {
              t
            }
          _ => t
        }
      }
    _ => t
  }
}

///|
/// Enter regular function context (increment depth)
fn enter_regular_function(checker : TypeChecker) -> TypeChecker {
  {
    ..checker,
    regular_function_depth: checker.regular_function_depth + 1,
    innermost_function_is_arrow: false,
  }
}

///|
/// Exit regular function context (decrement depth)
fn exit_regular_function(checker : TypeChecker) -> TypeChecker {
  {
    ..checker,
    regular_function_depth: checker.regular_function_depth - 1,
    // Restore: innermost is arrow if we're still inside an arrow but no more regular functions between
    innermost_function_is_arrow: checker.regular_function_depth == 1 &&
    checker.arrow_function_depth > 0,
  }
}

///|
/// Check if currently inside a regular function (not arrow function)
fn is_in_regular_function(checker : TypeChecker) -> Bool {
  checker.regular_function_depth > 0
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
    { ..checker, local_scopes: scopes }
  } else {
    // At global scope - look up the symbol and set its type
    match lookup_symbol(checker, name) {
      Some(symbol) => {
        let new_symbol_types = checker.symbol_types
        new_symbol_types.set(symbol.id, var_type)
        { ..checker, symbol_types: new_symbol_types }
      }
      None => checker // Symbol not found, nothing to do
    }
  }
}

///|
/// Add a const variable to the current local scope
fn add_local_const_variable(
  checker : TypeChecker,
  name : String,
  var_type : Type,
) -> TypeChecker {
  let scopes = checker.local_scopes
  if scopes.length() > 0 {
    let scope = scopes[scopes.length() - 1]
    scope.variables.set(name, var_type)
    scope.const_vars.insert(name)
    { ..checker, local_scopes: scopes }
  } else {
    // At global scope - look up the symbol and set its type
    match lookup_symbol(checker, name) {
      Some(symbol) => {
        let new_symbol_types = checker.symbol_types
        new_symbol_types.set(symbol.id, var_type)
        { ..checker, symbol_types: new_symbol_types }
      }
      None => checker // Symbol not found, nothing to do
    }
  }
}

///|
/// Collect all binding names from a destructuring pattern
fn collect_binding_names(pattern : Node, names : Array[String]) -> Unit {
  match pattern {
    Identifier(id) => names.push(id.name)
    ArrayBindingPattern(arr_pattern) => {
      for i = 0; i < arr_pattern.elements.length(); i = i + 1 {
        match arr_pattern.elements[i] {
          Some(elem) => collect_binding_names(elem, names)
          None => ()
        }
      }
    }
    ObjectBindingPattern(obj_pattern) => {
      for i = 0; i < obj_pattern.properties.length(); i = i + 1 {
        let elem = obj_pattern.properties[i]
        collect_binding_names(elem.name, names)
      }
    }
    BindingElement(elem) => collect_binding_names(elem.name, names)
    _ => ()
  }
}

///|
/// Check for duplicate binding names in destructuring pattern (TS2451)
fn check_duplicate_bindings(
  checker : TypeChecker,
  pattern : Node,
) -> TypeChecker {
  let names : Array[String] = []
  collect_binding_names(pattern, names)

  // Check for duplicates
  let seen : @hashmap.HashMap[String, SourceLocation] = @hashmap.new()
  let mut c = checker

  fn check_name(name : String, location : SourceLocation) -> Unit {
    match seen.get(name) {
      Some(_) => {
        c = add_diagnostic_with_code(
          c,
          "Cannot redeclare block-scoped variable '\{name}'.",
          location,
          TS2451,
        )
      }
      None => seen.set(name, location)
    }
  }

  // Recursively check all identifiers with their locations
  fn check_pattern(pat : Node) -> Unit {
    match pat {
      Identifier(id) => check_name(id.name, id.location)
      ArrayBindingPattern(arr_pattern) => {
        for i = 0; i < arr_pattern.elements.length(); i = i + 1 {
          match arr_pattern.elements[i] {
            Some(elem) => check_pattern(elem)
            None => ()
          }
        }
      }
      ObjectBindingPattern(obj_pattern) => {
        for i = 0; i < obj_pattern.properties.length(); i = i + 1 {
          let elem = obj_pattern.properties[i]
          check_pattern(elem.name)
        }
      }
      BindingElement(elem) => check_pattern(elem.name)
      _ => ()
    }
  }

  check_pattern(pattern)
  c
}

///|
/// Add variables from a binding pattern to the current local scope
/// This handles ArrayBindingPattern, ObjectBindingPattern, and nested patterns
fn add_binding_pattern_variables(
  checker : TypeChecker,
  pattern : Node,
  var_type : Type,
) -> TypeChecker {
  match pattern {
    Identifier(id) => add_local_variable(checker, id.name, var_type)
    ArrayBindingPattern(arr_pattern) => {
      let mut c = checker
      for i = 0; i < arr_pattern.elements.length(); i = i + 1 {
        match arr_pattern.elements[i] {
          Some(elem) => c = add_binding_pattern_variables(c, elem, var_type)
          None => ()
        }
      }
      c
    }
    ObjectBindingPattern(obj_pattern) => {
      let mut c = checker
      for i = 0; i < obj_pattern.properties.length(); i = i + 1 {
        let prop = obj_pattern.properties[i]
        c = add_binding_pattern_variables(c, prop.name, var_type)
      }
      c
    }
    BindingElement(elem) =>
      add_binding_pattern_variables(checker, elem.name, var_type)
    SpreadExpression(spread) =>
      add_binding_pattern_variables(checker, spread.expression, var_type)
    _ => checker
  }
}

///|
/// Add variables from a binding pattern to scope as const (for let/const tracking)
/// This tracks the variables in const_vars set for TS2481 error detection
fn add_binding_pattern_variables_as_const(
  checker : TypeChecker,
  pattern : Node,
  var_type : Type,
) -> TypeChecker {
  match pattern {
    Identifier(id) => add_local_const_variable(checker, id.name, var_type)
    ArrayBindingPattern(arr_pattern) => {
      let mut c = checker
      for i = 0; i < arr_pattern.elements.length(); i = i + 1 {
        match arr_pattern.elements[i] {
          Some(elem) => c = add_binding_pattern_variables_as_const(c, elem, var_type)
          None => ()
        }
      }
      c
    }
    ObjectBindingPattern(obj_pattern) => {
      let mut c = checker
      for i = 0; i < obj_pattern.properties.length(); i = i + 1 {
        let prop = obj_pattern.properties[i]
        c = add_binding_pattern_variables_as_const(c, prop.name, var_type)
      }
      c
    }
    BindingElement(elem) =>
      add_binding_pattern_variables_as_const(checker, elem.name, var_type)
    SpreadExpression(spread) =>
      add_binding_pattern_variables_as_const(checker, spread.expression, var_type)
    _ => checker
  }
}

///|
/// Check if a local variable is const
fn is_local_const_variable(checker : TypeChecker, name : String) -> Bool {
  let scopes = checker.local_scopes
  for i = scopes.length() - 1; i >= 0; i = i - 1 {
    if scopes[i].const_vars.contains(name) {
      return true
    }
  }
  false
}

///|
/// Check assignment to local const variable
fn check_local_const_assignment(
  checker : TypeChecker,
  var_name : String,
  location : SourceLocation,
) -> TypeChecker {
  if is_local_const_variable(checker, var_name) {
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
/// Hoist var declarations in a statement block to the current local scope.
/// This ensures that var declarations are visible even in their own initializers.
/// Hoists `var` declarations and function declarations to the current scope.
/// Only hoists `var` declarations, not `let` or `const` (which have temporal dead zone).
/// Function declarations are always hoisted in JavaScript/TypeScript.
fn hoist_var_declarations(checker : TypeChecker, stmt : Node) -> TypeChecker {
  let (any_t, checker) = any_type(checker)
  match stmt {
    BlockStatement(block) => {
      let mut checker = checker
      for s in block.statements {
        checker = hoist_var_declarations(checker, s)
      }
      checker
    }
    VariableStatement(var_stmt) => {
      // Only hoist `var`, not `let` or `const`
      if var_stmt.is_let || var_stmt.is_const {
        return checker
      }
      let mut checker = checker
      for decl in var_stmt.declarations {
        checker = hoist_var_decl_binding(checker, decl.name, any_t)
      }
      checker
    }
    FunctionDeclaration(func) => {
      // Only hoist nested function declarations (inside another function body)
      // Top-level functions are handled via global scope and may have overloads
      // We check if we're in a local scope (local_scopes is non-empty)
      if checker.local_scopes.is_empty() {
        return checker // Top-level function, don't hoist to local scope
      }
      // Hoist function declaration - add function type to current local scope
      // This enables forward references to nested functions within the same function body
      let name = match func.name {
        Some(Identifier(id)) => id.name
        _ => return checker // Anonymous function
      }
      // Get function type and add to local scope
      let (func_type, checker) = get_function_declaration_type(checker, func)
      add_local_variable(checker, name, func_type)
    }
    // Recurse into statements that can contain var declarations
    IfStatement(if_stmt) => {
      let checker = hoist_var_declarations(checker, if_stmt.then_statement)
      match if_stmt.else_statement {
        Some(else_stmt) => hoist_var_declarations(checker, else_stmt)
        None => checker
      }
    }
    WhileStatement(while_stmt) =>
      hoist_var_declarations(checker, while_stmt.statement)
    DoWhileStatement(do_stmt) =>
      hoist_var_declarations(checker, do_stmt.statement)
    ForStatement(for_stmt) => {
      let checker = match for_stmt.initializer {
        Some(init) => hoist_var_declarations(checker, init)
        None => checker
      }
      hoist_var_declarations(checker, for_stmt.statement)
    }
    ForInStatement(for_in) => {
      let checker = hoist_var_declarations(checker, for_in.initializer)
      hoist_var_declarations(checker, for_in.statement)
    }
    ForOfStatement(for_of) => {
      let checker = hoist_var_declarations(checker, for_of.initializer)
      hoist_var_declarations(checker, for_of.statement)
    }
    SwitchStatement(switch_stmt) => {
      let mut checker = checker
      for clause in switch_stmt.cases {
        for s in clause.statements {
          checker = hoist_var_declarations(checker, s)
        }
      }
      checker
    }
    TryStatement(try_stmt) => {
      let checker = hoist_var_declarations(checker, try_stmt.try_block)
      let checker = match try_stmt.catch_clause {
        Some(catch_clause) =>
          hoist_var_declarations(checker, catch_clause.block)
        None => checker
      }
      match try_stmt.finally_block {
        Some(finally_block) => hoist_var_declarations(checker, finally_block)
        None => checker
      }
    }
    WithStatement(with_stmt) =>
      hoist_var_declarations(checker, with_stmt.statement)
    LabeledStatement(labeled) =>
      hoist_var_declarations(checker, labeled.statement)
    _ => checker
  }
}

///|
/// Add a var binding to the current local scope during hoisting
fn hoist_var_decl_binding(
  checker : TypeChecker,
  name : Node,
  var_type : Type,
) -> TypeChecker {
  match name {
    Identifier(id) => add_local_variable(checker, id.name, var_type)
    ArrayBindingPattern(pattern) => {
      let mut checker = checker
      for elem in pattern.elements {
        match elem {
          Some(binding_node) =>
            // Elements can be Identifier or nested patterns
            checker = hoist_var_decl_binding(checker, binding_node, var_type)
          None => ()
        }
      }
      checker
    }
    ObjectBindingPattern(pattern) => {
      let mut checker = checker
      for elem in pattern.properties {
        // The name field is the binding target (Identifier or nested pattern)
        checker = hoist_var_decl_binding(checker, elem.name, var_type)
      }
      checker
    }
    _ => checker
  }
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
/// Check if a variable exists in the innermost local scope only
/// (not searching up the scope chain)
fn is_in_innermost_scope(checker : TypeChecker, name : String) -> Bool {
  let scopes = checker.local_scopes
  if scopes.length() == 0 {
    return false
  }
  // Only check the innermost scope
  scopes[scopes.length() - 1].variables.contains(name)
}

///|
/// Add a function parameter to the current local scope
fn add_parameter_to_scope(checker : TypeChecker, param : Node) -> TypeChecker {
  match param {
    Parameter(p) => {
      // Get the parameter type from type annotation, or any if not specified
      let (param_type, checker) = resolve_type_annotation_or_any(checker, p.type_annotation)
      // Handle parameter name (identifier or binding pattern)
      match p.name {
        Identifier(id) => add_local_variable(checker, id.name, param_type)
        // Handle binding patterns (destructuring) in parameters
        ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
          add_binding_pattern_variables(checker, p.name, param_type)
        _ => checker
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
      union_type.types.iter().all(fn(mem) { is_array_like_type(mem) })
    Object(obj_type) =>
      // In ES6+, user-defined classes can be iterable via [Symbol.iterator]
      // Accept any class instance (has class_name) as potentially iterable
      match obj_type.class_name {
        Some(_) => true // User-defined class instances are potentially iterable
        None =>
          // For plain objects, check for numeric index signature
          obj_type.index_signatures
          .iter()
          .any(fn(idx_sig) {
            match idx_sig.parameter_type {
              Number(_) => true
              _ => false
            }
          })
      }
    TypeReference(_) => true // Type references might be arrays
    _ => false
  }
}

///|
/// Add array binding pattern elements to local scope
fn add_array_binding_elements_to_scope(
  checker : TypeChecker,
  arr_pat : ArrayBindingPattern,
  arr_type : Type,
  is_const : Bool,
) -> TypeChecker {
  let mut checker = checker

  // TS2493: Check if destructuring from a tuple exceeds tuple length
  // Only check for tuple types where we know the exact length
  match arr_type {
    Tuple(tuple_type) => {
      let tuple_len = tuple_type.element_types.length()
      // Count non-rest elements in the binding pattern
      for i, elem in arr_pat.elements {
        match elem {
          Some(element) => {
            // Check if this is a rest element (SpreadExpression in array patterns)
            let is_rest = match element {
              SpreadExpression(_) => true
              _ => false
            }
            // If not a rest element and index exceeds tuple length, report error
            if not(is_rest) && i >= tuple_len {
              let tuple_str = type_to_string(arr_type)
              checker = add_diagnostic_with_code(
                checker,
                "Tuple type '\{tuple_str}' of length '\{tuple_len}' has no element at index '\{i}'.",
                arr_pat.location,
                TS2493,
              )
            }
          }
          None =>
            // Hole in pattern - still check if index is valid
            if i >= tuple_len {
              let tuple_str = type_to_string(arr_type)
              checker = add_diagnostic_with_code(
                checker,
                "Tuple type '\{tuple_str}' of length '\{tuple_len}' has no element at index '\{i}'.",
                arr_pat.location,
                TS2493,
              )
            }
        }
      }
    }
    _ => ()
  }
  for elem in arr_pat.elements {
    match elem {
      Some(element) =>
        match element {
          Identifier(id) => {
            // Get the element type from array, or any if unknown
            let (elem_type, c) = any_type(checker)
            checker = if is_const {
              add_local_const_variable(c, id.name, elem_type)
            } else {
              add_local_variable(c, id.name, elem_type)
            }
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
  obj_type : Type,
  is_const : Bool,
) -> TypeChecker {
  let mut checker = checker
  for prop in obj_pat.properties {
    // property_name is the source property name (from the object being destructured)
    // For shorthand { x }, property_name == "x" and name is Identifier("x")
    // For rename { x: y }, property_name == "x" and name is Identifier("y")
    let source_prop_name : String = prop.property_name

    // Get the binding name (what we're declaring)
    let binding_name : String = match prop.name {
      Identifier(id) => id.name
      _ => "" // Nested patterns would need recursive handling
    }
    if binding_name != "" {
      // Look up the property type from the object type
      let (prop_type, c) = match obj_type {
        Object(obj) =>
          match obj.properties.get(source_prop_name) {
            Some(prop_sig) =>
              // If the property is optional and we have a default initializer,
              // the type is the property type with undefined removed
              // For now, just use the property type
              (prop_sig.prop_type, checker)
            None => any_type(checker) // Property not found, use any
          }
        // For type references (like `Thing`), we need to look up the type alias
        // and get its underlying object type's properties
        TypeReference(type_ref) =>
          match checker.type_cache.get(type_ref.name) {
            Some(Object(obj)) =>
              match obj.properties.get(source_prop_name) {
                Some(prop_sig) => (prop_sig.prop_type, checker)
                None => any_type(checker)
              }
            _ => any_type(checker)
          }
        _ => any_type(checker) // For other types, use any
      }
      checker = if is_const {
        add_local_const_variable(c, binding_name, prop_type)
      } else {
        add_local_variable(c, binding_name, prop_type)
      }
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
/// Helper: Resolve type from type_node, fallback to any type
/// Pattern A: Basic type resolution with any fallback
fn resolve_type_or_any(
  checker : TypeChecker,
  type_node : Node
) -> (Type, TypeChecker) {
  match get_type_from_type_node(checker, type_node) {
    (Some(t), c) => (t, c)
    (None, c) => any_type(c)
  }
}

///|
/// Helper: Resolve type from optional type annotation, fallback to any
/// Pattern B: Parameter/property type resolution
fn resolve_type_annotation_or_any(
  checker : TypeChecker,
  type_annotation : Node?
) -> (Type, TypeChecker) {
  match type_annotation {
    Some(type_node) => resolve_type_or_any(checker, type_node)
    None => any_type(checker)
  }
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
/// Get the bigint type
pub fn bigint_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  (BigInt(info), checker)
}

///|
/// Check if a Type is bigint (for use in checker.mbt)
fn type_is_bigint(t : Type) -> Bool {
  match t {
    BigInt(_) => true
    _ => false
  }
}

///|
/// Check if a Type is string-like (string, string literal, or template literal)
fn type_is_string_like(t : Type) -> Bool {
  match t {
    String(_) | StringLiteral(_, _) | TemplateLiteral(_) => true
    _ => false
  }
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
fn get_type_parameters_from_type(_t : Type) -> Array[CheckerTypeParameter] {
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
  (IndexAccess({ object_type, index_type, info, is_keyof: false }), checker)
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

// Maximum number of constituents allowed in a union type before reporting TS2590

///|
let max_union_constituents : Int = 100000

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
  // TS2590: Check if union is too complex
  if flattened.length() > max_union_constituents {
    let checker = add_diagnostic_with_code(
      checker,
      "Expression produces a union type that is too complex to represent.",
      checker.current_location,
      TS2590,
    )
    // Return 'any' type as fallback when union is too complex
    return any_type(checker)
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
  check_source_file_with_options(bound, false, Target::ESNext)
}

///|
/// Check a bound source file with compiler options
pub fn check_source_file_with_options(
  bound : BoundSourceFile,
  no_unchecked_indexed_access : Bool,
  target : Target,
  no_implicit_any? : Bool = false,
) -> CheckResult {
  let mut checker = TypeChecker::new_with_options(
    bound.file_path,
    Some(bound.global_scope),
    no_unchecked_indexed_access,
    target,
    no_implicit_any~,
  )

  // Apply global augmentations to the global scope
  // This handles `declare global { interface SymbolConstructor { ... } }` blocks
  if bound.global_augmentations.length() > 0 {
    checker = apply_global_augmentations_to_checker(
      checker,
      bound.global_augmentations,
    )
  }

  // Push a top-level scope for the source file so local variables are tracked
  let checker = push_local_scope(checker)
  let checker = check_statements(checker, bound.statements)
  // Pop the top-level scope
  let checker = pop_local_scope(checker)

  // Check for unused @ts-expect-error directives (TS2578)
  let checker = check_unused_ts_expect_error_directives(
    checker,
    bound.ts_expect_error_directives,
  )

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
/// Check a bound source file with external types from other modules
/// This enables cross-file type checking by providing types from imported modules.
pub fn check_source_file_with_external_types(
  bound : BoundSourceFile,
  external_registry : ExternalTypeRegistry,
  no_unchecked_indexed_access : Bool,
  target : Target,
  no_implicit_any? : Bool = false,
) -> CheckResult {
  let mut checker = TypeChecker::new_with_options(
    bound.file_path,
    Some(bound.global_scope),
    no_unchecked_indexed_access,
    target,
    no_implicit_any~,
  )

  // Apply global augmentations to the global scope
  // This handles `declare global { interface SymbolConstructor { ... } }` blocks
  if bound.global_augmentations.length() > 0 {
    checker = apply_global_augmentations_to_checker(
      checker,
      bound.global_augmentations,
    )
  }

  // Build import map from module_info.imports
  let import_map = build_import_map(
    bound.module_info.imports,
    bound.file_path,
    external_registry,
  )

  // Store external registry and import map in checker for type resolution
  let checker = {
    ..checker,
    external_registry: Some(external_registry),
    import_map,
  }

  // Push a top-level scope for the source file so local variables are tracked
  let checker = push_local_scope(checker)
  let checker = check_statements(checker, bound.statements)
  // Pop the top-level scope
  let checker = pop_local_scope(checker)

  // Check for unused @ts-expect-error directives (TS2578)
  let checker = check_unused_ts_expect_error_directives(
    checker,
    bound.ts_expect_error_directives,
  )

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
/// Build import map from ImportInfo array
/// Maps local name -> (resolved_module_path, original_name)
fn build_import_map(
  imports : Array[ImportInfo],
  current_file : String,
  registry : ExternalTypeRegistry,
) -> Map[String, (String, String)] {
  let import_map : Map[String, (String, String)] = Map::new()
  for import_info in imports {
    let module_spec = import_info.module_specifier

    // Resolve module path - first try registry mappings, then relative path resolution
    let resolved_module = resolve_module_path_with_registry(
      module_spec, current_file, registry,
    )

    // Handle default import
    match import_info.default_import {
      Some(local_name) =>
        import_map.set(local_name, (resolved_module, "default"))
      None => ()
    }

    // Handle namespace import (import * as ns from 'mod')
    match import_info.namespace_import {
      Some(local_name) => import_map.set(local_name, (resolved_module, "*"))
      None => ()
    }

    // Handle named imports
    for named in import_info.named_imports {
      let (property_name, local_name) = named
      // If property_name is different, that's the original name
      // e.g., import { foo as bar } -> property_name="foo", local_name="bar"
      let original_name = if property_name.length() > 0 {
        property_name
      } else {
        local_name
      }
      import_map.set(local_name, (resolved_module, original_name))
    }
  }
  import_map
}

///|
/// Resolve a module specifier using the registry mappings (for node_modules) and relative paths
fn resolve_module_path_with_registry(
  module_spec : String,
  current_file : String,
  registry : ExternalTypeRegistry,
) -> String {
  // Handle relative imports (./foo, ../bar)
  if module_spec.has_prefix("./") || module_spec.has_prefix("../") {
    // Get directory of current file
    let dir = get_directory_from_path(current_file)

    // Join with module specifier and normalize
    let joined = if dir.length() > 0 {
      dir + "/" + module_spec
    } else {
      module_spec
    }

    // Add .ts extension if not present
    let with_ext = if joined.has_suffix(".ts") || joined.has_suffix(".tsx") {
      joined
    } else {
      joined + ".ts"
    }

    // Normalize path (remove ./ and resolve ../)
    normalize_import_path(with_ext)
  } else {
    // Non-relative import (node_modules, etc.) - try registry first
    registry.resolve_module(module_spec)
  }
}

///|
/// Resolve a module specifier relative to the current file (legacy, used without registry)
fn resolve_module_path(module_spec : String, current_file : String) -> String {
  // Handle relative imports (./foo, ../bar)
  if module_spec.has_prefix("./") || module_spec.has_prefix("../") {
    // Get directory of current file
    let dir = get_directory_from_path(current_file)

    // Join with module specifier and normalize
    let joined = if dir.length() > 0 {
      dir + "/" + module_spec
    } else {
      module_spec
    }

    // Add .ts extension if not present
    let with_ext = if joined.has_suffix(".ts") || joined.has_suffix(".tsx") {
      joined
    } else {
      joined + ".ts"
    }

    // Normalize path (remove ./ and resolve ../)
    normalize_import_path(with_ext)
  } else {
    // Non-relative import (node_modules, etc.) - return as-is
    module_spec
  }
}

///|
/// Get directory from a file path
fn get_directory_from_path(path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' {
      last_slash = i
    }
  }
  if last_slash >= 0 {
    substring(path, 0, last_slash)
  } else {
    ""
  }
}

///|
/// Normalize an import path by resolving . and .. components
fn normalize_import_path(path : String) -> String {
  let parts = split_path(path)
  let result : Array[String] = []
  for part in parts {
    if part == "." {
      // Skip current directory
      continue
    } else if part == ".." {
      // Go up one directory
      if result.length() > 0 && result[result.length() - 1] != ".." {
        let _ = result.pop()

      } else {
        result.push(part)
      }
    } else if part.length() > 0 {
      result.push(part)
    }
  }
  "/" +
  result
  .iter()
  .fold(init="", fn(acc, part) {
    if acc.length() == 0 {
      part
    } else {
      acc + "/" + part
    }
  })
}

///|
/// Split a path by /
fn split_path(path : String) -> Array[String] {
  let parts : Array[String] = []
  let mut current = ""
  for c in path {
    if c == '/' {
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
/// Get substring of a string
fn substring(s : String, start : Int, end : Int) -> String {
  let mut result = ""
  for i = start; i < end && i < s.length(); i = i + 1 {
    result = result + s[i].unsafe_to_char().to_string()
  }
  result
}

///|
/// Resolve type from external registry for an imported symbol
fn resolve_import_type(checker : TypeChecker, name : String) -> Type? {
  // Check if this name is an import
  match checker.import_map.get(name) {
    None => None
    Some((module_path, original_name)) =>
      // Look up in external registry
      match checker.external_registry {
        None => None
        Some(registry) =>
          if original_name == "default" {
            // Default import
            match registry.lookup_default(module_path) {
              Some(info) => Some(type_v2_to_type(info.ty))
              None => None
            }
          } else if original_name == "*" {
            // Namespace import - create module type
            match registry.get_module(module_path) {
              Some(module_types) =>
                Some(module_types_to_object_type(module_types))
              None => None
            }
          } else {
            // Named import
            match registry.lookup_export(module_path, original_name) {
              Some(info) => Some(type_v2_to_type(info.ty))
              None => None
            }
          }
      }
  }
}

///|
/// Lookup a member of an imported namespace from external types
/// For imports like "import * as m4 from 'm4'", look up m4.foo in the external registry
fn lookup_imported_namespace_member(
  checker : TypeChecker,
  namespace_name : String,
  member_name : String,
) -> Type? {
  // Check if this namespace is an import
  match checker.import_map.get(namespace_name) {
    None => None
    Some((module_path, original_name)) => {
      // Only handle namespace imports (import * as ns)
      if original_name != "*" {
        return None
      }
      // Look up in external registry
      match checker.external_registry {
        None => None
        Some(registry) =>
          // Look up the export from the module
          match registry.lookup_export(module_path, member_name) {
            Some(info) => Some(type_v2_to_type(info.ty))
            None => None
          }
      }
    }
  }
}

///|
/// Convert ObjectTypeV2 to ObjectType
fn object_type_v2_to_type(obj : ObjectTypeV2) -> ObjectType {
  let info = default_type_info()
  let props : Map[String, PropertySignature] = Map::new()
  for entry in obj.fields {
    let (name, field) = entry
    props.set(name, PropertySignature::{
      name,
      prop_type: type_v2_to_type(field.ty),
      is_optional: field.optional,
      is_readonly: field.is_readonly,
    })
  }
  ObjectType::{
    properties: props,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info,
    class_name: obj.class_name,
  }
}

///|
/// Resolve a global namespace from external types (e.g., declare module M1 in .d.ts files)
fn resolve_global_namespace(checker : TypeChecker, name : String) -> Type? {
  match checker.external_registry {
    None => None
    Some(registry) =>
      match registry.lookup_global_namespace(name) {
        Some(ns_type) => {
          let obj_type = object_type_v2_to_type(ns_type)
          Some(Object(obj_type))
        }
        None => None
      }
  }
}

///|
/// Create a default TypeInfo for conversions from TypeV2
fn default_type_info() -> TypeInfo {
  TypeInfo::{ id: 0, flags: TypeFlags::default() }
}

///|
/// Convert TypeV2 to Type
fn type_v2_to_type(ty : TypeV2) -> Type {
  let info = default_type_info()
  match ty {
    TNumber => Number(info)
    TString => String(info)
    TBoolean => Boolean(info)
    TUndefined => Undefined(info)
    TNull => Null(info)
    TVoid => Void(info)
    TAny => Any(info)
    TUnknown => Unknown(info)
    TNever => Never(info)
    TBigInt => BigInt(info)
    TSymbol => Symbol(info)
    TUniqueSymbol(_) => Symbol(info) // Treat unique symbols as regular symbols for now
    TObject(obj) => {
      let props : Map[String, PropertySignature] = Map::new()
      for entry in obj.fields {
        let (name, field) = entry
        props.set(name, PropertySignature::{
          name,
          prop_type: type_v2_to_type(field.ty),
          is_optional: field.optional,
          is_readonly: field.is_readonly,
        })
      }
      Object(ObjectType::{
        properties: props,
        call_signatures: [],
        construct_signatures: [],
        index_signatures: [],
        info,
        class_name: obj.class_name,
      })
    }
    TArray(elem) =>
      Array(CheckerArrayType::{ element_type: type_v2_to_type(elem), info })
    TTuple(elements) => {
      let elem_types = elements.map(fn(elem) {
        TupleElement::{
          element_type: type_v2_to_type(elem.ty),
          is_optional: elem.optional,
          is_rest: elem.is_rest,
          label: elem.label,
        }
      })
      Tuple(CheckerTupleType::{ element_types: elem_types, info })
    }
    TFunction(func) => {
      let params = func.params.map(fn(p) {
        CheckerParameter::{
          name: p.name,
          param_type: type_v2_to_type(p.ty),
          is_optional: p.optional,
          is_rest: p.is_rest,
        }
      })
      Function(CheckerFunctionType::{
        parameters: params,
        return_type: type_v2_to_type(func.return_type),
        info,
      })
    }
    TUnion(types) => {
      let converted = types.map(type_v2_to_type)
      Union(CheckerUnionType::{ types: converted, info })
    }
    TIntersection(types) => {
      let converted = types.map(type_v2_to_type)
      Intersection(CheckerIntersectionType::{ types: converted, info })
    }
    TLiteralString(s) => StringLiteral(s, info)
    TLiteralNumber(n) => NumberLiteral(n, info)
    TLiteralBool(b) => BooleanLiteral(b, info)
    TLiteralBigInt(_) => BigInt(info) // BigInt literal treated as BigInt type
    TGenericInstance(name, type_args) =>
      TypeReference(TypeReferenceType::{
        name,
        type_arguments: type_args.map(type_v2_to_type),
        info,
      })
    TTypeParam(name, constraint) =>
      // Type parameters are represented as type references for now
      TypeReference(TypeReferenceType::{ name, type_arguments: [], info })
    TConditional(cond) =>
      Conditional(CheckerConditionalType::{
        check_type: type_v2_to_type(cond.check_type),
        extends_type: type_v2_to_type(cond.extends_type),
        true_type: type_v2_to_type(cond.true_type),
        false_type: type_v2_to_type(cond.false_type),
        info,
      })
    TIndexAccess(idx) =>
      IndexAccess(CheckerIndexAccessType::{
        object_type: type_v2_to_type(idx.object_type),
        index_type: type_v2_to_type(idx.index_type),
        info,
        is_keyof: false,
      })
    TMapped(mapped) =>
      Mapped(CheckerMappedType::{
        type_parameter: CheckerTypeParameter::{
          name: mapped.type_param.name,
          constraint: match mapped.type_param.constraint {
            Some(c) => Some(type_v2_to_type(c))
            None => None
          },
          default_type: match mapped.type_param.default_type {
            Some(d) => Some(type_v2_to_type(d))
            None => None
          },
        },
        name_type: match mapped.name_type {
          Some(n) => Some(type_v2_to_type(n))
          None => None
        },
        template_type: type_v2_to_type(mapped.template_type),
        readonly_modifier: MappedModifier::Unchanged,
        optional_modifier: MappedModifier::Unchanged,
        info,
      })
    TInfer(name) => Infer(CheckerInferType::{ type_parameter_name: name, info })
    TTemplateLiteral(tpl) =>
      TemplateLiteral(CheckerTemplateLiteralType::{
        texts: tpl.texts,
        types: tpl.types.map(type_v2_to_type),
        info,
      })
    TError => Error(info)
  }
}

///|
/// Convert ModuleTypes to an Object type (for namespace imports)
fn module_types_to_object_type(module_types : ModuleTypes) -> Type {
  let props : Map[String, PropertySignature] = Map::new()
  let type_info = default_type_info()
  for entry in module_types.named_exports {
    let (name, export_info) = entry
    props.set(name, PropertySignature::{
      name,
      prop_type: type_v2_to_type(export_info.ty),
      is_optional: false,
      is_readonly: true,
    })
  }
  Object(ObjectType::{
    properties: props,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: type_info,
    class_name: None,
  })
}

///|
/// Check for unused @ts-expect-error directives (TS2578)
/// A @ts-expect-error directive should suppress an error on the following line.
/// If no error occurs on that line, the directive is "unused" and TS2578 is reported.
fn check_unused_ts_expect_error_directives(
  checker : TypeChecker,
  directives : Array[SourceLocation],
) -> TypeChecker {
  if directives.is_empty() {
    return checker
  }

  // Build a set of line numbers that have errors
  let error_lines : Map[Int, Bool] = Map::new()
  for diag in checker.diagnostics {
    error_lines.set(diag.location.start.line, true)
  }

  // Check each @ts-expect-error directive
  let mut result_checker = checker
  for directive_loc in directives {
    // The directive is on line N, it should suppress errors on line N+1
    let expected_error_line = directive_loc.start.line + 1

    // Check if there's an error on the expected line
    if not(error_lines.contains(expected_error_line)) {
      // No error on the following line - report TS2578
      result_checker = add_diagnostic_with_code(
        result_checker,
        "Unused '@ts-expect-error' directive.",
        directive_loc,
        TS2578,
      )
    }
  }
  result_checker
}

///|
/// Check an array of statements
fn check_statements(
  checker : TypeChecker,
  statements : Array[Node],
) -> TypeChecker {
  let mut checker = checker

  // Check function overloads (TS2391, TS2383, TS2394)
  checker = check_statement_overloads(statements, checker)
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
    ImportDeclaration(import_decl) =>
      check_import_declaration(checker, import_decl)
    ExportDeclaration(_) => checker // Exports checked separately
    TryStatement(try_stmt) => check_try_statement(checker, try_stmt)
    ThrowStatement(throw_stmt) => check_throw_statement(checker, throw_stmt)
    SwitchStatement(switch_stmt) => check_switch_statement(checker, switch_stmt)
    BreakStatement(_) => checker
    ContinueStatement(_) => checker
    ModuleDeclaration(mod_decl) => check_module_declaration(checker, mod_decl)
    _ => checker // Other statements
  }
}

///|
/// Check module/namespace declaration body
fn check_module_declaration(
  checker : TypeChecker,
  mod_decl : ModuleDeclaration,
) -> TypeChecker {
  // Look up the namespace symbol to get its locals (all members, not just exports)
  // This allows internal access to non-exported members within the namespace
  match lookup_symbol(checker, mod_decl.name) {
    Some(ns_symbol) =>
      // Use locals (all members) for internal namespace scope, not just exports
      match ns_symbol.locals {
        Some(locals) => {
          // Push the namespace locals as a local scope
          let checker = push_local_scope(checker)
          // Add all locals to namespace_symbols so lookup_symbol can find them
          // Use direct map mutation (Map.set mutates in place)
          locals.each(fn(name, sym) { checker.namespace_symbols.set(name, sym) })
          // Check the body with the namespace scope active
          let checker = match mod_decl.body {
            Some(BlockStatement(block)) =>
              check_statements(checker, block.statements)
            Some(body) => check_statement(checker, body)
            None => checker
          }
          // Clear namespace_symbols after checking (to not leak between namespaces)
          locals.each(fn(name, _sym) { checker.namespace_symbols.remove(name) })
          // Pop the namespace scope
          pop_local_scope(checker)
        }
        None =>
          // No locals, just check the body
          match mod_decl.body {
            Some(BlockStatement(block)) =>
              check_statements(checker, block.statements)
            Some(body) => check_statement(checker, body)
            None => checker
          }
      }
    None =>
      // Namespace symbol not found, just check the body
      match mod_decl.body {
        Some(BlockStatement(block)) =>
          check_statements(checker, block.statements)
        Some(body) => check_statement(checker, body)
        None => checker
      }
  }
}

// ============================================================================
// Variable Statement Checking
// ============================================================================

///|
/// Check if modifiers include Declare (ambient declaration)
fn is_ambient_declaration(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    if m == Declare {
      return true
    }
  }
  false
}

///|
/// Collect all type reference names from a type (for TS2742 check)
fn collect_type_reference_names(t : Type) -> Array[String] {
  let names : Array[String] = []
  collect_type_reference_names_inner(t, names)
  names
}

///|
/// Helper to recursively collect type reference names
fn collect_type_reference_names_inner(t : Type, names : Array[String]) -> Unit {
  match t {
    TypeReference(ref_type) => {
      names.push(ref_type.name)
      // Also collect from type arguments
      for arg in ref_type.type_arguments {
        collect_type_reference_names_inner(arg, names)
      }
    }
    Object(obj) => {
      // Collect from class_name if present
      match obj.class_name {
        Some(name) => names.push(name)
        None => ()
      }
      // Collect from property types
      obj.properties.each(fn(_key, prop) {
        collect_type_reference_names_inner(prop.prop_type, names)
      })
      // Collect from call signatures
      for sig in obj.call_signatures {
        collect_type_reference_names_inner(sig.return_type, names)
        for param in sig.parameters {
          collect_type_reference_names_inner(param.param_type, names)
        }
      }
      // Collect from construct signatures
      for sig in obj.construct_signatures {
        collect_type_reference_names_inner(sig.return_type, names)
        for param in sig.parameters {
          collect_type_reference_names_inner(param.param_type, names)
        }
      }
      // Collect from index signatures
      for idx_sig in obj.index_signatures {
        collect_type_reference_names_inner(idx_sig.parameter_type, names)
        collect_type_reference_names_inner(idx_sig.return_type, names)
      }
    }
    Function(func_type) => {
      collect_type_reference_names_inner(func_type.return_type, names)
      for param in func_type.parameters {
        collect_type_reference_names_inner(param.param_type, names)
      }
    }
    Union(union_type) =>
      for constituent in union_type.types {
        collect_type_reference_names_inner(constituent, names)
      }
    Intersection(intersection_type) =>
      for constituent in intersection_type.types {
        collect_type_reference_names_inner(constituent, names)
      }
    Array(arr_type) =>
      collect_type_reference_names_inner(arr_type.element_type, names)
    Tuple(tuple_type) =>
      for elem in tuple_type.element_types {
        collect_type_reference_names_inner(elem.element_type, names)
      }
    Conditional(cond_type) => {
      collect_type_reference_names_inner(cond_type.check_type, names)
      collect_type_reference_names_inner(cond_type.extends_type, names)
      collect_type_reference_names_inner(cond_type.true_type, names)
      collect_type_reference_names_inner(cond_type.false_type, names)
    }
    Mapped(mapped_type) => {
      collect_type_reference_names_inner(mapped_type.template_type, names)
      // Check type parameter constraint
      match mapped_type.type_parameter.constraint {
        Some(ct) => collect_type_reference_names_inner(ct, names)
        None => ()
      }
      // Check name_type if present
      match mapped_type.name_type {
        Some(nt) => collect_type_reference_names_inner(nt, names)
        None => ()
      }
    }
    IndexAccess(idx_access) => {
      collect_type_reference_names_inner(idx_access.object_type, names)
      collect_type_reference_names_inner(idx_access.index_type, names)
    }
    // Primitives, literals, infer, error don't contain type references
    _ => ()
  }
}

///|
/// Check if a symbol is exported (for TS2742 check)
fn is_symbol_exported(checker : TypeChecker, name : String) -> Bool {
  // First check if it's a built-in type (always accessible)
  let builtins = [
    "Array", "Object", "String", "Number", "Boolean", "Function", "Symbol", "BigInt",
    "Promise", "Map", "Set", "WeakMap", "WeakSet", "Date", "RegExp", "Error", "TypeError",
    "RangeError", "SyntaxError", "ReferenceError", "Partial", "Required", "Readonly",
    "Pick", "Omit", "Record", "Exclude", "Extract", "NonNullable", "ReturnType",
    "Parameters", "InstanceType", "ConstructorParameters", "ThisParameterType", "OmitThisParameter",
    "ThisType", "Awaited", "Generator", "AsyncGenerator", "IterableIterator", "AsyncIterableIterator",
    "ReadonlyArray", "ReadonlyMap", "ReadonlySet",
  ]
  if builtins.contains(name) {
    return true
  }

  // Check if symbol exists and is exported
  match lookup_symbol(checker, name) {
    Some(symbol) => symbol.flags.is_export
    None =>
      // If we can't find the symbol, it might be from another file
      // In single-file mode, assume it's accessible (conservative)
      true
  }
}

///|
/// Infer return type from function body (for TS2742 check)
fn infer_function_body_return_type(
  checker : TypeChecker,
  func : FunctionDeclaration,
) -> (Type?, TypeChecker) {
  match func.body {
    Some(BlockStatement(block)) => {
      // Collect return types from all return statements
      let return_types : Array[Type] = []
      let mut checker = checker
      for stmt in block.statements {
        match stmt {
          ReturnStatement(ret) =>
            match ret.expression {
              Some(expr) => {
                let (return_type, c) = infer_type(checker, expr)
                checker = c
                return_types.push(return_type)
              }
              None => {
                let (vt, c) = void_type(checker)
                checker = c
                return_types.push(vt)
              }
            }
          _ => ()
        }
      }
      if return_types.is_empty() {
        let (vt, checker) = void_type(checker)
        (Some(vt), checker)
      } else if return_types.length() == 1 {
        (Some(return_types[0]), checker)
      } else {
        // Multiple return types - create union
        let (ut, checker) = union_type(checker, return_types)
        (Some(ut), checker)
      }
    }
    _ => (None, checker)
  }
}

///|
/// Check TS2742: Inferred type of exported function cannot be named without reference
fn check_inferred_type_accessibility(
  checker : TypeChecker,
  func : FunctionDeclaration,
) -> TypeChecker {
  // Only check exported functions without explicit return type
  if not(has_export_modifier(func.modifiers)) {
    return checker
  }
  if func.return_type is Some(_) {
    return checker // Has explicit return type, no issue
  }

  // Get function name
  let func_name = match func.name {
    Some(Identifier(id)) => id.name
    _ => return checker // Anonymous function, skip
  }

  // Infer the return type from body
  let (return_type_opt, checker) = infer_function_body_return_type(
    checker, func,
  )
  match return_type_opt {
    Some(return_type) => {
      // Collect all type references in the return type
      let type_names = collect_type_reference_names(return_type)

      // Check if any referenced type is not exported
      for name in type_names {
        if not(is_symbol_exported(checker, name)) {
          return add_diagnostic_with_code(
            checker,
            "The inferred type of '\{func_name}' cannot be named without a reference to '\{name}'. This is likely not portable. A type annotation is necessary.",
            func.location,
            TS2742,
          )
        }
      }
      checker
    }
    None => checker
  }
}

///|
/// Check variable statement
fn check_variable_statement(
  checker : TypeChecker,
  var_stmt : VariableStatement,
) -> TypeChecker {
  let mut checker = checker

  // Check if this is an ambient declaration (declare const/let/var)
  let is_ambient = is_ambient_declaration(var_stmt.modifiers)

  // Check if this is an exported variable (for TS2494 check)
  let is_exported = has_export_modifier(var_stmt.modifiers)
  for i = 0; i < var_stmt.declarations.length(); i = i + 1 {
    let decl = var_stmt.declarations[i]

    // TS2481: Check if var declaration conflicts with let/const in parent scope
    // This occurs when 'var' is declared in a nested block, but a let/const with the
    // same name exists in a parent scope (e.g., for-of loop binding)
    // We only check this for block-scoped variables (those in const_vars set)
    if not(var_stmt.is_let) && not(var_stmt.is_const) {
      match decl.name {
        Identifier(id) => {
          // Check if there's a block-scoped variable with this name in parent scope
          // Only trigger error if the variable in parent scope is let/const (in const_vars)
          // AND we're in a nested scope (not the function-level scope)
          if checker.local_scopes.length() > 1 && is_local_const_variable(checker, id.name) {
            checker = add_diagnostic_with_code(
              checker,
              "Cannot initialize outer scoped variable '\{id.name}' in the same scope as block scoped declaration '\{id.name}'.",
              decl.location,
              TS2481,
            )
          }
        }
        _ => ()
      }
    }

    checker = check_variable_declaration(checker, decl, var_stmt.is_const)

    // TS1155: 'const' declarations must be initialized
    // Only check if NOT ambient declaration (declare const x: T is allowed)
    if var_stmt.is_const && not(is_ambient) {
      match decl.initializer {
        None =>
          checker = add_diagnostic_with_code(
            checker,
            "'const' declarations must be initialized.",
            decl.location,
            TS1155,
          )
        Some(_) => ()
      }
    }

    // TS1182: A destructuring declaration must have an initializer
    // Only check if NOT ambient declaration (declare var is allowed without initializer)
    // Note: for-of/for-in loop bindings are handled separately and don't go through this function
    if not(is_ambient) {
      match (decl.name, decl.initializer) {
        (ArrayBindingPattern(_), None) | (ObjectBindingPattern(_), None) =>
          checker = add_diagnostic_with_code(
            checker,
            "A destructuring declaration must have an initializer.",
            decl.location,
            TS1182,
          )
        _ => ()
      }
    }

    // TS2494: Exported variable using private type
    // Note: Modern TypeScript (5.x) does NOT emit TS2494 in most cases.
    // When generating .d.ts files, TypeScript includes non-exported types rather than erroring.
    // We match TypeScript behavior by not checking for TS2494.
    ignore(is_exported)

    // Track uninitialized variables for TS2454 (definite assignment)
    // Only track if:
    // 1. NOT ambient declaration
    // 2. Has type annotation but no initializer
    // 3. Is let or const (NOT var - var is hoisted and initialized to undefined)
    // 4. Type annotation is NOT 'any' (any-typed vars are implicitly allowed uninitialized)
    let is_block_scoped = var_stmt.is_let || var_stmt.is_const
    if not(is_ambient) && is_block_scoped {
      match (decl.name, decl.type_annotation, decl.initializer) {
        (Identifier(id), Some(type_ann), None) => {
          // Skip tracking if type annotation is 'any'
          let is_any_type = match type_ann {
            KeywordType(kt) => kt.kind == Any
            _ => false
          }
          if not(is_any_type) {
            // Block-scoped variable declared with type but no initializer - track it
            checker.uninitialized_vars.set(id.name, decl.location.start.line)
          }
        }
        _ => ()
      }
    }
  }
  checker
}

///|
/// Check TS2494: Exported variable using private type
fn check_exported_variable_private_type(
  checker : TypeChecker,
  decl : VariableDeclaration,
) -> TypeChecker {
  // Get the variable name
  let var_name = match decl.name {
    Identifier(id) => id.name
    _ => return checker // Skip binding patterns for now
  }

  // First check type annotation node directly for type references
  // This catches cases where the annotation is a direct reference to a private type
  match decl.type_annotation {
    Some(type_node) => {
      let type_names = collect_type_names_from_type_node(type_node)
      for name in type_names {
        if not(is_symbol_exported(checker, name)) {
          return add_diagnostic_with_code(
            checker,
            "Exported variable '\{var_name}' has or is using private name '\{name}'.",
            decl.location,
            TS2494,
          )
        }
      }
      checker
    }
    None =>
      // No annotation - check inferred type from initializer
      match decl.initializer {
        Some(init) => {
          let (t, checker) = infer_type(checker, init)
          let type_names = collect_type_reference_names(t)
          for name in type_names {
            if not(is_symbol_exported(checker, name)) {
              return add_diagnostic_with_code(
                checker,
                "Exported variable '\{var_name}' has or is using private name '\{name}'.",
                decl.location,
                TS2494,
              )
            }
          }
          checker
        }
        None => checker
      }
  }
}

///|
/// Collect type names from a type annotation node (before resolution)
fn collect_type_names_from_type_node(node : Node) -> Array[String] {
  let names : Array[String] = []
  collect_type_names_from_type_node_inner(node, names)
  names
}

///|
/// Helper to recursively collect type names from type annotation nodes
fn collect_type_names_from_type_node_inner(
  node : Node,
  names : Array[String],
) -> Unit {
  match node {
    TypeReference(type_ref) => {
      names.push(type_ref.type_name)
      // Also check type arguments
      for arg in type_ref.type_arguments {
        collect_type_names_from_type_node_inner(arg, names)
      }
    }
    UnionType(union_type) =>
      for t in union_type.types {
        collect_type_names_from_type_node_inner(t, names)
      }
    IntersectionType(intersection_type) =>
      for t in intersection_type.types {
        collect_type_names_from_type_node_inner(t, names)
      }
    ArrayType(arr_type) =>
      collect_type_names_from_type_node_inner(arr_type.element_type, names)
    TupleType(tuple_type) =>
      // element_types is Array[Node]
      for elem in tuple_type.element_types {
        collect_type_names_from_type_node_inner(elem, names)
      }
    TypeLiteral(type_literal) =>
      // Check property types in type literal (members is Array[Node])
      for mem in type_literal.members {
        match mem {
          TypeLiteralProperty(prop) =>
            match prop.type_node {
              Some(t) => collect_type_names_from_type_node_inner(t, names)
              None => ()
            }
          _ => ()
        }
      }
    FunctionType(func_type) => {
      // Check return type
      collect_type_names_from_type_node_inner(func_type.return_type, names)
      // Check parameter types
      for param in func_type.parameters {
        match param {
          Parameter(p) =>
            match p.type_annotation {
              Some(t) => collect_type_names_from_type_node_inner(t, names)
              None => ()
            }
          _ => ()
        }
      }
    }
    _ => () // Other node types don't contain type references
  }
}

///|
/// Check variable declaration
fn check_variable_declaration(
  checker : TypeChecker,
  decl : VariableDeclaration,
  is_const : Bool,
) -> TypeChecker {
  // Check for TS2748: variable referencing itself in initializer (temporal dead zone)
  let checker = check_variable_self_reference(checker, decl)

  // Get the declared type (if any)
  let (declared_type, checker) = match decl.type_annotation {
    Some(type_node) => get_type_from_type_node(checker, type_node)
    None => (None, checker)
  }

  // Get the initializer type (if any)
  // For const declarations with literal type annotations, infer literal types from expressions
  let (init_type, checker) = match decl.initializer {
    Some(init) => {
      let (t, c) = infer_type_with_context(
        checker, init, declared_type, is_const,
      )
      (Some(t), c)
    }
    None => (None, checker)
  }

  // Check for TS2475: const enum used as value (not in property/index access)
  let checker = match decl.initializer {
    Some(init) =>
      match get_const_enum_name(checker, init) {
        Some(_) =>
          add_diagnostic_with_code(
            checker,
            "'const' enums can only be used in property or index access expressions or the right hand side of an import declaration or export assignment or type query.",
            get_node_location(init),
            TS2475,
          )
        None => checker
      }
    None => checker
  }

  // Check compatibility if both are present using check_assignment_compatibility
  let checker = match (declared_type, init_type) {
    (Some(decl_t), Some(init_t)) =>
      check_assignment_compatibility(checker, init_t, decl_t, decl.location)
    _ => checker
  }

  // Check for array destructuring on non-array type (TS2460)
  // Use declared type if present (e.g., `: any`), otherwise use init_type
  let type_for_array_check = match declared_type {
    Some(t) => Some(t)
    None => init_type
  }
  let checker = match (decl.name, type_for_array_check) {
    (ArrayBindingPattern(_), Some(check_t)) =>
      if not(is_array_like_type(check_t)) {
        add_diagnostic_with_code(
          checker,
          "Type '\{type_to_string(check_t)}' is not an array type.",
          decl.location,
          TS2460,
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

  // TS7034: Check for implicit any[] type in variable declaration
  // This occurs when a variable is initialized to [] without type annotation
  let checker = if checker.no_implicit_any && declared_type.is_empty() {
    match var_type {
      Array(arr_type) =>
        match arr_type.element_type {
          Any(_) =>
            match decl.name {
              Identifier(id) => {
                // Track this variable for TS7005 (when it's referenced)
                checker.implicit_any_array_vars.add(id.name)
                add_diagnostic_with_code(
                  checker,
                  "Variable '\{id.name}' implicitly has type 'any[]' in some locations where its type cannot be determined.",
                  decl.location,
                  TS7034,
                )
              }
              _ => checker
            }
          _ => checker
        }
      _ => checker
    }
  } else {
    checker
  }

  // Get the variable name and add to local scope
  // Use add_local_const_variable for const declarations to track const-ness
  let checker = match decl.name {
    Identifier(id) =>
      if is_const {
        add_local_const_variable(checker, id.name, var_type)
      } else {
        add_local_variable(checker, id.name, var_type)
      }
    ArrayBindingPattern(arr_pat) =>
      // For array destructuring, add each element's name to scope
      add_array_binding_elements_to_scope(checker, arr_pat, var_type, is_const)
    ObjectBindingPattern(obj_pat) =>
      // For object destructuring, add each property to scope
      add_object_binding_elements_to_scope(checker, obj_pat, var_type, is_const)
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
  // Set flag only if the expression is directly a YieldExpression
  // This indicates the yield result is not used (statement-level yield)
  let checker = match expr_stmt.expression {
    YieldExpression(_) => { ..checker, in_expression_statement: true }
    _ => checker
  }
  let (_, checker) = infer_type(checker, expr_stmt.expression)
  // Reset flag after checking expression
  { ..checker, in_expression_statement: false }
}

///|
/// Infer the type of an expression with contextual type information
/// For const declarations with literal type annotations, this infers literal types
fn infer_type_with_context(
  checker : TypeChecker,
  expr : Node,
  contextual_type : Type?,
  is_const : Bool,
) -> (Type, TypeChecker) {
  // For const declarations, check if we should infer a literal type
  if is_const {
    match (expr, contextual_type) {
      // String literal with string literal type annotation
      (StringLiteral(lit), Some(StringLiteral(expected_val, _))) =>
        if lit.value == expected_val {
          // Infer the literal type
          string_literal_type(checker, lit.value)
        } else {
          // Different value - infer base type, will cause type error
          string_type(checker)
        }
      // String literal with union type annotation containing string literals
      (StringLiteral(lit), Some(Union(union))) =>
        if union_contains_string_literal(union, lit.value) {
          string_literal_type(checker, lit.value)
        } else {
          string_type(checker)
        }
      // Number literal with number literal type annotation
      (NumericLiteral(lit), Some(NumberLiteral(expected_val, _))) => {
        let num_val = @strconv.parse_double(lit.value) catch { _ => 0.0 }
        if num_val == expected_val {
          number_literal_type(checker, num_val)
        } else {
          number_type(checker)
        }
      }
      // Number literal with union type annotation containing number literals
      (NumericLiteral(lit), Some(Union(union))) => {
        let num_val = @strconv.parse_double(lit.value) catch { _ => 0.0 }
        if union_contains_number_literal(union, num_val) {
          number_literal_type(checker, num_val)
        } else {
          number_type(checker)
        }
      }
      // Boolean literal with boolean literal type annotation
      (BooleanLiteral(lit), Some(BooleanLiteral(expected_val, _))) =>
        if lit.value == expected_val {
          boolean_literal_type(checker, lit.value)
        } else {
          boolean_type(checker)
        }
      // Boolean literal with union type annotation containing boolean literals
      (BooleanLiteral(lit), Some(Union(union))) =>
        if union_contains_boolean_literal(union, lit.value) {
          boolean_literal_type(checker, lit.value)
        } else {
          boolean_type(checker)
        }
      // Array literal with tuple type annotation - infer as tuple
      (ArrayLiteralExpression(arr), Some(Tuple(tuple_type))) =>
        infer_tuple_from_array_literal(checker, arr, tuple_type)
      // Array literal with array-of-tuples type annotation (for const too)
      // e.g., const array: [number, string][] = [[0, "hello"]]
      (ArrayLiteralExpression(arr), Some(Array(arr_type))) =>
        match arr_type.element_type {
          Tuple(tuple_type) =>
            // Infer as array of tuples with contextual typing for each element
            infer_array_with_tuple_elements(checker, arr, tuple_type)
          _ => infer_type(checker, expr)
        }
      // For other cases, fall back to regular inference
      _ => infer_type(checker, expr)
    }
  } else {
    // Not a const declaration, but still check for tuple type annotation
    match (expr, contextual_type) {
      // Array literal with tuple type annotation - infer as tuple (for var/let too)
      (ArrayLiteralExpression(arr), Some(Tuple(tuple_type))) =>
        infer_tuple_from_array_literal(checker, arr, tuple_type)
      // Array literal with array-of-tuples type annotation
      // e.g., var array: [number, string][] = [[0, "hello"]]
      (ArrayLiteralExpression(arr), Some(Array(arr_type))) =>
        match arr_type.element_type {
          Tuple(tuple_type) =>
            // Infer as array of tuples with contextual typing for each element
            infer_array_with_tuple_elements(checker, arr, tuple_type)
          _ => infer_type(checker, expr)
        }
      _ => infer_type(checker, expr)
    }
  }
}

///|
/// Check if a union type contains a specific string literal
fn union_contains_string_literal(
  union : CheckerUnionType,
  value : String,
) -> Bool {
  for t in union.types {
    match t {
      StringLiteral(v, _) => if v == value { return true }
      _ => ()
    }
  }
  false
}

///|
/// Check if a union type contains a specific number literal
fn union_contains_number_literal(
  union : CheckerUnionType,
  value : Double,
) -> Bool {
  for t in union.types {
    match t {
      NumberLiteral(v, _) => if v == value { return true }
      _ => ()
    }
  }
  false
}

///|
/// Check if a union type contains a specific boolean literal
fn union_contains_boolean_literal(
  union : CheckerUnionType,
  value : Bool,
) -> Bool {
  for t in union.types {
    match t {
      BooleanLiteral(v, _) => if v == value { return true }
      _ => ()
    }
  }
  false
}

///|
/// Infer a tuple type from an array literal with contextual tuple type
fn infer_tuple_from_array_literal(
  checker : TypeChecker,
  arr : ArrayLiteralExpression,
  tuple_type : CheckerTupleType,
) -> (Type, TypeChecker) {
  let mut checker = checker
  let element_types : Array[TupleElement] = []

  // Check if tuple has a rest element
  let mut rest_element_idx : Int? = None
  for i = 0; i < tuple_type.element_types.length(); i = i + 1 {
    if tuple_type.element_types[i].is_rest {
      rest_element_idx = Some(i)
      break
    }
  }

  // Infer types for all array literal elements
  for i = 0; i < arr.elements.length(); i = i + 1 {
    let elem_type = match arr.elements[i] {
      Some(elem_node) => {
        let (t, c) = infer_type(checker, elem_node)
        checker = c
        t
      }
      None => {
        // Hole in array - use undefined
        let (t, c) = undefined_type(checker)
        checker = c
        t
      }
    }
    element_types.push(TupleElement::{
      element_type: elem_type,
      is_optional: false,
      is_rest: false,
      label: None,
    })
  }
  let (info, checker) = create_type_info(checker)
  (Tuple(CheckerTupleType::{ element_types, info }), checker)
}

///|
/// Infer array literal as array of tuples with contextual typing
/// Used when: var array: [number, string][] = [[0, "hello"]]
fn infer_array_with_tuple_elements(
  checker : TypeChecker,
  arr : ArrayLiteralExpression,
  tuple_type : CheckerTupleType,
) -> (Type, TypeChecker) {
  let mut checker = checker
  let inferred_elements = []

  // Infer each element with the tuple type as context
  for i = 0; i < arr.elements.length(); i = i + 1 {
    match arr.elements[i] {
      Some(elem_node) => {
        // Each element should be inferred as a tuple with the contextual type
        match elem_node {
          ArrayLiteralExpression(inner_arr) => {
            // Infer this inner array as a tuple
            let (elem_type, c) = infer_tuple_from_array_literal(
              checker, inner_arr, tuple_type,
            )
            checker = c
            inferred_elements.push(elem_type)
          }
          _ => {
            // Non-array element - infer normally
            let (elem_type, c) = infer_type(checker, elem_node)
            checker = c
            inferred_elements.push(elem_type)
          }
        }
      }
      None => {
        // Hole in array - use undefined
        let (t, c) = undefined_type(checker)
        checker = c
        inferred_elements.push(t)
      }
    }
  }

  // Create an array type where the element type is the tuple type
  let (info, checker) = create_type_info(checker)
  let array_type = Array(CheckerArrayType::{
    element_type: Tuple(tuple_type),
    info,
  })
  (array_type, checker)
}

///|
/// Infer the type of an expression
fn infer_type(checker : TypeChecker, expr : Node) -> (Type, TypeChecker) {
  match expr {
    NumericLiteral(_) => number_type(checker)
    StringLiteral(_) => string_type(checker)
    BooleanLiteral(_) => boolean_type(checker)
    NullLiteral(_) => null_type(checker)
    BigIntLiteral(lit) => {
      // TS2737: BigInt literals are not available when targeting lower than ES2020
      let checker = if not(checker.target.supports_bigint()) {
        add_diagnostic_with_code(
          checker,
          "BigInt literals are not available when targeting lower than ES2020.",
          lit.location,
          TS2737,
        )
      } else {
        checker
      }
      bigint_type(checker)
    }
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
    TaggedTemplateExpression(tte) =>
      infer_tagged_template_expression_type(checker, tte)
    ThisExpression(this_expr) => infer_this_type(checker, this_expr.location)
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
  // Handle 'arguments' identifier specially
  if id.name == "arguments" {
    // Check if 'arguments' is a parameter in the current scope (shadows built-in)
    if is_in_innermost_scope(checker, id.name) {
      // arguments is a parameter name, let normal lookup handle it
      ()
    } else if checker.innermost_function_is_arrow {
      // The innermost function is an arrow - arrow functions don't have 'arguments'
      // In ES3/ES5, this is always an error
      // In ES2015+, arrow functions inherit arguments from enclosing non-arrow function
      if checker.target.older_than(ES2015) {
        let checker = add_diagnostic_with_code(
          checker,
          "The 'arguments' object cannot be referenced in an arrow function in ES3 and ES5. Consider using a standard function expression.",
          id.location,
          TS2496,
        )
        return any_type(checker)
        // ES2015+: Arrow functions can access enclosing function's arguments
        // Only if we're inside a regular function (somewhere in the outer scope)
      } else if is_in_regular_function(checker) {
        return get_arguments_type(checker)
      }
      // Otherwise it's an error - no enclosing function
    } else if is_in_regular_function(checker) {
      // Innermost function is a regular function - arguments is available
      return get_arguments_type(checker)
    }
    // At top level or in arrow without enclosing function - let it fall through to error
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

  // TS2454: Check for variable used before being assigned
  match checker.uninitialized_vars.get(id.name) {
    Some(_) => {
      let checker = add_diagnostic_with_code(
        checker,
        "Variable '\{id.name}' is used before being assigned.",
        id.location,
        TS2454,
      )
      return any_type(checker)
    }
    None => ()
  }

  // TS7005: Check for variable with implicit any[] type being referenced
  // Don't emit for assignment targets (left side of = in destructuring patterns)
  let checker = if checker.no_implicit_any &&
    checker.implicit_any_array_vars.contains(id.name) &&
    not(checker.in_destructuring_pattern) {
    add_diagnostic_with_code(
      checker,
      "Variable '\{id.name}' implicitly has an 'any[]' type.",
      id.location,
      TS7005,
    )
  } else {
    checker
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
            Some(symbol) => {
              // Check for TS2710: Cannot use namespace as a value
              // Only if namespace has no value exports (only type exports)
              // BUT first check if this is a namespace import from an external module
              // (e.g., import * as m1 from "m1") - those should resolve from registry
              if is_namespace_symbol(symbol) &&
                not(namespace_has_value_exports(symbol)) {
                // Before reporting error, check if this is an imported namespace
                // that has exports in the external registry
                match resolve_import_type(checker, id.name) {
                  Some(imported_type) => return (imported_type, checker)
                  None => {
                    let checker = add_diagnostic_with_code(
                      checker,
                      "Cannot use namespace '\{id.name}' as a value.",
                      id.location,
                      TS2710,
                    )
                    return any_type(checker)
                  }
                }
              }
              // Get type from symbol
              match get_symbol_type(checker, symbol) {
                (Some(t), c) => (t, c)
                (None, c) =>
                  // Symbol exists but type not yet computed - infer from declaration
                  infer_symbol_type(c, symbol)
              }
            }
            None =>
              // Check for built-in globals before emitting error
              match get_builtin_global_type(checker, id.name) {
                Some((builtin_type, c)) => (builtin_type, c)
                None =>
                  // Check for imported types from external modules
                  match resolve_import_type(checker, id.name) {
                    Some(imported_type) => (imported_type, checker)
                    None =>
                      // Check for global namespaces from external types (e.g., declare module M1 in .d.ts files)
                      match resolve_global_namespace(checker, id.name) {
                        Some(ns_type) => (ns_type, checker)
                        None => {
                          // Variable not found - try to find a similar name for suggestion
                          let suggestion = find_similar_name_in_scope(
                            checker,
                            id.name,
                          )
                          let checker = match suggestion {
                            Some(similar_name) =>
                              add_diagnostic_with_code(
                                checker,
                                "Cannot find name '\{id.name}'. Did you mean '\{similar_name}'?",
                                id.location,
                                TS2552,
                              )
                            None =>
                              // No similar name found - check for specialized error codes
                              // TS2579: Test runner globals (Jest, Mocha, etc.)
                              if is_test_runner_global(id.name) {
                                add_diagnostic_with_code(
                                  checker,
                                  "Cannot find name '\{id.name}'. Do you need to install type definitions for a test runner? Try `npm i --save-dev @types/jest` or `npm i --save-dev @types/mocha`.",
                                  id.location,
                                  TS2579,
                                )
                              } else if is_dom_global(id.name) {
                                // TS2580: DOM/Browser globals
                                add_diagnostic_with_code(
                                  checker,
                                  "Cannot find name '\{id.name}'. Do you need to change your target library? Try changing the 'lib' compiler option to include 'dom'.",
                                  id.location,
                                  TS2580,
                                )
                              } else if is_es_library_global(id.name) {
                                // TS2584: ES library globals (newer JS features)
                                add_diagnostic_with_code(
                                  checker,
                                  "Cannot find name '\{id.name}'. Do you need to change your target library? Try changing the 'lib' compiler option to include a newer ES version.",
                                  id.location,
                                  TS2584,
                                )
                              } else {
                                // Generic TS2304
                                add_diagnostic_with_code(
                                  checker,
                                  "Cannot find name '" + id.name + "'",
                                  id.location,
                                  TS2304,
                                )
                              }
                          }
                          any_type(checker)
                        }
                      }
                  }
              }
          }
      }
  }
}

///|
/// Check if a name is a test runner global (Jest, Mocha, Jasmine, etc.)
/// Used for TS2579 error
fn is_test_runner_global(name : String) -> Bool {
  // Jest globals
  name == "describe" ||
  name == "it" ||
  name == "test" ||
  name == "expect" ||
  name == "beforeEach" ||
  name == "afterEach" ||
  name == "beforeAll" ||
  name == "afterAll" ||
  name == "jest" ||
  // Mocha globals
  name == "suite" ||
  name == "context" ||
  name == "specify" ||
  name == "before" ||
  name == "after" ||
  // Jasmine globals
  name == "jasmine" ||
  name == "spyOn" ||
  name == "fail" ||
  name == "pending" ||
  name == "fdescribe" ||
  name == "fit" ||
  name == "xdescribe" ||
  name == "xit"
}

///|
/// Check if a name is a DOM/Browser global
/// Used for TS2580 error
fn is_dom_global(name : String) -> Bool {
  name == "document" ||
  name == "window" ||
  name == "navigator" ||
  name == "location" ||
  name == "history" ||
  name == "localStorage" ||
  name == "sessionStorage" ||
  name == "fetch" ||
  name == "XMLHttpRequest" ||
  name == "WebSocket" ||
  name == "Worker" ||
  name == "ServiceWorker" ||
  name == "Blob" ||
  name == "File" ||
  name == "FileReader" ||
  name == "FormData" ||
  name == "URL" ||
  name == "URLSearchParams" ||
  name == "HTMLElement" ||
  name == "Element" ||
  name == "Node" ||
  name == "Event" ||
  name == "EventTarget" ||
  name == "MutationObserver" ||
  name == "IntersectionObserver" ||
  name == "ResizeObserver" ||
  name == "requestAnimationFrame" ||
  name == "cancelAnimationFrame" ||
  name == "alert" ||
  name == "confirm" ||
  name == "prompt"
}

///|
/// Check if a name is an ES library global (newer JS features)
/// Used for TS2584 error
fn is_es_library_global(name : String) -> Bool {
  // ES2015+ features
  name == "Proxy" ||
  name == "Reflect" ||
  name == "WeakMap" ||
  name == "WeakSet" ||
  name == "SharedArrayBuffer" ||
  name == "Atomics" ||
  // ES2017+ features
  name == "AsyncIterator" ||
  // ES2020+ features
  name == "BigInt" ||
  name == "globalThis" ||
  // ES2021+ features
  name == "FinalizationRegistry" ||
  name == "WeakRef" ||
  // Iterator helpers (ES2024+)
  name == "Iterator"
}

///|
/// Check if a symbol is a namespace/module (for TS2694, TS2710 checks)
fn is_namespace_symbol(symbol : Symbol) -> Bool {
  symbol.kind == Module
}

///|
/// Check if a namespace has only type exports (no value exports)
/// Used for TS2710 - namespace can only be used as value if it has value members
fn namespace_has_value_exports(symbol : Symbol) -> Bool {
  match symbol.exports {
    Some(exports) => {
      // Check if any export is a value (not just types)
      let mut has_value = false
      exports.each(fn(_name, exp_symbol) {
        // Values: Variable, Function, Class, Enum, EnumMember
        // Types: Interface, Type, TypeParameter
        if exp_symbol.kind == Variable ||
          exp_symbol.kind == Function ||
          exp_symbol.kind == Class ||
          exp_symbol.kind == Enum ||
          exp_symbol.kind == EnumMember {
          has_value = true
        }
      })
      has_value
    }
    None => false
  }
}

///|
/// Get type for built-in globals like console, JSON, Math, etc.
fn get_builtin_global_type(
  checker : TypeChecker,
  name : String,
) -> (Type, TypeChecker)? {
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
  } else if name == "exports" {
    Some(get_exports_type(checker))
  } else if name == "module" {
    Some(get_module_type(checker))
  } else if name == "Infinity" {
    // Infinity is a global constant of type number
    let (id, checker) = next_type_id(checker)
    Some((Type::Number(TypeInfo::{ id, flags: TypeFlags::default() }), checker))
  } else if name == "NaN" {
    // NaN is a global constant of type number
    let (id, checker) = next_type_id(checker)
    Some((Type::Number(TypeInfo::{ id, flags: TypeFlags::default() }), checker))
  } else if name == "undefined" {
    // undefined is a global constant
    let (id, checker) = next_type_id(checker)
    Some(
      (Type::Undefined(TypeInfo::{ id, flags: TypeFlags::default() }), checker),
    )
  } else if name == "Map" {
    Some(get_map_constructor_type(checker))
  } else if name == "Set" {
    Some(get_set_constructor_type(checker))
  } else if name == "WeakMap" {
    Some(get_weakmap_constructor_type(checker))
  } else if name == "WeakSet" {
    Some(get_weakset_constructor_type(checker))
  } else {
    None
  }
}

///|
/// Get the type for the 'arguments' object (IArguments interface)
/// arguments is an array-like object available in regular functions
fn get_arguments_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let any_info = TypeInfo::{ id: 0, flags: default_flags }

  // IArguments has:
  // - length: number
  // - [index: number]: any (numeric indexing)
  // - callee: Function (deprecated but exists)
  let properties : Map[String, PropertySignature] = Map::new()

  // length property
  let (num_id, checker) = next_type_id(checker)
  properties.set("length", PropertySignature::{
    name: "length",
    prop_type: Type::Number(TypeInfo::{ id: num_id, flags: default_flags }),
    is_optional: false,
    is_readonly: false,
  })

  // callee property (Function type)
  let (func_id, checker) = next_type_id(checker)
  properties.set("callee", PropertySignature::{
    name: "callee",
    prop_type: Type::Function(CheckerFunctionType::{
      parameters: [],
      return_type: Type::Any(any_info),
      info: TypeInfo::{ id: func_id, flags: default_flags },
    }),
    is_optional: false,
    is_readonly: false,
  })

  // Create the arguments type with numeric index signature
  let arguments_type = Type::Object(ObjectType::{
    properties,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [
      IndexSignature::{
        parameter_name: "index",
        parameter_type: Type::Number(TypeInfo::{ id: 0, flags: default_flags }),
        return_type: Type::Any(any_info),
        is_readonly: false,
      },
    ],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })
  (arguments_type, checker)
}

///|
/// Get the type for the console global object
fn get_console_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let console_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let void_info = TypeInfo::{ id: 0, flags: default_flags }

  // All console methods accept any number of any type arguments via rest parameter
  // and return void
  console_methods.set("log", make_rest_method("log", "data", TKAny, TKVoid, void_info))
  console_methods.set("warn", make_rest_method("warn", "data", TKAny, TKVoid, void_info))
  console_methods.set("error", make_rest_method("error", "data", TKAny, TKVoid, void_info))
  console_methods.set("info", make_rest_method("info", "data", TKAny, TKVoid, void_info))
  console_methods.set("debug", make_rest_method("debug", "data", TKAny, TKVoid, void_info))

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

  // JSON.parse - takes string, returns any
  json_methods.set("parse", make_unary_method("parse", "text", TKString, TKAny, info))

  // JSON.stringify - takes any, returns string
  json_methods.set("stringify", make_unary_method("stringify", "value", TKAny, TKString, info))

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

  // Unary math methods (number -> number)
  let unary_methods = ["abs", "floor", "ceil", "sqrt", "sin", "cos", "tan", "round", "log", "exp"]
  for method_name in unary_methods {
    math_methods.set(method_name, make_unary_method(method_name, "x", TKNumber, TKNumber, info))
  }

  // Nullary methods
  math_methods.set("random", make_nullary_method("random", TKNumber, info))

  // Rest parameter methods
  math_methods.set("max", make_rest_method("max", "values", TKNumber, TKNumber, info))
  math_methods.set("min", make_rest_method("min", "values", TKNumber, TKNumber, info))

  // Binary method
  math_methods.set("pow", make_binary_method("pow", "base", TKNumber, "exponent", TKNumber, TKNumber, info))

  // Constants
  math_methods.set("PI", make_readonly_property("PI", Type::Number(info)))
  math_methods.set("E", make_readonly_property("E", Type::Number(info)))

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

  // Promise.resolve - optional parameter
  let resolve_param = CheckerParameter::{
    name: "value",
    param_type: Type::Any(info),
    is_optional: true,
    is_rest: false,
  }
  promise_methods.set("resolve", make_method_property(
    "resolve",
    [resolve_param],
    Type::Any(info),
    info
  ))

  // Promise.reject - optional parameter
  let reject_param = CheckerParameter::{
    name: "reason",
    param_type: Type::Any(info),
    is_optional: true,
    is_rest: false,
  }
  promise_methods.set("reject", make_method_property(
    "reject",
    [reject_param],
    Type::Any(info),
    info
  ))

  // Promise.all - required parameter
  let all_param = CheckerParameter::{
    name: "values",
    param_type: Type::Any(info),
    is_optional: false,
    is_rest: false,
  }
  promise_methods.set("all", make_method_property(
    "all",
    [all_param],
    Type::Any(info),
    info
  ))

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

  // Date.now - returns number
  date_methods.set("now", make_nullary_method("now", TKNumber, info))

  // Date.parse - string -> number
  date_methods.set("parse", make_unary_method("parse", "s", TKString, TKNumber, info))

  // Create Date instance type with methods like getTime, getFullYear, etc.
  let (instance_id, checker) = next_type_id(checker)
  let instance_methods : Map[String, PropertySignature] = Map::new()
  instance_methods.set("getTime", make_nullary_method("getTime", TKNumber, info))

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
    parameters: [
      CheckerParameter::{
        name: "value",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      },
    ],
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

  // String.fromCharCode - rest parameter
  string_methods.set("fromCharCode", make_rest_method("fromCharCode", "codes", TKNumber, TKString, info))

  // Create String instance type (the result of new String())
  let string_instance_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: Some("String"),
  })

  // Construct signature: new String(value?) => String
  let construct_sig = CheckerSignature::{
    parameters: [
      CheckerParameter::{
        name: "value",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      },
    ],
    return_type: string_instance_type,
    type_parameters: [],
  }
  let string_type = Type::Object(ObjectType::{
    properties: string_methods,
    call_signatures: [],
    construct_signatures: [construct_sig],
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

  // Symbol.for - string -> symbol
  symbol_methods.set("for", make_unary_method("for", "key", TKString, TKSymbol, info))

  // Well-known Symbol properties (ES2015+)
  // These are readonly properties that return unique symbol values
  let symbol_props = [
    "iterator", "asyncIterator", "hasInstance", "isConcatSpreadable",
    "match", "matchAll", "replace", "search", "species", "split",
    "toPrimitive", "toStringTag", "unscopables"
  ]
  for prop_name in symbol_props {
    symbol_methods.set(prop_name, make_readonly_property(prop_name, Type::Symbol(info)))
  }

  // Check for user-defined SymbolConstructor interface augmentation
  let mut checker = checker
  match lookup_symbol(checker, "SymbolConstructor") {
    Some(symbol) =>
      match symbol.kind {
        Interface =>
          // Merge properties from the user-defined interface
          match resolve_interface_type(checker, symbol) {
            (Some(Object(user_obj)), c) => {
              checker = c
              // Add user-defined properties to symbol_methods
              for entry in user_obj.properties {
                let (key, value) = entry
                // Don't overwrite built-in properties
                if not(symbol_methods.contains(key)) {
                  symbol_methods.set(key, value)
                }
              }
            }
            (_, c) => checker = c
          }
        _ => ()
      }
    None => ()
  }
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
  error_instance_properties.set("message", make_simple_property("message", Type::String(info)))
  error_instance_properties.set("name", make_simple_property("name", Type::String(info)))
  // stack is optional
  error_instance_properties.set("stack", PropertySignature::{
    name: "stack",
    prop_type: Type::String(info),
    is_optional: true,
    is_readonly: false,
  })
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

  // Array.isArray - any -> boolean
  array_methods.set("isArray", make_unary_method("isArray", "arg", TKAny, TKBoolean, info))

  // Array.from - arrayLike -> any
  array_methods.set("from", make_unary_method("from", "arrayLike", TKAny, TKAny, info))

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

  // Object.keys, Object.values, Object.entries - all take any object and return any
  let unary_object_methods = ["keys", "values", "entries"]
  for method_name in unary_object_methods {
    object_methods.set(method_name, make_unary_method(method_name, "o", TKAny, TKAny, info))
  }

  // Object.assign - target + rest sources -> any
  let assign_target = CheckerParameter::{
    name: "target",
    param_type: Type::Any(info),
    is_optional: false,
    is_rest: false,
  }
  let assign_sources = CheckerParameter::{
    name: "sources",
    param_type: Type::Any(info),
    is_optional: false,
    is_rest: true,
  }
  object_methods.set("assign", make_method_property(
    "assign",
    [assign_target, assign_sources],
    Type::Any(info),
    info
  ))

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

  // Number.isNaN, Number.isFinite - any -> boolean
  number_methods.set("isNaN", make_unary_method("isNaN", "number", TKAny, TKBoolean, info))
  number_methods.set("isFinite", make_unary_method("isFinite", "number", TKAny, TKBoolean, info))

  // Number.parseInt - string -> number
  number_methods.set("parseInt", make_unary_method("parseInt", "string", TKString, TKNumber, info))

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
/// Get the type for the Map global constructor
fn get_map_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let map_methods : Map[String, PropertySignature] = Map::new()
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Map.groupBy - static method with two parameters
  map_methods.set("groupBy", make_binary_method(
    "groupBy",
    "items", TKAny,
    "keySelector", TKAny,
    TKAny,
    info
  ))

  // Map instance type (returned by new Map())
  let (instance_id, checker) = next_type_id(checker)
  let map_instance_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id: instance_id, flags: default_flags },
    class_name: Some("Map"),
  })

  // Construct signature: new Map(entries?) => Map
  let construct_sig = CheckerSignature::{
    parameters: [
      CheckerParameter::{
        name: "entries",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      },
    ],
    return_type: map_instance_type,
    type_parameters: [],
  }
  let map_type = Type::Object(ObjectType::{
    properties: map_methods,
    call_signatures: [],
    construct_signatures: [construct_sig],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })
  (map_type, checker)
}

///|
/// Get the type for the Set global constructor
fn get_set_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // Set instance type (returned by new Set())
  let (instance_id, checker) = next_type_id(checker)
  let set_instance_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id: instance_id, flags: default_flags },
    class_name: Some("Set"),
  })

  // Construct signature: new Set(values?) => Set
  let construct_sig = CheckerSignature::{
    parameters: [
      CheckerParameter::{
        name: "values",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      },
    ],
    return_type: set_instance_type,
    type_parameters: [],
  }
  let set_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [construct_sig],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })
  (set_type, checker)
}

///|
/// Get the type for the WeakMap global constructor
fn get_weakmap_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // WeakMap instance type (returned by new WeakMap())
  let (instance_id, checker) = next_type_id(checker)
  let weakmap_instance_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id: instance_id, flags: default_flags },
    class_name: Some("WeakMap"),
  })

  // Construct signature: new WeakMap(entries?) => WeakMap
  let construct_sig = CheckerSignature::{
    parameters: [
      CheckerParameter::{
        name: "entries",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      },
    ],
    return_type: weakmap_instance_type,
    type_parameters: [],
  }
  let weakmap_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [construct_sig],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })
  (weakmap_type, checker)
}

///|
/// Get the type for the WeakSet global constructor
fn get_weakset_constructor_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id: 0, flags: default_flags }

  // WeakSet instance type (returned by new WeakSet())
  let (instance_id, checker) = next_type_id(checker)
  let weakset_instance_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info: TypeInfo::{ id: instance_id, flags: default_flags },
    class_name: Some("WeakSet"),
  })

  // Construct signature: new WeakSet(values?) => WeakSet
  let construct_sig = CheckerSignature::{
    parameters: [
      CheckerParameter::{
        name: "values",
        param_type: Type::Any(info),
        is_optional: true,
        is_rest: false,
      },
    ],
    return_type: weakset_instance_type,
    type_parameters: [],
  }
  let weakset_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [construct_sig],
    index_signatures: [],
    info: TypeInfo::{ id, flags: default_flags },
    class_name: None,
  })
  (weakset_type, checker)
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
/// Get the type for the exports object (Node.js CommonJS exports)
/// exports is typed as { [key: string]: any } to allow dynamic property assignment
fn get_exports_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id, flags: default_flags }

  // exports is an object with an index signature: { [key: string]: any }
  // This allows assignments like exports.foo = ... and exports["bar"] = ...
  let string_index = IndexSignature::{
    parameter_name: "key",
    parameter_type: Type::String(TypeInfo::{ id: 0, flags: default_flags }),
    return_type: Type::Any(TypeInfo::{ id: 0, flags: default_flags }),
    is_readonly: false,
  }
  let exports_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [string_index],
    info,
    class_name: None,
  })
  (exports_type, checker)
}

///|
/// Get the type for the module object (Node.js CommonJS module)
/// module is typed as { exports: { [key: string]: any } }
fn get_module_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (id, checker) = next_type_id(checker)
  let default_flags = TypeFlags::default()
  let info = TypeInfo::{ id, flags: default_flags }

  // module.exports is the same type as exports
  let string_index = IndexSignature::{
    parameter_name: "key",
    parameter_type: Type::String(TypeInfo::{ id: 0, flags: default_flags }),
    return_type: Type::Any(TypeInfo::{ id: 0, flags: default_flags }),
    is_readonly: false,
  }
  let exports_inner_type = Type::Object(ObjectType::{
    properties: Map::new(),
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [string_index],
    info: TypeInfo::{ id: 0, flags: default_flags },
    class_name: None,
  })
  let module_properties : Map[String, PropertySignature] = Map::new()
  module_properties.set("exports", PropertySignature::{
    name: "exports",
    prop_type: exports_inner_type,
    is_optional: false,
    is_readonly: false,
  })
  let module_type = Type::Object(ObjectType::{
    properties: module_properties,
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info,
    class_name: None,
  })
  (module_type, checker)
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
  // For Alias symbols (imports), try to resolve from external registry
  if symbol.kind == SymbolKind::Alias {
    match resolve_import_type(checker, symbol.name) {
      Some(imported_type) => return (imported_type, checker)
      None => ()
    }
  }
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
/// Get type of a function declaration (for hoisting, without caching to symbol)
fn get_function_declaration_type(
  checker : TypeChecker,
  func : FunctionDeclaration,
) -> (Type, TypeChecker) {
  // Build parameter list
  let parameters : Array[CheckerParameter] = []
  let mut c = checker
  for param_node in func.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
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
  let checker = c

  // Get return type
  let (return_type, checker) = resolve_type_annotation_or_any(checker, func.return_type)
  let (info, checker) = create_type_info(checker)
  let func_type = Type::Function({ parameters, return_type, info })
  (func_type, checker)
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
  let mut c = checker
  for param_node in func.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
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
  let checker = c

  // Get return type
  let (return_type, checker) = resolve_type_annotation_or_any(checker, func.return_type)
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
              let (param_type, checker) = resolve_type_annotation_or_any(checker, p.type_annotation)
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
        if func.body is None {
          call_signatures.push({ parameters, return_type, type_parameters: [] })
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
  if checker.resolving_symbols.get(symbol.id) is Some(_) {
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

  // Inherit properties from parent class (if extends clause exists)
  for heritage_clause in class_decl.heritage_clauses {
    if heritage_clause.kind == Extends {
      for type_node in heritage_clause.types {
        // Get the type of the parent class by looking up the class name
        let (parent_type, c) = match type_node {
          TypeReference(type_ref) =>
            // Look up the class by name
            match lookup_symbol(checker, type_ref.type_name) {
              Some(parent_symbol) =>
                match get_symbol_type(checker, parent_symbol) {
                  (Some(t), c) => (t, c)
                  (None, c) => infer_symbol_type(c, parent_symbol)
                }
              None => any_type(checker)
            }
          _ => infer_type(checker, type_node)
        }
        checker = c
        // If parent is an object type (class constructor), inherit both static and instance properties
        match parent_type {
          Object(parent_obj) => {
            // Copy static properties from parent
            for entry in parent_obj.properties.iter() {
              static_properties.set(entry.0, entry.1)
            }
            // Copy instance properties from parent's construct signature
            if parent_obj.construct_signatures.length() > 0 {
              match parent_obj.construct_signatures[0].return_type {
                Object(parent_instance) =>
                  for entry in parent_instance.properties.iter() {
                    instance_properties.set(entry.0, entry.1)
                  }
                _ => ()
              }
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
        // The method name might be "__@iterator" for Symbol.iterator
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

  // Track generator function context for yield expressions
  // For non-generator methods, we must reset generator_function_depth to 0
  // to ensure yield in nested non-generator methods triggers TS1163
  let saved_generator_depth = checker.generator_function_depth
  let saved_collected_yield_types = checker.collected_yield_types
  let (checker, saved_yield_types) = if method_decl.is_generator {
    let has_return_type = method_decl.return_type is Some(_)
    enter_generator_function(checker, has_return_type)
  } else {
    (
      {
        ..checker,
        generator_function_depth: 0,
        generator_has_return_type: false,
      },
      [],
    )
  }

  // Build parameter list and add parameters to local scope
  let parameters : Array[CheckerParameter] = []
  let mut c = checker
  for param_node in method_decl.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
        let param_name = get_parameter_name(p.name)
        parameters.push({
          name: param_name,
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
        // Add parameter to local scope for body checking
        c = add_local_variable(c, param_name, param_type)
      }
      _ => ()
    }
  }
  let checker = c

  // Get return type
  let (return_type, checker) = resolve_type_annotation_or_any(checker, method_decl.return_type)

  // Check method body for errors (including await expressions)
  let checker = match method_decl.body {
    Some(body) => {
      // Hoist var declarations to the method scope before checking body
      let checker = hoist_var_declarations(checker, body)
      match body {
        BlockStatement(block) => check_block_statement(checker, block)
        _ => checker
      }
    }
    None => checker
  }

  // Exit generator function context or restore saved depth
  let (checker, _collected_yield_types) = if method_decl.is_generator {
    exit_generator_function(checker, saved_yield_types)
  } else {
    (
      {
        ..checker,
        generator_function_depth: saved_generator_depth,
        collected_yield_types: saved_collected_yield_types,
      },
      [],
    )
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
  let (param_type, checker) = resolve_type_annotation_or_any(checker, param.type_annotation)

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
  // For assignment expressions with destructuring patterns on the left,
  // mark all variables in the pattern as initialized BEFORE inferring their types.
  // This prevents false TS2454 errors for variables being assigned to.
  let checker = match bin_expr.operator {
    Assign
    | AddAssign
    | SubtractAssign
    | MultiplyAssign
    | DivideAssign
    | RemainderAssign
    | BitwiseAndAssign
    | BitwiseOrAssign
    | BitwiseXorAssign =>
      mark_assignment_pattern_variables_initialized(checker, bin_expr.left)
    _ => checker
  }
  // For assignment operators, the left side is a destructuring pattern (not a value)
  // Set flag to avoid TS2548 errors for rest elements in patterns
  let is_assignment = match bin_expr.operator {
    Assign
    | AddAssign
    | SubtractAssign
    | MultiplyAssign
    | DivideAssign
    | RemainderAssign
    | BitwiseAndAssign
    | BitwiseOrAssign
    | BitwiseXorAssign => true
    _ => false
  }
  let checker = if is_assignment {
    { ..checker, in_destructuring_pattern: true }
  } else {
    checker
  }
  let (left_type, checker) = infer_type(checker, bin_expr.left)
  // Reset the flag after inferring left side
  let checker = { ..checker, in_destructuring_pattern: false }
  let (right_type, checker) = infer_type(checker, bin_expr.right)

  // Determine result type based on operator
  match bin_expr.operator {
    // Addition: can be number + number -> number OR string + string -> string OR bigint + bigint -> bigint
    Add =>
      // Check if either operand is a string (including template literals and string literals)
      if type_is_string_like(left_type) || type_is_string_like(right_type) {
        string_type(checker)
      } else {
        match (left_type, right_type) {
          (BigInt(_), BigInt(_)) =>
            // bigint + bigint -> bigint
            bigint_type(checker)
          _ => {
            let checker = check_numeric_operands_with_locations(
              checker,
              left_type,
              right_type,
              get_node_location(bin_expr.left),
              get_node_location(bin_expr.right),
            )
            number_type(checker)
          }
        }
      }
    // Arithmetic operators: number op number -> number OR bigint op bigint -> bigint
    Subtract | Multiply | Divide | Remainder | Exponentiate =>
      // Check if both are bigint
      if type_is_bigint(left_type) && type_is_bigint(right_type) {
        bigint_type(checker)
      } else {
        let checker = check_numeric_operands_with_locations(
          checker,
          left_type,
          right_type,
          get_node_location(bin_expr.left),
          get_node_location(bin_expr.right),
        )
        number_type(checker)
      }
    // Bitwise operators: number op number -> number OR bigint op bigint -> bigint
    BitwiseAnd
    | BitwiseOr
    | BitwiseXor
    | LeftShift
    | RightShift
    | UnsignedRightShift =>
      // Check if both are bigint
      if type_is_bigint(left_type) && type_is_bigint(right_type) {
        bigint_type(checker)
      } else {
        let checker = check_numeric_operands_with_locations(
          checker,
          left_type,
          right_type,
          get_node_location(bin_expr.left),
          get_node_location(bin_expr.right),
        )
        number_type(checker)
      }
    // Comparison operators: any op any -> boolean
    LessThan | GreaterThan | LessThanEquals | GreaterThanEquals =>
      boolean_type(checker)
    // Loose equality operators - no type overlap check (type coercion allowed)
    Equals | NotEquals => boolean_type(checker)
    // Strict equality operators - check for no overlap between types (TS2367)
    StrictEquals | StrictNotEquals => {
      let checker = check_equality_type_overlap(
        checker, left_type, right_type, bin_expr,
      )
      boolean_type(checker)
    }
    // instanceof operator: obj instanceof Constructor -> boolean
    InstanceOf => {
      let checker = check_instanceof_operands(
        checker, left_type, right_type, bin_expr,
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
          // Check for const assignment in global scope
          let checker = match lookup_symbol(checker, id.name) {
            Some(symbol) =>
              check_const_assignment(
                checker,
                id.name,
                symbol,
                get_node_location(BinaryExpression(bin_expr)),
              )
            None => checker
          }
          // Check for const assignment in local scope
          let checker = check_local_const_assignment(
            checker,
            id.name,
            get_node_location(BinaryExpression(bin_expr)),
          )
          // First check local scopes (for function parameters and local variables)
          let (checker, declared_type_opt) = match
            lookup_local_variable(checker, id.name) {
            Some(local_type) => (checker, Some(local_type))
            None =>
              // Fall back to global scope lookup
              match lookup_symbol(checker, id.name) {
                Some(symbol) =>
                  // Get the declared type (not narrowed) for assignment checking
                  match get_symbol_type(checker, symbol) {
                    (Some(t), c2) => (c2, Some(t))
                    (None, c2) => (c2, None)
                  }
                None => (checker, None) // Can't find symbol, skip type check
              }
          }
          // Assignment invalidates type narrowing for this variable
          let checker = remove_narrowed_type(checker, id.name)
          // Mark variable as initialized (remove from uninitialized_vars for TS2454)
          let checker = {
            let _ = checker.uninitialized_vars.remove(id.name)
            checker
          }
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
              let has_readonly_index = obj_type.index_signatures
                .iter()
                .any(fn(idx_sig) { idx_sig.is_readonly })
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
                  _ =>
                    // TS2701: The target of an object rest assignment must be a variable or a property access.
                    // In destructuring contexts, only simple identifiers are allowed
                    checker = add_diagnostic_with_code(
                      checker,
                      "The target of an object rest assignment must be a variable or a property access.",
                      loc,
                      TS2701,
                    )
                }
              _ => ()
            }
          }
          // Mark all variables in the destructuring pattern as initialized (for TS2454)
          let checker = mark_assignment_pattern_variables_initialized(
            checker,
            ObjectLiteralExpression(obj),
          )
          (checker, left_type)
        }
        ArrayLiteralExpression(arr) => {
          // Mark all variables in the destructuring pattern as initialized (for TS2454)
          let checker = mark_assignment_pattern_variables_initialized(
            checker,
            ArrayLiteralExpression(arr),
          )
          // For array destructuring, right side can be any iterable (not just array)
          // Use Any type to skip assignability check - iterability was checked elsewhere
          let (any, _) = any_type(checker)
          (checker, any)
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
          // TS2810: Private field can only be assigned using 'this' access
          let checker = check_private_field_this_access(
            checker,
            prop,
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
    // Comma operator: evaluates left, discards result, returns right
    Comma => {
      // TS2695: Left operand of comma operator is unused and has no side effects
      let checker = if not(expression_has_side_effects(bin_expr.left)) {
        add_diagnostic_with_code(
          checker,
          "Left side of comma operator is unused and has no side effects.",
          get_node_location(bin_expr.left),
          DiagnosticCode::TS2695,
        )
      } else {
        checker
      }
      // Comma operator returns the type of the right operand
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
    Plus => {
      // TS2736: Operator '+' cannot be applied to type 'bigint'
      // Note: Unary + is a type coercion operator that converts any value to number
      // It works on strings, objects, etc. - only bigint is an error
      let checker = if type_is_bigint(operand_type) {
        add_diagnostic_with_code(
          checker,
          "Operator '+' cannot be applied to type 'bigint'.",
          get_node_location(UnaryExpression(un_expr)),
          TS2736,
        )
      } else {
        // Unary + converts any value to number, no error for strings/objects
        checker
      }
      number_type(checker)
    }
    Minus | BitwiseNot =>
      // Minus and BitwiseNot work on both number and bigint
      if type_is_bigint(operand_type) {
        // bigint - no error, return bigint
        bigint_type(checker)
      } else {
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
    Delete => {
      // TS2703: The operand of a 'delete' operator must be a property reference
      let checker = match un_expr.operand {
        PropertyAccessExpression(_)
        | ElementAccessExpression(_)
        | OptionalChain(_) =>
          // Valid delete targets
          checker
        Identifier(_) =>
          // delete on identifier is allowed in non-strict mode (though it's a no-op)
          checker
        _ =>
          // Invalid delete target (e.g., literals, template expressions)
          add_diagnostic_with_code(
            checker,
            "The operand of a 'delete' operator must be a property reference.",
            get_node_location(un_expr.operand),
            TS2703,
          )
      }
      boolean_type(checker)
    }
  }
}

///|
/// Infer call expression type with signature matching
fn infer_call_expression_type(
  checker : TypeChecker,
  call : CallExpression,
) -> (Type, TypeChecker) {
  // Check if this is a super() call
  let is_super_call = match call.expression {
    SuperExpression(_) => true
    _ => false
  }

  // TS2335/TS2337/TS17005: Check for super() call outside class/constructor or in extends null
  let checker = match call.expression {
    SuperExpression(super_expr) =>
      // TS17005: A constructor cannot contain a 'super' call when its class extends 'null'
      if checker.in_extends_null_class {
        add_diagnostic_with_code(
          checker,
          "A constructor cannot contain a 'super' call when its class extends 'null'.",
          super_expr.location,
          TS17005,
        )
      } else if not(checker.in_class_body) || not(checker.in_derived_class) {
        // TS2335: 'super' can only be referenced in a derived class
        add_diagnostic_with_code(
          checker,
          "'super' can only be referenced in a derived class.",
          super_expr.location,
          TS2335,
        )
      } else if not(checker.in_constructor) {
        // TS2337: Super calls are not permitted outside constructors
        add_diagnostic_with_code(
          checker,
          "Super calls are not permitted outside constructors or in nested functions inside constructors.",
          super_expr.location,
          TS2337,
        )
      } else {
        // Don't mark super as called yet - arguments are evaluated first!
        // super_called will be set to true AFTER we check the arguments
        checker
      }
    _ => checker
  }
  let (func_type, checker) = infer_type(checker, call.expression)

  // Infer argument types
  // IMPORTANT: For super() calls, arguments are evaluated BEFORE super() completes
  // So 'this' in super(this) should raise TS17009
  let mut checker = checker
  let arg_types : Array[Type] = []
  for i = 0; i < call.arguments.length(); i = i + 1 {
    let (arg_type, c) = infer_type(checker, call.arguments[i])
    arg_types.push(arg_type)
    checker = c
  }

  // Now mark super as called AFTER arguments have been checked
  let checker = if is_super_call &&
    checker.in_constructor &&
    checker.in_derived_class &&
    not(checker.in_extends_null_class) {
    { ..checker, super_called: true }
  } else {
    checker
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
      | TemplateLiteral(_)
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
  let max_allowed = type_params.length()
  let actual = type_args.length()
  if actual < min_required || actual > max_allowed {
    // Use TS2707 when there's a range (optional type params exist)
    if min_required != max_allowed {
      checker = add_diagnostic_with_code(
        checker,
        "Generic type requires between \{min_required} and \{max_allowed} type arguments, but got \{actual}.",
        location,
        DiagnosticCode::TS2707,
      )
    } else if actual < min_required {
      // Exact count required, too few provided
      checker = add_diagnostic_with_code(
        checker,
        "Generic type requires \{min_required} type argument(s), but got \{actual}.",
        location,
        DiagnosticCode::TS2314,
      )
    } else {
      // Exact count required, too many provided
      checker = add_diagnostic_with_code(
        checker,
        "Generic type requires \{max_allowed} type argument(s), but got \{actual}.",
        location,
        DiagnosticCode::TS2558,
      )
    }
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
      get_instanceof_guard_with_type(checker, bin.left, bin.right)
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
/// Creates the class type for narrowing when x instanceof Class is true
fn get_instanceof_guard_with_type(
  checker : TypeChecker,
  left : Node,
  right : Node,
) -> TypeGuardInfo? {
  match (left, right) {
    (Identifier(id), Identifier(class_id)) => {
      // Create TypeReference for the class
      let (info, _) = create_type_info(checker)
      let class_type = Type::TypeReference({
        name: class_id.name,
        type_arguments: [],
        info,
      })
      Some({
        parameter_name: id.name,
        type_when_true: Some(class_type),
        type_when_false: None, // Could exclude the class type from union
      })
    }
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
/// Mark all variables in a destructuring assignment pattern as initialized
/// This handles object patterns like { x, y, ...rest } and array patterns like [a, b, ...rest]
fn mark_assignment_pattern_variables_initialized(
  checker : TypeChecker,
  pattern : Node,
) -> TypeChecker {
  match pattern {
    Identifier(id) => {
      let _ = checker.uninitialized_vars.remove(id.name)
      checker
    }
    ObjectLiteralExpression(obj) => {
      let mut checker = checker
      for prop in obj.properties {
        match prop {
          PropertyAssignment(_, value, _) =>
            // { x: y } or { x: y = default } - y is the target, default is read
            match value {
              BinaryExpression(bin) =>
                // { x: y = default } - only y is target, default is read
                if bin.operator == Assign {
                  checker = mark_assignment_pattern_variables_initialized(
                    checker,
                    bin.left,
                  )
                } else {
                  checker = mark_assignment_pattern_variables_initialized(
                    checker, value,
                  )
                }
              _ =>
                checker = mark_assignment_pattern_variables_initialized(
                  checker, value,
                )
            }
          ShorthandProperty(name, _) => {
            // { x } - x is both source and target
            let _ = checker.uninitialized_vars.remove(name)

          }
          SpreadAssignment(spread_expr, _) =>
            // { ...rest } - rest is the target
            checker = mark_assignment_pattern_variables_initialized(
              checker, spread_expr,
            )
          _ => ()
        }
      }
      checker
    }
    ArrayLiteralExpression(arr) => {
      let mut checker = checker
      for elem in arr.elements {
        match elem {
          Some(node) =>
            match node {
              SpreadExpression(spread) =>
                // [...rest]
                checker = mark_assignment_pattern_variables_initialized(
                  checker,
                  spread.expression,
                )
              _ =>
                // Regular element or nested pattern
                checker = mark_assignment_pattern_variables_initialized(
                  checker, node,
                )
            }
          None => () // Elision
        }
      }
      checker
    }
    // Also handle binding patterns in case they appear in assignment context
    ArrayBindingPattern(arr) => {
      let mut checker = checker
      for elem in arr.elements {
        match elem {
          Some(node) =>
            checker = mark_assignment_pattern_variables_initialized(
              checker, node,
            )
          None => ()
        }
      }
      checker
    }
    ObjectBindingPattern(obj) => {
      let mut checker = checker
      for elem in obj.properties {
        checker = mark_assignment_pattern_variables_initialized(
          checker,
          elem.name,
        )
      }
      checker
    }
    BindingElement(elem) =>
      mark_assignment_pattern_variables_initialized(checker, elem.name)
    SpreadExpression(spread) =>
      mark_assignment_pattern_variables_initialized(checker, spread.expression)
    _ => checker
  }
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
    Object(obj_type) =>
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
    TypeReference(type_ref) =>
      // Resolve the type reference and check
      match lookup_symbol(checker, type_ref.name) {
        Some(symbol) =>
          match get_symbol_type(checker, symbol) {
            (Some(resolved), c) =>
              check_readonly_property_assignment(
                c, resolved, prop_name, location,
              )
            (None, _) => checker
          }
        None => checker
      }
    _ => checker
  }
}

///|
/// Check if a private field (starting with #) is being assigned via non-'this' access (TS2810)
/// Private fields can only be assigned using 'this' access within the class body
fn check_private_field_this_access(
  checker : TypeChecker,
  prop : PropertyAccessExpression,
  location : SourceLocation,
) -> TypeChecker {
  // Check if this is a private field (name starts with #)
  if prop.name.has_prefix("#") {
    // Check if the base expression is 'this'
    let is_this_access = match prop.expression {
      ThisExpression(_) => true
      _ => false
    }
    if not(is_this_access) {
      // TS2810: Property '#field' can only be assigned using 'this' access
      add_diagnostic_with_code(
        checker,
        "Property '\{prop.name}' can only be assigned to by using 'this' access within the class body.",
        location,
        TS2810,
      )
    } else {
      checker
    }
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
                // Use check_assignment_compatibility for better union handling
                checker = check_assignment_compatibility(
                  checker,
                  return_type,
                  declared_return,
                  get_node_location(expr),
                )
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
      // Handle built-in Promise methods
      if type_ref.name == "Promise" || type_ref.name == "PromiseLike" {
        match prop_name {
          "then" => {
            // then<TResult1, TResult2>(onfulfilled?, onrejected?): Promise<TResult1 | TResult2>
            // For simplicity, return a function that returns Promise<any>
            let (any_t, checker) = any_type(checker)
            let (info, checker) = create_type_info(checker)
            let then_return = Type::TypeReference({
              name: "Promise",
              type_arguments: [any_t],
              info,
            })
            let (fn_info, checker) = create_type_info(checker)
            let then_type = Type::Function({
              parameters: [
                {
                  name: "onfulfilled",
                  param_type: any_t,
                  is_optional: true,
                  is_rest: false,
                },
                {
                  name: "onrejected",
                  param_type: any_t,
                  is_optional: true,
                  is_rest: false,
                },
              ],
              return_type: then_return,
              info: fn_info,
            })
            return (Some(then_type), checker)
          }
          "catch" => {
            // catch<TResult>(onrejected?): Promise<T | TResult>
            let (any_t, checker) = any_type(checker)
            let (info, checker) = create_type_info(checker)
            let catch_return = Type::TypeReference({
              name: "Promise",
              type_arguments: [any_t],
              info,
            })
            let (fn_info, checker) = create_type_info(checker)
            let catch_type = Type::Function({
              parameters: [
                {
                  name: "onrejected",
                  param_type: any_t,
                  is_optional: true,
                  is_rest: false,
                },
              ],
              return_type: catch_return,
              info: fn_info,
            })
            return (Some(catch_type), checker)
          }
          "finally" => {
            // finally(onfinally?): Promise<T>
            let (any_t, checker) = any_type(checker)
            let (info, checker) = create_type_info(checker)
            let finally_return = Type::TypeReference({
              name: "Promise",
              type_arguments: if type_ref.type_arguments.length() > 0 {
                [type_ref.type_arguments[0]]
              } else {
                [any_t]
              },
              info,
            })
            let (fn_info, checker) = create_type_info(checker)
            let finally_type = Type::Function({
              parameters: [
                {
                  name: "onfinally",
                  param_type: any_t,
                  is_optional: true,
                  is_rest: false,
                },
              ],
              return_type: finally_return,
              info: fn_info,
            })
            return (Some(finally_type), checker)
          }
          _ => () // Fall through to normal lookup
        }
      }
      // Resolve the type reference and look up property in resolved type
      let (resolved, checker) = resolve_type_reference(checker, type_ref)
      match resolved {
        TypeReference(_) =>
          // Could not resolve further, check if it's a class or interface with properties
          match lookup_symbol(checker, type_ref.name) {
            Some(symbol) =>
              match symbol.kind {
                Interface =>
                  match
                    get_interface_property_type(checker, symbol, prop_name) {
                    (Some(prop_type), checker) => (Some(prop_type), checker)
                    (None, checker) => (None, checker)
                  }
                Class =>
                  match get_class_property_type(checker, symbol, prop_name) {
                    (Some(prop_type), checker) => (Some(prop_type), checker)
                    (None, checker) => (None, checker)
                  }
                _ => (None, checker)
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
    Array(arr) =>
      // Handle built-in array properties
      match prop_name {
        "length" => {
          let (num_type, checker) = number_type(checker)
          (Some(num_type), checker)
        }
        "values" => {
          // Array.prototype.values() returns IterableIterator<T>
          // where T is the element type of the array
          let (info, checker) = create_type_info(checker)
          let iter_type = Type::TypeReference({
            name: "IterableIterator",
            type_arguments: [arr.element_type],
            info,
          })

          // Return a function type: () => IterableIterator<T>
          let (fn_info, checker) = create_type_info(checker)
          let values_fn = Type::Function({
            parameters: [],
            return_type: iter_type,
            info: fn_info,
          })
          (Some(values_fn), checker)
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
/// Get property type from an interface symbol (without full resolution)
fn get_interface_property_type(
  checker : TypeChecker,
  interface_symbol : Symbol,
  prop_name : String,
) -> (Type?, TypeChecker) {
  match interface_symbol.value_declaration {
    Some(InterfaceDeclaration(interface_decl)) => {
      for i = 0; i < interface_decl.members.length(); i = i + 1 {
        match interface_decl.members[i] {
          PropertyDeclaration(prop) =>
            if prop.name == prop_name {
              let (prop_type, c) = resolve_type_annotation_or_any(checker, prop.type_annotation)
              return (Some(prop_type), c)
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
priv enum MemberVisibility {
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
          for mem in class_decl.members {
            match mem {
              PropertyDeclaration(prop) =>
                if prop.name == member_name {
                  return get_visibility_from_modifiers(prop.modifiers)
                }
              MethodDeclaration(meth) =>
                if meth.name == member_name {
                  return get_visibility_from_modifiers(meth.modifiers)
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
fn get_visibility_from_modifiers(
  modifiers : Array[Modifier],
) -> MemberVisibility {
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
                    } else if is_subclass_of(checker, name, parent_name) {
                      return true
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
      let visibility = get_class_member_visibility(
        checker, class_name, member_name,
      )
      match visibility {
        MemberVisibility::Private =>
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
        MemberVisibility::Protected =>
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
    ParenthesizedExpression(paren) =>
      unwrap_parenthesized_expression(paren.expression)
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
          MethodDeclaration(meth) =>
            if meth.name == prop_name && is_static_modifier(meth.modifiers) {
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
    Some(global) =>
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
    Object(obj_type) =>
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
      VariableStatement(var_stmt) =>
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
      _ => continue
    }
  }
  ""
}

///|
/// Check if an expression is a namespace identifier and return the symbol
fn get_namespace_symbol_from_expr(
  checker : TypeChecker,
  expr : Node,
) -> Symbol? {
  match expr {
    Identifier(id) =>
      match lookup_symbol(checker, id.name) {
        Some(symbol) =>
          if is_namespace_symbol(symbol) {
            Some(symbol)
          } else {
            None
          }
        None => None
      }
    _ => None
  }
}

///|
/// Infer property access type
fn infer_property_access_type(
  checker : TypeChecker,
  prop : PropertyAccessExpression,
) -> (Type, TypeChecker) {
  // Check if base expression is a namespace - handle TS2694
  let namespace_sym = get_namespace_symbol_from_expr(checker, prop.expression)
  match namespace_sym {
    Some(ns_symbol) => {
      // This is namespace member access - look up in exports
      let ns_name = ns_symbol.name

      // First try to look up in external registry (for imports like "import * as m4 from 'm4'")
      match lookup_imported_namespace_member(checker, ns_name, prop.name) {
        Some(member_type) => (member_type, checker)
        None =>
          // Fall back to local symbol exports
          match ns_symbol.exports {
            Some(exports) =>
              match exports.get(prop.name) {
                Some(member_symbol) =>
                  // Found the exported member - get its type
                  match get_symbol_type(checker, member_symbol) {
                    (Some(t), c) => (t, c)
                    (None, c) => infer_symbol_type(c, member_symbol)
                  }
                None => {
                  // TS2339: Property does not exist on type 'typeof X'
                  // (TypeScript uses TS2339 for property access, not TS2694)
                  let checker = add_diagnostic_with_code(
                    checker,
                    "Property '\{prop.name}' does not exist on type 'typeof \{ns_name}'.",
                    prop.location,
                    TS2339,
                  )
                  any_type(checker)
                }
              }
            None => {
              // TS2339: Property does not exist on type 'typeof X'
              let checker = add_diagnostic_with_code(
                checker,
                "Property '\{prop.name}' does not exist on type 'typeof \{ns_name}'.",
                prop.location,
                TS2339,
              )
              any_type(checker)
            }
          }
      }
    }
    None => {
      // Not a namespace - normal property access
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
                // Check if this is 'this' in global scope accessing a restricted property
                // TypeScript emits TS2339 for 'this.name' in global scope because 'name'
                // is declared globally but not accessible via globalThis
                if is_global_this_type(object_type) &&
                  is_restricted_global_this_property(prop.name) {
                  add_diagnostic_with_code(
                    checker,
                    "Property '\{prop.name}' does not exist on type '\{type_to_string(object_type)}'.",
                    get_node_location(prop.expression),
                    TS2339,
                  )
                } else {
                  checker // Don't error for other property access on 'this' - allows implicit property assignment
                }
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
  }
}

///|
/// Check if an expression refers to a const enum and return the enum name
fn get_const_enum_name(checker : TypeChecker, expr : Node) -> String? {
  match expr {
    Identifier(id) =>
      match lookup_symbol(checker, id.name) {
        Some(symbol) =>
          if symbol.kind == SymbolKind::Enum && symbol.flags.is_const {
            Some(id.name)
          } else {
            None
          }
        None => None
      }
    _ => None
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

  // Check for const enum access restrictions (TS2476)
  let checker = match get_const_enum_name(checker, elem.expression) {
    Some(_) =>
      // For const enums, only string literal access is allowed
      match elem.argument_expression {
        StringLiteral(_) => checker // Valid: Colors["Red"]
        _ =>
          // TS2476: A const enum member can only be accessed using a string literal
          add_diagnostic_with_code(
            checker,
            "A const enum member can only be accessed using a string literal.",
            get_node_location(elem.argument_expression),
            TS2476,
          )
      }
    None => checker
  }
  let no_unchecked = checker.no_unchecked_indexed_access
  match object_type {
    Array(arr_type) => {
      // Check if index type is valid (number or string for arrays)
      let checker = match index_type {
        Number(_)
        | NumberLiteral(_, _)
        | String(_)
        | StringLiteral(_, _)
        | Any(_)
        | Unknown(_) => checker
        Boolean(_)
        | BooleanLiteral(_, _)
        | Object(_)
        | Void(_)
        | Null(_)
        | Undefined(_) =>
          // TS2538: Type cannot be used as an index type
          add_diagnostic_with_code(
            checker,
            "Type '\{type_to_string(index_type)}' cannot be used as an index type",
            get_node_location(elem.argument_expression),
            TS2538,
          )
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
            Boolean(_)
            | BooleanLiteral(_, _)
            | Object(_)
            | Array(_)
            | Void(_)
            | Null(_)
            | Undefined(_) => {
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
  // Skip check for class types and built-in constructors
  let builtin_constructors = [
    "Array", "Object", "String", "Number", "Boolean", "Function", "Symbol", "BigInt",
    "Date", "RegExp", "Error", "TypeError", "RangeError", "SyntaxError", "ReferenceError",
    "EvalError", "URIError", "Map", "Set", "WeakMap", "WeakSet", "Promise", "Proxy",
    "ArrayBuffer", "SharedArrayBuffer", "DataView", "Int8Array", "Uint8Array", "Uint8ClampedArray",
    "Int16Array", "Uint16Array", "Int32Array", "Uint32Array", "Float32Array", "Float64Array",
    "BigInt64Array", "BigUint64Array",
  ]
  let is_class_type = match new_expr.expression {
    Identifier(id) =>
      // Check if it's a built-in constructor
      if builtin_constructors.contains(id.name) {
        true
      } else {
        // Check if it's a user-defined class
        match lookup_symbol(checker, id.name) {
          Some(symbol) =>
            match symbol.kind {
              Class => true
              _ => false
            }
          None => false
        }
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
      | TemplateLiteral(_)
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
  // Build a template literal type that captures the structure
  // texts: ["head_text", "span1_text", "span2_text", ...]
  // types: [expr1_type, expr2_type, ...]

  let texts : Array[String] = []
  let types : Array[Type] = []
  let mut checker = checker

  // First text part is the head
  texts.push(template.head)

  // Check if all expressions are literal AST nodes (not inferred types)
  // This determines if we can create a precise template literal type
  let mut all_literal_nodes = true

  // Process each template span
  for i = 0; i < template.template_spans.length(); i = i + 1 {
    let span = template.template_spans[i]

    // Check if this expression is a literal AST node
    let is_literal_node = match span.expression {
      NumericLiteral(_) | Node::StringLiteral(_) | Node::BooleanLiteral(_) =>
        true
      _ => false
    }
    if not(is_literal_node) {
      all_literal_nodes = false
    }

    // Create the appropriate type for the template
    // For literal nodes, create literal types; otherwise, use inferred type
    let (expr_type, c) = match span.expression {
      NumericLiteral(lit) => {
        let num_val = @strconv.parse_double(lit.value) catch { _ => 0.0 }
        number_literal_type(checker, num_val)
      }
      Node::StringLiteral(lit) => string_literal_type(checker, lit.value)
      Node::BooleanLiteral(lit) => boolean_literal_type(checker, lit.value)
      _ => infer_type(checker, span.expression)
    }
    checker = c
    types.push(expr_type)
    texts.push(span.literal)
  }

  // If all expression nodes are literals (or no expressions), return a template literal type
  // Otherwise, fall back to string type
  if all_literal_nodes {
    // Create a template literal type (even for templates without expressions)
    let (info, checker) = create_type_info(checker)
    let tl_type : Type = Type::TemplateLiteral({ texts, types, info })
    (tl_type, checker)
  } else {
    // Fall back to plain string type for non-literal expressions
    string_type(checker)
  }
}

///|
/// Infer tagged template expression type
/// Tagged templates like html`<div>${x}</div>` or sql`SELECT * FROM ${table}`
fn infer_tagged_template_expression_type(
  checker : TypeChecker,
  tte : TaggedTemplateExpression,
) -> (Type, TypeChecker) {
  // First, infer the type of the tag expression
  let (tag_type, checker) = infer_type(checker, tte.tag)

  // Collect template expression types for checking against call signature
  let mut checker = checker
  let expr_types : Array[(Type, SourceLocation)] = []
  match tte.template {
    TemplateExpression(template) =>
      for i = 0; i < template.template_spans.length(); i = i + 1 {
        let span = template.template_spans[i]
        let (expr_type, c) = infer_type(checker, span.expression)
        expr_types.push((expr_type, get_node_location(span.expression)))
        checker = c
      }
    // NoSubstitutionTemplateLiteral is just a string literal, no expressions to check
    _ => ()
  }

  // If the tag is typed as 'any', the result is 'any'
  match tag_type {
    Any(_) => any_type(checker)
    Function(func) => {
      // Check template expression types against function parameters (skip first param which is TemplateStringsArray)
      let checker = check_tagged_template_args(
        checker,
        func.parameters,
        expr_types,
      )
      // The return type of the tag function is the result type
      (func.return_type, checker)
    }
    // For other types, try to find a call signature
    Object(obj) =>
      if obj.call_signatures.length() > 0 {
        // Check template expression types against call signature parameters
        let sig = obj.call_signatures[0]
        let checker = check_tagged_template_args(
          checker,
          sig.parameters,
          expr_types,
        )
        // Use the first call signature's return type
        (sig.return_type, checker)
      } else {
        // TS2349: No call signature - report error
        let type_name = type_to_string(tag_type)
        let checker = add_diagnostic_with_code(
          checker,
          "This expression is not callable. Type '" +
          type_name +
          "' has no call signatures.",
          get_node_location(tte.tag),
          TS2349,
        )
        any_type(checker)
      }
    // String, Number, Boolean types are not callable
    String(_) | StringLiteral(_) | TemplateLiteral(_) => {
      // TS2349: String types are not callable
      let type_name = type_to_string(tag_type)
      let checker = add_diagnostic_with_code(
        checker,
        "This expression is not callable. Type '" +
        type_name +
        "' has no call signatures.",
        get_node_location(tte.tag),
        TS2349,
      )
      any_type(checker)
    }
    Number(_) | NumberLiteral(_) | BigInt(_) | Boolean(_) | BooleanLiteral(_) => {
      // TS2349: Primitive types are not callable
      let type_name = type_to_string(tag_type)
      let checker = add_diagnostic_with_code(
        checker,
        "This expression is not callable. Type '" +
        type_name +
        "' has no call signatures.",
        get_node_location(tte.tag),
        TS2349,
      )
      any_type(checker)
    }
    // For unknown or other types, return any
    _ => any_type(checker)
  }
}

///|
/// Check tagged template interpolation arguments against call signature parameters
fn check_tagged_template_args(
  checker : TypeChecker,
  parameters : Array[CheckerParameter],
  expr_types : Array[(Type, SourceLocation)],
) -> TypeChecker {
  // Tagged templates have: first param = TemplateStringsArray, rest params = interpolation values
  // Skip the first parameter (TemplateStringsArray) and check the rest
  if parameters.length() < 2 {
    return checker
  }
  let mut checker = checker

  // Check if last parameter is a rest parameter
  let last_param = parameters[parameters.length() - 1]
  if last_param.is_rest {
    // Rest parameter - all interpolation values must be assignable to the rest element type
    let rest_element_type = match last_param.param_type {
      Array(arr) => arr.element_type
      _ => last_param.param_type
    }
    for i = 0; i < expr_types.length(); i = i + 1 {
      let (expr_type, loc) = expr_types[i]
      if not(is_assignable(expr_type, rest_element_type)) {
        // TS2345: Argument of type 'X' is not assignable to parameter of type 'Y'
        let expr_type_str = type_to_string(expr_type)
        let param_type_str = type_to_string(rest_element_type)
        checker = add_diagnostic_with_code(
          checker,
          "Argument of type '" +
          expr_type_str +
          "' is not assignable to parameter of type '" +
          param_type_str +
          "'.",
          loc,
          TS2345,
        )
      }
    }
  } else {
    // Regular parameters (starting from index 1, skipping TemplateStringsArray)
    for i = 0; i < expr_types.length(); i = i + 1 {
      let param_index = i + 1 // Skip first param
      if param_index < parameters.length() {
        let param = parameters[param_index]
        let (expr_type, loc) = expr_types[i]
        if not(is_assignable(expr_type, param.param_type)) {
          // TS2345: Argument of type 'X' is not assignable to parameter of type 'Y'
          let expr_type_str = type_to_string(expr_type)
          let param_type_str = type_to_string(param.param_type)
          checker = add_diagnostic_with_code(
            checker,
            "Argument of type '" +
            expr_type_str +
            "' is not assignable to parameter of type '" +
            param_type_str +
            "'.",
            loc,
            TS2345,
          )
        }
      }
    }
  }
  checker
}

///|
/// Infer this keyword type
fn infer_this_type(
  checker : TypeChecker,
  location : SourceLocation,
) -> (Type, TypeChecker) {
  // TS2334: 'this' cannot be referenced in a static property initializer
  let checker = if checker.in_static_context {
    add_diagnostic_with_code(
      checker,
      "'this' cannot be referenced in a static property initializer.",
      location,
      TS2334,
    )
  } else {
    checker
  }
  // TS17009: 'super' must be called before accessing 'this' in derived class constructor
  // Note: Only check when 'this' is directly in the constructor, not inside nested arrow functions
  // Arrow functions inherit 'this' but don't count as direct constructor body access
  let checker = if checker.in_constructor &&
    checker.in_derived_class &&
    not(checker.super_called) &&
    checker.arrow_function_depth == 0 {
    add_diagnostic_with_code(
      checker,
      "'super' must be called before accessing 'this' in the constructor of a derived class.",
      location,
      TS17009,
    )
  } else {
    checker
  }
  match checker.current_this_type {
    Some(this_type) => (this_type, checker)
    None =>
      // When current_this_type is None, we're at global scope or in a function
      // - Arrow functions: 'this' is lexically bound, so it's 'typeof globalThis' in global scope
      // - Regular functions: 'this' is dynamically bound, so it's 'any' (no error for property access)
      //
      // The condition: arrow_function_depth > 0 && regular_function_depth == 0
      // means we're inside an arrow function that's directly at global scope,
      // not inside a regular function that would provide dynamic 'this'
      if checker.arrow_function_depth > 0 && checker.regular_function_depth == 0 {
        // Arrow function at global scope - 'this' is typeof globalThis
        get_global_this_type(checker)
      } else {
        // Regular function or global scope outside arrow function - 'this' is any
        any_type(checker)
      }
  }
}

///|
/// Get the type of globalThis for global scope 'this' references
/// This is a special object type that represents the global object
fn get_global_this_type(checker : TypeChecker) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  // Create an object type representing globalThis with no known properties
  // This will cause TS2339 for known restricted properties like 'name'
  // Use class_name to mark this as a special globalThis type
  let global_this_type = Type::Object({
    properties: {},
    call_signatures: [],
    construct_signatures: [],
    index_signatures: [],
    info,
    class_name: Some("typeof globalThis"),
  })
  (global_this_type, checker)
}

///|
/// Check if a type is the special 'typeof globalThis' type
fn is_global_this_type(t : Type) -> Bool {
  match t {
    Object(obj) =>
      match obj.class_name {
        Some(n) => n == "typeof globalThis"
        None => false
      }
    _ => false
  }
}

///|
/// Check if a property name is restricted on globalThis
/// These are properties that exist as global declarations but are not
/// accessible via 'this' in global scope (e.g., 'name' from lib.dom.d.ts)
fn is_restricted_global_this_property(prop_name : String) -> Bool {
  // 'name' is declared as 'declare const name: void;' in lib.dom.d.ts
  // It exists as a global but cannot be accessed via globalThis
  prop_name == "name"
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
  // TS1308: 'await' expressions are only allowed within async functions and at top level of modules
  let checker = if not(is_in_async_function(checker)) {
    add_diagnostic_with_code(
      checker,
      "'await' expressions are only allowed within async functions and at the top levels of modules.",
      ae.location,
      TS1308,
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
  // TS1163: A 'yield' expression is only allowed in a generator body
  let checker = if not(is_in_generator_function(checker)) {
    add_diagnostic_with_code(
      checker,
      "A 'yield' expression is only allowed in a generator body.",
      ye.location,
      TS1163,
    )
  } else {
    checker
  }
  // Get the type of the yielded expression if present
  match ye.expression {
    Some(expr) => {
      let (expr_type, checker) = infer_type(checker, expr)

      // TS7057: If the expression is a yield expression and we're in a generator
      // without return type annotation, and noImplicitAny is set, report error
      let checker = match expr {
        YieldExpression(_) =>
          if checker.no_implicit_any && not(checker.generator_has_return_type) {
            add_diagnostic_with_code(
              checker,
              "'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation.",
              get_node_location(expr),
              TS7057,
            )
          } else {
            checker
          }
        _ => checker
      }

      // TS2741: Check if yield operand type is compatible with expected yield type
      // For regular yield (not yield*), check the operand directly
      // For yield*, check if elements of the iterable are compatible
      let checker = if not(ye.is_delegate) {
        check_yield_type_compatibility(checker, expr_type, expr, ye.location)
      } else {
        // For yield*, we need to check the element type of the iterable
        // against the expected yield type
        check_yield_delegate_type_compatibility(
          checker,
          expr_type,
          expr,
          ye.location,
        )
      }

      // TS2770: Check if yield operand type has a problematic 'then' member
      // In an async generator, the yield operand must either be a valid promise
      // or must not contain a callable 'then' member
      let checker = check_yield_operand_then_member(
        checker,
        expr_type,
        ye.location,
      )

      // TS2488: For yield*, the operand must be iterable (have [Symbol.iterator]())
      let checker = if ye.is_delegate {
        check_yield_delegate_iterable(checker, expr_type, expr, ye.location)
      } else {
        checker
      }

      // Collect yield type for Generator type inference
      // For yield*, we collect the element type of the iterable
      // For plain yield, we collect the expression type
      let checker = collect_yield_type(checker, expr_type, ye.is_delegate)

      // TS7057: When noImplicitAny is enabled and the generator lacks a return type,
      // the yield expression's result (TNext) is implicitly 'any'
      // We emit this error when the yield expression itself is being used (not just as a statement)
      // Only emit for simple yield, not for yield* (delegation)
      // Don't emit for statement-level yields (e.g., "yield 0;" where result isn't used)
      let checker = if checker.no_implicit_any &&
        not(checker.generator_has_return_type) &&
        not(ye.is_delegate) &&
        not(checker.in_expression_statement) {
        add_diagnostic_with_code(
          checker,
          "'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation.",
          ye.location,
          TS7057,
        )
      } else {
        checker
      }

      // For yield*, should iterate over the expression
      // For plain yield, return the expression type
      (expr_type, checker)
    }
    None => {
      // TS7057: When noImplicitAny is enabled and the generator lacks a return type,
      // bare yield's result is also implicitly 'any'
      let (t, checker) = undefined_type(checker)
      let checker = if checker.no_implicit_any &&
        not(checker.generator_has_return_type) {
        add_diagnostic_with_code(
          checker,
          "'yield' expression implicitly results in an 'any' type because its containing generator lacks a return-type annotation.",
          ye.location,
          TS7057,
        )
      } else {
        checker
      }
      // Collect undefined as a yield type for bare yield
      let checker = collect_yield_type(checker, t, false)
      (t, checker)
    }
  }
}

///|
/// Check if we're in an async generator (both async and generator)
fn is_in_async_generator(checker : TypeChecker) -> Bool {
  is_in_async_function(checker) && is_in_generator_function(checker)
}

///|
/// Check if a type has a callable 'then' member (thenable)
fn has_callable_then_member(checker : TypeChecker, t : Type) -> Bool {
  match t {
    Object(obj_type) =>
      match obj_type.properties.get("then") {
        Some(prop) =>
          // Check if 'then' is a function type
          match prop.prop_type {
            Function(_) => true
            _ => false
          }
        None => false
      }
    TypeReference(type_ref) =>
      // Check if it's a Promise type (which is allowed)
      if type_ref.name == "Promise" {
        false // Promise is allowed, don't report error
      } else {
        // Resolve the type and check
        match resolve_type_reference(checker, type_ref) {
          (Object(obj_type), _) =>
            match obj_type.properties.get("then") {
              Some(prop) =>
                match prop.prop_type {
                  Function(_) => true
                  _ => false
                }
              None => false
            }
          _ => false
        }
      }
    _ => false
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
  // Only check in async generators
  if not(is_in_async_generator(checker)) {
    return checker
  }

  // Check if the type has a 'then' property that is callable but not a proper Promise
  if has_callable_then_member(checker, operand_type) {
    add_diagnostic_with_code(
      checker,
      "Type of 'yield' operand in an async generator must either be a valid promise or must not contain a callable 'then' member.",
      location,
      TS2770,
    )
  } else {
    checker
  }
}

///|
/// Check if yield operand type is compatible with expected yield type (TS2741)
/// Reports error if the operand type is missing required properties
fn check_yield_type_compatibility(
  checker : TypeChecker,
  operand_type : Type,
  expr : Node,
  location : SourceLocation,
) -> TypeChecker {
  // Only check if we have an expected yield type
  match checker.generator_yield_type {
    Some(expected_type) => {
      // Check if operand_type is assignable to expected_type
      // For TS2741, we check if operand is missing properties
      let (missing_prop_opt, checker) = find_missing_property_with_checker(
        checker, operand_type, expected_type,
      )
      match missing_prop_opt {
        Some(missing_prop) => {
          let operand_type_str = get_type_name_for_error(operand_type, expr)
          let expected_type_str = type_to_string(expected_type)
          add_diagnostic_with_code(
            checker,
            "Property '" +
            missing_prop +
            "' is missing in type '" +
            operand_type_str +
            "' but required in type '" +
            expected_type_str +
            "'.",
            location,
            TS2741,
          )
        }
        None => checker
      }
    }
    None => checker
  }
}

///|
/// Check if yield* delegate type elements are compatible with expected yield type (TS2741)
fn check_yield_delegate_type_compatibility(
  checker : TypeChecker,
  operand_type : Type,
  expr : Node,
  location : SourceLocation,
) -> TypeChecker {
  // Only check if we have an expected yield type
  match checker.generator_yield_type {
    Some(expected_type) => {
      // Get the element type of the iterable
      let element_type = get_iterable_element_type(operand_type)
      match element_type {
        Some(elem_type) => {
          // Check if element type is compatible
          let (missing_prop_opt, checker) = find_missing_property_with_checker(
            checker, elem_type, expected_type,
          )
          match missing_prop_opt {
            Some(missing_prop) => {
              let operand_type_str = get_type_name_for_error(elem_type, expr)
              let expected_type_str = type_to_string(expected_type)
              add_diagnostic_with_code(
                checker,
                "Property '" +
                missing_prop +
                "' is missing in type '" +
                operand_type_str +
                "' but required in type '" +
                expected_type_str +
                "'.",
                location,
                TS2741,
              )
            }
            None => checker
          }
        }
        None => checker
      }
    }
    None => checker
  }
}

///|
/// Find a missing property in the source type that is required in the target type
/// This version takes a checker to resolve type references
fn find_missing_property_with_checker(
  checker : TypeChecker,
  source : Type,
  target : Type,
) -> (String?, TypeChecker) {
  // First, try to resolve TypeReferences to their actual types (classes)
  let (resolved_source, checker) = resolve_type_for_property_check(
    checker, source,
  )
  let (resolved_target, checker) = resolve_type_for_property_check(
    checker, target,
  )

  // Now check for missing properties with resolved types
  match resolved_target {
    Object(target_obj) => {
      // Check each required property in the target
      for prop_name in target_obj.properties.keys() {
        let prop = target_obj.properties[prop_name]
        // Skip optional properties
        if prop.is_optional {
          continue
        }
        // Check if source has this property
        if not(type_has_property_with_resolved(resolved_source, prop_name)) {
          return (Some(prop_name), checker)
        }
      }
      (None, checker)
    }
    TypeReference(target_ref) =>
      // Target is still a type reference (couldn't resolve)
      // Check if source is structurally compatible
      match resolved_source {
        Object(source_obj) =>
          match source_obj.class_name {
            Some(source_name) =>
              if source_name == target_ref.name {
                (None, checker) // Same class
              } else {
                // Different classes - need to look up target class properties
                match get_class_properties(checker, target_ref.name) {
                  Some(target_props) => {
                    // Check if source has all target properties
                    for prop_name in target_props.keys() {
                      let prop = target_props[prop_name]
                      if not(prop.is_optional) &&
                        not(
                          type_has_property_with_resolved(
                            resolved_source, prop_name,
                          ),
                        ) {
                        return (Some(prop_name), checker)
                      }
                    }
                    (None, checker)
                  }
                  None => (None, checker) // Can't find target class
                }
              }
            None => (None, checker)
          }
        TypeReference(source_ref) =>
          // Both are type references
          if source_ref.name == target_ref.name {
            (None, checker) // Same type
          } else {
            // Different type names - look up and compare properties
            match
              (
                get_class_properties(checker, source_ref.name),
                get_class_properties(checker, target_ref.name),
              ) {
              (Some(source_props), Some(target_props)) => {
                // Check if source has all required target properties
                for prop_name in target_props.keys() {
                  let prop = target_props[prop_name]
                  if not(prop.is_optional) &&
                    not(source_props.contains(prop_name)) {
                    return (Some(prop_name), checker)
                  }
                }
                (None, checker)
              }
              _ => (None, checker) // Can't find class definitions
            }
          }
        _ => (None, checker)
      }
    _ => (None, checker)
  }
}

///|
/// Resolve a type for property checking - looks up class types to get their Object representation
fn resolve_type_for_property_check(
  checker : TypeChecker,
  t : Type,
) -> (Type, TypeChecker) {
  match t {
    TypeReference(type_ref) =>
      // Try to look up the class and get its instance type
      match lookup_symbol(checker, type_ref.name) {
        Some(symbol) =>
          match symbol.kind {
            Class => {
              // Get the class's type and extract instance type from construct signature
              // Try cached type first, then infer if not cached
              let (class_type, checker) = match
                get_symbol_type(checker, symbol) {
                (Some(ct), c) => (ct, c)
                (None, c) => infer_symbol_type(c, symbol)
              }
              // The instance type is in the construct signature's return type
              match class_type {
                Object(obj) =>
                  if obj.construct_signatures.length() > 0 {
                    (obj.construct_signatures[0].return_type, checker)
                  } else {
                    (t, checker)
                  }
                _ => (t, checker)
              }
            }
            Interface =>
              // Get interface type
              match resolve_interface_type(checker, symbol) {
                (Some(interface_t), c) => (interface_t, c)
                (None, c) => (t, c)
              }
            _ => (t, checker)
          }
        None => (t, checker)
      }
    _ => (t, checker)
  }
}

///|
/// Get the properties of a class by name (returns the instance properties)
fn get_class_properties(
  checker : TypeChecker,
  class_name : String,
) -> Map[String, PropertySignature]? {
  match lookup_symbol(checker, class_name) {
    Some(symbol) =>
      match symbol.kind {
        Class => {
          // Get class type and extract instance properties from construct signature
          // Try cached type first, then infer if not cached
          let (class_type_opt, _) = match get_symbol_type(checker, symbol) {
            (Some(ct), c) => (Some(ct), c)
            (None, c) => {
              let (t, c2) = infer_symbol_type(c, symbol)
              (Some(t), c2)
            }
          }
          match class_type_opt {
            Some(Object(obj)) =>
              if obj.construct_signatures.length() > 0 {
                match obj.construct_signatures[0].return_type {
                  Object(instance_obj) => Some(instance_obj.properties)
                  _ => None
                }
              } else {
                None
              }
            _ => None
          }
        }
        Interface =>
          // Get interface properties
          match resolve_interface_type(checker, symbol) {
            (Some(Object(obj)), _) => Some(obj.properties)
            _ => None
          }
        _ => None
      }
    None => None
  }
}

///|
/// Check if a type has a property - handles resolved types
fn type_has_property_with_resolved(t : Type, prop_name : String) -> Bool {
  match t {
    Object(obj) => obj.properties.contains(prop_name)
    Any(_) => true // any has all properties
    TypeReference(tr) =>
      // If still unresolved, assume it has the property (conservative)
      // This shouldn't happen if resolution worked
      tr.name == "any" || tr.name == "unknown"
    _ => false
  }
}

///|
/// Check if a type has a property
fn type_has_property(t : Type, prop_name : String) -> Bool {
  match t {
    Object(obj) => obj.properties.contains(prop_name)
    Any(_) => true // any has all properties
    _ => false
  }
}

///|
/// Get the element type of an iterable
fn get_iterable_element_type(t : Type) -> Type? {
  match t {
    Array(arr) => Some(arr.element_type)
    TypeReference(tr) =>
      // For Iterator<T>, Generator<T>, etc., the element type is the first type arg
      if tr.type_arguments.length() > 0 {
        Some(tr.type_arguments[0])
      } else {
        None
      }
    _ => None
  }
}

///|
/// Get the type name for error messages, using the expression for context
fn get_type_name_for_error(t : Type, expr : Node) -> String {
  match t {
    Object(obj) =>
      match obj.class_name {
        Some(name) => name
        None => type_to_string(t)
      }
    TypeReference(tr) => tr.name
    _ => type_to_string_for_error(t, expr)
  }
}

///|
/// Check if yield* operand is iterable (TS2488)
/// Type must have a '[Symbol.iterator]()' method that returns an iterator
fn check_yield_delegate_iterable(
  checker : TypeChecker,
  operand_type : Type,
  expr : Node,
  location : SourceLocation,
) -> TypeChecker {
  // Check if the type is iterable
  if not(is_type_iterable(operand_type)) {
    let type_str = type_to_string_for_error(operand_type, expr)
    add_diagnostic_with_code(
      checker,
      "Type '" +
      type_str +
      "' must have a '[Symbol.iterator]()' method that returns an iterator.",
      location,
      TS2488,
    )
  } else {
    checker
  }
}

///|
/// Check if a type is iterable (has [Symbol.iterator]() method)
fn is_type_iterable(t : Type) -> Bool {
  match t {
    // any is always considered iterable
    Any(_) => true
    // Arrays are iterable
    Array(_) => true
    // Strings are iterable
    String(_) => true
    // Generator types are iterable
    TypeReference(type_ref) =>
      type_ref.name == "Generator" ||
      type_ref.name == "Iterator" ||
      type_ref.name == "IterableIterator" ||
      type_ref.name == "Iterable" ||
      type_ref.name == "AsyncGenerator" ||
      type_ref.name == "AsyncIterator" ||
      type_ref.name == "AsyncIterable" ||
      type_ref.name == "AsyncIterableIterator" ||
      type_ref.name == "Array" ||
      type_ref.name == "Map" ||
      type_ref.name == "Set" ||
      type_ref.name == "String"
    // Object types - check if they have Symbol.iterator or are known iterable classes
    Object(obj) =>
      // Check if this is a class instance with a known name
      match obj.class_name {
        Some(name) =>
          // Known iterable built-in classes
          name == "Array" ||
          name == "Map" ||
          name == "Set" ||
          name == "String" ||
          name == "NodeList" ||
          name == "HTMLCollection" ||
          name == "TypedArray" ||
          name == "Int8Array" ||
          name == "Uint8Array" ||
          name == "Uint8ClampedArray" ||
          name == "Int16Array" ||
          name == "Uint16Array" ||
          name == "Int32Array" ||
          name == "Uint32Array" ||
          name == "Float32Array" ||
          name == "Float64Array" ||
          name == "BigInt64Array" ||
          name == "BigUint64Array"
        // For anonymous object types (object literals), they could have Symbol.iterator defined
        // via computed property syntax. Since we can't easily detect this, be permissive for
        // anonymous objects and let the actual iteration fail at runtime if needed
        None => true
      }
    // Union types - all members must be iterable
    Union(ut) => {
      for member_type in ut.types {
        if not(is_type_iterable(member_type)) {
          return false
        }
      }
      true
    }
    // Function types are NOT iterable (this is the key case for TS2488)
    Function(_) => false
    // Primitive types (except string) are not iterable
    Number(_) => false
    Boolean(_) => false
    BigInt(_) => false
    Symbol(_) => false
    Undefined(_) => false
    Null(_) => false
    // Other types - be permissive
    _ => true
  }
}

///|
/// Check if an object type has an iterator-related property
fn has_iterator_property(obj : ObjectType) -> Bool {
  for prop_name in obj.properties.keys() {
    // Check for various iterator-related property names
    // TypeScript uses different representations for Symbol.iterator
    if prop_name.contains("iterator") ||
      prop_name.contains("Iterator") ||
      prop_name == "__@iterator" {
      return true
    }
  }
  false
}

///|
/// Convert a type to a string for error messages, using the expression for context
fn type_to_string_for_error(t : Type, expr : Node) -> String {
  match t {
    Function(_) =>
      // For function types, try to get more specific info
      // Check if this is a generator function reference
      match expr {
        Identifier(_) => "() => any"
        _ => "() => any"
      }
    Any(_) => "any"
    Unknown(_) => "unknown"
    Number(_) => "number"
    String(_) => "string"
    Boolean(_) => "boolean"
    Void(_) => "void"
    Undefined(_) => "undefined"
    Null(_) => "null"
    Never(_) => "never"
    Symbol(_) => "symbol"
    BigInt(_) => "bigint"
    Array(arr) => type_to_string(arr.element_type) + "[]"
    TypeReference(tr) => tr.name
    _ => type_to_string(t)
  }
}

///|
/// Check for circular type reference in promise 'then' method (TS2771)
/// Type '{0}' is referenced directly or indirectly in the fulfillment callback of its own 'then' method
fn check_promise_then_circular_reference(
  checker : TypeChecker,
  interface_name : String,
  members : Array[Node],
  location : SourceLocation,
) -> TypeChecker {
  // Look for a 'then' method in the interface
  for mem in members {
    match mem {
      MethodDeclaration(meth) =>
        if meth.name == "then" {
          // Check if any parameter's callback type references the interface itself
          for param in meth.parameters {
            match param {
              Parameter(p) =>
                match p.type_annotation {
                  Some(type_node) =>
                    if type_references_name_in_callback(
                        type_node, interface_name,
                      ) {
                      return add_diagnostic_with_code(
                        checker,
                        "Type '\{interface_name}' is referenced directly or indirectly in the fulfillment callback of its own 'then' method.",
                        location,
                        TS2771,
                      )
                    }
                  None => ()
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
  }
  checker
}

///|
/// Check if a type node references a given name in a callback parameter
fn type_references_name_in_callback(type_node : Node, name : String) -> Bool {
  match type_node {
    FunctionType(ft) => {
      // Check the parameter types of the function
      for param in ft.parameters {
        match param {
          Parameter(p) =>
            match p.type_annotation {
              Some(param_type) =>
                if type_node_references_name(param_type, name) {
                  return true
                }
              None => ()
            }
          _ => ()
        }
      }
      false
    }
    _ => false
  }
}

///|
/// Check if a type node directly references a given name
fn type_node_references_name(type_node : Node, name : String) -> Bool {
  match type_node {
    TypeReference(type_ref) => type_ref.type_name == name
    Identifier(id) => id.name == name
    _ => false
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
  // Push a local scope for function body checking
  let checker = push_local_scope(checker)

  // Track async function context for TS2465
  let checker = if fe.is_async {
    enter_async_function(checker)
  } else {
    checker
  }

  // Reset generator context for non-generator function expressions
  // yield is not valid inside a non-generator function, even if nested in a generator
  let saved_generator_depth = checker.generator_function_depth
  let saved_collected_yield_types = checker.collected_yield_types
  let (checker, saved_yield_types) = if fe.is_generator {
    let has_return_type = fe.return_type is Some(_)
    enter_generator_function(checker, has_return_type)
  } else {
    (
      {
        ..checker,
        generator_function_depth: 0,
        generator_has_return_type: false,
      },
      [],
    )
  }

  // Build a function type from the function expression and add parameters to local scope
  let mut c = checker

  // First, build the function type so we can add the function name binding
  // We need to do a preliminary pass to build the type before adding it to scope
  let preliminary_params : Array[CheckerParameter] = []
  for param_node in fe.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
        let param_name = match p.name {
          Identifier(id) => id.name
          _ => ""
        }
        preliminary_params.push({
          name: param_name,
          param_type,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }
  let checker = c
  let (preliminary_return_type, checker) = match fe.return_type {
    Some(type_node) => {
      let (type_opt, c) = get_type_from_type_node(checker, type_node)
      match type_opt {
        Some(t) => (t, c)
        None => any_type(c)
      }
    }
    None => any_type(checker)
  }

  // If the function expression has a name, add it to the local scope
  // This allows self-reference like: function y() { return y; }
  let (func_info, checker) = create_type_info(checker)
  let func_type : Type = Type::Function({
    parameters: preliminary_params,
    return_type: preliminary_return_type,
    info: func_info,
  })
  let checker = match fe.name {
    Some(name) => add_local_variable(checker, name, func_type)
    None => checker
  }

  // Now add parameters to local scope for body checking
  // We need to iterate the original parameters to handle binding patterns
  let mut c = checker
  for param_node in fe.parameters {
    match param_node {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
        // Handle identifier or binding pattern
        c = match p.name {
          Identifier(id) => add_local_variable(c, id.name, param_type)
          ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
            add_binding_pattern_variables(c, p.name, param_type)
          _ => c
        }
      }
      _ => ()
    }
  }
  let checker = c

  // Track regular function context (for 'arguments' object availability)
  let checker = enter_regular_function(checker)

  // Hoist var declarations to the function scope before checking body
  // This ensures var declarations are visible even before their declaration
  let checker = hoist_var_declarations(checker, fe.body)

  // Check function body for errors (including await expressions)
  let checker = match fe.body {
    BlockStatement(block) => check_block_statement(checker, block)
    _ => checker
  }

  // Exit regular function context
  let checker = exit_regular_function(checker)

  // Exit generator function context or restore saved depth
  let (checker, collected_yield_types) = if fe.is_generator {
    exit_generator_function(checker, saved_yield_types)
  } else {
    (
      {
        ..checker,
        generator_function_depth: saved_generator_depth,
        collected_yield_types: saved_collected_yield_types,
      },
      [],
    )
  }

  // Exit async function context if needed
  let checker = if fe.is_async { exit_async_function(checker) } else { checker }

  // Pop the local scope
  let checker = pop_local_scope(checker)

  // For generator functions, create a Generator type if no explicit return type
  // The Generator type is inferred from collected yield types
  let (final_type, checker) = if fe.is_generator && fe.return_type is None {
    // Create Generator<TYield, TReturn, TNext> type
    // TYield = union of all yield types (or never if empty)
    // TReturn = void (no explicit return)
    // TNext = unknown
    let (yield_union_type, checker) = if collected_yield_types.is_empty() {
      never_type(checker)
    } else if collected_yield_types.length() == 1 {
      (collected_yield_types[0], checker)
    } else {
      // Create union of all yield types
      let (info, checker) = create_type_info(checker)
      (Union({ types: collected_yield_types, info }), checker)
    }
    let (return_type_void, checker) = void_type(checker)
    let (unknown_type, checker) = unknown_type(checker)
    let (info, checker) = create_type_info(checker)
    // Create Generator<TYield, void, unknown> type as a TypeReference
    let generator_type = Type::TypeReference({
      name: "Generator",
      type_arguments: [yield_union_type, return_type_void, unknown_type],
      info,
    })
    // Wrap in function type
    let (func_info, checker) = create_type_info(checker)
    (
      Type::Function({
        parameters: preliminary_params,
        return_type: generator_type,
        info: func_info,
      }),
      checker,
    )
  } else {
    (func_type, checker)
  }

  // Return the function type
  (final_type, checker)
}

///|
/// Infer array literal type
fn infer_array_literal_type(
  checker : TypeChecker,
  arr : ArrayLiteralExpression,
) -> (Type, TypeChecker) {
  // TS1186: Check for rest elements with initializers at the start
  // This needs to be checked before we infer types to catch syntax errors
  let mut checker = checker
  for elem in arr.elements {
    match elem {
      Some(SpreadExpression(spread)) =>
        match spread.expression {
          BinaryExpression(be) if be.operator == Assign =>
            checker = add_diagnostic_with_code(
              checker,
              "A rest element cannot have an initializer.",
              spread.location,
              TS1186,
            )
          _ => ()
        }
      _ => ()
    }
  }
  // Infer element types and create union
  let element_types = []
  for i = 0; i < arr.elements.length(); i = i + 1 {
    match arr.elements[i] {
      Some(elem) =>
        // Check for spread expressions - they must spread iterable types (TS2548)
        match elem {
          SpreadExpression(spread) => {
            let (spread_type, c) = infer_type(checker, spread.expression)
            checker = c
            // Only check iterability for spread sources (array construction), not targets
            // in_destructuring_pattern is set when we're on the left side of an assignment
            if not(checker.in_destructuring_pattern) {
              // Check if type is iterable - use extract_iterable_element_type to determine if we can extract an element
              let is_iterable = match spread_type {
                Array(_) | String(_) => true
                _ => {
                  // Try to extract element type - if successful, it's iterable
                  let (elem_type_opt, c) = extract_iterable_element_type(
                    checker,
                    spread_type,
                  )
                  checker = c
                  match elem_type_opt {
                    Some(_) => true
                    None => false
                  }
                }
              }
              // Error if not iterable (extract_iterable_element_type returned None)
              // BUT be permissive for TypeReference/Union/Intersection like for-of
              let should_error = if not(is_iterable) {
                match spread_type {
                  TypeReference(_) | Union(_) | Intersection(_) => false
                  Any(_) => false
                  _ => true // Error for all other non-iterable types (primitives, objects)
                }
              } else {
                false
              }
              if should_error {
                checker = add_diagnostic_with_code(
                  checker,
                  "Type is not an array type or a string type. Use a spread only on iterable types",
                  get_node_location(spread.expression),
                  TS2548,
                )
              }
            }
            // For arrays, extract element type
            match spread_type {
              Array(arr_type) => element_types.push(arr_type.element_type)
              String(_) => {
                let (info, c) = create_type_info(checker)
                checker = c
                element_types.push(String(info))
              }
              Object(_) | TypeReference(_) => {
                // Try to extract element type from iterable
                let (elem_type_opt, c) = extract_iterable_element_type(
                  checker,
                  spread_type,
                )
                checker = c
                match elem_type_opt {
                  Some(elem_type) => element_types.push(elem_type)
                  None => element_types.push(spread_type)
                }
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

///| Check if a type is valid for computed property names (TS2464)
///| Valid types: string, number, symbol, any
fn is_valid_computed_property_type(t : Type) -> Bool {
  match t {
    String(_) | Number(_) | Symbol(_) | Any(_) => true
    Union(u) =>
      // For unions, all constituent types must be valid
      u.types.iter().all(fn(typ) { is_valid_computed_property_type(typ) })
    _ => false
  }
}

///| Check if a type is a simple literal type or unique symbol for class property names (TS1166)
///| Valid types: string literals, number literals, unique symbols
///| Note: For now, we accept all symbol types. Full unique symbol checking can be added later.
fn is_valid_class_property_computed_name_type(t : Type) -> Bool {
  match t {
    StringLiteral(_) | NumberLiteral(_) | Symbol(_) => true
    _ => false
  }
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
      ComputedPropertyAssignment(name_expr, value, loc) => {
        // For computed properties, try to get the property name from string/identifier
        let key = get_property_name(name_expr)
        let key = if key == "" { "[computed]" } else { key }
        let (name_type, c) = infer_type(checker, name_expr)
        // TS2464: Check if computed property name type is valid
        let c = if not(is_valid_computed_property_type(name_type)) {
          add_diagnostic_with_code(
            c,
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'.",
            loc,
            TS2464,
          )
        } else {
          c
        }
        let (prop_type, c) = infer_type(c, value)
        properties.set(key, {
          name: key,
          prop_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      ShorthandProperty(name, loc) => {
        // Shorthand property - get type from identifier in scope
        // First check local scopes (for function parameters and local variables)
        // then fall back to global scope lookup
        let (prop_type, c) = match lookup_local_variable(checker, name) {
          Some(local_type) => (local_type, checker)
          None =>
            match lookup_symbol(checker, name) {
              Some(symbol) =>
                match checker.symbol_types.get(symbol.id) {
                  Some(t) => (t, checker)
                  None => any_type(checker)
                }
              None => {
                // TS18004: No value exists in scope for the shorthand property
                let checker = add_diagnostic_with_code(
                  checker,
                  "No value exists in scope for the shorthand property '" +
                  name +
                  "'. Either declare one or provide an initializer.",
                  loc,
                  TS18004,
                )
                any_type(checker)
              }
            }
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
          TypeReference(_) =>
            // TS2762: Spread types may only be created from object types
            // Type parameter T might not be an object type
            checker = add_diagnostic_with_code(
              checker,
              "Spread types may only be created from object types",
              loc,
              TS2762,
            )
          _ =>
            // TS2762: Spread types may only be created from object types
            checker = add_diagnostic_with_code(
              checker,
              "Spread types may only be created from object types",
              loc,
              TS2762,
            )
        }
      }
      MethodDeclaration(name, func_expr, _) => {
        // Shorthand method declaration: { method() { ... } }
        let (method_type, c) = infer_function_expression_type(
          checker, func_expr,
        )
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
        let (getter_type, c) = infer_function_expression_type(
          checker, func_expr,
        )
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
        let (setter_type, c) = infer_function_expression_type(
          checker, func_expr,
        )
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
      ComputedMethodDeclaration(name_expr, func_expr, loc) => {
        // Computed method: { [expr]() { ... } }
        let key = get_property_name(name_expr)
        let key = if key == "" { "[computed]" } else { key }
        let (name_type, c) = infer_type(checker, name_expr)
        // TS2464: Check if computed property name type is valid
        let c = if not(is_valid_computed_property_type(name_type)) {
          add_diagnostic_with_code(
            c,
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'.",
            loc,
            TS2464,
          )
        } else {
          c
        }
        let (method_type, c) = infer_function_expression_type(c, func_expr)
        properties.set(key, {
          name: key,
          prop_type: method_type,
          is_optional: false,
          is_readonly: false,
        })
        checker = c
      }
      ComputedGetAccessor(name_expr, func_expr, loc) => {
        // Computed getter: { get [expr]() { ... } }
        let key = get_property_name(name_expr)
        let key = if key == "" { "[computed]" } else { key }
        let (name_type, c) = infer_type(checker, name_expr)
        // TS2464: Check if computed property name type is valid
        let c = if not(is_valid_computed_property_type(name_type)) {
          add_diagnostic_with_code(
            c,
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'.",
            loc,
            TS2464,
          )
        } else {
          c
        }
        let (getter_type, c) = infer_function_expression_type(c, func_expr)
        let prop_type = match getter_type {
          Function(func_type) => func_type.return_type
          _ => getter_type
        }
        properties.set(key, {
          name: key,
          prop_type,
          is_optional: false,
          is_readonly: true,
        })
        checker = c
      }
      ComputedSetAccessor(name_expr, func_expr, loc) => {
        // Computed setter: { set [expr](value) { ... } }
        let key = get_property_name(name_expr)
        let key = if key == "" { "[computed]" } else { key }
        let (name_type, c) = infer_type(checker, name_expr)
        // TS2464: Check if computed property name type is valid
        let c = if not(is_valid_computed_property_type(name_type)) {
          add_diagnostic_with_code(
            c,
            "A computed property name must be of type 'string', 'number', 'symbol', or 'any'.",
            loc,
            TS2464,
          )
        } else {
          c
        }
        let (setter_type, c) = infer_function_expression_type(c, func_expr)
        let prop_type = match setter_type {
          Function(func_type) =>
            if func_type.parameters.length() > 0 {
              func_type.parameters[0].param_type
            } else {
              let (t, _) = any_type(c)
              t
            }
          _ => {
            let (t, _) = any_type(c)
            t
          }
        }
        match properties.get(key) {
          Some(_) => ()
          None =>
            properties.set(key, {
              name: key,
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

  // Arrow functions cannot be generators, so reset generator context
  // This ensures yield inside arrow functions triggers TS1163
  let saved_generator_depth = checker.generator_function_depth
  let checker = {
    ..checker,
    generator_function_depth: 0,
    generator_has_return_type: false,
  }

  // Build parameter list and add parameters to local scope
  let parameters = []
  let mut c = checker
  for i = 0; i < arrow.parameters.length(); i = i + 1 {
    match arrow.parameters[i] {
      Parameter(param) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, param.type_annotation)
        c = c2
        parameters.push({
          name: get_parameter_name(param.name),
          param_type,
          is_optional: param.is_optional,
          is_rest: param.is_rest,
        })
        // Add parameter to local scope (handles identifiers and binding patterns)
        c = match param.name {
          Identifier(id) => add_local_variable(c, id.name, param_type)
          ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
            add_binding_pattern_variables(c, param.name, param_type)
          _ => c
        }
      }
      _ => ()
    }
  }
  let checker = c

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
          // Infer return type from return statements in the block
          infer_return_type_from_block(checker, block)
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

  // Restore generator context
  let checker = { ..checker, generator_function_depth: saved_generator_depth }

  // Exit arrow function context
  let checker = exit_arrow_function(checker)

  // Pop the local scope
  let checker = pop_local_scope(checker)
  let (info, checker) = create_type_info(checker)
  (Function({ parameters, return_type, info }), checker)
}

///|
/// Infer return type from a block statement by collecting return statement types
fn infer_return_type_from_block(
  checker : TypeChecker,
  block : BlockStatement,
) -> (Type, TypeChecker) {
  let return_types : Array[Type] = []

  // Collect return types from the block
  for stmt in block.statements {
    collect_return_types_from_statement(checker, stmt, return_types)
  }

  // If no return statements found, return void
  if return_types.length() == 0 {
    return void_type(checker)
  }

  // If single return type, return it directly
  if return_types.length() == 1 {
    return (return_types[0], checker)
  }

  // Multiple return types - create union
  let (info, checker) = create_type_info(checker)
  (Union({ types: return_types, info }), checker)
}

///|
/// Collect return types from a statement (recursive helper)
fn collect_return_types_from_statement(
  checker : TypeChecker,
  stmt : Node,
  return_types : Array[Type],
) -> Unit {
  match stmt {
    ReturnStatement(ret) =>
      match ret.expression {
        Some(expr) => {
          let (ret_type, _) = infer_type(checker, expr)
          return_types.push(ret_type)
        }
        None => {
          // Return without expression returns undefined
          let (undef, _) = undefined_type(checker)
          return_types.push(undef)
        }
      }
    IfStatement(if_stmt) => {
      // Check both branches for return statements
      collect_return_types_from_statement(
        checker,
        if_stmt.then_statement,
        return_types,
      )
      match if_stmt.else_statement {
        Some(else_stmt) =>
          collect_return_types_from_statement(checker, else_stmt, return_types)
        None => ()
      }
    }
    BlockStatement(inner_block) =>
      for inner_stmt in inner_block.statements {
        collect_return_types_from_statement(checker, inner_stmt, return_types)
      }
    SwitchStatement(switch_stmt) =>
      // CaseClause has expression (optional for default) and statements
      for case_clause in switch_stmt.cases {
        for case_stmt in case_clause.statements {
          collect_return_types_from_statement(checker, case_stmt, return_types)
        }
      }
    TryStatement(try_stmt) => {
      collect_return_types_from_statement(
        checker,
        try_stmt.try_block,
        return_types,
      )
      match try_stmt.catch_clause {
        Some(catch_clause) =>
          collect_return_types_from_statement(
            checker,
            catch_clause.block,
            return_types,
          )
        None => ()
      }
      match try_stmt.finally_block {
        Some(finally_block) =>
          collect_return_types_from_statement(
            checker, finally_block, return_types,
          )
        None => ()
      }
    }
    _ => () // Other statements don't contain return statements at top level
  }
}

///|
/// Infer conditional expression type
fn infer_conditional_type(
  checker : TypeChecker,
  cond : ConditionalExpression,
) -> (Type, TypeChecker) {
  let (_condition_type, checker) = infer_type(checker, cond.condition)
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
    (BigInt(_), BigInt(_)) => true
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
    // Union to Union - check if all source members are assignable to target union
    (Union(source_union), Union(target_union)) =>
      is_union_to_union_assignable(source_union, target_union)
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
    // Object with class_name -> TypeReference (class instance to class type)
    (Object(source_obj), TypeReference(target_ref)) =>
      match source_obj.class_name {
        Some(class_name) =>
          // Class names match and no type arguments - compatible
          class_name == target_ref.name &&
          target_ref.type_arguments.length() == 0
        None => false
      }
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
/// Check if a type name is a built-in TypeScript generic type
/// These are types that are part of the TypeScript standard library
/// but may not be in the symbol table when type checking
fn is_builtin_generic_type(name : String) -> Bool {
  match name {
    "Generator"
    | "Iterator"
    | "Iterable"
    | "IterableIterator"
    | "AsyncGenerator"
    | "AsyncIterator"
    | "AsyncIterable"
    | "AsyncIterableIterator"
    | "Promise"
    | "PromiseLike"
    | "Array"
    | "ReadonlyArray"
    | "Map"
    | "Set"
    | "WeakMap"
    | "WeakSet"
    | "ReadonlyMap"
    | "ReadonlySet"
    | "IteratorResult"
    | "IteratorYieldResult"
    | "IteratorReturnResult" => true
    _ => false
  }
}

///|
/// Check if type reference is assignable
fn is_type_reference_assignable(
  source : TypeReferenceType,
  target : TypeReferenceType,
) -> Bool {
  // Same type name - check type arguments
  if source.name == target.name {
    if source.type_arguments.length() != target.type_arguments.length() {
      return false
    }
    for i = 0; i < source.type_arguments.length(); i = i + 1 {
      if not(is_assignable(source.type_arguments[i], target.type_arguments[i])) {
        return false
      }
    }
    return true
  }

  // Special handling for Generator<TYield, TReturn, TNext> assignability
  // Generator extends Iterator<TYield> which implements Iterable<TYield>
  if source.name == "Generator" && source.type_arguments.length() >= 1 {
    let source_yield_type = source.type_arguments[0]

    // Generator<TYield> -> Iterable<T>: TYield must be assignable to T
    if target.name == "Iterable" && target.type_arguments.length() >= 1 {
      let target_element_type = target.type_arguments[0]
      return is_assignable(source_yield_type, target_element_type)
    }

    // Generator<TYield> -> Iterator<T>: TYield must be assignable to T
    if target.name == "Iterator" && target.type_arguments.length() >= 1 {
      let target_yield_type = target.type_arguments[0]
      return is_assignable(source_yield_type, target_yield_type)
    }

    // Generator<TYield> -> IterableIterator<T>: TYield must be assignable to T
    if target.name == "IterableIterator" && target.type_arguments.length() >= 1 {
      let target_element_type = target.type_arguments[0]
      return is_assignable(source_yield_type, target_element_type)
    }
  }

  // Different names - for built-in generic types with different names,
  // return false (they need explicit handling like Generator -> Iterable above)
  // But for class types and other user-defined types with no type arguments,
  // we need structural compatibility checking which happens elsewhere.
  //
  // For class types (no type arguments), return true here to allow structural
  // checking to happen via Object type comparison. The actual structural check
  // should happen in check_assignment_detailed when both types have resolved
  // object representations.
  if source.type_arguments.length() == 0 &&
    target.type_arguments.length() == 0 &&
    not(is_builtin_generic_type(source.name)) &&
    not(is_builtin_generic_type(target.name)) {
    // For class types, defer to structural checking (handled elsewhere)
    // This allows Bar extends Foo to work
    true
  } else {
    // For generic types with different names and type arguments, return false
    // This prevents Generator<T> from being incorrectly assignable to unrelated types
    false
  }
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
  // Count required elements in target (excluding rest)
  let mut target_required = 0
  let mut target_rest_idx : Int? = None
  for i = 0; i < target.element_types.length(); i = i + 1 {
    if target.element_types[i].is_rest {
      target_rest_idx = Some(i)
    } else if not(target.element_types[i].is_optional) {
      target_required = target_required + 1
    }
  }

  // Source must have at least as many elements as target required
  if source.element_types.length() < target_required {
    return false
  }

  // Check element-wise assignability
  for i = 0; i < target.element_types.length(); i = i + 1 {
    let target_elem = target.element_types[i]
    if target_elem.is_rest {
      // For rest element, all remaining source elements must be assignable
      // to the rest element's array element type
      let rest_elem_type = match target_elem.element_type {
        Array(arr) => arr.element_type
        _ => target_elem.element_type // Fallback if not array
      }
      // Check all remaining source elements
      for j = i; j < source.element_types.length(); j = j + 1 {
        if not(
            is_assignable(source.element_types[j].element_type, rest_elem_type),
          ) {
          return false
        }
      }
      // Rest element handled all remaining, we're done
      return true
    }
    if i < source.element_types.length() {
      if not(
          is_assignable(
            source.element_types[i].element_type,
            target_elem.element_type,
          ),
        ) {
        return false
      }
    } else if not(target_elem.is_optional) {
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
/// Check if union is assignable to another union
/// A union is assignable to another union if all members of the source
/// are assignable to at least one member of the target
fn is_union_to_union_assignable(
  source_union : CheckerUnionType,
  target_union : CheckerUnionType,
) -> Bool {
  // Check if all source members are assignable to the target union
  for i = 0; i < source_union.types.length(); i = i + 1 {
    if not(is_assignable_to_union(source_union.types[i], target_union)) {
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

  // Check TypeReference types (classes, Generator, Iterable, etc.)
  match (source, target) {
    (TypeReference(source_ref), TypeReference(target_ref)) =>
      return check_type_reference_assignability_detailed(
        checker, source_ref, target_ref, location, path,
      )
    _ => ()
  }

  // Handle Object with class_name -> TypeReference (class instance assigned to class type)
  // This happens when: const f: Foo = new Foo();
  // new Foo() returns Object{class_name: Some("Foo")} but target is TypeReference("Foo", [])
  match (source, target) {
    (Object(source_obj), TypeReference(target_ref)) =>
      match source_obj.class_name {
        Some(source_class_name) => {
          // If class names match and target has no type arguments, they're compatible
          if source_class_name == target_ref.name &&
            target_ref.type_arguments.length() == 0 {
            return checker
          }
          // Check if source class inherits from target class
          // Resolve target class to object type and check structural compatibility
          match resolve_class_to_object_type(checker, target_ref.name) {
            Some(target_obj) =>
              return check_object_assignability_detailed(
                checker, source_obj, target_obj, location, path,
              )
            None => () // Fall through to default handling
          }
        }
        None => () // Object without class_name - fall through
      }
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
  // If source is also a union, check if all source members are assignable to target union
  match source {
    Union(source_union) => {
      // For each source union member, check if it's assignable to the target union
      for source_member in source_union.types {
        // Check if this source member is assignable to any target union member
        let mut member_assignable = false
        for target_member in union.types {
          if is_assignable(source_member, target_member) {
            member_assignable = true
            break
          }
        }
        if not(member_assignable) {
          return add_diagnostic_with_code(
            checker,
            "Type '\{type_to_string(source)}' is not assignable to type '\{type_to_string(Union(union))}'",
            location,
            TS2322,
          )
        }
      }
      // All source members are assignable to target union
      return checker
    }
    _ => ()
  }

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

  // Count required elements in target (excluding rest)
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
    let target_elem = target.element_types[i]
    if target_elem.is_rest {
      // For rest element, check all remaining source elements against the rest element's inner type
      let rest_elem_type = match target_elem.element_type {
        Array(arr) => arr.element_type
        _ => target_elem.element_type // Fallback if not array
      }
      // Check all remaining source elements
      for j = i; j < source.element_types.length(); j = j + 1 {
        let elem_path = if path == "" { "[\{j}]" } else { "\{path}[\{j}]" }
        checker = check_assignment_detailed(
          checker,
          source.element_types[j].element_type,
          rest_elem_type,
          location,
          elem_path,
        )
      }
      // Rest element handled all remaining, we're done
      break
    }
    if i < source.element_types.length() {
      let elem_path = if path == "" { "[\{i}]" } else { "\{path}[\{i}]" }
      checker = check_assignment_detailed(
        checker,
        source.element_types[i].element_type,
        target_elem.element_type,
        location,
        elem_path,
      )
    }
  }
  checker
}

///|
/// Check TypeReference assignability with detailed error reporting
/// Handles Generator -> Iterable, class types, etc.
fn check_type_reference_assignability_detailed(
  checker : TypeChecker,
  source : TypeReferenceType,
  target : TypeReferenceType,
  location : SourceLocation,
  path : String,
) -> TypeChecker {
  // Same type name - check type arguments
  if source.name == target.name {
    if source.type_arguments.length() != target.type_arguments.length() {
      return add_diagnostic_with_code(
        checker,
        "Type '\{source.name}' requires \{target.type_arguments.length()} type argument(s) but got \{source.type_arguments.length()}.",
        location,
        TS2322,
      )
    }
    let mut checker = checker
    for i = 0; i < source.type_arguments.length(); i = i + 1 {
      checker = check_assignment_detailed(
        checker,
        source.type_arguments[i],
        target.type_arguments[i],
        location,
        path,
      )
    }
    return checker
  }

  // Special handling for Generator<TYield, TReturn, TNext> -> Iterable<T>
  if source.name == "Generator" && source.type_arguments.length() >= 1 {
    let source_yield_type = source.type_arguments[0]
    // Filter out undefined from yield type - bare yield; statements don't affect type compatibility
    let filtered_yield_opt = filter_undefined_from_type(source_yield_type)

    // Generator<TYield> -> Iterable<T>: TYield must be assignable to T
    if target.name == "Iterable" && target.type_arguments.length() >= 1 {
      let target_element_type = target.type_arguments[0]
      match filtered_yield_opt {
        None => return checker // Only undefined yields - compatible with any element type
        Some(filtered_yield) =>
          return check_assignment_detailed(
            checker, filtered_yield, target_element_type, location, path,
          )
      }
    }

    // Generator<TYield> -> Iterator<T>: TYield must be assignable to T
    if target.name == "Iterator" && target.type_arguments.length() >= 1 {
      let target_yield_type = target.type_arguments[0]
      match filtered_yield_opt {
        None => return checker // Only undefined yields - compatible with any element type
        Some(filtered_yield) =>
          return check_assignment_detailed(
            checker, filtered_yield, target_yield_type, location, path,
          )
      }
    }

    // Generator<TYield> -> IterableIterator<T>: TYield must be assignable to T
    if target.name == "IterableIterator" && target.type_arguments.length() >= 1 {
      let target_element_type = target.type_arguments[0]
      match filtered_yield_opt {
        None => return checker // Only undefined yields - compatible with any element type
        Some(filtered_yield) =>
          return check_assignment_detailed(
            checker, filtered_yield, target_element_type, location, path,
          )
      }
    }
  }

  // For class types (no type arguments), resolve to their object types and check
  // structural compatibility
  if source.type_arguments.length() == 0 &&
    target.type_arguments.length() == 0 &&
    not(is_builtin_generic_type(source.name)) &&
    not(is_builtin_generic_type(target.name)) {
    // Resolve class types to their object types for structural comparison
    let source_obj_opt = resolve_class_to_object_type(checker, source.name)
    let target_obj_opt = resolve_class_to_object_type(checker, target.name)
    match (source_obj_opt, target_obj_opt) {
      (Some(source_obj), Some(target_obj)) =>
        // Check structural compatibility between resolved object types
        return check_object_assignability_detailed(
          checker, source_obj, target_obj, location, path,
        )
      _ =>
        // Can't resolve types - fall through to default handling
        ()
    }
  }

  // Default: types are not assignable
  let source_str = type_ref_to_string(source)
  let target_str = type_ref_to_string(target)
  let msg = if path == "" {
    "Type '\{source_str}' is not assignable to type '\{target_str}'"
  } else {
    "Type '\{source_str}' is not assignable to type '\{target_str}' at \{path}"
  }
  add_diagnostic_with_code(checker, msg, location, TS2322)
}

///|
/// Convert TypeReferenceType to string for error messages
fn type_ref_to_string(ref_type : TypeReferenceType) -> String {
  if ref_type.type_arguments.length() > 0 {
    let args_str = ref_type.type_arguments.map(type_to_string).join(", ")
    ref_type.name + "<" + args_str + ">"
  } else {
    ref_type.name
  }
}

///|
/// Resolve a class name to its object type for structural comparison
fn resolve_class_to_object_type(
  checker : TypeChecker,
  class_name : String,
) -> ObjectType? {
  match lookup_symbol(checker, class_name) {
    Some(symbol) =>
      match symbol.kind {
        Class => {
          // Get the class from the symbol and extract its properties
          let properties : Map[String, PropertySignature] = Map::new()
          // Use the value_declaration to get the class declaration
          match symbol.value_declaration {
            Some(node) =>
              match node {
                ClassDeclaration(class_decl) => {
                  // First, add inherited properties from the parent class
                  for heritage_clause in class_decl.heritage_clauses {
                    if heritage_clause.kind == Extends {
                      for type_node in heritage_clause.types {
                        // Extract the parent class name from heritage node
                        let parent_name = get_name_from_heritage_node(type_node)
                        match parent_name {
                          Some(name) =>
                            // Recursively get parent class properties
                            match resolve_class_to_object_type(checker, name) {
                              Some(parent_obj) =>
                                for entry in parent_obj.properties {
                                  let (prop_name, prop_sig) = entry
                                  properties[prop_name] = prop_sig
                                }
                              None => ()
                            }
                          None => ()
                        }
                      }
                    }
                  }
                  // Then add this class's own properties (overriding inherited ones)
                  for mem in class_decl.members {
                    match mem {
                      PropertyDeclaration(prop_decl) => {
                        let (prop_type, _) = match prop_decl.type_annotation {
                          Some(type_node) =>
                            match get_type_from_type_node(checker, type_node) {
                              (Some(t), _) => (t, checker)
                              (None, _) => any_type(checker)
                            }
                          None => any_type(checker)
                        }
                        properties[prop_decl.name] = PropertySignature::{
                          name: prop_decl.name,
                          prop_type,
                          is_optional: prop_decl.is_optional,
                          is_readonly: false,
                        }
                      }
                      _ => ()
                    }
                  }
                }
                _ => ()
              }
            None => ()
          }
          let (info, _) = create_type_info(checker)
          Some({
            properties,
            call_signatures: [],
            construct_signatures: [],
            index_signatures: [],
            info,
            class_name: Some(class_name),
          })
        }
        _ => None
      }
    None => None
  }
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
/// Check numeric operands for arithmetic operations
/// Emits TS2362 for left-hand side and TS2363 for right-hand side
/// Uses separate locations for left and right operand errors
fn check_numeric_operands(
  checker : TypeChecker,
  left : Type,
  right : Type,
  _operator : BinaryOperator,
  location : SourceLocation,
) -> TypeChecker {
  let left_is_numeric = is_numeric_type(left)
  let right_is_numeric = is_numeric_type(right)

  // TS2362: The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type
  let checker = if not(left_is_numeric) {
    add_diagnostic_with_code(
      checker,
      "The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type.",
      location,
      TS2362,
    )
  } else {
    checker
  }

  // TS2363: The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type
  let checker = if not(right_is_numeric) {
    add_diagnostic_with_code(
      checker,
      "The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type.",
      location,
      TS2363,
    )
  } else {
    checker
  }
  checker
}

///|
/// Check numeric operands for arithmetic operations with separate operand locations
/// Emits TS2362 for left-hand side and TS2363 for right-hand side
fn check_numeric_operands_with_locations(
  checker : TypeChecker,
  left : Type,
  right : Type,
  left_location : SourceLocation,
  right_location : SourceLocation,
) -> TypeChecker {
  let left_is_numeric = is_numeric_type(left)
  let right_is_numeric = is_numeric_type(right)

  // TS2362: The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type
  let checker = if not(left_is_numeric) {
    add_diagnostic_with_code(
      checker,
      "The left-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type.",
      left_location,
      TS2362,
    )
  } else {
    checker
  }

  // TS2363: The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type
  let checker = if not(right_is_numeric) {
    add_diagnostic_with_code(
      checker,
      "The right-hand side of an arithmetic operation must be of type 'any', 'number', 'bigint' or an enum type.",
      right_location,
      TS2363,
    )
  } else {
    checker
  }
  checker
}

///|
/// Check single numeric operand
fn check_numeric_operand(
  checker : TypeChecker,
  operand : Type,
  _operator : UnaryOperator,
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
  _left : Type,
  _right : Type,
  _operator : BinaryOperator,
  _location : SourceLocation,
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
    Number(_)
    | Boolean(_)
    | String(_)
    | Void(_)
    | Undefined(_)
    | NumberLiteral(_, _)
    | StringLiteral(_, _)
    | BooleanLiteral(_, _)
    | TemplateLiteral(_) =>
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
    Number(_)
    | Boolean(_)
    | String(_)
    | Void(_)
    | Undefined(_)
    | Null(_)
    | NumberLiteral(_, _)
    | StringLiteral(_, _)
    | BooleanLiteral(_, _)
    | TemplateLiteral(_) =>
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
/// Check if two types have overlap for equality comparisons (TS2367)
/// Types have no overlap if there's no value that could be both types
fn check_equality_type_overlap(
  checker : TypeChecker,
  left_type : Type,
  right_type : Type,
  bin_expr : BinaryExpression,
) -> TypeChecker {
  // Check if types have overlap
  if types_have_overlap(left_type, right_type) {
    return checker
  }

  // No overlap - report TS2367
  // Determine result based on operator (== vs !=)
  let result = match bin_expr.operator {
    Equals | StrictEquals => "false"
    NotEquals | StrictNotEquals => "true"
    _ => "false"
  }
  add_diagnostic_with_code(
    checker,
    "This condition will always return '\{result}' since the types '\{type_to_string(left_type)}' and '\{type_to_string(right_type)}' have no overlap.",
    bin_expr.location,
    TS2367,
  )
}

///|
/// Check if two types have any possible overlap (could share a value)
fn types_have_overlap(left : Type, right : Type) -> Bool {
  // Any/Unknown/Error overlap with everything
  match (left, right) {
    (Any(_), _) | (_, Any(_)) => return true
    (Unknown(_), _) | (_, Unknown(_)) => return true
    (Error(_), _) | (_, Error(_)) => return true
    _ => ()
  }

  // Handle union types - check if ANY member overlaps
  match left {
    Union(u) => {
      for mem in u.types {
        if types_have_overlap(mem, right) {
          return true
        }
      }
      return false
    }
    _ => ()
  }
  match right {
    Union(u) => {
      for mem in u.types {
        if types_have_overlap(left, mem) {
          return true
        }
      }
      return false
    }
    _ => ()
  }

  // Get base type categories
  let left_cat = get_type_category(left)
  let right_cat = get_type_category(right)

  // Same category types can overlap
  if left_cat == right_cat && left_cat != "never" {
    // Check for literal type mismatches within same category
    match (left, right) {
      // Different number literals have no overlap
      (NumberLiteral(n1, _), NumberLiteral(n2, _)) => n1 == n2
      // Different string literals have no overlap
      (StringLiteral(s1, _), StringLiteral(s2, _)) => s1 == s2
      // Different boolean literals have no overlap
      (BooleanLiteral(b1, _), BooleanLiteral(b2, _)) => b1 == b2
      // Template literal vs string literal - check if evaluated values could match
      (TemplateLiteral(tl), StringLiteral(s, _)) =>
        template_literal_matches_string(tl, s)
      (StringLiteral(s, _), TemplateLiteral(tl)) =>
        template_literal_matches_string(tl, s)
      // Template literal vs template literal - check if they could produce same string
      (TemplateLiteral(tl1), TemplateLiteral(tl2)) =>
        template_literals_could_match(tl1, tl2)
      // Base type vs literal always overlap (e.g., number vs 42, string vs "hello")
      _ => true
    }
  } else {
    // Different categories - no overlap
    false
  }
}

///|
/// Check if a template literal type could match a given string literal
/// For template literals with expressions, we can only match if:
/// 1. The template has no expressions and the text matches exactly
/// 2. The template has expressions but the string could be produced by any value of those expressions
fn template_literal_matches_string(
  tl : CheckerTemplateLiteralType,
  s : String,
) -> Bool {
  // If template has no types (no expressions), just concatenate texts and compare
  if tl.types.length() == 0 {
    // No expressions - just check if concatenated texts match
    let mut full_text = ""
    for text in tl.texts {
      full_text = full_text + text
    }
    full_text == s
  } else {
    // Template has expressions - check if evaluated values could match
    // Get the evaluated string value if possible
    let evaluated = evaluate_template_literal_to_string(tl)
    match evaluated {
      Some(eval_str) => eval_str == s
      None => {
        // Cannot evaluate (has non-literal expressions)
        // Check if the string at least starts with first text part
        if tl.texts.length() > 0 && not(s.has_prefix(tl.texts[0])) {
          return false
        }
        // Has non-literal expressions, could potentially match any value
        // Be conservative and say they could overlap
        true
      }
    }
  }
}

///|
/// Try to evaluate a template literal type to a concrete string
/// Returns Some(string) if all expressions are literals, None otherwise
fn evaluate_template_literal_to_string(
  tl : CheckerTemplateLiteralType,
) -> String? {
  // texts has one more element than types (for template `a${b}c`, texts=["a","c"], types=[typeof b])
  let mut result = ""
  for i = 0; i < tl.texts.length(); i = i + 1 {
    result = result + tl.texts[i]
    if i < tl.types.length() {
      // Try to get the literal value of the expression type
      match tl.types[i] {
        StringLiteral(s, _) => result = result + s
        NumberLiteral(n, _) => result = result + n.to_string()
        BooleanLiteral(b, _) =>
          result = result + (if b { "true" } else { "false" })
        _ => return None // Non-literal type, can't evaluate
      }
    }
  }
  Some(result)
}

///|
/// Check if two template literals could produce the same string
fn template_literals_could_match(
  tl1 : CheckerTemplateLiteralType,
  tl2 : CheckerTemplateLiteralType,
) -> Bool {
  // Try to evaluate both to concrete strings
  let eval1 = evaluate_template_literal_to_string(tl1)
  let eval2 = evaluate_template_literal_to_string(tl2)
  match (eval1, eval2) {
    (Some(s1), Some(s2)) => s1 == s2
    _ => {
      // At least one can't be evaluated - check if structure could match
      // If first texts are different, they likely can't match
      if tl1.texts.length() > 0 && tl2.texts.length() > 0 {
        if tl1.texts[0] != tl2.texts[0] &&
          not(tl1.texts[0].has_prefix(tl2.texts[0])) &&
          not(tl2.texts[0].has_prefix(tl1.texts[0])) {
          return false
        }
      }
      // Be conservative - they might match
      true
    }
  }
}

///|
/// Get type category for overlap checking
fn get_type_category(t : Type) -> String {
  match t {
    Number(_) | NumberLiteral(_, _) => "number"
    String(_) | StringLiteral(_, _) | TemplateLiteral(_) => "string"
    Boolean(_) | BooleanLiteral(_, _) => "boolean"
    BigInt(_) => "bigint"
    Symbol(_) => "symbol"
    Null(_) => "null"
    Undefined(_) => "undefined"
    Void(_) => "void"
    Never(_) => "never"
    Any(_) => "any"
    Unknown(_) => "unknown"
    Object(_) => "object"
    Function(_) => "function"
    Array(_) => "array"
    Tuple(_) => "tuple"
    Union(_) => "union" // Union needs special handling
    Intersection(_) => "intersection"
    TypeReference(_) => "reference"
    _ => "other"
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

///|
/// Check if a function body contains bare yield expressions (without expression)
/// Used to determine if TS7055 should be emitted (only when generator has yields
/// that would result in implicit any - i.e., bare `yield;` without a value)
fn body_contains_bare_yield(body : Node?) -> Bool {
  match body {
    Some(BlockStatement(b)) => statements_contain_bare_yield(b.statements)
    _ => false
  }
}

///|
/// Check if statements contain bare yield expressions (yield without expression)
fn statements_contain_bare_yield(statements : Array[Node]) -> Bool {
  for stmt in statements {
    match stmt {
      YieldExpression(ye) =>
        // Bare yield: yield; (no expression)
        match ye.expression {
          None => return true
          Some(_) => ()
        }
      ExpressionStatement(es) =>
        match es.expression {
          YieldExpression(ye) =>
            match ye.expression {
              None => return true
              Some(_) => ()
            }
          _ => ()
        }
      BlockStatement(b) =>
        if statements_contain_bare_yield(b.statements) {
          return true
        }
      IfStatement(is_node) => {
        if statements_contain_bare_yield_in_node(is_node.then_statement) {
          return true
        }
        match is_node.else_statement {
          Some(else_node) =>
            if statements_contain_bare_yield_in_node(else_node) {
              return true
            }
          None => ()
        }
      }
      WhileStatement(ws) =>
        if statements_contain_bare_yield_in_node(ws.statement) {
          return true
        }
      DoWhileStatement(dws) =>
        if statements_contain_bare_yield_in_node(dws.statement) {
          return true
        }
      ForStatement(fs) =>
        if statements_contain_bare_yield_in_node(fs.statement) {
          return true
        }
      ForInStatement(fis) =>
        if statements_contain_bare_yield_in_node(fis.statement) {
          return true
        }
      ForOfStatement(fos) =>
        if statements_contain_bare_yield_in_node(fos.statement) {
          return true
        }
      TryStatement(ts) => {
        if statements_contain_bare_yield_in_node(ts.try_block) {
          return true
        }
        match ts.catch_clause {
          Some(cc) =>
            if statements_contain_bare_yield_in_node(cc.block) {
              return true
            }
          None => ()
        }
        match ts.finally_block {
          Some(fb) =>
            if statements_contain_bare_yield_in_node(fb) {
              return true
            }
          None => ()
        }
      }
      LabeledStatement(ls) =>
        if statements_contain_bare_yield_in_node(ls.statement) {
          return true
        }
      // Don't descend into nested functions/generators
      FunctionDeclaration(_) => ()
      FunctionExpression(_) => ()
      ArrowFunction(_) => ()
      MethodDeclaration(_) => ()
      _ => ()
    }
  }
  false
}

///|
/// Check if a Node (typically a body) contains bare yield expressions
fn statements_contain_bare_yield_in_node(node : Node) -> Bool {
  match node {
    BlockStatement(b) => statements_contain_bare_yield(b.statements)
    ExpressionStatement(es) =>
      match es.expression {
        YieldExpression(ye) =>
          match ye.expression {
            None => true
            Some(_) => false
          }
        _ => false
      }
    YieldExpression(ye) =>
      match ye.expression {
        None => true
        Some(_) => false
      }
    _ => false
  }
}

///|
/// Collect yield types from a generator function body
/// Returns a list of types from all yield expressions (excluding nested generators)
fn collect_yield_types_from_body(
  checker : TypeChecker,
  body : Node?,
) -> (Array[Type], TypeChecker) {
  let yield_types : Array[Type] = []
  match body {
    Some(BlockStatement(block)) => {
      let (types, checker) = collect_yield_types_from_statements(
        checker,
        block.statements,
      )
      for t in types {
        yield_types.push(t)
      }
      (yield_types, checker)
    }
    _ => (yield_types, checker)
  }
}

///|
/// Collect yield types from statements
fn collect_yield_types_from_statements(
  checker : TypeChecker,
  statements : Array[Node],
) -> (Array[Type], TypeChecker) {
  let yield_types : Array[Type] = []
  let mut checker = checker
  for stmt in statements {
    let (types, c) = collect_yield_types_from_node(checker, stmt)
    checker = c
    for t in types {
      yield_types.push(t)
    }
  }
  (yield_types, checker)
}

///|
/// Collect yield types from a single node (recursively)
fn collect_yield_types_from_node(
  checker : TypeChecker,
  node : Node,
) -> (Array[Type], TypeChecker) {
  let yield_types : Array[Type] = []
  let mut checker = checker
  match node {
    YieldExpression(ye) => {
      match ye.expression {
        Some(expr) => {
          let (expr_type, c) = infer_type(checker, expr)
          checker = c
          if ye.is_delegate {
            // yield*: extract element type from iterable
            let (elem_type, c) = extract_iterable_element_type(
              checker, expr_type,
            )
            checker = c
            match elem_type {
              Some(et) => yield_types.push(et)
              None => yield_types.push(expr_type) // fallback
            }
          } else {
            yield_types.push(expr_type)
          }
        }
        None => {
          // bare yield - yields undefined
          let (undef, c) = undefined_type(checker)
          checker = c
          yield_types.push(undef)
        }
      }
      (yield_types, checker)
    }
    ExpressionStatement(es) => {
      let (types, c) = collect_yield_types_from_node(checker, es.expression)
      (types, c)
    }
    BlockStatement(b) =>
      collect_yield_types_from_statements(checker, b.statements)
    IfStatement(is_node) => {
      let (types1, c) = collect_yield_types_from_node(
        checker,
        is_node.then_statement,
      )
      checker = c
      for t in types1 {
        yield_types.push(t)
      }
      match is_node.else_statement {
        Some(else_node) => {
          let (types2, c) = collect_yield_types_from_node(checker, else_node)
          checker = c
          for t in types2 {
            yield_types.push(t)
          }
        }
        None => ()
      }
      (yield_types, checker)
    }
    WhileStatement(ws) => collect_yield_types_from_node(checker, ws.statement)
    DoWhileStatement(dws) =>
      collect_yield_types_from_node(checker, dws.statement)
    ForStatement(fs) => collect_yield_types_from_node(checker, fs.statement)
    ForInStatement(fis) => collect_yield_types_from_node(checker, fis.statement)
    ForOfStatement(fos) => collect_yield_types_from_node(checker, fos.statement)
    TryStatement(ts) => {
      let (types1, c) = collect_yield_types_from_node(checker, ts.try_block)
      checker = c
      for t in types1 {
        yield_types.push(t)
      }
      match ts.catch_clause {
        Some(cc) => {
          let (types2, c) = collect_yield_types_from_node(checker, cc.block)
          checker = c
          for t in types2 {
            yield_types.push(t)
          }
        }
        None => ()
      }
      match ts.finally_block {
        Some(fb) => {
          let (types3, c) = collect_yield_types_from_node(checker, fb)
          checker = c
          for t in types3 {
            yield_types.push(t)
          }
        }
        None => ()
      }
      (yield_types, checker)
    }
    LabeledStatement(ls) => collect_yield_types_from_node(checker, ls.statement)
    SwitchStatement(ss) => {
      for case_clause in ss.cases {
        let (types, c) = collect_yield_types_from_statements(
          checker,
          case_clause.statements,
        )
        checker = c
        for t in types {
          yield_types.push(t)
        }
      }
      (yield_types, checker)
    }
    // Don't descend into nested functions/generators - they have their own scope
    FunctionDeclaration(_) => (yield_types, checker)
    FunctionExpression(_) => (yield_types, checker)
    ArrowFunction(_) => (yield_types, checker)
    MethodDeclaration(_) => (yield_types, checker)
    // Also check binary expressions, call expressions etc for yield
    BinaryExpression(be) => {
      let (types1, c) = collect_yield_types_from_node(checker, be.left)
      checker = c
      for t in types1 {
        yield_types.push(t)
      }
      let (types2, c) = collect_yield_types_from_node(checker, be.right)
      checker = c
      for t in types2 {
        yield_types.push(t)
      }
      (yield_types, checker)
    }
    ConditionalExpression(ce) => {
      let (types1, c) = collect_yield_types_from_node(checker, ce.when_true)
      checker = c
      for t in types1 {
        yield_types.push(t)
      }
      let (types2, c) = collect_yield_types_from_node(checker, ce.when_false)
      checker = c
      for t in types2 {
        yield_types.push(t)
      }
      (yield_types, checker)
    }
    ReturnStatement(rs) =>
      match rs.expression {
        Some(expr) => {
          let (types, c) = collect_yield_types_from_node(checker, expr)
          (types, c)
        }
        None => (yield_types, checker)
      }
    VariableStatement(vs) => {
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) => {
            let (types, c) = collect_yield_types_from_node(checker, init)
            checker = c
            for t in types {
              yield_types.push(t)
            }
          }
          None => ()
        }
      }
      (yield_types, checker)
    }
    _ => (yield_types, checker)
  }
}

///|
/// Extract the element type from an Iterable type
fn extract_iterable_element_type(
  checker : TypeChecker,
  iter_type : Type,
) -> (Type?, TypeChecker) {
  match iter_type {
    Type::Array(arr) => (Some(arr.element_type), checker)
    TypeReference(tr) =>
      // Handle Generator<T>, Iterable<T>, Iterator<T>, etc.
      if (
          tr.name == "Generator" ||
          tr.name == "Iterable" ||
          tr.name == "Iterator" ||
          tr.name == "IterableIterator"
        ) &&
        tr.type_arguments.length() > 0 {
        (Some(tr.type_arguments[0]), checker)
      } else {
        // Try to look up the class/interface and check if it has Symbol.iterator
        // First try type_cache, then lookup_symbol
        match checker.type_cache.get(tr.name) {
          Some(resolved_type) =>
            // Recursively check the resolved type
            extract_iterable_element_type(checker, resolved_type)
          None =>
            // Look up symbol and get its type
            match lookup_symbol(checker, tr.name) {
              Some(symbol) =>
                match get_symbol_type(checker, symbol) {
                  (Some(class_type), c) =>
                    // For class types, we need the instance type from the construct signature
                    match class_type {
                      Object(obj) =>
                        if obj.construct_signatures.length() > 0 {
                          // Get instance type and check if it has Symbol.iterator
                          extract_iterable_element_type(
                            c,
                            obj.construct_signatures[0].return_type,
                          )
                        } else {
                          // Not a class constructor, check the object itself
                          extract_iterable_element_type(c, class_type)
                        }
                      _ => (None, c)
                    }
                  (None, c) => (None, c)
                }
              None => (None, checker)
            }
        }
      }
    Object(obj) => {
      // If this is a class instance (has class_name), we should have the methods in properties already
      // But let's check for [Symbol.iterator]() method
      // Symbol.iterator can be represented in different ways: "__@iterator", "[Symbol.iterator]", etc.
      let mut iterator_method_type : Type? = None
      for entry in obj.properties {
        let (prop_name, prop) = entry
        // Check for Symbol.iterator - stored as "__@iterator" by get_property_name()
        // Also check for other possible representations
        if prop_name == "__@iterator" ||
          prop_name == "[Symbol.iterator]" ||
          prop_name.contains("iterator") ||
          prop_name.contains("Iterator") {
          iterator_method_type = Some(prop.prop_type)
          break
        }
      }

      // If we found the iterator method, extract its return type
      match iterator_method_type {
        Some(Function(func)) => {
          // The iterator method returns an iterator
          // Don't recursively call extract_iterable_element_type to avoid infinite loops
          // (e.g., when [Symbol.iterator]() returns 'this')
          // Instead, directly look for next() method on the return type
          match func.return_type {
            Object(iter_obj) => {
              // Look for next() method on the iterator
              for entry in iter_obj.properties {
                let (prop_name, prop) = entry
                if prop_name == "next" {
                  match prop.prop_type {
                    Function(next_func) => {
                      // next() returns { value: T, done: boolean }
                      // Extract T from the 'value' property
                      match next_func.return_type {
                        Object(ret_obj) => {
                          for entry in ret_obj.properties {
                            let (val_name, val_prop) = entry
                            if val_name == "value" {
                              return (Some(val_prop.prop_type), checker)
                            }
                          }
                        }
                        _ => ()
                      }
                    }
                    _ => ()
                  }
                  break
                }
              }
              (None, checker)
            }
            TypeReference(tr) => {
              // If return type is a TypeReference like "IterableIterator<T>",
              // try to extract T from the type arguments
              if (
                  tr.name == "Generator" ||
                  tr.name == "Iterable" ||
                  tr.name == "Iterator" ||
                  tr.name == "IterableIterator"
                ) &&
                tr.type_arguments.length() > 0 {
                (Some(tr.type_arguments[0]), checker)
              } else {
                // For other TypeReferences (like custom class names), resolve and look for next()
                match lookup_symbol(checker, tr.name) {
                  Some(symbol) =>
                    match get_symbol_type(checker, symbol) {
                      (Some(resolved_type), c) => {
                        // Get the instance type if it's a class constructor
                        let instance_type = match resolved_type {
                          Object(obj) =>
                            if obj.construct_signatures.length() > 0 {
                              obj.construct_signatures[0].return_type
                            } else {
                              resolved_type
                            }
                          _ => resolved_type
                        }
                        // Now look for next() on the instance type
                        match instance_type {
                          Object(iter_obj) => {
                            for entry in iter_obj.properties {
                              let (prop_name, prop) = entry
                              if prop_name == "next" {
                                match prop.prop_type {
                                  Function(next_func) =>
                                    match next_func.return_type {
                                      Object(ret_obj) => {
                                        for entry in ret_obj.properties {
                                          let (val_name, val_prop) = entry
                                          if val_name == "value" {
                                            return (Some(val_prop.prop_type), c)
                                          }
                                        }
                                      }
                                      _ => ()
                                    }
                                  _ => ()
                                }
                                break
                              }
                            }
                            (None, c)
                          }
                          _ => (None, c)
                        }
                      }
                      (None, c) => (None, c)
                    }
                  None => (None, checker)
                }
              }
            }
            _ => (None, checker)
          }
        }
        // Handle case where the property type is already resolved to a TypeReference
        Some(TypeReference(tr)) =>
          // This shouldn't normally happen for a method, but handle it
          if (
              tr.name == "Generator" ||
              tr.name == "Iterable" ||
              tr.name == "Iterator" ||
              tr.name == "IterableIterator"
            ) &&
            tr.type_arguments.length() > 0 {
            (Some(tr.type_arguments[0]), checker)
          } else {
            (None, checker)
          }
        _ => {
          // No Symbol.iterator found - check if this IS an iterator (has next() method)
          // This handles edge cases where the object is directly used as an iterator
          for entry in obj.properties {
            let (prop_name, prop) = entry
            if prop_name == "next" {
              match prop.prop_type {
                Function(next_func) => {
                  // next() returns { value: T, done: boolean }
                  match next_func.return_type {
                    Object(ret_obj) => {
                      for entry in ret_obj.properties {
                        let (val_name, val_prop) = entry
                        if val_name == "value" {
                          return (Some(val_prop.prop_type), checker)
                        }
                      }
                    }
                    _ => ()
                  }
                }
                _ => ()
              }
              break
            }
          }
          (None, checker)
        }
      }
    }
    _ => (None, checker)
  }
}

///|
/// Check for conflicting Iterator<T> and Iterable<U> in heritage clauses
/// This detects cases like: interface Bad extends Iterator<number>, Iterable<string> {}
fn check_for_iterator_iterable_conflict_in_heritage(
  checker : TypeChecker,
  _return_type : Type,
  return_type_node : Node,
) -> TypeChecker {
  // Check the type node (AST) instead of the resolved type
  // The resolved type may already be an empty Object
  match return_type_node {
    TypeReference(tr) => {
      // Look up the interface symbol
      let mut checker = checker
      match lookup_symbol(checker, tr.type_name) {
        Some(symbol) =>
          match symbol.kind {
            Interface =>
              match symbol.value_declaration {
                Some(InterfaceDeclaration(iface)) => {
                  // Check heritage clauses for Iterator and Iterable
                  let mut iterator_type_arg : Type? = None
                  let mut iterable_type_arg : Type? = None
                  for heritage in iface.heritage_clauses {
                    for type_node in heritage.types {
                      match type_node {
                        TypeReference(type_ref) => {
                          // Check for Iterator<T>
                          if type_ref.type_name == "Iterator" &&
                            type_ref.type_arguments.length() > 0 {
                            match
                              get_type_from_type_node(
                                checker,
                                type_ref.type_arguments[0],
                              ) {
                              (Some(arg_type), c) => {
                                iterator_type_arg = Some(arg_type)
                                checker = c
                              }
                              (None, _) => ()
                            }
                          }
                          // Check for Iterable<T>
                          if type_ref.type_name == "Iterable" &&
                            type_ref.type_arguments.length() > 0 {
                            match
                              get_type_from_type_node(
                                checker,
                                type_ref.type_arguments[0],
                              ) {
                              (Some(arg_type), c) => {
                                iterable_type_arg = Some(arg_type)
                                checker = c
                              }
                              (None, _) => ()
                            }
                          }
                        }
                        _ => ()
                      }
                    }
                  }

                  // Check for conflict
                  match (iterator_type_arg, iterable_type_arg) {
                    (Some(iter_type), Some(itbl_type)) =>
                      if not(types_equal(iter_type, itbl_type)) {
                        // Report TS2322 error
                        let itbl_str = type_to_string(itbl_type)
                        let gen_type_str = "Generator<\{itbl_str}, any, any>"
                        let target_str = type_node_to_string(return_type_node)
                        let message = "Type '\{gen_type_str}' is not assignable to type '\{target_str}'."
                        add_diagnostic_with_code(
                          checker,
                          message,
                          get_location(return_type_node),
                          TS2322,
                        )
                      } else {
                        checker
                      }
                    _ => checker
                  }
                }
                _ => checker
              }
            _ => checker
          }
        None => checker
      }
    }
    _ => checker
  }
}

///|
/// Check if a Generator type is assignable to a declared return type
/// This handles checking for missing properties (TS2741) and type incompatibility (TS2322)
fn check_generator_return_type_assignability(
  checker : TypeChecker,
  func : FunctionDeclaration,
  declared_return_type : Type,
  return_type_node : Node,
) -> TypeChecker {
  // Collect yield types from the function body
  let (yield_types, checker) = collect_yield_types_from_body(checker, func.body)

  // Check for conflicting Iterator<T> and Iterable<U> in heritage clauses
  // This must be done BEFORE resolving because resolve_interface_type doesn't merge heritage
  let checker = check_for_iterator_iterable_conflict_in_heritage(
    checker, declared_return_type, return_type_node,
  )

  // Resolve the declared return type for assignability checking
  let (resolved_for_conflict_check, checker) = resolve_type_for_generator_check(
    checker, declared_return_type,
  )

  // Determine the combined yield type
  // For empty generators, infer yield type from Iterable<T> in return type if present
  let (yield_type, checker) = if yield_types.length() == 0 {
    // For empty generators, use the Iterable<T> type argument if present
    // Note: The conflict detection above will have already reported an error if
    // Iterator<T> and Iterable<U> have different type arguments
    match get_iterable_type_argument(checker, declared_return_type) {
      (Some(iterable_arg), c) => (iterable_arg, c)
      (None, c) => void_type(c)
    }
  } else if yield_types.length() == 1 {
    (yield_types[0], checker)
  } else {
    // Multiple yield types - create union
    union_type(checker, yield_types)
  }

  // Create Generator<YieldType, void, unknown> type
  let (generator_type, checker) = create_generator_type(checker, yield_type)

  // Reuse the resolved type we already computed for conflict checking
  // This avoids resolving the return type twice
  let resolved_return = resolved_for_conflict_check

  // Check assignability - use type_node_to_string for accurate type name in errors
  let original_target_str = type_node_to_string(return_type_node)

  // If no yields, skip the yield type compatibility check but still do structural checking
  let has_yields = yield_types.length() > 0
  check_generator_type_assignability_v2(
    checker,
    generator_type,
    yield_type,
    resolved_return,
    original_target_str,
    get_location(return_type_node),
    has_yields,
  )
}

///|
/// Create a Generator<T, TReturn, TNext> type
fn create_generator_type(
  checker : TypeChecker,
  yield_type : Type,
) -> (Type, TypeChecker) {
  let (info, checker) = create_type_info(checker)
  let (any_t, checker) = any_type(checker)
  (
    TypeReference({
      name: "Generator",
      type_arguments: [yield_type, any_t, any_t],
      info,
    }),
    checker,
  )
}

///|
/// Get the type argument from Iterable<T> in the return type
/// This is used to infer the yield type for empty generators
fn get_iterable_type_argument(
  checker : TypeChecker,
  t : Type,
) -> (Type?, TypeChecker) {
  match t {
    TypeReference(tr) => {
      // Direct Iterable<T> reference
      if tr.name == "Iterable" && tr.type_arguments.length() > 0 {
        return (Some(tr.type_arguments[0]), checker)
      }
      // Check if it's an interface that extends Iterable<T>
      match lookup_symbol(checker, tr.name) {
        Some(symbol) =>
          match symbol.kind {
            Interface =>
              match symbol.value_declaration {
                Some(InterfaceDeclaration(iface)) => {
                  // Check heritage clauses for Iterable<T>
                  for heritage in iface.heritage_clauses {
                    for type_node in heritage.types {
                      // Heritage types can be TypeReference nodes
                      match type_node {
                        TypeReference(type_ref) =>
                          if type_ref.type_name == "Iterable" &&
                            type_ref.type_arguments.length() > 0 {
                            match
                              get_type_from_type_node(
                                checker,
                                type_ref.type_arguments[0],
                              ) {
                              (Some(arg_type), c) => return (Some(arg_type), c)
                              (None, _) => ()
                            }
                          }
                        _ => ()
                      }
                    }
                  }
                  (None, checker)
                }
                _ => (None, checker)
              }
            _ => (None, checker)
          }
        None => (None, checker)
      }
    }
    _ => (None, checker)
  }
}

///|
/// Get the type argument from Iterator<T> in the return type
fn get_iterator_type_argument(
  checker : TypeChecker,
  t : Type,
) -> (Type?, TypeChecker) {
  match t {
    TypeReference(tr) => {
      // Direct Iterator<T> reference
      if tr.name == "Iterator" && tr.type_arguments.length() > 0 {
        return (Some(tr.type_arguments[0]), checker)
      }
      // Check if it's an interface that extends Iterator<T>
      match lookup_symbol(checker, tr.name) {
        Some(symbol) =>
          match symbol.kind {
            Interface =>
              match symbol.value_declaration {
                Some(InterfaceDeclaration(iface)) => {
                  // Check heritage clauses for Iterator<T>
                  for heritage in iface.heritage_clauses {
                    for type_node in heritage.types {
                      match type_node {
                        TypeReference(type_ref) =>
                          if type_ref.type_name == "Iterator" &&
                            type_ref.type_arguments.length() > 0 {
                            match
                              get_type_from_type_node(
                                checker,
                                type_ref.type_arguments[0],
                              ) {
                              (Some(arg_type), c) => return (Some(arg_type), c)
                              (None, _) => ()
                            }
                          }
                        _ => ()
                      }
                    }
                  }
                  (None, checker)
                }
                _ => (None, checker)
              }
            _ => (None, checker)
          }
        None => (None, checker)
      }
    }
    _ => (None, checker)
  }
}

///|
/// Get both Iterator<T> and Iterable<U> type arguments from the return type
/// Returns (Iterator arg, Iterable arg, checker)
/// This is used to detect conflicts in generator return types
fn get_iterator_and_iterable_type_arguments(
  checker : TypeChecker,
  t : Type,
) -> (Type?, Type?, TypeChecker) {
  match t {
    TypeReference(tr) => {
      let mut iterator_arg : Type? = None
      let mut iterable_arg : Type? = None
      let mut checker = checker

      // Direct Iterator<T> or Iterable<U> reference
      if tr.name == "Iterator" && tr.type_arguments.length() > 0 {
        iterator_arg = Some(tr.type_arguments[0])
      } else if tr.name == "Iterable" && tr.type_arguments.length() > 0 {
        iterable_arg = Some(tr.type_arguments[0])
      }

      // Check if it's an interface that extends Iterator<T> and/or Iterable<U>
      match lookup_symbol(checker, tr.name) {
        Some(symbol) =>
          match symbol.kind {
            Interface =>
              match symbol.value_declaration {
                Some(InterfaceDeclaration(iface)) =>
                  // Check heritage clauses for Iterator<T> and Iterable<U>
                  for heritage in iface.heritage_clauses {
                    for type_node in heritage.types {
                      match type_node {
                        TypeReference(type_ref) =>
                          if type_ref.type_name == "Iterator" &&
                            type_ref.type_arguments.length() > 0 {
                            match
                              get_type_from_type_node(
                                checker,
                                type_ref.type_arguments[0],
                              ) {
                              (Some(arg_type), c) => {
                                iterator_arg = Some(arg_type)
                                checker = c
                              }
                              (None, _) => ()
                            }
                          } else if type_ref.type_name == "Iterable" &&
                            type_ref.type_arguments.length() > 0 {
                            match
                              get_type_from_type_node(
                                checker,
                                type_ref.type_arguments[0],
                              ) {
                              (Some(arg_type), c) => {
                                iterable_arg = Some(arg_type)
                                checker = c
                              }
                              (None, _) => ()
                            }
                          }
                        _ => ()
                      }
                    }
                  }
                _ => ()
              }
            _ => ()
          }
        None => ()
      }
      (iterator_arg, iterable_arg, checker)
    }
    _ => (None, None, checker)
  }
}

///|
/// Resolve a type for generator return type checking
/// This resolves interfaces and type references to their structural form
fn resolve_type_for_generator_check(
  checker : TypeChecker,
  t : Type,
) -> (Type, TypeChecker) {
  match t {
    TypeReference(tr) =>
      // Try to resolve the type reference
      match lookup_symbol(checker, tr.name) {
        Some(symbol) =>
          match symbol.kind {
            Interface =>
              // Resolve interface to its object type
              match resolve_interface_type(checker, symbol) {
                (Some(resolved), checker) => (resolved, checker)
                (None, checker) => (t, checker)
              }
            _ => (t, checker)
          }
        None => (t, checker)
      }
    _ => (t, checker)
  }
}

///|
/// Check if a Generator type is assignable to a target type (v2 with has_yields param)
fn check_generator_type_assignability_v2(
  checker : TypeChecker,
  generator_type : Type,
  yield_type : Type,
  resolved_target : Type,
  original_target_str : String,
  location : SourceLocation,
  has_yields : Bool,
) -> TypeChecker {
  match resolved_target {
    Object(target_obj) => {
      // Check if target has any properties that Generator doesn't have
      // Generator has: next, return, throw, [Symbol.iterator]
      let generator_props = ["next", "return", "throw"]
      let mut checker = checker
      for entry in target_obj.properties {
        let (prop_name, target_prop) = entry
        // Check if this is a property Generator doesn't have
        let is_generator_prop = generator_props
          .iter()
          .any(fn(p) { p == prop_name })
        if not(is_generator_prop) && not(target_prop.is_optional) {
          // TS2741: Property is missing
          checker = add_diagnostic_with_code(
            checker,
            "Property '\{prop_name}' is missing in type '\{type_to_string(generator_type)}' but required in type '\{original_target_str}'.",
            location,
            TS2741,
          )
        }
      }
      checker
    }
    TypeReference(target_ref) =>
      // Check if target is an iterator type and verify type parameter compatibility
      if is_iterator_type_name(target_ref.name) {
        // Only check yield type compatibility if there are actual yields
        // Empty generators are compatible with any element type
        if has_yields && target_ref.type_arguments.length() > 0 {
          let expected_yield = target_ref.type_arguments[0]
          check_yield_type_vs_expected(
            checker, generator_type, yield_type, expected_yield, original_target_str,
            location,
          )
        } else {
          checker
        }
      } else {
        // Non-iterator type reference - Generator is not assignable
        // This is handled by is_valid_generator_return_type already
        checker
      }
    _ => checker
  }
}

///|
/// Check if actual yield type is compatible with expected yield type from return type annotation
fn check_yield_type_vs_expected(
  checker : TypeChecker,
  generator_type : Type,
  actual_yield : Type,
  expected_yield : Type,
  original_target_str : String,
  location : SourceLocation,
) -> TypeChecker {
  // Filter out undefined from the actual yield type
  // In TypeScript, bare yield; statements don't affect the type parameter
  // when there's an explicit return type annotation
  let filtered_yield = filter_undefined_from_type(actual_yield)

  // If after filtering, there's nothing left (only undefined yields), it's valid
  match filtered_yield {
    None => checker
    Some(yield_type) => {
      // Check if the yield type is assignable to the expected type
      // Use check_assignment_detailed which handles class inheritance
      let initial_error_count = checker.diagnostics.length()
      let checked = check_assignment_detailed(
        checker, yield_type, expected_yield, location, "",
      )
      // If there were new errors, we need to report the generator type error instead
      if checked.diagnostics.length() > initial_error_count {
        // Remove the detailed error and add a generator-specific error
        let diagnostics : Array[Diagnostic] = []
        for i = 0; i < initial_error_count; i = i + 1 {
          diagnostics.push(checked.diagnostics[i])
        }
        add_diagnostic_with_code(
          { ..checked, diagnostics, },
          "Type '\{type_to_string(generator_type)}' is not assignable to type '\{original_target_str}'.",
          location,
          TS2322,
        )
      } else {
        checked
      }
    }
  }
}

///|
/// Filter undefined from a type - returns None if only undefined, Some(type) otherwise
fn filter_undefined_from_type(t : Type) -> Type? {
  match t {
    Undefined(_) => None
    Union(u) => {
      // Filter out undefined from the union
      let filtered : Array[Type] = []
      for member in u.types {
        match member {
          Undefined(_) => () // Skip undefined
          _ => filtered.push(member)
        }
      }
      if filtered.length() == 0 {
        None
      } else if filtered.length() == 1 {
        Some(filtered[0])
      } else {
        Some(Union({ types: filtered, info: u.info }))
      }
    }
    _ => Some(t)
  }
}

///|
/// Unwrap a Promise<T> type to get T
/// For async functions, return statements should be checked against T, not Promise<T>
fn unwrap_promise_type(t : Type) -> Type {
  match t {
    TypeReference(ref_type) =>
      if (ref_type.name == "Promise" || ref_type.name == "PromiseLike") &&
        ref_type.type_arguments.length() > 0 {
        ref_type.type_arguments[0]
      } else {
        t
      }
    _ => t
  }
}

///|
/// Check if a return type node is a valid generator return type
/// Generator can be assigned to object types, iterator types, etc.
/// But NOT to primitive types (number, string, boolean, etc.)
fn is_valid_generator_return_type(return_type_node : Node) -> Bool {
  match return_type_node {
    // Primitive keyword types are NOT valid (Generator can't be assigned to them)
    KeywordType(kt) =>
      match kt.kind {
        // Invalid primitive types - Generator is not assignable to these
        Number => false
        String => false
        Boolean => false
        Symbol => false
        BigInt => false
        // Valid types that Generator can be assigned to
        Any => true
        Unknown => true
        Object => true
        Never => true // Never is bottom type, everything assignable
        Void => true // Handled separately with TS2505
        Undefined => true
        Null => true
        Const => true
      }
    // TypeReference - check if it's an iterator type (always valid)
    // or a class/interface type (also valid, Generator is assignable to {})
    TypeReference(_) => true
    // Object type literals (like {}) are valid - Generator extends object
    TypeLiteral(_) => true
    // Union types - valid if at least one member is valid
    UnionType(ut) => {
      for t in ut.types {
        if is_valid_generator_return_type(t) {
          return true
        }
      }
      false
    }
    // Intersection types - need to check each member
    IntersectionType(it) => {
      for t in it.types {
        if not(is_valid_generator_return_type(t)) {
          return false
        }
      }
      true
    }
    // Array types, tuple types, etc. - Generator is not assignable to these
    ArrayType(_) => false
    TupleType(_) => false
    // Function types - Generator is not assignable
    FunctionType(_) => false
    // Other types default to valid (be permissive)
    _ => true
  }
}

///|
/// Check if a type name is a valid iterator type name
fn is_iterator_type_name(name : String) -> Bool {
  name == "Generator" ||
  name == "Iterator" ||
  name == "IterableIterator" ||
  name == "Iterable" ||
  name == "AsyncGenerator" ||
  name == "AsyncIterator" ||
  name == "AsyncIterable" ||
  name == "AsyncIterableIterator"
}

///|
/// Extract the yield type from a generator return type node
/// e.g., from IterableIterator<Foo> extracts Foo as a Type
fn extract_yield_type_from_return_type(
  checker : TypeChecker,
  return_type_node : Node,
) -> (Type?, TypeChecker) {
  match return_type_node {
    TypeReference(tr) =>
      // Check if this is an iterator type with type arguments
      if is_iterator_type_name(tr.type_name) && tr.type_arguments.length() > 0 {
        // The first type argument is typically the yield type
        // e.g., Generator<T>, IterableIterator<T>, Iterator<T>
        let first_arg = tr.type_arguments[0]
        match get_type_from_type_node(checker, first_arg) {
          (Some(yield_type), checker) => (Some(yield_type), checker)
          (None, checker) => (None, checker)
        }
      } else {
        (None, checker)
      }
    _ => (None, checker)
  }
}

///|
/// Convert a type node to a string representation for error messages
fn type_node_to_string(node : Node) -> String {
  match node {
    KeywordType(kt) =>
      match kt.kind {
        Any => "any"
        Unknown => "unknown"
        Number => "number"
        String => "string"
        Boolean => "boolean"
        Void => "void"
        Undefined => "undefined"
        Null => "null"
        Never => "never"
        Object => "object"
        Symbol => "symbol"
        BigInt => "bigint"
        Const => "const"
      }
    TypeReference(tr) => {
      // type_name is a String, type_arguments is Array[Node]
      let name = tr.type_name
      if tr.type_arguments.length() > 0 {
        let sb = StringBuilder::new()
        sb.write_string(name)
        sb.write_string("<")
        for i, arg in tr.type_arguments {
          if i > 0 {
            sb.write_string(", ")
          }
          sb.write_string(type_node_to_string(arg))
        }
        sb.write_string(">")
        sb.to_string()
      } else {
        name
      }
    }
    ArrayType(at) => type_node_to_string(at.element_type) + "[]"
    LiteralType(lt) =>
      match lt.literal {
        StringLiteral(sl) => "\"" + sl.value + "\""
        NumericLiteral(nl) => nl.value
        BooleanLiteral(bl) => if bl.value { "true" } else { "false" }
        NullLiteral(_) => "null"
        _ => "literal"
      }
    UnionType(ut) => {
      let sb = StringBuilder::new()
      for i, t in ut.types {
        if i > 0 {
          sb.write_string(" | ")
        }
        sb.write_string(type_node_to_string(t))
      }
      sb.to_string()
    }
    IntersectionType(it) => {
      let sb = StringBuilder::new()
      for i, t in it.types {
        if i > 0 {
          sb.write_string(" & ")
        }
        sb.write_string(type_node_to_string(t))
      }
      sb.to_string()
    }
    TupleType(tt) => {
      let sb = StringBuilder::new()
      sb.write_string("[")
      for i, elem in tt.element_types {
        if i > 0 {
          sb.write_string(", ")
        }
        sb.write_string(type_node_to_string(elem))
      }
      sb.write_string("]")
      sb.to_string()
    }
    Identifier(id) => id.name
    _ => "unknown"
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
  // Check for TS2371: parameter initializer in ambient declaration
  let is_ambient = is_ambient_declaration(func.modifiers) || func.body is None
  let checker = if is_ambient {
    check_ambient_parameter_initializers(checker, func.parameters)
  } else {
    checker
  }

  // Check for TS1221: Generators are not allowed in an ambient context
  let checker = if func.is_generator && is_ambient {
    add_diagnostic_with_code(
      checker,
      "Generators are not allowed in an ambient context.",
      func.location,
      TS1221,
    )
  } else {
    checker
  }

  // Check for TS2505: A generator cannot have a 'void' type annotation
  let checker = if func.is_generator {
    match func.return_type {
      Some(return_type_node) => {
        // Check if return type is 'void'
        let is_void_type = match return_type_node {
          KeywordType(kt) => kt.kind == Void
          _ => false
        }
        if is_void_type {
          add_diagnostic_with_code(
            checker,
            "A generator cannot have a 'void' type annotation.",
            get_location(return_type_node),
            TS2505,
          )
        } else {
          // TS2322: Generator return type must be an iterator type
          // Check if return type is a valid iterator type (Generator, Iterator, IterableIterator, etc.)
          let is_valid_generator_return = is_valid_generator_return_type(
            return_type_node,
          )
          if not(is_valid_generator_return) {
            let return_type_str = type_node_to_string(return_type_node)
            add_diagnostic_with_code(
              checker,
              "Type 'Generator<any, any, unknown>' is not assignable to type '" +
              return_type_str +
              "'.",
              get_location(return_type_node),
              TS2322,
            )
          } else {
            checker
          }
        }
      }
      None =>
        // TS7055: Generator function lacks return-type annotation
        // Only emit when noImplicitAny is enabled AND the function has bare yield statements
        // Generators that yield concrete values (yield 0) don't need this error
        if checker.no_implicit_any && body_contains_bare_yield(func.body) {
          let name = match func.name {
            Some(Identifier(id)) => id.name
            _ => "(anonymous)"
          }
          add_diagnostic_with_code(
            checker,
            "'" +
            name +
            "', which lacks return-type annotation, implicitly has an 'any' yield type.",
            func.location,
            TS7055,
          )
        } else {
          checker
        }
    }
  } else {
    checker
  }

  // Check for TS2372: parameter cannot reference itself
  let checker = check_parameter_self_reference(checker, func.parameters)

  // Clear any narrowed types from outer scope before entering function body
  let saved_narrowed_types = checker.narrowed_types
  let checker = clear_narrowed_types(checker)

  // Push a new local scope for the function
  let checker = push_local_scope(checker)

  // Check type parameter names for reserved keywords (TS2368)
  let checker = check_type_parameter_names(checker, func.type_parameters)

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
    // Check TS2461: Array binding pattern parameter with non-array default value
    match param {
      Parameter(p) =>
        match (p.name, p.initializer) {
          (ArrayBindingPattern(_), Some(init)) => {
            let (init_type, c) = infer_type(checker, init)
            checker = c
            // Check if default value type is array-like
            if not(is_array_like_type(init_type)) {
              checker = add_diagnostic_with_code(
                checker,
                "Type '\{type_to_string(init_type)}' is not an array type.",
                p.location,
                TS2461,
              )
            }
          }
          _ => ()
        }
      _ => ()
    }
    // Check TS2463: Binding pattern parameter cannot be optional in implementation signature
    // Only report this error for true optional parameters (using ? syntax), not for
    // parameters with default values (using = syntax). Parameters with default values
    // may have is_optional = true but they have an initializer.
    match param {
      Parameter(p) =>
        if p.is_optional && p.initializer.is_empty() {
          match p.name {
            ArrayBindingPattern(_) | ObjectBindingPattern(_) =>
              checker = add_diagnostic_with_code(
                checker,
                "A binding pattern parameter cannot be optional in an implementation signature.",
                p.location,
                TS2463,
              )
            _ => ()
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

  // Track generator function context for TS2764
  // For non-generator functions, we must reset generator_function_depth to 0
  // to ensure yield in nested non-generator functions triggers TS1163
  let saved_generator_depth = checker.generator_function_depth
  let saved_collected_yield_types = checker.collected_yield_types
  let (checker, saved_yield_types) = if func.is_generator {
    let has_return_type = func.return_type is Some(_)
    // Extract yield type from return type annotation (e.g., Foo from IterableIterator<Foo>)
    let (yield_type, checker) = match func.return_type {
      Some(return_type_node) =>
        extract_yield_type_from_return_type(checker, return_type_node)
      None => (None, checker)
    }
    enter_generator_function(checker, has_return_type, yield_type~)
  } else {
    // Reset generator context - yield is not valid in non-generator functions
    (
      {
        ..checker,
        generator_function_depth: 0,
        generator_has_return_type: false,
        generator_yield_type: None,
      },
      [],
    )
  }

  // Track regular function context (for 'arguments' object availability)
  let checker = enter_regular_function(checker)

  // Hoist var declarations to the function scope before checking body
  // This ensures self-references like `var x = yield \`${ x }\`` work correctly
  let checker = match func.body {
    Some(body) => hoist_var_declarations(checker, body)
    None => checker
  }

  // Check function body
  let checker = match func.body {
    Some(body) => check_statement(checker, body)
    None => checker
  }

  // Exit generator function context or restore saved depth
  let (checker, _collected_yield_types) = if func.is_generator {
    exit_generator_function(checker, saved_yield_types)
  } else {
    // Restore the saved generator context
    (
      {
        ..checker,
        generator_function_depth: saved_generator_depth,
        collected_yield_types: saved_collected_yield_types,
      },
      [],
    )
  }

  // Exit async function context
  let checker = if func.is_async {
    exit_async_function(checker)
  } else {
    checker
  }

  // Exit regular function context
  let checker = exit_regular_function(checker)

  // Check return type consistency if a return type is declared
  // This must happen AFTER body is checked so variables are in scope
  // Skip for generators - their return type is checked differently (via yield types)
  let checker = if func.is_generator {
    // For generators, return statements are checked separately
    // (against the TReturn type argument, not the full Generator/Iterator type)
    checker
  } else {
    match func.return_type {
      Some(return_type_node) =>
        match get_type_from_type_node(checker, return_type_node) {
          (Some(declared_return), c) => {
            // For async functions, unwrap the Promise type for return type checking
            // async function foo(): Promise<T> { return x; } - x should be checked against T
            let effective_return_type = if func.is_async {
              unwrap_promise_type(declared_return)
            } else {
              declared_return
            }
            check_return_type_consistency(c, func, effective_return_type)
          }
          (None, c) => c
        }
      None => checker
    }
  }

  // Check generator return type assignability (TS2741, TS2322)
  // This checks if the Generator type is structurally assignable to the declared return type
  let checker = if func.is_generator {
    match func.return_type {
      Some(return_type_node) =>
        match get_type_from_type_node(checker, return_type_node) {
          (Some(declared_return), c) =>
            check_generator_return_type_assignability(
              c, func, declared_return, return_type_node,
            )
          (None, c) => c
        }
      None => checker
    }
  } else {
    checker
  }

  // Check TS2742: Inferred type cannot be named without reference
  // This applies when exported function has no explicit return type
  let checker = check_inferred_type_accessibility(checker, func)

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
  let (cond_type, checker) = infer_type(checker, if_stmt.condition)

  // Check for always-true conditions (TS2773, TS2774)
  let checker = check_condition_always_true(
    checker,
    if_stmt.condition,
    cond_type,
  )

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
/// Check for conditions that always evaluate to true (TS2773, TS2774)
fn check_condition_always_true(
  checker : TypeChecker,
  condition : Node,
  cond_type : Type,
) -> TypeChecker {
  // TS2773: Function used as condition without being called
  match condition {
    Identifier(ident) =>
      match cond_type {
        Function(_) =>
          return add_diagnostic_with_code(
            checker,
            "This condition will always return true since this function is always defined. Did you mean to call it instead?",
            ident.location,
            TS2773,
          )
        Object(obj) =>
          // Check if it's a callable object type
          if obj.call_signatures.length() > 0 {
            return add_diagnostic_with_code(
              checker,
              "This condition will always return true since this function is always defined. Did you mean to call it instead?",
              ident.location,
              TS2773,
            )
          }
        _ => ()
      }
    _ => ()
  }

  // TS2774: Object/non-nullable value always truthy
  // Only check for simple identifiers that are objects
  match condition {
    Identifier(ident) =>
      match cond_type {
        Object(obj) =>
          // Object types are always truthy (when not null/undefined)
          // Only report if strictNullChecks is implied and no call signatures
          if obj.call_signatures.is_empty() && obj.class_name is Some(_) {
            return add_diagnostic_with_code(
              checker,
              "This condition will always return true since this '\{type_to_string(cond_type)}' is always defined.",
              ident.location,
              TS2774,
            )
          }
        _ => ()
      }
    _ => ()
  }
  checker
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
/// Check if the left-hand side of a for-in statement is valid (TS2406)
fn check_for_in_left_side(
  checker : TypeChecker,
  initializer : Node,
) -> TypeChecker {
  match initializer {
    // Valid: for (const key in obj), for (let key in obj), for (var key in obj)
    VariableStatement(_) => checker
    // Valid: for (key in obj) where key is an identifier (previously declared)
    Identifier(_) => checker
    // Valid: for (obj.prop in otherObj) - property access assignment
    PropertyAccessExpression(_) => checker
    // Valid: for (obj["prop"] in otherObj) - element access assignment
    ElementAccessExpression(_) => checker
    // Invalid: expressions like (1 + 2), function calls, etc.
    _ =>
      add_diagnostic_with_code(
        checker,
        "The left-hand side of a 'for...in' statement must be a variable or a property access.",
        get_node_location(initializer),
        TS2406,
      )
  }
}

///|
/// Check for-in statement
/// Validates TS2406: Left-hand side must be a variable
/// Validates TS2407: Right-hand side must be an object type
fn check_for_in_statement(
  checker : TypeChecker,
  for_in_stmt : ForInStatement,
) -> TypeChecker {
  // Check the left-hand side (TS2406)
  // Must be a variable declaration, identifier, or property access
  let checker = check_for_in_left_side(checker, for_in_stmt.initializer)

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
    VariableStatement(var_stmt) =>
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
    Identifier(_) =>
      // Handle: for (key in obj) where key was previously declared
      checker
    _ => checker
  }
}

///|
/// Check if the left-hand side of a for-of statement is valid (TS2487)
fn check_for_of_left_side(
  checker : TypeChecker,
  initializer : Node,
) -> TypeChecker {
  match initializer {
    // Valid: for (const item of arr), for (let item of arr), for (var item of arr)
    VariableStatement(_) => checker
    // Valid: for (item of arr) where item is an identifier (previously declared)
    Identifier(_) => checker
    // Valid: for (obj.prop of arr) - property access assignment
    PropertyAccessExpression(_) => checker
    // Valid: for (obj["prop"] of arr) - element access assignment
    ElementAccessExpression(_) => checker
    // Valid: for ([a, b] of arr) - array destructuring without declaration
    ArrayBindingPattern(_) => checker
    // Valid: for ({x, y} of arr) - object destructuring without declaration
    ObjectBindingPattern(_) => checker
    // Valid: for ([a, b] of arr) - array literal used as destructuring pattern
    ArrayLiteralExpression(_) => checker
    // Valid: for ({x, y} of arr) - object literal used as destructuring pattern
    ObjectLiteralExpression(_) => checker
    // Invalid: expressions like (1 + 2), function calls, etc.
    _ =>
      add_diagnostic_with_code(
        checker,
        "The left-hand side of a 'for...of' statement must be a variable or a property access.",
        get_node_location(initializer),
        TS2487,
      )
  }
}

///|
/// Check for-of statement
/// Validates TS2487: Left-hand side must be a variable
/// Validates TS2488: Right-hand side must be iterable (array, string, or has [Symbol.iterator])
/// Validates TS2588: Cannot assign to const variable
/// Validates TS2322: Type compatibility for pre-declared variables
fn check_for_of_statement(
  checker : TypeChecker,
  for_of_stmt : ForOfStatement,
) -> TypeChecker {
  // Check the left-hand side (TS2487)
  let checker = check_for_of_left_side(checker, for_of_stmt.initializer)

  // Check for TS2448: Variable used before declaration
  // If the for-of expression is an identifier that matches the variable being declared,
  // report an error because the variable is used before it's declared
  let checker = match for_of_stmt.initializer {
    VariableStatement(var_stmt) =>
      if var_stmt.declarations.length() > 0 {
        let decl = var_stmt.declarations[0]
        match (decl.name, for_of_stmt.expression) {
          (Identifier(decl_id), Identifier(expr_id)) =>
            if decl_id.name == expr_id.name && (var_stmt.is_let || var_stmt.is_const) {
              add_diagnostic_with_code(
                checker,
                "Block-scoped variable '\{decl_id.name}' used before its declaration.",
                get_node_location(for_of_stmt.expression),
                TS2448,
              )
            } else {
              checker
            }
          _ => checker
        }
      } else {
        checker
      }
    _ => checker
  }

  // Infer the type of the iterable expression
  let (iterable_type, checker) = infer_type(checker, for_of_stmt.expression)

  // Push scope for loop variable
  let checker = push_local_scope(checker)

  // Add the loop variable to scope with the element type
  let checker = add_for_of_variable_to_scope(
    checker,
    for_of_stmt.initializer,
    iterable_type,
    get_node_location(for_of_stmt.expression),
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
  expr_location : SourceLocation,
) -> TypeChecker {
  // Get the element type from the iterable
  let (elem_type, checker) = get_for_of_element_type(
    checker,
    iterable_type,
    expr_location,
  )
  match initializer {
    VariableStatement(var_stmt) =>
      // Handle: for (const item of arr) or for (const [a, b] of arr)
      if var_stmt.declarations.length() > 0 {
        let decl = var_stmt.declarations[0]
        match decl.name {
          Identifier(id) => {
            // Use add_local_const_variable for let/const to track block-scoped variables
            // This is needed for TS2481 error detection (var conflicts with let/const)
            if var_stmt.is_let || var_stmt.is_const {
              add_local_const_variable(checker, id.name, elem_type)
            } else {
              add_local_variable(checker, id.name, elem_type)
            }
          }
          ArrayBindingPattern(_) | ObjectBindingPattern(_) => {
            // Check for duplicate bindings (TS2451) if let/const
            let checker = if var_stmt.is_let || var_stmt.is_const {
              check_duplicate_bindings(checker, decl.name)
            } else {
              checker
            }
            // Handle destructuring patterns
            // For let/const, we need to track binding names in const_vars for TS2481
            if var_stmt.is_let || var_stmt.is_const {
              add_binding_pattern_variables_as_const(checker, decl.name, elem_type)
            } else {
              add_binding_pattern_variables(checker, decl.name, elem_type)
            }
          }
          _ => checker
        }
      } else {
        checker
      }
    Identifier(id) => {
      // Handle: for (item of arr) where item was previously declared
      // First check if the variable exists in scope (TS2304)
      let var_type = lookup_local_variable(checker, id.name)
      match var_type {
        None => {
          // Variable not found - report TS2304
          add_diagnostic_with_code(
            checker,
            "Cannot find name '\{id.name}'.",
            get_node_location(initializer),
            TS2304,
          )
        }
        Some(declared_type) => {
          // Variable exists - check if it's const (TS2588)
          let checker = if is_local_const_variable(checker, id.name) {
            add_diagnostic_with_code(
              checker,
              "Cannot assign to '\{id.name}' because it is a constant.",
              get_node_location(initializer),
              TS2588,
            )
          } else {
            checker
          }

          // Type check: ensure elem_type is assignable to variable's declared type
          if not(is_assignable(elem_type, declared_type)) {
            let elem_str = type_to_string(elem_type)
            let var_str = type_to_string(declared_type)
            let msg = "Type '\{elem_str}' is not assignable to type '\{var_str}'."
            add_diagnostic_with_code(
              checker,
              msg,
              get_node_location(initializer),
              TS2322,
            )
          } else {
            checker
          }
        }
      }
    }
    // Handle: for ([a, b] of arr) or for ({x, y} of arr)
    // Bare destructuring pattern (without var/let/const)
    // Variables should already be declared
    ArrayBindingPattern(_) | ObjectBindingPattern(_) | ArrayLiteralExpression(_) | ObjectLiteralExpression(_) =>
      checker
    _ => checker
  }
}

///|
/// Get the element type of an iterable for for-of loops
/// Validates iterator protocol and reports appropriate errors:
/// - TS2488: Type must have '[Symbol.iterator]()' method that returns an iterator
/// - TS2569: Type is not an array type or a string type
fn get_for_of_element_type(
  checker : TypeChecker,
  iterable_type : Type,
  expr_location : SourceLocation,
) -> (Type, TypeChecker) {
  match iterable_type {
    Array(arr) => (arr.element_type, checker)
    String(_) => string_type(checker) // Iterating string produces strings
    _ => {
      // Try to extract element type using iterator protocol
      let (elem_type_opt, checker) = extract_iterable_element_type(
        checker,
        iterable_type,
      )
      match elem_type_opt {
        Some(elem_type) => (elem_type, checker)
        None => {
          // Could not extract element type - check if we should report error
          // Only report TS2488 for obviously non-iterable types (primitives)
          // For complex types (Object, TypeReference, etc.), fall back to 'any'
          // to avoid false positives when Symbol.iterator might be present but
          // not yet resolved in the type system

          // Special case: Check if this is an Object with next() but no [Symbol.iterator]()
          // This is a direct iterator being used incorrectly (TS2488)
          // IMPORTANT: Only check this if extract_iterable_element_type returned None
          // (meaning [Symbol.iterator]() was not found or didn't work)
          let is_direct_iterator = match iterable_type {
            Object(obj) => {
              let mut has_next = false
              for entry in obj.properties {
                let (prop_name, _) = entry
                if prop_name == "next" {
                  has_next = true
                  break
                }
              }
              // It's a direct iterator if it has next() but we couldn't extract
              // the iterable element type (meaning no working [Symbol.iterator]())
              has_next
            }
            _ => false
          }

          let should_error = if is_direct_iterator {
            true // Error: has next() but no [Symbol.iterator]()
          } else {
            match iterable_type {
              Number(_) | Boolean(_) | Null(_) | Undefined(_) | Void(_) => true
              Object(_) | TypeReference(_) | Union(_) | Intersection(_) => false
              Any(_) => false // any is always iterable
              _ => false // Default: don't error for complex types
            }
          }

          let checker = if should_error {
            let type_str = type_to_string(iterable_type)
            let msg = "Type '\{type_str}' must have a '[Symbol.iterator]()' method that returns an iterator."
            add_diagnostic_with_code(checker, msg, expr_location, TS2488)
          } else {
            checker
          }

          let (any_t, checker) = any_type(checker)
          (any_t, checker)
        }
      }
    }
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
/// Note: A class that extends null is NOT considered a derived class for
/// the purposes of super() call requirements, because null has no constructor
fn is_derived_class(class_decl : ClassDeclaration) -> Bool {
  for clause in class_decl.heritage_clauses {
    if clause.kind == Extends {
      // Check if it's extending null
      for type_expr in clause.types {
        match type_expr {
          TypeReference(type_ref) =>
            if type_ref.type_name == "null" {
              // extends null - not a derived class for super() purposes
              return false
            }
          _ => ()
        }
      }
      return true
    }
  }
  false
}

///|
/// Check if a class extends null (for TS17005)
fn extends_null(class_decl : ClassDeclaration) -> Bool {
  for clause in class_decl.heritage_clauses {
    if clause.kind == Extends {
      for type_expr in clause.types {
        match type_expr {
          TypeReference(type_ref) =>
            if type_ref.type_name == "null" {
              return true
            }
          _ => ()
        }
      }
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
    // Variable statements (let/const/var declarations)
    VariableStatement(vs) => {
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) => if contains_super_call(init) { return true }
          None => ()
        }
      }
      false
    }
    // Object literal expressions
    ObjectLiteralExpression(ole) => {
      for prop in ole.properties {
        match prop {
          PropertyAssignment(_, value, _) =>
            if contains_super_call(value) {
              return true
            }
          ShorthandProperty(_, _) => ()
          SpreadAssignment(expr, _) =>
            if contains_super_call(expr) {
              return true
            }
          MethodDeclaration(_, func, _) =>
            if contains_super_call(func.body) {
              return true
            }
          GetAccessor(_, func, _) =>
            if contains_super_call(func.body) {
              return true
            }
          SetAccessor(_, func, _) =>
            if contains_super_call(func.body) {
              return true
            }
          ComputedPropertyAssignment(_, value, _) =>
            if contains_super_call(value) {
              return true
            }
          ComputedMethodDeclaration(_, func, _) =>
            if contains_super_call(func.body) {
              return true
            }
          ComputedGetAccessor(_, func, _) =>
            if contains_super_call(func.body) {
              return true
            }
          ComputedSetAccessor(_, func, _) =>
            if contains_super_call(func.body) {
              return true
            }
        }
      }
      false
    }
    // Array literal expressions
    ArrayLiteralExpression(ale) => {
      for elem in ale.elements {
        match elem {
          Some(e) => if contains_super_call(e) { return true }
          None => ()
        }
      }
      false
    }
    // Parenthesized expressions
    ParenthesizedExpression(pe) => contains_super_call(pe.expression)
    // Binary expressions
    BinaryExpression(be) =>
      contains_super_call(be.left) || contains_super_call(be.right)
    // Conditional expressions (ternary)
    ConditionalExpression(ce) =>
      contains_super_call(ce.condition) ||
      contains_super_call(ce.when_true) ||
      contains_super_call(ce.when_false)
    _ => false
  }
}

///|
/// Check for super() call requirement in derived class constructor (TS2377)
/// Also checks that super() is the first statement (TS2376) when class has
/// initialized properties, parameter properties, or private identifiers
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
  if not(contains_super_call(body)) {
    // Emit TS2377 error
    return add_diagnostic_with_code(
      checker,
      "Constructors for derived classes must contain a 'super' call.",
      location,
      TS2377,
    )
  }

  // Check if super() is the first statement (TS2376)
  // Only required when class has initialized properties, parameter properties,
  // or private identifiers (e.g., #privateField)
  if class_has_initialized_or_parameter_properties(class_decl) {
    check_super_is_first_statement(checker, body)
  } else {
    checker
  }
}

///|
/// Check if class has initialized properties, parameter properties,
/// or private identifiers that require super() to be the first statement
fn class_has_initialized_or_parameter_properties(
  class_decl : ClassDeclaration,
) -> Bool {
  for member in class_decl.members {
    match member {
      PropertyDeclaration(prop) => {
        // Check if property has an initializer
        match prop.initializer {
          Some(_) => return true
          None => ()
        }
        // Check for private identifier (starts with #)
        if prop.name.has_prefix("#") {
          return true
        }
      }
      MethodDeclaration(method) =>
        // Check for parameter properties in constructor
        if method.name == "constructor" {
          for param in method.parameters {
            match param {
              Parameter(p) =>
                // Parameter properties have accessibility modifiers (public, private, protected, readonly)
                for modifier in p.modifiers {
                  match modifier {
                    Public | Private | Protected | Readonly => return true
                    _ => ()
                  }
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
  }
  false
}

///|
/// Check that super() is the first statement in constructor (TS2376)
fn check_super_is_first_statement(
  checker : TypeChecker,
  body : Node,
) -> TypeChecker {
  match body {
    BlockStatement(block) => {
      // Find the first non-empty statement
      for i = 0; i < block.statements.length(); i = i + 1 {
        let stmt = block.statements[i]
        // Check if this statement is a super() call
        if is_super_call_statement(stmt) {
          // super() is the first statement, OK
          return checker
        }
        // If it's an empty statement or just a variable declaration without
        // side effects, we might be lenient, but TypeScript is strict:
        // any statement before super() is an error
        // Report TS2376 with the location of this statement
        return add_diagnostic_with_code(
          checker,
          "A 'super' call must be the first statement in the constructor when a class contains initialized properties, parameter properties, or private identifiers.",
          get_node_location(stmt),
          TS2376,
        )
      }
      // Empty constructor body - should have been caught by TS2377
      checker
    }
    _ => checker
  }
}

///|
/// Check if a statement is a super() call expression statement
fn is_super_call_statement(stmt : Node) -> Bool {
  match stmt {
    ExpressionStatement(expr_stmt) =>
      match expr_stmt.expression {
        CallExpression(call) =>
          match call.expression {
            SuperExpression(_) => true
            _ => false
          }
        _ => false
      }
    _ => false
  }
}

///|
/// TS2502: Check if class references itself in its own base expression
fn check_class_self_reference(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
) -> TypeChecker {
  let class_name = get_class_decl_name(class_decl)
  if class_name == "<anonymous>" {
    return checker // Anonymous classes can't self-reference by name
  }

  // Check heritage clauses for self-reference
  let mut checker = checker
  for clause in class_decl.heritage_clauses {
    if clause.kind == Extends {
      // Check each type expression in the extends clause
      for type_expr in clause.types {
        match type_expr {
          TypeReference(type_ref) =>
            if type_ref.type_name == class_name {
              checker = add_diagnostic_with_code(
                checker,
                "'\{class_name}' is referenced directly or indirectly in its own base expression.",
                clause.location,
                TS2502,
              )
            }
          Identifier(id) =>
            if id.name == class_name {
              checker = add_diagnostic_with_code(
                checker,
                "'\{class_name}' is referenced directly or indirectly in its own base expression.",
                clause.location,
                TS2502,
              )
            }
          // Handle property access like Namespace.ClassName
          PropertyAccessExpression(prop_access) => {
            let base_name = get_leftmost_identifier_name(
              PropertyAccessExpression(prop_access),
            )
            if base_name == class_name {
              checker = add_diagnostic_with_code(
                checker,
                "'\{class_name}' is referenced directly or indirectly in its own base expression.",
                clause.location,
                TS2502,
              )
            }
          }
          _ => ()
        }
      }
    }
  }
  checker
}

///|
/// Get the leftmost identifier name from a property access chain
fn get_leftmost_identifier_name(expr : Node) -> String {
  match expr {
    Identifier(id) => id.name
    PropertyAccessExpression(prop_access) =>
      get_leftmost_identifier_name(prop_access.expression)
    _ => ""
  }
}

///|
/// Check class declaration
fn check_class_declaration(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
) -> TypeChecker {
  // TS2502: Check if class references itself in its own base expression
  let checker = check_class_self_reference(checker, class_decl)

  // Check type parameter names for reserved keywords (TS2368)
  let checker = check_type_parameter_names(checker, class_decl.type_parameters)

  // Build the class type so we can set current_this_type
  let (class_type, checker) = build_class_type_for_this(checker, class_decl)

  // Save previous this type and context flags, set current_this_type to class type
  let prev_this_type = checker.current_this_type
  let prev_in_class_body = checker.in_class_body
  let prev_in_static_context = checker.in_static_context
  let prev_in_constructor = checker.in_constructor
  let prev_in_derived_class = checker.in_derived_class
  let prev_in_extends_null_class = checker.in_extends_null_class
  // Check if this is a derived class (has extends clause)
  let is_derived = is_derived_class(class_decl)
  let is_extends_null = extends_null(class_decl)
  let mut checker = {
    ..checker,
    current_this_type: Some(class_type),
    in_class_body: true,
    in_derived_class: is_derived,
    in_extends_null_class: is_extends_null,
  }

  // Collect uninitialized properties for definite assignment checking
  let uninitialized_props : Map[String, SourceLocation] = Map::new()
  for mem in class_decl.members {
    match mem {
      PropertyDeclaration(prop) =>
        if prop.initializer is None {
          // Property without initializer - needs to be assigned in constructor
          uninitialized_props.set(prop.name, prop.location)
        }
      _ => ()
    }
  }

  // For TS2729: Track properties not yet initialized (includes later properties with initializers)
  // A property initializer cannot reference properties that appear later in the class
  let not_yet_initialized : Map[String, Bool] = Map::new()
  for mem in class_decl.members {
    match mem {
      PropertyDeclaration(prop) =>
        if not(has_modifier(prop.modifiers, Modifier::Static)) {
          // Add all non-static properties - we'll remove them as we process them
          not_yet_initialized.set(prop.name, true)
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
            // Set in_constructor flag and track super call status for TS2337/TS17009
            let checker = {
              ..checker,
              in_constructor: true,
              super_called: false,
            }
            // Add constructor parameters to scope
            let mut checker = checker
            for param in ctor.parameters {
              checker = add_parameter_to_scope(checker, param)
            }
            // Hoist var declarations to the constructor scope before checking body
            // This ensures var declarations are visible even before their declaration
            let checker = hoist_var_declarations(checker, body)
            // Check for property use before assignment (TS2565)
            // Note: This check is only enabled when strictPropertyInitialization is true
            // Since we don't have that compiler flag yet, we skip this check for now
            // TODO: Re-enable when strictPropertyInitialization flag is implemented
            let checker = checker
            let checker = check_statement(checker, body)
            // Check for super() call in derived class constructor (TS2377)
            let checker = check_super_call_in_constructor(
              checker,
              class_decl,
              body,
              ctor.location,
            )
            // Restore in_constructor flag
            let checker = { ..checker, in_constructor: false }
            // Pop local scope
            pop_local_scope(checker)
          }
          None => checker
        }
      MethodDeclaration(method_dec) => {
        // Check for TS1221: Generators are not allowed in an ambient context
        // A method is ambient if the class has 'declare' modifier or the method has no body
        let class_is_ambient = is_ambient_declaration(class_decl.modifiers)
        let method_is_ambient = class_is_ambient || method_dec.body is None
        let checker = if method_dec.is_generator && method_is_ambient {
          add_diagnostic_with_code(
            checker,
            "Generators are not allowed in an ambient context.",
            method_dec.location,
            TS1221,
          )
        } else {
          checker
        }
        match method_dec.body {
          Some(body) => {
            // Push local scope for method
            let checker = push_local_scope(checker)
            // Check for TS2369: parameter property only in constructor
            let checker = check_method_parameter_properties(
              checker,
              method_dec.parameters,
            )
            // Track async function context for TS2465
            let checker = if method_dec.is_async {
              enter_async_function(checker)
            } else {
              checker
            }
            // Track generator function context for yield expressions
            let (checker, saved_yield_types) = if method_dec.is_generator {
              let has_return_type = method_dec.return_type is Some(_)
              enter_generator_function(checker, has_return_type)
            } else {
              (checker, [])
            }
            // Add method parameters to scope
            let mut checker = checker
            for param in method_dec.parameters {
              checker = add_parameter_to_scope(checker, param)
            }
            // Hoist var declarations to the method scope before checking body
            let checker = hoist_var_declarations(checker, body)
            let checker = check_statement(checker, body)
            // Exit generator function context if needed
            let (checker, _collected_yield_types) = if method_dec.is_generator {
              exit_generator_function(checker, saved_yield_types)
            } else {
              (checker, [])
            }
            // Exit async function context if needed
            let checker = if method_dec.is_async {
              exit_async_function(checker)
            } else {
              checker
            }
            // Pop local scope
            pop_local_scope(checker)
          }
          None =>
            // Also check method signatures without body for TS2369
            check_method_parameter_properties(checker, method_dec.parameters)
        }
      }
      PropertyDeclaration(prop) => {
        // Check if this is a static property for TS2334
        let is_static = has_modifier(prop.modifiers, Modifier::Static)
        match prop.initializer {
          Some(init) => {
            let checker = if is_static {
              { ..checker, in_static_context: true }
            } else {
              checker
            }
            // Check for TS2729: property forward reference (only for non-static properties)
            let checker = if not(is_static) {
              check_property_forward_reference(
                checker, init, not_yet_initialized,
              )
            } else {
              checker
            }
            // TS1163: yield is not allowed in class property initializers
            // Save and reset generator context - class property initializers are not
            // inside the generator body even if the class is inside a generator function
            let saved_generator_depth = checker.generator_function_depth
            let checker = {
              ..checker,
              generator_function_depth: 0,
              generator_has_return_type: false,
            }
            let (_, c) = infer_type(checker, init)
            // Restore generator context
            let c = { ..c, generator_function_depth: saved_generator_depth }
            // Restore in_static_context flag and mark property as initialized
            let c = if is_static {
              { ..c, in_static_context: false }
            } else {
              c
            }
            // Remove from not_yet_initialized after processing (for TS2729)
            if not(is_static) {
              not_yet_initialized.remove(prop.name)
            }
            c
          }
          None => {
            // Property without initializer - still remove from not_yet_initialized
            // (it's in uninitialized_props for TS2565 checking in constructor)
            if not(is_static) {
              not_yet_initialized.remove(prop.name)
            }
            checker
          }
        }
      }
      _ => checker
    }
  }

  // Check for abstract members in non-abstract class (TS2516)
  let checker = check_abstract_members_in_non_abstract_class(
    checker, class_decl,
  )

  // Check for constructor overloads (TS2390)
  let class_name = get_class_decl_name(class_decl)
  let checker = check_class_constructor_overloads(
    class_name,
    class_decl.members,
    checker,
  )

  // Check for method overloads static consistency (TS2388)
  let class_is_ambient = is_ambient_declaration(class_decl.modifiers)
  let checker = check_class_method_overloads(
    class_decl.members,
    class_is_ambient,
    checker,
  )

  // Restore previous context flags
  {
    ..checker,
    current_this_type: prev_this_type,
    in_class_body: prev_in_class_body,
    in_static_context: prev_in_static_context,
    in_constructor: prev_in_constructor,
    in_derived_class: prev_in_derived_class,
    in_extends_null_class: prev_in_extends_null_class,
  }
}

///|
/// Check that abstract members only appear in abstract classes (TS2516)
fn check_abstract_members_in_non_abstract_class(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
) -> TypeChecker {
  // If class is abstract, abstract members are allowed
  if class_decl.is_abstract {
    return checker
  }
  let mut checker = checker
  for mem in class_decl.members {
    match mem {
      MethodDeclaration(meth) =>
        if is_abstract_modifier(meth.modifiers) {
          checker = add_diagnostic_with_code(
            checker,
            "Abstract methods can only appear within an abstract class.",
            meth.location,
            TS2516,
          )
        }
      PropertyDeclaration(prop) =>
        if is_abstract_modifier(prop.modifiers) {
          checker = add_diagnostic_with_code(
            checker,
            "Abstract methods can only appear within an abstract class.",
            prop.location,
            TS2516,
          )
        }
      _ => ()
    }
  }

  // Check that non-abstract class implements all abstract members from base class (TS2515)
  checker = check_abstract_member_implementation(checker, class_decl)
  checker
}

///|
/// Check that non-abstract class implements all abstract members from base class (TS2515)
fn check_abstract_member_implementation(
  checker : TypeChecker,
  class_decl : ClassDeclaration,
) -> TypeChecker {
  // Only check non-abstract classes that extend another class
  if class_decl.is_abstract {
    return checker
  }
  let mut checker = checker

  // Get the base class from extends clause
  for heritage_clause in class_decl.heritage_clauses {
    if heritage_clause.kind == Extends {
      for type_node in heritage_clause.types {
        match type_node {
          TypeReference(type_ref) =>
            // Look up the base class by name
            match lookup_symbol(checker, type_ref.type_name) {
              Some(base_symbol) => {
                // Get abstract members from base class
                let abstract_members = get_abstract_members_from_symbol(
                  base_symbol,
                )

                // Get implemented members in the derived class
                let implemented_members = get_class_member_names(class_decl)

                // Check each abstract member is implemented
                for abstract_member in abstract_members {
                  if not(implemented_members.contains(abstract_member.0)) {
                    checker = add_diagnostic_with_code(
                      checker,
                      "Non-abstract class '\{get_class_decl_name(class_decl)}' does not implement inherited abstract member '\{abstract_member.0}' from class '\{type_ref.type_name}'.",
                      class_decl.location,
                      TS2515,
                    )
                  }
                }
              }
              None => ()
            }
          _ => ()
        }
      }
    }
  }
  checker
}

///|
/// Get the class name from a class declaration for diagnostics
fn get_class_decl_name(class_decl : ClassDeclaration) -> String {
  match class_decl.name {
    Some(Identifier(ident)) => ident.name
    _ => "<anonymous>"
  }
}

///|
/// Get names of all members in a class
fn get_class_member_names(class_decl : ClassDeclaration) -> Array[String] {
  let names : Array[String] = []
  for mem in class_decl.members {
    match mem {
      MethodDeclaration(meth) => names.push(meth.name)
      PropertyDeclaration(prop) => names.push(prop.name)
      _ => ()
    }
  }
  names
}

///|
/// Get abstract members from a symbol (returns array of (name, location) pairs)
fn get_abstract_members_from_symbol(
  symbol : Symbol,
) -> Array[(String, SourceLocation)] {
  let abstract_members : Array[(String, SourceLocation)] = []
  for decl in symbol.declarations {
    match decl {
      ClassDeclaration(class_decl) =>
        for mem in class_decl.members {
          match mem {
            MethodDeclaration(meth) =>
              if is_abstract_modifier(meth.modifiers) {
                abstract_members.push((meth.name, meth.location))
              }
            PropertyDeclaration(prop) =>
              if is_abstract_modifier(prop.modifiers) {
                abstract_members.push((prop.name, prop.location))
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  abstract_members
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
  check_this_property_accesses(
    checker, body, uninitialized_props, assigned_props,
  )
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
        ThisExpression(_) =>
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
          checker, arg, uninitialized_props, assigned_props,
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
          checker, stmt, uninitialized_props, assigned_props,
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
              checker, init, uninitialized_props, assigned_props,
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
            checker, expr, uninitialized_props, assigned_props,
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
            checker, else_stmt, uninitialized_props, assigned_props,
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
  // Check type parameter names for reserved keywords (TS2368)
  let checker = check_type_parameter_names(checker, iface_decl.type_parameters)
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
    Some(idx_ret_type) =>
      for interface_member in iface_decl.members {
        match interface_member {
          PropertyDeclaration(prop) => {
            // Skip computed properties (Symbol properties) - they are not subject to index signature constraints
            // Symbol properties like [Symbol.iterator] are in a separate namespace from string/number properties
            if prop.name == "[computed]" {
              continue
            }
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
            let is_compatible = is_simple_type_compatible(
              prop_type, idx_ret_type,
            )
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
    None => ()
  }
  // TS2771: Check for circular reference in Promise-like interface's then method
  checker = check_promise_then_circular_reference(
    checker,
    iface_decl.name,
    iface_decl.members,
    iface_decl.location,
  )
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
          Some(name) =>
            // Look up the interface symbol
            match lookup_symbol(checker, name) {
              Some(symbol) => {
                // Resolve the interface type
                let (base_type_opt, c) = resolve_interface_type(checker, symbol)
                checker = c
                match base_type_opt {
                  Some(Object(obj_type)) =>
                    // Check each property against already collected properties
                    for prop_entry in obj_type.properties {
                      let (prop_name, prop_sig) = prop_entry
                      match base_properties.get(prop_name) {
                        Some((existing_type, existing_source)) =>
                          // Check if types are compatible
                          if not(
                              is_simple_type_compatible(
                                prop_sig.prop_type,
                                existing_type,
                              ),
                            ) &&
                            not(
                              is_simple_type_compatible(
                                existing_type,
                                prop_sig.prop_type,
                              ),
                            ) {
                            checker = add_diagnostic_with_code(
                              checker,
                              "Property '\{prop_name}' has conflicting declarations and is inaccessible in type '\{iface_decl.name}' (from '\{existing_source}' and '\{name}')",
                              iface_decl.location,
                              TS2746,
                            )
                          }
                        None =>
                          // First time seeing this property
                          base_properties.set(
                            prop_name,
                            (prop_sig.prop_type, name),
                          )
                      }
                    }
                  _ => ()
                }
              }
              None => ()
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
/// and TS2368 (type parameter name cannot be reserved)
fn check_type_alias_declaration(
  checker : TypeChecker,
  type_alias : TypeAliasDeclaration,
) -> TypeChecker {
  // Check type parameter names for reserved keywords (TS2368)
  let checker = check_type_parameter_names(checker, type_alias.type_parameters)
  // Validate the type node (checks type argument counts, etc.)
  let (_, checker) = get_type_from_type_node(checker, type_alias.type_node)
  check_type_node_for_rest_errors(checker, type_alias.type_node)
}

///|
/// Recursively check type nodes for rest/spread type errors
fn check_type_node_for_rest_errors(
  checker : TypeChecker,
  node : Node,
) -> TypeChecker {
  match node {
    TypeLiteral(tl) => {
      let mut checker = checker
      for type_member in tl.members {
        match type_member {
          SpreadExpression(spread_expr) => {
            // Check if spread target is an object type
            let (spread_type, c) = get_type_from_type_node(
              checker,
              spread_expr.expression,
            )
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
    TupleType(tt) => {
      // Check for TS2574: rest element type must be array type
      let mut checker = checker
      for elem in tt.element_types {
        match elem {
          RestType(rt) =>
            // Check if the rest element type is an array type
            match rt.element_type {
              ArrayType(_) => () // Valid: ...number[]
              _ =>
                checker = add_diagnostic_with_code(
                  checker,
                  "A rest element type must be an array type.",
                  rt.location,
                  TS2574,
                )
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
  // TS2431: Check for reserved type names used as enum names
  let checker = check_enum_reserved_name(checker, enum_decl)

  // Push a local scope for enum members so they can reference each other
  let checker = push_local_scope(checker)

  // For enum merging: add members from previous declarations to the local scope
  // This allows later enum declarations to reference members from earlier ones
  let checker = add_previous_enum_members_to_scope(checker, enum_decl.name)

  // Check TS2432: In an enum with multiple declarations, only one declaration can omit
  // an initializer for its first enum element
  let checker = check_enum_merging_first_initializer(checker, enum_decl)

  // Save and reset async/generator context for enum body
  // Enum initializers are evaluated in a static context, not the function's dynamic context
  // This ensures await/yield in enum initializers will trigger TS1308/TS1163 errors
  let saved_async_depth = checker.async_function_depth
  let saved_generator_depth = checker.generator_function_depth
  let checker = {
    ..checker,
    async_function_depth: 0,
    generator_function_depth: 0,
  }

  // Collect all enum member names for forward reference checking
  let all_member_names : Map[String, Bool] = Map::new()
  for mem in enum_decl.members {
    all_member_names.set(mem.name, true)
  }
  // Track seen members as we process them
  let seen_members : Map[String, Bool] = Map::new()
  let checker = check_enum_members_with_forward_check(
    checker,
    enum_decl.members,
    enum_decl.is_const,
    0,
    seen_members,
    all_member_names,
    enum_decl.name,
  )

  // Restore async/generator context
  let checker = {
    ..checker,
    async_function_depth: saved_async_depth,
    generator_function_depth: saved_generator_depth,
  }

  // Pop the local scope
  pop_local_scope(checker)
}

///|
/// Check TS2431: Enum name cannot be a reserved type name
fn check_enum_reserved_name(
  checker : TypeChecker,
  enum_decl : EnumDeclaration,
) -> TypeChecker {
  // List of reserved type names that cannot be used as enum names
  let reserved_names = [
    "any", "number", "string", "boolean", "symbol", "never", "unknown", "object",
    "undefined",
  ]
  for reserved in reserved_names {
    if enum_decl.name == reserved {
      return add_diagnostic_with_code(
        checker,
        "Enum name cannot be '\{reserved}'.",
        enum_decl.name_location,
        TS2431,
      )
    }
  }
  checker
}

///|
/// Check TS2432: In an enum with multiple declarations, only one declaration can omit
/// an initializer for its first enum element.
fn check_enum_merging_first_initializer(
  checker : TypeChecker,
  enum_decl : EnumDeclaration,
) -> TypeChecker {
  // If this enum declaration has no members or its first member has an initializer, no error
  if enum_decl.members.length() == 0 {
    return checker
  }
  let first_member = enum_decl.members[0]
  match first_member.initializer {
    Some(_) => checker // This declaration has an initializer, no error
    None =>
      // This declaration omits the initializer for first element
      // Check if there are other declarations that also omit it
      // Use lookup_symbol which checks namespace_symbols first, then global scope
      match lookup_symbol(checker, enum_decl.name) {
        Some(enum_symbol) => {
          // Check if any EARLIER declaration (before this one in source order) already omits the first initializer
          // TypeScript reports TS2432 only on declarations that come after another declaration
          // that already omitted an initializer
          let mut earlier_omits_initializer = false
          for decl in enum_symbol.declarations {
            match decl {
              EnumDeclaration(prev_enum) =>
                // Only consider declarations that come BEFORE the current one
                // (their start offset is less than ours)
                if prev_enum.location.start.offset <
                  enum_decl.location.start.offset &&
                  prev_enum.members.length() > 0 {
                  match prev_enum.members[0].initializer {
                    None => {
                      earlier_omits_initializer = true
                      break
                    }
                    Some(_) => ()
                  }
                }
              _ => ()
            }
          }
          // If an earlier declaration also omits the first initializer, error on this one
          if earlier_omits_initializer {
            add_diagnostic_with_code(
              checker,
              "In an enum with multiple declarations, only one declaration can omit an initializer for its first enum element.",
              first_member.location,
              TS2432,
            )
          } else {
            checker
          }
        }
        None => checker
      }
  }
}

///|
/// Add members from previous enum declarations to the local scope (for enum merging)
fn add_previous_enum_members_to_scope(
  checker : TypeChecker,
  enum_name : String,
) -> TypeChecker {
  match lookup_symbol(checker, enum_name) {
    Some(enum_symbol) => {
      // Iterate through all declarations of this enum
      let mut checker = checker
      for decl in enum_symbol.declarations {
        match decl {
          EnumDeclaration(prev_enum) =>
            // Add each member from previous declarations
            for mem in prev_enum.members {
              let member_type = Type::Number(default_type_info())
              checker = add_local_variable(checker, mem.name, member_type)
            }
          _ => ()
        }
      }
      checker
    }
    None => checker
  }
}

///|
/// Check enum members with forward reference checking
/// Validates that enum member initializers don't reference members defined later
fn check_enum_members_with_forward_check(
  checker : TypeChecker,
  members : Array[EnumMember],
  is_const : Bool,
  index : Int,
  seen_members : Map[String, Bool],
  all_member_names : Map[String, Bool],
  enum_name : String,
) -> TypeChecker {
  if index >= members.length() {
    checker
  } else {
    let e_member = members[index]
    // Check for forward references in the initializer
    let checker = match e_member.initializer {
      Some(init) =>
        check_enum_initializer_forward_reference(
          checker,
          init,
          seen_members,
          all_member_names,
          e_member.location,
        )
      None => checker
    }
    // Mark this member as seen
    seen_members.set(e_member.name, true)

    // Add this member to the local scope so it can be referenced by subsequent members
    // The type is number (enum members are numeric in TypeScript)
    let member_type = Type::Number(default_type_info())
    let checker = add_local_variable(checker, e_member.name, member_type)

    // Check the member itself
    let checker = check_enum_member(checker, e_member, is_const)
    check_enum_members_with_forward_check(
      checker,
      members,
      is_const,
      index + 1,
      seen_members,
      all_member_names,
      enum_name,
    )
  }
}

///|
/// Check if an enum initializer references a forward-declared member (TS2651)
fn check_enum_initializer_forward_reference(
  checker : TypeChecker,
  expr : Node,
  seen_members : Map[String, Bool],
  all_member_names : Map[String, Bool],
  location : SourceLocation,
) -> TypeChecker {
  match expr {
    Identifier(id) =>
      // If the identifier is an enum member that hasn't been seen yet, it's a forward reference
      if all_member_names.contains(id.name) &&
        not(seen_members.contains(id.name)) {
        add_diagnostic_with_code(
          checker,
          "Enum member '\{id.name}' cannot be accessed before it is defined.",
          location,
          TS2651,
        )
      } else {
        checker
      }
    PropertyAccessExpression(prop_access) =>
      // Check if accessing a forward-declared member like MyEnum.ForwardMember
      if all_member_names.contains(prop_access.name) &&
        not(seen_members.contains(prop_access.name)) {
        add_diagnostic_with_code(
          checker,
          "Enum member '\{prop_access.name}' cannot be accessed before it is defined.",
          location,
          TS2651,
        )
      } else {
        checker
      }
    BinaryExpression(bin) => {
      // Check both sides of binary expressions
      let checker = check_enum_initializer_forward_reference(
        checker,
        bin.left,
        seen_members,
        all_member_names,
        location,
      )
      check_enum_initializer_forward_reference(
        checker,
        bin.right,
        seen_members,
        all_member_names,
        location,
      )
    }
    UnaryExpression(un) =>
      check_enum_initializer_forward_reference(
        checker,
        un.operand,
        seen_members,
        all_member_names,
        location,
      )
    ParenthesizedExpression(paren) =>
      check_enum_initializer_forward_reference(
        checker,
        paren.expression,
        seen_members,
        all_member_names,
        location,
      )
    _ => checker
  }
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
  enum_mem : EnumMember,
  is_const : Bool,
) -> TypeChecker {
  match enum_mem.initializer {
    Some(init) => {
      // Infer the type of the initializer
      let (init_type, checker) = infer_type(checker, init)
      // Validate the initializer type - use the initializer's location for error reporting
      validate_enum_initializer(
        checker,
        init_type,
        init,
        get_node_location(init),
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
        // Check for non-finite values (TS2477) and NaN (TS2478)
        match evaluate_const_enum_value(init) {
          Some(ConstEnumValue::InfinityValue) =>
            add_diagnostic_with_code(
              checker,
              "'const' enum member initializer was evaluated to a non-finite value.",
              location,
              TS2477,
            )
          Some(ConstEnumValue::NaNValue) =>
            add_diagnostic_with_code(
              checker,
              "'const' enum member initializer was evaluated to disallowed value 'NaN'.",
              location,
              TS2478,
            )
          _ => checker
        }
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
    // TS18033: Type 'X' is not assignable to type 'number' as required for computed enum member values
    // This is for computed values (non-const) that aren't numbers
    // Note: String literals are allowed for const string enums, but computed values must be numbers
    add_diagnostic_with_code(
      checker,
      "Type '\{type_to_string(init_type)}' is not assignable to type 'number' as required for computed enum member values.",
      location,
      TS18033,
    )
  }
}

///|
/// Result of evaluating a const enum initializer
enum ConstEnumValue {
  FiniteValue(Double)
  InfinityValue
  NaNValue
}

///|
/// Evaluate a const enum initializer to detect Infinity/NaN
fn evaluate_const_enum_value(expr : Node) -> ConstEnumValue? {
  match expr {
    NumericLiteral(lit) => {
      // Parse the string value to a double
      let v = @strconv.parse_double(lit.value) catch { _ => 0.0 }
      Some(ConstEnumValue::FiniteValue(v))
    }
    Identifier(id) =>
      // Check for special identifiers like NaN and Infinity
      if id.name == "NaN" {
        Some(ConstEnumValue::NaNValue)
      } else if id.name == "Infinity" {
        Some(ConstEnumValue::InfinityValue)
      } else {
        // Other identifiers (enum members) - assume finite
        None
      }
    UnaryExpression(un) =>
      match un.operator {
        UnaryOperator::Minus =>
          match evaluate_const_enum_value(un.operand) {
            Some(ConstEnumValue::FiniteValue(v)) =>
              Some(ConstEnumValue::FiniteValue(-v))
            Some(ConstEnumValue::InfinityValue) =>
              Some(ConstEnumValue::InfinityValue)
            Some(ConstEnumValue::NaNValue) => Some(ConstEnumValue::NaNValue)
            None => None
          }
        UnaryOperator::Plus => evaluate_const_enum_value(un.operand)
        _ => None
      }
    BinaryExpression(bin) => {
      let left = evaluate_const_enum_value(bin.left)
      let right = evaluate_const_enum_value(bin.right)
      match (left, right) {
        (
          Some(ConstEnumValue::FiniteValue(l)),
          Some(ConstEnumValue::FiniteValue(r)),
        ) =>
          match bin.operator {
            BinaryOperator::Divide =>
              // Division - check for Infinity or NaN
              if r == 0.0 {
                if l == 0.0 {
                  Some(ConstEnumValue::NaNValue) // 0/0 = NaN
                } else {
                  Some(ConstEnumValue::InfinityValue) // n/0 = Infinity
                }
              } else {
                Some(ConstEnumValue::FiniteValue(l / r))
              }
            BinaryOperator::Add => Some(ConstEnumValue::FiniteValue(l + r))
            BinaryOperator::Subtract => Some(ConstEnumValue::FiniteValue(l - r))
            BinaryOperator::Multiply => Some(ConstEnumValue::FiniteValue(l * r))
            _ => None
          }
        (Some(ConstEnumValue::InfinityValue), _) =>
          Some(ConstEnumValue::InfinityValue)
        (_, Some(ConstEnumValue::InfinityValue)) =>
          Some(ConstEnumValue::InfinityValue)
        (Some(ConstEnumValue::NaNValue), _) => Some(ConstEnumValue::NaNValue)
        (_, Some(ConstEnumValue::NaNValue)) => Some(ConstEnumValue::NaNValue)
        _ => None
      }
    }
    ParenthesizedExpression(paren) =>
      evaluate_const_enum_value(paren.expression)
    _ => None
  }
}

///|
/// Check if a type is valid for an enum initializer
/// Valid types are: number, string, or literal types (including template literals)
fn is_valid_enum_initializer_type(t : Type) -> Bool {
  match t {
    Number(_) => true
    String(_) => true
    NumberLiteral(_) => true
    StringLiteral(_) => true
    TemplateLiteral(_) => true // Template literals like `1` are valid string enum initializers
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
    TemplateExpression(_) => true // Template literals like `1` or `${x}` are valid
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
/// Check import declaration for TS2691 (import path cannot end with extension)
fn check_import_declaration(
  checker : TypeChecker,
  import_decl : ImportDeclaration,
) -> TypeChecker {
  let module_spec = import_decl.module_specifier

  // Check for .d.ts files first - TS2591: Cannot import type declaration files
  if module_spec.has_suffix(".d.ts") {
    let suggested_path = remove_extension(module_spec)
    return add_diagnostic_with_code(
      checker,
      "Cannot import type declaration files. Consider importing '\{suggested_path}' instead.",
      import_decl.location,
      TS2591,
    )
  }

  // TS2691: An import path cannot end with a '.ts', '.tsx', '.js', or '.jsx' extension
  // Check for prohibited extensions
  let has_prohibited_extension = module_spec.has_suffix(".ts") ||
    module_spec.has_suffix(".tsx") ||
    module_spec.has_suffix(".js") ||
    module_spec.has_suffix(".jsx")
  if has_prohibited_extension {
    // Determine which extension was used
    let ext = if module_spec.has_suffix(".tsx") {
      ".tsx"
    } else if module_spec.has_suffix(".ts") {
      ".ts"
    } else if module_spec.has_suffix(".jsx") {
      ".jsx"
    } else {
      ".js"
    }
    add_diagnostic_with_code(
      checker,
      "An import path cannot end with a '\{ext}' extension. Consider importing '\{remove_extension(module_spec)}' instead.",
      import_decl.location,
      TS2691,
    )
  } else {
    checker
  }
}

///|
/// Module export information for cross-file validation
pub struct ResolvedModuleExports {
  /// File path of the module
  file_path : String
  /// Whether this file is a module (has imports/exports)
  is_module : Bool
  /// Whether this module has a default export
  has_default_export : Bool
  /// Set of exported names
  exports : @hashset.HashSet[String]
} derive(Show)

///|
/// Validate import against resolved module exports
/// This checks for TS2307 (module not found), TS2305 (no exported member),
/// TS2306 (not a module), TS1192 (no default export)
pub fn validate_import_resolution(
  import_decl : ImportDeclaration,
  module_registry : Map[String, ResolvedModuleExports],
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  let module_spec = import_decl.module_specifier

  // Check if module exists in registry
  match module_registry.get(module_spec) {
    None =>
      // TS2307: Cannot find module
      diagnostics.push(
        create_module_not_found_diagnostic_with_location(
          module_spec,
          import_decl.location,
        ),
      )
    Some(module_exports) =>
      // Check if the file is a module (has exports)
      if not(module_exports.is_module) {
        // TS2306: File is not a module
        diagnostics.push(
          create_file_not_module_diagnostic(module_spec, import_decl.location),
        )
      } else {
        // Validate import clause
        match import_decl.import_clause {
          Some(clause) => {
            // Check default import
            match clause.name {
              Some(_default_name) =>
                if not(module_exports.has_default_export) {
                  // TS1192: Module has no default export
                  diagnostics.push(
                    create_no_default_export_diagnostic_with_location(
                      module_spec,
                      import_decl.location,
                    ),
                  )
                }
              None => ()
            }

            // Check named bindings
            match clause.named_bindings {
              Some(NamedImports(specifiers, _)) =>
                for specifier in specifiers {
                  let import_name = match specifier.property_name {
                    Some(prop) => prop
                    None => specifier.name
                  }
                  if not(module_exports.exports.contains(import_name)) {
                    // TS2305: Module has no exported member
                    diagnostics.push(
                      create_export_not_found_diagnostic_with_location(
                        import_name,
                        module_spec,
                        specifier.location,
                      ),
                    )
                  }
                }
              Some(NamespaceImport(_, _)) =>
                // Namespace import is always valid if the module exists
                ()
              None => ()
            }
          }
          None =>
            // Side-effect import (import 'module') - always valid if module exists
            ()
        }
      }
  }
  diagnostics
}

///|
/// Create module exports from a bound source file
pub fn ResolvedModuleExports::from_bound_file(
  bound_file : BoundSourceFile,
  file_path : String,
) -> ResolvedModuleExports {
  let exports : @hashset.HashSet[String] = @hashset.new()
  let mut has_default = false
  let mut is_module = false

  // Check for imports/exports to determine if it's a module
  for statement in bound_file.statements {
    match statement {
      ImportDeclaration(_) | ImportEqualsDeclaration(_) => is_module = true
      ExportDeclaration(ed) => {
        is_module = true
        match ed.export_clause {
          Some(NamedExports(specifiers, _)) =>
            for spec in specifiers {
              // ExportSpecifier: name is String, property_name is String?
              // export { foo } -> name = "foo", property_name = None
              // export { foo as bar } -> name = "bar", property_name = Some("foo")
              // The exported name is always `name`
              exports.add(spec.name)
            }
          Some(NamespaceExport(name, _)) => exports.add(name)
          None => () // export * from 'mod'
        }
      }
      ExportAssignment(_) => {
        is_module = true
        // Both export = and export default create a default export
        has_default = true
      }
      FunctionDeclaration(fd) =>
        if has_export_modifier_in_list(fd.modifiers) {
          is_module = true
          if has_default_modifier_in_list(fd.modifiers) {
            has_default = true
          } else {
            // fd.name is Node? - extract name from Identifier
            match fd.name {
              Some(Identifier(id)) => exports.add(id.name)
              _ => ()
            }
          }
        }
      ClassDeclaration(cd) =>
        if has_export_modifier_in_list(cd.modifiers) {
          is_module = true
          if has_default_modifier_in_list(cd.modifiers) {
            has_default = true
          } else {
            // cd.name is Node? - extract name from Identifier
            match cd.name {
              Some(Identifier(id)) => exports.add(id.name)
              _ => ()
            }
          }
        }
      VariableStatement(vs) =>
        if has_export_modifier_in_list(vs.modifiers) {
          is_module = true
          for decl in vs.declarations {
            match decl.name {
              Identifier(id) => exports.add(id.name)
              _ => ()
            }
          }
        }
      InterfaceDeclaration(iface) =>
        if has_export_modifier_in_list(iface.modifiers) {
          is_module = true
          exports.add(iface.name)
        }
      TypeAliasDeclaration(td) =>
        if has_export_modifier_in_list(td.modifiers) {
          is_module = true
          exports.add(td.name)
        }
      EnumDeclaration(ed) =>
        if has_export_modifier_in_list(ed.modifiers) {
          is_module = true
          exports.add(ed.name)
        }
      _ => ()
    }
  }
  { file_path, is_module, has_default_export: has_default, exports }
}

///|
/// Check if modifiers contain export keyword
fn has_export_modifier_in_list(modifiers : Array[Modifier]) -> Bool {
  for modifier in modifiers {
    match modifier {
      Export => return true
      _ => ()
    }
  }
  false
}

///|
/// Check if modifiers contain default keyword
fn has_default_modifier_in_list(modifiers : Array[Modifier]) -> Bool {
  for modifier in modifiers {
    match modifier {
      Default => return true
      _ => ()
    }
  }
  false
}

///|
/// Remove file extension from a module path for TS2691 suggestion
fn remove_extension(path : String) -> String {
  if path.has_suffix(".d.ts") {
    @utils.substr(path, end=path.length() - 5)
  } else if path.has_suffix(".tsx") {
    @utils.substr(path, end=path.length() - 4)
  } else if path.has_suffix(".jsx") {
    @utils.substr(path, end=path.length() - 4)
  } else if path.has_suffix(".ts") {
    @utils.substr(path, end=path.length() - 3)
  } else if path.has_suffix(".js") {
    @utils.substr(path, end=path.length() - 3)
  } else {
    path
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
        Some(type_node) =>
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
                let _var_name = match catch_clause.variable_declaration {
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
        None =>
          // No type annotation - default to 'any'
          any_type(checker)
      }

      // Add the catch clause variable to scope if present
      // Handles Identifier, ArrayBindingPattern, and ObjectBindingPattern
      let checker = match catch_clause.variable_declaration {
        Some(var_decl) =>
          add_binding_pattern_variables(checker, var_decl, catch_type)
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
  // Infer the type of the switch expression
  let (switch_type, checker) = infer_type(checker, switch_stmt.expression)
  let mut checker = checker
  for i = 0; i < switch_stmt.cases.length(); i = i + 1 {
    let case_clause = switch_stmt.cases[i]
    match case_clause.expression {
      Some(case_expr) => {
        let (case_type, c) = infer_type(checker, case_expr)
        checker = c

        // TS2678: Check if case type is comparable to switch expression type
        if not(types_have_overlap(case_type, switch_type)) {
          checker = add_diagnostic_with_code(
            checker,
            "Type '\{type_to_string(case_type)}' is not comparable to type '\{type_to_string(switch_type)}'.",
            get_node_location(case_expr),
            TS2678,
          )
        }
        checker = check_statements(checker, case_clause.statements)
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
/// Check if a parameter has a parameter property modifier (public, private, protected, readonly)
/// These are only valid in constructors (TS2369)
fn has_parameter_property_modifier(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    match m {
      Public | Private | Protected | Readonly => return true
      _ => continue
    }
  }
  false
}

///|
/// Check method parameters for TS2369 (parameter property only in constructor)
fn check_method_parameter_properties(
  checker : TypeChecker,
  parameters : Array[Node],
) -> TypeChecker {
  let mut checker = checker
  for param_node in parameters {
    match param_node {
      Parameter(p) =>
        if has_parameter_property_modifier(p.modifiers) {
          checker = add_diagnostic_with_code(
            checker,
            "A parameter property is only allowed in a constructor implementation.",
            p.location,
            DiagnosticCode::TS2369,
          )
        }
      _ => ()
    }
  }
  checker
}

///|
/// Check parameters in ambient context for TS2371 (parameter initializer not allowed)
fn check_ambient_parameter_initializers(
  checker : TypeChecker,
  parameters : Array[Node],
) -> TypeChecker {
  let mut checker = checker
  for param_node in parameters {
    match param_node {
      Parameter(p) =>
        if p.initializer is Some(_) {
          checker = add_diagnostic_with_code(
            checker,
            "A parameter initializer is only allowed in a function or constructor implementation.",
            p.location,
            DiagnosticCode::TS2371,
          )
        }
      _ => ()
    }
  }
  checker
}

///|
/// Check if an expression has side effects (for TS2695 comma operator check)
fn expression_has_side_effects(expr : Node) -> Bool {
  match expr {
    // Call expressions have side effects
    CallExpression(_) => true
    // New expressions have side effects
    NewExpression(_) => true
    // Assignment expressions have side effects
    BinaryExpression(bin) =>
      match bin.operator {
        Assign
        | AddAssign
        | SubtractAssign
        | MultiplyAssign
        | DivideAssign
        | RemainderAssign
        | BitwiseAndAssign
        | BitwiseOrAssign
        | BitwiseXorAssign
        | ExponentiateAssign
        | LeftShiftAssign
        | RightShiftAssign
        | UnsignedRightShiftAssign
        | LogicalAndAssign
        | LogicalOrAssign
        | NullishCoalescingAssign => true
        // Comma operator on the left - check if either part has side effects
        Comma =>
          expression_has_side_effects(bin.left) ||
          expression_has_side_effects(bin.right)
        _ => false
      }
    // Increment/decrement have side effects
    UnaryExpression(un) =>
      match un.operator {
        Increment | Decrement => true
        _ => false
      }
    // Await has side effects (async operation)
    AwaitExpression(_) => true
    // Yield has side effects (generator operation)
    YieldExpression(_) => true
    // Delete has side effects (removes property)
    // Already handled in UnaryExpression
    // Parenthesized - check inner expression
    ParenthesizedExpression(paren) =>
      expression_has_side_effects(paren.expression)
    // All other expressions (literals, identifiers, property access, etc.) have no side effects
    _ => false
  }
}

///|
/// Check if an expression contains a reference to a given identifier name
fn expression_contains_identifier(expr : Node, name : String) -> Bool {
  match expr {
    Identifier(id) => id.name == name
    BinaryExpression(bin) =>
      expression_contains_identifier(bin.left, name) ||
      expression_contains_identifier(bin.right, name)
    ParenthesizedExpression(paren) =>
      expression_contains_identifier(paren.expression, name)
    UnaryExpression(unary) =>
      expression_contains_identifier(unary.operand, name)
    ConditionalExpression(cond) =>
      expression_contains_identifier(cond.condition, name) ||
      expression_contains_identifier(cond.when_true, name) ||
      expression_contains_identifier(cond.when_false, name)
    CallExpression(call) => {
      if expression_contains_identifier(call.expression, name) {
        return true
      }
      for arg in call.arguments {
        if expression_contains_identifier(arg, name) {
          return true
        }
      }
      false
    }
    PropertyAccessExpression(prop) =>
      expression_contains_identifier(prop.expression, name)
    ElementAccessExpression(elem) =>
      expression_contains_identifier(elem.expression, name) ||
      expression_contains_identifier(elem.argument_expression, name)
    _ => false
  }
}

///|
/// Check parameter for TS2372 (parameter cannot reference itself in initializer)
fn check_parameter_self_reference(
  checker : TypeChecker,
  parameters : Array[Node],
) -> TypeChecker {
  let mut checker = checker
  for param_node in parameters {
    match param_node {
      Parameter(p) =>
        match p.initializer {
          Some(init) => {
            // Get parameter name
            let param_name = match p.name {
              Identifier(id) => id.name
              _ => ""
            }
            if param_name != "" &&
              expression_contains_identifier(init, param_name) {
              checker = add_diagnostic_with_code(
                checker,
                "Parameter '\{param_name}' cannot reference itself.",
                p.location,
                DiagnosticCode::TS2372,
              )
            }
          }
          None => ()
        }
      _ => ()
    }
  }
  checker
}

///|
/// Check if an expression contains a reference to this.propName where propName is uninitialized (TS2729)
fn check_property_forward_reference(
  checker : TypeChecker,
  expr : Node,
  uninitialized_props : Map[String, Bool],
) -> TypeChecker {
  let mut checker = checker
  match expr {
    PropertyAccessExpression(pa) =>
      match pa.expression {
        ThisExpression(_) => {
          // This is a this.propName access
          if uninitialized_props.contains(pa.name) {
            checker = add_diagnostic_with_code(
              checker,
              "Property '\{pa.name}' is used before its initialization.",
              pa.location,
              DiagnosticCode::TS2729,
            )
          }
          checker
        }
        _ =>
          check_property_forward_reference(
            checker,
            pa.expression,
            uninitialized_props,
          )
      }
    BinaryExpression(bin) => {
      checker = check_property_forward_reference(
        checker,
        bin.left,
        uninitialized_props,
      )
      check_property_forward_reference(checker, bin.right, uninitialized_props)
    }
    UnaryExpression(un) =>
      check_property_forward_reference(checker, un.operand, uninitialized_props)
    ConditionalExpression(cond) => {
      checker = check_property_forward_reference(
        checker,
        cond.condition,
        uninitialized_props,
      )
      checker = check_property_forward_reference(
        checker,
        cond.when_true,
        uninitialized_props,
      )
      check_property_forward_reference(
        checker,
        cond.when_false,
        uninitialized_props,
      )
    }
    CallExpression(call) => {
      checker = check_property_forward_reference(
        checker,
        call.expression,
        uninitialized_props,
      )
      for arg in call.arguments {
        checker = check_property_forward_reference(
          checker, arg, uninitialized_props,
        )
      }
      checker
    }
    NewExpression(new_expr) => {
      checker = check_property_forward_reference(
        checker,
        new_expr.expression,
        uninitialized_props,
      )
      match new_expr.arguments {
        Some(args) =>
          for arg in args {
            checker = check_property_forward_reference(
              checker, arg, uninitialized_props,
            )
          }
        None => ()
      }
      checker
    }
    ArrayLiteralExpression(arr) => {
      for elem in arr.elements {
        match elem {
          Some(e) =>
            checker = check_property_forward_reference(
              checker, e, uninitialized_props,
            )
          None => ()
        }
      }
      checker
    }
    ObjectLiteralExpression(obj) => {
      for prop in obj.properties {
        match prop {
          PropertyAssignment(_, initializer, _) =>
            checker = check_property_forward_reference(
              checker, initializer, uninitialized_props,
            )
          ShorthandProperty(_, _) => ()
          SpreadAssignment(expression, _) =>
            checker = check_property_forward_reference(
              checker, expression, uninitialized_props,
            )
          MethodDeclaration(_, _, _) => ()
          GetAccessor(_, _, _) => ()
          SetAccessor(_, _, _) => ()
          ComputedPropertyAssignment(key_expr, value_expr, _) => {
            checker = check_property_forward_reference(
              checker, key_expr, uninitialized_props,
            )
            checker = check_property_forward_reference(
              checker, value_expr, uninitialized_props,
            )
          }
          ComputedMethodDeclaration(key_expr, _, _) =>
            checker = check_property_forward_reference(
              checker, key_expr, uninitialized_props,
            )
          ComputedGetAccessor(key_expr, _, _) =>
            checker = check_property_forward_reference(
              checker, key_expr, uninitialized_props,
            )
          ComputedSetAccessor(key_expr, _, _) =>
            checker = check_property_forward_reference(
              checker, key_expr, uninitialized_props,
            )
        }
      }
      checker
    }
    ParenthesizedExpression(paren) =>
      check_property_forward_reference(
        checker,
        paren.expression,
        uninitialized_props,
      )
    ElementAccessExpression(elem) => {
      checker = check_property_forward_reference(
        checker,
        elem.expression,
        uninitialized_props,
      )
      check_property_forward_reference(
        checker,
        elem.argument_expression,
        uninitialized_props,
      )
    }
    ArrowFunction(_) =>
      // Don't recurse into arrow function bodies - they're evaluated lazily
      checker
    FunctionExpression(_) =>
      // Don't recurse into function expressions - they're evaluated lazily
      checker
    TemplateExpression(tmpl) => {
      for span in tmpl.template_spans {
        checker = check_property_forward_reference(
          checker,
          span.expression,
          uninitialized_props,
        )
      }
      checker
    }
    AwaitExpression(await_expr) =>
      check_property_forward_reference(
        checker,
        await_expr.expression,
        uninitialized_props,
      )
    _ => checker
  }
}

///|
/// Check for TS2748: variable referencing itself in initializer (temporal dead zone)
fn check_variable_self_reference(
  checker : TypeChecker,
  decl : VariableDeclaration,
) -> TypeChecker {
  // Get the variable name
  let var_name = match decl.name {
    Identifier(id) => id.name
    _ => return checker // Skip destructuring patterns for now
  }

  // Check if the initializer references the variable
  match decl.initializer {
    Some(init) =>
      if expression_contains_identifier(init, var_name) {
        add_diagnostic_with_code(
          checker,
          "Cannot access '\{var_name}' before initialization.",
          decl.location,
          DiagnosticCode::TS2748,
        )
      } else {
        checker
      }
    None => checker
  }
}

///|
/// Get type parameters from a symbol's declarations (interfaces, classes, type aliases)
fn get_type_parameters_from_symbol(symbol : Symbol) -> Array[TypeParameter] {
  for decl in symbol.declarations {
    match decl {
      InterfaceDeclaration(iface) => return iface.type_parameters
      ClassDeclaration(class_decl) => return class_decl.type_parameters
      TypeAliasDeclaration(type_alias) => return type_alias.type_parameters
      _ => continue
    }
  }
  []
}

///|
/// Count required type parameters (those without defaults)
fn count_required_type_params_from_ast(
  type_params : Array[TypeParameter],
) -> Int {
  let mut count = 0
  for param in type_params {
    if param.default is None {
      count = count + 1
    }
  }
  count
}

///|
/// Validate type arguments against type parameters, returning (isValid, checker)
/// If invalid, adds diagnostic and returns false
fn validate_type_argument_count(
  checker : TypeChecker,
  type_name : String,
  type_args_count : Int,
  type_params : Array[TypeParameter],
  location : SourceLocation,
) -> TypeChecker {
  let min_required = count_required_type_params_from_ast(type_params)
  let max_allowed = type_params.length()
  if type_args_count < min_required || type_args_count > max_allowed {
    if min_required != max_allowed {
      // TS2707: Generic type requires between N and M type arguments
      return add_diagnostic_with_code(
        checker,
        "Generic type '\{type_name}' requires between \{min_required} and \{max_allowed} type argument(s), but got \{type_args_count}.",
        location,
        DiagnosticCode::TS2707,
      )
    } else if type_args_count < min_required {
      // TS2314: Generic type requires N type argument(s)
      return add_diagnostic_with_code(
        checker,
        "Generic type '\{type_name}' requires \{min_required} type argument(s).",
        location,
        DiagnosticCode::TS2314,
      )
    } else {
      // Too many type arguments (exact count expected)
      return add_diagnostic_with_code(
        checker,
        "Generic type '\{type_name}' requires \{max_allowed} type argument(s), but got \{type_args_count}.",
        location,
        DiagnosticCode::TS2558,
      )
    }
  }
  checker
}

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
        BigInt => {
          let (t, c) = bigint_type(checker)
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
            Some(symbol) => {
              // Validate type argument count against type parameters
              let type_params = get_type_parameters_from_symbol(symbol)
              let type_args_count = type_ref.type_arguments.length()
              let checker = validate_type_argument_count(
                checker,
                type_ref.type_name,
                type_args_count,
                type_params,
                type_ref.location,
              )
              match symbol.kind {
                Interface =>
                  // Resolve interface to an Object type with its properties
                  match resolve_interface_type(checker, symbol) {
                    (Some(t), c) => (Some(t), c)
                    (None, c) => (None, c)
                  }
                Type =>
                  // Resolve type alias to its underlying type
                  // If there are type arguments, use the version that substitutes them
                  if type_ref.type_arguments.length() > 0 {
                    resolve_type_alias_type_with_args(
                      checker,
                      symbol,
                      type_ref.type_arguments,
                    )
                  } else {
                    resolve_type_alias_type(checker, symbol)
                  }
                Class => {
                  // For class types, create a TypeReference to the class
                  // This preserves the class name for later type checking
                  let (info, c) = create_type_info(checker)
                  (
                    Some(
                      Type::TypeReference({
                        name: type_ref.type_name,
                        type_arguments: [],
                        info,
                      }),
                    ),
                    c,
                  )
                }
                Module => {
                  // TS2709: Cannot use namespace as a type
                  let checker = add_diagnostic_with_code(
                    checker,
                    "Cannot use namespace '\{type_ref.type_name}' as a type.",
                    type_ref.location,
                    TS2709,
                  )
                  (None, checker)
                }
                _ => (None, checker) // Other symbol kinds not yet supported
              }
            }
            None =>
              // Handle well-known TypeScript built-in types that may not be in the symbol table
              // These are standard library types like Generator, Iterable, Iterator, etc.
              if is_builtin_generic_type(type_ref.type_name) {
                // Create a TypeReference for the built-in type with resolved type arguments
                let mut checker = checker
                let resolved_args : Array[Type] = []
                for i = 0; i < type_ref.type_arguments.length(); i = i + 1 {
                  match
                    get_type_from_type_node(checker, type_ref.type_arguments[i]) {
                    (Some(arg_type), c) => {
                      resolved_args.push(arg_type)
                      checker = c
                    }
                    (None, c) => {
                      // If we can't resolve a type argument, use any as fallback
                      let (any_t, c2) = any_type(c)
                      resolved_args.push(any_t)
                      checker = c2
                    }
                  }
                }
                let (info, checker) = create_type_info(checker)
                (
                  Some(
                    Type::TypeReference({
                      name: type_ref.type_name,
                      type_arguments: resolved_args,
                      info,
                    }),
                  ),
                  checker,
                )
              } else {
                (None, checker)
              }
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
      for mem in type_literal.members {
        match mem {
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
            let (param_type, c) = match
              get_type_from_type_node(checker, idx_sig.parameter_type) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
            checker = c
            // Get return type (return_type is Node, not Node?)
            let (return_type, c) = match
              get_type_from_type_node(checker, idx_sig.return_type) {
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
          MethodDeclaration(method_decl) =>
            // Handle method signatures - check for construct/call signatures
            if method_decl.name == "new" {
              // Construct signature: new (params): ReturnType
              let (sig, c) = get_method_checker_signature(checker, method_decl)
              checker = c
              construct_signatures.push(sig)
            } else if method_decl.name == "" {
              // Call signature: (params): ReturnType
              let (sig, c) = get_method_checker_signature(checker, method_decl)
              checker = c
              call_signatures.push(sig)
            } else {
              // Regular method - add as property
              let (method_type, c) = get_method_signature_type(
                checker, method_decl,
              )
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
    LiteralType(lit_type) =>
      // Handle literal types: "up" | "down", 1 | 2, true | false
      match lit_type.literal {
        StringLiteral(s) => {
          let (info, c) = create_type_info(checker)
          (Some(StringLiteral(s.value, info)), c)
        }
        NumericLiteral(n) => {
          let (info, c) = create_type_info(checker)
          // Parse the string value to a number
          let num_value = @strconv.parse_double(n.value) catch { _ => 0.0 }
          (Some(NumberLiteral(num_value, info)), c)
        }
        BooleanLiteral(b) => {
          let (info, c) = create_type_info(checker)
          (Some(BooleanLiteral(b.value, info)), c)
        }
        _ => (None, checker)
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
      let (return_type, checker) = match
        get_type_from_type_node(checker, func_type.return_type) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
      let (info, checker) = create_type_info(checker)
      (Some(Type::Function({ parameters, return_type, info })), checker)
    }
    TypeOperator(type_op) =>
      // Handle type operators: keyof T, typeof x, readonly T, unique symbol
      match type_op.operator {
        KeyOf =>
          // For keyof, we need to get the inner type and extract its keys as a union
          match get_type_from_type_node(checker, type_op.type_node) {
            (Some(inner_type), c) => {
              let keys = extract_keys_from_type(inner_type)
              if keys.length() > 0 {
                let (info, c2) = create_type_info(c)
                (Some(Union({ types: keys, info })), c2)
              } else {
                // The inner type exists but has no keys - could be a type parameter
                // Create an IndexAccess type to represent "keyof T" for later substitution
                // When the inner type is a TypeReference (type parameter), preserve it
                match inner_type {
                  TypeReference(_) => {
                    // Create a special representation: IndexAccess with "keyof" marker
                    // We use IndexAccess { object_type: inner_type, index_type: string }
                    // to represent "keyof inner_type"
                    let (str_t, c2) = string_type(c)
                    let (info, c3) = create_type_info(c2)
                    (
                      Some(
                        IndexAccess({
                          object_type: inner_type,
                          index_type: str_t,
                          info,
                          is_keyof: true,
                        }),
                      ),
                      c3,
                    )
                  }
                  _ => {
                    // No keys found, return string | number | symbol for general keyof
                    let (str_t, c2) = string_type(c)
                    let (num_t, c3) = number_type(c2)
                    let (sym_t, c4) = symbol_type(c3)
                    let (info, c5) = create_type_info(c4)
                    (Some(Union({ types: [str_t, num_t, sym_t], info })), c5)
                  }
                }
              }
            }
            (None, c) =>
              // The inner type wasn't found - check if it's a type parameter reference
              match type_op.type_node {
                Node::TypeReference(type_ref) => {
                  // Create a TypeReference for the unresolved type parameter
                  let (info, c2) = create_type_info(c)
                  let inner_type_ref = Type::TypeReference({
                    name: type_ref.type_name,
                    type_arguments: [],
                    info,
                  })
                  // Create IndexAccess to represent "keyof T"
                  let (str_t, c3) = string_type(c2)
                  let (info2, c4) = create_type_info(c3)
                  (
                    Some(
                      IndexAccess({
                        object_type: inner_type_ref,
                        index_type: str_t,
                        info: info2,
                        is_keyof: true,
                      }),
                    ),
                    c4,
                  )
                }
                _ => (None, c)
              }
          }
        TypeOf => {
          // typeof x - would need to look up the value and get its type
          // For now, return any
          let (t, c) = any_type(checker)
          (Some(t), c)
        }
        Readonly =>
          // readonly T - return the underlying type (readonly is a modifier on properties)
          get_type_from_type_node(checker, type_op.type_node)
        Unique => {
          // unique symbol
          let (t, c) = symbol_type(checker)
          (Some(t), c)
        }
      }
    TupleType(tuple_type) => {
      // Handle tuple types: [number, string]
      let mut checker = checker
      let element_types : Array[TupleElement] = []
      for elem_node in tuple_type.element_types {
        // Handle different tuple element representations
        // Could be a bare type node, or a NamedTupleMember for labeled tuples
        let (elem_type, is_optional, is_rest, label) = match elem_node {
          NamedTupleMember(named) => {
            let (t, c) = match
              get_type_from_type_node(checker, named.element_type) {
              (Some(t), c) => (t, c)
              (None, c) => any_type(c)
            }
            checker = c
            (t, named.is_optional, false, Some(named.name))
          }
          SpreadExpression(spread) => {
            // Rest element in tuple: ...T
            let (t, c) = match
              get_type_from_type_node(checker, spread.expression) {
              (Some(t), c) => (t, c)
              (None, c) => any_type(c)
            }
            checker = c
            (t, false, true, None)
          }
          RestType(rest) => {
            // Rest type: ...T[]
            let (t, c) = match
              get_type_from_type_node(checker, rest.element_type) {
              (Some(t), c) => (t, c)
              (None, c) => any_type(c)
            }
            checker = c
            (t, false, true, None)
          }
          OptionalType(opt) => {
            // Optional element: T?
            let (t, c) = match
              get_type_from_type_node(checker, opt.element_type) {
              (Some(t), c) => (t, c)
              (None, c) => any_type(c)
            }
            checker = c
            (t, true, false, None)
          }
          _ => {
            // Regular type element
            let (t, c) = match get_type_from_type_node(checker, elem_node) {
              (Some(t), c) => (t, c)
              (None, c) => any_type(c)
            }
            checker = c
            (t, false, false, None)
          }
        }
        element_types.push(TupleElement::{
          element_type: elem_type,
          is_optional,
          is_rest,
          label,
        })
      }
      let (info, checker) = create_type_info(checker)
      (Some(Tuple(CheckerTupleType::{ element_types, info })), checker)
    }
    _ => (None, checker)
  }
}

///|
/// Extract keys from a type as string literal types
fn extract_keys_from_type(t : Type) -> Array[Type] {
  let keys : Array[Type] = []
  match t {
    Object(obj) =>
      for kv in obj.properties {
        // Create a string literal type for each property name
        let info : TypeInfo = {
          id: 0,
          flags: { is_readonly: false, is_optional: false },
        }
        keys.push(StringLiteral(kv.0, info))
      }
    _ => ()
  }
  keys
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
/// Get CheckerSignature from a method declaration (for construct/call signatures)
fn get_method_checker_signature(
  checker : TypeChecker,
  method_decl : MethodDeclaration,
) -> (CheckerSignature, TypeChecker) {
  // Build parameters
  let mut c = checker
  let parameters : Array[CheckerParameter] = []
  for param in method_decl.parameters {
    match param {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
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
  let checker = c

  // Get return type
  let (return_type, checker) = match method_decl.return_type {
    Some(rt) =>
      match get_type_from_type_node(checker, rt) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
    None => any_type(checker)
  }
  ({ parameters, return_type, type_parameters: [] }, checker)
}

///|
/// Get type for a method signature in type literal
fn get_method_signature_type(
  checker : TypeChecker,
  method_decl : MethodDeclaration,
) -> (Type, TypeChecker) {
  // Build parameters
  let mut c = checker
  let parameters : Array[CheckerParameter] = []
  for param in method_decl.parameters {
    match param {
      Parameter(p) => {
        let (param_type, c2) = resolve_type_annotation_or_any(c, p.type_annotation)
        c = c2
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
  let checker = c

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
    // Handle Symbol.iterator as a special case
    PropertyAccessExpression(pae) =>
      match pae.expression {
        Identifier(obj_id) if obj_id.name == "Symbol" =>
          if pae.name == "iterator" {
            "__@iterator"
          } else if pae.name == "asyncIterator" {
            "__@asyncIterator"
          } else {
            ""
          }
        _ => ""
      }
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
    BigInt(_) => "bigint"
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
    TemplateLiteral(tl) =>
      // Try to evaluate to a concrete string for better error messages
      match evaluate_template_literal_to_string(tl) {
        Some(s) => "\"\{s}\""
        None => "`...`"
      }
    IndexAccess(ia) =>
      "\{type_to_string(ia.object_type)}[\{type_to_string(ia.index_type)}]"
    Infer(inf) => "infer \{inf.type_parameter_name}"
    Function(_) => "function"
    Object(obj) =>
      // First check for named types (class instances, typeof globalThis, etc.)
      match obj.class_name {
        Some(name) => name
        None =>
          // Display empty object literals as {} (like TypeScript does)
          if obj.properties.size() == 0 &&
            obj.call_signatures.length() == 0 &&
            obj.construct_signatures.length() == 0 &&
            obj.index_signatures.length() == 0 {
            "{}"
          } else {
            "object"
          }
      }
    TypeReference(type_ref) => type_ref.name
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
    // First check namespace_symbols (for symbols in current namespace scope)
    match checker.namespace_symbols.get(name) {
      Some(sym) => Some(sym)
      None =>
        // Fall back to simple name lookup in global scope
        match checker.global_scope {
          Some(scope) => scope.symbols.get(name)
          None => None
        }
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
fn lookup_qualified_symbol(
  checker : TypeChecker,
  qualified_name : String,
) -> Symbol? {
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
    // Circular reference detected - return a TypeReference to the interface name
    // This ensures that when interface I has a call signature returning I,
    // the return type correctly refers back to the interface
    let (info, checker) = create_type_info(checker)
    return (
      Some(
        Type::TypeReference({
          name: interface_symbol.name,
          type_arguments: [],
          info,
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
            let func_sig : CheckerSignature = {
              parameters,
              return_type,
              type_parameters: [],
            }
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
          class_name: Some(interface_symbol.name),
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

///|
/// Resolve a type alias symbol to its underlying type
fn resolve_type_alias_type(
  checker : TypeChecker,
  type_alias_symbol : Symbol,
) -> (Type?, TypeChecker) {
  // Check for circular reference
  if checker.resolving_symbols.get(type_alias_symbol.id) is Some(_) {
    // Circular reference - return a TypeReference
    let (info, checker) = create_type_info(checker)
    return (
      Some(
        Type::TypeReference({
          name: type_alias_symbol.name,
          type_arguments: [],
          info,
        }),
      ),
      checker,
    )
  }

  // Mark symbol as being resolved
  let resolving = checker.resolving_symbols
  resolving.set(type_alias_symbol.id, true)
  let mut checker = { ..checker, resolving_symbols: resolving }

  // Get the type alias declaration from the symbol
  let result = match type_alias_symbol.value_declaration {
    Some(TypeAliasDeclaration(type_alias)) =>
      // Get the underlying type from the type_node
      match get_type_from_type_node(checker, type_alias.type_node) {
        (Some(t), c) => {
          checker = c
          Some(t)
        }
        (None, c) => {
          checker = c
          None
        }
      }
    _ =>
      // Try declarations array if value_declaration is not a TypeAliasDeclaration
      match
        type_alias_symbol.declarations
        .iter()
        .find_first(fn(decl) { decl is TypeAliasDeclaration(_) }) {
        Some(TypeAliasDeclaration(type_alias)) =>
          match get_type_from_type_node(checker, type_alias.type_node) {
            (Some(t), c) => {
              checker = c
              Some(t)
            }
            (None, c) => {
              checker = c
              None
            }
          }
        _ => None
      }
  }

  // Unmark symbol as being resolved
  let resolving = checker.resolving_symbols
  resolving.remove(type_alias_symbol.id)
  checker = { ..checker, resolving_symbols: resolving }
  (result, checker)
}

///|
/// Resolve a type alias with type arguments, performing substitution
fn resolve_type_alias_type_with_args(
  checker : TypeChecker,
  type_alias_symbol : Symbol,
  type_args : Array[Node],
) -> (Type?, TypeChecker) {
  // First resolve the base type alias
  let (base_type_opt, checker) = resolve_type_alias_type(
    checker, type_alias_symbol,
  )
  match base_type_opt {
    Some(base_type) => {
      // Get type parameter names from the type alias declaration
      let type_param_names = get_type_param_names_from_symbol(type_alias_symbol)

      // Convert type argument nodes to types
      let mut checker = checker
      let resolved_args : Array[Type] = []
      for type_arg_node in type_args {
        match get_type_from_type_node(checker, type_arg_node) {
          (Some(t), c) => {
            resolved_args.push(t)
            checker = c
          }
          (None, c) => checker = c
        }
      }

      // Create substitution map
      let subst_map : Map[String, Type] = Map::new()
      for i = 0
          i < type_param_names.length() && i < resolved_args.length()
          i = i + 1 {
        subst_map.set(type_param_names[i], resolved_args[i])
      }

      // Substitute and expand
      let (result, checker) = substitute_and_expand_type(
        checker, base_type, subst_map,
      )
      (Some(result), checker)
    }
    None => (None, checker)
  }
}

///|
/// Get type parameter names from a type alias symbol
fn get_type_param_names_from_symbol(symbol : Symbol) -> Array[String] {
  let names : Array[String] = []
  match symbol.value_declaration {
    Some(TypeAliasDeclaration(type_alias)) =>
      for param in type_alias.type_parameters {
        names.push(param.name)
      }
    _ => ()
  }
  names
}

///|
/// Substitute type parameters and expand mapped types
fn substitute_and_expand_type(
  checker : TypeChecker,
  t : Type,
  subst_map : Map[String, Type],
) -> (Type, TypeChecker) {
  match t {
    // Type reference - might be a type parameter to substitute
    TypeReference(type_ref) =>
      match subst_map.get(type_ref.name) {
        Some(substituted) => (substituted, checker)
        None => {
          // Recursively substitute in type arguments
          let mut checker = checker
          let new_args : Array[Type] = []
          for arg in type_ref.type_arguments {
            let (new_arg, c) = substitute_and_expand_type(
              checker, arg, subst_map,
            )
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
    // Mapped type - expand if constraint is keyof of a known type
    Mapped(mapped) => expand_mapped_type_with_subst(checker, mapped, subst_map)
    // Union type - substitute in each member
    Union(union) => {
      let mut checker = checker
      let new_types : Array[Type] = []
      for member in union.types {
        let (new_member, c) = substitute_and_expand_type(
          checker, member, subst_map,
        )
        new_types.push(new_member)
        checker = c
      }
      let (info, checker) = create_type_info(checker)
      (Union({ types: new_types, info }), checker)
    }
    // Array type - substitute element type
    Array(arr) => {
      let (new_elem, checker) = substitute_and_expand_type(
        checker,
        arr.element_type,
        subst_map,
      )
      let (info, checker) = create_type_info(checker)
      (Array({ element_type: new_elem, info }), checker)
    }
    // Object type - substitute property types
    Object(obj) => {
      let mut checker = checker
      let new_props : Map[String, PropertySignature] = Map::new()
      for entry in obj.properties {
        let (name, prop) = entry
        let (new_type, c) = substitute_and_expand_type(
          checker,
          prop.prop_type,
          subst_map,
        )
        new_props.set(name, { ..prop, prop_type: new_type })
        checker = c
      }
      let (info, checker) = create_type_info(checker)
      (
        Object({
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
    // Other types - return as is
    _ => (t, checker)
  }
}

///|
/// Expand a mapped type after substitution
fn expand_mapped_type_with_subst(
  checker : TypeChecker,
  mapped : CheckerMappedType,
  subst_map : Map[String, Type],
) -> (Type, TypeChecker) {
  // Check if the constraint is "keyof T" where T is in subst_map
  match mapped.type_parameter.constraint {
    Some(constraint) =>
      match get_keyof_target(constraint, subst_map) {
        Some(target_type) =>
          // We have keyof T where T is known - expand the mapped type
          match target_type {
            Object(obj) => {
              // Create properties from the target object
              let result_props : Map[String, PropertySignature] = Map::new()
              for entry in obj.properties {
                let (name, prop) = entry
                // Substitute the template type with the property type
                // For { [K in keyof T]: T[K] }, the value is the original property type
                // For { [K in keyof T]?: T[K] }, add optional modifier
                let is_readonly = match mapped.readonly_modifier {
                  Add => true
                  Remove => false
                  Unchanged => prop.is_readonly
                }
                let is_optional = match mapped.optional_modifier {
                  Add => true
                  Remove => false
                  Unchanged => prop.is_optional
                }
                // The template_type might reference the mapped key's value
                // For T[K], we use the property type
                let prop_type = substitute_template_type(
                  mapped.template_type,
                  mapped.type_parameter.name,
                  prop.prop_type,
                  subst_map,
                )
                result_props.set(name, {
                  name,
                  prop_type,
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
              // Can't expand - target is not an object
              (Mapped(mapped), checker)
          }
        None =>
          // Constraint is not a substitutable keyof - return mapped type as is
          (Mapped(mapped), checker)
      }
    None =>
      // No constraint - return mapped type as is
      (Mapped(mapped), checker)
  }
}

///|
/// Check if a type is "keyof T" where T is in the substitution map
fn get_keyof_target(t : Type, subst_map : Map[String, Type]) -> Type? {
  match t {
    // IndexAccess with is_keyof flag represents "keyof T"
    IndexAccess(ia) =>
      if ia.is_keyof {
        // This is a "keyof T" representation
        match ia.object_type {
          TypeReference(type_ref) => subst_map.get(type_ref.name)
          _ => None
        }
      } else {
        // Regular index access T[K]
        match ia.object_type {
          TypeReference(type_ref) => subst_map.get(type_ref.name)
          _ => None
        }
      }
    // TypeReference to a type parameter (fallback case)
    TypeReference(type_ref) =>
      // Check if this is a keyof constraint that was simplified
      subst_map.get(type_ref.name)
    _ => None
  }
}

///|
/// Substitute the template type (e.g., T[K]) with the actual property type
fn substitute_template_type(
  template : Type,
  key_param : String,
  prop_type : Type,
  subst_map : Map[String, Type],
) -> Type {
  match template {
    // IndexAccess like T[K] - return the property type
    IndexAccess(_) => prop_type
    // TypeReference - check if it's a type parameter to substitute
    TypeReference(type_ref) =>
      match subst_map.get(type_ref.name) {
        Some(t) => t
        None => if type_ref.name == key_param { prop_type } else { template }
      }
    // Other types - return as is
    _ => template
  }
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
    diagnostics.push(Diagnostic::{
      code: 1208,
      category: DiagnosticCategory::Error,
      message: "'isolatedModules' requires all files to be modules (have import or export statements).",
      location,
    })
  }

  // TS1209: const enum declarations are not allowed
  for stmt in bound.statements {
    match stmt {
      EnumDeclaration(enum_decl) =>
        if enum_decl.is_const {
          diagnostics.push(Diagnostic::{
            code: 1209,
            category: DiagnosticCategory::Error,
            message: "const enums are not allowed when 'isolatedModules' is enabled. Use regular enums instead.",
            location: enum_decl.location,
          })
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
  _file_path : String,
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
              Some(NamedImports::NamedImports(specifiers, _)) =>
                for specifier in specifiers {
                  // Skip if the specifier is type-only
                  if specifier.is_type_only {
                    continue
                  }

                  // The local name is the name used in the file
                  let local_name = specifier.name

                  // Check if this symbol is a type-only symbol in the local scope
                  // Since we can't resolve cross-file imports, we check local declarations
                  if type_only_symbols.get(local_name).unwrap_or(false) {
                    diagnostics.push(Diagnostic::{
                      code: 1485,
                      category: DiagnosticCategory::Error,
                      message: "'\{local_name}' is a type and must be imported using a type-only import when 'verbatimModuleSyntax' is enabled.",
                      location: specifier.location,
                    })
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
          Some(NamedExports::NamedExports(specifiers, _)) =>
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
              if type_only_symbols.get(local_name).unwrap_or(false) {
                diagnostics.push(Diagnostic::{
                  code: 1486,
                  category: DiagnosticCategory::Error,
                  message: "'\{local_name}' is a type and must be exported using a type-only export when 'verbatimModuleSyntax' is enabled.",
                  location: specifier.location,
                })
              }
            }
          Some(NamedExports::NamespaceExport(_, _)) => () // Namespace exports (export * as ns) don't need type-only checking
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
priv struct ExactOptPropertyInfo {
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
          for mem in iface.members {
            match mem {
              PropertyDeclaration(prop_decl) =>
                props.set(prop_decl.name, {
                  is_optional: prop_decl.is_optional,
                  type_node: prop_decl.type_annotation,
                })
              _ => ()
            }
          }
        }
      TypeAliasDeclaration(type_alias) =>
        if type_alias.name == type_name {
          // Handle type alias to object type
          match type_alias.type_node {
            TypeLiteral(tl) =>
              for mem in tl.members {
                match mem {
                  PropertyDeclaration(prop_decl) =>
                    props.set(prop_decl.name, {
                      is_optional: prop_decl.is_optional,
                      type_node: prop_decl.type_annotation,
                    })
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
                bound,
                type_ref.type_name,
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
                              diagnostics.push(Diagnostic::{
                                code: 2412,
                                category: DiagnosticCategory::Error,
                                message: "Type 'undefined' is not assignable to type with 'exactOptionalPropertyTypes' enabled. Consider adding 'undefined' to the type of the target.",
                                location,
                              })
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

// ============================================================================
// Type Parameter Name Validation (TS2368)
// ============================================================================

///|
/// Check if a type parameter name is a reserved TypeScript type name
fn is_reserved_type_name(name : String) -> Bool {
  match name {
    "string"
    | "number"
    | "boolean"
    | "symbol"
    | "bigint"
    | "void"
    | "any"
    | "object"
    | "never"
    | "unknown"
    | "undefined"
    | "null" => true
    _ => false
  }
}

///|
/// Check type parameter names for reserved keywords (TS2368)
/// and required type parameters after optional (TS2706)
fn check_type_parameter_names(
  checker : TypeChecker,
  type_params : Array[TypeParameter],
) -> TypeChecker {
  let mut checker = checker
  let mut seen_optional = false
  let mut first_optional_name = ""
  for param in type_params {
    // TS2368: Check reserved type names
    if is_reserved_type_name(param.name) {
      checker = add_diagnostic_with_code(
        checker,
        "Type parameter name cannot be '\{param.name}'",
        param.location,
        TS2368,
      )
    }

    // TS2706: Check required type params don't follow optional
    let has_default = param.default is Some(_)
    if has_default {
      if not(seen_optional) {
        seen_optional = true
        first_optional_name = param.name
      }
    } else if seen_optional {
      // Required param after optional - error!
      checker = add_diagnostic_with_code(
        checker,
        "Required type parameters may not follow optional type parameters. '\{param.name}' is required but follows '\{first_optional_name}' which has a default.",
        param.location,
        TS2706,
      )
    }
  }
  checker
}

// ============================================================================
// Extract ModuleTypes for Cross-File Type Checking
// ============================================================================

///|
/// Extract module types from a bound source file for cross-file type checking.
/// This creates a ModuleTypes object containing all exported types.
pub fn extract_module_types(
  bound_file : BoundSourceFile,
  file_path : String,
) -> ModuleTypes {
  // Call the extended version without external registry
  extract_module_types_with_registry(bound_file, file_path, None)
}

///|
/// Extract module types with access to external registry for resolving require() calls.
/// This enables proper type inference for CommonJS require chains.
pub fn extract_module_types_with_registry(
  bound_file : BoundSourceFile,
  file_path : String,
  external_registry : ExternalTypeRegistry?,
) -> ModuleTypes {
  let module_types = ModuleTypes::empty(file_path)

  // Create a base environment to convert AST types to TypeV2
  let env = TypeEnv::with_builtins()

  // First pass: collect require() bindings (var x = require('mod'))
  let require_bindings : Map[String, String] = collect_require_bindings(
    bound_file.statements,
    file_path,
  )

  // Create CommonJS context for resolving require() bindings
  let cjs_ctx = CommonJSTypeContext::{
    env,
    require_bindings,
    external_registry,
  }
  for statement in bound_file.statements {
    match statement {
      // Export declaration: export { a, b } or export { a as b }
      ExportDeclaration(ed) =>
        match ed.export_clause {
          Some(NamedExports(specifiers, _)) =>
            for spec in specifiers {
              // Get type from global scope if available
              let ty = resolve_export_type(
                bound_file.global_scope,
                spec.name,
                env,
              )
              let info = ExternalTypeInfo::value(ty, spec.name)
              module_types.add_export(spec.name, info)
            }
          Some(NamespaceExport(name, _)) => {
            // Namespace re-export - add as any for now
            let info = ExternalTypeInfo::value(TAny, name)
            module_types.add_export(name, info)
          }
          None => () // export * from 'mod' - handled by module resolver
        }

      // Export assignment: export = x or export default x
      ExportAssignment(ea) => {
        let ty = match ea.expression {
          Identifier(id) =>
            resolve_export_type(bound_file.global_scope, id.name, env)
          _ => TAny
        }
        let info = if ea.is_export_equals {
          ExternalTypeInfo::value(ty, "=")
        } else {
          ExternalTypeInfo::value(ty, "default")
        }
        // Store in a special key for default
        module_types.named_exports.set("default", info)
      }

      // Exported function declaration
      FunctionDeclaration(fd) =>
        if has_export_modifier_in_list(fd.modifiers) {
          match fd.name {
            Some(Identifier(id)) => {
              let ty = function_declaration_to_type(env, fd)
              let is_default = has_default_modifier_in_list(fd.modifiers)
              if is_default {
                let info = ExternalTypeInfo::value(ty, id.name)
                module_types.named_exports.set("default", info)
              } else {
                let info = ExternalTypeInfo::value(ty, id.name)
                module_types.add_export(id.name, info)
              }
            }
            _ => ()
          }
        }

      // Exported class declaration
      ClassDeclaration(cd) =>
        if has_export_modifier_in_list(cd.modifiers) {
          match cd.name {
            Some(Identifier(id)) => {
              let ty = class_declaration_to_type(env, cd)
              let is_default = has_default_modifier_in_list(cd.modifiers)
              if is_default {
                let info = ExternalTypeInfo::value(ty, id.name)
                module_types.named_exports.set("default", info)
              } else {
                let info = ExternalTypeInfo::value(ty, id.name)
                module_types.add_export(id.name, info)
              }
            }
            _ => ()
          }
        }

      // Exported variable statement
      VariableStatement(vs) =>
        if has_export_modifier_in_list(vs.modifiers) {
          for decl in vs.declarations {
            match decl.name {
              Identifier(id) => {
                let ty = variable_declaration_to_type(env, decl)
                let info = ExternalTypeInfo::value(ty, id.name)
                module_types.add_export(id.name, info)
              }
              _ => ()
            }
          }
        }

      // Exported type alias
      TypeAliasDeclaration(tad) =>
        if has_export_modifier_in_list(tad.modifiers) {
          let ty = ast_type_to_v2(env, tad.type_node)
          let alias_info = TypeAliasInfoV2::{ type_params: [], body: ty }
          module_types.type_aliases.set(tad.name, alias_info)
          // Also add to named exports as type-only
          let info = ExternalTypeInfo::type_only(ty, tad.name)
          module_types.add_export(tad.name, info)
        }

      // Exported interface
      InterfaceDeclaration(iface) =>
        if has_export_modifier_in_list(iface.modifiers) {
          let obj_type = interface_declaration_to_object_type(env, iface)
          module_types.interfaces.set(iface.name, obj_type)
          // Also add to named exports as type-only
          let info = ExternalTypeInfo::type_only(TObject(obj_type), iface.name)
          module_types.add_export(iface.name, info)
        }

      // Exported enum
      EnumDeclaration(ed) =>
        if has_export_modifier_in_list(ed.modifiers) {
          // Create a simple object type for the enum
          let ty = TAny // Enums are complex - use any for now
          let info = ExternalTypeInfo::value(ty, ed.name)
          module_types.add_export(ed.name, info)
        }

      // Module/Namespace declaration (e.g., declare module M1 { ... })
      // These become global namespaces in .d.ts files
      ModuleDeclaration(md) => {
        // Extract namespace members and add to global_namespaces
        let ns_type = module_declaration_to_object_type(
          env,
          bound_file.global_scope,
          md,
        )
        module_types.global_namespaces.set(md.name, ns_type)
      }

      // CommonJS: exports.xxx = value  or  module.exports = value
      ExpressionStatement(es) =>
        match es.expression {
          // exports.xxx = value
          BinaryExpression(be) if be.operator == Assign =>
            match be.left {
              // exports.propertyName = ... OR module.exports = ...
              PropertyAccessExpression(pae) =>
                match pae.expression {
                  Identifier(id) if id.name == "exports" => {
                    // Found exports.xxx = value, extract type from RHS
                    // Use context to resolve require() bindings
                    let ty = expression_to_type_v2_with_context(
                      cjs_ctx,
                      be.right,
                    )
                    let info = ExternalTypeInfo::value(ty, pae.name)
                    module_types.add_export(pae.name, info)
                  }
                  // module.exports = value (whole module assignment)
                  // pae.expression = Identifier("module"), pae.name = "exports"
                  Identifier(id) if id.name == "module" && pae.name == "exports" =>
                    // module.exports = value or module.exports = { ... }
                    extract_module_exports_assignment_with_context(
                      cjs_ctx,
                      module_types,
                      be.right,
                    )
                  // module.exports.xxx = value (nested property)
                  PropertyAccessExpression(inner_pae) =>
                    match inner_pae.expression {
                      Identifier(inner_id) if inner_id.name == "module" &&
                        inner_pae.name == "exports" => {
                        // module.exports.xxx = value
                        let ty = expression_to_type_v2_with_context(
                          cjs_ctx,
                          be.right,
                        )
                        let info = ExternalTypeInfo::value(ty, pae.name)
                        module_types.add_export(pae.name, info)
                      }
                      _ => ()
                    }
                  _ => ()
                }
              _ => ()
            }
          _ => ()
        }
      _ => ()
    }
  }
  module_types
}

///|
/// Extract exports from module.exports = expression
/// Handles: module.exports = { a, b } or module.exports = someValue
fn extract_module_exports_assignment(
  env : TypeEnv,
  module_types : ModuleTypes,
  expression : Node,
) -> Unit {
  // Use simple context for backward compatibility
  extract_module_exports_assignment_with_context(
    simple_cjs_context(env),
    module_types,
    expression,
  )
}

///|
/// Extract exports from module.exports = expression with CommonJS context
/// This version can resolve require() bindings for proper type inference
fn extract_module_exports_assignment_with_context(
  ctx : CommonJSTypeContext,
  module_types : ModuleTypes,
  expression : Node,
) -> Unit {
  match expression {
    // module.exports = { key1: value1, key2: value2 }
    ObjectLiteralExpression(ole) =>
      for prop in ole.properties {
        match prop {
          // PropertyAssignment(name: String, value: Node, location: SourceLocation)
          PropertyAssignment(name, value, _) =>
            if name.length() > 0 {
              let ty = expression_to_type_v2_with_context(ctx, value)
              let info = ExternalTypeInfo::value(ty, name)
              module_types.add_export(name, info)
            }
          // ShorthandProperty(name: String, location: SourceLocation)
          ShorthandProperty(name, _) => {
            // Try to resolve from require bindings
            let ty = resolve_identifier_type(ctx, name)
            let info = ExternalTypeInfo::value(ty, name)
            module_types.add_export(name, info)
          }
          _ => ()
        }
      }
    // module.exports = identifier (re-export everything from identifier)
    Identifier(id) => {
      // Try to resolve from require bindings
      let ty = resolve_identifier_type(ctx, id.name)
      match ty {
        TObject(obj) =>
          // Re-export all fields from the resolved type
          obj.fields.each(fn(field_name, field_info) {
            let info = ExternalTypeInfo::value(field_info.ty, field_name)
            module_types.add_export(field_name, info)
          })
        _ => () // Can't resolve, skip
      }
    }
    // module.exports = function() { ... }
    FunctionExpression(fe) => {
      let ty = function_expression_to_type_v2(ctx.env, fe)
      let info = ExternalTypeInfo::value(ty, "default")
      module_types.named_exports.set("default", info)
    }
    _ => ()
  }
}

///|
/// Convert a function expression to TypeV2
fn function_expression_to_type_v2(
  env : TypeEnv,
  fe : FunctionExpression,
) -> TypeV2 {
  let params : Array[ParamInfoV2] = []
  for param in fe.parameters {
    match param {
      Parameter(p) => {
        let param_name = match p.name {
          Identifier(id) => id.name
          _ => "_"
        }
        let param_type = match p.type_annotation {
          Some(type_node) => ast_type_to_v2(env, type_node)
          None => TAny
        }
        params.push(ParamInfoV2::{
          name: param_name,
          ty: param_type,
          optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }
  let return_type = match fe.return_type {
    Some(type_node) => ast_type_to_v2(env, type_node)
    None => TAny
  }
  TFunction(FunctionTypeV2::{
    type_params: [],
    params,
    rest_param: None,
    return_type,
    type_predicate: None,
    this_type: None,
  })
}

///|
/// Collect require() bindings from CommonJS variable declarations
/// Returns a map from variable name to resolved module path
fn collect_require_bindings(
  statements : Array[Node],
  current_file : String,
) -> Map[String, String] {
  let bindings : Map[String, String] = Map::new()
  for statement in statements {
    match statement {
      // var x = require('mod') or const x = require('mod')
      VariableStatement(vs) =>
        for vd in vs.declarations {
          // Check if initializer is a require() call
          match vd.initializer {
            Some(init) =>
              match init {
                CallExpression(ce) =>
                  // Check if this is require('...')
                  match ce.expression {
                    Identifier(id) if id.name == "require" =>
                      // Get the module specifier from the first argument
                      if ce.arguments.length() > 0 {
                        match ce.arguments[0] {
                          StringLiteral(sl) => {
                            // Get the variable name
                            let var_name = match vd.name {
                              Identifier(vid) => vid.name
                              _ => ""
                            }
                            if var_name.length() > 0 {
                              // Resolve the module path
                              let resolved = resolve_require_path(
                                sl.value,
                                current_file,
                              )
                              bindings.set(var_name, resolved)
                            }
                          }
                          _ => ()
                        }
                      }
                    _ => ()
                  }
                _ => ()
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  bindings
}

///|
/// Resolve a require() module specifier to an absolute path
fn resolve_require_path(specifier : String, current_file : String) -> String {
  if specifier.has_prefix("./") || specifier.has_prefix("../") {
    // Relative path - resolve relative to current file
    let dir = get_directory_from_path(current_file)
    let joined = if dir.length() > 0 {
      dir + "/" + specifier
    } else {
      specifier
    }
    // Normalize and return
    normalize_import_path(joined)
  } else {
    // Bare specifier (node_modules) - return as-is for now
    // The external registry will handle the mapping
    specifier
  }
}

///|
/// Context for CommonJS expression type inference
struct CommonJSTypeContext {
  env : TypeEnv
  require_bindings : Map[String, String] // variable name -> resolved module path
  external_registry : ExternalTypeRegistry?
}

///|
/// Create a simple context without require resolution
fn simple_cjs_context(env : TypeEnv) -> CommonJSTypeContext {
  CommonJSTypeContext::{
    env,
    require_bindings: Map::new(),
    external_registry: None,
  }
}

///|
/// Convert an expression to TypeV2 for CommonJS export type inference
fn expression_to_type_v2(env : TypeEnv, expr : Node) -> TypeV2 {
  // Use simple context for backward compatibility
  expression_to_type_v2_with_context(simple_cjs_context(env), expr)
}

///|
/// Convert an expression to TypeV2 with full CommonJS context for require resolution
fn expression_to_type_v2_with_context(
  ctx : CommonJSTypeContext,
  expr : Node,
) -> TypeV2 {
  match expr {
    // Literal values
    NumericLiteral(_) => TNumber
    StringLiteral(_) => TString
    BooleanLiteral(bl) =>
      if bl.value {
        TLiteralBool(true)
      } else {
        TLiteralBool(false)
      }
    NullLiteral(_) => TNull

    // Function expressions
    FunctionExpression(fe) => function_expression_to_type_v2(ctx.env, fe)
    ArrowFunction(af) => arrow_function_to_type_v2(ctx.env, af)

    // Object literals - create object type
    ObjectLiteralExpression(ole) => {
      let fields : Map[String, FieldInfoV2] = Map::new()
      for prop in ole.properties {
        match prop {
          // PropertyAssignment(name: String, value: Node, location: SourceLocation)
          PropertyAssignment(name, value, _) =>
            if name.length() > 0 {
              let ty = expression_to_type_v2_with_context(ctx, value)
              fields.set(name, FieldInfoV2::{
                ty,
                optional: false,
                is_readonly: false,
              })
            }
          // ShorthandProperty(name: String, location: SourceLocation)
          ShorthandProperty(name, _) => {
            // For shorthand properties, try to resolve from require bindings
            let ty = resolve_identifier_type(ctx, name)
            fields.set(name, FieldInfoV2::{
              ty,
              optional: false,
              is_readonly: false,
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

    // Array literals
    ArrayLiteralExpression(_) => TArray(TAny)

    // Identifiers - try to resolve from require bindings, then fallback to any
    Identifier(id) => resolve_identifier_type(ctx, id.name)

    // Property access on identifier - try to resolve the base from require bindings
    PropertyAccessExpression(pae) =>
      match pae.expression {
        Identifier(id) => {
          // Try to resolve base.property from require bindings
          let base_type = resolve_identifier_type(ctx, id.name)
          // If we got an object type, try to look up the property
          match base_type {
            TObject(obj) =>
              match obj.fields.get(pae.name) {
                Some(field) => field.ty
                None => TAny
              }
            _ => TAny
          }
        }
        _ => TAny
      }

    // Default to any for complex expressions
    _ => TAny
  }
}

///|
/// Resolve an identifier to its type using require bindings and external registry
fn resolve_identifier_type(ctx : CommonJSTypeContext, name : String) -> TypeV2 {
  // Check if this identifier is a require binding
  match ctx.require_bindings.get(name) {
    Some(module_path) =>
      // Found a require binding, try to resolve from external registry
      match ctx.external_registry {
        Some(registry) => {
          // First, resolve bare specifier to absolute path using module mappings
          // e.g., "m2" -> "/path/to/node_modules/m2/entry.js"
          let resolved_path = registry.resolve_module(module_path)

          // Get the module's exports as an object type
          match registry.get_module(resolved_path) {
            Some(module_types) => module_types_to_type_v2(module_types)
            None => TAny
          }
        }
        None => TAny
      }
    None => TAny
  }
}

///|
/// Convert ModuleTypes to a TypeV2 object type
fn module_types_to_type_v2(module_types : ModuleTypes) -> TypeV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()

  // Add all named exports as fields
  module_types.named_exports.each(fn(name, info) {
    if name != "default" {
      fields.set(name, FieldInfoV2::{
        ty: info.ty,
        optional: false,
        is_readonly: false,
      })
    }
  })
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
/// Convert an arrow function to TypeV2
fn arrow_function_to_type_v2(env : TypeEnv, af : ArrowFunction) -> TypeV2 {
  let params : Array[ParamInfoV2] = []
  for param in af.parameters {
    match param {
      Parameter(p) => {
        let param_name = match p.name {
          Identifier(id) => id.name
          _ => "_"
        }
        let param_type = match p.type_annotation {
          Some(type_node) => ast_type_to_v2(env, type_node)
          None => TAny
        }
        params.push(ParamInfoV2::{
          name: param_name,
          ty: param_type,
          optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }
  let return_type = match af.return_type {
    Some(type_node) => ast_type_to_v2(env, type_node)
    None => TAny
  }
  TFunction(FunctionTypeV2::{
    type_params: [],
    params,
    rest_param: None,
    return_type,
    type_predicate: None,
    this_type: None,
  })
}

///|
/// Convert a module/namespace declaration to an ObjectType
/// This extracts the exported members from the namespace
fn module_declaration_to_object_type(
  env : TypeEnv,
  scope : Scope,
  md : ModuleDeclaration,
) -> ObjectTypeV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  let call_signatures : Array[FunctionTypeV2] = []
  let construct_signatures : Array[FunctionTypeV2] = []

  // Look up the namespace symbol in the scope to get its exports
  match scope.symbols.get(md.name) {
    Some(symbol) =>
      match symbol.exports {
        Some(exports) =>
          // Process each exported member
          exports.each(fn(name, sym) {
            let ty = match sym.value_declaration {
              Some(FunctionDeclaration(fd)) =>
                function_declaration_to_type(env, fd)
              Some(VariableStatement(vs)) =>
                if vs.declarations.length() > 0 {
                  variable_declaration_to_type(env, vs.declarations[0])
                } else {
                  TAny
                }
              Some(ClassDeclaration(cd)) => class_declaration_to_type(env, cd)
              Some(InterfaceDeclaration(iface)) =>
                TObject(interface_declaration_to_object_type(env, iface))
              _ => TAny
            }
            fields.set(name, FieldInfoV2::{
              ty,
              optional: false,
              is_readonly: false,
            })
          })
        None => ()
      }
    None => ()
  }

  // Also scan the module body directly for declarations
  match md.body {
    Some(BlockStatement(block)) =>
      for stmt in block.statements {
        match stmt {
          FunctionDeclaration(fd) =>
            if has_export_modifier_in_list(fd.modifiers) {
              match fd.name {
                Some(Identifier(id)) => {
                  let ty = function_declaration_to_type(env, fd)
                  fields.set(id.name, FieldInfoV2::{
                    ty,
                    optional: false,
                    is_readonly: false,
                  })
                }
                _ => ()
              }
            }
          VariableStatement(vs) =>
            if has_export_modifier_in_list(vs.modifiers) {
              for decl in vs.declarations {
                match decl.name {
                  Identifier(id) => {
                    let ty = variable_declaration_to_type(env, decl)
                    fields.set(id.name, FieldInfoV2::{
                      ty,
                      optional: false,
                      is_readonly: false,
                    })
                  }
                  _ => ()
                }
              }
            }
          InterfaceDeclaration(iface) =>
            if has_export_modifier_in_list(iface.modifiers) {
              let ty = TObject(interface_declaration_to_object_type(env, iface))
              fields.set(iface.name, FieldInfoV2::{
                ty,
                optional: false,
                is_readonly: false,
              })
            }
          ClassDeclaration(cd) =>
            if has_export_modifier_in_list(cd.modifiers) {
              match cd.name {
                Some(Identifier(id)) => {
                  let ty = class_declaration_to_type(env, cd)
                  fields.set(id.name, FieldInfoV2::{
                    ty,
                    optional: false,
                    is_readonly: false,
                  })
                }
                _ => ()
              }
            }
          _ => ()
        }
      }
    _ => ()
  }
  ObjectTypeV2::{
    fields,
    symbol_fields: [],
    call_signatures,
    construct_signatures,
    index_signature: None,
    is_class: false,
    class_name: None,
  }
}

///|
/// Resolve the type of an export from the global scope
fn resolve_export_type(scope : Scope, name : String, env : TypeEnv) -> TypeV2 {
  match scope.symbols.get(name) {
    None => TAny
    Some(symbol) =>
      match symbol.value_declaration {
        None => TAny
        Some(decl) =>
          match decl {
            FunctionDeclaration(fd) => function_declaration_to_type(env, fd)
            ClassDeclaration(cd) => class_declaration_to_type(env, cd)
            VariableStatement(vs) =>
              // Get the type of the first declaration
              if vs.declarations.length() > 0 {
                variable_declaration_to_type(env, vs.declarations[0])
              } else {
                TAny
              }
            TypeAliasDeclaration(tad) => ast_type_to_v2(env, tad.type_node)
            InterfaceDeclaration(iface) =>
              TObject(interface_declaration_to_object_type(env, iface))
            _ => TAny
          }
      }
  }
}

///|
/// Convert a class declaration to TypeV2
fn class_declaration_to_type(env : TypeEnv, cd : ClassDeclaration) -> TypeV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  let call_signatures : Array[FunctionTypeV2] = []
  let construct_signatures : Array[FunctionTypeV2] = []
  for mem in cd.members {
    match mem {
      PropertyDeclaration(prop) => {
        let ty = match prop.type_annotation {
          Some(type_node) => ast_type_to_v2(env, type_node)
          None => TAny
        }
        fields.set(prop.name, FieldInfoV2::{
          ty,
          optional: prop.is_optional,
          is_readonly: false,
        })
      }
      MethodDeclaration(meth) => {
        let params = meth.parameters.map(fn(p) {
          match p {
            Parameter(param) => {
              let ty = match param.type_annotation {
                Some(type_node) => ast_type_to_v2(env, type_node)
                None => TAny
              }
              ParamInfoV2::{
                name: match param.name {
                  Identifier(id) => id.name
                  _ => "arg"
                },
                ty,
                optional: param.is_optional,
                is_rest: param.is_rest,
              }
            }
            _ => ParamInfoV2::required("arg", TAny)
          }
        })
        let return_ty = match meth.return_type {
          Some(type_node) => ast_type_to_v2(env, type_node)
          None => TAny
        }
        let func_type = FunctionTypeV2::{
          type_params: [],
          params,
          rest_param: None,
          return_type: return_ty,
          type_predicate: None,
          this_type: None,
        }
        fields.set(meth.name, FieldInfoV2::{
          ty: TFunction(func_type),
          optional: meth.is_optional,
          is_readonly: false,
        })
      }
      ConstructorDeclaration(ctor) => {
        let params = ctor.parameters.map(fn(p) {
          match p {
            Parameter(param) => {
              let ty = match param.type_annotation {
                Some(type_node) => ast_type_to_v2(env, type_node)
                None => TAny
              }
              ParamInfoV2::{
                name: match param.name {
                  Identifier(id) => id.name
                  _ => "arg"
                },
                ty,
                optional: param.is_optional,
                is_rest: param.is_rest,
              }
            }
            _ => ParamInfoV2::required("arg", TAny)
          }
        })
        let class_name = match cd.name {
          Some(Identifier(id)) => Some(id.name)
          _ => None
        }
        let instance_type = TObject(ObjectTypeV2::{
          fields,
          symbol_fields: [],
          call_signatures: [],
          construct_signatures: [],
          index_signature: None,
          is_class: true,
          class_name,
        })
        construct_signatures.push(FunctionTypeV2::{
          type_params: [],
          params,
          rest_param: None,
          return_type: instance_type,
          type_predicate: None,
          this_type: None,
        })
      }
      _ => ()
    }
  }

  // Return the class type (with construct signature)
  TObject(ObjectTypeV2::{
    fields,
    symbol_fields: [],
    call_signatures,
    construct_signatures,
    index_signature: None,
    is_class: true,
    class_name: match cd.name {
      Some(Identifier(id)) => Some(id.name)
      _ => None
    },
  })
}

///|
/// Convert a variable declaration to TypeV2
fn variable_declaration_to_type(
  env : TypeEnv,
  decl : VariableDeclaration,
) -> TypeV2 {
  match decl.type_annotation {
    Some(type_node) => ast_type_to_v2(env, type_node)
    None =>
      // Try to infer from initializer
      match decl.initializer {
        Some(StringLiteral(_)) => TString
        Some(NumericLiteral(_)) => TNumber
        Some(BooleanLiteral(_)) => TBoolean
        Some(NullLiteral(_)) => TNull
        _ => TAny
      }
  }
}

///|
/// Extract module types from source code string for cross-file type checking.
/// This parses, binds, and extracts types in one step.
pub fn extract_module_types_from_source(
  source : String,
  file_path : String,
) -> ModuleTypes? {
  // Parse and bind the source
  match parse_and_bind(source, file_path) {
    Ok(bound_file) => Some(extract_module_types(bound_file, file_path))
    Err(_) => None
  }
}

// Suppress warnings for functions reserved for future use

///|
fn init {
  ignore(check_type_arguments)
  ignore(get_class_name_from_symbol_declarations)
  ignore(check_enum_members)
}
