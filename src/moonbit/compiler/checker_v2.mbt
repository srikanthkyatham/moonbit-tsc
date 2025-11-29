// Bidirectional Type Checker V2
// Implements the guide's approach with Direction-based checking
// This provides the core framework - detailed node handlers can be added incrementally

///|
/// Result of bidirectional type checking
pub struct CheckResultV2 {
  ty : TypeV2
  narrowing : Narrowing
  errors : Array[TypeMismatchError]
} derive(Show)

///|
/// Create a successful check result
pub fn CheckResultV2::ok(ty : TypeV2) -> CheckResultV2 {
  { ty, narrowing: NNone, errors: [] }
}

///|
/// Create a check result with narrowing info
pub fn CheckResultV2::with_narrowing(
  ty : TypeV2,
  narrowing : Narrowing,
) -> CheckResultV2 {
  { ty, narrowing, errors: [] }
}

///|
/// Create an error result
pub fn CheckResultV2::error(
  ty : TypeV2,
  err : TypeMismatchError,
) -> CheckResultV2 {
  { ty, narrowing: NNone, errors: [err] }
}

///|
/// Create result with multiple errors
pub fn CheckResultV2::errors(
  ty : TypeV2,
  errs : Array[TypeMismatchError],
) -> CheckResultV2 {
  { ty, narrowing: NNone, errors: errs }
}

///|
/// Check if result has errors
pub fn CheckResultV2::has_errors(self : CheckResultV2) -> Bool {
  not(self.errors.is_empty())
}

///|
/// Combine errors from two results
pub fn CheckResultV2::combine_errors(
  self : CheckResultV2,
  other : CheckResultV2,
) -> CheckResultV2 {
  let combined : Array[TypeMismatchError] = []
  combined.append(self.errors)
  combined.append(other.errors)
  { ty: self.ty, narrowing: self.narrowing, errors: combined }
}

// ============================================================================
// Core Bidirectional Type Checking
// ============================================================================

///|
/// Bidirectional type check an expression
/// dir = Infer: synthesize (infer) the type
/// dir = Check(expected): check against expected type
pub fn check_expr_v2(
  env : TypeEnv,
  node : Node,
  dir : Direction,
) -> CheckResultV2 {
  match dir {
    Infer => infer_expr_v2(env, node)
    Check(expected) => check_against_v2(env, node, expected)
  }
}

///|
/// Infer (synthesize) the type of an expression
pub fn infer_expr_v2(env : TypeEnv, node : Node) -> CheckResultV2 {
  match node {
    // Literals - direct type synthesis
    NumericLiteral(lit) => {
      let num_val = @strconv.parse_double(lit.value) catch { _ => 0.0 }
      CheckResultV2::ok(TLiteralNumber(num_val))
    }
    StringLiteral(lit) => CheckResultV2::ok(TLiteralString(lit.value))
    BooleanLiteral(lit) => CheckResultV2::ok(TLiteralBool(lit.value))
    NullLiteral(_) => CheckResultV2::ok(TNull)
    BigIntLiteral(lit) => CheckResultV2::ok(TLiteralBigInt(lit.value))

    // Identifier - lookup in environment
    Identifier(id) =>
      match env.lookup(id.name) {
        Some(ty) => CheckResultV2::ok(ty)
        None => CheckResultV2::error(TError, unbound_variable_error(id.name))
      }

    // Array literal
    ArrayLiteralExpression(arr) =>
      infer_array_literal_elements_v2(env, arr.elements)

    // Object literal
    ObjectLiteralExpression(obj) => infer_object_literal_v2(env, obj.properties)

    // Function expression
    FunctionExpression(func) => infer_function_v2(env, func)
    ArrowFunction(arrow) => infer_arrow_v2(env, arrow)

    // Call expression
    CallExpression(call) => infer_call_v2(env, call)

    // Property access
    PropertyAccessExpression(prop) => infer_property_access_v2(env, prop)
    ElementAccessExpression(elem) => infer_element_access_v2(env, elem)

    // Binary expression
    BinaryExpression(bin) => infer_binary_v2(env, bin)

    // Unary expression
    UnaryExpression(un) => infer_unary_v2(env, un)

    // Conditional expression
    ConditionalExpression(cond) => infer_conditional_v2(env, cond)

    // New expression
    NewExpression(new_expr) => infer_new_v2(env, new_expr)

    // Template expression
    TemplateExpression(_) => CheckResultV2::ok(TString)

    // Parenthesized - unwrap
    ParenthesizedExpression(paren) => infer_expr_v2(env, paren.expression)

    // Type assertion (as T)
    AsExpression(_) => CheckResultV2::ok(TAny) // Would need type conversion

    // Await expression
    AwaitExpression(await_expr) => {
      let result = infer_expr_v2(env, await_expr.expression)
      // Unwrap Promise<T> to T
      match result.ty {
        TGenericInstance(name, args) if name == "Promise" && args.length() > 0 =>
          CheckResultV2::ok(args[0])
        other => CheckResultV2::ok(other)
      }
    }

    // Spread
    SpreadExpression(spread) => infer_expr_v2(env, spread.expression)

    // This expression
    ThisExpression(_) => CheckResultV2::ok(TAny) // Would need this context

    // Default for unhandled nodes
    _ => CheckResultV2::ok(TAny)
  }
}

