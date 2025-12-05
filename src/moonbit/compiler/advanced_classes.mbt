// Advanced Class Features - Super Call Validation, Polymorphic This, Class Expressions
// Implements missing TypeScript class type checking features

// ============================================================================
// Super Call Validation (TS17009, TS2337, TS2377)
// ============================================================================
// TypeScript requires:
// 1. super() must be called before accessing 'this' in derived class constructors
// 2. super() must be called in derived class constructors
// 3. super() can only be called in constructors

///|
/// State for tracking super call and this access in constructor
pub struct ConstructorValidationState {
  /// Whether we're in a derived class (has extends clause)
  is_derived_class : Bool
  /// Whether super() has been called
  super_called : Bool
  /// Whether this has been accessed before super()
  this_accessed_before_super : Bool
  /// Whether we're currently in a constructor
  in_constructor : Bool
  /// Whether we're in a static method/property
  in_static_context : Bool
  /// The base class name (if derived)
  base_class_name : String?
}

///|
/// Create an initial constructor validation state
pub fn ConstructorValidationState::new() -> ConstructorValidationState {
  {
    is_derived_class: false,
    super_called: false,
    this_accessed_before_super: false,
    in_constructor: false,
    in_static_context: false,
    base_class_name: None,
  }
}

///|
/// Create state for a derived class constructor
pub fn ConstructorValidationState::for_derived_constructor(
  base_class : String,
) -> ConstructorValidationState {
  {
    is_derived_class: true,
    super_called: false,
    this_accessed_before_super: false,
    in_constructor: true,
    in_static_context: false,
    base_class_name: Some(base_class),
  }
}

///|
/// Create state for a non-derived class constructor
pub fn ConstructorValidationState::for_constructor() -> ConstructorValidationState {
  {
    is_derived_class: false,
    super_called: false,
    this_accessed_before_super: false,
    in_constructor: true,
    in_static_context: false,
    base_class_name: None,
  }
}

///|
/// Result of validating a constructor
pub struct ConstructorValidationResult {
  errors : Array[TypeMismatchError]
  super_call_found : Bool
}

///|
/// Validate a constructor body for super call requirements
pub fn validate_constructor_body(
  state : ConstructorValidationState,
  body : Node,
) -> ConstructorValidationResult {
  let errors : Array[TypeMismatchError] = []

  // Walk the body to find super() calls and this accesses
  let (found_super, found_this_before_super) = analyze_constructor_body_for_super(
    body, false, // super_called so far
     false, // in any nested function that would hide 'this'
  )

  // Check for errors in derived class constructor
  if state.is_derived_class {
    // Error if this is accessed before super
    if found_this_before_super {
      errors.push(TypeMismatchError::{
        path: PRoot,
        expected: TVoid,
        actual: TAny,
        reason: ThisBeforeSuperCall,
        children: [],
        suggestions: [
          "Call 'super()' before accessing 'this' in the constructor.", "Move the super() call to the beginning of the constructor.",
        ],
      })
    }

    // Error if super() is never called in derived class constructor
    if not(found_super) {
      let class_name = state.base_class_name.unwrap_or("unknown")
      errors.push(TypeMismatchError::{
        path: PRoot,
        expected: TVoid,
        actual: TAny,
        reason: SuperCallRequired(class_name),
        children: [],
        suggestions: [
          "Add a 'super()' call in the constructor.", "Derived classes must call super() in their constructor.",
        ],
      })
    }
  }
  { errors, super_call_found: found_super }
}

