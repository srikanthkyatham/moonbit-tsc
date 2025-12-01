// JSX Type Checking
// Implements TypeScript's JSX type checking including:
// - JSX intrinsic element type lookup (JSX.IntrinsicElements['div'])
// - Component prop type checking
// - Children type validation
// - JSX.Element return type enforcement

// ============================================================================
// JSX Type Inference
// ============================================================================

///|
/// Infer the type of a JSX element expression
/// Returns JSX.Element type and checks prop/children validity
pub fn infer_jsx_element_type(
  checker : TypeChecker,
  element : JsxElement,
) -> (Type, TypeChecker) {
  // Get tag name and attributes from opening element
  let (tag_name, attributes, type_args) = match element.opening_element {
    JsxOpeningElement(joe) => (joe.tag_name, joe.attributes, joe.type_arguments)
    _ => return any_type(checker)
  }

  // Check the element type based on tag name
  let checker = check_jsx_element_type(checker, tag_name, attributes, type_args, element.children)

  // JSX expressions always return JSX.Element type
  get_jsx_element_type(checker)
}

///|
/// Infer the type of a self-closing JSX element
pub fn infer_jsx_self_closing_type(
  checker : TypeChecker,
  element : JsxSelfClosingElement,
) -> (Type, TypeChecker) {
  // Check the element type
  let checker = check_jsx_element_type(
    checker,
    element.tag_name,
    element.attributes,
    element.type_arguments,
    [], // No children for self-closing
  )

  // JSX expressions always return JSX.Element type
  get_jsx_element_type(checker)
}

///|
/// Infer the type of a JSX fragment
pub fn infer_jsx_fragment_type(
  checker : TypeChecker,
  fragment : JsxFragment,
) -> (Type, TypeChecker) {
  // Validate children types
  let checker = check_jsx_children(checker, fragment.children)

  // Fragments also return JSX.Element
  get_jsx_element_type(checker)
}

// ============================================================================
// JSX Element Type Checking
// ============================================================================

///|
/// Check JSX element type and validate props
fn check_jsx_element_type(
  checker : TypeChecker,
  tag_name : JsxTagName,
  attributes : Array[JsxAttribute],
  type_args : Array[Node],
  children : Array[JsxChild],
) -> TypeChecker {
  // Determine if this is an intrinsic element or component
  match tag_name {
    Identifier(name, loc) => {
      if is_intrinsic_element(name) {
        // Intrinsic element (lowercase): look up in JSX.IntrinsicElements
        check_intrinsic_element(checker, name, attributes, children, loc)
      } else {
        // Custom component (uppercase): look up component type
        check_component_element(checker, name, attributes, type_args, children, loc)
      }
    }
    NamespacedName(ns_prefix, local_name, loc) => {
      // Namespaced elements (e.g., svg:rect) are treated as intrinsic
      let full_name = ns_prefix + ":" + local_name
      check_intrinsic_element(checker, full_name, attributes, children, loc)
    }
    PropertyAccess(_, _, _) => {
      // Property access components (e.g., Module.Component)
      check_property_access_component(checker, tag_name, attributes, type_args, children)
    }
  }
}

///|
/// Check if a tag name represents an intrinsic element (lowercase first letter)
fn is_intrinsic_element(name : String) -> Bool {
  if name.length() == 0 {
    return false
  }
  let first_char = name[0].unsafe_to_char()
  first_char >= 'a' && first_char <= 'z'
}

///|
/// Check intrinsic element type and props
fn check_intrinsic_element(
  checker : TypeChecker,
  tag_name : String,
  attributes : Array[JsxAttribute],
  children : Array[JsxChild],
  _loc : SourceLocation,
) -> TypeChecker {
  // Look up element type in JSX.IntrinsicElements
  let (element_props_type, checker) = get_intrinsic_element_type(checker, tag_name)

  // Validate attributes against expected props
  let checker = match element_props_type {
    Some(props_type) => check_jsx_attributes(checker, attributes, props_type)
    None => checker // No type info, skip checking
  }

  // Validate children
  check_jsx_children(checker, children)
}

