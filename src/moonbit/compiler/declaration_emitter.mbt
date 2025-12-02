// TypeScript Declaration File (.d.ts) Emitter
// Converts TypeScript AST to declaration file format

///|
/// Emitter context for declaration file generation
pub struct DeclarationEmitterContext {
  indent_level : Int
  indent_string : String
  emit_comments : Bool
  strip_internal : Bool // Strip declarations marked as @internal
  type_env : TypeEnv? // Type environment for inferring types of unannotated exports
  strip_private : Bool // Strip private members from classes
  type_only_imports : Map[String, Bool] // Track which imports are type-only
}

///|
/// Create default declaration emitter context
pub fn DeclarationEmitterContext::default() -> DeclarationEmitterContext {
  {
    indent_level: 0,
    indent_string: "  ",
    emit_comments: true,
    strip_internal: true,
    type_env: None,
    strip_private: true,
    type_only_imports: Map::new(),
  }
}

///|
/// Create custom declaration emitter context
pub fn DeclarationEmitterContext::new(
  emit_comments : Bool,
  strip_internal : Bool,
) -> DeclarationEmitterContext {
  {
    indent_level: 0,
    indent_string: "  ",
    emit_comments,
    strip_internal,
    type_env: None,
    strip_private: true,
    type_only_imports: Map::new(),
  }
}

///|
/// Create declaration emitter context with type environment for type inference
pub fn DeclarationEmitterContext::with_type_env(
  type_env : TypeEnv,
) -> DeclarationEmitterContext {
  {
    indent_level: 0,
    indent_string: "  ",
    emit_comments: true,
    strip_internal: true,
    type_env: Some(type_env),
    strip_private: true,
    type_only_imports: Map::new(),
  }
}

///|
/// Increase indentation level
pub fn DeclarationEmitterContext::indent(
  self : DeclarationEmitterContext,
) -> DeclarationEmitterContext {
  {
    indent_level: self.indent_level + 1,
    indent_string: self.indent_string,
    emit_comments: self.emit_comments,
    strip_internal: self.strip_internal,
    type_env: self.type_env,
    strip_private: self.strip_private,
    type_only_imports: self.type_only_imports,
  }
}

///|
/// Decrease indentation level
pub fn DeclarationEmitterContext::dedent(
  self : DeclarationEmitterContext,
) -> DeclarationEmitterContext {
  {
    indent_level: if self.indent_level > 0 {
      self.indent_level - 1
    } else {
      0
    },
    indent_string: self.indent_string,
    emit_comments: self.emit_comments,
    strip_internal: self.strip_internal,
    type_env: self.type_env,
    strip_private: self.strip_private,
    type_only_imports: self.type_only_imports,
  }
}

///|
/// Get current indentation string
fn DeclarationEmitterContext::get_indent(
  self : DeclarationEmitterContext,
) -> String {
  let mut result = ""
  for i = 0; i < self.indent_level; i = i + 1 {
    result = result + self.indent_string
  }
  result
}

///|
/// Helper function to check if a modifier is present
fn has_modifier(modifiers : Array[Modifier], modifier : Modifier) -> Bool {
  for i = 0; i < modifiers.length(); i = i + 1 {
    if modifiers[i] == modifier {
      return true
    }
  }
  false
}

///|
/// Helper function to convert TypeKeyword to string
fn type_keyword_to_string(keyword : TypeKeyword) -> String {
  match keyword {
    Any => "any"
    Unknown => "unknown"
    Never => "never"
    Void => "void"
    Undefined => "undefined"
    Null => "null"
    Boolean => "boolean"
    Number => "number"
    String => "string"
    Symbol => "symbol"
    BigInt => "bigint"
    Object => "object"
    Const => "const" // For "as const" assertions
  }
}

///|
/// Convert TypeV2 to TypeScript type string
/// Used for emitting inferred types in declaration files
pub fn type_v2_to_ts_string(ty : TypeV2) -> String {
  match ty {
    // Primitives
    TNumber => "number"
    TString => "string"
    TBoolean => "boolean"
    TNull => "null"
    TUndefined => "undefined"
    TVoid => "void"
    TNever => "never"
    TAny => "any"
    TUnknown => "unknown"
    TSymbol => "symbol"
    TUniqueSymbol(_) => "unique symbol"
    TBigInt => "bigint"
    // Literals - widen to base types in declarations
    TLiteralString(s) => "\"" + s + "\""
    TLiteralNumber(n) =>
      if n == n.floor() {
        n.to_int().to_string()
      } else {
        n.to_string()
      }
    TLiteralBool(b) => if b { "true" } else { "false" }
    TLiteralBigInt(s) => s + "n"
    // Union types
    TUnion(types) => {
      let parts : Array[String] = []
      for t in types {
        parts.push(type_v2_to_ts_string(t))
      }
      parts.join(" | ")
    }
    // Intersection types
    TIntersection(types) => {
      let parts : Array[String] = []
      for t in types {
        parts.push(type_v2_to_ts_string(t))
      }
      parts.join(" & ")
    }
    // Array type
    TArray(elem) => type_v2_to_ts_string(elem) + "[]"
    // Tuple type
    TTuple(elements) => {
      let parts : Array[String] = []
      for elem in elements {
        let elem_str = type_v2_to_ts_string(elem.ty)
        if elem.optional {
          parts.push(elem_str + "?")
        } else if elem.is_rest {
          parts.push("..." + elem_str)
        } else {
          parts.push(elem_str)
        }
      }
      "[" + parts.join(", ") + "]"
    }
    // Object type
    TObject(obj) => type_v2_object_to_ts_string(obj)
    // Function type
    TFunction(func) => type_v2_function_to_ts_string(func)
    // Generic instance (e.g., Array<number>)
    TGenericInstance(name, args) =>
      if args.length() == 0 {
        name
      } else {
        let arg_strs : Array[String] = []
        for arg in args {
          arg_strs.push(type_v2_to_ts_string(arg))
        }
        name + "<" + arg_strs.join(", ") + ">"
      }
    // Type parameter
    TTypeParam(name, _) => name
    // Conditional type
    TConditional(cond) =>
      type_v2_to_ts_string(cond.check_type) +
      " extends " +
      type_v2_to_ts_string(cond.extends_type) +
      " ? " +
      type_v2_to_ts_string(cond.true_type) +
      " : " +
      type_v2_to_ts_string(cond.false_type)
    // Mapped type
    TMapped(mapped) => {
      let mut output = "{ "
      match mapped.readonly_modifier {
        MappedModifierV2::Add => output = output + "readonly "
        MappedModifierV2::Remove => output = output + "-readonly "
        MappedModifierV2::Unchanged => ()
      }
      output = output + "[" + mapped.type_param.name + " in "
      match mapped.type_param.constraint {
        Some(c) => output = output + type_v2_to_ts_string(c)
        None => output = output + "any"
      }
      output = output + "]"
      match mapped.optional_modifier {
        MappedModifierV2::Add => output = output + "?"
        MappedModifierV2::Remove => output = output + "-?"
        MappedModifierV2::Unchanged => ()
      }
      output = output + ": " + type_v2_to_ts_string(mapped.template_type) + "; }"
      output
    }
    // Indexed access type
    TIndexAccess(idx) =>
      type_v2_to_ts_string(idx.object_type) +
      "[" +
      type_v2_to_ts_string(idx.index_type) +
      "]"
    // Template literal type
    TTemplateLiteral(tlt) => {
      let mut output = "`"
      for i, text in tlt.texts {
        output = output + text
        if i < tlt.types.length() {
          output = output + "${" + type_v2_to_ts_string(tlt.types[i]) + "}"
        }
      }
      output + "`"
    }
    // Infer type
    TInfer(name) => "infer " + name
    // Error type - emit as any
    TError => "any"
  }
}

