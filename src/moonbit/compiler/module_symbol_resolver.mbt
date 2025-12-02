// Module Symbol Resolver - Cross-file symbol linking for TypeScript imports/exports
// Integrates module resolution with symbol table binding

// ============================================================================
// Module Symbol Table
// ============================================================================

///|
/// Exported symbol information from a module
pub struct ExportedSymbol {
  /// Name as exported (may differ from original name)
  exported_name : String
  /// Original name in the source module
  original_name : String
  /// Symbol ID in the source module
  symbol_id : Int
  /// Whether this is a type-only export
  is_type_only : Bool
  /// Whether this is a re-export from another module
  re_exported_from : String?
} derive(Show)

///|
/// Create a new exported symbol
pub fn ExportedSymbol::new(
  exported_name : String,
  original_name : String,
  symbol_id : Int,
  is_type_only? : Bool = false,
  re_exported_from? : String? = None,
) -> ExportedSymbol {
  { exported_name, original_name, symbol_id, is_type_only, re_exported_from }
}

///|
/// Module export information
pub struct ModuleExports {
  /// Path to the module file
  module_path : String
  /// Named exports: { exportedName -> ExportedSymbol }
  named_exports : Map[String, ExportedSymbol]
  /// Default export (if any)
  default_export : ExportedSymbol?
  /// Whether this module has `export * from` (namespace re-export)
  star_exports : Array[String] // Module paths that are re-exported with *
} derive(Show)

///|
/// Create module exports with a default export
pub fn ModuleExports::with_default(
  module_path : String,
  default_export : ExportedSymbol,
) -> ModuleExports {
  {
    module_path,
    named_exports: Map::new(),
    default_export: Some(default_export),
    star_exports: [],
  }
}

///|
/// Create empty module exports
pub fn ModuleExports::empty(module_path : String) -> ModuleExports {
  {
    module_path,
    named_exports: Map::new(),
    default_export: None,
    star_exports: [],
  }
}

///|
/// Add a named export
pub fn ModuleExports::add_export(
  self : ModuleExports,
  name : String,
  exported_symbol : ExportedSymbol,
) -> Unit {
  self.named_exports.set(name, exported_symbol)
}

///|
/// Get an export by name
pub fn ModuleExports::get_export(
  self : ModuleExports,
  name : String,
) -> ExportedSymbol? {
  self.named_exports.get(name)
}

///|
/// Check if module has a specific export
pub fn ModuleExports::has_export(self : ModuleExports, name : String) -> Bool {
  self.named_exports.get(name) is Some(_)
}

///|
/// Get all export names
pub fn ModuleExports::get_export_names(self : ModuleExports) -> Array[String] {
  let names : Array[String] = []
  self.named_exports.each(fn(name, _symbol) { names.push(name) })
  names
}

// ============================================================================
// Import Binding
// ============================================================================

///|
/// Resolved import binding - links local symbol to imported symbol
pub struct ImportBinding {
  /// Local name used in this file
  local_name : String
  /// Local symbol ID
  local_symbol_id : Int
  /// Source module path (resolved)
  source_module : String
  /// Name in the source module
  imported_name : String
  /// Symbol ID in the source module (if resolved)
  mut resolved_symbol_id : Int?
  /// Whether this is a type-only import
  is_type_only : Bool
  /// Import kind
  kind : ImportBindingKind
} derive(Show)

///|
/// Create a new import binding
pub fn ImportBinding::new(
  local_name : String,
  local_symbol_id : Int,
  source_module : String,
  imported_name : String,
  kind : ImportBindingKind,
  is_type_only? : Bool = false,
) -> ImportBinding {
  {
    local_name,
    local_symbol_id,
    source_module,
    imported_name,
    resolved_symbol_id: None,
    is_type_only,
    kind,
  }
}

///|
/// Kind of import binding
pub enum ImportBindingKind {
  /// Default import: import foo from 'mod'
  DefaultImport
  /// Named import: import { foo } from 'mod'
  NamedImport
  /// Namespace import: import * as ns from 'mod'
  NamespaceImport
} derive(Show, Eq)

///|
/// Get DefaultImport kind
pub fn ImportBindingKind::default_import() -> ImportBindingKind {
  DefaultImport
}

///|
/// Get NamedImport kind
pub fn ImportBindingKind::named_import() -> ImportBindingKind {
  NamedImport
}

///|
/// Get NamespaceImport kind
pub fn ImportBindingKind::namespace_import() -> ImportBindingKind {
  NamespaceImport
}

// ============================================================================
// Module Symbol Resolver
// ============================================================================

