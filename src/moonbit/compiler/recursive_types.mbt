// Recursive Type Handling
// Implements TypeScript's recursive type checking including:
// - Cycle detection in type resolution
// - Recursion depth limiting to prevent infinite expansion
// - "Assumed true" strategy for recursive type comparisons
// - Support for mutually recursive types

// ============================================================================
// Type Identity and Cycle Detection
// ============================================================================

///|
/// Unique identifier for a type comparison pair
/// Used to detect cycles in recursive type comparisons
pub struct TypeComparisonId {
  source_id : String
  target_id : String
} derive(Show, Eq)

///|
/// Create a comparison ID from two types
pub fn make_comparison_id(source : TypeV2, target : TypeV2) -> TypeComparisonId {
  { source_id: type_identity_key(source), target_id: type_identity_key(target) }
}

///|
/// Generate a unique identity key for a type
/// Used for cycle detection in recursive type operations
pub fn type_identity_key(ty : TypeV2) -> String {
  match ty {
    TString => "string"
    TNumber => "number"
    TBoolean => "boolean"
    TVoid => "void"
    TUndefined => "undefined"
    TNull => "null"
    TSymbol => "symbol"
    TUniqueSymbol(us) => "unique_sym:" + us.name + ":" + us.id.to_string()
    TBigInt => "bigint"
    TAny => "any"
    TUnknown => "unknown"
    TNever => "never"
    TError => "error"
    TLiteralString(s) => "lit_s:" + s
    TLiteralNumber(n) => "lit_n:" + n.to_string()
    TLiteralBool(b) => "lit_b:" + b.to_string()
    TLiteralBigInt(n) => "lit_bi:" + n
    TArray(elem) => "arr:" + type_identity_key(elem)
    TTypeParam(name, _) => "tp:" + name
    TGenericInstance(name, args) => {
      let arg_keys = args.map(fn(a) { type_identity_key(a) })
      "gi:" + name + "<" + arg_keys.join(",") + ">"
    }
    TUnion(types) => {
      let keys = types.map(fn(t) { type_identity_key(t) })
      "union:" + keys.join("|")
    }
    TIntersection(types) => {
      let keys = types.map(fn(t) { type_identity_key(t) })
      "inter:" + keys.join("&")
    }
    TObject(obj) => object_identity_key(obj)
    TFunction(func) => function_identity_key(func)
    TTuple(elems) => {
      let keys = elems.map(fn(e) { type_identity_key(e.ty) })
      "tuple:[" + keys.join(",") + "]"
    }
    TConditional(c) =>
      "cond:" +
      type_identity_key(c.check_type) +
      "?" +
      type_identity_key(c.true_type) +
      ":" +
      type_identity_key(c.false_type)
    TMapped(m) =>
      "mapped:" + m.type_param.name + ":" + type_identity_key(m.constraint)
    TIndexAccess(ia) =>
      "idx:" +
      type_identity_key(ia.object_type) +
      "[" +
      type_identity_key(ia.index_type) +
      "]"
    TInfer(name) => "infer:" + name
    TTemplateLiteral(_) => "template"
  }
}

///|
/// Generate identity key for object type
fn object_identity_key(obj : ObjectTypeV2) -> String {
  let parts : Array[String] = []
  for entry in obj.fields.iter() {
    let (name, field) = entry
    parts.push(name + ":" + type_identity_key(field.ty))
  }
  "obj:{" + parts.join(",") + "}"
}

///|
/// Generate identity key for function type
fn function_identity_key(func : FunctionTypeV2) -> String {
  let param_keys = func.params.map(fn(p) { type_identity_key(p.ty) })
  "fn:(" + param_keys.join(",") + ")=>" + type_identity_key(func.return_type)
}

// ============================================================================
// Recursive Type Resolution Context
// ============================================================================