///|
/// Check custom component element type and props
fn check_component_element(
  checker : TypeChecker,
  component_name : String,
  attributes : Array[JsxAttribute],
  _type_args : Array[Node],
  children : Array[JsxChild],
  loc : SourceLocation,
) -> TypeChecker {
  // Look up component in scope
  match lookup_symbol(checker, component_name) {
    Some(symbol) => {
      // Get component type
      let (component_type, checker) = get_symbol_type(checker, symbol)
      match component_type {
        Some(Function(fn_type)) => {
          // Function component: first parameter is props
          let props_type = get_function_props_type(checker, fn_type)
          let checker = match props_type {
            Some(pt) => check_jsx_attributes(checker, attributes, pt)
            None => checker
          }
          check_jsx_children(checker, children)
        }
        Some(Object(obj_type)) => {
          // Class component or object with callable signature
          let props_type = get_class_component_props_type(checker, obj_type)
          let checker = match props_type {
            Some(pt) => check_jsx_attributes(checker, attributes, pt)
            None => checker
          }
          check_jsx_children(checker, children)
        }
        _ =>
          // Component type not found or unrecognized - add diagnostic
          jsx_error_cannot_find_component(checker, component_name, loc)
      }
    }
    None =>
      // Component not found in scope
      jsx_error_cannot_find_component(checker, component_name, loc)
  }
}

///|
/// Check property access component (e.g., Components.Button)
fn check_property_access_component(
  checker : TypeChecker,
  _tag_name : JsxTagName,
  attributes : Array[JsxAttribute],
  _type_args : Array[Node],
  children : Array[JsxChild],
) -> TypeChecker {
  // For now, just validate children and skip detailed prop checking
  // Full implementation would resolve the property access to get component type
  let mut checker = checker
  for i = 0; i < attributes.length(); i = i + 1 {
    checker = check_jsx_attribute_expression(checker, attributes[i])
  }
  check_jsx_children(checker, children)
}

// ============================================================================
// JSX.IntrinsicElements Lookup
// ============================================================================

///|
/// Get the props type for an intrinsic element from JSX.IntrinsicElements
fn get_intrinsic_element_type(
  checker : TypeChecker,
  tag_name : String,
) -> (Type?, TypeChecker) {
  // Look up JSX namespace
  match lookup_symbol(checker, "JSX") {
    Some(jsx_symbol) => {
      // Look for IntrinsicElements in JSX namespace
      match get_jsx_intrinsic_elements(checker, jsx_symbol) {
        (Some(intrinsic_type), checker) => {
          // Look up the specific element type
          get_indexed_type(checker, intrinsic_type, tag_name)
        }
        (None, checker) => (None, checker)
      }
    }
    None => {
      // JSX namespace not found - this is common in projects without React types
      // Don't report error, just skip type checking
      (None, checker)
    }
  }
}

///|
/// Get JSX.IntrinsicElements type from JSX namespace symbol
fn get_jsx_intrinsic_elements(
  checker : TypeChecker,
  jsx_symbol : Symbol,
) -> (Type?, TypeChecker) {
  // Get the JSX namespace type
  let (jsx_type, checker) = get_symbol_type(checker, jsx_symbol)
  match jsx_type {
    Some(Object(obj_type)) => {
      // Look for IntrinsicElements property
      match obj_type.properties.get("IntrinsicElements") {
        Some(prop) => (Some(prop.prop_type), checker)
        None => (None, checker)
      }
    }
    _ => (None, checker)
  }
}

///|
/// Get type from indexed access (obj[key])
fn get_indexed_type(
  checker : TypeChecker,
  obj_type : Type,
  key : String,
) -> (Type?, TypeChecker) {
  match obj_type {
    Object(ot) => {
      // First check for exact property match
      match ot.properties.get(key) {
        Some(prop) => (Some(prop.prop_type), checker)
        None => {
          // Check index signatures
          if ot.index_signatures.length() > 0 {
            // Use string index signature
            for i = 0; i < ot.index_signatures.length(); i = i + 1 {
              match ot.index_signatures[i].parameter_type {
                String(_) => return (Some(ot.index_signatures[i].return_type), checker)
                _ => continue
              }
            }
          }
          (None, checker)
        }
      }
    }
    _ => (None, checker)
  }
}

// ============================================================================
// JSX Attribute Type Checking
// ============================================================================

