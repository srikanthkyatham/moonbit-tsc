// Overload Checking - Function Overload Validation
// Implements:
// - TS2394: Overload signature is not compatible with function implementation
// - TS2391: Function implementation is missing or not immediately following the declaration
// - TS2383: Overload signatures must all be ambient or non-ambient
// - Contextual overload selection for callback parameter matching

// ============================================================================
// Overload Signature Collection
// ============================================================================

///|
/// Represents a collected overload signature
pub struct OverloadSignature {
  parameters : Array[OverloadParameter]
  return_type : Node?
  type_parameters : Array[TypeParameter]
  location : SourceLocation
  is_ambient : Bool
} derive(Show)

///|
/// Parameter in an overload signature
pub struct OverloadParameter {
  name : String
  type_annotation : Node?
  is_optional : Bool
  is_rest : Bool
} derive(Show)

///|
/// Collected overloads for a function
pub struct FunctionOverloads {
  name : String
  signatures : Array[OverloadSignature]
  implementation : FunctionDeclaration?
  implementation_location : SourceLocation?
} derive(Show)

///|
/// Create empty function overloads
pub fn FunctionOverloads::empty(name : String) -> FunctionOverloads {
  { name, signatures: [], implementation: None, implementation_location: None }
}

///|
/// Add a signature to overloads
pub fn FunctionOverloads::add_signature(
  self : FunctionOverloads,
  sig : OverloadSignature,
) -> FunctionOverloads {
  self.signatures.push(sig)
  self
}

///|
/// Set the implementation
pub fn FunctionOverloads::set_implementation(
  self : FunctionOverloads,
  impl_ : FunctionDeclaration,
  location : SourceLocation,
) -> FunctionOverloads {
  { ..self, implementation: Some(impl_), implementation_location: Some(location) }
}

// ============================================================================
// Overload Collection from Statements
// ============================================================================

///|
/// Collect function overloads from a list of statements
/// Groups consecutive function declarations with the same name
pub fn collect_overloads(statements : Array[Node]) -> Map[String, FunctionOverloads] {
  let overloads : Map[String, FunctionOverloads] = Map::new()

  for stmt in statements {
    match stmt {
      FunctionDeclaration(func) =>
        match func.name {
          Some(Identifier(id)) => {
            let name = id.name
            let existing = overloads.get(name).unwrap_or(FunctionOverloads::empty(name))

            // Check if this is a signature (no body) or implementation (has body)
            match func.body {
              None => {
                // This is an overload signature
                let sig = extract_overload_signature(func)
                let _ = existing.add_signature(sig)
                overloads.set(name, existing)
              }
              Some(_) => {
                // This is the implementation
                let updated = existing.set_implementation(func, func.location)
                overloads.set(name, updated)
              }
            }
          }
          _ => ()
        }
      _ => ()
    }
  }

  overloads
}