///|
/// Convert ObjectTypeV2 to TypeScript string
fn type_v2_object_to_ts_string(obj : ObjectTypeV2) -> String {
  // If it's a named class, just use the class name
  match obj.class_name {
    Some(name) => return name
    None => ()
  }
  // Build object literal type
  let parts : Array[String] = []
  // Fields
  for kv in obj.fields {
    let name = kv.0
    let field = kv.1
    let mut prop = ""
    if field.is_readonly {
      prop = prop + "readonly "
    }
    prop = prop + name
    if field.optional {
      prop = prop + "?"
    }
    prop = prop + ": " + type_v2_to_ts_string(field.ty)
    parts.push(prop)
  }
  // Call signatures
  for sig in obj.call_signatures {
    parts.push(type_v2_function_to_ts_string(sig))
  }
  // Index signature
  match obj.index_signature {
    Some(idx) => {
      let key_type = match idx.key_type {
        TString => "string"
        TNumber => "number"
        TSymbol => "symbol"
        _ => "string"
      }
      parts.push("[key: " + key_type + "]: " + type_v2_to_ts_string(idx.value_type))
    }
    None => ()
  }
  if parts.length() == 0 {
    "{}"
  } else {
    "{ " + parts.join("; ") + " }"
  }
}

///|
/// Convert FunctionTypeV2 to TypeScript string
fn type_v2_function_to_ts_string(func : FunctionTypeV2) -> String {
  let mut output = "("
  for i, param in func.params {
    if i > 0 {
      output = output + ", "
    }
    output = output + param.name
    if param.optional {
      output = output + "?"
    }
    output = output + ": " + type_v2_to_ts_string(param.ty)
  }
  output + ") => " + type_v2_to_ts_string(func.return_type)
}

///|
/// Check if a modifier indicates private visibility
fn is_private_modifier(modifier : Modifier) -> Bool {
  match modifier {
    Modifier::Private => true
    _ => false
  }
}

///|
/// Check if modifiers contain private modifier
fn has_private_modifier(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    if is_private_modifier(m) {
      return true
    }
  }
  false
}

// ============================================================================
// Declaration Merging Support
// ============================================================================

///|
/// Merge interfaces with the same name for declaration merging
fn merge_interface_declarations(
  statements : Array[Node],
) -> (Array[Node], Map[String, InterfaceDeclaration]) {
  // Collect interfaces by name
  let interface_map : Map[String, Array[InterfaceDeclaration]] = Map::new()
  let other_statements : Array[Node] = []
  for stmt in statements {
    match stmt {
      InterfaceDeclaration(iface) => {
        match interface_map.get(iface.name) {
          Some(arr) => arr.push(iface)
          None => interface_map.set(iface.name, [iface])
        }
      }
      _ => other_statements.push(stmt)
    }
  }
  // Merge interfaces with the same name
  let merged_interfaces : Map[String, InterfaceDeclaration] = Map::new()
  for kv in interface_map {
    let name = kv.0
    let interfaces = kv.1
    if interfaces.length() == 1 {
      merged_interfaces.set(name, interfaces[0])
    } else {
      // Merge multiple interfaces
      let merged = merge_interfaces(interfaces)
      merged_interfaces.set(name, merged)
    }
  }
  (other_statements, merged_interfaces)
}

///|
/// Merge multiple interface declarations into one
fn merge_interfaces(interfaces : Array[InterfaceDeclaration]) -> InterfaceDeclaration {
  // Use first interface as base
  let base = interfaces[0]
  let merged_members : Array[Node] = []
  // Collect all members from all interfaces
  for iface in interfaces {
    for m in iface.members {
      merged_members.push(m)
    }
  }
  // Merge type parameters (take union)
  let merged_type_params : Array[TypeParameter] = []
  let seen_params : Map[String, Bool] = Map::new()
  for iface in interfaces {
    for param in iface.type_parameters {
      if not(seen_params.contains(param.name)) {
        merged_type_params.push(param)
        seen_params.set(param.name, true)
      }
    }
  }
  // Merge heritage clauses
  let merged_heritage : Array[HeritageClause] = []
  for iface in interfaces {
    for heritage in iface.heritage_clauses {
      merged_heritage.push(heritage)
    }
  }
  {
    name: base.name,
    type_parameters: merged_type_params,
    heritage_clauses: merged_heritage,
    members: merged_members,
    modifiers: base.modifiers,
    location: base.location,
  }
}

// ============================================================================
// Re-export Flattening Support
// ============================================================================

