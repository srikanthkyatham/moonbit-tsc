// Class Type System - OOP Features for TypeScript Compiler
// Implements Phase 2 of the TypeScript compiler feature gap:
// 1. Class member accessibility (public/private/protected)
// 2. Abstract class validation
// 3. Override compatibility checking
// 4. This type handling in classes

// ============================================================================
// Accessibility
// ============================================================================

///|
/// Member accessibility level
pub enum Accessibility {
  Public
  Private
  Protected
} derive(Show, Eq)

///|
/// Get accessibility from modifier list
pub fn get_accessibility(modifiers : Array[Modifier]) -> Accessibility {
  for m in modifiers {
    match m {
      Private => return Private
      Protected => return Protected
      Public => return Public
      _ => continue
    }
  }
  // Default is public in TypeScript
  Public
}

///|
/// Check if a modifier list contains 'static'
pub fn is_static_modifier(modifiers : Array[Modifier]) -> Bool {
  modifiers
  .iter()
  .any(fn(m) {
    match m {
      Static => true
      _ => false
    }
  })
}

///|
/// Check if a modifier list contains 'abstract'
pub fn is_abstract_modifier(modifiers : Array[Modifier]) -> Bool {
  modifiers
  .iter()
  .any(fn(m) {
    match m {
      Abstract => true
      _ => false
    }
  })
}

///|
/// Check if a modifier list contains 'readonly'
pub fn is_readonly_modifier(modifiers : Array[Modifier]) -> Bool {
  modifiers
  .iter()
  .any(fn(m) {
    match m {
      Readonly => true
      _ => false
    }
  })
}

// ============================================================================
// Class Member Info
// ============================================================================

///|
/// Information about a class member (property or method)
pub struct ClassMemberInfo {
  name : String
  ty : TypeV2
  accessibility : Accessibility
  is_static : Bool
  is_abstract : Bool
  is_readonly : Bool
  is_optional : Bool
  declared_in : String // Class name where this member was declared
} derive(Show, Eq)

///|
/// Create a class member info
pub fn ClassMemberInfo::new(
  name : String,
  ty : TypeV2,
  accessibility : Accessibility,
  is_static : Bool,
  is_abstract : Bool,
  is_readonly : Bool,
  is_optional : Bool,
  declared_in : String,
) -> ClassMemberInfo {
  {
    name,
    ty,
    accessibility,
    is_static,
    is_abstract,
    is_readonly,
    is_optional,
    declared_in,
  }
}

// ============================================================================
// Class Type Info
// ============================================================================

///|
/// Complete information about a class type
pub struct ClassTypeInfo {
  name : String
  type_params : Array[TypeParamV2]
  base_class : String? // Name of the base class
  base_type_args : Array[TypeV2] // Type arguments for base class
  implemented_interfaces : Array[String]
  members : Map[String, ClassMemberInfo]
  static_members : Map[String, ClassMemberInfo]
  construct_signatures : Array[FunctionTypeV2]
  is_abstract : Bool
  object_type : ObjectTypeV2 // The instance type
} derive(Show, Eq)

///|
/// Create an empty class type info
pub fn ClassTypeInfo::new(name : String) -> ClassTypeInfo {
  {
    name,
    type_params: [],
    base_class: None,
    base_type_args: [],
    implemented_interfaces: [],
    members: Map::new(),
    static_members: Map::new(),
    construct_signatures: [],
    is_abstract: false,
    object_type: ObjectTypeV2::empty(),
  }
}

// ============================================================================
// Access Checking
// ============================================================================

///|
/// Result of an access check
pub struct AccessCheckResult {
  allowed : Bool
  errors : Array[TypeMismatchError]
} derive(Show)

