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
/// Type checker state
pub struct TypeChecker {
  next_type_id : Int
  type_cache : Map[String, Type]
  symbol_types : Map[Int, Type] // Symbol ID -> Type
  node_types : Map[String, Type] // Node identifier -> Type
  diagnostics : Array[Diagnostic]
  file_path : String
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
pub fn TypeChecker::new(file_path : String) -> TypeChecker {
  {
    next_type_id: 0,
    type_cache: Map::new(),
    symbol_types: Map::new(),
    node_types: Map::new(),
    diagnostics: [],
    file_path,
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
// Type Checking Entry Point
// ============================================================================

///|
/// Check a bound source file
pub fn check_source_file(
  bound : BoundSourceFile
) -> CheckResult {
  let checker = TypeChecker::new(bound.file_path)
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
  statements : Array[Node]
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
    ExpressionStatement(expr_stmt) => check_expression_statement(
      checker,
      expr_stmt,
    )
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
  var_stmt : VariableStatement
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
  decl : VariableDeclaration
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
    (Some(decl_t), Some(init_t)) => {
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
  expr_stmt : ExpressionStatement
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
    Identifier(id) => {
      // Check for undefined identifier
      if id.name == "undefined" {
        undefined_type(checker)
      } else {
        infer_identifier_type(checker, id)
      }
    }
    BinaryExpression(bin_expr) => infer_binary_expression_type(checker, bin_expr)
    UnaryExpression(un_expr) => infer_unary_expression_type(checker, un_expr)
    CallExpression(call) => infer_call_expression_type(checker, call)
    PropertyAccessExpression(prop) => infer_property_access_type(checker, prop)
    ElementAccessExpression(elem) => infer_element_access_type(checker, elem)
    ArrayLiteralExpression(arr) => infer_array_literal_type(checker, arr)
    ObjectLiteralExpression(obj) => infer_object_literal_type(checker, obj)
    ArrowFunction(arrow) => infer_arrow_function_type(checker, arrow)
    ConditionalExpression(cond) => infer_conditional_type(checker, cond)
    NewExpression(new_expr) => infer_new_expression_type(checker, new_expr)
    TemplateExpression(template) => infer_template_expression_type(checker, template)
    ThisExpression(_) => infer_this_type(checker)
    SpreadExpression(spread) => infer_type(checker, spread.expression)
    _ => any_type(checker) // Fallback for unhandled expressions
  }
}

///|
/// Infer identifier type
fn infer_identifier_type(
  checker : TypeChecker,
  id : Identifier
) -> (Type, TypeChecker) {
  // TODO: Look up symbol in scope and get its type
  // For now, return any type
  any_type(checker)
}

///|
/// Infer binary expression type
fn infer_binary_expression_type(
  checker : TypeChecker,
  bin_expr : BinaryExpression
) -> (Type, TypeChecker) {
  let (left_type, checker) = infer_type(checker, bin_expr.left)
  let (right_type, checker) = infer_type(checker, bin_expr.right)

  // Determine result type based on operator
  match bin_expr.operator {
    // Addition: can be number + number -> number OR string + string -> string
    Add => {
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
    }
    // Arithmetic operators: number op number -> number
    Subtract
    | Multiply
    | Divide
    | Remainder
    | Exponentiate => {
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
    _ => any_type(checker)
  }
}

///|
/// Infer unary expression type
fn infer_unary_expression_type(
  checker : TypeChecker,
  un_expr : UnaryExpression
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
/// Infer call expression type
fn infer_call_expression_type(
  checker : TypeChecker,
  call : CallExpression
) -> (Type, TypeChecker) {
  let (func_type, checker) = infer_type(checker, call.expression)

  // Check arguments
  let mut checker = checker
  for i = 0; i < call.arguments.length(); i = i + 1 {
    let (_, c) = infer_type(checker, call.arguments[i])
    checker = c
  }

  // TODO: Check function signature and return appropriate type
  any_type(checker)
}

///|
/// Infer property access type
fn infer_property_access_type(
  checker : TypeChecker,
  prop : PropertyAccessExpression
) -> (Type, TypeChecker) {
  let (object_type, checker) = infer_type(checker, prop.expression)
  // TODO: Look up property in object type
  match object_type {
    Object(obj_type) => {
      match obj_type.properties.get(prop.name) {
        Some(property) => (property.prop_type, checker)
        None => any_type(checker)
      }
    }
    _ => any_type(checker)
  }
}

///|
/// Infer element access type (bracket notation)
fn infer_element_access_type(
  checker : TypeChecker,
  elem : ElementAccessExpression
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
  new_expr : NewExpression
) -> (Type, TypeChecker) {
  let (_, checker) = infer_type(checker, new_expr.expression)

  // Check arguments if present
  let mut checker = checker
  match new_expr.arguments {
    Some(args) => {
      for i = 0; i < args.length(); i = i + 1 {
        let (_, c) = infer_type(checker, args[i])
        checker = c
      }
    }
    None => ()
  }

  // TODO: Return the constructed instance type based on constructor
  any_type(checker)
}

///|
/// Infer template expression type
fn infer_template_expression_type(
  checker : TypeChecker,
  template : TemplateExpression
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
/// Infer array literal type
fn infer_array_literal_type(
  checker : TypeChecker,
  arr : ArrayLiteralExpression
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
  obj : ObjectLiteralExpression
) -> (Type, TypeChecker) {
  let mut checker = checker
  let properties = Map::new()

  for i = 0; i < obj.properties.length(); i = i + 1 {
    match obj.properties[i] {
      PropertyAssignment(name, value, _) => {
        let (prop_type, c) = infer_type(checker, value)
        properties.set(
          name,
          { name, prop_type, is_optional: false, is_readonly: false },
        )
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
  arrow : ArrowFunction
) -> (Type, TypeChecker) {
  // Build parameter list
  let parameters = []
  let mut checker = checker
  for i = 0; i < arrow.parameters.length(); i = i + 1 {
    match arrow.parameters[i] {
      Parameter(param) => {
        let (param_type, c) = match param.type_annotation {
          Some(type_node) => {
            match get_type_from_type_node(checker, type_node) {
              (Some(t), c2) => (t, c2)
              (None, c2) => any_type(c2)
            }
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
    Some(type_node) => {
      match get_type_from_type_node(checker, type_node) {
        (Some(t), c) => (t, c)
        (None, c) => any_type(c)
      }
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
  cond : ConditionalExpression
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
    // Unknown is only assignable to unknown or any
    (Unknown(_), Unknown(_)) => true
    (Unknown(_), Any(_)) => true
    // Same primitive types
    (Number(_), Number(_)) => true
    (String(_), String(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Void(_), Void(_)) => true
    (Undefined(_), Undefined(_)) => true
    (Null(_), Null(_)) => true
    // Undefined and null are assignable to most types (like TypeScript)
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
    // Union type assignability - source is assignable to union if assignable to any member
    (source, Union(union)) => is_assignable_to_union(source, union)
    // Union source is assignable to target if all members are assignable
    (Union(union), target) => is_union_assignable_to(union, target)
    // Array types
    (Array(source_arr), Array(target_arr)) => is_assignable(
      source_arr.element_type,
      target_arr.element_type,
    )
    // Object types - structural typing
    (Object(source_obj), Object(target_obj)) => is_object_assignable(
      source_obj,
      target_obj,
    )
    // Function types - check parameter and return types
    (Function(source_fn), Function(target_fn)) => is_function_assignable(
      source_fn,
      target_fn,
    )
    _ => false
  }
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
fn is_object_assignable(
  source : ObjectType,
  target : ObjectType
) -> Bool {
  // Check that all required properties in target exist in source
  let target_props = target.properties.iter()
  let mut assignable = true
  for entry in target_props {
    let (prop_name, target_prop) = entry
    match source.properties.get(prop_name) {
      Some(source_prop) => {
        if !is_assignable(source_prop.prop_type, target_prop.prop_type) {
          assignable = false
          break
        }
      }
      None => {
        if !target_prop.is_optional {
          assignable = false
          break
        }
      }
    }
  }
  assignable
}

///|
/// Check if source function is assignable to target function
fn is_function_assignable(
  source : CheckerFunctionType,
  target : CheckerFunctionType
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
    if !is_assignable(target.parameters[i].param_type, source.parameters[i].param_type) {
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
      checker,
      "Left operand must be of type 'number'",
      location,
      2363,
    )
  } else {
    checker
  }

  if !is_numeric_type(right) {
    add_diagnostic(
      checker,
      "Right operand must be of type 'number'",
      location,
      2363,
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
    add_diagnostic(
      checker,
      "Operand must be of type 'number'",
      location,
      2363,
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
  func : FunctionDeclaration
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
  ret : ReturnStatement
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
/// Check if statement
fn check_if_statement(
  checker : TypeChecker,
  if_stmt : IfStatement
) -> TypeChecker {
  let (_, checker) = infer_type(checker, if_stmt.condition)
  let checker = check_statement(checker, if_stmt.then_statement)
  match if_stmt.else_statement {
    Some(else_stmt) => check_statement(checker, else_stmt)
    None => checker
  }
}

///|
/// Check while statement
fn check_while_statement(
  checker : TypeChecker,
  while_stmt : WhileStatement
) -> TypeChecker {
  let (_, checker) = infer_type(checker, while_stmt.condition)
  check_statement(checker, while_stmt.statement)
}

///|
/// Check do-while statement
fn check_do_while_statement(
  checker : TypeChecker,
  do_while : DoWhileStatement
) -> TypeChecker {
  let checker = check_statement(checker, do_while.statement)
  let (_, checker) = infer_type(checker, do_while.condition)
  checker
}

///|
/// Check for statement
fn check_for_statement(
  checker : TypeChecker,
  for_stmt : ForStatement
) -> TypeChecker {
  // Check initializer
  let checker = match for_stmt.initializer {
    Some(VariableStatement(var_stmt)) => check_variable_statement(
      checker,
      var_stmt,
    )
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
  block : BlockStatement
) -> TypeChecker {
  check_statements(checker, block.statements)
}

///|
/// Check class declaration
fn check_class_declaration(
  checker : TypeChecker,
  class_decl : ClassDeclaration
) -> TypeChecker {
  // TODO: Check class members
  checker
}

///|
/// Check enum declaration
fn check_enum_declaration(
  checker : TypeChecker,
  enum_decl : EnumDeclaration
) -> TypeChecker {
  // TODO: Check enum members
  checker
}

///|
/// Check try statement
fn check_try_statement(
  checker : TypeChecker,
  try_stmt : TryStatement
) -> TypeChecker {
  let checker = check_statement(checker, try_stmt.try_block)

  let checker = match try_stmt.catch_clause {
    Some(catch_clause) => check_statement(checker, catch_clause.block)
    None => checker
  }

  match try_stmt.finally_block {
    Some(finally) => check_statement(checker, finally)
    None => checker
  }
}

///|
/// Check throw statement
fn check_throw_statement(
  checker : TypeChecker,
  throw_stmt : ThrowStatement
) -> TypeChecker {
  let (_, checker) = infer_type(checker, throw_stmt.expression)
  checker
}

///|
/// Check switch statement
fn check_switch_statement(
  checker : TypeChecker,
  switch_stmt : SwitchStatement
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
      None => {
        // Default case
        checker = check_statements(checker, case_clause.statements)
      }
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
  type_node : Node
) -> (Type?, TypeChecker) {
  match type_node {
    // Handle keyword types (from parser)
    KeywordType(kw_type) => {
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
          (None, c) => {
            checker = c
          }
        }
      }
      let (info, checker) = create_type_info(checker)
      (Some(Union({ types, info })), checker)
    }
    TypeReference(type_ref) => {
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
        _ => (None, checker)
      }
    }
    ArrayType(array_type) => {
      // Handle array types
      match get_type_from_type_node(checker, array_type.element_type) {
        (Some(element_type), c) => {
          let (info, c2) = create_type_info(c)
          (Some(Array({ element_type, info })), c2)
        }
        (None, c) => (None, c)
      }
    }
    _ => (None, checker)
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
    Function(_) => "function"
    Object(_) => "object"
    TypeReference(ref) => ref.name
    Error(_) => "error"
  }
}