///|
/// Analyze constructor body for super() calls and this accesses
/// Returns (super_found, this_accessed_before_super)
fn analyze_constructor_body_for_super(
  node : Node,
  super_called : Bool,
  in_nested_function : Bool,
) -> (Bool, Bool) {
  match node {
    // super() call
    CallExpression(ce) =>
      match ce.expression {
        SuperExpression(_) => (true, false) // super() was called
        _ => {
          // Check arguments for this access
          let mut this_before = false
          for arg in ce.arguments {
            let (_, found_this) = analyze_constructor_body_for_super(
              arg, super_called, in_nested_function,
            )
            if found_this && not(super_called) {
              this_before = true
            }
          }
          // Also check the expression being called
          let (found_s, found_t) = analyze_constructor_body_for_super(
            ce.expression,
            super_called,
            in_nested_function,
          )
          (found_s, this_before || found_t)
        }
      }

    // this expression
    ThisExpression(_) =>
      if in_nested_function {
        // 'this' in nested function doesn't require super
        (false, false)
      } else {
        // 'this' accessed directly - check if before super
        (false, not(super_called))
      }

    // Block statement - process statements in order
    BlockStatement(bs) => {
      let mut current_super_called = super_called
      let mut this_before_super = false
      for stmt in bs.statements {
        let (found_super, found_this) = analyze_constructor_body_for_super(
          stmt, current_super_called, in_nested_function,
        )
        if found_super {
          current_super_called = true
        }
        if found_this && not(current_super_called) {
          this_before_super = true
        }
      }
      (current_super_called, this_before_super)
    }

    // Expression statement
    ExpressionStatement(es) =>
      analyze_constructor_body_for_super(
        es.expression,
        super_called,
        in_nested_function,
      )

    // If statement
    IfStatement(is_stmt) => {
      let (s1, t1) = analyze_constructor_body_for_super(
        is_stmt.condition,
        super_called,
        in_nested_function,
      )
      let (s2, t2) = analyze_constructor_body_for_super(
        is_stmt.then_statement,
        super_called || s1,
        in_nested_function,
      )
      let (s3, t3) = match is_stmt.else_statement {
        Some(else_stmt) =>
          analyze_constructor_body_for_super(
            else_stmt,
            super_called || s1,
            in_nested_function,
          )
        None => (false, false)
      }
      // Super is called if called in condition or both branches
      let super_called_in_both = (s2 && s3) || s1
      (super_called_in_both, t1 || t2 || t3)
    }

    // Arrow function / function expression - 'this' is lexically scoped for arrow
    ArrowFunction(_) =>
      // Arrow functions capture outer 'this', so we still need to check
      (false, false)
    FunctionExpression(_) =>
      // Regular function has its own 'this', so we don't need to check
      (false, false)

    // Variable statement - check initializers
    VariableStatement(vs) => {
      let mut found_super = false
      let mut found_this = false
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) => {
            let (s, t) = analyze_constructor_body_for_super(
              init,
              super_called || found_super,
              in_nested_function,
            )
            if s {
              found_super = true
            }
            if t {
              found_this = true
            }
          }
          None => ()
        }
      }
      (found_super, found_this)
    }

    // Return statement
    ReturnStatement(rs) =>
      match rs.expression {
        Some(arg) =>
          analyze_constructor_body_for_super(
            arg, super_called, in_nested_function,
          )
        None => (false, false)
      }

    // Binary expression (also handles assignments)
    BinaryExpression(be) => {
      let (s1, t1) = analyze_constructor_body_for_super(
        be.left,
        super_called,
        in_nested_function,
      )
      let (s2, t2) = analyze_constructor_body_for_super(
        be.right,
        super_called || s1,
        in_nested_function,
      )
      (s1 || s2, t1 || t2)
    }

    // Property access expression - check for this.x
    PropertyAccessExpression(pae) =>
      analyze_constructor_body_for_super(
        pae.expression,
        super_called,
        in_nested_function,
      )

    // Other nodes - default
    _ => (false, false)
  }
}

///|
/// Check if a super() call is valid in the current context
pub fn validate_super_call(
  in_constructor : Bool,
  is_derived : Bool,
) -> Array[TypeMismatchError] {
  let errors : Array[TypeMismatchError] = []

  // super() can only be called in constructors
  if not(in_constructor) {
    errors.push(TypeMismatchError::{
      path: PRoot,
      expected: TVoid,
      actual: TAny,
      reason: SuperCallOutsideConstructor,
      children: [],
      suggestions: [
        "'super()' can only be called inside a constructor.", "Use 'super.method()' to call a parent method.",
      ],
    })
  }

  // super() can only be used in derived classes
  if not(is_derived) && in_constructor {
    errors.push(TypeMismatchError::{
      path: PRoot,
      expected: TVoid,
      actual: TAny,
      reason: SuperPropertyOutsideClass,
      children: [],
      suggestions: [
        "'super' can only be used in a derived class.", "Add an 'extends' clause to your class.",
      ],
    })
  }
  errors
}