///|
/// Flatten re-exports by collecting exported names
/// Returns a map of exported names to their declarations (if available)
fn collect_reexports(statements : Array[Node]) -> Map[String, String?] {
  let exports : Map[String, String?] = Map::new()
  for stmt in statements {
    match stmt {
      ExportDeclaration(exp) =>
        match exp.export_clause {
          Some(NamedExports(specifiers, _)) =>
            for spec in specifiers {
              // Map property_name to name (for aliased exports)
              match spec.property_name {
                Some(prop) => exports.set(spec.name, Some(prop))
                None => exports.set(spec.name, None)
              }
            }
          Some(NamespaceExport(ns_name, _)) => exports.set(ns_name, None)
          None => ()
        }
      _ => ()
    }
  }
  exports
}

///|
/// Emit flattened re-export (expand to actual type when possible)
fn emit_flattened_export(
  spec_name : String,
  original_name : String?,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  // If we have access to type environment, try to emit the actual type
  match ctx.type_env {
    Some(env) => {
      let lookup_name = match original_name {
        Some(n) => n
        None => spec_name
      }
      match env.lookup(lookup_name) {
        Some(ty) => {
          // Emit as type alias for the exported type
          indent + "export type " + spec_name + " = " + type_v2_to_ts_string(ty) +
          ";"
        }
        None =>
          // Fall back to regular export
          indent + "export { " + spec_name + " };"
      }
    }
    None => indent + "export { " + spec_name + " };"
  }
}

// ============================================================================
// Import Elision Support
// ============================================================================

///|
/// Extract base type name (part before first dot, if any)
fn extract_base_type_name(type_name : String) -> String {
  let mut result = ""
  for c in type_name {
    if c == '.' {
      break
    }
    result = result + c.to_string()
  }
  if result.length() == 0 { type_name } else { result }
}

///|
/// Check if an import is type-only (import type {} or import type X from)
fn is_type_only_import(imp : ImportDeclaration) -> Bool {
  imp.is_type_only
}

///|
/// Collect used type references from statements
/// This helps identify which imports are actually used
fn collect_used_type_refs(statements : Array[Node]) -> Map[String, Bool] {
  let used : Map[String, Bool] = Map::new()
  for stmt in statements {
    collect_type_refs_from_node(stmt, used)
  }
  used
}

///|
/// Recursively collect type references from a node
fn collect_type_refs_from_node(node : Node, used : Map[String, Bool]) -> Unit {
  match node {
    TypeReference(type_ref) => {
      // Extract the base type name (before any dots)
      let base_name = extract_base_type_name(type_ref.type_name)
      used.set(base_name, true)
      // Also collect refs from type arguments
      for arg in type_ref.type_arguments {
        collect_type_refs_from_node(arg, used)
      }
    }
    FunctionDeclaration(func) => {
      match func.return_type {
        Some(rt) => collect_type_refs_from_node(rt, used)
        None => ()
      }
      for param in func.parameters {
        collect_type_refs_from_node(param, used)
      }
    }
    ClassDeclaration(cls) =>
      for m in cls.members {
        collect_type_refs_from_node(m, used)
      }
    InterfaceDeclaration(iface) =>
      for m in iface.members {
        collect_type_refs_from_node(m, used)
      }
    PropertyDeclaration(prop) =>
      match prop.type_annotation {
        Some(ta) => collect_type_refs_from_node(ta, used)
        None => ()
      }
    MethodDeclaration(meth) => {
      match meth.return_type {
        Some(rt) => collect_type_refs_from_node(rt, used)
        None => ()
      }
      for param in meth.parameters {
        collect_type_refs_from_node(param, used)
      }
    }
    Parameter(param) =>
      match param.type_annotation {
        Some(ta) => collect_type_refs_from_node(ta, used)
        None => ()
      }
    VariableStatement(var_stmt) =>
      for decl in var_stmt.declarations {
        match decl.type_annotation {
          Some(ta) => collect_type_refs_from_node(ta, used)
          None => ()
        }
      }
    UnionType(union) =>
      for t in union.types {
        collect_type_refs_from_node(t, used)
      }
    IntersectionType(intersection) =>
      for t in intersection.types {
        collect_type_refs_from_node(t, used)
      }
    ArrayType(arr) => collect_type_refs_from_node(arr.element_type, used)
    _ => ()
  }
}

///|
/// Filter imports to only include used type imports (import elision)
fn filter_imports_for_declaration(
  statements : Array[Node],
) -> (Array[ImportDeclaration], Array[Node]) {
  let used_types = collect_used_type_refs(statements)
  let kept_imports : Array[ImportDeclaration] = []
  let other_statements : Array[Node] = []
  for stmt in statements {
    match stmt {
      ImportDeclaration(imp) => {
        // Keep type-only imports as-is
        if is_type_only_import(imp) {
          kept_imports.push(imp)
        } else {
          // For regular imports, check if any imported names are used as types
          match imp.import_clause {
            Some(clause) => {
              let mut has_used = false
              // Check default import
              match clause.name {
                Some(name) =>
                  if used_types.contains(name) {
                    has_used = true
                  }
                None => ()
              }
              // Check named imports
              match clause.named_bindings {
                Some(NamedImports(specifiers, _)) =>
                  for spec in specifiers {
                    if used_types.contains(spec.name) {
                      has_used = true
                    }
                  }
                Some(NamespaceImport(name, _)) =>
                  if used_types.contains(name) {
                    has_used = true
                  }
                None => ()
              }
              if has_used {
                kept_imports.push(imp)
              }
            }
            None => ()
          }
        }
      }
      _ => other_statements.push(stmt)
    }
  }
  (kept_imports, other_statements)
}

// ============================================================================
// Inline Type Expansion Support
// ============================================================================

///|
/// Check if a type alias should be inlined (simple types, small unions, etc.)
fn should_inline_type_alias(ty : TypeV2) -> Bool {
  match ty {
    // Primitives are always inlinable
    TNumber | TString | TBoolean | TNull | TUndefined | TVoid | TNever | TAny |
    TUnknown | TSymbol | TBigInt => true
    // Literals are inlinable
    TLiteralString(_) | TLiteralNumber(_) | TLiteralBool(_) |
    TLiteralBigInt(_) => true
    // Small unions (up to 3 members) can be inlined
    TUnion(types) => types.length() <= 3
    // Type params should not be inlined
    TTypeParam(_, _) => false
    // Generic instances are usually named types, don't inline
    TGenericInstance(_, _) => false
    // Complex types should not be inlined
    _ => false
  }
}