///|
/// Context for tracking recursive type resolution
/// Prevents infinite loops when resolving recursive types
pub struct RecursiveResolutionContext {
  /// Set of type identity keys currently being resolved
  resolving : Map[String, Bool]
  /// Maximum recursion depth
  max_depth : Int
  /// Current recursion depth
  current_depth : Int
  /// Cache of already resolved types
  resolved_cache : Map[String, TypeV2]
} derive(Show)

///|
/// Create a new recursive resolution context
pub fn RecursiveResolutionContext::new() -> RecursiveResolutionContext {
  {
    resolving: Map::new(),
    max_depth: 50, // TypeScript uses ~50 for recursion limit
    current_depth: 0,
    resolved_cache: Map::new(),
  }
}

///|
/// Create a child context with incremented depth
pub fn RecursiveResolutionContext::child(
  self : RecursiveResolutionContext,
) -> RecursiveResolutionContext? {
  if self.current_depth >= self.max_depth {
    None // Recursion limit exceeded
  } else {
    Some({
      resolving: self.resolving,
      max_depth: self.max_depth,
      current_depth: self.current_depth + 1,
      resolved_cache: self.resolved_cache,
    })
  }
}

///|
/// Check if we're currently resolving a type (cycle detection)
pub fn RecursiveResolutionContext::is_resolving(
  self : RecursiveResolutionContext,
  ty : TypeV2,
) -> Bool {
  let key = type_identity_key(ty)
  self.resolving.contains(key)
}

///|
/// Mark a type as being resolved
pub fn RecursiveResolutionContext::start_resolving(
  self : RecursiveResolutionContext,
  ty : TypeV2,
) -> RecursiveResolutionContext {
  let key = type_identity_key(ty)
  let resolving = self.resolving
  resolving.set(key, true)
  { ..self, resolving, }
}

///|
/// Mark a type as finished resolving
pub fn RecursiveResolutionContext::finish_resolving(
  self : RecursiveResolutionContext,
  ty : TypeV2,
) -> RecursiveResolutionContext {
  let key = type_identity_key(ty)
  let resolving = self.resolving
  ignore(resolving.remove(key))
  { ..self, resolving, }
}

///|
/// Cache a resolved type
pub fn RecursiveResolutionContext::cache_resolved(
  self : RecursiveResolutionContext,
  ty : TypeV2,
  resolved : TypeV2,
) -> RecursiveResolutionContext {
  let key = type_identity_key(ty)
  let cache = self.resolved_cache
  cache.set(key, resolved)
  { ..self, resolved_cache: cache }
}

///|
/// Look up a cached resolved type
pub fn RecursiveResolutionContext::get_cached(
  self : RecursiveResolutionContext,
  ty : TypeV2,
) -> TypeV2? {
  let key = type_identity_key(ty)
  self.resolved_cache.get(key)
}

// ============================================================================
// Recursive Type Comparison Context
// ============================================================================

///|
/// Context for tracking recursive type comparisons
/// Implements the "assumed true" strategy for recursive types
pub struct RecursiveComparisonContext {
  /// Set of type pairs currently being compared (assume true for cycles)
  comparing : Map[String, Bool]
  /// Maximum recursion depth for comparison
  max_depth : Int
  /// Current comparison depth
  current_depth : Int
} derive(Show)

///|
/// Create a new recursive comparison context
pub fn RecursiveComparisonContext::new() -> RecursiveComparisonContext {
  {
    comparing: Map::new(),
    max_depth: 100, // Higher limit for comparisons
    current_depth: 0,
  }
}

///|
/// Create a child context with incremented depth
pub fn RecursiveComparisonContext::child(
  self : RecursiveComparisonContext,
) -> RecursiveComparisonContext? {
  if self.current_depth >= self.max_depth {
    None // Recursion limit exceeded
  } else {
    Some({
      comparing: self.comparing,
      max_depth: self.max_depth,
      current_depth: self.current_depth + 1,
    })
  }
}

