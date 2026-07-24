// Module System - Complete Module Resolution, Detection, and Conversion
// Implements missing TypeScript module system features:
// 1. Module kind detection and conversion (ESM ↔ CommonJS)
// 2. Type-only import/export semantic enforcement
// 3. File system interface for module resolution
// 4. Binder/checker integration

// ============================================================================
// Module Format Detection
// ============================================================================

///|
/// Detected module format
pub enum ModuleFormat {
  /// ES Modules (import/export)
  ESM
  /// CommonJS (require/module.exports)
  CJS
  /// Ambient module declaration (declare module)
  Ambient
  /// Script (no module syntax)
  Script
} derive(Eq, Debug)

///|
/// Factory function for ESM
pub fn ModuleFormat::esm() -> ModuleFormat {
  ESM
}

///|
/// Factory function for CJS
pub fn ModuleFormat::cjs() -> ModuleFormat {
  CJS
}

///|
/// Factory function for Ambient
pub fn ModuleFormat::ambient() -> ModuleFormat {
  Ambient
}

///|
/// Factory function for Script
pub fn ModuleFormat::script() -> ModuleFormat {
  Script
}

///|
/// Result of module format detection
pub struct ModuleFormatInfo {
  /// Detected format
  mut format : ModuleFormat
  /// Whether file has ES imports
  mut has_esm_imports : Bool
  /// Whether file has ES exports
  mut has_esm_exports : Bool
  /// Whether file has CommonJS require
  mut has_cjs_require : Bool
  /// Whether file has CommonJS exports
  mut has_cjs_exports : Bool
  /// Whether file has top-level await (ESM only)
  mut has_top_level_await : Bool
  /// Whether file extension forces module format
  mut extension_forced : Bool
} derive(Debug)

///|
/// Create default module format info
pub fn ModuleFormatInfo::default() -> ModuleFormatInfo {
  {
    format: Script,
    has_esm_imports: false,
    has_esm_exports: false,
    has_cjs_require: false,
    has_cjs_exports: false,
    has_top_level_await: false,
    extension_forced: false,
  }
}

///|
/// Detect module format from source file
pub fn detect_module_format(source_file : SourceFile) -> ModuleFormatInfo {
  let info = ModuleFormatInfo::default()

  // Check file extension
  let extension = get_file_extension(source_file.file_path)
  if extension == ".mjs" || extension == ".mts" {
    info.format = ESM
    info.extension_forced = true
  } else if extension == ".cjs" || extension == ".cts" {
    info.format = CJS
    info.extension_forced = true
  }

  // Analyze statements
  for stmt in source_file.statements {
    analyze_statement_for_module_format(stmt, info)
  }

  // Determine final format if not extension-forced
  if !(info.extension_forced) {
    info.format = determine_format(info)
  }
  info
}

///|
/// Get all import declarations from a source file
/// Includes ES6 imports, TypeScript import equals declarations, and CommonJS require() calls
pub fn get_imports(source_file : SourceFile) -> Array[ImportDeclaration] {
  let imports : Array[ImportDeclaration] = []
  for stmt in source_file.statements {
    match stmt {
      ImportDeclaration(import_decl) => imports.push(import_decl)
      ImportEqualsDeclaration(import_equals) =>
        // Convert ImportEqualsDeclaration to ImportDeclaration format
        // import x = require("module") -> extract "module" as module_specifier
        match import_equals.module_reference {
          ExternalModuleReference(module_specifier, loc) => {
            // Create an ImportDeclaration with the name as default import
            let import_clause = ImportClause::{
              name: Some(import_equals.name),
              named_bindings: None,
              location: loc,
            }
            let import_decl = ImportDeclaration::{
              import_clause: Some(import_clause),
              module_specifier,
              is_type_only: import_equals.is_type_only,
              location: import_equals.location,
            }
            imports.push(import_decl)
          }
          EntityName(_) =>
            // import x = M.N - namespace import, not a module import
            // Skip these as they reference other namespaces, not modules
            ()
        }
      VariableStatement(var_stmt) =>
        // Check for CommonJS: const x = require("module")
        for decl in var_stmt.declarations {
          match decl.initializer {
            Some(init) => {
              // Extract variable name from the name node
              let var_name = match decl.name {
                Identifier(id) => id.name
                _ => "" // Binding patterns like { a, b } = require(...) - use empty name
              }
              extract_require_import(init, var_name, imports)
            }
            None => ()
          }
        }
      ExpressionStatement(expr_stmt) =>
        // Check for side-effect require: require("module")
        extract_require_import(expr_stmt.expression, "", imports)
      _ => ()
    }
  }
  imports
}

///|
/// Extract require() calls and convert to ImportDeclaration
fn extract_require_import(
  expr : Node,
  var_name : String,
  imports : Array[ImportDeclaration],
) -> Unit {
  match expr {
    CallExpression(call) =>
      // Check if callee is "require"
      match call.expression {
        Identifier(id) if id.name == "require" =>
          // Extract module specifier from first argument
          if call.arguments.length() > 0 {
            match call.arguments[0] {
              StringLiteral(lit) => {
                let loc = call.location
                let import_clause : ImportClause? = if var_name.length() > 0 {
                  Some(ImportClause::{
                    name: Some(var_name),
                    named_bindings: None,
                    location: loc,
                  })
                } else {
                  None
                }
                let import_decl = ImportDeclaration::{
                  import_clause,
                  module_specifier: lit.value,
                  is_type_only: false,
                  location: loc,
                }
                imports.push(import_decl)
              }
              _ => ()
            }
          }
        _ => ()
      }
    _ => ()
  }
}

///|
/// Analyze a statement for module format indicators
fn analyze_statement_for_module_format(
  stmt : Node,
  info : ModuleFormatInfo,
) -> Unit {
  match stmt {
    ImportDeclaration(_) => info.has_esm_imports = true
    ExportDeclaration(_) | ExportAssignment(_) => info.has_esm_exports = true
    ModuleDeclaration(_) =>
      // Ambient module - check for declare module
      info.format = Ambient
    ExpressionStatement(es) =>
      // Check for CommonJS patterns
      analyze_expression_for_cjs(es.expression, info)
    VariableStatement(vs) =>
      // Check for const x = require('...')
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) => analyze_expression_for_cjs(init, info)
          None => ()
        }
      }
    _ => ()
  }
}

