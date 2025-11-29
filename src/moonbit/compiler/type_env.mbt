// TypeEnv - Type Environment for Bidirectional Type Checking
// Manages type bindings, narrowings, and scoped lookups

///|
/// Type alias information
pub struct TypeAliasInfoV2 {
  type_params : Array[TypeParamV2]
  body : TypeV2
} derive(Show, Eq)

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
          // Finally check parent scope
          match self.parent {
            Some(p) => p.lookup(name)
            None => None
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
  }
}

///|
/// Add an interface
pub fn TypeEnv::with_interface(
  self : TypeEnv,
  name : String,
  obj : ObjectTypeV2,
) -> TypeEnv {
  let new_interfaces = self.interfaces
  new_interfaces.set(name, obj)
  {
    variables: self.variables,
    type_aliases: self.type_aliases,
    interfaces: new_interfaces,
    type_params: self.type_params,
    narrowings: self.narrowings,
    parent: self.parent,
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
      }),
    ),
  )
  let console_type = TObject({
    fields: console_fields,
    call_signatures: [],
    construct_signatures: [],
    index_signature: None,
    is_class: false,
    class_name: None,
  })
  env.with_variable("console", console_type)
}