///|
/// Check if we're currently comparing these types (cycle)
pub fn RecursiveComparisonContext::is_comparing(
  self : RecursiveComparisonContext,
  source : TypeV2,
  target : TypeV2,
) -> Bool {
  let id = make_comparison_id(source, target)
  let key = id.source_id + "<:" + id.target_id
  self.comparing.contains(key)
}

///|
/// Mark types as being compared
pub fn RecursiveComparisonContext::start_comparing(
  self : RecursiveComparisonContext,
  source : TypeV2,
  target : TypeV2,
) -> RecursiveComparisonContext {
  let id = make_comparison_id(source, target)
  let key = id.source_id + "<:" + id.target_id
  let comparing = self.comparing
  comparing.set(key, true)
  { ..self, comparing, }
}

///|
/// Mark types as finished comparing
pub fn RecursiveComparisonContext::finish_comparing(
  self : RecursiveComparisonContext,
  source : TypeV2,
  target : TypeV2,
) -> RecursiveComparisonContext {
  let id = make_comparison_id(source, target)
  let key = id.source_id + "<:" + id.target_id
  let comparing = self.comparing
  ignore(comparing.remove(key))
  { ..self, comparing, }
}

// ============================================================================
// Recursive Type Resolution
// ============================================================================

///|
/// Resolve a type with cycle detection
/// Returns the original type if a cycle is detected
pub fn resolve_type_recursive(
  env : TypeEnv,
  ty : TypeV2,
  ctx : RecursiveResolutionContext,
) -> (TypeV2, RecursiveResolutionContext) {
  // Check cache first
  match ctx.get_cached(ty) {
    Some(cached) => return (cached, ctx)
    None => ()
  }

  // Check for cycle
  if ctx.is_resolving(ty) {
    // Cycle detected - return original type to break the cycle
    return (ty, ctx)
  }

  // Check recursion depth
  let child_ctx = match ctx.child() {
    Some(c) => c
    None => return (ty, ctx) // Depth limit exceeded
  }

  // Mark as resolving
  let ctx = child_ctx.start_resolving(ty)

  // Resolve the type
  let (resolved, ctx) = resolve_type_impl(env, ty, ctx)

  // Cache and finish
  let ctx = ctx.cache_resolved(ty, resolved)
  let ctx = ctx.finish_resolving(ty)
  (resolved, ctx)
}