///|
/// Check JSX attributes against expected props type
fn check_jsx_attributes(
  checker : TypeChecker,
  attributes : Array[JsxAttribute],
  expected_props : Type,
) -> TypeChecker {
  let mut checker = checker

  // Build map of provided attributes
  let provided_attrs : Map[String, Type] = Map::new()

  for i = 0; i < attributes.length(); i = i + 1 {
    match attributes[i] {
      Attribute(attr_node) => {
        let attr_name = get_jsx_attribute_name(attr_node.name)
        let (attr_type, c) = infer_jsx_attribute_value_type(checker, attr_node.initializer)
        checker = c
        provided_attrs.set(attr_name, attr_type)

        // Check attribute type against expected
        checker = check_single_attribute(checker, attr_name, attr_type, expected_props)
      }
      SpreadAttribute(expr, _) => {
        // Type check the spread expression
        let (_, c) = infer_type(checker, expr)
        checker = c
        // Spread attributes are harder to check statically
      }
    }
  }

  // Check for missing required props
  check_required_props(checker, expected_props, provided_attrs)
}

///|
/// Check a single attribute against expected props
fn check_single_attribute(
  checker : TypeChecker,
  attr_name : String,
  attr_type : Type,
  expected_props : Type,
) -> TypeChecker {
  match expected_props {
    Object(obj_type) =>
      match obj_type.properties.get(attr_name) {
        Some(expected_prop) =>
          // Check type compatibility
          if not(is_type_assignable(attr_type, expected_prop.prop_type)) {
            let loc = make_default_location(checker.file_path)
            jsx_error_prop_type_mismatch(
              checker,
              attr_name,
              jsx_type_to_string(attr_type),
              jsx_type_to_string(expected_prop.prop_type),
              loc,
            )
          } else {
            checker
          }
        None =>
          // Unknown property - check for index signature
          if has_string_index_signature(obj_type) {
            checker
          } else {
            let loc = make_default_location(checker.file_path)
            jsx_error_unknown_prop(checker, attr_name, jsx_type_to_string(expected_props), loc)
          }
      }
    _ => checker
  }
}

///|
/// Create a default source location for a file
fn make_default_location(file_path : String) -> SourceLocation {
  SourceLocation::{
    file_path,
    start: Position::{ line: 1, column: 1, offset: 0 },
    end: Position::{ line: 1, column: 1, offset: 0 },
  }
}

///|
/// Check for missing required props
fn check_required_props(
  checker : TypeChecker,
  expected_props : Type,
  provided : Map[String, Type],
) -> TypeChecker {
  match expected_props {
    Object(obj_type) => {
      let mut c = checker
      for entry in obj_type.properties.iter() {
        let (name, prop_sig) = entry
        if not(prop_sig.is_optional) && not(provided.contains(name)) {
          let loc = make_default_location(c.file_path)
          c = jsx_error_missing_prop(c, name, jsx_type_to_string(expected_props), loc)
        }
      }
      c
    }
    _ => checker
  }
}

///|
/// Check if object type has a string index signature
fn has_string_index_signature(obj_type : ObjectType) -> Bool {
  for i = 0; i < obj_type.index_signatures.length(); i = i + 1 {
    match obj_type.index_signatures[i].parameter_type {
      String(_) => return true
      _ => continue
    }
  }
  false
}

///|
/// Get the name of a JSX attribute
fn get_jsx_attribute_name(name : JsxAttributeName) -> String {
  match name {
    Identifier(s, _) => s
    NamespacedName(ns, local_name, _) => ns + ":" + local_name
  }
}

///|
/// Infer the type of a JSX attribute value
fn infer_jsx_attribute_value_type(
  checker : TypeChecker,
  value : JsxAttributeValue?,
) -> (Type, TypeChecker) {
  match value {
    Some(StringLiteral(s, _)) => {
      // String literal attribute - create literal string type
      let id = checker.next_type_id
      let flags = TypeFlags::{ is_readonly: false, is_optional: false }
      (StringLiteral(s, { id, flags }), { ..checker, next_type_id: id + 1 })
    }
    Some(Expression(expr, _)) => {
      // Expression attribute - infer expression type
      infer_type(checker, expr)
    }
    Some(Element(element, _)) => {
      // JSX element attribute
      infer_type(checker, element)
    }
    None => {
      // Boolean attribute (no value means true)
      boolean_type(checker)
    }
  }
}