///|
/// Expand a type alias if it should be inlined
fn expand_type_if_inline(
  type_name : String,
  ctx : DeclarationEmitterContext,
) -> String? {
  match ctx.type_env {
    Some(env) =>
      match env.lookup_type_alias(type_name) {
        Some(alias_info) =>
          if should_inline_type_alias(alias_info.body) {
            Some(type_v2_to_ts_string(alias_info.body))
          } else {
            None
          }
        None => None
      }
    None => None
  }
}

///|
/// Emit a source file as a declaration file
pub fn emit_declaration_file(
  source_file : SourceFile,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = ""

  // Emit header comment
  output = output + "// Type definitions for " + source_file.file_path + "\n"
  output = output + "// Generated by MoonBit TypeScript Compiler\n\n"

  // Apply declaration merging for interfaces
  let (other_stmts, merged_ifaces) = merge_interface_declarations(
    source_file.statements,
  )

  // Emit merged interfaces first
  for kv in merged_ifaces {
    let iface = kv.1
    output = output + emit_decl_interface(iface, ctx) + "\n"
  }

  // Emit other statements
  for stmt in other_stmts {
    match emit_decl_statement(stmt, ctx) {
      Some(decl) => output = output + decl + "\n"
      None => ()
    }
  }
  output
}

///|
/// Emit a statement as a declaration (returns None for non-declaration statements)
fn emit_decl_statement(node : Node, ctx : DeclarationEmitterContext) -> String? {
  match node {
    // Declarations that should be emitted
    FunctionDeclaration(func) => Some(emit_decl_function(func, ctx, true))
    ClassDeclaration(cls) => Some(emit_decl_class(cls, ctx, true))
    InterfaceDeclaration(iface) => Some(emit_decl_interface(iface, ctx))
    TypeAliasDeclaration(type_alias) =>
      Some(emit_decl_type_alias(type_alias, ctx))
    EnumDeclaration(enum_decl) => Some(emit_decl_enum(enum_decl, ctx))
    ModuleDeclaration(mod_decl) => Some(emit_decl_module(mod_decl, ctx))
    ImportDeclaration(imp) => Some(emit_decl_import(imp, ctx))
    ExportDeclaration(exp) => Some(emit_decl_export(exp, ctx))
    ExportAssignment(assign) => Some(emit_decl_export_assignment(assign, ctx))

    // Variable statements - emit as declarations
    VariableStatement(var_stmt) =>
      Some(emit_decl_variable_statement(var_stmt, ctx))

    // Skip all other statement types (they don't belong in .d.ts files)
    _ => None
  }
}

///|
/// Emit a variable statement as a declaration
fn emit_decl_variable_statement(
  var_stmt : VariableStatement,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent

  // Use declare keyword for top-level variables
  output = output + "declare "
  if var_stmt.is_const {
    output = output + "const "
  } else if var_stmt.is_let {
    output = output + "let "
  } else {
    output = output + "var "
  }

  // Emit variable declarations
  for i = 0; i < var_stmt.declarations.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    let decl = var_stmt.declarations[i]
    output = output + emit_decl_variable_declarator(decl, ctx)
  }
  output + ";"
}

///|
/// Emit a variable declarator
fn emit_decl_variable_declarator(
  decl : VariableDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let var_name = emit_decl_binding_name(decl.name)
  let mut output = var_name

  // Add type annotation - prefer explicit, then inferred, then any
  match decl.type_annotation {
    Some(type_node) =>
      output = output + ": " + emit_decl_type_node(type_node, ctx)
    None =>
      // Try to get inferred type from type environment
      match ctx.type_env {
        Some(env) =>
          match env.lookup(var_name) {
            Some(inferred_ty) =>
              output = output + ": " + type_v2_to_ts_string(inferred_ty)
            None => output = output + ": any"
          }
        None => output = output + ": any"
      }
  }
  output
}

///|
/// Emit binding name (identifier or pattern)
fn emit_decl_binding_name(node : Node) -> String {
  match node {
    Identifier(id) => id.name
    ArrayBindingPattern(_) => "[]" // Simplified
    ObjectBindingPattern(_) => "{}" // Simplified
    _ => "unknown"
  }
}

///|
/// Emit a function declaration

///|
/// Check if modifiers have Export modifier
fn has_export_mod(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    if m == Modifier::Export {
      return true
    }
  }
  false
}

///|
/// Check if modifiers have Default modifier
fn has_default_mod(modifiers : Array[Modifier]) -> Bool {
  for m in modifiers {
    if m == Modifier::Default {
      return true
    }
  }
  false
}

///|
fn emit_decl_function(
  func : FunctionDeclaration,
  ctx : DeclarationEmitterContext,
  is_top_level : Bool,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent

  // Handle export modifiers
  let is_exported = has_export_mod(func.modifiers)
  let is_default = has_default_mod(func.modifiers)
  if is_exported && is_default {
    output = output + "export default "
  } else if is_exported {
    output = output + "export "
  } else if is_top_level {
    // Add declare keyword for top-level non-exported functions
    output = output + "declare "
  }

  // Function keyword
  if func.is_async {
    output = output + "async "
  }
  output = output + "function"
  if func.is_generator {
    output = output + "*"
  }
  output = output + " "

  // Function name
  match func.name {
    Some(Identifier(id)) => output = output + id.name
    _ => output = output + "anonymous"
  }

  // Type parameters
  if func.type_parameters.length() > 0 {
    output = output + emit_decl_type_parameters(func.type_parameters, ctx)
  }

  // Parameters
  output = output + "("
  for i = 0; i < func.parameters.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_parameter(func.parameters[i], ctx)
  }
  output = output + ")"

  // Return type
  match func.return_type {
    Some(return_type) =>
      output = output + ": " + emit_decl_type_node(return_type, ctx)
    None => output = output + ": void"
  }
  output + ";"
}