///|
/// Internal type resolution implementation
fn resolve_type_impl(
  env : TypeEnv,
  ty : TypeV2,
  ctx : RecursiveResolutionContext,
) -> (TypeV2, RecursiveResolutionContext) {
  match ty {
    TConditional(c) => {
      // Resolve check, extends, true, and false types
      let (check_resolved, ctx) = resolve_type_recursive(env, c.check_type, ctx)
      let (extends_resolved, ctx) = resolve_type_recursive(
        env,
        c.extends_type,
        ctx,
      )
      let (true_resolved, ctx) = resolve_type_recursive(env, c.true_type, ctx)
      let (false_resolved, ctx) = resolve_type_recursive(env, c.false_type, ctx)

      // Evaluate the conditional
      let result = if is_subtype_recursive(
          check_resolved, extends_resolved, ctx,
        ) {
        true_resolved
      } else {
        false_resolved
      }
      (result, ctx)
    }
    TMapped(m) => {
      // Resolve constraint
      let (constraint_resolved, ctx) = resolve_type_recursive(
        env,
        m.constraint,
        ctx,
      )
      // Build a mapped type result (simplified)
      let mapped_resolved = TMapped({ ..m, constraint: constraint_resolved })
      (mapped_resolved, ctx)
    }
    TIndexAccess(ia) => {
      // Resolve object and index types
      let (obj_resolved, ctx) = resolve_type_recursive(env, ia.object_type, ctx)
      let (idx_resolved, ctx) = resolve_type_recursive(env, ia.index_type, ctx)
      // Try to evaluate the index access
      let result = evaluate_index_access_resolved(obj_resolved, idx_resolved)
      (result, ctx)
    }
    TTypeParam(name, _) =>
      // Try to resolve from environment
      match env.lookup_type_param(name) {
        Some(_) => (ty, ctx) // Keep as type param
        None =>
          // Check type alias
          match env.resolve_type_alias(name, []) {
            Some(resolved) => resolve_type_recursive(env, resolved, ctx)
            None => (ty, ctx)
          }
      }
    TGenericInstance(name, args) => {
      // Resolve all type arguments
      let resolved_args : Array[TypeV2] = []
      let mut current_ctx = ctx
      for arg in args {
        let (resolved_arg, new_ctx) = resolve_type_recursive(
          env, arg, current_ctx,
        )
        resolved_args.push(resolved_arg)
        current_ctx = new_ctx
      }
      // Try to resolve the type alias
      match env.resolve_type_alias(name, resolved_args) {
        Some(resolved) => resolve_type_recursive(env, resolved, current_ctx)
        None => (TGenericInstance(name, resolved_args), current_ctx)
      }
    }
    TUnion(types) => {
      let resolved_types : Array[TypeV2] = []
      let mut current_ctx = ctx
      for t in types {
        let (resolved_t, new_ctx) = resolve_type_recursive(env, t, current_ctx)
        resolved_types.push(resolved_t)
        current_ctx = new_ctx
      }
      (make_union(resolved_types), current_ctx)
    }
    TIntersection(types) => {
      let resolved_types : Array[TypeV2] = []
      let mut current_ctx = ctx
      for t in types {
        let (resolved_t, new_ctx) = resolve_type_recursive(env, t, current_ctx)
        resolved_types.push(resolved_t)
        current_ctx = new_ctx
      }
      (make_intersection(resolved_types), current_ctx)
    }
    TArray(elem) => {
      let (resolved_elem, ctx) = resolve_type_recursive(env, elem, ctx)
      (TArray(resolved_elem), ctx)
    }
    TTuple(elems) => {
      let resolved_elems : Array[TupleElementV2] = []
      let mut current_ctx = ctx
      for e in elems {
        let (resolved_ty, new_ctx) = resolve_type_recursive(
          env,
          e.ty,
          current_ctx,
        )
        resolved_elems.push(TupleElementV2::{
          ty: resolved_ty,
          optional: e.optional,
          is_rest: e.is_rest,
          label: e.label,
        })
        current_ctx = new_ctx
      }
      (TTuple(resolved_elems), current_ctx)
    }
    TObject(obj) => {
      // Resolve field types
      let resolved_fields : Map[String, FieldInfoV2] = Map::new()
      let mut current_ctx = ctx
      for entry in obj.fields.iter() {
        let (name, field) = entry
        let (resolved_ty, new_ctx) = resolve_type_recursive(
          env,
          field.ty,
          current_ctx,
        )
        resolved_fields.set(name, FieldInfoV2::{
          ty: resolved_ty,
          optional: field.optional,
          is_readonly: field.is_readonly,
        })
        current_ctx = new_ctx
      }
      let resolved_obj = ObjectTypeV2::{
        fields: resolved_fields,
        symbol_fields: obj.symbol_fields,
        index_signature: obj.index_signature,
        call_signatures: obj.call_signatures,
        construct_signatures: obj.construct_signatures,
        is_class: obj.is_class,
        class_name: obj.class_name,
      }
      (TObject(resolved_obj), current_ctx)
    }
    TFunction(func) => {
      // Resolve parameter and return types
      let resolved_params : Array[ParamInfoV2] = []
      let mut current_ctx = ctx
      for p in func.params {
        let (resolved_ty, new_ctx) = resolve_type_recursive(
          env,
          p.ty,
          current_ctx,
        )
        resolved_params.push(ParamInfoV2::{
          name: p.name,
          ty: resolved_ty,
          optional: p.optional,
          is_rest: p.is_rest,
        })
        current_ctx = new_ctx
      }
      let (resolved_return, final_ctx) = resolve_type_recursive(
        env,
        func.return_type,
        current_ctx,
      )
      let resolved_func = FunctionTypeV2::{
        params: resolved_params,
        return_type: resolved_return,
        type_params: func.type_params,
        rest_param: func.rest_param,
        type_predicate: func.type_predicate,
        this_type: func.this_type,
      }
      (TFunction(resolved_func), final_ctx)
    }
    _ => (ty, ctx)
  }
}