///|
/// Check an expression against an expected type
pub fn check_against_v2(
  env : TypeEnv,
  node : Node,
  expected : TypeV2,
) -> CheckResultV2 {
  // First try to use the expected type to guide checking
  match node {
    // For literals, infer and then check compatibility
    NumericLiteral(_) | StringLiteral(_) | BooleanLiteral(_) | NullLiteral(_) => {
      let inferred = infer_expr_v2(env, node)
      check_assignable_v2(inferred.ty, expected, PRoot)
    }

    // Array literal - push expected element type down
    ArrayLiteralExpression(arr) =>
      match expected {
        TArray(elem_ty) => check_array_literal_v2(env, arr.elements, elem_ty)
        _ => {
          let inferred = infer_array_literal_elements_v2(env, arr.elements)
          check_assignable_v2(inferred.ty, expected, PRoot)
        }
      }

    // Object literal - push expected property types down
    ObjectLiteralExpression(obj) =>
      match expected {
        TObject(obj_ty) => check_object_literal_v2(env, obj.properties, obj_ty)
        _ => {
          let inferred = infer_object_literal_v2(env, obj.properties)
          check_assignable_v2(inferred.ty, expected, PRoot)
        }
      }

    // Function - push expected return type down
    FunctionExpression(func) =>
      match expected {
        TFunction(func_ty) => check_function_v2(env, func, func_ty)
        _ => {
          let inferred = infer_function_v2(env, func)
          check_assignable_v2(inferred.ty, expected, PRoot)
        }
      }
    ArrowFunction(arrow) =>
      match expected {
        TFunction(func_ty) => check_arrow_v2(env, arrow, func_ty)
        _ => {
          let inferred = infer_arrow_v2(env, arrow)
          check_assignable_v2(inferred.ty, expected, PRoot)
        }
      }

    // Default: infer then check
    _ => {
      let inferred = infer_expr_v2(env, node)
      if inferred.has_errors() {
        inferred
      } else {
        check_assignable_v2(inferred.ty, expected, PRoot)
      }
    }
  }
}

// ============================================================================
// Specific Expression Type Inference
// ============================================================================

///|
/// Infer type of array literal from Node? elements
fn infer_array_literal_elements_v2(
  env : TypeEnv,
  elements : Array[Node?],
) -> CheckResultV2 {
  if elements.is_empty() {
    return CheckResultV2::ok(TArray(TAny))
  }
  let elem_types : Array[TypeV2] = []
  let all_errors : Array[TypeMismatchError] = []
  for elem in elements {
    match elem {
      Some(expr) => {
        let result = infer_expr_v2(env, expr)
        elem_types.push(result.ty)
        all_errors.append(result.errors)
      }
      None => () // Hole in array
    }
  }

  // Find common type (simplified - just union all)
  let unified = if elem_types.is_empty() {
    TAny
  } else {
    make_union(elem_types)
  }
  { ty: TArray(unified), narrowing: NNone, errors: all_errors }
}

///|
/// Check array literal against expected element type
fn check_array_literal_v2(
  env : TypeEnv,
  elements : Array[Node?],
  expected_elem : TypeV2,
) -> CheckResultV2 {
  let all_errors : Array[TypeMismatchError] = []
  for i, elem in elements {
    match elem {
      Some(expr) => {
        let result = check_against_v2(env, expr, expected_elem)
        if result.has_errors() {
          for err in result.errors {
            all_errors.push(TypeMismatchError::{
              path: PIndex(err.path, i),
              expected: err.expected,
              actual: err.actual,
              reason: err.reason,
              children: err.children,
              suggestions: err.suggestions,
            })
          }
        }
      }
      None => () // Hole in array
    }
  }
  { ty: TArray(expected_elem), narrowing: NNone, errors: all_errors }
}