///|
/// Emit a class declaration
fn emit_decl_class(
  cls : ClassDeclaration,
  ctx : DeclarationEmitterContext,
  is_top_level : Bool,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent

  // Handle export modifiers
  let is_exported = has_export_mod(cls.modifiers)
  let is_default = has_default_mod(cls.modifiers)
  if is_exported && is_default {
    output = output + "export default "
  } else if is_exported {
    output = output + "export "
  } else if is_top_level {
    // Add declare keyword for top-level non-exported classes
    output = output + "declare "
  }

  // Abstract modifier
  if cls.is_abstract {
    output = output + "abstract "
  }
  output = output + "class "

  // Class name
  match cls.name {
    Some(Identifier(id)) => output = output + id.name
    _ => output = output + "Anonymous"
  }

  // Type parameters
  if cls.type_parameters.length() > 0 {
    output = output + emit_decl_type_parameters(cls.type_parameters, ctx)
  }

  // Heritage clauses (extends/implements)
  for i = 0; i < cls.heritage_clauses.length(); i = i + 1 {
    output = output +
      " " +
      emit_decl_heritage_clause(cls.heritage_clauses[i], ctx)
  }
  output = output + " {\n"

  // Emit members
  let member_ctx = ctx.indent()
  for i = 0; i < cls.members.length(); i = i + 1 {
    match emit_decl_class_member(cls.members[i], member_ctx) {
      Some(mem) => output = output + mem + "\n"
      None => ()
    }
  }
  output + indent + "}"
}

///|
/// Emit a class member
fn emit_decl_class_member(
  node : Node,
  ctx : DeclarationEmitterContext,
) -> String? {
  // Strip private members when strip_private is enabled
  if ctx.strip_private {
    match node {
      PropertyDeclaration(prop) =>
        if has_private_modifier(prop.modifiers) {
          return None
        }
      MethodDeclaration(meth) =>
        if has_private_modifier(meth.modifiers) {
          return None
        }
      GetAccessor(getter) =>
        if has_private_modifier(getter.modifiers) {
          return None
        }
      SetAccessor(setter) =>
        if has_private_modifier(setter.modifiers) {
          return None
        }
      _ => ()
    }
  }
  match node {
    PropertyDeclaration(prop) => Some(emit_decl_property(prop, ctx))
    MethodDeclaration(meth) => Some(emit_decl_method(meth, ctx))
    ConstructorDeclaration(ctor) => Some(emit_decl_constructor(ctor, ctx))
    GetAccessor(getter) => Some(emit_decl_get_accessor(getter, ctx))
    SetAccessor(setter) => Some(emit_decl_set_accessor(setter, ctx))
    _ => None
  }
}

///|
/// Emit a property declaration
fn emit_decl_property(
  prop : PropertyDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent

  // Modifiers
  if has_modifier(prop.modifiers, Static) {
    output = output + "static "
  }
  if has_modifier(prop.modifiers, Readonly) {
    output = output + "readonly "
  }

  // Property name
  output = output + prop.name

  // Optional marker
  if prop.is_optional {
    output = output + "?"
  }

  // Type annotation
  match prop.type_annotation {
    Some(type_node) =>
      output = output + ": " + emit_decl_type_node(type_node, ctx)
    None => output = output + ": any"
  }
  output + ";"
}

///|
/// Emit a method declaration
fn emit_decl_method(
  meth : MethodDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent

  // Modifiers
  if has_modifier(meth.modifiers, Static) {
    output = output + "static "
  }
  if has_modifier(meth.modifiers, Abstract) {
    output = output + "abstract "
  }
  if meth.is_async {
    output = output + "async "
  }

  // Method name
  output = output + meth.name

  // Optional marker
  if meth.is_optional {
    output = output + "?"
  }

  // Type parameters
  if meth.type_parameters.length() > 0 {
    output = output + emit_decl_type_parameters(meth.type_parameters, ctx)
  }

  // Parameters
  output = output + "("
  for i = 0; i < meth.parameters.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_parameter(meth.parameters[i], ctx)
  }
  output = output + ")"

  // Return type
  match meth.return_type {
    Some(return_type) =>
      output = output + ": " + emit_decl_type_node(return_type, ctx)
    None => output = output + ": void"
  }
  output + ";"
}

///|
/// Emit a constructor declaration
fn emit_decl_constructor(
  ctor : ConstructorDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "constructor("

  // Parameters
  for i = 0; i < ctor.parameters.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_parameter(ctor.parameters[i], ctx)
  }
  output + ");"
}

///|
/// Emit a get accessor
fn emit_decl_get_accessor(
  getter : GetAccessor,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent
  if has_modifier(getter.modifiers, Static) {
    output = output + "static "
  }
  output = output + "get " + getter.name + "()"

  // Return type
  match getter.return_type {
    Some(type_node) =>
      output = output + ": " + emit_decl_type_node(type_node, ctx)
    None => output = output + ": any"
  }
  output + ";"
}

///|
/// Emit a set accessor
fn emit_decl_set_accessor(
  setter : SetAccessor,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent
  if has_modifier(setter.modifiers, Static) {
    output = output + "static "
  }
  output = output + "set " + setter.name + "("
  output = output + emit_decl_parameter(setter.parameter, ctx)
  output + ");"
}

///|
/// Emit an interface declaration
fn emit_decl_interface(
  iface : InterfaceDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "interface " + iface.name

  // Type parameters
  if iface.type_parameters.length() > 0 {
    output = output + emit_decl_type_parameters(iface.type_parameters, ctx)
  }

  // Heritage clauses (extends)
  for i = 0; i < iface.heritage_clauses.length(); i = i + 1 {
    output = output +
      " " +
      emit_decl_heritage_clause(iface.heritage_clauses[i], ctx)
  }
  output = output + " {\n"

  // Emit members
  let member_ctx = ctx.indent()
  for i = 0; i < iface.members.length(); i = i + 1 {
    match emit_decl_type_element(iface.members[i], member_ctx) {
      Some(mem) => output = output + mem + "\n"
      None => ()
    }
  }
  output + indent + "}"
}

///|
/// Emit a type element (interface/type literal member)
fn emit_decl_type_element(
  node : Node,
  ctx : DeclarationEmitterContext,
) -> String? {
  match node {
    PropertyDeclaration(prop) => Some(emit_decl_property_signature(prop, ctx))
    IndexSignatureDeclaration(idx) => Some(emit_decl_index_signature(idx, ctx))
    MethodDeclaration(meth) => Some(emit_decl_method_signature(meth, ctx))
    ConstructorDeclaration(ctor) =>
      Some(emit_decl_constructor_signature(ctor, ctx))
    _ => None
  }
}