///|
/// Evaluate index access on resolved types
fn evaluate_index_access_resolved(obj : TypeV2, index : TypeV2) -> TypeV2 {
  match (obj, index) {
    (TObject(obj_type), TLiteralString(key)) =>
      match obj_type.fields.get(key) {
        Some(field) => field.ty
        None =>
          // Check index signature
          match obj_type.index_signature {
            Some(sig) => sig.value_type
            None => TUndefined
          }
      }
    (TTuple(elems), TLiteralNumber(idx)) => {
      let i = idx.to_int()
      if i >= 0 && i < elems.length() {
        elems[i].ty
      } else {
        TUndefined
      }
    }
    (TArray(elem), TNumber) => elem
    _ => TAny
  }
}

// ============================================================================
// Recursive Type Comparison (Subtyping)
// ============================================================================

///|
/// Check if source is subtype of target with cycle detection
/// Uses "assumed true" strategy for recursive types
pub fn is_subtype_recursive(
  source : TypeV2,
  target : TypeV2,
  _ctx : RecursiveResolutionContext,
) -> Bool {
  let cmp_ctx = RecursiveComparisonContext::new()
  is_subtype_with_context(source, target, cmp_ctx)
}

///|
/// Internal subtype check with comparison context
fn is_subtype_with_context(
  source : TypeV2,
  target : TypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  // Same type is always subtype
  if type_identity_key(source) == type_identity_key(target) {
    return true
  }

  // Check for cycle - if we're already comparing these types, assume true
  // This implements TypeScript's "assumed true" strategy for recursive types
  if ctx.is_comparing(source, target) {
    return true
  }

  // Check depth limit
  let child_ctx = match ctx.child() {
    Some(c) => c
    None => return true // Assume true at depth limit
  }

  // Mark as comparing
  let ctx = child_ctx.start_comparing(source, target)

  // Perform comparison
  is_subtype_impl(source, target, ctx)
}