///|
/// Infer type of object literal
fn infer_object_literal_v2(
  env : TypeEnv,
  properties : Array[ObjectProperty],
) -> CheckResultV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  let all_errors : Array[TypeMismatchError] = []
  for prop in properties {
    match prop {
      PropertyAssignment(name, value, _) => {
        let result = infer_expr_v2(env, value)
        fields.set(name, FieldInfoV2::required(result.ty))
        all_errors.append(result.errors)
      }
      ShorthandProperty(name, _) =>
        // Shorthand property - lookup in environment
        match env.lookup(name) {
          Some(ty) => fields.set(name, FieldInfoV2::required(ty))
          None => all_errors.push(unbound_variable_error(name))
        }
      SpreadAssignment(spread_expr, _) => {
        let result = infer_expr_v2(env, spread_expr)
        // For spread, merge fields from the spread expression
        match result.ty {
          TObject(obj) =>
            for kv in obj.fields {
              fields.set(kv.0, kv.1)
            }
          _ => ()
        }
        all_errors.append(result.errors)
      }
      MethodDeclaration(name, func_expr, _) => {
        let result = infer_function_v2(env, func_expr)
        fields.set(name, FieldInfoV2::required(result.ty))
        all_errors.append(result.errors)
      }
      GetAccessor(name, func_expr, _) => {
        let result = infer_function_v2(env, func_expr)
        match result.ty {
          TFunction(f) => fields.set(name, FieldInfoV2::required(f.return_type))
          _ => fields.set(name, FieldInfoV2::required(TAny))
        }
      }
      SetAccessor(name, _, _) =>
        // Setter has void return, we infer any for the property
        fields.set(name, FieldInfoV2::required(TAny))
      ComputedPropertyAssignment(_, value, _) => {
        // For computed properties, we can't statically know the key
        let result = infer_expr_v2(env, value)
        all_errors.append(result.errors)
      }
    }
  }
  let obj_ty = ObjectTypeV2::{
    fields,
    call_signatures: [],
    construct_signatures: [],
    index_signature: None,
    is_class: false,
    class_name: None,
  }
  { ty: TObject(obj_ty), narrowing: NNone, errors: all_errors }
}

///|
/// Check object literal against expected object type
fn check_object_literal_v2(
  env : TypeEnv,
  properties : Array[ObjectProperty],
  expected : ObjectTypeV2,
) -> CheckResultV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  let all_errors : Array[TypeMismatchError] = []
  let provided_props : Array[String] = []
  for prop in properties {
    match prop {
      PropertyAssignment(name, value, _) => {
        provided_props.push(name)
        match expected.fields.get(name) {
          Some(expected_field) => {
            let result = check_against_v2(env, value, expected_field.ty)
            fields.set(name, FieldInfoV2::required(result.ty))
            if result.has_errors() {
              for err in result.errors {
                all_errors.push(property_mismatch_error(name, err))
              }
            }
          }
          None => {
            // Excess property check
            let result = infer_expr_v2(env, value)
            fields.set(name, FieldInfoV2::required(result.ty))
            all_errors.push(excess_property_error(PProperty(PRoot, name), name))
          }
        }
      }
      ShorthandProperty(name, _) => {
        provided_props.push(name)
        match env.lookup(name) {
          Some(ty) => {
            fields.set(name, FieldInfoV2::required(ty))
            match expected.fields.get(name) {
              Some(expected_field) => {
                let compat = check_assignable_v2(
                  ty,
                  expected_field.ty,
                  PProperty(PRoot, name),
                )
                all_errors.append(compat.errors)
              }
              None =>
                all_errors.push(
                  excess_property_error(PProperty(PRoot, name), name),
                )
            }
          }
          None => all_errors.push(unbound_variable_error(name))
        }
      }
      SpreadAssignment(spread_expr, _) => {
        let result = infer_expr_v2(env, spread_expr)
        match result.ty {
          TObject(obj) =>
            for kv in obj.fields {
              provided_props.push(kv.0)
              fields.set(kv.0, kv.1)
            }
          _ => ()
        }
        all_errors.append(result.errors)
      }
      MethodDeclaration(name, func_expr, _) => {
        provided_props.push(name)
        match expected.fields.get(name) {
          Some(expected_field) =>
            match expected_field.ty {
              TFunction(expected_func) => {
                let result = check_function_v2(env, func_expr, expected_func)
                fields.set(name, FieldInfoV2::required(result.ty))
                all_errors.append(result.errors)
              }
              _ => {
                let result = infer_function_v2(env, func_expr)
                fields.set(name, FieldInfoV2::required(result.ty))
              }
            }
          None => {
            let result = infer_function_v2(env, func_expr)
            fields.set(name, FieldInfoV2::required(result.ty))
            all_errors.push(excess_property_error(PProperty(PRoot, name), name))
          }
        }
      }
      GetAccessor(name, func_expr, _) => {
        provided_props.push(name)
        let result = infer_function_v2(env, func_expr)
        match result.ty {
          TFunction(f) => fields.set(name, FieldInfoV2::required(f.return_type))
          _ => fields.set(name, FieldInfoV2::required(TAny))
        }
      }
      SetAccessor(name, _, _) => {
        provided_props.push(name)
        fields.set(name, FieldInfoV2::required(TAny))
      }
      ComputedPropertyAssignment(_, value, _) => {
        let result = infer_expr_v2(env, value)
        all_errors.append(result.errors)
      }
    }
  }

  // Check for missing required properties
  for kv in expected.fields {
    let name = kv.0
    let field = kv.1
    if not(field.optional) &&
      not(provided_props.iter().any(fn(p) { p == name })) {
      all_errors.push(
        missing_property_error(
          PProperty(PRoot, name),
          name,
          find_similar_properties(name, provided_props),
        ),
      )
    }
  }
  let obj_ty = ObjectTypeV2::{
    fields,
    call_signatures: [],
    construct_signatures: [],
    index_signature: None,
    is_class: false,
    class_name: None,
  }
  { ty: TObject(obj_ty), narrowing: NNone, errors: all_errors }
}

