// TypeEnv - Type Environment for Bidirectional Type Checking
// Manages type bindings, narrowings, and scoped lookups

///|
/// Type alias information
pub struct TypeAliasInfoV2 {
  type_params : Array[TypeParamV2]
  body : TypeV2
} derive(Show, Eq)

///|
/// Import binding info - maps local name to external module/export
pub struct ImportBindingInfo {
  /// Module path the import comes from
  module_path : String
  /// Name in the source module (may differ from local name for renamed imports)
  imported_name : String
  /// Whether this is a default import
  is_default : Bool
  /// Whether this is a namespace import (import * as ns)
  is_namespace : Bool
} derive(Show, Eq)

///|
/// Create a named import binding
pub fn ImportBindingInfo::named(
  module_path : String,
  imported_name : String,
) -> ImportBindingInfo {
  { module_path, imported_name, is_default: false, is_namespace: false }
}

///|
/// Create a default import binding
pub fn ImportBindingInfo::default(module_path : String) -> ImportBindingInfo {
  {
    module_path,
    imported_name: "default",
    is_default: true,
    is_namespace: false,
  }
}

///|
/// Create a namespace import binding
pub fn ImportBindingInfo::namespace(module_path : String) -> ImportBindingInfo {
  { module_path, imported_name: "*", is_default: false, is_namespace: true }
}

///|
/// Type environment with scoped bindings
/// Supports lexical scoping through parent chain
pub struct TypeEnv {
  variables : Map[String, TypeV2]
  type_aliases : Map[String, TypeAliasInfoV2]
  interfaces : Map[String, ObjectTypeV2]
  type_params : Map[String, TypeParamV2]
  narrowings : Map[String, TypeV2]
  parent : TypeEnv?
  /// External type registry for cross-file type resolution
  external_registry : ExternalTypeRegistry?
  /// Import bindings: local_name -> ImportBindingInfo
  import_bindings : Map[String, ImportBindingInfo]
} derive(Show, Eq)

///|
/// Create a new empty type environment
pub fn TypeEnv::new() -> TypeEnv {
  {
    variables: Map::new(),
    type_aliases: Map::new(),
    interfaces: Map::new(),
    type_params: Map::new(),
    narrowings: Map::new(),
    parent: None,
    external_registry: None,
    import_bindings: Map::new(),
  }
}

///|
/// Create a new type environment with external type registry
pub fn TypeEnv::with_external_registry(
  registry : ExternalTypeRegistry,
) -> TypeEnv {
  {
    variables: Map::new(),
    type_aliases: Map::new(),
    interfaces: Map::new(),
    type_params: Map::new(),
    narrowings: Map::new(),
    parent: None,
    external_registry: Some(registry),
    import_bindings: Map::new(),
  }
}