///|
/// Internal subtype implementation
fn is_subtype_impl(
  source : TypeV2,
  target : TypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  match (source, target) {
    // Any/Unknown/Never
    (TAny, _) => true
    (_, TAny) => true
    (_, TUnknown) => true
    (TNever, _) => true

    // Literal types to base types
    (TLiteralString(_), TString) => true
    (TLiteralNumber(_), TNumber) => true
    (TLiteralBool(_), TBoolean) => true
    (TLiteralBigInt(_), TBigInt) => true

    // Union target: source must be subtype of at least one member
    (src, TUnion(target_types)) =>
      target_types.iter().any(fn(t) { is_subtype_with_context(src, t, ctx) })

    // Source union: all members must be subtypes of target
    (TUnion(source_types), tgt) =>
      source_types.iter().all(fn(s) { is_subtype_with_context(s, tgt, ctx) })

    // Intersection target: source must be subtype of all members
    (src, TIntersection(target_types)) =>
      target_types.iter().all(fn(t) { is_subtype_with_context(src, t, ctx) })

    // Source intersection: at least one member must be subtype of target
    (TIntersection(source_types), tgt) =>
      source_types.iter().any(fn(s) { is_subtype_with_context(s, tgt, ctx) })

    // Array types - covariant
    (TArray(src_elem), TArray(tgt_elem)) =>
      is_subtype_with_context(src_elem, tgt_elem, ctx)

    // Object types - structural
    (TObject(src_obj), TObject(tgt_obj)) =>
      is_object_subtype_recursive(src_obj, tgt_obj, ctx)

    // Function types
    (TFunction(src_func), TFunction(tgt_func)) =>
      is_function_subtype_recursive(src_func, tgt_func, ctx)

    // Generic instances
    (TGenericInstance(src_name, src_args), TGenericInstance(tgt_name, tgt_args)) =>
      if src_name != tgt_name || src_args.length() != tgt_args.length() {
        false
      } else {
        let mut all_match = true
        for i = 0; i < src_args.length(); i = i + 1 {
          if not(is_subtype_with_context(src_args[i], tgt_args[i], ctx)) {
            all_match = false
            break
          }
        }
        all_match
      }

    // Tuple types
    (TTuple(src_elems), TTuple(tgt_elems)) => {
      if src_elems.length() < tgt_elems.length() {
        return false
      }
      for i = 0; i < tgt_elems.length(); i = i + 1 {
        if i >= src_elems.length() {
          if not(tgt_elems[i].optional) {
            return false
          }
        } else if not(
            is_subtype_with_context(src_elems[i].ty, tgt_elems[i].ty, ctx),
          ) {
          return false
        }
      }
      true
    }

    // Same primitive types
    (TString, TString) => true
    (TNumber, TNumber) => true
    (TBoolean, TBoolean) => true
    (TVoid, TVoid) => true
    (TUndefined, TUndefined) => true
    (TNull, TNull) => true
    (TSymbol, TSymbol) => true
    (TBigInt, TBigInt) => true

    // Literal to literal equality
    (TLiteralString(s1), TLiteralString(s2)) => s1 == s2
    (TLiteralNumber(n1), TLiteralNumber(n2)) => n1 == n2
    (TLiteralBool(b1), TLiteralBool(b2)) => b1 == b2
    (TLiteralBigInt(n1), TLiteralBigInt(n2)) => n1 == n2
    _ => false
  }
}

///|
/// Check object subtype with recursion handling
fn is_object_subtype_recursive(
  source : ObjectTypeV2,
  target : ObjectTypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  // All target fields must exist in source with compatible types
  for entry in target.fields.iter() {
    let (name, tgt_field) = entry
    match source.fields.get(name) {
      Some(src_field) =>
        if not(is_subtype_with_context(src_field.ty, tgt_field.ty, ctx)) {
          return false
        }
      None => if not(tgt_field.optional) { return false }
    }
  }
  true
}

///|
/// Check function subtype with recursion handling
/// Contravariant in parameters, covariant in return
fn is_function_subtype_recursive(
  source : FunctionTypeV2,
  target : FunctionTypeV2,
  ctx : RecursiveComparisonContext,
) -> Bool {
  // Parameter count compatibility
  let min_src_params = source.params
    .iter()
    .filter(fn(p) { not(p.optional) })
    .count()
  if min_src_params > target.params.length() {
    return false
  }

  // Check parameters (contravariant)
  for i = 0; i < target.params.length(); i = i + 1 {
    if i < source.params.length() {
      // Target param must be subtype of source param (contravariant)
      if not(
          is_subtype_with_context(target.params[i].ty, source.params[i].ty, ctx),
        ) {
        return false
      }
    }
  }

  // Check return type (covariant)
  is_subtype_with_context(source.return_type, target.return_type, ctx)
}

// ============================================================================
// Infinite Type Expansion Detection
// ============================================================================

///|
/// Result of checking for infinite type expansion
pub enum InfiniteTypeResult {
  Safe // Type is safe, no infinite expansion
  Infinite(String) // Type would expand infinitely with reason
  DepthLimitReached // Couldn't determine, depth limit reached
} derive(Show)

///|
/// Check if a type alias would cause infinite expansion
pub fn check_infinite_expansion(
  type_name : String,
  type_body : TypeV2,
  _type_params : Array[String],
) -> InfiniteTypeResult {
  let visited : Map[String, Bool] = Map::new()
  check_expansion_impl(type_name, type_body, visited, 0, 50)
}