///|
/// Check if a member can be accessed from a given context
pub fn check_member_access(
  member_info : ClassMemberInfo,
  current_class : String?,
  is_subclass : Bool,
) -> AccessCheckResult {
  match member_info.accessibility {
    // Public members can be accessed from anywhere
    Public => { allowed: true, errors: [] }

    // Private members can only be accessed within the same class
    Private =>
      match current_class {
        Some(class_name) if class_name == member_info.declared_in =>
          { allowed: true, errors: [] }
        _ =>
          {
            allowed: false,
            errors: [
              TypeMismatchError::{
                path: PRoot,
                expected: TAny,
                actual: member_info.ty,
                reason: PrivateMemberAccess(
                  member_info.name,
                  member_info.declared_in,
                ),
                children: [],
                suggestions: [
                  "Property '" +
                  member_info.name +
                  "' is private and only accessible within class '" +
                  member_info.declared_in +
                  "'.",
                ],
              },
            ],
          }
      }

    // Protected members can be accessed within the class and subclasses
    Protected =>
      match current_class {
        Some(class_name) if class_name == member_info.declared_in =>
          { allowed: true, errors: [] }
        Some(_) if is_subclass => { allowed: true, errors: [] }
        _ =>
          {
            allowed: false,
            errors: [
              TypeMismatchError::{
                path: PRoot,
                expected: TAny,
                actual: member_info.ty,
                reason: ProtectedMemberAccess(
                  member_info.name,
                  member_info.declared_in,
                ),
                children: [],
                suggestions: [
                  "Property '" +
                  member_info.name +
                  "' is protected and only accessible within class '" +
                  member_info.declared_in +
                  "' and its subclasses.",
                ],
              },
            ],
          }
      }
  }
}

// ============================================================================
// Abstract Class Validation
// ============================================================================

///|
/// Check if instantiating a class is allowed (not abstract)
pub fn check_abstract_class_instantiation(
  class_info : ClassTypeInfo,
) -> Array[TypeMismatchError] {
  if class_info.is_abstract {
    [
      TypeMismatchError::{
        path: PRoot,
        expected: TAny,
        actual: TObject(class_info.object_type),
        reason: AbstractClassInstantiation(class_info.name),
        children: [],
        suggestions: [
          "Cannot create an instance of an abstract class.", "Create a concrete subclass that implements all abstract members.",
        ],
      },
    ]
  } else {
    []
  }
}

///|
/// Check if all abstract members from base class are implemented
pub fn check_abstract_members_implemented(
  class_info : ClassTypeInfo,
  base_class_info : ClassTypeInfo,
) -> Array[TypeMismatchError] {
  // Skip if the derived class is also abstract
  if class_info.is_abstract {
    return []
  }
  let errors : Array[TypeMismatchError] = []

  // Check each base class member
  for kv in base_class_info.members {
    let name = kv.0
    let base_member = kv.1
    if base_member.is_abstract {
      // Check if implemented in derived class
      match class_info.members.get(name) {
        None =>
          errors.push(TypeMismatchError::{
            path: PRoot,
            expected: base_member.ty,
            actual: TUndefined,
            reason: AbstractMemberNotImplemented(name, base_class_info.name),
            children: [],
            suggestions: [
              "Non-abstract class '" +
              class_info.name +
              "' does not implement inherited abstract member '" +
              name +
              "' from class '" +
              base_class_info.name +
              "'.",
            ],
          })
        Some(derived_member) =>
          if derived_member.is_abstract {
            errors.push(TypeMismatchError::{
              path: PRoot,
              expected: base_member.ty,
              actual: derived_member.ty,
              reason: AbstractMemberNotImplemented(name, base_class_info.name),
              children: [],
              suggestions: [
                "Non-abstract class '" +
                class_info.name +
                "' must provide implementation for abstract member '" +
                name +
                "'.",
              ],
            })
          }
      }
    }
  }
  errors
}

// ============================================================================
// Override Compatibility
// ============================================================================