///|
/// Infer function type
fn infer_function_v2(env : TypeEnv, func : FunctionExpression) -> CheckResultV2 {
  let params : Array[ParamInfoV2] = []
  let mut child_env = env.child()

  // Add parameters to environment
  for param in func.parameters {
    let param_name = get_param_name_v2(param)
    let param_ty = TAny // Would need type annotation parsing
    params.push(ParamInfoV2::required(param_name, param_ty))
    child_env = child_env.with_variable(param_name, param_ty)
  }

  // Infer return type from body
  let return_ty = infer_block_return_v2(child_env, func.body)
  let func_ty = FunctionTypeV2::{
    type_params: [],
    params,
    rest_param: None,
    return_type: return_ty,
  }
  CheckResultV2::ok(TFunction(func_ty))
}

///|
/// Check function against expected function type
fn check_function_v2(
  env : TypeEnv,
  func : FunctionExpression,
  expected : FunctionTypeV2,
) -> CheckResultV2 {
  let mut child_env = env.child()
  let all_errors : Array[TypeMismatchError] = []

  // Add parameters with expected types
  for i, param in func.parameters {
    let param_name = get_param_name_v2(param)
    let param_ty = if i < expected.params.length() {
      expected.params[i].ty
    } else {
      TAny
    }
    child_env = child_env.with_variable(param_name, param_ty)
  }

  // Check body against expected return type
  let body_result = check_block_return_v2(
    child_env,
    func.body,
    expected.return_type,
  )
  all_errors.append(body_result.errors)
  { ty: TFunction(expected), narrowing: NNone, errors: all_errors }
}

///|
/// Infer arrow function type
fn infer_arrow_v2(env : TypeEnv, arrow : ArrowFunction) -> CheckResultV2 {
  let params : Array[ParamInfoV2] = []
  let mut child_env = env.child()
  for param in arrow.parameters {
    let param_name = get_param_name_v2(param)
    let param_ty = TAny
    params.push(ParamInfoV2::required(param_name, param_ty))
    child_env = child_env.with_variable(param_name, param_ty)
  }
  let return_ty = match arrow.body {
    BlockStatement(block) =>
      infer_block_return_from_stmts_v2(child_env, block.statements)
    expr => {
      let result = infer_expr_v2(child_env, expr)
      result.ty
    }
  }
  let func_ty = FunctionTypeV2::{
    type_params: [],
    params,
    rest_param: None,
    return_type: return_ty,
  }
  CheckResultV2::ok(TFunction(func_ty))
}

///|
/// Check arrow function against expected type
fn check_arrow_v2(
  env : TypeEnv,
  arrow : ArrowFunction,
  expected : FunctionTypeV2,
) -> CheckResultV2 {
  let mut child_env = env.child()
  let all_errors : Array[TypeMismatchError] = []
  for i, param in arrow.parameters {
    let param_name = get_param_name_v2(param)
    let param_ty = if i < expected.params.length() {
      expected.params[i].ty
    } else {
      TAny
    }
    child_env = child_env.with_variable(param_name, param_ty)
  }
  match arrow.body {
    BlockStatement(block) => {
      let body_result = check_block_return_from_stmts_v2(
        child_env,
        block.statements,
        expected.return_type,
      )
      all_errors.append(body_result.errors)
    }
    expr => {
      let result = check_against_v2(child_env, expr, expected.return_type)
      all_errors.append(result.errors)
    }
  }
  { ty: TFunction(expected), narrowing: NNone, errors: all_errors }
}