// ============================================================================
// Polymorphic This Type
// ============================================================================
// TypeScript supports a special 'this' type that refers to the type of the
// containing class or interface. It's polymorphic - in subclasses, 'this'
// refers to the subclass type, not the base class type.

///|
/// Represents the polymorphic 'this' type
pub struct PolymorphicThisType {
  /// The class/interface this type belongs to
  containing_class : String
  /// Type parameters in scope
  type_params : Array[TypeParamV2]
  /// Whether this is a static this (less common)
  is_static : Bool
}

///|
/// Create a polymorphic this type for a class
pub fn PolymorphicThisType::for_class(
  class_name : String,
  type_params : Array[TypeParamV2],
) -> PolymorphicThisType {
  { containing_class: class_name, type_params, is_static: false }
}

///|
/// Create the TypeV2 representation of a polymorphic this type
pub fn create_polymorphic_this_type(
  class_name : String,
  type_params : Array[TypeParamV2],
) -> TypeV2 {
  // 'this' type is represented as a generic instance of the class
  // with type parameters remaining as type parameters
  if type_params.is_empty() {
    // For non-generic classes, just use the class name as a reference
    TGenericInstance(class_name, [])
  } else {
    // For generic classes, this type includes the type parameters
    let type_args = type_params.map(fn(p) { TTypeParam(p.name, p.constraint) })
    TGenericInstance(class_name, type_args)
  }
}

///|
/// Resolve 'this' type in a method return type or property type
/// When a subclass inherits a method returning 'this', the return type
/// should be the subclass type, not the base class type.
pub fn resolve_this_type_in_derived(
  base_this_type : TypeV2,
  derived_class_name : String,
  derived_type_params : Array[TypeParamV2],
) -> TypeV2 {
  // Replace the base class reference with derived class reference
  substitute_this_type(base_this_type, derived_class_name, derived_type_params)
}

///|
/// Substitute 'this' type references in a type
fn substitute_this_type(
  ty : TypeV2,
  class_name : String,
  type_params : Array[TypeParamV2],
) -> TypeV2 {
  match ty {
    // Generic instance might be a 'this' type reference
    TGenericInstance(name, args) =>
      if is_this_type_reference(name) {
        create_polymorphic_this_type(class_name, type_params)
      } else {
        TGenericInstance(
          name,
          args.map(fn(a) { substitute_this_type(a, class_name, type_params) }),
        )
      }

    // Recursively process compound types
    TArray(elem) => TArray(substitute_this_type(elem, class_name, type_params))
    TUnion(types) =>
      TUnion(
        types.map(fn(t) { substitute_this_type(t, class_name, type_params) }),
      )
    TIntersection(types) =>
      TIntersection(
        types.map(fn(t) { substitute_this_type(t, class_name, type_params) }),
      )
    TFunction(func) =>
      TFunction(FunctionTypeV2::{
        type_params: func.type_params,
        params: func.params.map(fn(p) {
          ParamInfoV2::{
            name: p.name,
            ty: substitute_this_type(p.ty, class_name, type_params),
            optional: p.optional,
            is_rest: p.is_rest,
          }
        }),
        rest_param: match func.rest_param {
          Some(r) =>
            Some(ParamInfoV2::{
              name: r.name,
              ty: substitute_this_type(r.ty, class_name, type_params),
              optional: r.optional,
              is_rest: r.is_rest,
            })
          None => None
        },
        return_type: substitute_this_type(
          func.return_type,
          class_name,
          type_params,
        ),
        type_predicate: func.type_predicate,
        this_type: func.this_type.map(fn(t) {
          substitute_this_type(t, class_name, type_params)
        }),
      })

    // Other types pass through unchanged
    _ => ty
  }
}

///|
/// Check if a type name represents 'this' type
fn is_this_type_reference(name : String) -> Bool {
  name == "this" || name == "This"
}

// ============================================================================
// Class Expression Type Inference
// ============================================================================
// Class expressions: const MyClass = class { ... }
// Need to infer the type of the class expression as a constructor type