///|
/// Extract overload signature from function declaration
fn extract_overload_signature(func : FunctionDeclaration) -> OverloadSignature {
  let parameters : Array[OverloadParameter] = []

  for param_node in func.parameters {
    match param_node {
      Parameter(p) => {
        parameters.push({
          name: overload_get_param_name(p.name),
          type_annotation: p.type_annotation,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }

  let is_ambient = overload_has_declare_modifier(func.modifiers)

  {
    parameters,
    return_type: func.return_type,
    type_parameters: func.type_parameters,
    location: func.location,
    is_ambient,
  }
}

///|
/// Get parameter name from binding pattern
fn overload_get_param_name(pattern : Node) -> String {
  match pattern {
    Identifier(id) => id.name
    _ => "_"
  }
}

///|
/// Check if modifiers include 'declare'
fn overload_has_declare_modifier(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    match m {
      Declare => return true
      _ => ()
    }
  }
  false
}

// ============================================================================
// Overload Validation
// ============================================================================

///|
/// Result of overload validation
pub struct OverloadValidationResult {
  errors : Array[OverloadError]
  is_valid : Bool
} derive(Show)

///|
/// Overload-specific error
pub struct OverloadError {
  kind : OverloadErrorKind
  message : String
  location : SourceLocation
  code : Int
} derive(Show)

///|
/// Types of overload errors
pub enum OverloadErrorKind {
  NotCompatibleWithImpl(Int) // signature index
  MissingImplementation
  AmbientMismatch
  ParamCountMismatch(Int, Int) // signature index, expected vs actual
  ParamTypeMismatch(Int, Int) // signature index, param index
  ReturnTypeMismatch(Int) // signature index
} derive(Show)

///|
/// Validate function overloads
pub fn validate_overloads(overloads : FunctionOverloads) -> OverloadValidationResult {
  let errors : Array[OverloadError] = []

  // If there are no signatures, nothing to validate
  if overloads.signatures.is_empty() {
    return { errors, is_valid: true }
  }

  // Check TS2391: Missing implementation (for non-ambient overloads)
  let has_non_ambient = overloads.signatures.iter().any(fn(s) { not(s.is_ambient) })
  if has_non_ambient && overloads.implementation is None {
    errors.push({
      kind: MissingImplementation,
      message: "Function implementation is missing or not immediately following the declaration.",
      location: overloads.signatures[0].location,
      code: 2391,
    })
  }

  // Check TS2383: Ambient mismatch
  let result = check_ambient_consistency(overloads)
  for err in result.errors {
    errors.push(err)
  }

  // Check TS2394: Overload compatibility with implementation
  match overloads.implementation {
    Some(impl_) => {
      let compat_errors = check_overload_compatibility(overloads.signatures, impl_)
      for err in compat_errors {
        errors.push(err)
      }
    }
    None => ()
  }

  { errors, is_valid: errors.is_empty() }
}

///|
/// Check that all overloads are either ambient or non-ambient
fn check_ambient_consistency(overloads : FunctionOverloads) -> OverloadValidationResult {
  let errors : Array[OverloadError] = []

  if overloads.signatures.length() < 2 {
    return { errors, is_valid: true }
  }

  let first_is_ambient = overloads.signatures[0].is_ambient
  for i = 1; i < overloads.signatures.length(); i = i + 1 {
    let sig = overloads.signatures[i]
    if sig.is_ambient != first_is_ambient {
      errors.push({
        kind: AmbientMismatch,
        message: "Overload signatures must all be ambient or non-ambient.",
        location: sig.location,
        code: 2383,
      })
    }
  }

  { errors, is_valid: errors.is_empty() }
}

///|
/// Check that each overload signature is compatible with the implementation
fn check_overload_compatibility(
  signatures : Array[OverloadSignature],
  impl_ : FunctionDeclaration,
) -> Array[OverloadError] {
  let errors : Array[OverloadError] = []

  // Get implementation parameter count
  let impl_required = count_impl_required_params(impl_.parameters)
  let impl_total = impl_.parameters.length()

  for i = 0; i < signatures.length(); i = i + 1 {
    let sig = signatures[i]

    // Check parameter count compatibility
    // Implementation must accept at least as many parameters as any overload requires
    let sig_required = count_overload_required_params(sig.parameters)
    let sig_total = sig.parameters.length()

    // The implementation's required params must be <= each overload's required params
    // (implementation must be able to handle all overloads)
    if impl_required > sig_required {
      errors.push({
        kind: ParamCountMismatch(i, sig_required),
        message: "Overload signature is not compatible with function implementation. " +
          "Implementation requires " +
          impl_required.to_string() +
          " parameters, but overload only provides " +
          sig_required.to_string() +
          ".",
        location: sig.location,
        code: 2394,
      })
      continue
    }

    // The implementation should have at least as many total parameters as the overload
    // (to handle all parameters that could be passed)
    if impl_total < sig_total && not(overload_has_rest_param(impl_.parameters)) {
      errors.push({
        kind: NotCompatibleWithImpl(i),
        message: "Overload signature is not compatible with function implementation. " +
          "Overload has " +
          sig_total.to_string() +
          " parameters, but implementation only has " +
          impl_total.to_string() +
          ".",
        location: sig.location,
        code: 2394,
      })
    }
  }

  errors
}

///|
/// Count required parameters in overload signature
fn count_overload_required_params(params : Array[OverloadParameter]) -> Int {
  let mut count = 0
  for p in params {
    if not(p.is_optional) && not(p.is_rest) {
      count = count + 1
    }
  }
  count
}

///|
/// Count required parameters in implementation
fn count_impl_required_params(params : Array[Node]) -> Int {
  let mut count = 0
  for param_node in params {
    match param_node {
      Parameter(p) =>
        if not(p.is_optional) && not(p.is_rest) {
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
/// Check if implementation has a rest parameter
fn overload_has_rest_param(params : Array[Node]) -> Bool {
  for param_node in params {
    match param_node {
      Parameter(p) =>
        if p.is_rest {
          return true
        }
      _ => ()
    }
  }
  false
}

// ============================================================================
// Contextual Overload Selection
// ============================================================================

///|
/// Result of contextual overload selection
pub struct OverloadSelectionResult {
  selected_index : Int?
  matched_signature : CheckerSignature?
  inference_context : Map[String, Type]
} derive(Show)

///|
/// Select the best overload based on contextual typing of callback parameters
pub fn select_overload_contextually(
  signatures : Array[CheckerSignature],
  arg_types : Array[Type],
  arg_nodes : Array[Node],
  checker : TypeChecker,
) -> (OverloadSelectionResult?, TypeChecker) {
  let mut checker = checker

  // Try each signature in order
  for i = 0; i < signatures.length(); i = i + 1 {
    let sig = signatures[i]
    let (matches, c) = try_contextual_match(sig, arg_types, arg_nodes, checker)
    checker = c

    if matches {
      return (
        Some({
          selected_index: Some(i),
          matched_signature: Some(sig),
          inference_context: Map::new(),
        }),
        checker,
      )
    }
  }

  (None, checker)
}

///|
/// Try to match a signature with contextual typing
fn try_contextual_match(
  signature : CheckerSignature,
  arg_types : Array[Type],
  arg_nodes : Array[Node],
  checker : TypeChecker,
) -> (Bool, TypeChecker) {
  let checker = checker

  // Check basic arity first
  let min_required = count_checker_required_params(signature.parameters)
  if arg_types.length() < min_required {
    return (false, checker)
  }

  // For each argument, check compatibility with contextual typing
  for i = 0; i < arg_types.length(); i = i + 1 {
    if i >= signature.parameters.length() {
      // More args than params - check for rest parameter
      let last_param = signature.parameters[signature.parameters.length() - 1]
      if not(last_param.is_rest) {
        return (false, checker)
      }
      continue
    }

    let param = signature.parameters[i]
    let arg_type = arg_types[i]
    let arg_node = if i < arg_nodes.length() { Some(arg_nodes[i]) } else { None }

    // Check if argument matches with contextual typing
    let compatible = check_arg_with_context(arg_type, arg_node, param.param_type)

    if not(compatible) {
      return (false, checker)
    }
  }

  (true, checker)
}

///|
/// Check argument compatibility with contextual typing support
fn check_arg_with_context(
  arg_type : Type,
  arg_node : Node?,
  param_type : Type,
) -> Bool {
  // First try direct type compatibility using structural check
  if types_structurally_compatible(arg_type, param_type) {
    return true
  }

  // For function arguments (callbacks), try contextual typing
  match arg_node {
    Some(ArrowFunction(_)) | Some(FunctionExpression(_)) => {
      // The argument is a callback - use contextual parameter typing
      // This allows callback parameters to be inferred from the expected type
      match param_type {
        Function(_) => {
          // Try contextual match for callback
          return try_callback_contextual_match(arg_type, param_type)
        }
        _ => ()
      }
    }
    _ => ()
  }

  false
}

///|
/// Check structural compatibility of types
fn types_structurally_compatible(source : Type, target : Type) -> Bool {
  match (source, target) {
    // Same type variants
    (Number(_), Number(_)) => true
    (String(_), String(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Void(_), Void(_)) => true
    (Undefined(_), Undefined(_)) => true
    (Null(_), Null(_)) => true
    (Symbol(_), Symbol(_)) => true
    (Any(_), _) | (_, Any(_)) => true
    (Unknown(_), _) => true
    (Never(_), _) => true
    // Function compatibility
    (Function(src_func), Function(tgt_func)) => {
      // Check parameter count (source can have fewer params)
      if src_func.parameters.length() > tgt_func.parameters.length() {
        return false
      }
      true
    }
    // Array compatibility
    (Array(src_arr), Array(tgt_arr)) =>
      types_structurally_compatible(src_arr.element_type, tgt_arr.element_type)
    // Union - source must be compatible with at least one union type
    (_, Union(tgt_union)) => {
      for union_type in tgt_union.types {
        if types_structurally_compatible(source, union_type) {
          return true
        }
      }
      false
    }
    // Source is union - all union types must be compatible with target
    (Union(src_union), _) => {
      for union_type in src_union.types {
        if not(types_structurally_compatible(union_type, target)) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
/// Try contextual matching for callback functions
fn try_callback_contextual_match(callback_type : Type, expected_type : Type) -> Bool {
  match (callback_type, expected_type) {
    (Function(cb_func), Function(exp_func)) => {
      // Check parameter count compatibility
      // Callback can have fewer parameters than expected (unused params OK)
      if cb_func.parameters.length() > exp_func.parameters.length() {
        return false
      }

      // Check return type compatibility (simplified)
      match cb_func.return_type {
        Void(_) => true // void callbacks match any return type
        _ => types_structurally_compatible(cb_func.return_type, exp_func.return_type)
      }
    }
    _ => false
  }
}

///|
/// Count required parameters in checker signature
fn count_checker_required_params(params : Array[CheckerParameter]) -> Int {
  let mut count = 0
  for p in params {
    if not(p.is_optional) && not(p.is_rest) {
      count = count + 1
    }
  }
  count
}

// ============================================================================
// Integration with Statement Checking
// ============================================================================

///|
/// Check overloads in a list of statements
/// Returns diagnostics for any overload errors
pub fn check_statement_overloads(
  statements : Array[Node],
  checker : TypeChecker,
) -> TypeChecker {
  let overloads_map = collect_overloads(statements)
  let checker = checker

  overloads_map.each(fn(_name, overloads) {
    let result = validate_overloads(overloads)

    // Add diagnostics for any errors
    for err in result.errors {
      let diag = Diagnostic::error(err.message, err.location, err.code)
      checker.diagnostics.push(diag)
    }
  })

  checker
}

// ============================================================================
// Constructor Overload Checking (TS2390)
// ============================================================================

///|
/// Collected constructor overloads for a class
pub struct ConstructorOverloads {
  class_name : String
  signatures : Array[OverloadSignature]
  implementation : ConstructorDeclaration?
  implementation_location : SourceLocation?
} derive(Show)

///|
/// Create empty constructor overloads
pub fn ConstructorOverloads::empty(class_name : String) -> ConstructorOverloads {
  { class_name, signatures: [], implementation: None, implementation_location: None }
}

///|
/// Collect constructor overloads from class members
pub fn collect_constructor_overloads(
  class_name : String,
  members : Array[Node],
) -> ConstructorOverloads {
  let mut overloads = ConstructorOverloads::empty(class_name)

  for member in members {
    match member {
      ConstructorDeclaration(ctor) =>
        match ctor.body {
          None => {
            // This is an overload signature
            let sig = extract_constructor_signature(ctor)
            overloads.signatures.push(sig)
          }
          Some(_) => {
            // This is the implementation
            overloads = {
              ..overloads,
              implementation: Some(ctor),
              implementation_location: Some(ctor.location),
            }
          }
        }
      _ => ()
    }
  }

  overloads
}

///|
/// Extract overload signature from constructor declaration
fn extract_constructor_signature(ctor : ConstructorDeclaration) -> OverloadSignature {
  let parameters : Array[OverloadParameter] = []

  for param_node in ctor.parameters {
    match param_node {
      Parameter(p) => {
        parameters.push({
          name: overload_get_param_name(p.name),
          type_annotation: p.type_annotation,
          is_optional: p.is_optional,
          is_rest: p.is_rest,
        })
      }
      _ => ()
    }
  }

  {
    parameters,
    return_type: None, // Constructors don't have explicit return type
    type_parameters: [],
    location: ctor.location,
    is_ambient: false,
  }
}

///|
/// Validate constructor overloads (TS2390)
pub fn validate_constructor_overloads(
  overloads : ConstructorOverloads,
) -> OverloadValidationResult {
  let errors : Array[OverloadError] = []

  // If there are no signatures, nothing to validate
  if overloads.signatures.is_empty() {
    return { errors, is_valid: true }
  }

  // Check TS2390: Missing implementation
  if overloads.implementation is None {
    errors.push({
      kind: MissingImplementation,
      message: "Constructor implementation is missing.",
      location: overloads.signatures[0].location,
      code: 2390,
    })
  }

  { errors, is_valid: errors.is_empty() }
}

///|
/// Check constructor overloads in a class
pub fn check_class_constructor_overloads(
  class_name : String,
  members : Array[Node],
  checker : TypeChecker,
) -> TypeChecker {
  let overloads = collect_constructor_overloads(class_name, members)
  let result = validate_constructor_overloads(overloads)

  // Add diagnostics for any errors
  for err in result.errors {
    let diag = Diagnostic::error(err.message, err.location, err.code)
    checker.diagnostics.push(diag)
  }

  checker
}