///|
/// Create a child environment (for nested scopes like function bodies, blocks)
pub fn TypeEnv::child(self : TypeEnv) -> TypeEnv {
  {
    variables: Map::new(),
    type_aliases: Map::new(),
    interfaces: Map::new(),
    type_params: Map::new(),
    narrowings: Map::new(),
    parent: Some(self),
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Create a closure child environment that inherits narrowings from parent
/// This implements control flow narrowing in nested closures.
/// When a closure captures a variable that has been narrowed, the narrowing
/// persists inside the closure (assuming the variable isn't reassigned).
///
/// Example:
///   function example(x: string | number) {
///     if (typeof x === "string") {
///       const fn = () => {
///         x.toUpperCase(); // x is narrowed to string here
///       };
///     }
///   }
pub fn TypeEnv::closure_child(self : TypeEnv) -> TypeEnv {
  // Collect all narrowings from the entire parent chain
  let inherited_narrowings : Map[String, TypeV2] = Map::new()
  let mut current : TypeEnv? = Some(self)
  while true {
    match current {
      Some(env) => {
        // Copy narrowings from this level (don't overwrite existing ones)
        for kv in env.narrowings {
          let name = kv.0
          let ty = kv.1
          if not(inherited_narrowings.contains(name)) {
            inherited_narrowings.set(name, ty)
          }
        }
        current = env.parent
      }
      None => break
    }
  }
  {
    variables: Map::new(),
    type_aliases: Map::new(),
    interfaces: Map::new(),
    type_params: Map::new(),
    narrowings: inherited_narrowings,
    parent: Some(self),
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Look up a variable type in the environment chain
pub fn TypeEnv::lookup(self : TypeEnv, name : String) -> TypeV2? {
  // First check narrowings (narrowed types take precedence)
  match self.narrowings.get(name) {
    Some(ty) => Some(ty)
    None =>
      // Then check regular variable bindings
      match self.variables.get(name) {
        Some(ty) => Some(ty)
        None =>
          // Check import bindings for external types
          match self.lookup_imported(name) {
            Some(ty) => Some(ty)
            None =>
              // Finally check parent scope
              match self.parent {
                Some(p) => p.lookup(name)
                None => None
              }
          }
      }
  }
}

///|
/// Look up a type from an imported symbol
pub fn TypeEnv::lookup_imported(self : TypeEnv, name : String) -> TypeV2? {
  // Check if this name is an import binding
  match self.import_bindings.get(name) {
    None => None
    Some(binding) =>
      // Look up the type from the external registry
      match self.external_registry {
        None => None
        Some(registry) =>
          if binding.is_default {
            // Default import - look up default export
            match registry.lookup_default(binding.module_path) {
              Some(info) => Some(info.ty)
              None => None
            }
          } else if binding.is_namespace {
            // Namespace import - create an object type with all exports
            match registry.get_module(binding.module_path) {
              None => None
              Some(module_types) => {
                // Build an object type from all exports
                let fields : Map[String, FieldInfoV2] = Map::new()
                for kv in module_types.named_exports {
                  fields.set(kv.0, FieldInfoV2::required(kv.1.ty))
                }
                Some(
                  TObject(ObjectTypeV2::{
                    fields,
                    symbol_fields: [],
                    call_signatures: [],
                    construct_signatures: [],
                    index_signature: None,
                    is_class: false,
                    class_name: None,
                  }),
                )
              }
            }
          } else {
            // Named import - look up specific export
            match
              registry.lookup_export(binding.module_path, binding.imported_name) {
              Some(info) => Some(info.ty)
              None => None
            }
          }
      }
  }
}

///|
/// Look up a variable's base type (without narrowings)
pub fn TypeEnv::lookup_base(self : TypeEnv, name : String) -> TypeV2? {
  match self.variables.get(name) {
    Some(ty) => Some(ty)
    None =>
      match self.parent {
        Some(p) => p.lookup_base(name)
        None => None
      }
  }
}

///|
/// Look up a type alias
pub fn TypeEnv::lookup_type_alias(
  self : TypeEnv,
  name : String,
) -> TypeAliasInfoV2? {
  match self.type_aliases.get(name) {
    Some(type_alias) => Some(type_alias)
    None =>
      match self.parent {
        Some(p) => p.lookup_type_alias(name)
        None => None
      }
  }
}

///|
/// Look up an interface/object type
pub fn TypeEnv::lookup_interface(
  self : TypeEnv,
  name : String,
) -> ObjectTypeV2? {
  match self.interfaces.get(name) {
    Some(obj) => Some(obj)
    None =>
      match self.parent {
        Some(p) => p.lookup_interface(name)
        None => None
      }
  }
}

///|
/// Look up a type parameter
pub fn TypeEnv::lookup_type_param(
  self : TypeEnv,
  name : String,
) -> TypeParamV2? {
  match self.type_params.get(name) {
    Some(param) => Some(param)
    None =>
      match self.parent {
        Some(p) => p.lookup_type_param(name)
        None => None
      }
  }
}

///|
/// Add an import binding (returns new environment)
pub fn TypeEnv::with_import_binding(
  self : TypeEnv,
  local_name : String,
  binding : ImportBindingInfo,
) -> TypeEnv {
  let new_bindings = self.import_bindings
  new_bindings.set(local_name, binding)
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: self.narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: new_bindings,
  }
}

///|
/// Add a variable binding (returns new environment)
pub fn TypeEnv::with_variable(
  self : TypeEnv,
  name : String,
  ty : TypeV2,
) -> TypeEnv {
  let new_vars = self.variables
  new_vars.set(name, ty)
  {
    variables: new_vars,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: self.narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Add multiple variable bindings
pub fn TypeEnv::with_variables(
  self : TypeEnv,
  bindings : Array[(String, TypeV2)],
) -> TypeEnv {
  let new_vars = self.variables
  for binding in bindings {
    new_vars.set(binding.0, binding.1)
  }
  {
    variables: new_vars,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: self.narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Add a type alias
pub fn TypeEnv::with_type_alias(
  self : TypeEnv,
  name : String,
  type_alias_info : TypeAliasInfoV2,
) -> TypeEnv {
  let new_aliases = self.type_aliases
  new_aliases.set(name, type_alias_info)
  {
    variables: self.variables,
    type_aliases: new_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: self.narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Add an interface (supports declaration merging)
/// If an interface with the same name already exists, merge them
pub fn TypeEnv::with_interface(
  self : TypeEnv,
  name : String,
  obj : ObjectTypeV2,
) -> TypeEnv {
  let new_interfaces = self.interfaces
  // Check if interface already exists for merging
  let merged_obj = match new_interfaces.get(name) {
    Some(existing) => merge_object_types(existing, obj)
    None => obj
  }
  new_interfaces.set(name, merged_obj)
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: new_interfaces,
    type_params: self.type_params,
    narrowings: self.narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Add type parameters to scope
pub fn TypeEnv::with_type_params(
  self : TypeEnv,
  params : Array[TypeParamV2],
) -> TypeEnv {
  let new_params = self.type_params
  for param in params {
    new_params.set(param.name, param)
  }
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: new_params,
    narrowings: self.narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Add a narrowing (returns new environment)
pub fn TypeEnv::with_narrowing(
  self : TypeEnv,
  name : String,
  ty : TypeV2,
) -> TypeEnv {
  let new_narrowings = self.narrowings
  new_narrowings.set(name, ty)
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: new_narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Add multiple narrowings
pub fn TypeEnv::with_narrowings(
  self : TypeEnv,
  narrows : Array[(String, TypeV2)],
) -> TypeEnv {
  let new_narrowings = self.narrowings
  for narrow in narrows {
    new_narrowings.set(narrow.0, narrow.1)
  }
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: new_narrowings,
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Clear all narrowings (for after control flow merges)
pub fn TypeEnv::clear_narrowings(self : TypeEnv) -> TypeEnv {
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: self.interfaces,
    type_params: self.type_params,
    narrowings: Map::new(),
    parent: self.parent,
    external_registry: self.external_registry,
    import_bindings: self.import_bindings,
  }
}

///|
/// Resolve a type alias with given type arguments
pub fn TypeEnv::resolve_type_alias(
  self : TypeEnv,
  name : String,
  args : Array[TypeV2],
) -> TypeV2? {
  match self.lookup_type_alias(name) {
    None => None
    Some(type_alias_info) =>
      if type_alias_info.type_params.is_empty() {
        Some(type_alias_info.body)
      } else {
        // Substitute type arguments
        Some(
          substitute_type_params_v2(
            type_alias_info.body,
            type_alias_info.type_params,
            args,
          ),
        )
      }
  }
}

///|
/// Apply narrowing to a variable's type
pub fn TypeEnv::apply_narrowing(
  self : TypeEnv,
  narrowing : Narrowing,
) -> TypeEnv {
  match narrowing {
    NNone => self
    NTypeof(name, type_str) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) =>
          match typeof_narrowed_type(type_str) {
            None => self
            Some(narrowed) => {
              let new_ty = intersect_types(current_ty, narrowed)
              self.with_narrowing(name, new_ty)
            }
          }
      }
    NInstanceof(name, instance_ty) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          let new_ty = intersect_types(current_ty, instance_ty)
          self.with_narrowing(name, new_ty)
        }
      }
    NTruthy(name) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          let new_ty = apply_truthy_narrowing(current_ty)
          self.with_narrowing(name, new_ty)
        }
      }
    NEquality(name, eq_ty) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          let new_ty = intersect_types(current_ty, eq_ty)
          self.with_narrowing(name, new_ty)
        }
      }
    NInequality(name, neq_ty) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          let new_ty = exclude_type(current_ty, neq_ty)
          self.with_narrowing(name, new_ty)
        }
      }
    NHasProperty(name, prop) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          let new_ty = apply_has_property_narrowing(current_ty, prop)
          self.with_narrowing(name, new_ty)
        }
      }
    NNullCheck(name, is_null) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) =>
          if is_null {
            self.with_narrowing(name, TNull)
          } else {
            let new_ty = exclude_type(current_ty, TNull)
            self.with_narrowing(name, new_ty)
          }
      }
    NUndefinedCheck(name, is_undef) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) =>
          if is_undef {
            self.with_narrowing(name, TUndefined)
          } else {
            let new_ty = exclude_type(current_ty, TUndefined)
            self.with_narrowing(name, new_ty)
          }
      }
    NPropertyEquality(obj_name, prop_name, value_type) =>
      match self.lookup_base(obj_name) {
        None => self
        Some(current_ty) => {
          let new_ty = apply_property_equality_narrowing(
            current_ty, prop_name, value_type,
          )
          self.with_narrowing(obj_name, new_ty)
        }
      }
    NPropertyInequality(obj_name, prop_name, value_type) =>
      match self.lookup_base(obj_name) {
        None => self
        Some(current_ty) => {
          let new_ty = apply_property_inequality_narrowing(
            current_ty, prop_name, value_type,
          )
          self.with_narrowing(obj_name, new_ty)
        }
      }
    NIsArray(name) =>
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          let new_ty = apply_is_array_narrowing(current_ty)
          self.with_narrowing(name, new_ty)
        }
      }
    NTypePredicate(name, predicate_ty) =>
      // User-defined type guard: x is Type
      // Narrows the variable to the predicate type
      match self.lookup_base(name) {
        None => self
        Some(current_ty) => {
          // Intersect current type with predicate type
          let new_ty = intersect_types(current_ty, predicate_ty)
          self.with_narrowing(name, new_ty)
        }
      }
    NAsserts(name, maybe_ty) =>
      // Assertion function: asserts x, asserts x is Type
      // Narrows after the assertion (only in then branch, not else)
      match maybe_ty {
        None =>
          // asserts x - just truthy narrowing
          match self.lookup_base(name) {
            None => self
            Some(current_ty) => {
              let new_ty = apply_truthy_narrowing(current_ty)
              self.with_narrowing(name, new_ty)
            }
          }
        Some(predicate_ty) =>
          // asserts x is Type - narrow to predicate type
          match self.lookup_base(name) {
            None => self
            Some(current_ty) => {
              let new_ty = intersect_types(current_ty, predicate_ty)
              self.with_narrowing(name, new_ty)
            }
          }
      }
    NAnd(a, b) => {
      let env1 = self.apply_narrowing(a)
      env1.apply_narrowing(b)
    }
    NOr(a, b) => {
      // For OR, we need the intersection of what both branches narrow
      // This is conservative - only narrow if both branches narrow the same
      let env_a = self.apply_narrowing(a)
      let env_b = self.apply_narrowing(b)
      merge_narrowing_envs(self, env_a, env_b)
    }
    NNot(inner) => {
      // Apply the inverted narrowing
      let inverted = invert_narrowing(inner)
      self.apply_narrowing(inverted)
    }
  }
}