///|
/// Emit a property signature
fn emit_decl_property_signature(
  prop : PropertyDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent
  if has_modifier(prop.modifiers, Readonly) {
    output = output + "readonly "
  }
  output = output + prop.name
  // Optional marker
  if prop.is_optional {
    output = output + "?"
  }
  match prop.type_annotation {
    Some(type_node) =>
      output = output + ": " + emit_decl_type_node(type_node, ctx)
    None => output = output + ": any"
  }
  output + ";"
}

///|
/// Emit an index signature
fn emit_decl_index_signature(
  idx : IndexSignatureDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let param_type = emit_decl_type_node(idx.parameter_type, ctx)
  let return_type = emit_decl_type_node(idx.return_type, ctx)
  indent +
  "[" +
  idx.parameter_name +
  ": " +
  param_type +
  "]: " +
  return_type +
  ";"
}

///|
/// Emit a method signature
fn emit_decl_method_signature(
  meth : MethodDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent

  // Check if this is a call signature (empty name)
  let is_call_signature = meth.name == ""

  // Add method name (skip for call signatures)
  if not(is_call_signature) {
    output = output + meth.name
    // Optional marker (only for named methods)
    if meth.is_optional {
      output = output + "?"
    }
  }

  // Type parameters
  if meth.type_parameters.length() > 0 {
    output = output + emit_decl_type_parameters(meth.type_parameters, ctx)
  }

  // Parameters
  output = output + "("
  for i = 0; i < meth.parameters.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_parameter(meth.parameters[i], ctx)
  }
  output = output + ")"

  // Return type
  match meth.return_type {
    Some(return_type) =>
      output = output + ": " + emit_decl_type_node(return_type, ctx)
    None => output = output + ": void"
  }
  output + ";"
}

///|
/// Emit a constructor signature
fn emit_decl_constructor_signature(
  ctor : ConstructorDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "new ("
  for i = 0; i < ctor.parameters.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_parameter(ctor.parameters[i], ctx)
  }
  output + ");"
}

///|
/// Emit a type alias declaration
fn emit_decl_type_alias(
  type_alias : TypeAliasDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "type " + type_alias.name
  if type_alias.type_parameters.length() > 0 {
    output = output + emit_decl_type_parameters(type_alias.type_parameters, ctx)
  }
  output + " = " + emit_decl_type_node(type_alias.type_node, ctx) + ";"
}

///|
/// Emit an enum declaration
fn emit_decl_enum(
  enum_decl : EnumDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent
  if enum_decl.is_const {
    output = output + "const "
  }
  output = output + "enum " + enum_decl.name + " {\n"
  let member_ctx = ctx.indent()
  let member_indent = member_ctx.get_indent()
  for i = 0; i < enum_decl.members.length(); i = i + 1 {
    let mem = enum_decl.members[i]
    output = output + member_indent + mem.name

    // Emit initializer if present
    match mem.initializer {
      Some(init) => output = output + " = " + emit_decl_expression(init)
      None => ()
    }
    if i < enum_decl.members.length() - 1 {
      output = output + ","
    }
    output = output + "\n"
  }
  output + indent + "}"
}

///|
/// Emit a module/namespace declaration
fn emit_decl_module(
  mod_decl : ModuleDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "declare namespace " + mod_decl.name + " {\n"

  // Emit body
  match mod_decl.body {
    Some(BlockStatement(block)) => {
      let body_ctx = ctx.indent()
      for i = 0; i < block.statements.length(); i = i + 1 {
        match emit_decl_statement(block.statements[i], body_ctx) {
          Some(decl) => output = output + decl + "\n"
          None => ()
        }
      }
    }
    _ => ()
  }
  output + indent + "}"
}

///|
/// Emit an import declaration
fn emit_decl_import(
  imp : ImportDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "import "
  match imp.import_clause {
    Some(clause) => {
      let parts : Array[String] = []

      // Default import
      match clause.name {
        Some(name) => parts.push(name)
        None => ()
      }

      // Named imports
      match clause.named_bindings {
        Some(NamespaceImport(name, _)) => parts.push("* as " + name)
        Some(NamedImports(specifiers, _)) => {
          let mut named = "{ "
          for i = 0; i < specifiers.length(); i = i + 1 {
            if i > 0 {
              named = named + ", "
            }
            let spec = specifiers[i]
            match spec.property_name {
              Some(prop) => named = named + prop + " as " + spec.name
              None => named = named + spec.name
            }
          }
          named = named + " }"
          parts.push(named)
        }
        None => ()
      }

      // Combine parts
      for i = 0; i < parts.length(); i = i + 1 {
        if i > 0 {
          output = output + ", "
        }
        output = output + parts[i]
      }
      output = output + " from "
    }
    None => ()
  }
  output + "\"" + imp.module_specifier + "\";"
}

///|
/// Emit an export declaration
fn emit_decl_export(
  exp : ExportDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  let mut output = indent + "export "
  match exp.export_clause {
    Some(NamedExports(specifiers, _)) => {
      output = output + "{ "
      for i = 0; i < specifiers.length(); i = i + 1 {
        if i > 0 {
          output = output + ", "
        }
        let spec = specifiers[i]
        match spec.property_name {
          Some(prop) => output = output + spec.name + " as " + prop
          None => output = output + spec.name
        }
      }
      output = output + " }"
    }
    Some(NamespaceExport(ns_name, _)) => output = output + "* as " + ns_name
    None => output = output + "*"
  }
  match exp.module_specifier {
    Some(module_spec) => output = output + " from \"" + module_spec + "\""
    None => ()
  }
  output + ";"
}