///|
/// Check if a method override is compatible with the base method
pub fn check_method_override(
  base_method : FunctionTypeV2,
  derived_method : FunctionTypeV2,
  method_name : String,
  base_class : String,
  _derived_class : String,
) -> Array[TypeMismatchError] {
  let errors : Array[TypeMismatchError] = []

  // Check return type - covariant (derived can be narrower)
  if not(is_subtype_of(derived_method.return_type, base_method.return_type)) {
    errors.push(TypeMismatchError::{
      path: PReturnType(PRoot),
      expected: base_method.return_type,
      actual: derived_method.return_type,
      reason: OverrideReturnTypeMismatch(method_name, base_class),
      children: [],
      suggestions: [
        "Return type of override method must be assignable to return type of base method.",
      ],
    })
  }

  // Check parameters - contravariant (derived can be wider)
  // Also, derived must accept at least as many parameters
  let base_required = base_method.params
    .filter(fn(p) { not(p.optional) })
    .length()
  let derived_required = derived_method.params
    .filter(fn(p) { not(p.optional) })
    .length()
  if derived_required > base_required {
    errors.push(TypeMismatchError::{
      path: PRoot,
      expected: TFunction(base_method),
      actual: TFunction(derived_method),
      reason: OverrideParamCountMismatch(
        method_name, base_required, derived_required,
      ),
      children: [],
      suggestions: [
        "Override method must not require more parameters than base method.",
      ],
    })
  }

  // Check each parameter type - base param type must be subtype of derived param type (contravariant)
  for i in 0..<base_method.params.length() {
    if i < derived_method.params.length() {
      let base_param = base_method.params[i]
      let derived_param = derived_method.params[i]
      // Contravariance: base param should be subtype of derived param
      if not(is_subtype_of(base_param.ty, derived_param.ty)) {
        errors.push(TypeMismatchError::{
          path: PParameter(PRoot, i, base_param.name),
          expected: base_param.ty,
          actual: derived_param.ty,
          reason: OverrideParamTypeMismatch(method_name, i, base_param.name),
          children: [],
          suggestions: [
            "Parameter type of override method must be compatible with base method.",
          ],
        })
      }
    }
  }
  errors
}

///|
/// Check accessibility compatibility for overrides
pub fn check_override_accessibility(
  base_member : ClassMemberInfo,
  derived_member : ClassMemberInfo,
) -> Array[TypeMismatchError] {
  // Cannot make a member more restrictive than base
  let base_level = accessibility_level(base_member.accessibility)
  let derived_level = accessibility_level(derived_member.accessibility)
  if derived_level < base_level {
    [
      TypeMismatchError::{
        path: PRoot,
        expected: TAny,
        actual: derived_member.ty,
        reason: OverrideAccessibilityMismatch(
          derived_member.name,
          base_member.accessibility.to_string(),
          derived_member.accessibility.to_string(),
        ),
        children: [],
        suggestions: [
          "Override cannot have more restrictive accessibility than base member.",
          "Base member is " +
          base_member.accessibility.to_string() +
          ", but override is " +
          derived_member.accessibility.to_string() +
          ".",
        ],
      },
    ]
  } else {
    []
  }
}

///|
/// Get numeric level for accessibility comparison
fn accessibility_level(acc : Accessibility) -> Int {
  match acc {
    Public => 3 // Most permissive
    Protected => 2
    Private => 1 // Most restrictive
  }
}

// ============================================================================
// This Type Handling
// ============================================================================

///|
/// Create a polymorphic 'this' type for a class
pub fn create_this_type(class_info : ClassTypeInfo) -> TypeV2 {
  // 'this' in a class refers to the instance type
  // For a class C<T>, this has type C<T> (with type params in scope)
  if class_info.type_params.is_empty() {
    TObject(class_info.object_type)
  } else {
    // Create a generic instance with type params
    let type_args = class_info.type_params.map(fn(p) {
      TTypeParam(p.name, p.constraint)
    })
    TGenericInstance(class_info.name, type_args)
  }
}