///|
/// Analyze an expression for CommonJS patterns
fn analyze_expression_for_cjs(expr : Node, info : ModuleFormatInfo) -> Unit {
  match expr {
    // require('module')
    CallExpression(ce) =>
      match ce.expression {
        Identifier(id) if id.name == "require" => info.has_cjs_require = true
        _ => ()
      }
    // module.exports = ... or exports.x = ...
    BinaryExpression(be) =>
      if is_cjs_export_pattern(be.left) {
        info.has_cjs_exports = true
      }
    // await at top level
    AwaitExpression(_) => info.has_top_level_await = true
    _ => ()
  }
}

///|
/// Check if expression is a CommonJS export pattern
fn is_cjs_export_pattern(expr : Node) -> Bool {
  match expr {
    PropertyAccessExpression(pae) =>
      match pae.expression {
        Identifier(id) => id.name == "module" || id.name == "exports"
        _ => false
      }
    Identifier(id) => id.name == "exports"
    _ => false
  }
}

///|
/// Determine module format from detection flags
fn determine_format(info : ModuleFormatInfo) -> ModuleFormat {
  if info.has_esm_imports || info.has_esm_exports || info.has_top_level_await {
    ESM
  } else if info.has_cjs_require || info.has_cjs_exports {
    CJS
  } else {
    Script
  }
}

///|
/// Get file extension from path
pub fn get_file_extension(path : String) -> String {
  let chars : Array[Char] = path.to_array()
  let mut last_dot = -1
  let mut last_slash = -1
  for i = 0; i < chars.length(); i = i + 1 {
    if chars[i] == '.' {
      last_dot = i
    }
    if chars[i] == '/' || chars[i] == '\\' {
      last_slash = i
    }
  }
  if last_dot > last_slash && last_dot >= 0 {
    let result : Array[Char] = []
    for i = last_dot; i < chars.length(); i = i + 1 {
      result.push(chars[i])
    }
    String::from_array(result)
  } else {
    ""
  }
}

// ============================================================================
// Module Kind Conversion
// ============================================================================

///|
/// Convert ESM import to CommonJS require
pub fn convert_esm_import_to_cjs(
  import_decl : ImportDeclaration,
) -> Array[String] {
  let statements : Array[String] = []
  let module_path = import_decl.module_specifier
  match import_decl.import_clause {
    Some(clause) => {
      // Handle default import: import x from 'mod' -> const x = require('mod').default
      match clause.name {
        Some(default_name) =>
          statements.push(
            "const " +
            default_name +
            " = require('" +
            module_path +
            "').default;",
          )
        None => ()
      }

      // Handle named imports: import { a, b } from 'mod' -> const { a, b } = require('mod')
      match clause.named_bindings {
        Some(NamedImports::NamedImports(specifiers, _)) => {
          let names : Array[String] = []
          for spec in specifiers {
            match spec.property_name {
              Some(orig) => names.push(orig + ": " + spec.name)
              None => names.push(spec.name)
            }
          }
          if names.length() > 0 {
            statements.push(
              "const { " +
              names.join(", ") +
              " } = require('" +
              module_path +
              "');",
            )
          }
        }
        Some(NamespaceImport(ns_name, _)) =>
          // import * as ns from 'mod' -> const ns = require('mod')
          statements.push(
            "const " + ns_name + " = require('" + module_path + "');",
          )
        None => ()
      }
    }
    None =>
      // Side-effect import: import 'mod' -> require('mod')
      statements.push("require('" + module_path + "');")
  }
  statements
}

///|
/// Convert CommonJS require to ESM import
pub fn convert_cjs_require_to_esm(
  var_name : String,
  module_path : String,
  is_default? : Bool = false,
) -> String {
  if is_default {
    "import " + var_name + " from '" + module_path + "';"
  } else {
    "import * as " + var_name + " from '" + module_path + "';"
  }
}

///|
/// Convert ESM export to CommonJS exports
pub fn convert_esm_export_to_cjs(
  export_name : String,
  local_name : String,
  is_default? : Bool = false,
) -> String {
  if is_default {
    "module.exports = " + local_name + ";"
  } else {
    "exports." + export_name + " = " + local_name + ";"
  }
}

// ============================================================================
// Type-Only Import/Export Enforcement
// ============================================================================

///|
/// Type-only import/export validation result
pub struct TypeOnlyValidation {
  errors : Array[Diagnostic]
  warnings : Array[Diagnostic]
}

///|
/// Validate type-only imports and exports
/// Enforces that:
/// 1. Type-only imports cannot be used as values
/// 2. Type-only exports cannot export values
/// 3. With verbatimModuleSyntax, types must use type-only syntax
pub fn validate_type_only_semantics(
  bound_source : BoundSourceFile,
  file_path : String,
  type_symbols : Map[String, Bool],
) -> TypeOnlyValidation {
  let errors : Array[Diagnostic] = []
  let warnings : Array[Diagnostic] = []

  // Track type-only imports
  let type_only_imports : Map[String, Bool] = Map([])

  // First pass: collect type-only imports
  for stmt in bound_source.statements {
    match stmt {
      ImportDeclaration(import_decl) =>
        if import_decl.is_type_only {
          // All imports from this declaration are type-only
          collect_import_names(import_decl, type_only_imports)
        } else {
          // Check individual specifiers
          match import_decl.import_clause {
            Some(clause) =>
              match clause.named_bindings {
                Some(NamedImports::NamedImports(specifiers, _)) =>
                  for spec in specifiers {
                    if spec.is_type_only {
                      type_only_imports.set(spec.name, true)
                    }
                  }
                _ => ()
              }
            None => ()
          }
        }
      _ => ()
    }
  }

  // Second pass: validate usage
  for stmt in bound_source.statements {
    validate_statement_type_only_usage(
      stmt, type_only_imports, type_symbols, file_path, errors,
    )
  }
  { errors, warnings }
}