///|
/// Result of inferring a class expression type
pub struct ClassExpressionTypeResult {
  /// The constructor type (what you get when using 'new')
  constructor_type : TypeV2
  /// The instance type (what instances of the class have)
  instance_type : TypeV2
  /// The static type (static members)
  static_type : TypeV2
  /// Any errors during inference
  errors : Array[TypeMismatchError]
}

///|
/// Infer the type of a class expression
pub fn infer_class_expression_type(
  env : TypeEnv,
  class_decl : ClassDeclaration,
) -> ClassExpressionTypeResult {
  let errors : Array[TypeMismatchError] = []

  // Build class info using existing function
  let class_result = build_class_info(env, class_decl)
  errors.append(class_result.errors)
  let class_info = class_result.class_info

  // The instance type is the object type of the class
  let instance_type = TObject(class_info.object_type)

  // Build static type from static members
  let static_fields : Map[String, FieldInfoV2] = Map::new()
  class_info.static_members.each(fn(name, member_info) {
    static_fields.set(name, FieldInfoV2::{
      ty: member_info.ty,
      optional: member_info.is_optional,
      is_readonly: member_info.is_readonly,
    })
  })
  let static_type = TObject(ObjectTypeV2::{
    fields: static_fields,
    symbol_fields: [],
    call_signatures: [],
    construct_signatures: class_info.construct_signatures,
    index_signature: None,
    is_class: true,
    class_name: Some(class_info.name),
  })

  // The constructor type is a function that creates instances
  let constructor_type = build_class_expression_constructor_type(class_info)
  { constructor_type, instance_type, static_type, errors }
}

///|
/// Build the constructor type for a class expression
fn build_class_expression_constructor_type(
  class_info : ClassTypeInfo,
) -> TypeV2 {
  // If there are explicit construct signatures, use the first one
  if not(class_info.construct_signatures.is_empty()) {
    let sig = class_info.construct_signatures[0]
    return TFunction(sig)
  }

  // Otherwise, create a default constructor
  let instance_type = if class_info.type_params.is_empty() {
    TObject(class_info.object_type)
  } else {
    let type_args = class_info.type_params.map(fn(p) {
      TTypeParam(p.name, p.constraint)
    })
    TGenericInstance(class_info.name, type_args)
  }
  TFunction(FunctionTypeV2::{
    type_params: class_info.type_params,
    params: [],
    rest_param: None,
    return_type: instance_type,
    type_predicate: None,
    this_type: None,
  })
}

// ============================================================================
// Super Expression Resolution
// ============================================================================
// Resolve super.property and super.method() accesses

///|
/// Result of resolving a super property access
pub struct SuperResolutionResult {
  resolved_type : TypeV2
  errors : Array[TypeMismatchError]
}

///|
/// Resolve super property access (super.foo)
pub fn resolve_super_property(
  base_class_info : ClassTypeInfo?,
  property_name : String,
) -> SuperResolutionResult {
  let errors : Array[TypeMismatchError] = []
  match base_class_info {
    None => {
      // No base class
      errors.push(TypeMismatchError::{
        path: PRoot,
        expected: TAny,
        actual: TAny,
        reason: SuperPropertyOutsideClass,
        children: [],
        suggestions: [
          "'super' can only be used in a derived class.", "Add an 'extends' clause to access parent members.",
        ],
      })
      { resolved_type: TError, errors }
    }
    Some(base) =>
      // Look up the property in the base class
      match base.members.get(property_name) {
        Some(member_info) =>
          // Check accessibility
          match member_info.accessibility {
            Private => {
              errors.push(TypeMismatchError::{
                path: PRoot,
                expected: member_info.ty,
                actual: TAny,
                reason: PrivateMemberAccess(property_name, base.name),
                children: [],
                suggestions: [
                  "Cannot access private member '" +
                  property_name +
                  "' via super.",
                  "Make the member protected or public.",
                ],
              })
              { resolved_type: TError, errors }
            }
            Protected | Public => { resolved_type: member_info.ty, errors }
          }
        None =>
          // Try static members
          match base.static_members.get(property_name) {
            Some(member_info) => { resolved_type: member_info.ty, errors }
            None => {
              errors.push(TypeMismatchError::{
                path: PRoot,
                expected: TAny,
                actual: TAny,
                reason: SuperPropertyAccess(property_name),
                children: [],
                suggestions: [
                  "Property '" +
                  property_name +
                  "' does not exist on base class '" +
                  base.name +
                  "'.",
                ],
              })
              { resolved_type: TError, errors }
            }
          }
      }
  }
}