///|
/// Substitute type parameters with actual type arguments
fn substitute_type_params_v2(
  ty : TypeV2,
  params : Array[TypeParamV2],
  args : Array[TypeV2],
) -> TypeV2 {
  // Build substitution map
  let subst : Map[String, TypeV2] = Map::new()
  for i in 0..<params.length() {
    if i < args.length() {
      subst.set(params[i].name, args[i])
    } else {
      // Use default if available
      match params[i].default_type {
        Some(default_ty) => subst.set(params[i].name, default_ty)
        None => ()
      }
    }
  }
  subst_in_type_v2(ty, subst)
}

///|
/// Apply substitution to a type
fn subst_in_type_v2(ty : TypeV2, subst : Map[String, TypeV2]) -> TypeV2 {
  match ty {
    TTypeParam(name, _) =>
      match subst.get(name) {
        Some(replacement) => replacement
        None => ty
      }
    TUnion(types) => TUnion(types.map(fn(t) { subst_in_type_v2(t, subst) }))
    TIntersection(types) =>
      TIntersection(types.map(fn(t) { subst_in_type_v2(t, subst) }))
    TArray(elem) => TArray(subst_in_type_v2(elem, subst))
    TTuple(elems) =>
      TTuple(
        elems.map(fn(e) {
          {
            ty: subst_in_type_v2(e.ty, subst),
            optional: e.optional,
            is_rest: e.is_rest,
            label: e.label,
          }
        }),
      )
    TObject(obj) => TObject(subst_in_object_v2(obj, subst))
    TFunction(f) => TFunction(subst_in_function_v2(f, subst))
    TGenericInstance(name, args) =>
      TGenericInstance(name, args.map(fn(t) { subst_in_type_v2(t, subst) }))
    TConditional(c) =>
      TConditional({
        check_type: subst_in_type_v2(c.check_type, subst),
        extends_type: subst_in_type_v2(c.extends_type, subst),
        true_type: subst_in_type_v2(c.true_type, subst),
        false_type: subst_in_type_v2(c.false_type, subst),
      })
    TIndexAccess(ia) =>
      TIndexAccess({
        object_type: subst_in_type_v2(ia.object_type, subst),
        index_type: subst_in_type_v2(ia.index_type, subst),
      })
    TMapped(m) =>
      TMapped(MappedTypeV2::{
        type_param: m.type_param,
        constraint: subst_in_type_v2(m.constraint, subst),
        name_type: match m.name_type {
          Some(n) => Some(subst_in_type_v2(n, subst))
          None => None
        },
        template_type: subst_in_type_v2(m.template_type, subst),
        readonly_modifier: m.readonly_modifier,
        optional_modifier: m.optional_modifier,
        source_type: match m.source_type {
          Some(s) => Some(subst_in_type_v2(s, subst))
          None => None
        },
      })
    // Primitives and literals don't change
    _ => ty
  }
}