// ============================================================================
// Class Declaration Checking
// ============================================================================

///|
/// Result of checking a class declaration
pub struct ClassCheckResult {
  class_info : ClassTypeInfo
  errors : Array[TypeMismatchError]
} derive(Show)

///|
/// Get class name from node
fn get_class_name(name_node : Node?) -> String {
  match name_node {
    Some(Identifier(id)) => id.name
    _ => "anonymous"
  }
}

///|
/// Build class type info from a class declaration
pub fn build_class_info(
  env : TypeEnv,
  cd : ClassDeclaration,
) -> ClassCheckResult {
  let errors : Array[TypeMismatchError] = []

  // Create base class info
  let class_info = ClassTypeInfo::{
    name: get_class_name(cd.name),
    type_params: cd.type_parameters.map(fn(tp) {
      TypeParamV2::{
        name: tp.name,
        constraint: match tp.constraint {
          Some(c) => Some(ast_type_to_v2(env, c))
          None => None
        },
        default_type: match tp.default {
          Some(d) => Some(ast_type_to_v2(env, d))
          None => None
        },
        is_const: tp.is_const,
        variance: None,
      }
    }),
    base_class: None,
    base_type_args: [],
    implemented_interfaces: [],
    members: Map::new(),
    static_members: Map::new(),
    construct_signatures: [],
    is_abstract: is_abstract_modifier(cd.modifiers),
    object_type: ObjectTypeV2::empty(),
  }

  // Process heritage clauses
  let class_info = process_heritage_clauses(
    env,
    class_info,
    cd.heritage_clauses,
  )

  // Process class members
  let (class_info, member_errors) = process_class_members(
    env,
    class_info,
    cd.members,
  )
  errors.append(member_errors)

  // Build the object type
  let object_type = build_class_object_type(class_info)
  let class_info = { ..class_info, object_type, }
  { class_info, errors }
}

///|
/// Process heritage clauses (extends, implements)
fn process_heritage_clauses(
  env : TypeEnv,
  class_info : ClassTypeInfo,
  clauses : Array[HeritageClause],
) -> ClassTypeInfo {
  let mut result = class_info
  for clause in clauses {
    match clause.kind {
      Extends =>
        // Can only extend one class
        if clause.types.length() > 0 {
          let base = clause.types[0]
          match base {
            TypeReference(tr) =>
              result = {
                ..result,
                base_class: Some(tr.type_name),
                base_type_args: tr.type_arguments.map(fn(ta) {
                  ast_type_to_v2(env, ta)
                }),
              }
            _ => ()
          }
        }
      Implements =>
        // Can implement multiple interfaces
        for iface in clause.types {
          match iface {
            TypeReference(tr) =>
              result = {
                ..result,
                implemented_interfaces: result.implemented_interfaces +
                [tr.type_name],
              }
            _ => ()
          }
        }
    }
  }
  result
}