///|
/// Resolve super method call (super.foo())
pub fn resolve_super_method_call(
  base_class_info : ClassTypeInfo?,
  method_name : String,
  arg_types : Array[TypeV2],
) -> SuperResolutionResult {
  // First resolve the property
  let prop_result = resolve_super_property(base_class_info, method_name)
  if not(prop_result.errors.is_empty()) {
    return prop_result
  }

  // Check if the property is callable
  match prop_result.resolved_type {
    TFunction(func) => {
      // Validate argument types (simplified)
      let errors : Array[TypeMismatchError] = []
      let required_params = func.params
        .filter(fn(p) { not(p.optional) })
        .length()
      if arg_types.length() < required_params {
        errors.push(TypeMismatchError::{
          path: PRoot,
          expected: TFunction(func),
          actual: TAny,
          reason: ParamCountMismatch(required_params, arg_types.length()),
          children: [],
          suggestions: [],
        })
      }
      { resolved_type: func.return_type, errors }
    }
    _ => {
      let errors : Array[TypeMismatchError] = []
      errors.push(TypeMismatchError::{
        path: PRoot,
        expected: TAny,
        actual: prop_result.resolved_type,
        reason: NotCallable,
        children: [],
        suggestions: ["'" + method_name + "' is not a method."],
      })
      { resolved_type: TError, errors }
    }
  }
}

///|
/// Resolve super() call in constructor
pub fn resolve_super_constructor_call(
  base_class_info : ClassTypeInfo?,
  arg_types : Array[TypeV2],
) -> SuperResolutionResult {
  let errors : Array[TypeMismatchError] = []
  match base_class_info {
    None => {
      errors.push(TypeMismatchError::{
        path: PRoot,
        expected: TAny,
        actual: TAny,
        reason: SuperPropertyOutsideClass,
        children: [],
        suggestions: [
          "'super()' can only be used in a derived class constructor.",
        ],
      })
      { resolved_type: TError, errors }
    }
    Some(base) =>
      // Get the constructor signature from base class
      if base.construct_signatures.is_empty() {
        // Default constructor takes no arguments
        if not(arg_types.is_empty()) {
          errors.push(TypeMismatchError::{
            path: PRoot,
            expected: TVoid,
            actual: TAny,
            reason: ParamCountMismatch(0, arg_types.length()),
            children: [],
            suggestions: [
              "Base class has no explicit constructor.", "Remove arguments from super() call.",
            ],
          })
        }
        { resolved_type: TVoid, errors }
      } else {
        // Use the first construct signature
        let ctor = base.construct_signatures[0]
        let required = ctor.params.filter(fn(p) { not(p.optional) }).length()
        if arg_types.length() < required {
          errors.push(TypeMismatchError::{
            path: PRoot,
            expected: TFunction(ctor),
            actual: TAny,
            reason: ParamCountMismatch(required, arg_types.length()),
            children: [],
            suggestions: [],
          })
        }
        { resolved_type: TVoid, errors }
      }
  }
}

// ============================================================================
// Constructor Functions for Read-Only Enums (for tests)
// ============================================================================

///|
/// Create ThisBeforeSuperCall error reason
pub fn MismatchReason::this_before_super() -> MismatchReason {
  ThisBeforeSuperCall
}

///|
/// Create SuperCallRequired error reason
pub fn MismatchReason::super_call_required(
  class_name : String,
) -> MismatchReason {
  SuperCallRequired(class_name)
}

///|
/// Create SuperCallOutsideConstructor error reason
pub fn MismatchReason::super_outside_constructor() -> MismatchReason {
  SuperCallOutsideConstructor
}

///|
/// Create SuperPropertyOutsideClass error reason
pub fn MismatchReason::super_outside_class() -> MismatchReason {
  SuperPropertyOutsideClass
}

///|
/// Create SuperPropertyAccess error reason
pub fn MismatchReason::super_property_access(prop : String) -> MismatchReason {
  SuperPropertyAccess(prop)
}