///|
/// Internal infinite expansion check
fn check_expansion_impl(
  type_name : String,
  ty : TypeV2,
  visited : Map[String, Bool],
  depth : Int,
  max_depth : Int,
) -> InfiniteTypeResult {
  if depth > max_depth {
    return DepthLimitReached
  }
  match ty {
    TGenericInstance(name, args) => {
      // Check if this is a self-reference
      if name == type_name {
        // Self-reference detected - check if it's guarded
        // A guarded self-reference is wrapped in an object, array, or function
        // This is safe: type Tree<T> = { value: T, children: Tree<T>[] }
        // This is unsafe: type Infinite<T> = Infinite<T>
        if depth == 0 {
          // Direct self-reference at top level is infinite
          return Infinite("Direct self-reference without wrapper")
        }
        // Self-reference at deeper level is OK (guarded by wrapper)
        return Safe
      }
      // Check arguments for self-reference
      for arg in args {
        match
          check_expansion_impl(type_name, arg, visited, depth + 1, max_depth) {
          Infinite(reason) => return Infinite(reason)
          DepthLimitReached => return DepthLimitReached
          Safe => continue
        }
      }
      Safe
    }
    TUnion(types) => {
      for t in types {
        match
          check_expansion_impl(type_name, t, visited, depth + 1, max_depth) {
          Infinite(reason) => return Infinite(reason)
          DepthLimitReached => return DepthLimitReached
          Safe => continue
        }
      }
      Safe
    }
    TIntersection(types) => {
      for t in types {
        match
          check_expansion_impl(type_name, t, visited, depth + 1, max_depth) {
          Infinite(reason) => return Infinite(reason)
          DepthLimitReached => return DepthLimitReached
          Safe => continue
        }
      }
      Safe
    }
    TArray(elem) =>
      // Array wraps the type - this is a safe guard
      check_expansion_impl(type_name, elem, visited, depth + 1, max_depth)
    TObject(obj) => {
      // Object wraps types - this is a safe guard
      for entry in obj.fields.iter() {
        let (_, field) = entry
        match
          check_expansion_impl(
            type_name,
            field.ty,
            visited,
            depth + 1,
            max_depth,
          ) {
          Infinite(reason) => return Infinite(reason)
          DepthLimitReached => return DepthLimitReached
          Safe => continue
        }
      }
      Safe
    }
    TFunction(func) => {
      // Function wraps types - this is a safe guard
      for p in func.params {
        match
          check_expansion_impl(type_name, p.ty, visited, depth + 1, max_depth) {
          Infinite(reason) => return Infinite(reason)
          DepthLimitReached => return DepthLimitReached
          Safe => continue
        }
      }
      check_expansion_impl(
        type_name,
        func.return_type,
        visited,
        depth + 1,
        max_depth,
      )
    }
    TConditional(c) => {
      // Check all branches
      match
        check_expansion_impl(
          type_name,
          c.check_type,
          visited,
          depth + 1,
          max_depth,
        ) {
        Infinite(reason) => return Infinite(reason)
        DepthLimitReached => return DepthLimitReached
        Safe => ()
      }
      match
        check_expansion_impl(
          type_name,
          c.true_type,
          visited,
          depth + 1,
          max_depth,
        ) {
        Infinite(reason) => return Infinite(reason)
        DepthLimitReached => return DepthLimitReached
        Safe => ()
      }
      check_expansion_impl(
        type_name,
        c.false_type,
        visited,
        depth + 1,
        max_depth,
      )
    }
    TMapped(m) =>
      // Check the template type
      check_expansion_impl(
        type_name,
        m.template_type,
        visited,
        depth + 1,
        max_depth,
      )
    TTuple(elems) => {
      for e in elems {
        match
          check_expansion_impl(type_name, e.ty, visited, depth + 1, max_depth) {
          Infinite(reason) => return Infinite(reason)
          DepthLimitReached => return DepthLimitReached
          Safe => continue
        }
      }
      Safe
    }
    _ => Safe
  }
}