///|
/// Check a JSX attribute expression for type errors
fn check_jsx_attribute_expression(
  checker : TypeChecker,
  attr : JsxAttribute,
) -> TypeChecker {
  match attr {
    Attribute(attr_node) => {
      let (_, checker) = infer_jsx_attribute_value_type(checker, attr_node.initializer)
      checker
    }
    SpreadAttribute(expr, _) => {
      let (_, checker) = infer_type(checker, expr)
      checker
    }
  }
}

// ============================================================================
// JSX Children Type Checking
// ============================================================================

///|
/// Check JSX children types
fn check_jsx_children(
  checker : TypeChecker,
  children : Array[JsxChild],
) -> TypeChecker {
  let mut checker = checker
  for i = 0; i < children.length(); i = i + 1 {
    checker = check_jsx_child(checker, children[i])
  }
  checker
}

///|
/// Check a single JSX child
fn check_jsx_child(checker : TypeChecker, child : JsxChild) -> TypeChecker {
  match child {
    Text(_, _) =>
      // Text is always valid
      checker
    Expression(jsx_expr) =>
      // Type check the expression
      match jsx_expr.expression {
        Some(expr) => {
          let (child_type, c) = infer_type(checker, expr)
          // Validate that child type is renderable
          validate_jsx_child_type(c, child_type)
        }
        None => checker // Empty expression {}
      }
    Element(element, _) => {
      // Nested element - recursively check
      let (_, c) = infer_type(checker, element)
      c
    }
    Fragment(fragment, _) => {
      // Fragment - recursively check
      let (_, c) = infer_type(checker, fragment)
      c
    }
  }
}

///|
/// Validate that a type is valid as JSX child
fn validate_jsx_child_type(checker : TypeChecker, child_type : Type) -> TypeChecker {
  // Valid JSX children: string, number, boolean, null, undefined, JSX.Element, arrays thereof
  match child_type {
    String(_) | Number(_) | Boolean(_) | Null(_) | Undefined(_) => checker
    StringLiteral(_, _) | NumberLiteral(_, _) | BooleanLiteral(_, _) => checker
    Array(_) => checker // Arrays of valid children
    Object(_) => checker // Assume JSX.Element or similar
    Union(_) => checker // Could contain valid types
    Any(_) => checker
    _ => checker // Be permissive for now
  }
}

// ============================================================================
// Component Props Type Extraction
// ============================================================================

///|
/// Get props type from function component type
fn get_function_props_type(_checker : TypeChecker, fn_type : CheckerFunctionType) -> Type? {
  // Function component: props is the first parameter
  if fn_type.parameters.length() > 0 {
    Some(fn_type.parameters[0].param_type)
  } else {
    None
  }
}

///|
/// Get props type from class component type
fn get_class_component_props_type(_checker : TypeChecker, obj_type : ObjectType) -> Type? {
  // Class component: look for constructor or props property
  match obj_type.properties.get("props") {
    Some(prop) => Some(prop.prop_type)
    None => None
  }
}

// ============================================================================
// JSX.Element Type
// ============================================================================

///|
/// Get or create the JSX.Element type
fn get_jsx_element_type(checker : TypeChecker) -> (Type, TypeChecker) {
  // Look up JSX.Element from JSX namespace
  match lookup_symbol(checker, "JSX") {
    Some(jsx_symbol) => {
      let (jsx_type, checker) = get_symbol_type(checker, jsx_symbol)
      match jsx_type {
        Some(Object(obj_type)) => {
          match obj_type.properties.get("Element") {
            Some(element_prop) => (element_prop.prop_type, checker)
            None => create_jsx_element_type(checker)
          }
        }
        _ => create_jsx_element_type(checker)
      }
    }
    None => create_jsx_element_type(checker)
  }
}

///|
/// Create a default JSX.Element type when JSX namespace is not available
fn create_jsx_element_type(checker : TypeChecker) -> (Type, TypeChecker) {
  // Create a placeholder object type representing JSX.Element
  let id = checker.next_type_id
  let flags = TypeFlags::{ is_readonly: false, is_optional: false }
  let jsx_element = Type::Object({
    properties: Map::new(),
    index_signatures: [],
    call_signatures: [],
    construct_signatures: [],
    info: { id, flags },
    class_name: None,
  })
  (jsx_element, { ..checker, next_type_id: id + 1 })
}

// ============================================================================
// JSX Diagnostic Errors
// ============================================================================