///|
/// Process class members
fn process_class_members(
  env : TypeEnv,
  class_info : ClassTypeInfo,
  class_members : Array[Node],
) -> (ClassTypeInfo, Array[TypeMismatchError]) {
  let mut result = class_info
  let errors : Array[TypeMismatchError] = []

  // Create child env with class type params in scope
  let class_env = env.with_type_params(class_info.type_params)
  for class_member in class_members {
    match class_member {
      PropertyDeclaration(pd) => {
        let member_ty = match pd.type_annotation {
          Some(ta) => ast_type_to_v2(class_env, ta)
          None =>
            match pd.initializer {
              Some(init) => infer_class_member_expr_type(class_env, init)
              None => TAny
            }
        }
        let member_info = ClassMemberInfo::{
          name: pd.name,
          ty: member_ty,
          accessibility: get_accessibility(pd.modifiers),
          is_static: is_static_modifier(pd.modifiers),
          is_abstract: is_abstract_modifier(pd.modifiers),
          is_readonly: is_readonly_modifier(pd.modifiers),
          is_optional: pd.is_optional,
          declared_in: class_info.name,
        }
        if member_info.is_static {
          result.static_members.set(pd.name, member_info)
        } else {
          result.members.set(pd.name, member_info)
        }
      }
      MethodDeclaration(md) => {
        // Build function type for the method
        let method_type = build_method_type(class_env, md)
        let member_info = ClassMemberInfo::{
          name: md.name,
          ty: TFunction(method_type),
          accessibility: get_accessibility(md.modifiers),
          is_static: is_static_modifier(md.modifiers),
          is_abstract: is_abstract_modifier(md.modifiers),
          is_readonly: false,
          is_optional: md.is_optional,
          declared_in: class_info.name,
        }
        if member_info.is_static {
          result.static_members.set(md.name, member_info)
        } else {
          result.members.set(md.name, member_info)
        }
      }
      ConstructorDeclaration(ctr) => {
        let ctr_type = build_constructor_type(class_env, ctr)
        result = { ..result, construct_signatures: [ctr_type] }

        // Handle parameter properties
        for param in ctr.parameters {
          match param {
            Parameter(p) => {
              let param_accessibility = get_accessibility(p.modifiers)
              // Check if this is a parameter property (has accessibility modifier)
              let has_accessibility = p.modifiers
                .iter()
                .any(fn(m) {
                  match m {
                    Public | Private | Protected => true
                    _ => false
                  }
                })
              let has_readonly = is_readonly_modifier(p.modifiers)
              if has_accessibility || has_readonly {
                // This is a parameter property - add as class member
                let param_ty = match p.type_annotation {
                  Some(ta) => ast_type_to_v2(class_env, ta)
                  None => TAny
                }
                let param_name = get_param_name(p.name)
                let member_info = ClassMemberInfo::{
                  name: param_name,
                  ty: param_ty,
                  accessibility: if has_accessibility {
                    param_accessibility
                  } else {
                    Public
                  },
                  is_static: false,
                  is_abstract: false,
                  is_readonly: has_readonly,
                  is_optional: p.is_optional,
                  declared_in: class_info.name,
                }
                result.members.set(param_name, member_info)
              }
            }
            _ => ()
          }
        }
      }
      GetAccessor(ga) => {
        let getter_type = match ga.return_type {
          Some(rt) => ast_type_to_v2(class_env, rt)
          None => TAny
        }
        let member_info = ClassMemberInfo::{
          name: ga.name,
          ty: getter_type,
          accessibility: get_accessibility(ga.modifiers),
          is_static: is_static_modifier(ga.modifiers),
          is_abstract: is_abstract_modifier(ga.modifiers),
          is_readonly: true, // Getters are effectively readonly
          is_optional: false,
          declared_in: class_info.name,
        }
        if member_info.is_static {
          result.static_members.set(ga.name, member_info)
        } else {
          result.members.set(ga.name, member_info)
        }
      }
      SetAccessor(sa) => {
        // Get type from setter parameter
        let setter_type = match sa.parameter {
          Parameter(p) =>
            match p.type_annotation {
              Some(ta) => ast_type_to_v2(class_env, ta)
              None => TAny
            }
          _ => TAny
        }

        // Check if we already have a getter for this
        let existing_ty = if is_static_modifier(sa.modifiers) {
          result.static_members.get(sa.name).map(fn(m) { m.ty })
        } else {
          result.members.get(sa.name).map(fn(m) { m.ty })
        }

        // Only add if no getter exists (getter takes precedence for type)
        if existing_ty is None {
          let member_info = ClassMemberInfo::{
            name: sa.name,
            ty: setter_type,
            accessibility: get_accessibility(sa.modifiers),
            is_static: is_static_modifier(sa.modifiers),
            is_abstract: is_abstract_modifier(sa.modifiers),
            is_readonly: false,
            is_optional: false,
            declared_in: class_info.name,
          }
          if member_info.is_static {
            result.static_members.set(sa.name, member_info)
          } else {
            result.members.set(sa.name, member_info)
          }
        }
      }
      _ => ()
    }
  }
  (result, errors)
}

