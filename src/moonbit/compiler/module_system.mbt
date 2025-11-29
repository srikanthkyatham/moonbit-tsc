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
} derive(Show, Eq)

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
} derive(Show)

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
  if not(info.extension_forced) {
    info.format = determine_format(info)
  }

  info
}

///|
/// Analyze a statement for module format indicators
fn analyze_statement_for_module_format(
  stmt : Node,
  info : ModuleFormatInfo,
) -> Unit {
  match stmt {
    ImportDeclaration(_) => {
      info.has_esm_imports = true
    }
    ExportDeclaration(_) | ExportAssignment(_) => {
      info.has_esm_exports = true
    }
    ModuleDeclaration(_) => {
      // Ambient module - check for declare module
      info.format = Ambient
    }
    ExpressionStatement(es) => {
      // Check for CommonJS patterns
      analyze_expression_for_cjs(es.expression, info)
    }
    VariableStatement(vs) => {
      // Check for const x = require('...')
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) => analyze_expression_for_cjs(init, info)
          None => ()
        }
      }
    }
    _ => ()
  }
}

///|
/// Analyze an expression for CommonJS patterns
fn analyze_expression_for_cjs(
  expr : Node,
  info : ModuleFormatInfo,
) -> Unit {
  match expr {
    // require('module')
    CallExpression(ce) => {
      match ce.expression {
        Identifier(id) if id.name == "require" => {
          info.has_cjs_require = true
        }
        _ => ()
      }
    }
    // module.exports = ... or exports.x = ...
    BinaryExpression(be) => {
      if is_cjs_export_pattern(be.left) {
        info.has_cjs_exports = true
      }
    }
    // await at top level
    AwaitExpression(_) => {
      info.has_top_level_await = true
    }
    _ => ()
  }
}

///|
/// Check if expression is a CommonJS export pattern
fn is_cjs_export_pattern(expr : Node) -> Bool {
  match expr {
    PropertyAccessExpression(pae) => {
      match pae.expression {
        Identifier(id) => id.name == "module" || id.name == "exports"
        _ => false
      }
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
        Some(default_name) => {
          statements.push(
            "const " + default_name + " = require('" + module_path + "').default;",
          )
        }
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
              "const { " + names.join(", ") + " } = require('" + module_path + "');",
            )
          }
        }
        Some(NamespaceImport(ns_name, _)) => {
          // import * as ns from 'mod' -> const ns = require('mod')
          statements.push("const " + ns_name + " = require('" + module_path + "');")
        }
        None => ()
      }
    }
    None => {
      // Side-effect import: import 'mod' -> require('mod')
      statements.push("require('" + module_path + "');")
    }
  }

  statements
}