///|
/// Apply substitution to object type
fn subst_in_object_v2(
  obj : ObjectTypeV2,
  subst : Map[String, TypeV2],
) -> ObjectTypeV2 {
  let new_fields : Map[String, FieldInfoV2] = Map::new()
  for kv in obj.fields {
    new_fields.set(kv.0, {
      ty: subst_in_type_v2(kv.1.ty, subst),
      optional: kv.1.optional,
      is_readonly: kv.1.is_readonly,
    })
  }
  {
    fields: new_fields,
    symbol_fields: obj.symbol_fields.map(fn(sp) {
      SymbolPropertyV2::{
        symbol: sp.symbol,
        field: FieldInfoV2::{
          ty: subst_in_type_v2(sp.field.ty, subst),
          optional: sp.field.optional,
          is_readonly: sp.field.is_readonly,
        },
      }
    }),
    call_signatures: obj.call_signatures.map(fn(f) {
      subst_in_function_v2(f, subst)
    }),
    construct_signatures: obj.construct_signatures.map(fn(f) {
      subst_in_function_v2(f, subst)
    }),
    index_signature: match obj.index_signature {
      None => None
      Some(sig) =>
        Some({
          key_type: subst_in_type_v2(sig.key_type, subst),
          value_type: subst_in_type_v2(sig.value_type, subst),
          is_readonly: sig.is_readonly,
        })
    },
    is_class: obj.is_class,
    class_name: obj.class_name,
  }
}

///|
/// Apply substitution to function type
fn subst_in_function_v2(
  f : FunctionTypeV2,
  subst : Map[String, TypeV2],
) -> FunctionTypeV2 {
  {
    type_params: f.type_params, // Don't substitute bound type params
    params: f.params.map(fn(p) {
      {
        name: p.name,
        ty: subst_in_type_v2(p.ty, subst),
        optional: p.optional,
        is_rest: p.is_rest,
      }
    }),
    rest_param: match f.rest_param {
      None => None
      Some(r) =>
        Some({
          name: r.name,
          ty: subst_in_type_v2(r.ty, subst),
          optional: r.optional,
          is_rest: r.is_rest,
        })
    },
    return_type: subst_in_type_v2(f.return_type, subst),
    type_predicate: f.type_predicate,
    this_type: f.this_type.map(fn(t) { subst_in_type_v2(t, subst) }),
  }
}

///|
/// Merge two narrowing environments (for OR branches)
/// Takes the "widest" narrowing that both branches agree on
fn merge_narrowing_envs(
  base : TypeEnv,
  env_a : TypeEnv,
  env_b : TypeEnv,
) -> TypeEnv {
  let merged_narrowings : Map[String, TypeV2] = Map::new()

  // For each narrowing in A, check if B also narrows that variable
  for kv in env_a.narrowings {
    let name = kv.0
    let ty_a = kv.1
    match env_b.narrowings.get(name) {
      Some(ty_b) => {
        // Both narrow this variable - take the union (widest type)
        let merged = make_union([ty_a, ty_b])
        merged_narrowings.set(name, merged)
      }
      None => () // Only A narrows, don't include
    }
  }
  {
    variables: base.variables,
    type_aliases: base.type_aliases,
    interfaces: base.interfaces,
    type_params: base.type_params,
    narrowings: merged_narrowings,
    parent: base.parent,
    external_registry: base.external_registry,
    import_bindings: base.import_bindings,
  }
}

// ============================================================================
// Built-in Type Environment
// ============================================================================

///|
/// Create an environment with built-in types
pub fn TypeEnv::with_builtins() -> TypeEnv {
  let env = TypeEnv::new()

  // Add built-in type aliases
  let env = env.with_type_alias("Array", {
    type_params: [TypeParamV2::simple("T")],
    body: TArray(TTypeParam("T", None)),
  })
  let env = env.with_type_alias("ReadonlyArray", {
    type_params: [TypeParamV2::simple("T")],
    body: TArray(TTypeParam("T", None)),
  })

  // Add Promise type
  let env = env.with_type_alias("Promise", {
    type_params: [TypeParamV2::simple("T")],
    body: TGenericInstance("Promise", [TTypeParam("T", None)]),
  })

  // Add Map type
  let env = env.with_type_alias("Map", {
    type_params: [TypeParamV2::simple("K"), TypeParamV2::simple("V")],
    body: TGenericInstance("Map", [TTypeParam("K", None), TTypeParam("V", None)]),
  })

  // Add Set type
  let env = env.with_type_alias("Set", {
    type_params: [TypeParamV2::simple("T")],
    body: TGenericInstance("Set", [TTypeParam("T", None)]),
  })

  // Add ThisType<T> - marker type for typing `this` in object literal methods
  // Used as: methods?: M & ThisType<D & M>
  // This is a marker interface that doesn't add properties but affects `this` typing
  let env = env.with_type_alias("ThisType", {
    type_params: [TypeParamV2::simple("T")],
    body: TTypeParam("T", None), // Evaluates to T
  })

  // Add NoInfer<T> - prevents type inference from this position (TS 5.4+)
  // Example: function foo<T>(x: T, y: NoInfer<T>): T
  // The type of T is not inferred from y, only from x
  let env = env.with_type_alias("NoInfer", {
    type_params: [TypeParamV2::simple("T")],
    body: TTypeParam("T", None), // Evaluates to T
  })

  // Add common global variables
  let env = env.with_variable("undefined", TUndefined)
  let env = env.with_variable("NaN", TNumber)
  let env = env.with_variable("Infinity", TNumber)

  // Add console object type
  let console_fields : Map[String, FieldInfoV2] = Map::new()
  console_fields.set(
    "log",
    FieldInfoV2::required(
      TFunction({
        type_params: [],
        params: [],
        rest_param: Some(ParamInfoV2::rest("args", TAny)),
        return_type: TVoid,
        type_predicate: None,
        this_type: None,
      }),
    ),
  )
  console_fields.set(
    "error",
    FieldInfoV2::required(
      TFunction({
        type_params: [],
        params: [],
        rest_param: Some(ParamInfoV2::rest("args", TAny)),
        return_type: TVoid,
        type_predicate: None,
        this_type: None,
      }),
    ),
  )
  console_fields.set(
    "warn",
    FieldInfoV2::required(
      TFunction({
        type_params: [],
        params: [],
        rest_param: Some(ParamInfoV2::rest("args", TAny)),
        return_type: TVoid,
        type_predicate: None,
        this_type: None,
      }),
    ),
  )
  let console_type = TObject({
    fields: console_fields,
    symbol_fields: [],
    call_signatures: [],
    construct_signatures: [],
    index_signature: None,
    is_class: false,
    class_name: None,
  })
  env.with_variable("console", console_type)
}