///|
/// Module symbol resolver - manages cross-file symbol resolution
pub struct ModuleSymbolResolver {
  /// Module resolver for path resolution
  module_resolver : ModuleResolver
  /// Cached module exports: { modulePath -> ModuleExports }
  module_exports_cache : Map[String, ModuleExports]
  /// Import bindings for each file: { filePath -> Array[ImportBinding] }
  import_bindings : Map[String, Array[ImportBinding]]
  /// Files currently being processed (for circular dependency detection)
  processing_stack : Array[String]
  /// Diagnostics collected during resolution
  diagnostics : Array[Diagnostic]
} derive(Show)

///|
/// Create a new module symbol resolver
pub fn ModuleSymbolResolver::new(
  module_resolver : ModuleResolver,
) -> ModuleSymbolResolver {
  {
    module_resolver,
    module_exports_cache: Map::new(),
    import_bindings: Map::new(),
    processing_stack: [],
    diagnostics: [],
  }
}

///|
/// Create with default module resolver
pub fn ModuleSymbolResolver::with_defaults(
  current_directory : String,
) -> ModuleSymbolResolver {
  let module_resolver = ModuleResolver::with_defaults(current_directory)
  ModuleSymbolResolver::new(module_resolver)
}

///|
/// Register module exports
pub fn ModuleSymbolResolver::register_exports(
  self : ModuleSymbolResolver,
  module_path : String,
  exports : ModuleExports,
) -> Unit {
  self.module_exports_cache.set(module_path, exports)
}

///|
/// Get cached module exports
pub fn ModuleSymbolResolver::get_exports(
  self : ModuleSymbolResolver,
  module_path : String,
) -> ModuleExports? {
  self.module_exports_cache.get(module_path)
}

///|
/// Register an import binding
pub fn ModuleSymbolResolver::add_import_binding(
  self : ModuleSymbolResolver,
  file_path : String,
  binding : ImportBinding,
) -> Unit {
  match self.import_bindings.get(file_path) {
    Some(bindings) => bindings.push(binding)
    None => {
      let bindings : Array[ImportBinding] = [binding]
      self.import_bindings.set(file_path, bindings)
    }
  }
}

///|
/// Get import bindings for a file
pub fn ModuleSymbolResolver::get_import_bindings(
  self : ModuleSymbolResolver,
  file_path : String,
) -> Array[ImportBinding] {
  match self.import_bindings.get(file_path) {
    Some(bindings) => bindings
    None => []
  }
}

// ============================================================================
// Symbol Linking
// ============================================================================

///|
/// Link import bindings to their target exports
pub fn ModuleSymbolResolver::link_imports(
  self : ModuleSymbolResolver,
  file_path : String,
) -> Array[Diagnostic] {
  let diagnostics : Array[Diagnostic] = []
  match self.import_bindings.get(file_path) {
    Some(bindings) =>
      for binding in bindings {
        link_single_import(self, binding, file_path, diagnostics)
      }
    None => ()
  }
  diagnostics
}

///|
/// Link a single import to its target
fn link_single_import(
  resolver : ModuleSymbolResolver,
  binding : ImportBinding,
  containing_file : String,
  diagnostics : Array[Diagnostic],
) -> Unit {
  // Get module exports
  match resolver.module_exports_cache.get(binding.source_module) {
    Some(exports) =>
      match binding.kind {
        DefaultImport =>
          match exports.default_export {
            Some(exp) => binding.resolved_symbol_id = Some(exp.symbol_id)
            None => {
              // No default export
              let diag = create_no_default_export_diagnostic(
                binding.source_module,
                containing_file,
              )
              diagnostics.push(diag)
            }
          }
        NamedImport =>
          match exports.get_export(binding.imported_name) {
            Some(exp) => binding.resolved_symbol_id = Some(exp.symbol_id)
            None => {
              // Export not found
              let diag = create_export_not_found_diagnostic(
                binding.imported_name,
                binding.source_module,
                containing_file,
              )
              diagnostics.push(diag)
            }
          }
        NamespaceImport =>
          // Namespace import doesn't need to resolve to a specific symbol
          // The entire module namespace is the "symbol"
          binding.resolved_symbol_id = Some(-2) // Marker for namespace
      }
    None =>
      // Module not yet processed - this shouldn't happen in proper resolution order
      ()
  }
}

// ============================================================================
// Circular Dependency Detection
// ============================================================================

///|
/// Check if processing a module would create a circular dependency
pub fn ModuleSymbolResolver::would_be_circular(
  self : ModuleSymbolResolver,
  module_path : String,
) -> Bool {
  self.processing_stack.contains(module_path)
}

///|
/// Start processing a module (for circular detection)
pub fn ModuleSymbolResolver::start_processing(
  self : ModuleSymbolResolver,
  module_path : String,
) -> Unit {
  self.processing_stack.push(module_path)
}