///|
/// Build function type for a method
fn build_method_type(env : TypeEnv, md : MethodDeclaration) -> FunctionTypeV2 {
  // Process type parameters
  let type_params = md.type_parameters.map(fn(tp) {
    TypeParamV2::{
      name: tp.name,
      constraint: match tp.constraint {
        Some(c) => Some(ast_type_to_v2(env, c))
        None => None
      },
      default_type: match tp.default {
        Some(d) => Some(ast_type_to_v2(env, d))
        None => None
      },
      is_const: tp.is_const,
      variance: None,
    }
  })

  // Create child env with method type params
  let method_env = env.with_type_params(type_params)

  // Process parameters
  let params : Array[ParamInfoV2] = []
  let mut rest_param : ParamInfoV2? = None
  for param in md.parameters {
    match param {
      Parameter(p) => {
        let param_ty = match p.type_annotation {
          Some(ta) => ast_type_to_v2(method_env, ta)
          None => TAny
        }
        let param_name = get_param_name(p.name)
        if p.is_rest {
          rest_param = Some(ParamInfoV2::{
            name: param_name,
            ty: param_ty,
            optional: p.is_optional,
            is_rest: true,
          })
        } else {
          params.push(ParamInfoV2::{
            name: param_name,
            ty: param_ty,
            optional: p.is_optional,
            is_rest: false,
          })
        }
      }
      _ => ()
    }
  }

  // Return type
  let return_type = match md.return_type {
    Some(rt) => ast_type_to_v2(method_env, rt)
    None => TAny
  }
  {
    type_params,
    params,
    rest_param,
    return_type,
    type_predicate: None,
    this_type: None,
  }
}

///|
/// Build function type for a constructor
fn build_constructor_type(
  env : TypeEnv,
  cd : ConstructorDeclaration,
) -> FunctionTypeV2 {
  let params : Array[ParamInfoV2] = []
  let mut rest_param : ParamInfoV2? = None
  for param in cd.parameters {
    match param {
      Parameter(p) => {
        let param_ty = match p.type_annotation {
          Some(ta) => ast_type_to_v2(env, ta)
          None => TAny
        }
        let param_name = get_param_name(p.name)
        if p.is_rest {
          rest_param = Some(ParamInfoV2::{
            name: param_name,
            ty: param_ty,
            optional: p.is_optional,
            is_rest: true,
          })
        } else {
          params.push(ParamInfoV2::{
            name: param_name,
            ty: param_ty,
            optional: p.is_optional,
            is_rest: false,
          })
        }
      }
      _ => ()
    }
  }
  {
    type_params: [],
    params,
    rest_param,
    return_type: TVoid,
    type_predicate: None,
    this_type: None,
  }
}

///|
/// Build the ObjectTypeV2 for a class instance
fn build_class_object_type(class_info : ClassTypeInfo) -> ObjectTypeV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  for kv in class_info.members {
    let name = kv.0
    let member_info = kv.1
    fields.set(name, FieldInfoV2::{
      ty: member_info.ty,
      optional: member_info.is_optional,
      is_readonly: member_info.is_readonly,
    })
  }
  {
    fields,
    symbol_fields: [],
    call_signatures: [],
    construct_signatures: class_info.construct_signatures,
    index_signature: None,
    is_class: true,
    class_name: Some(class_info.name),
  }
}

///|
/// Helper to infer expression type for class members (delegates to checker)
fn infer_class_member_expr_type(env : TypeEnv, node : Node) -> TypeV2 {
  let result = infer_expr_v2(env, node)
  result.ty
}