///|
/// Extract narrowing from a call expression (e.g., Array.isArray(x))
fn extract_call_narrowing(call : CallExpression) -> Narrowing {
  // Check for Array.isArray(x)
  match call.expression {
    PropertyAccessExpression(prop) =>
      if prop.name == "isArray" {
        match prop.expression {
          Identifier(id) if id.name == "Array" => {
            // This is Array.isArray(...)
            if call.arguments.length() == 1 {
              match call.arguments[0] {
                Identifier(arg_id) => return NIsArray(arg_id.name)
                _ => ()
              }
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
  NNone
}

///|
/// Infer call expression type
/// Supports generic function calls with type argument inference and constraint checking
fn infer_call_v2(env : TypeEnv, call : CallExpression) -> CheckResultV2 {
  let callee_result = infer_expr_v2(env, call.expression)

  // Extract narrowing from special call patterns like Array.isArray()
  let call_narrowing = extract_call_narrowing(call)

  match callee_result.ty {
    TFunction(func) => {
      let all_errors : Array[TypeMismatchError] = []
      all_errors.append(callee_result.errors)

      // Check if this is a generic function call
      if func.type_params.is_empty() && call.type_arguments.is_empty() {
        // Non-generic call - check arguments directly
        for i, arg in call.arguments {
          if i < func.params.length() {
            let expected_param = func.params[i]
            let arg_result = check_against_v2(env, arg, expected_param.ty)
            if arg_result.has_errors() {
              for err in arg_result.errors {
                all_errors.push(TypeMismatchError::{
                  path: PParameter(err.path, i, expected_param.name),
                  expected: err.expected,
                  actual: err.actual,
                  reason: err.reason,
                  children: err.children,
                  suggestions: err.suggestions,
                })
              }
            }
          }
        }
        { ty: func.return_type, narrowing: call_narrowing, errors: all_errors }
      } else {
        // Generic function call - use full generic handling
        let generic_result = check_generic_call(
          env, func, call.type_arguments, call.arguments,
        )
        all_errors.append(generic_result.errors)
        { ty: generic_result.return_type, narrowing: call_narrowing, errors: all_errors }
      }
    }
    TObject(obj) =>
      // Check for call signatures
      if obj.call_signatures.is_empty() {
        CheckResultV2::error(TError, not_callable_error(PRoot, TObject(obj)))
      } else {
        // Use first call signature - check for generics
        let sig = obj.call_signatures[0]
        if sig.type_params.is_empty() && call.type_arguments.is_empty() {
          { ty: sig.return_type, narrowing: call_narrowing, errors: callee_result.errors }
        } else {
          let generic_result = check_generic_call(
            env, sig, call.type_arguments, call.arguments,
          )
          {
            ty: generic_result.return_type,
            narrowing: call_narrowing,
            errors: generic_result.errors,
          }
        }
      }
    TAny => { ty: TAny, narrowing: call_narrowing, errors: [] }
    other => CheckResultV2::error(TError, not_callable_error(PRoot, other))
  }
}

///|
/// Infer property access type
fn infer_property_access_v2(
  env : TypeEnv,
  prop : PropertyAccessExpression,
) -> CheckResultV2 {
  let obj_result = infer_expr_v2(env, prop.expression)
  let prop_name = prop.name
  infer_member_type_v2(obj_result.ty, prop_name, obj_result.errors)
}

///|
/// Infer element access type
fn infer_element_access_v2(
  env : TypeEnv,
  elem : ElementAccessExpression,
) -> CheckResultV2 {
  let obj_result = infer_expr_v2(env, elem.expression)
  let _ = infer_expr_v2(env, elem.argument_expression)
  match obj_result.ty {
    TArray(elem_ty) => CheckResultV2::ok(elem_ty)
    TString => CheckResultV2::ok(TString)
    TObject(obj) =>
      match obj.index_signature {
        Some(sig) => CheckResultV2::ok(sig.value_type)
        None => CheckResultV2::ok(TAny)
      }
    _ => CheckResultV2::ok(TAny)
  }
}

///|
/// Infer member type from object type
fn infer_member_type_v2(
  obj_ty : TypeV2,
  prop_name : String,
  base_errors : Array[TypeMismatchError],
) -> CheckResultV2 {
  match obj_ty {
    TObject(obj) =>
      match obj.fields.get(prop_name) {
        Some(field) => { ty: field.ty, narrowing: NNone, errors: base_errors }
        None =>
          match obj.index_signature {
            Some(sig) =>
              { ty: sig.value_type, narrowing: NNone, errors: base_errors }
            None => {
              let available : Array[String] = []
              for kv in obj.fields {
                available.push(kv.0)
              }
              CheckResultV2::error(
                TError,
                missing_property_error(
                  PProperty(PRoot, prop_name),
                  prop_name,
                  find_similar_properties(prop_name, available),
                ),
              )
            }
          }
      }
    TArray(_) =>
      if prop_name == "length" {
        CheckResultV2::ok(TNumber)
      } else {
        CheckResultV2::ok(TAny)
      }
    TString =>
      if prop_name == "length" {
        CheckResultV2::ok(TNumber)
      } else {
        CheckResultV2::ok(TAny)
      }
    TAny | TUnknown => CheckResultV2::ok(TAny)
    _ => CheckResultV2::ok(TAny)
  }
}

///|
/// Infer binary expression type
fn infer_binary_v2(env : TypeEnv, bin : BinaryExpression) -> CheckResultV2 {
  let left_result = infer_expr_v2(env, bin.left)
  let right_result = infer_expr_v2(env, bin.right)

  // Extract narrowing information from comparison
  let narrowing = extract_narrowing_v2(bin)
  let result_ty = match bin.operator {
    // Arithmetic operators
    Add =>
      match (left_result.ty, right_result.ty) {
        (TString, _) | (_, TString) => TString
        (TLiteralString(_), _) | (_, TLiteralString(_)) => TString
        _ => TNumber
      }
    Subtract | Multiply | Divide | Remainder | Exponentiate => TNumber

    // Comparison operators -> boolean
    LessThan | LessThanEquals | GreaterThan | GreaterThanEquals => TBoolean

    // Equality operators -> boolean
    StrictEquals | StrictNotEquals | Equals | NotEquals => TBoolean

    // Logical operators
    LogicalAnd =>
      match left_result.ty {
        TLiteralBool(false) | TNull | TUndefined => left_result.ty
        _ => right_result.ty
      }
    LogicalOr =>
      match left_result.ty {
        TLiteralBool(true) => left_result.ty
        TNull | TUndefined | TLiteralBool(false) => right_result.ty
        _ => make_union([left_result.ty, right_result.ty])
      }
    NullishCoalescing =>
      make_union([get_non_null_type(left_result.ty), right_result.ty])

    // Bitwise operators
    BitwiseAnd
    | BitwiseOr
    | BitwiseXor
    | LeftShift
    | RightShift
    | UnsignedRightShift => TNumber

    // In operator
    In => TBoolean

    // Instanceof
    InstanceOf => TBoolean
    _ => TAny
  }
  let all_errors : Array[TypeMismatchError] = []
  all_errors.append(left_result.errors)
  all_errors.append(right_result.errors)
  { ty: result_ty, narrowing, errors: all_errors }
}

///|
/// Extract narrowing info from binary expression
fn extract_narrowing_v2(bin : BinaryExpression) -> Narrowing {
  // typeof checks
  match is_typeof_binary_check(bin.operator, bin.left, bin.right) {
    Some((var_name, type_str)) =>
      match bin.operator {
        StrictEquals | Equals => return NTypeof(var_name, type_str)
        StrictNotEquals | NotEquals => return NNot(NTypeof(var_name, type_str))
        _ => ()
      }
    None => ()
  }

  // null checks
  match is_null_check(bin.operator, bin.left, bin.right) {
    Some((var_name, is_equals)) => return NNullCheck(var_name, is_equals)
    None => ()
  }

  // undefined checks
  match is_undefined_check(bin.operator, bin.left, bin.right) {
    Some((var_name, is_equals)) => return NUndefinedCheck(var_name, is_equals)
    None => ()
  }

  // instanceof checks
  match bin.operator {
    InstanceOf =>
      match is_instanceof_check(bin.left, bin.right) {
        Some((var_name, class_name)) => {
          let class_ty = TGenericInstance(class_name, [])
          return NInstanceof(var_name, class_ty)
        }
        None => ()
      }
    _ => ()
  }

  // "in" checks
  match bin.operator {
    In =>
      match is_in_check(bin.left, bin.right) {
        Some((obj_name, prop_name)) => return NHasProperty(obj_name, prop_name)
        None => ()
      }
    _ => ()
  }

  // Property access equality checks: obj.prop === "value"
  match is_property_equality_check(bin.operator, bin.left, bin.right) {
    Some((obj_name, prop_name, value_type, is_equals)) =>
      if is_equals {
        return NPropertyEquality(obj_name, prop_name, value_type)
      } else {
        return NPropertyInequality(obj_name, prop_name, value_type)
      }
    None => ()
  }
  NNone
}

///|
/// Infer unary expression type
fn infer_unary_v2(env : TypeEnv, un : UnaryExpression) -> CheckResultV2 {
  let operand_result = infer_expr_v2(env, un.operand)
  let result_ty = match un.operator {
    LogicalNot => TBoolean
    BitwiseNot => TNumber
    Minus => TNumber
    Plus => TNumber
    TypeOf => TString
    Void => TUndefined
    Delete => TBoolean
    Increment | Decrement => TNumber
  }

  // Extract narrowing for truthy checks (e.g., !x)
  let narrowing = match un.operator {
    LogicalNot =>
      match un.operand {
        Identifier(id) => NNot(NTruthy(id.name))
        _ => NNone
      }
    _ => NNone
  }
  { ty: result_ty, narrowing, errors: operand_result.errors }
}

///|
/// Infer conditional expression type
fn infer_conditional_v2(
  env : TypeEnv,
  cond : ConditionalExpression,
) -> CheckResultV2 {
  let cond_result = infer_expr_v2(env, cond.condition)

  // Apply narrowing to when_true and when_false branches
  let true_env = env.apply_narrowing(cond_result.narrowing)
  let false_env = env.apply_narrowing(invert_narrowing(cond_result.narrowing))
  let true_result = infer_expr_v2(true_env, cond.when_true)
  let false_result = infer_expr_v2(false_env, cond.when_false)
  let result_ty = make_union([true_result.ty, false_result.ty])
  let all_errors : Array[TypeMismatchError] = []
  all_errors.append(cond_result.errors)
  all_errors.append(true_result.errors)
  all_errors.append(false_result.errors)
  { ty: result_ty, narrowing: NNone, errors: all_errors }
}

///|
/// Infer new expression type
fn infer_new_v2(env : TypeEnv, new_expr : NewExpression) -> CheckResultV2 {
  let callee_result = infer_expr_v2(env, new_expr.expression)
  match callee_result.ty {
    TObject(obj) =>
      if obj.construct_signatures.is_empty() {
        CheckResultV2::ok(TObject(obj))
      } else {
        let sig = obj.construct_signatures[0]
        CheckResultV2::ok(sig.return_type)
      }
    TFunction(func) => CheckResultV2::ok(func.return_type)
    TGenericInstance(_, _) => CheckResultV2::ok(callee_result.ty)
    _ => CheckResultV2::ok(TObject(ObjectTypeV2::empty()))
  }
}

// ============================================================================
// Type Assignability Checking
// ============================================================================

///|
/// Check if source type is assignable to target type
pub fn check_assignable_v2(
  source : TypeV2,
  target : TypeV2,
  path : TypePath,
) -> CheckResultV2 {
  // Same type
  if types_v2_equal(source, target) {
    return CheckResultV2::ok(source)
  }

  // Any is assignable to/from anything
  match (source, target) {
    (TAny, _) | (_, TAny) => return CheckResultV2::ok(source)
    (_, TUnknown) => return CheckResultV2::ok(source)
    (TNever, _) => return CheckResultV2::ok(source)
    _ => ()
  }

  // Literal widening
  match (source, target) {
    (TLiteralString(_), TString) => return CheckResultV2::ok(source)
    (TLiteralNumber(_), TNumber) => return CheckResultV2::ok(source)
    (TLiteralBool(_), TBoolean) => return CheckResultV2::ok(source)
    _ => ()
  }

  // Union target: source must be assignable to at least one member
  match target {
    TUnion(targets) => {
      for t in targets {
        let result = check_assignable_v2(source, t, path)
        if not(result.has_errors()) {
          return CheckResultV2::ok(source)
        }
      }
      return CheckResultV2::error(
        source,
        no_union_member_matches_error(path, source, targets),
      )
    }
    _ => ()
  }

  // Union source: all members must be assignable
  match source {
    TUnion(sources) => {
      let all_errors : Array[TypeMismatchError] = []
      for i, s in sources {
        let result = check_assignable_v2(s, target, PUnionMember(path, i))
        all_errors.append(result.errors)
      }
      if all_errors.is_empty() {
        return CheckResultV2::ok(source)
      } else {
        return { ty: source, narrowing: NNone, errors: all_errors }
      }
    }
    _ => ()
  }

  // Array assignability
  match (source, target) {
    (TArray(s_elem), TArray(t_elem)) => {
      let result = check_assignable_v2(s_elem, t_elem, path.array_element())
      if result.has_errors() {
        return result
      }
      return CheckResultV2::ok(source)
    }
    _ => ()
  }

  // Object assignability
  match (source, target) {
    (TObject(s_obj), TObject(t_obj)) =>
      return check_object_assignable_v2(s_obj, t_obj, path)
    _ => ()
  }

  // Function assignability
  match (source, target) {
    (TFunction(s_func), TFunction(t_func)) =>
      return check_function_assignable_v2(s_func, t_func, path)
    _ => ()
  }

  // Generic instance
  match (source, target) {
    (TGenericInstance(s_name, s_args), TGenericInstance(t_name, t_args)) =>
      if s_name == t_name {
        let all_errors : Array[TypeMismatchError] = []
        for i in 0..<s_args.length() {
          if i < t_args.length() {
            let result = check_assignable_v2(
              s_args[i],
              t_args[i],
              path.type_arg("T", i),
            )
            all_errors.append(result.errors)
          }
        }
        if all_errors.is_empty() {
          return CheckResultV2::ok(source)
        } else {
          return { ty: source, narrowing: NNone, errors: all_errors }
        }
      }
    _ => ()
  }

  // Default: incompatible
  CheckResultV2::error(source, type_mismatch(path, source, target))
}

///|
/// Check object assignability
fn check_object_assignable_v2(
  source : ObjectTypeV2,
  target : ObjectTypeV2,
  path : TypePath,
) -> CheckResultV2 {
  let all_errors : Array[TypeMismatchError] = []
  for kv in target.fields {
    let name = kv.0
    let t_field = kv.1
    match source.fields.get(name) {
      Some(s_field) => {
        let result = check_assignable_v2(
          s_field.ty,
          t_field.ty,
          path.property(name),
        )
        all_errors.append(result.errors)
      }
      None =>
        if not(t_field.optional) {
          let available : Array[String] = []
          for skv in source.fields {
            available.push(skv.0)
          }
          all_errors.push(
            missing_property_error(
              path.property(name),
              name,
              find_similar_properties(name, available),
            ),
          )
        }
    }
  }
  if all_errors.is_empty() {
    CheckResultV2::ok(TObject(source))
  } else {
    { ty: TObject(source), narrowing: NNone, errors: all_errors }
  }
}

///|
/// Check function assignability (contravariant params, covariant return)
fn check_function_assignable_v2(
  source : FunctionTypeV2,
  target : FunctionTypeV2,
  path : TypePath,
) -> CheckResultV2 {
  let all_errors : Array[TypeMismatchError] = []

  // Parameters are contravariant
  for i in 0..<target.params.length() {
    if i < source.params.length() {
      let result = check_assignable_v2(
        target.params[i].ty,
        source.params[i].ty,
        path.parameter(i, source.params[i].name),
      )
      all_errors.append(result.errors)
    }
  }

  // Return type is covariant
  let ret_result = check_assignable_v2(
    source.return_type,
    target.return_type,
    path.return_type(),
  )
  all_errors.append(ret_result.errors)
  if all_errors.is_empty() {
    CheckResultV2::ok(TFunction(source))
  } else {
    { ty: TFunction(source), narrowing: NNone, errors: all_errors }
  }
}

// ============================================================================
// Helper Functions
// ============================================================================

///|
/// Get parameter name from node
fn get_param_name_v2(node : Node) -> String {
  match node {
    Parameter(param) =>
      match param.name {
        Identifier(id) => id.name
        _ => "arg"
      }
    Identifier(id) => id.name
    _ => "arg"
  }
}

///|
/// Infer return type from block body
fn infer_block_return_v2(env : TypeEnv, body : Node) -> TypeV2 {
  match body {
    BlockStatement(block) =>
      infer_block_return_from_stmts_v2(env, block.statements)
    _ => TVoid
  }
}

///|
/// Check block body against expected return type
fn check_block_return_v2(
  env : TypeEnv,
  body : Node,
  expected : TypeV2,
) -> CheckResultV2 {
  match body {
    BlockStatement(block) =>
      check_block_return_from_stmts_v2(env, block.statements, expected)
    _ => CheckResultV2::ok(expected)
  }
}

///|
/// Infer return type from statements
fn infer_block_return_from_stmts_v2(
  env : TypeEnv,
  statements : Array[Node],
) -> TypeV2 {
  let return_types : Array[TypeV2] = []
  for stmt in statements {
    match stmt {
      ReturnStatement(ret) =>
        match ret.expression {
          Some(arg) => {
            let result = infer_expr_v2(env, arg)
            return_types.push(result.ty)
          }
          None => return_types.push(TVoid)
        }
      _ => ()
    }
  }
  if return_types.is_empty() {
    TVoid
  } else {
    make_union(return_types)
  }
}

///|
/// Check block body against expected return type
fn check_block_return_from_stmts_v2(
  env : TypeEnv,
  statements : Array[Node],
  expected : TypeV2,
) -> CheckResultV2 {
  let all_errors : Array[TypeMismatchError] = []
  for stmt in statements {
    match stmt {
      ReturnStatement(ret) =>
        match ret.expression {
          Some(arg) => {
            let result = check_against_v2(env, arg, expected)
            all_errors.append(result.errors)
          }
          None =>
            if expected != TVoid {
              all_errors.push(
                return_type_mismatch_error(PReturnType(PRoot), TVoid, expected),
              )
            }
        }
      _ => ()
    }
  }
  { ty: expected, narrowing: NNone, errors: all_errors }
}