// ============================================================================
// Global Augmentation Support
// ============================================================================

///|
/// Apply a global augmentation to the type environment
/// This processes interface declarations from `declare global { }` blocks
pub fn TypeEnv::apply_global_augmentation(
  self : TypeEnv,
  augmentation : GlobalAugmentation,
) -> TypeEnv {
  let mut env = self
  // Process each declaration in the augmentation
  augmentation.declarations.each(fn(name, symbol) {
    match symbol.kind {
      SymbolKind::Interface =>
        // Get the interface type from the symbol's declarations
        match symbol.value_declaration {
          Some(InterfaceDeclaration(iface_decl)) => {
            // Convert interface to ObjectTypeV2
            let obj_type = interface_declaration_to_object_type(env, iface_decl)
            env = env.with_interface(name, obj_type)
          }
          _ => ()
        }
      SymbolKind::Variable =>
        // Add variable to scope - use the symbol's members or type
        env = env.with_variable(name, TAny)
      SymbolKind::Function =>
        // Add function to scope
        match symbol.value_declaration {
          Some(FunctionDeclaration(func_decl)) => {
            let func_type = function_declaration_to_type(env, func_decl)
            env = env.with_variable(name, func_type)
          }
          _ => ()
        }
      SymbolKind::Type =>
        // Add type alias
        match symbol.value_declaration {
          Some(TypeAliasDeclaration(alias_decl)) => {
            let ty = ast_type_to_v2(env, alias_decl.type_node)
            let alias_info = TypeAliasInfoV2::{ type_params: [], body: ty }
            let new_aliases = env.type_aliases
            new_aliases.set(name, alias_info)
            env = { ..env, type_aliases: new_aliases }
          }
          _ => ()
        }
      _ => ()
    }
  })
  env
}

///|
/// Apply multiple global augmentations
pub fn TypeEnv::apply_global_augmentations(
  self : TypeEnv,
  augmentations : Array[GlobalAugmentation],
) -> TypeEnv {
  let mut env = self
  for aug in augmentations {
    env = env.apply_global_augmentation(aug)
  }
  env
}

///|
/// Convert an interface declaration to ObjectTypeV2
fn interface_declaration_to_object_type(
  env : TypeEnv,
  iface : InterfaceDeclaration,
) -> ObjectTypeV2 {
  let fields : Map[String, FieldInfoV2] = Map::new()
  let call_signatures : Array[FunctionTypeV2] = []
  let construct_signatures : Array[FunctionTypeV2] = []
  let mut index_signature : IndexSignatureV2? = None
  for m in iface.members {
    match m {
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
        // Convert method to function type
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
        // Check if this is a construct signature (name "new") or call signature (name "")
        if meth.name == "new" {
          // Construct signature - add to construct_signatures
          construct_signatures.push(func_type)
        } else if meth.name == "" {
          // Call signature - add to call_signatures
          call_signatures.push(func_type)
        } else {
          // Regular method - add as field
          fields.set(meth.name, FieldInfoV2::{
            ty: TFunction(func_type),
            optional: meth.is_optional,
            is_readonly: false,
          })
        }
      }
      IndexSignatureDeclaration(idx) => {
        let key_ty = ast_type_to_v2(env, idx.parameter_type)
        let value_ty = ast_type_to_v2(env, idx.return_type)
        index_signature = Some(IndexSignatureV2::{
          key_type: key_ty,
          value_type: value_ty,
          is_readonly: idx.is_readonly,
        })
      }
      _ => ()
    }
  }
  ObjectTypeV2::{
    fields,
    symbol_fields: [],
    call_signatures,
    construct_signatures,
    index_signature,
    is_class: false,
    class_name: None,
  }
}