///|
/// Collect import names from declaration
fn collect_import_names(
  import_decl : ImportDeclaration,
  type_only_imports : Map[String, Bool],
) -> Unit {
  match import_decl.import_clause {
    Some(clause) => {
      match clause.name {
        Some(default_name) => type_only_imports.set(default_name, true)
        None => ()
      }
      match clause.named_bindings {
        Some(NamedImports::NamedImports(specifiers, _)) =>
          for spec in specifiers {
            type_only_imports.set(spec.name, true)
          }
        Some(NamespaceImport(ns_name, _)) =>
          type_only_imports.set(ns_name, true)
        None => ()
      }
    }
    None => ()
  }
}

///|
/// Validate type-only usage in a statement
fn validate_statement_type_only_usage(
  stmt : Node,
  type_only_imports : Map[String, Bool],
  type_symbols : Map[String, Bool],
  file_path : String,
  errors : Array[Diagnostic],
) -> Unit {
  match stmt {
    // Check for type-only imports used as values
    ExpressionStatement(es) =>
      check_expression_type_only_usage(
        es.expression,
        type_only_imports,
        file_path,
        errors,
      )
    VariableStatement(vs) =>
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) =>
            check_expression_type_only_usage(
              init, type_only_imports, file_path, errors,
            )
          None => ()
        }
      }
    // Check for non-type-only exports of types
    ExportDeclaration(export_decl) =>
      if !(export_decl.is_type_only) {
        match export_decl.export_clause {
          Some(NamespaceExport(_, _)) =>
            // Namespace exports (export * as ns from 'mod') are always OK
            ()
          Some(NamedExports::NamedExports(specifiers, _)) =>
            for spec in specifiers {
              if !(spec.is_type_only) {
                let local_name = match spec.property_name {
                  Some(pn) => pn
                  None => spec.name
                }
                // If exporting a type symbol without type-only marker
                if type_symbols.get(local_name).unwrap_or(false) {
                  errors.push(Diagnostic::{
                    code: 1205,
                    category: DiagnosticCategory::Error,
                    message: "Re-exporting a type when the '--isolatedModules' flag is provided requires using 'export type'.",
                    location: SourceLocation::{
                      file_path,
                      start: Position::{ line: 0, column: 0, offset: 0 },
                      end: Position::{ line: 0, column: 0, offset: 0 },
                    },
                  })
                }
              }
            }
          None => ()
        }
      }
    _ => ()
  }
}

///|
/// Check expression for type-only import used as value
fn check_expression_type_only_usage(
  expr : Node,
  type_only_imports : Map[String, Bool],
  file_path : String,
  errors : Array[Diagnostic],
) -> Unit {
  match expr {
    Identifier(id) =>
      if type_only_imports.get(id.name).unwrap_or(false) {
        errors.push(Diagnostic::{
          code: 1361,
          category: DiagnosticCategory::Error,
          message: "'" +
          id.name +
          "' cannot be used as a value because it was imported using 'import type'.",
          location: id.location,
        })
      }
    CallExpression(ce) => {
      check_expression_type_only_usage(
        ce.expression,
        type_only_imports,
        file_path,
        errors,
      )
      for arg in ce.arguments {
        check_expression_type_only_usage(
          arg, type_only_imports, file_path, errors,
        )
      }
    }
    PropertyAccessExpression(pae) =>
      check_expression_type_only_usage(
        pae.expression,
        type_only_imports,
        file_path,
        errors,
      )
    BinaryExpression(be) => {
      check_expression_type_only_usage(
        be.left,
        type_only_imports,
        file_path,
        errors,
      )
      check_expression_type_only_usage(
        be.right,
        type_only_imports,
        file_path,
        errors,
      )
    }
    NewExpression(ne) => {
      check_expression_type_only_usage(
        ne.expression,
        type_only_imports,
        file_path,
        errors,
      )
      match ne.arguments {
        Some(args) =>
          for arg in args {
            check_expression_type_only_usage(
              arg, type_only_imports, file_path, errors,
            )
          }
        None => ()
      }
    }
    _ => ()
  }
}

// ============================================================================
// File System Interface
// ============================================================================

///|
/// File system interface for module resolution
pub struct FileSystemInterface {
  /// Check if a file exists
  file_exists : (String) -> Bool
  /// Read file contents
  read_file : (String) -> String?
  /// Get directory entries
  read_directory : (String) -> Array[String]
  /// Check if path is directory
  is_directory : (String) -> Bool
  /// Get current working directory
  get_current_directory : () -> String
}

///|
/// Create a placeholder file system (for testing/compilation)
pub fn FileSystemInterface::placeholder() -> FileSystemInterface {
  {
    file_exists: fn(_path : String) -> Bool { false },
    read_file: fn(_path : String) -> String? { None },
    read_directory: fn(_path : String) -> Array[String] { [] },
    is_directory: fn(_path : String) -> Bool { false },
    get_current_directory: fn() -> String { "/" },
  }
}

///|
/// File system interface that can be set up externally
/// This is the integration point for actual FS access
pub struct ModuleResolutionHost {
  /// File system interface
  fs : FileSystemInterface
  /// Cached file existence checks
  file_cache : Map[String, Bool]
  /// Cached directory contents
  dir_cache : Map[String, Array[String]]
}

///|
/// Create module resolution host with file system
pub fn ModuleResolutionHost::new(
  fs : FileSystemInterface,
) -> ModuleResolutionHost {
  { fs, file_cache: Map([]), dir_cache: Map([]) }
}

///|
/// Create with placeholder file system
pub fn ModuleResolutionHost::placeholder() -> ModuleResolutionHost {
  ModuleResolutionHost::new(FileSystemInterface::placeholder())
}

///|
/// Check if file exists (with caching)
pub fn ModuleResolutionHost::file_exists(
  self : ModuleResolutionHost,
  path : String,
) -> Bool {
  match self.file_cache.get(path) {
    Some(exists) => exists
    None => {
      let exists = (self.fs.file_exists)(path)
      self.file_cache.set(path, exists)
      exists
    }
  }
}

///|
/// Read file contents
pub fn ModuleResolutionHost::read_file(
  self : ModuleResolutionHost,
  path : String,
) -> String? {
  (self.fs.read_file)(path)
}

///|
/// Get directory contents (with caching)
pub fn ModuleResolutionHost::get_directory_contents(
  self : ModuleResolutionHost,
  path : String,
) -> Array[String] {
  match self.dir_cache.get(path) {
    Some(contents) => contents
    None => {
      let contents = (self.fs.read_directory)(path)
      self.dir_cache.set(path, contents)
      contents
    }
  }
}