///|
/// Emit an export assignment
fn emit_decl_export_assignment(
  assign : ExportAssignment,
  ctx : DeclarationEmitterContext,
) -> String {
  let indent = ctx.get_indent()
  if assign.is_export_equals {
    indent + "export = " + emit_decl_expression(assign.expression) + ";"
  } else {
    // Check if the expression is a function or class declaration
    match assign.expression {
      FunctionDeclaration(func) => {
        // Emit as export default function (not top-level since it's exported)
        let func_decl = emit_decl_function(func, ctx, false)
        // Remove the indent and add "export default " prefix
        let func_body = @utils.substr(func_decl, start=indent.length())
        indent + "export default " + func_body
      }
      ClassDeclaration(cls) => {
        // Emit as export default class (not top-level since it's exported)
        let cls_decl = emit_decl_class(cls, ctx, false)
        // Remove the indent and add "export default " prefix
        let cls_body = @utils.substr(cls_decl, start=indent.length())
        indent + "export default " + cls_body
      }
      _ =>
        // For expressions, use the original behavior
        indent +
        "export default " +
        emit_decl_expression(assign.expression) +
        ";"
    }
  }
}

///|
/// Emit type parameters
fn emit_decl_type_parameters(
  type_params : Array[TypeParameter],
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = "<"
  for i = 0; i < type_params.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    let param = type_params[i]
    output = output + param.name

    // Constraint
    match param.constraint {
      Some(constraint) =>
        output = output + " extends " + emit_decl_type_node(constraint, ctx)
      None => ()
    }

    // Default
    match param.default {
      Some(default) =>
        output = output + " = " + emit_decl_type_node(default, ctx)
      None => ()
    }
  }
  output + ">"
}

///|
/// Emit a parameter
fn emit_decl_parameter(node : Node, ctx : DeclarationEmitterContext) -> String {
  match node {
    Parameter(param) => {
      let mut output = ""

      // Parameter name
      output = output + emit_decl_binding_name(param.name)

      // Optional marker
      if param.is_optional {
        output = output + "?"
      }

      // Type annotation
      match param.type_annotation {
        Some(type_node) =>
          output = output + ": " + emit_decl_type_node(type_node, ctx)
        None => ()
      }
      output
    }
    _ => "unknown"
  }
}

///|
/// Emit a heritage clause (extends/implements)
fn emit_decl_heritage_clause(
  clause : HeritageClause,
  ctx : DeclarationEmitterContext,
) -> String {
  let keyword = match clause.kind {
    Extends => "extends"
    Implements => "implements"
  }
  let mut output = keyword + " "
  for i = 0; i < clause.types.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_type_node(clause.types[i], ctx)
  }
  output
}

///|
/// Emit a type node
fn emit_decl_type_node(node : Node, ctx : DeclarationEmitterContext) -> String {
  match node {
    KeywordType(keyword) => type_keyword_to_string(keyword.kind)
    TypeReference(type_ref) => emit_decl_type_reference(type_ref, ctx)
    UnionType(union) => emit_decl_union_type(union, ctx)
    IntersectionType(intersection) =>
      emit_decl_intersection_type(intersection, ctx)
    FunctionType(func_type) => emit_decl_function_type(func_type, ctx)
    ArrayType(array_type) => emit_decl_array_type(array_type, ctx)
    TupleType(tuple_type) => emit_decl_tuple_type(tuple_type, ctx)
    LiteralType(literal) => emit_decl_literal_type(literal)
    IndexedAccessType(indexed) => emit_decl_indexed_access_type(indexed, ctx)
    ConditionalType(cond) => emit_decl_conditional_type(cond, ctx)
    MappedType(mapped) => emit_decl_mapped_type(mapped, ctx)
    TypeOperator(type_op) => emit_decl_type_operator(type_op, ctx)
    TemplateLiteralType(tlt) => emit_decl_template_literal_type(tlt, ctx)
    NamedTupleMember(ntm) => emit_decl_named_tuple_member(ntm, ctx)
    TypeLiteral(tl) => emit_decl_type_literal(tl, ctx)
    TypeLiteralProperty(prop) => emit_decl_type_literal_property(prop, ctx)
    _ => "any"
  }
}

///|
/// Emit a type operator (keyof T, typeof x, readonly T, unique symbol)
fn emit_decl_type_operator(
  type_op : TypeOperator,
  ctx : DeclarationEmitterContext,
) -> String {
  let keyword = match type_op.operator {
    TypeOperatorKind::KeyOf => "keyof"
    TypeOperatorKind::TypeOf => "typeof"
    TypeOperatorKind::Unique => "unique"
    TypeOperatorKind::Readonly => "readonly"
  }
  keyword + " " + emit_decl_type_node(type_op.type_node, ctx)
}

///|
/// Helper to get dollar-brace string (workaround for JS template literal compilation)
fn dollar_brace() -> String {
  // Build "${" using character codes to avoid issues with JS template literal compilation
  (36).unsafe_to_char().to_string() + (123).unsafe_to_char().to_string()
}

///|
/// Emit a template literal type (`prefix${Type}suffix`)
fn emit_decl_template_literal_type(
  tlt : TemplateLiteralType,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = "`" + tlt.head
  for span in tlt.spans {
    output = output + dollar_brace() + emit_decl_type_node(span.type_node, ctx) + "}" +
      span.literal
  }
  output + "`"
}

///|
/// Emit a named tuple member (name: type or name?: type)
fn emit_decl_named_tuple_member(
  ntm : NamedTupleMember,
  ctx : DeclarationEmitterContext,
) -> String {
  let optional_marker = if ntm.is_optional { "?" } else { "" }
  ntm.name + optional_marker + ": " + emit_decl_type_node(ntm.element_type, ctx)
}

///|
/// Emit a type literal: { prop: type; [key: string]: type }
fn emit_decl_type_literal(
  tl : TypeLiteral,
  ctx : DeclarationEmitterContext,
) -> String {
  if tl.members.length() == 0 {
    return "{}"
  }
  let mut output = "{ "
  for i = 0; i < tl.members.length(); i = i + 1 {
    if i > 0 {
      output = output + "; "
    }
    match tl.members[i] {
      TypeLiteralProperty(prop) =>
        output = output + emit_decl_type_literal_property(prop, ctx)
      IndexSignatureDeclaration(idx) =>
        output = output + emit_decl_index_signature_inline(idx, ctx)
      _ => ()
    }
  }
  output + " }"
}