///|
/// Convert a function declaration to function type
fn function_declaration_to_type(
  env : TypeEnv,
  func : FunctionDeclaration,
) -> TypeV2 {
  let params = func.parameters.map(fn(p) {
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
  let return_ty = match func.return_type {
    Some(type_node) => ast_type_to_v2(env, type_node)
    None => TAny
  }
  TFunction(FunctionTypeV2::{
    type_params: [],
    params,
    rest_param: None,
    return_type: return_ty,
    type_predicate: None,
    this_type: None,
  })
}

// ============================================================================
// External Type Registry - Cross-file Type Checking Support
// ============================================================================

///|
/// Information about an exported type from another module
pub struct ExternalTypeInfo {
  /// Type of the exported symbol
  ty : TypeV2
  /// Whether this is a type-only export (interface, type alias)
  is_type_only : Bool
  /// Original name in the source module
  original_name : String
} derive(Show, Eq)

///|
/// Create a value export info
pub fn ExternalTypeInfo::value(ty : TypeV2, name : String) -> ExternalTypeInfo {
  { ty, is_type_only: false, original_name: name }
}

///|
/// Create a type-only export info
pub fn ExternalTypeInfo::type_only(
  ty : TypeV2,
  name : String,
) -> ExternalTypeInfo {
  { ty, is_type_only: true, original_name: name }
}

///|
/// Module type information - types exported from a single module
pub struct ModuleTypes {
  /// Path to the module
  module_path : String
  /// Named exports: export_name -> ExternalTypeInfo
  named_exports : Map[String, ExternalTypeInfo]
  /// Default export (if any)
  default_export : ExternalTypeInfo?
  /// Type aliases defined in this module
  type_aliases : Map[String, TypeAliasInfoV2]
  /// Interfaces defined in this module
  interfaces : Map[String, ObjectTypeV2]
} derive(Show, Eq)

///|
/// Create empty module types
pub fn ModuleTypes::empty(module_path : String) -> ModuleTypes {
  {
    module_path,
    named_exports: Map::new(),
    default_export: None,
    type_aliases: Map::new(),
    interfaces: Map::new(),
  }
}

///|
/// Add a named export
pub fn ModuleTypes::add_export(
  self : ModuleTypes,
  name : String,
  info : ExternalTypeInfo,
) -> Unit {
  self.named_exports.set(name, info)
}

///|
/// Set the default export
pub fn ModuleTypes::set_default(
  self : ModuleTypes,
  info : ExternalTypeInfo,
) -> Unit {
  // We need to create a new ModuleTypes to update default_export
  // Since we can't mutate an optional field directly, use a workaround
  // by using a mutable map entry pattern
  self.named_exports.set("__default__", info)
}

///|
/// Get an export by name
pub fn ModuleTypes::get_export(
  self : ModuleTypes,
  name : String,
) -> ExternalTypeInfo? {
  self.named_exports.get(name)
}

///|
/// Get the default export
pub fn ModuleTypes::get_default(self : ModuleTypes) -> ExternalTypeInfo? {
  self.default_export
}

///|
/// External type registry - holds types from all external modules
pub struct ExternalTypeRegistry {
  /// Module path -> ModuleTypes
  modules : Map[String, ModuleTypes]
} derive(Show, Eq)

///|
/// Create a new empty registry
pub fn ExternalTypeRegistry::new() -> ExternalTypeRegistry {
  { modules: Map::new() }
}

///|
/// Register a module's types
pub fn ExternalTypeRegistry::register_module(
  self : ExternalTypeRegistry,
  module_path : String,
  module_types : ModuleTypes,
) -> Unit {
  self.modules.set(module_path, module_types)
}

///|
/// Get a module's types
pub fn ExternalTypeRegistry::get_module(
  self : ExternalTypeRegistry,
  module_path : String,
) -> ModuleTypes? {
  self.modules.get(module_path)
}

///|
/// Look up an exported type from a module
pub fn ExternalTypeRegistry::lookup_export(
  self : ExternalTypeRegistry,
  module_path : String,
  export_name : String,
) -> ExternalTypeInfo? {
  match self.modules.get(module_path) {
    Some(module_types) => module_types.get_export(export_name)
    None => None
  }
}

///|
/// Look up the default export from a module
pub fn ExternalTypeRegistry::lookup_default(
  self : ExternalTypeRegistry,
  module_path : String,
) -> ExternalTypeInfo? {
  match self.modules.get(module_path) {
    Some(module_types) => module_types.get_default()
    None => None
  }
}

///|
/// Look up a type alias from a module
pub fn ExternalTypeRegistry::lookup_type_alias(
  self : ExternalTypeRegistry,
  module_path : String,
  name : String,
) -> TypeAliasInfoV2? {
  match self.modules.get(module_path) {
    Some(module_types) => module_types.type_aliases.get(name)
    None => None
  }
}

///|
/// Look up an interface from a module
pub fn ExternalTypeRegistry::lookup_interface(
  self : ExternalTypeRegistry,
  module_path : String,
  name : String,
) -> ObjectTypeV2? {
  match self.modules.get(module_path) {
    Some(module_types) => module_types.interfaces.get(name)
    None => None
  }
}

// ============================================================================
// JSON Parsing for External Type Registry
// ============================================================================

///|
/// Parse ExternalTypeRegistry from JSON string
/// JSON format:
/// {
///   "modules": {
///     "/path/to/module.ts": {
///       "module_path": "/path/to/module.ts",
///       "named_exports": { "name": { "ty": {...}, "is_type_only": false, "original_name": "name" } },
///       "default_export": null | { "ty": {...}, "is_type_only": false, "original_name": "default" },
///       "type_aliases": {},
///       "interfaces": {}
///     }
///   }
/// }
pub fn ExternalTypeRegistry::from_json(json_str : String) -> ExternalTypeRegistry? {
  try {
    let json = @json.parse(json_str)
    parse_external_registry(json)
  } catch {
    _ => None
  }
}

///|
/// Parse registry from JSON value
fn parse_external_registry(json : Json) -> ExternalTypeRegistry? {
  guard json is Object(obj) else {
    return None
  }

  let registry = ExternalTypeRegistry::new()

  match obj.get("modules") {
    Some(Object(modules_obj)) => {
      for kv in modules_obj {
        let module_path = kv.0
        let module_json = kv.1
        match parse_module_types(module_json) {
          Some(module_types) => registry.register_module(module_path, module_types)
          None => ()
        }
      }
    }
    _ => ()
  }

  Some(registry)
}

///|
/// Parse ModuleTypes from JSON
fn parse_module_types(json : Json) -> ModuleTypes? {
  guard json is Object(obj) else {
    return None
  }

  let module_path = match obj.get("module_path") {
    Some(String(s)) => s
    _ => return None
  }

  let module_types = ModuleTypes::empty(module_path)

  // Parse named exports
  match obj.get("named_exports") {
    Some(Object(exports_obj)) => {
      for kv in exports_obj {
        let export_name = kv.0
        let export_json = kv.1
        match parse_external_type_info(export_json) {
          Some(info) => module_types.add_export(export_name, info)
          None => ()
        }
      }
    }
    _ => ()
  }

  // Parse default export
  match obj.get("default_export") {
    Some(Null) | None => ()
    Some(export_json) => {
      match parse_external_type_info(export_json) {
        Some(info) => module_types.set_default(info)
        None => ()
      }
    }
  }

  // Parse type aliases
  match obj.get("type_aliases") {
    Some(Object(aliases_obj)) => {
      for kv in aliases_obj {
        let alias_name = kv.0
        let alias_json = kv.1
        match parse_type_alias_info(alias_json) {
          Some(info) => {
            module_types.type_aliases.set(alias_name, info)
          }
          None => ()
        }
      }
    }
    _ => ()
  }

  // Parse interfaces
  match obj.get("interfaces") {
    Some(Object(ifaces_obj)) => {
      for kv in ifaces_obj {
        let iface_name = kv.0
        let iface_json = kv.1
        match parse_object_type_v2(iface_json) {
          Some(obj_type) => {
            module_types.interfaces.set(iface_name, obj_type)
          }
          None => ()
        }
      }
    }
    _ => ()
  }

  Some(module_types)
}

///|
/// Parse ExternalTypeInfo from JSON
fn parse_external_type_info(json : Json) -> ExternalTypeInfo? {
  guard json is Object(obj) else {
    return None
  }

  let ty = match obj.get("ty") {
    Some(ty_json) => parse_type_v2(ty_json)
    None => return None
  }

  let is_type_only = match obj.get("is_type_only") {
    Some(True) => true
    _ => false
  }

  let original_name = match obj.get("original_name") {
    Some(String(s)) => s
    _ => ""
  }

  Some(ExternalTypeInfo::{ ty, is_type_only, original_name })
}

///|
/// Parse TypeAliasInfoV2 from JSON
fn parse_type_alias_info(json : Json) -> TypeAliasInfoV2? {
  guard json is Object(obj) else {
    return None
  }

  let type_params : Array[TypeParamV2] = match obj.get("type_params") {
    Some(Array(arr)) => {
      let params : Array[TypeParamV2] = []
      for item in arr {
        match parse_type_param_v2(item) {
          Some(param) => params.push(param)
          None => ()
        }
      }
      params
    }
    _ => []
  }

  let body = match obj.get("body") {
    Some(body_json) => parse_type_v2(body_json)
    None => return None
  }

  Some(TypeAliasInfoV2::{ type_params, body })
}

///|
/// Parse TypeParamV2 from JSON
fn parse_type_param_v2(json : Json) -> TypeParamV2? {
  guard json is Object(obj) else {
    return None
  }

  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => return None
  }

  let constraint : TypeV2? = match obj.get("constraint") {
    Some(Null) | None => None
    Some(c_json) => Some(parse_type_v2(c_json))
  }

  let default_type : TypeV2? = match obj.get("default") {
    Some(Null) | None => None
    Some(d_json) => Some(parse_type_v2(d_json))
  }

  let is_const = match obj.get("is_const") {
    Some(True) => true
    _ => false
  }

  let variance : Variance? = match obj.get("variance") {
    Some(String("in")) => Some(Contravariant)
    Some(String("out")) => Some(Covariant)
    Some(String("inout")) => Some(Invariant)
    Some(String("bivariant")) => Some(Bivariant)
    _ => None
  }

  Some(TypeParamV2::{ name, constraint, default_type, is_const, variance })
}

///|
/// Parse TypeV2 from JSON
/// JSON format for types:
/// { "kind": "number" }
/// { "kind": "string" }
/// { "kind": "boolean" }
/// { "kind": "null" }
/// { "kind": "undefined" }
/// { "kind": "void" }
/// { "kind": "never" }
/// { "kind": "any" }
/// { "kind": "unknown" }
/// { "kind": "symbol" }
/// { "kind": "bigint" }
/// { "kind": "literal_string", "value": "hello" }
/// { "kind": "literal_number", "value": 42 }
/// { "kind": "literal_bool", "value": true }
/// { "kind": "array", "element": {...} }
/// { "kind": "union", "types": [...] }
/// { "kind": "intersection", "types": [...] }
/// { "kind": "object", "fields": {...}, ... }
/// { "kind": "function", "params": [...], "return": {...}, ... }
/// { "kind": "type_param", "name": "T", "constraint": null }
/// { "kind": "generic", "name": "Array", "args": [...] }
fn parse_type_v2(json : Json) -> TypeV2 {
  guard json is Object(obj) else {
    return TAny
  }

  let kind = match obj.get("kind") {
    Some(String(s)) => s
    _ => return TAny
  }

  match kind {
    "number" => TNumber
    "string" => TString
    "boolean" => TBoolean
    "null" => TNull
    "undefined" => TUndefined
    "void" => TVoid
    "never" => TNever
    "any" => TAny
    "unknown" => TUnknown
    "symbol" => TSymbol
    "bigint" => TBigInt
    "error" => TError

    "literal_string" => {
      match obj.get("value") {
        Some(String(v)) => TLiteralString(v)
        _ => TString
      }
    }

    "literal_number" => {
      match obj.get("value") {
        Some(Number(v)) => TLiteralNumber(v)
        _ => TNumber
      }
    }

    "literal_bool" => {
      match obj.get("value") {
        Some(True) => TLiteralBool(true)
        Some(False) => TLiteralBool(false)
        _ => TBoolean
      }
    }

    "literal_bigint" => {
      match obj.get("value") {
        Some(String(v)) => TLiteralBigInt(v)
        _ => TBigInt
      }
    }

    "array" => {
      match obj.get("element") {
        Some(elem_json) => TArray(parse_type_v2(elem_json))
        _ => TArray(TAny)
      }
    }

    "tuple" => {
      match obj.get("elements") {
        Some(Array(elems)) => {
          let elements : Array[TupleElementV2] = []
          for elem in elems {
            elements.push(parse_tuple_element_v2(elem))
          }
          TTuple(elements)
        }
        _ => TTuple([])
      }
    }

    "union" => {
      match obj.get("types") {
        Some(Array(types)) => {
          let parsed : Array[TypeV2] = []
          for t in types {
            parsed.push(parse_type_v2(t))
          }
          TUnion(parsed)
        }
        _ => TAny
      }
    }

    "intersection" => {
      match obj.get("types") {
        Some(Array(types)) => {
          let parsed : Array[TypeV2] = []
          for t in types {
            parsed.push(parse_type_v2(t))
          }
          TIntersection(parsed)
        }
        _ => TAny
      }
    }

    "object" => {
      match parse_object_type_v2(json) {
        Some(obj_type) => TObject(obj_type)
        None => TObject(ObjectTypeV2::empty())
      }
    }

    "function" => {
      match parse_function_type_v2(json) {
        Some(func_type) => TFunction(func_type)
        None => TFunction(FunctionTypeV2::any())
      }
    }

    "type_param" => {
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ => "T"
      }
      let constraint = match obj.get("constraint") {
        Some(Null) | None => None
        Some(c_json) => Some(parse_type_v2(c_json))
      }
      TTypeParam(name, constraint)
    }

    "generic" => {
      let name = match obj.get("name") {
        Some(String(s)) => s
        _ => ""
      }
      let args = match obj.get("args") {
        Some(Array(arr)) => {
          let parsed : Array[TypeV2] = []
          for a in arr {
            parsed.push(parse_type_v2(a))
          }
          parsed
        }
        _ => []
      }
      TGenericInstance(name, args)
    }

    _ => TAny
  }
}