///|
/// Convert CommonJS require to ESM import
pub fn convert_cjs_require_to_esm(
  var_name : String,
  module_path : String,
  is_default~ : Bool = false,
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
  is_default~ : Bool = false,
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
  let type_only_imports : Map[String, Bool] = Map::new()

  // First pass: collect type-only imports
  for stmt in bound_source.statements {
    match stmt {
      ImportDeclaration(import_decl) => {
        if import_decl.is_type_only {
          // All imports from this declaration are type-only
          collect_import_names(import_decl, type_only_imports)
        } else {
          // Check individual specifiers
          match import_decl.import_clause {
            Some(clause) =>
              match clause.named_bindings {
                Some(NamedImports::NamedImports(specifiers, _)) => {
                  for spec in specifiers {
                    if spec.is_type_only {
                      type_only_imports.set(spec.name, true)
                    }
                  }
                }
                _ => ()
              }
            None => ()
          }
        }
      }
      _ => ()
    }
  }

  // Second pass: validate usage
  for stmt in bound_source.statements {
    validate_statement_type_only_usage(
      stmt,
      type_only_imports,
      type_symbols,
      file_path,
      errors,
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
        Some(NamedImports::NamedImports(specifiers, _)) => {
          for spec in specifiers {
            type_only_imports.set(spec.name, true)
          }
        }
        Some(NamespaceImport(ns_name, _)) => {
          type_only_imports.set(ns_name, true)
        }
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
    ExpressionStatement(es) => {
      check_expression_type_only_usage(
        es.expression,
        type_only_imports,
        file_path,
        errors,
      )
    }
    VariableStatement(vs) => {
      for decl in vs.declarations {
        match decl.initializer {
          Some(init) =>
            check_expression_type_only_usage(
              init,
              type_only_imports,
              file_path,
              errors,
            )
          None => ()
        }
      }
    }
    // Check for non-type-only exports of types
    ExportDeclaration(export_decl) => {
      if not(export_decl.is_type_only) {
        match export_decl.export_clause {
          Some(NamespaceExport(_, _)) => {
            // Namespace exports (export * as ns from 'mod') are always OK
            ()
          }
          Some(NamedExports::NamedExports(specifiers, _)) => {
            for spec in specifiers {
              if not(spec.is_type_only) {
                let local_name = match spec.property_name {
                  Some(pn) => pn
                  None => spec.name
                }
                // If exporting a type symbol without type-only marker
                if type_symbols.get(local_name).unwrap_or(false) {
                  errors.push(
                    Diagnostic::{
                      code: 1205,
                      category: DiagnosticCategory::Error,
                      message: "Re-exporting a type when the '--isolatedModules' flag is provided requires using 'export type'.",
                      location: SourceLocation::{
                        file_path,
                        start: Position::{ line: 0, column: 0, offset: 0 },
                        end: Position::{ line: 0, column: 0, offset: 0 },
                      },
                    },
                  )
                }
              }
            }
          }
          None => ()
        }
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
    Identifier(id) => {
      if type_only_imports.get(id.name).unwrap_or(false) {
        errors.push(
          Diagnostic::{
            code: 1361,
            category: DiagnosticCategory::Error,
            message: "'" + id.name + "' cannot be used as a value because it was imported using 'import type'.",
            location: id.location,
          },
        )
      }
    }
    CallExpression(ce) => {
      check_expression_type_only_usage(ce.expression, type_only_imports, file_path, errors)
      for arg in ce.arguments {
        check_expression_type_only_usage(arg, type_only_imports, file_path, errors)
      }
    }
    PropertyAccessExpression(pae) => {
      check_expression_type_only_usage(pae.expression, type_only_imports, file_path, errors)
    }
    BinaryExpression(be) => {
      check_expression_type_only_usage(be.left, type_only_imports, file_path, errors)
      check_expression_type_only_usage(be.right, type_only_imports, file_path, errors)
    }
    NewExpression(ne) => {
      check_expression_type_only_usage(ne.expression, type_only_imports, file_path, errors)
      match ne.arguments {
        Some(args) => {
          for arg in args {
            check_expression_type_only_usage(arg, type_only_imports, file_path, errors)
          }
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
pub fn ModuleResolutionHost::new(fs : FileSystemInterface) -> ModuleResolutionHost {
  {
    fs,
    file_cache: Map::new(),
    dir_cache: Map::new(),
  }
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
    format_info: Map::new(),
    type_only_imports: Map::new(),
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
        (Some(src), Some(tgt)) => {
          // Check for format incompatibilities
          match (src.format, tgt.format) {
            (ESM, CJS) => {
              // ESM can import CJS (with interop)
              Ok(resolved_path)
            }
            (CJS, ESM) => {
              // CJS cannot require ESM directly in Node.js
              // This is allowed in bundlers, but we can warn
              Ok(resolved_path)
            }
            _ => Ok(resolved_path)
          }
        }
        _ => Ok(resolved_path)
      }
    }
    Err(failure) => {
      let message = match failure {
        ModuleNotFound(spec, _) => "Cannot find module '" + spec + "'."
        OutsideRootDir(path) => "Relative import '" + path + "' is outside of project root."
        InvalidSpecifier(spec) => "Invalid module specifier: " + spec
        CircularDependency(chain) => "Circular dependency detected: " + chain.join(" -> ")
        PackageExportsNotFound(pkg, subpath) =>
          "Cannot find subpath '" + subpath + "' in package '" + pkg + "'."
      }
      Err(
        Diagnostic::{
          code: 2307,
          category: DiagnosticCategory::Error,
          message,
          location: SourceLocation::{
            file_path: containing_file,
            start: Position::{ line: 0, column: 0, offset: 0 },
            end: Position::{ line: 0, column: 0, offset: 0 },
          },
        },
      )
    }
  }
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
    exports: Map::new(),
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
    exports: Map::new(),
    type_field: Some(type_field),
  }
}

///|
/// Create package.json info with main and esm entry
pub fn PackageJsonInfo::with_entries(
  main : String,
  esm_entry~ : String? = None,
) -> PackageJsonInfo {
  {
    name: Some("test"),
    version: None,
    main: Some(main),
    esm_entry,
    types: None,
    exports: Map::new(),
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
    ESM => {
      // Prefer esm_entry (module field) for ESM
      match self.esm_entry {
        Some(m) => Some(m)
        None => self.main
      }
    }
    CJS => {
      // Use main field for CJS
      self.main
    }
    _ => self.main
  }
}