///|
/// Add a JSX-related diagnostic to the checker
fn add_jsx_diagnostic(
  checker : TypeChecker,
  code : Int,
  message : String,
  location : SourceLocation,
) -> TypeChecker {
  let diag = Diagnostic::{
    code,
    message,
    category: Error,
    location,
  }
  let diagnostics = checker.diagnostics
  diagnostics.push(diag)
  { ..checker, diagnostics }
}

///|
/// Create diagnostic for: Cannot find component (TS2604)
fn jsx_error_cannot_find_component(
  checker : TypeChecker,
  component : String,
  loc : SourceLocation,
) -> TypeChecker {
  add_jsx_diagnostic(
    checker,
    2604,
    "JSX element type '" + component + "' does not have any construct or call signatures.",
    loc,
  )
}

///|
/// Create diagnostic for: Property type mismatch (TS2322)
fn jsx_error_prop_type_mismatch(
  checker : TypeChecker,
  prop_name : String,
  actual : String,
  expected : String,
  loc : SourceLocation,
) -> TypeChecker {
  add_jsx_diagnostic(
    checker,
    2322,
    "Type '" + actual + "' is not assignable to type '" + expected + "' for prop '" + prop_name + "'.",
    loc,
  )
}

///|
/// Create diagnostic for: Unknown prop (TS2339)
fn jsx_error_unknown_prop(
  checker : TypeChecker,
  prop_name : String,
  element_type : String,
  loc : SourceLocation,
) -> TypeChecker {
  add_jsx_diagnostic(
    checker,
    2339,
    "Property '" + prop_name + "' does not exist on type '" + element_type + "'.",
    loc,
  )
}

///|
/// Create diagnostic for: Missing required prop (TS2741)
fn jsx_error_missing_prop(
  checker : TypeChecker,
  prop_name : String,
  element_type : String,
  loc : SourceLocation,
) -> TypeChecker {
  add_jsx_diagnostic(
    checker,
    2741,
    "Property '" + prop_name + "' is missing in props but required in type '" + element_type + "'.",
    loc,
  )
}

// ============================================================================
// Type Assignability Helper (simplified)
// ============================================================================

///|
/// Check if source type is assignable to target type (simplified for JSX)
fn is_type_assignable(source : Type, target : Type) -> Bool {
  match (source, target) {
    (Any(_), _) => true
    (_, Any(_)) => true
    (String(_), String(_)) => true
    (Number(_), Number(_)) => true
    (Boolean(_), Boolean(_)) => true
    (Null(_), Null(_)) => true
    (Undefined(_), Undefined(_)) => true
    (StringLiteral(s1, _), StringLiteral(s2, _)) => s1 == s2
    (StringLiteral(_, _), String(_)) => true
    (NumberLiteral(n1, _), NumberLiteral(n2, _)) => n1 == n2
    (NumberLiteral(_, _), Number(_)) => true
    (BooleanLiteral(b1, _), BooleanLiteral(b2, _)) => b1 == b2
    (BooleanLiteral(_, _), Boolean(_)) => true
    (Null(_), Undefined(_)) => true // Loose equality
    (Undefined(_), Null(_)) => true
    (_, Union(ut)) => {
      // Source assignable to union if assignable to any member
      ut.types.iter().any(fn(t) { is_type_assignable(source, t) })
    }
    (Union(ut), _) => {
      // Union assignable to target if all members assignable
      ut.types.iter().all(fn(t) { is_type_assignable(t, target) })
    }
    _ => true // Be permissive for complex types
  }
}

///|
/// Convert type to string for error messages (JSX-specific)
fn jsx_type_to_string(ty : Type) -> String {
  match ty {
    String(_) => "string"
    Number(_) => "number"
    Boolean(_) => "boolean"
    Void(_) => "void"
    Undefined(_) => "undefined"
    Null(_) => "null"
    Any(_) => "any"
    Unknown(_) => "unknown"
    Never(_) => "never"
    StringLiteral(s, _) => "\"" + s + "\""
    NumberLiteral(n, _) => n.to_string()
    BooleanLiteral(b, _) => if b { "true" } else { "false" }
    Array(at) => type_to_string(at.element_type) + "[]"
    Object(_) => "object"
    Function(_) => "function"
    Union(ut) => {
      let parts : Array[String] = []
      for i = 0; i < ut.types.length(); i = i + 1 {
        parts.push(type_to_string(ut.types[i]))
      }
      parts.join(" | ")
    }
    _ => "unknown"
  }
}