///|
/// Parse TupleElementV2 from JSON
fn parse_tuple_element_v2(json : Json) -> TupleElementV2 {
  guard json is Object(obj) else {
    return TupleElementV2::required(TAny)
  }

  let ty = match obj.get("ty") {
    Some(ty_json) => parse_type_v2(ty_json)
    _ => TAny
  }

  let optional = match obj.get("optional") {
    Some(True) => true
    _ => false
  }

  let is_rest = match obj.get("rest") {
    Some(True) => true
    _ => false
  }

  let label = match obj.get("label") {
    Some(String(s)) => Some(s)
    _ => None
  }

  TupleElementV2::{ ty, optional, is_rest, label }
}

///|
/// Parse ObjectTypeV2 from JSON
fn parse_object_type_v2(json : Json) -> ObjectTypeV2? {
  guard json is Object(obj) else {
    return None
  }

  let fields : Map[String, FieldInfoV2] = Map::new()

  match obj.get("fields") {
    Some(Object(fields_obj)) => {
      for kv in fields_obj {
        let field_name = kv.0
        let field_json = kv.1
        match parse_field_info_v2(field_json) {
          Some(info) => fields.set(field_name, info)
          None => ()
        }
      }
    }
    _ => ()
  }

  let call_signatures : Array[FunctionTypeV2] = match obj.get("call_signatures") {
    Some(Array(sigs)) => {
      let parsed : Array[FunctionTypeV2] = []
      for sig in sigs {
        match parse_function_type_v2(sig) {
          Some(f) => parsed.push(f)
          None => ()
        }
      }
      parsed
    }
    _ => []
  }

  let construct_signatures : Array[FunctionTypeV2] = match obj.get("construct_signatures") {
    Some(Array(sigs)) => {
      let parsed : Array[FunctionTypeV2] = []
      for sig in sigs {
        match parse_function_type_v2(sig) {
          Some(f) => parsed.push(f)
          None => ()
        }
      }
      parsed
    }
    _ => []
  }

  let index_signature = match obj.get("index_signature") {
    Some(Null) | None => None
    Some(idx_json) => parse_index_signature_v2(idx_json)
  }

  let is_class = match obj.get("is_class") {
    Some(True) => true
    _ => false
  }

  let class_name = match obj.get("class_name") {
    Some(String(s)) => Some(s)
    _ => None
  }

  Some(ObjectTypeV2::{
    fields,
    symbol_fields: [],
    call_signatures,
    construct_signatures,
    index_signature,
    is_class,
    class_name,
  })
}