// ============================================================================
// Mutual Recursion Detection
// ============================================================================

///|
/// Result of checking mutual recursion
pub struct MutualRecursionInfo {
  is_mutually_recursive : Bool
  cycle_path : Array[String] // Names involved in the cycle
} derive(Show)

///|
/// Check for mutual recursion between type aliases
pub fn check_mutual_recursion(
  type_aliases : Map[String, TypeV2],
) -> Map[String, MutualRecursionInfo] {
  let results : Map[String, MutualRecursionInfo] = Map::new()
  for entry in type_aliases.iter() {
    let (name, _) = entry
    let visited : Map[String, Bool] = Map::new()
    let path : Array[String] = []
    let info = find_type_cycle(name, type_aliases, visited, path)
    results.set(name, info)
  }
  results
}

///|
/// Find if a type has a cycle back to itself
fn find_type_cycle(
  start_name : String,
  type_aliases : Map[String, TypeV2],
  visited : Map[String, Bool],
  path : Array[String],
) -> MutualRecursionInfo {
  if visited.contains(start_name) {
    // We've seen this before - check if it's in our path
    let mut found_idx : Int? = None
    for i = 0; i < path.length(); i = i + 1 {
      if path[i] == start_name {
        found_idx = Some(i)
        break
      }
    }
    match found_idx {
      Some(i) => {
        let cycle_path : Array[String] = []
        for j = i; j < path.length(); j = j + 1 {
          cycle_path.push(path[j])
        }
        cycle_path.push(start_name)
        return { is_mutually_recursive: true, cycle_path }
      }
      None => return { is_mutually_recursive: false, cycle_path: [] }
    }
  }
  visited.set(start_name, true)
  path.push(start_name)

  // Get the type body and find all type references
  match type_aliases.get(start_name) {
    Some(type_body) => {
      let refs = collect_type_references(type_body)
      for ref_name in refs {
        if type_aliases.contains(ref_name) {
          let result = find_type_cycle(ref_name, type_aliases, visited, path)
          if result.is_mutually_recursive {
            return result
          }
        }
      }
    }
    None => ()
  }
  { is_mutually_recursive: false, cycle_path: [] }
}

///|
/// Collect all type name references from a type
fn collect_type_references(ty : TypeV2) -> Array[String] {
  let refs : Array[String] = []
  collect_refs_impl(ty, refs)
  refs
}

///|
/// Internal reference collection
fn collect_refs_impl(ty : TypeV2, refs : Array[String]) -> Unit {
  match ty {
    TGenericInstance(name, args) => {
      refs.push(name)
      for arg in args {
        collect_refs_impl(arg, refs)
      }
    }
    TTypeParam(name, _) => refs.push(name)
    TUnion(types) =>
      for t in types {
        collect_refs_impl(t, refs)
      }
    TIntersection(types) =>
      for t in types {
        collect_refs_impl(t, refs)
      }
    TArray(elem) => collect_refs_impl(elem, refs)
    TObject(obj) =>
      for entry in obj.fields.iter() {
        let (_, field) = entry
        collect_refs_impl(field.ty, refs)
      }
    TFunction(func) => {
      for p in func.params {
        collect_refs_impl(p.ty, refs)
      }
      collect_refs_impl(func.return_type, refs)
    }
    TConditional(c) => {
      collect_refs_impl(c.check_type, refs)
      collect_refs_impl(c.extends_type, refs)
      collect_refs_impl(c.true_type, refs)
      collect_refs_impl(c.false_type, refs)
    }
    TMapped(m) => {
      collect_refs_impl(m.constraint, refs)
      collect_refs_impl(m.template_type, refs)
    }
    TIndexAccess(ia) => {
      collect_refs_impl(ia.object_type, refs)
      collect_refs_impl(ia.index_type, refs)
    }
    TTuple(elems) =>
      for e in elems {
        collect_refs_impl(e.ty, refs)
      }
    _ => ()
  }
}