///|
/// Emit a type literal property: name: type or name?: type
fn emit_decl_type_literal_property(
  prop : TypeLiteralProperty,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = ""
  if prop.is_readonly {
    output = output + "readonly "
  }
  output = output + prop.name
  if prop.is_optional {
    output = output + "?"
  }
  match prop.type_node {
    Some(type_node) => output = output + ": " + emit_decl_type_node(type_node, ctx)
    None => ()
  }
  output
}

///|
/// Emit an index signature inline (for type literals): [key: string]: type
fn emit_decl_index_signature_inline(
  idx : IndexSignatureDeclaration,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = ""
  if idx.is_readonly {
    output = output + "readonly "
  }
  output = output + "[" + idx.parameter_name + ": " +
    emit_decl_type_node(idx.parameter_type, ctx) + "]: " +
    emit_decl_type_node(idx.return_type, ctx)
  output
}

///|
/// Emit a type reference
fn emit_decl_type_reference(
  type_ref : TypeReference,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = type_ref.type_name
  if type_ref.type_arguments.length() > 0 {
    output = output + "<"
    for i = 0; i < type_ref.type_arguments.length(); i = i + 1 {
      if i > 0 {
        output = output + ", "
      }
      output = output + emit_decl_type_node(type_ref.type_arguments[i], ctx)
    }
    output = output + ">"
  }
  output
}

///|
/// Emit a union type
fn emit_decl_union_type(
  union : UnionType,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = ""
  for i = 0; i < union.types.length(); i = i + 1 {
    if i > 0 {
      output = output + " | "
    }
    output = output + emit_decl_type_node(union.types[i], ctx)
  }
  output
}

///|
/// Emit an intersection type
fn emit_decl_intersection_type(
  intersection : IntersectionType,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = ""
  for i = 0; i < intersection.types.length(); i = i + 1 {
    if i > 0 {
      output = output + " & "
    }
    output = output + emit_decl_type_node(intersection.types[i], ctx)
  }
  output
}

///|
/// Emit a function type
fn emit_decl_function_type(
  func_type : FunctionType,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = "("
  for i = 0; i < func_type.parameters.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_parameter(func_type.parameters[i], ctx)
  }
  output = output + ") => " + emit_decl_type_node(func_type.return_type, ctx)
  output
}

///|
/// Emit an array type
fn emit_decl_array_type(
  array_type : ArrayType,
  ctx : DeclarationEmitterContext,
) -> String {
  emit_decl_type_node(array_type.element_type, ctx) + "[]"
}

///|
/// Emit a tuple type
fn emit_decl_tuple_type(
  tuple_type : TupleType,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = "["
  for i = 0; i < tuple_type.element_types.length(); i = i + 1 {
    if i > 0 {
      output = output + ", "
    }
    output = output + emit_decl_type_node(tuple_type.element_types[i], ctx)
  }
  output + "]"
}

///|
/// Emit a literal type
fn emit_decl_literal_type(literal : LiteralType) -> String {
  match literal.literal {
    NumericLiteral(num) => num.value
    StringLiteral(str) => "\"" + str.value + "\""
    BooleanLiteral(bool) => if bool.value { "true" } else { "false" }
    NullLiteral(_) => "null"
    _ => "any"
  }
}

///|
/// Emit an indexed access type (T[K])
fn emit_decl_indexed_access_type(
  indexed : IndexedAccessType,
  ctx : DeclarationEmitterContext,
) -> String {
  let object_type = emit_decl_type_node(indexed.object_type, ctx)
  let index_type = emit_decl_type_node(indexed.index_type, ctx)
  object_type + "[" + index_type + "]"
}

///|
/// Emit a conditional type (T extends U ? X : Y)
fn emit_decl_conditional_type(
  cond : ConditionalType,
  ctx : DeclarationEmitterContext,
) -> String {
  let check = emit_decl_type_node(cond.check_type, ctx)
  let extends = emit_decl_type_node(cond.extends_type, ctx)
  let true_type = emit_decl_type_node(cond.true_type, ctx)
  let false_type = emit_decl_type_node(cond.false_type, ctx)
  check + " extends " + extends + " ? " + true_type + " : " + false_type
}

///|
/// Emit a mapped type ({ [P in keyof T]: T[P] })
fn emit_decl_mapped_type(
  mapped : MappedType,
  ctx : DeclarationEmitterContext,
) -> String {
  let mut output = "{ "

  // Emit readonly modifier
  match mapped.readonly_modifier {
    MappedTypeModifier::Plus => output = output + "readonly "
    MappedTypeModifier::Minus => output = output + "-readonly "
    MappedTypeModifier::Unchanged => ()
  }

  output = output + "[" + mapped.type_parameter.name + " in "
  match mapped.type_parameter.constraint {
    Some(constraint) => output = output + emit_decl_type_node(constraint, ctx)
    None => output = output + "any"
  }

  // Emit 'as' clause for key remapping
  match mapped.name_type {
    Some(name_type) =>
      output = output + " as " + emit_decl_type_node(name_type, ctx)
    None => ()
  }

  output = output + "]"

  // Emit optional modifier
  match mapped.optional_modifier {
    MappedTypeModifier::Plus => output = output + "?"
    MappedTypeModifier::Minus => output = output + "-?"
    MappedTypeModifier::Unchanged => ()
  }

  match mapped.type_node {
    Some(type_node) =>
      output = output + ": " + emit_decl_type_node(type_node, ctx)
    None => output = output + ": any"
  }
  output + "; }"
}

///|
/// Emit an expression (simplified for declarations)
fn emit_decl_expression(node : Node) -> String {
  match node {
    Identifier(id) => id.name
    NumericLiteral(num) => num.value
    StringLiteral(str) => "\"" + str.value + "\""
    BooleanLiteral(bool) => if bool.value { "true" } else { "false" }
    NullLiteral(_) => "null"
    // Type assertions - unwrap to inner expression
    AsExpression(ae) => emit_decl_expression(ae.expression)
    TypeAssertionExpression(tae) => emit_decl_expression(tae.expression)
    NonNullExpression(nne) => emit_decl_expression(nne.expression)
    _ => "unknown"
  }
}

// Suppress warnings for functions reserved for future use
fn init {
  ignore(collect_reexports)
  ignore(emit_flattened_export)
  ignore(filter_imports_for_declaration)
}