///|
/// Parse FieldInfoV2 from JSON
fn parse_field_info_v2(json : Json) -> FieldInfoV2? {
  guard json is Object(obj) else {
    return None
  }

  let ty = match obj.get("ty") {
    Some(ty_json) => parse_type_v2(ty_json)
    _ => TAny
  }

  let optional = match obj.get("optional") {
    Some(True) => true
    _ => false
  }

  let is_readonly = match obj.get("readonly") {
    Some(True) => true
    _ => false
  }

  Some(FieldInfoV2::{ ty, optional, is_readonly })
}

///|
/// Parse FunctionTypeV2 from JSON
fn parse_function_type_v2(json : Json) -> FunctionTypeV2? {
  guard json is Object(obj) else {
    return None
  }

  let type_params : Array[TypeParamV2] = match obj.get("type_params") {
    Some(Array(arr)) => {
      let parsed : Array[TypeParamV2] = []
      for item in arr {
        match parse_type_param_v2(item) {
          Some(param) => parsed.push(param)
          None => ()
        }
      }
      parsed
    }
    _ => []
  }

  let params : Array[ParamInfoV2] = match obj.get("params") {
    Some(Array(arr)) => {
      let parsed : Array[ParamInfoV2] = []
      for item in arr {
        parsed.push(parse_param_info_v2(item))
      }
      parsed
    }
    _ => []
  }

  let rest_param = match obj.get("rest_param") {
    Some(Null) | None => None
    Some(rest_json) => Some(parse_param_info_v2(rest_json))
  }

  let return_type = match obj.get("return") {
    Some(ret_json) => parse_type_v2(ret_json)
    _ => TVoid
  }

  let type_predicate = match obj.get("type_predicate") {
    Some(Null) | None => None
    Some(pred_json) => parse_type_predicate_v2(pred_json)
  }

  let this_type = match obj.get("this_type") {
    Some(Null) | None => None
    Some(this_json) => Some(parse_type_v2(this_json))
  }

  Some(FunctionTypeV2::{
    type_params,
    params,
    rest_param,
    return_type,
    type_predicate,
    this_type,
  })
}

///|
/// Parse ParamInfoV2 from JSON
fn parse_param_info_v2(json : Json) -> ParamInfoV2 {
  guard json is Object(obj) else {
    return ParamInfoV2::required("arg", TAny)
  }

  let name = match obj.get("name") {
    Some(String(s)) => s
    _ => "arg"
  }

  let ty = match obj.get("ty") {
    Some(ty_json) => parse_type_v2(ty_json)
    _ => TAny
  }

  let optional = match obj.get("optional") {
    Some(True) => true
    _ => false
  }

  let is_rest = match obj.get("rest") {
    Some(True) => true
    _ => false
  }

  ParamInfoV2::{ name, ty, optional, is_rest }
}

///|
/// Parse TypePredicateV2 from JSON
fn parse_type_predicate_v2(json : Json) -> TypePredicateV2? {
  guard json is Object(obj) else {
    return None
  }

  let parameter_name = match obj.get("parameter_name") {
    Some(String(s)) => s
    _ => return None
  }

  let predicate_type = match obj.get("predicate_type") {
    Some(Null) | None => TAny
    Some(ty_json) => parse_type_v2(ty_json)
  }

  let is_asserts = match obj.get("is_asserts") {
    Some(True) => true
    _ => false
  }

  Some(TypePredicateV2::{ parameter_name, predicate_type, is_asserts })
}

///|
/// Parse IndexSignatureV2 from JSON
fn parse_index_signature_v2(json : Json) -> IndexSignatureV2? {
  guard json is Object(obj) else {
    return None
  }

  let key_type = match obj.get("key_type") {
    Some(kt_json) => parse_type_v2(kt_json)
    _ => TString
  }

  let value_type = match obj.get("value_type") {
    Some(vt_json) => parse_type_v2(vt_json)
    _ => TAny
  }

  let is_readonly = match obj.get("readonly") {
    Some(True) => true
    _ => false
  }

  Some(IndexSignatureV2::{ key_type, value_type, is_readonly })
}