///|
/// Clear caches
pub fn ModuleResolutionHost::clear_cache(self : ModuleResolutionHost) -> Unit {
  // Clear by creating new maps
  self.file_cache.each(fn(k, _v) { self.file_cache.remove(k) })
  self.dir_cache.each(fn(k, _v) { self.dir_cache.remove(k) })
}

// ============================================================================
// Binder/Checker Integration
// ============================================================================

///|
/// Module resolution context for checker integration
pub struct ModuleResolutionContext {
  /// Module symbol resolver
  symbol_resolver : ModuleSymbolResolver
  /// Resolution host
  host : ModuleResolutionHost
  /// Module format info per file
  format_info : Map[String, ModuleFormatInfo]
  /// Type-only import tracking per file
  type_only_imports : Map[String, Map[String, Bool]]
}

///|
/// Create module resolution context
pub fn ModuleResolutionContext::new(
  symbol_resolver : ModuleSymbolResolver,
  host : ModuleResolutionHost,
) -> ModuleResolutionContext {
  {
    symbol_resolver,
    host,
    format_info: Map([]),
    type_only_imports: Map([]),
  }
}

///|
/// Register file's module format
pub fn ModuleResolutionContext::register_format(
  self : ModuleResolutionContext,
  file_path : String,
  format_info : ModuleFormatInfo,
) -> Unit {
  self.format_info.set(file_path, format_info)
}

///|
/// Get file's module format
pub fn ModuleResolutionContext::get_format(
  self : ModuleResolutionContext,
  file_path : String,
) -> ModuleFormatInfo? {
  self.format_info.get(file_path)
}

///|
/// Register type-only imports for a file
pub fn ModuleResolutionContext::register_type_only_imports(
  self : ModuleResolutionContext,
  file_path : String,
  imports : Map[String, Bool],
) -> Unit {
  self.type_only_imports.set(file_path, imports)
}

///|
/// Check if an import is type-only
pub fn ModuleResolutionContext::is_type_only_import(
  self : ModuleResolutionContext,
  file_path : String,
  name : String,
) -> Bool {
  match self.type_only_imports.get(file_path) {
    Some(imports) => imports.get(name).unwrap_or(false)
    None => false
  }
}

///|
/// Resolve import and check module compatibility
pub fn resolve_and_validate_import(
  ctx : ModuleResolutionContext,
  module_specifier : String,
  containing_file : String,
) -> Result[String, Diagnostic] {
  // Resolve the module
  match ctx.symbol_resolver.resolve_import(module_specifier, containing_file) {
    Ok(resolved_path) => {
      // Check module format compatibility
      let source_format = ctx.format_info.get(containing_file)
      let target_format = ctx.format_info.get(resolved_path)
      match (source_format, target_format) {
        (Some(src), Some(tgt)) =>
          // Check for format incompatibilities
          match (src.format, tgt.format) {
            (ESM, CJS) =>
              // ESM can import CJS (with interop)
              Ok(resolved_path)
            (CJS, ESM) =>
              // CJS cannot require ESM directly in Node.js
              // This is allowed in bundlers, but we can warn
              Ok(resolved_path)
            _ => Ok(resolved_path)
          }
        _ => Ok(resolved_path)
      }
    }
    Err(failure) => {
      let message = match failure {
        ModuleNotFound(spec, _) => "Cannot find module '" + spec + "'."
        OutsideRootDir(path) =>
          "Relative import '" + path + "' is outside of project root."
        InvalidSpecifier(spec) => "Invalid module specifier: " + spec
        CircularDependency(chain) =>
          "Circular dependency detected: " + chain.join(" -> ")
        PackageExportsNotFound(pkg, subpath) =>
          "Cannot find subpath '" + subpath + "' in package '" + pkg + "'."
      }
      Err(Diagnostic::{
        code: 2307,
        category: DiagnosticCategory::Error,
        message,
        location: SourceLocation::{
          file_path: containing_file,
          start: Position::{ line: 0, column: 0, offset: 0 },
          end: Position::{ line: 0, column: 0, offset: 0 },
        },
      })
    }
  }
}

// ============================================================================
// Multi-File Import Validation
// ============================================================================

///|
/// A relative import that did not resolve within the compiled file set.
/// `candidates` lists every path the resolver searched, so a caller with
/// real filesystem access (the CLI) can check whether the import target
/// exists on disk (e.g. an untyped .js file) before reporting TS2307.
pub(all) struct UnresolvedRelativeImport {
  file_path : String
  specifier : String
  location : SourceLocation
  candidates : Array[String]
  /// Effective noImplicitAny for the importing file (drives TS7016 when the
  /// import resolves to an untyped .js file on disk)
  no_implicit_any : Bool
} derive(Debug)

///|
/// A non-relative (bare/rooted) import that resolved within the compiled
/// file set or matched an ambient `declare module "..."` declaration.
/// The per-file checker emits an unconditional TS2307 for these sites, so
/// the caller should suppress that diagnostic.
pub(all) struct ResolvedBareImport {
  file_path : String
  specifier : String
  location : SourceLocation
  /// Path the specifier resolved to within the file set; None when the
  /// specifier matched an ambient module declaration instead
  resolved_path : String?
  /// Effective noImplicitAny for the importing file
  no_implicit_any : Bool
} derive(Debug)

///|
/// A non-relative (bare/rooted) import that resolved to nothing in the
/// compiled file set and matched no ambient module declaration. The caller
/// (CLI) should attempt real-filesystem node_modules resolution before
/// deciding between suppressing, TS7016, or keeping/adding TS2307.
pub(all) struct UnresolvedBareImport {
  file_path : String
  specifier : String
  location : SourceLocation
  /// Whether the per-file checker already reports TS2307 at this site
  /// (true for `import ... from "x"`; false for `import x = require("x")`
  /// and `export ... from "x"`, which the checker does not diagnose)
  checker_reports : Bool
  /// Effective noImplicitAny for the importing file
  no_implicit_any : Bool
  /// Whether the site has require semantics (`import x = require(...)`),
  /// which under node16 yields TS1471 when the target is an ES module
  require_like : Bool
  /// Type-only import (`import type ...`): exempt from TS1479/TS1471
  type_only : Bool
  /// Whether the importing file is ESM-format (selects the node16
  /// "import"/"require" resolution conditions; TS1479 applies to CJS)
  importer_esm : Bool
} derive(Debug)