///|
/// Finish processing a module
pub fn ModuleSymbolResolver::finish_processing(
  self : ModuleSymbolResolver,
  module_path : String,
) -> Unit {
  // Remove from stack
  let new_stack : Array[String] = []
  for path in self.processing_stack {
    if path != module_path {
      new_stack.push(path)
    }
  }
  // Clear and repopulate
  while self.processing_stack.length() > 0 {
    let _ = self.processing_stack.pop()

  }
  for path in new_stack {
    self.processing_stack.push(path)
  }
}

///|
/// Get the current dependency chain (for error reporting)
pub fn ModuleSymbolResolver::get_dependency_chain(
  self : ModuleSymbolResolver,
) -> Array[String] {
  // Copy the stack
  let chain : Array[String] = []
  for path in self.processing_stack {
    chain.push(path)
  }
  chain
}

// ============================================================================
// Resolve Module Import
// ============================================================================

///|
/// Resolve a module import and return the resolved path
pub fn ModuleSymbolResolver::resolve_import(
  self : ModuleSymbolResolver,
  module_specifier : String,
  containing_file : String,
) -> Result[String, ResolutionFailure] {
  match
    self.module_resolver.resolve_module_name(module_specifier, containing_file) {
    Ok(resolved) => Ok(resolved.resolved_file_name)
    Err(failure) => Err(failure)
  }
}

// ============================================================================
// Re-export Resolution
// ============================================================================

///|
/// Resolve star exports (export * from 'mod')
/// Returns all exports including those from star-exported modules
pub fn ModuleSymbolResolver::resolve_all_exports(
  self : ModuleSymbolResolver,
  module_path : String,
) -> Map[String, ExportedSymbol] {
  let all_exports : Map[String, ExportedSymbol] = Map::new()
  match self.module_exports_cache.get(module_path) {
    Some(exports) => {
      // Add direct exports
      exports.named_exports.each(fn(name, symbol) {
        all_exports.set(name, symbol)
      })

      // Process star exports recursively
      for star_path in exports.star_exports {
        // Resolve the star export path
        match self.module_resolver.resolve_module_name(star_path, module_path) {
          Ok(resolved) => {
            let star_exports_map = self.resolve_all_exports(
              resolved.resolved_file_name,
            )
            star_exports_map.each(fn(name, symbol) {
              // Don't override direct exports
              if all_exports.get(name) is None {
                all_exports.set(name, symbol)
              }
            })
          }
          Err(_) => ()
        }
      }
    }
    None => ()
  }
  all_exports
}

// ============================================================================
// Diagnostic Helpers
// ============================================================================

///|
/// Create diagnostic for missing default export
fn create_no_default_export_diagnostic(
  module_path : String,
  containing_file : String,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 1192, // TS1192: Module has no default export
    message: "Module '" + module_path + "' has no default export.",
    location: SourceLocation::{
      file_path: containing_file,
      start: Position::{ line: 0, column: 0, offset: 0 },
      end: Position::{ line: 0, column: 0, offset: 0 },
    },
  }
}

///|
/// Create diagnostic for export not found
fn create_export_not_found_diagnostic(
  export_name : String,
  module_path : String,
  containing_file : String,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 2305, // TS2305: Module has no exported member
    message: "Module '" +
    module_path +
    "' has no exported member '" +
    export_name +
    "'.",
    location: SourceLocation::{
      file_path: containing_file,
      start: Position::{ line: 0, column: 0, offset: 0 },
      end: Position::{ line: 0, column: 0, offset: 0 },
    },
  }
}

///|
/// Create diagnostic for module not found with location (TS2307)
pub fn create_module_not_found_diagnostic_with_location(
  module_specifier : String,
  location : SourceLocation,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 2307, // TS2307: Cannot find module
    message: "Cannot find module '" + module_specifier + "' or its corresponding type declarations.",
    location,
  }
}

///|
/// Create diagnostic for file is not a module (TS2306)
pub fn create_file_not_module_diagnostic(
  file_path : String,
  location : SourceLocation,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 2306, // TS2306: File is not a module
    message: "File '" + file_path + "' is not a module.",
    location,
  }
}

///|
/// Create diagnostic for module has no exported member with location (TS2305)
pub fn create_export_not_found_diagnostic_with_location(
  export_name : String,
  module_path : String,
  location : SourceLocation,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 2305, // TS2305: Module has no exported member
    message: "Module '" + module_path + "' has no exported member '" + export_name + "'.",
    location,
  }
}

///|
/// Create diagnostic for no default export with location (TS1192)
pub fn create_no_default_export_diagnostic_with_location(
  module_path : String,
  location : SourceLocation,
) -> Diagnostic {
  Diagnostic::{
    category: DiagnosticCategory::Error,
    code: 1192, // TS1192: Module has no default export
    message: "Module '" + module_path + "' has no default export.",
    location,
  }
}