///|
/// Result of validating imports across a multi-file compilation
pub(all) struct MultiFileImportValidation {
  /// Definite cross-file diagnostics (TS2305/TS2306/TS2724/TS1192)
  diagnostics : Array[Diagnostic]
  /// Relative imports that resolved to nothing in the compiled file set;
  /// candidates should be checked against the real filesystem before
  /// emitting TS2307
  unresolved : Array[UnresolvedRelativeImport]
  /// Non-relative imports that resolved in the file set (or via an ambient
  /// module declaration); the checker's TS2307 for them should be suppressed
  resolved_bare : Array[ResolvedBareImport]
  /// Non-relative imports that did not resolve in the file set; check the
  /// real filesystem (node_modules) before deciding on TS2307/TS7016
  unresolved_bare : Array[UnresolvedBareImport]
  /// (declaring_file, name) pairs for value names declared inside
  /// `declare global { ... }` blocks in the file set: the per-file checker
  /// cannot see cross-file global augmentations, so its TS2304 for these
  /// names should be suppressed (callers may restrict which declaring files
  /// count, e.g. node_modules files only when actually imported/referenced)
  global_value_names : Array[(String, String)]
} derive(Debug)

///|
/// Check whether a module specifier is a relative path (./a, ../b)
fn is_relative_specifier(spec : String) -> Bool {
  spec.has_prefix("./") || spec.has_prefix("../") || spec == "." || spec == ".."
}

///|
/// Check whether the per-file checker reports TS2307 for this specifier form
/// (check_import_declaration only treats "./" and "../" prefixes as relative)
fn checker_treats_as_relative(spec : String) -> Bool {
  spec.has_prefix("./") || spec.has_prefix("../")
}

///|
/// Collect the names of ambient module declarations
/// (`declare module "name" { ... }` / `declare module "name";`)
/// from the top level of a parsed source file.
pub fn collect_ambient_module_names(sf : SourceFile) -> Array[String] {
  let names : Array[String] = []
  for stmt in sf.statements {
    match stmt {
      Node::ModuleDeclaration(md) => if md.is_ambient { names.push(md.name) }
      _ => ()
    }
  }
  names
}

///|
/// Check whether a specifier matches any ambient module declaration name.
/// Names may contain a single `*` wildcard (e.g. `declare module "foo*"`).
pub fn matches_ambient_module(
  ambient_names : Array[String],
  specifier : String,
) -> Bool {
  for name in ambient_names {
    if name == specifier {
      return true
    }
    if name.contains("*") && match_pattern(name, specifier) is Some(_) {
      return true
    }
  }
  false
}

///|
/// Collect value names (var/let/const, function, class) declared inside
/// `declare global { ... }` blocks at the top level of a source file
pub fn collect_global_augmentation_value_names(
  sf : SourceFile,
) -> Array[String] {
  let names : Array[String] = []
  fn collect_from(stmts : Array[Node]) -> Unit {
    for stmt in stmts {
      match stmt {
        Node::VariableStatement(vs) =>
          for decl in vs.declarations {
            match decl.name {
              Node::Identifier(id) => names.push(id.name)
              _ => ()
            }
          }
        Node::FunctionDeclaration(fd) =>
          match fd.name {
            Some(Node::Identifier(id)) => names.push(id.name)
            _ => ()
          }
        Node::ClassDeclaration(cd) =>
          match cd.name {
            Some(Node::Identifier(id)) => names.push(id.name)
            _ => ()
          }
        _ => ()
      }
    }
  }

  for stmt in sf.statements {
    match stmt {
      Node::ModuleDeclaration(md) =>
        if md.is_global_augmentation {
          match md.body {
            Some(Node::BlockStatement(block)) => collect_from(block.statements)
            _ => ()
          }
        }
      _ => ()
    }
  }
  names
}

///|
/// Find an `import.meta` meta-property in an expression tree (common
/// expression forms; used for TS1470 in CJS-format files under node16)
fn expr_import_meta_location(expr : Node) -> SourceLocation? {
  match expr {
    Node::MetaProperty(mp) =>
      match mp.keyword_kind {
        ImportMeta => Some(mp.location)
        _ => None
      }
    Node::PropertyAccessExpression(pae) =>
      expr_import_meta_location(pae.expression)
    Node::CallExpression(ce) => {
      match expr_import_meta_location(ce.expression) {
        Some(loc) => return Some(loc)
        None => ()
      }
      for arg in ce.arguments {
        match expr_import_meta_location(arg) {
          Some(loc) => return Some(loc)
          None => ()
        }
      }
      None
    }
    Node::BinaryExpression(be) =>
      match expr_import_meta_location(be.left) {
        Some(loc) => Some(loc)
        None => expr_import_meta_location(be.right)
      }
    _ => None
  }
}

///|
/// Find the first `import.meta` occurrence in a file's top-level statements
fn find_import_meta_location(statements : Array[Node]) -> SourceLocation? {
  for stmt in statements {
    match stmt {
      Node::ExpressionStatement(es) =>
        match expr_import_meta_location(es.expression) {
          Some(loc) => return Some(loc)
          None => ()
        }
      Node::VariableStatement(vs) =>
        for decl in vs.declarations {
          match decl.initializer {
            Some(init) =>
              match expr_import_meta_location(init) {
                Some(loc) => return Some(loc)
                None => ()
              }
            None => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
/// Validate relative imports across a set of real files compiled together.
/// Resolves each relative specifier against the file set (with .ts/.tsx/.d.ts
/// extension and directory-index resolution) and validates imported members
/// against the target module's exports.
///
/// Returns member-mismatch diagnostics plus the list of unresolved relative
/// imports (see UnresolvedRelativeImport for how callers should handle them).
pub fn validate_multi_file_imports(
  files : Array[(String, String)], // (file_path, source) pairs
  node16? : Bool = false,
  cjs_require_esm_errors? : Bool = true,
  file_formats? : Map[String, ModuleFormat] = Map([]),
) -> MultiFileImportValidation {
  let diagnostics : Array[Diagnostic] = []
  let unresolved : Array[UnresolvedRelativeImport] = []
  let resolved_bare : Array[ResolvedBareImport] = []
  let unresolved_bare : Array[UnresolvedBareImport] = []
  let file_paths : Array[String] = []
  for f in files {
    file_paths.push(f.0)
  }
  let resolver = ModuleResolver::with_file_set(file_paths, ".")

  // Per-file CJS/ESM format (node16 mode): caller-provided map (normalized
  // here), falling back to extension-based classification with Node's CJS
  // default for .ts/.js files
  let formats_normalized : Map[String, ModuleFormat] = Map([])
  for entry in file_formats {
    formats_normalized.set(normalize_path(entry.0), entry.1)
  }
  fn format_of(path : String) -> ModuleFormat {
    match formats_normalized.get(normalize_path(path)) {
      Some(f) => f
      None =>
        if path.has_suffix(".mts") || path.has_suffix(".mjs") {
          ESM
        } else if path.has_suffix(".cts") || path.has_suffix(".cjs") {
          CJS
        } else {
          CJS
        }
    }
  }

  fn is_esm_file(path : String) -> Bool {
    format_of(path) == ESM
  }

  // Parse and bind every file; collect exports keyed by normalized path,
  // ambient module declarations, and the per-file effective noImplicitAny
  let exports_by_path : Map[String, ResolvedModuleExports] = Map([])
  let parsed_files : Array[(String, SourceFile)] = []
  let ambient_module_names : Array[String] = []
  let global_value_names : Array[(String, String)] = []
  let nia_by_path : Map[String, Bool] = Map([])
  for f in files {
    let (path, source) = f
    let tokens = scan_all_v2(source, path)
    match parse_source_file(tokens, path) {
      Ok(sf) => {
        parsed_files.push((path, sf))
        for name in collect_ambient_module_names(sf) {
          ambient_module_names.push(name)
        }
        for name in collect_global_augmentation_value_names(sf) {
          global_value_names.push((path, name))
        }
        // TS7016 (untyped module) only applies under noImplicitAny and
        // when allowJs is off: with allowJs the .js file joins the
        // compilation and provides (loosely) inferred types
        nia_by_path.set(
          path,
          effective_no_implicit_any(sf.compiler_directives, path) &&
          !(sf.compiler_directives.allow_js),
        )
        // Files with parse errors have unreliable export lists (e.g. an
        // unsupported syntax form dropping `export =`): skip member
        // validation against them rather than reporting false TS2305/TS2306
        let has_parse_errors = sf.parse_diagnostics
          .iter()
          .any(fn(d) { d.category == DiagnosticCategory::Error })
        if !(has_parse_errors) {
          match bind_source_file(sf) {
            Ok(bound) =>
              exports_by_path.set(
                normalize_path(path),
                ResolvedModuleExports::from_bound_file(bound, path),
              )
            Err(_) => ()
          }
        }
      }
      Err(_) => ()
    }
  }
  fn nia_for(path : String) -> Bool {
    nia_by_path.get(path).unwrap_or(false)
  }

  // Expand star re-exports (`export * from './x'` / `export type * from`):
  // the re-exporting module exposes every named export of its source module
  // (but not the default export). Runs to a fixpoint so chains of star
  // re-exports propagate; the iteration cap guards against cycles.
  let mut changed = true
  let mut iterations = 0
  while changed && iterations < 16 {
    changed = false
    iterations = iterations + 1
    for entry in parsed_files {
      let (path, sf) = entry
      match exports_by_path.get(normalize_path(path)) {
        Some(target_exports) =>
          for stmt in sf.statements {
            match stmt {
              Node::ExportDeclaration(ed) =>
                match (ed.export_clause, ed.module_specifier) {
                  (None, Some(spec)) =>
                    if is_relative_specifier(spec) {
                      match resolver.resolve_module_name(spec, path) {
                        Ok(resolved) =>
                          match
                            exports_by_path.get(
                              normalize_path(resolved.resolved_file_name),
                            ) {
                            Some(source_exports) =>
                              for name in source_exports.exports.iter() {
                                if !(target_exports.exports.contains(name)) {
                                  target_exports.exports.add(name)
                                  changed = true
                                }
                              }
                            None => ()
                          }
                        Err(_) => ()
                      }
                    }
                  _ => ()
                }
              _ => ()
            }
          }
        None => ()
      }
    }
  }

  // Record an unresolved relative import (deferred TS2307 decision)
  fn record_unresolved(
    path : String,
    spec : String,
    location : SourceLocation,
    failure : ResolutionFailure,
  ) -> Unit {
    let candidates = match failure {
      ModuleNotFound(_, searched) => searched
      _ => []
    }
    unresolved.push(UnresolvedRelativeImport::{
      file_path: path,
      specifier: spec,
      location,
      candidates,
      no_implicit_any: nia_for(path),
    })
  }

  // Handle a non-relative (bare/rooted) specifier: ambient module match,
  // then file-set resolution; otherwise defer to the caller's filesystem
  // lookup. Returns the resolved file-set path (if any) so import
  // declarations can validate members against it.
  //
  // Under node16, genuinely bare specifiers skip file-set resolution
  // entirely: package.json `exports` gates what a package exposes, and only
  // the caller (with filesystem access) can evaluate that. Rooted specifiers
  // keep the file-set path.
  fn handle_bare_specifier(
    path : String,
    spec : String,
    location : SourceLocation,
    checker_reports : Bool,
    require_like : Bool,
    type_only : Bool,
  ) -> String? {
    fn defer_to_caller() -> Unit {
      unresolved_bare.push(UnresolvedBareImport::{
        file_path: path,
        specifier: spec,
        location,
        checker_reports,
        no_implicit_any: nia_for(path),
        require_like,
        type_only,
        importer_esm: is_esm_file(path),
      })
    }

    if matches_ambient_module(ambient_module_names, spec) {
      resolved_bare.push(ResolvedBareImport::{
        file_path: path,
        specifier: spec,
        location,
        resolved_path: None,
        no_implicit_any: nia_for(path),
      })
      return None
    }
    if node16 && !(spec.has_prefix("/")) {
      defer_to_caller()
      return None
    }
    match resolver.resolve_module_name(spec, path) {
      Ok(resolved) => {
        resolved_bare.push(ResolvedBareImport::{
          file_path: path,
          specifier: spec,
          location,
          resolved_path: Some(resolved.resolved_file_name),
          no_implicit_any: nia_for(path),
        })
        Some(resolved.resolved_file_name)
      }
      Err(_) => {
        defer_to_caller()
        None
      }
    }
  }

  // node16: literal (extensioned) relative resolution for ESM-format
  // importers — no extension adding, no directory-index lookup. Emits
  // TS2835/TS2834/TS2307 for extensionless/directory/root specifiers.
  // Returns the resolved path when the literal lookup succeeded.
  fn node16_esm_relative(
    path : String,
    spec : String,
    location : SourceLocation,
  ) -> String? {
    // Bare "./"/"../" (and "."/"..", which the checker already reports as
    // TS2307): never resolvable in ESM
    if spec == "./" || spec == "../" {
      diagnostics.push(
        create_module_not_found_diagnostic_with_location(spec, location),
      )
      return None
    }
    if spec == "." || spec == ".." {
      return None // checker's bare-specifier TS2307 covers these
    }
    let containing_dir = get_directory_path(path)
    let base = normalize_path(join_paths(containing_dir, spec))
    let ext = get_extension(spec)
    if !(ext.is_empty()) {
      // Literal lookup with JS-output -> TS-source substitution
      let candidates : Array[String] = [base]
      let stem = base[:base.length() - ext.length()].to_owned()
      if ext == ".js" {
        candidates.push(stem + ".ts")
        candidates.push(stem + ".tsx")
        candidates.push(stem + ".d.ts")
      } else if ext == ".jsx" {
        candidates.push(stem + ".tsx")
      } else if ext == ".mjs" {
        candidates.push(stem + ".mts")
        candidates.push(stem + ".d.mts")
      } else if ext == ".cjs" {
        candidates.push(stem + ".cts")
        candidates.push(stem + ".d.cts")
      }
      for c in candidates {
        if resolver.file_exists(c) {
          return Some(c)
        }
      }
      unresolved.push(UnresolvedRelativeImport::{
        file_path: path,
        specifier: spec,
        location,
        candidates,
        no_implicit_any: nia_for(path),
      })
      return None
    }
    // Extensionless: adding an extension would have resolved it -> TS2835
    let ts_exts = [".mts", ".cts", ".ts", ".tsx", ".d.mts", ".d.cts", ".d.ts"]
    if !(spec.has_suffix("/")) {
      for e in ts_exts {
        if resolver.file_exists(base + e) {
          let out_ext = if e == ".mts" || e == ".d.mts" {
            ".mjs"
          } else if e == ".cts" || e == ".d.cts" {
            ".cjs"
          } else {
            ".js"
          }
          diagnostics.push(
            create_esm_needs_extension_diagnostic(Some(spec + out_ext), location),
          )
          return None
        }
      }
    }
    // Directory with an index file -> TS2834 (ESM has no index resolution)
    for e in ts_exts {
      if resolver.file_exists(join_paths(base, "index" + e)) {
        diagnostics.push(create_esm_needs_extension_diagnostic(None, location))
        return None
      }
    }
    // Nothing in the file set: defer to the caller's on-disk check (TS2307)
    unresolved.push(UnresolvedRelativeImport::{
      file_path: path,
      specifier: spec,
      location,
      candidates: [],
      no_implicit_any: nia_for(path),
    })
    None
  }

  // node16: relative resolution with require semantics (CJS importers'
  // static imports, and import= / require() in any file): full extension +
  // index resolution, but resolutions landing on an ES module are errors.
  // `require_like` selects TS1471 (require constructs) vs TS1479 (static
  // imports in CJS files).
  fn node16_cjs_relative(
    path : String,
    spec : String,
    location : SourceLocation,
    require_like : Bool,
    type_only : Bool,
  ) -> String? {
    match resolver.resolve_module_name(spec, path) {
      Ok(resolved) => {
        let target = resolved.resolved_file_name
        // node20/nodenext assume Node.js supports require() of ES modules,
        // so the TS1479/TS1471 interop errors only apply to node16/node18
        if cjs_require_esm_errors && !(type_only) && is_esm_file(target) {
          if require_like {
            diagnostics.push(create_require_of_esm_diagnostic(spec, location))
          } else {
            diagnostics.push(create_cjs_import_of_esm_diagnostic(spec, location))
          }
        }
        Some(target)
      }
      Err(failure) => {
        record_unresolved(path, spec, location, failure)
        None
      }
    }
  }

  // Validate imported members against the target module's exports
  fn validate_members(
    import_decl : ImportDeclaration,
    resolved_path : String,
  ) -> Unit {
    match exports_by_path.get(normalize_path(resolved_path)) {
      Some(module_exports) => {
        // Reuse the checker's single-import validation
        let registry : Map[String, ResolvedModuleExports] = Map([])
        registry.set(import_decl.module_specifier, module_exports)
        // Under node16, a CommonJS-format module imported from ESM always
        // exposes a synthetic default (the module.exports object), so
        // TS1192 does not apply
        let cjs_target = node16 && format_of(resolved_path) == CJS
        for d in validate_import_resolution(import_decl, registry) {
          if cjs_target && d.code == 1192 {
            continue
          }
          diagnostics.push(d)
        }
      }
      // Resolved to a file we didn't compile/bind (e.g. .js):
      // treat as untyped, no member validation
      None => ()
    }
  }
  for entry in parsed_files {
    let (path, sf) = entry

    // All import forms (import, import =, require()) — existence check for
    // relative specifiers. (node16 mode handles each form separately below,
    // since the resolution rules differ per import kind.)
    if !(node16) {
      for import_decl in get_imports(sf) {
        let spec = import_decl.module_specifier
        if !(is_relative_specifier(spec)) {
          continue
        }
        match resolver.resolve_module_name(spec, path) {
          Ok(_) => ()
          Err(failure) => record_unresolved(path, spec, import_decl.location, failure)
        }
      }
    } else {
      // node16: require() calls use CJS resolution; resolving to an ES
      // module is TS1471
      let require_imports : Array[ImportDeclaration] = []
      for stmt in sf.statements {
        match stmt {
          Node::VariableStatement(vs) =>
            for decl in vs.declarations {
              match decl.initializer {
                Some(init) => extract_require_import(init, "", require_imports)
                None => ()
              }
            }
          Node::ExpressionStatement(es) =>
            extract_require_import(es.expression, "", require_imports)
          _ => ()
        }
      }
      for r in require_imports {
        if is_relative_specifier(r.module_specifier) {
          let _ = node16_cjs_relative(
            path, r.module_specifier, r.location, true, false,
          )

        }
      }
      // TS1470: import.meta is not allowed in CJS-format files
      if format_of(path) == CJS {
        match find_import_meta_location(sf.statements) {
          Some(loc) =>
            diagnostics.push(Diagnostic::{
              category: DiagnosticCategory::Error,
              code: 1470,
              message: "The 'import.meta' meta-property is not allowed in files which will build into CommonJS output.",
              location: loc,
            })
          None => ()
        }
      }
    }
    for stmt in sf.statements {
      match stmt {
        // Genuine ES import declarations — validate imported members.
        // (import x = require(...) intentionally excluded: it binds the
        // whole module, not the default export.)
        Node::ImportDeclaration(import_decl) => {
          let spec = import_decl.module_specifier
          if is_relative_specifier(spec) {
            if node16 {
              // ESM importers need explicit extensions; CJS importers get
              // extension/index resolution but may not import ES modules
              let resolved_target = if is_esm_file(path) {
                node16_esm_relative(path, spec, import_decl.location)
              } else {
                node16_cjs_relative(
                  path,
                  spec,
                  import_decl.location,
                  false,
                  import_decl.is_type_only,
                )
              }
              match resolved_target {
                Some(target) => validate_members(import_decl, target)
                None => ()
              }
            } else {
              match resolver.resolve_module_name(spec, path) {
                Ok(resolved) => {
                  validate_members(import_decl, resolved.resolved_file_name)
                  // "." / ".." resolve relatively here, but the per-file
                  // checker still emits its bare-specifier TS2307 for them —
                  // record the resolution so the caller suppresses it
                  if !(checker_treats_as_relative(spec)) {
                    resolved_bare.push(ResolvedBareImport::{
                      file_path: path,
                      specifier: spec,
                      location: import_decl.location,
                      resolved_path: Some(resolved.resolved_file_name),
                      no_implicit_any: nia_for(path),
                    })
                  }
                }
                Err(_) => () // already recorded above
              }
            }
          } else if !(spec.has_prefix("http://")) &&
            !(spec.has_prefix("https://")) {
            match
              handle_bare_specifier(
                path,
                spec,
                import_decl.location,
                true,
                false,
                import_decl.is_type_only,
              ) {
              Some(resolved_path) => validate_members(import_decl, resolved_path)
              None => ()
            }
          }
        }
        // import x = require("pkg") — existence check; under node16 the
        // require form additionally rejects ES-module targets (TS1471)
        Node::ImportEqualsDeclaration(ied) =>
          match ied.module_reference {
            ExternalModuleReference(spec, _) =>
              if !(is_relative_specifier(spec)) {
                let _ = handle_bare_specifier(
                  path, spec, ied.location, false, true, ied.is_type_only,
                )

              } else if node16 {
                let _ = node16_cjs_relative(
                  path, spec, ied.location, true, ied.is_type_only,
                )

              }
            EntityName(_) => ()
          }
        // export ... from './x' — existence check for the re-export target
        Node::ExportDeclaration(ed) =>
          match ed.module_specifier {
            Some(spec) =>
              if is_relative_specifier(spec) {
                if node16 {
                  if is_esm_file(path) {
                    let _ = node16_esm_relative(path, spec, ed.location)

                  } else {
                    let _ = node16_cjs_relative(
                      path, spec, ed.location, false, ed.is_type_only,
                    )

                  }
                } else {
                  match resolver.resolve_module_name(spec, path) {
                    Ok(_) => ()
                    Err(failure) => record_unresolved(path, spec, ed.location, failure)
                  }
                }
              } else {
                let _ = handle_bare_specifier(
                  path, spec, ed.location, false, false, ed.is_type_only,
                )

              }
            None => ()
          }
        _ => ()
      }
    }
  }
  { diagnostics, unresolved, resolved_bare, unresolved_bare, global_value_names }
}

// ============================================================================
// Package.json Processing
// ============================================================================

///|
/// Package.json field information
pub struct PackageJsonInfo {
  /// Package name
  name : String?
  /// Package version
  version : String?
  /// Main entry point
  main : String?
  /// Module entry point (ESM) - "module" field in package.json
  esm_entry : String?
  /// Types entry point
  types : String?
  /// Exports map
  exports : Map[String, String]
  /// Type field ("module" or "commonjs")
  type_field : String?
}

///|
/// Create empty package.json info
pub fn PackageJsonInfo::empty() -> PackageJsonInfo {
  {
    name: None,
    version: None,
    main: None,
    esm_entry: None,
    types: None,
    exports: Map([]),
    type_field: None,
  }
}

///|
/// Create package.json info with module type
pub fn PackageJsonInfo::with_type(type_field : String) -> PackageJsonInfo {
  {
    name: Some("test"),
    version: None,
    main: None,
    esm_entry: None,
    types: None,
    exports: Map([]),
    type_field: Some(type_field),
  }
}

///|
/// Create package.json info with main and esm entry
pub fn PackageJsonInfo::with_entries(
  main : String,
  esm_entry? : String? = None,
) -> PackageJsonInfo {
  {
    name: Some("test"),
    version: None,
    main: Some(main),
    esm_entry,
    types: None,
    exports: Map([]),
    type_field: None,
  }
}

///|
/// Determine if package uses ESM based on package.json
pub fn PackageJsonInfo::is_esm(self : PackageJsonInfo) -> Bool {
  match self.type_field {
    Some("module") => true
    _ => false
  }
}

///|
/// Get the appropriate entry point for a module format
pub fn PackageJsonInfo::get_entry_point(
  self : PackageJsonInfo,
  format : ModuleFormat,
) -> String? {
  match format {
    ESM =>
      // Prefer esm_entry (module field) for ESM
      match self.esm_entry {
        Some(m) => Some(m)
        None => self.main
      }
    CJS =>
      // Use main field for CJS
      self.main
    _ => self.main
  }
}
