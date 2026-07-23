// Import Extractor - extracts import paths from TypeScript source files
// Uses the existing parser to parse source and extract module specifiers

///|
/// Result of extracting imports from a file
pub struct ImportResult {
  path : String
  imports : Array[String] // Module specifiers (e.g., "./utils", "lodash")
  errors : Array[String]
}

///|
/// Result of extracting imports and references from a file
pub struct ImportAndReferenceResult {
  path : String
  imports : Array[String] // Module specifiers (e.g., "./utils", "lodash")
  references : Array[String] // Reference paths (e.g., "./types.d.ts")
  errors : Array[String]
}

///|
/// Extract imports from TypeScript source code
pub fn extract_imports(source : String, file_path : String) -> ImportResult {
  match @compiler.parse_only(source, file_path) {
    Ok(source_file) => {
      let imports = extract_imports_from_ast(source_file)
      { path: file_path, imports, errors: [] }
    }
    Err(diagnostics) => {
      let errors : Array[String] = []
      for diag in diagnostics {
        errors.push(diag.message)
      }
      { path: file_path, imports: [], errors }
    }
  }
}

///|
/// Extract both imports and triple-slash reference paths from TypeScript source code
pub fn extract_imports_and_references(
  source : String,
  file_path : String,
) -> ImportAndReferenceResult {
  match @compiler.parse_and_bind(source, file_path) {
    Ok(bound_source) => {
      // Extract imports from AST statements. Re-exports
      // (`export ... from './x'`) are dependencies too: the re-exporting
      // module's exports cannot be computed before its source module.
      let imports : Array[String] = []
      for statement in bound_source.statements {
        match statement {
          @compiler.ImportDeclaration(import_decl) =>
            imports.push(import_decl.module_specifier)
          @compiler.ExportDeclaration(export_decl) =>
            match export_decl.module_specifier {
              Some(spec) => imports.push(spec)
              None => ()
            }
          _ => ()
        }
      }

      // Extract reference paths from triple-slash directives
      let references : Array[String] = []
      for directive in bound_source.triple_slash_directives {
        match directive.kind {
          @compiler.ReferencePath(path) => references.push(path)
          _ => () // Ignore other directive types (types, lib, etc.)
        }
      }
      { path: file_path, imports, references, errors: [] }
    }
    Err(diagnostics) => {
      let errors : Array[String] = []
      for diag in diagnostics {
        errors.push(diag.message)
      }
      { path: file_path, imports: [], references: [], errors }
    }
  }
}

///|
/// Extract import module specifiers from a parsed SourceFile
fn extract_imports_from_ast(
  source_file : @compiler.SourceFile,
) -> Array[String] {
  let imports : Array[String] = []
  for statement in source_file.statements {
    match statement {
      @compiler.ImportDeclaration(import_decl) =>
        imports.push(import_decl.module_specifier)
      _ => ()
    }
  }
  imports
}

///|
/// Extract imports from multiple files
pub fn extract_imports_batch(
  files : Array[(String, String)],
) -> Array[ImportResult] {
  let results : Array[ImportResult] = []
  for file in files {
    let (source, path) = file
    results.push(extract_imports(source, path))
  }
  results
}

///|
/// Resolve a module specifier to an absolute file path
/// Handles relative imports (./foo, ../bar) and bare imports (lodash)
pub fn resolve_import_path(
  module_specifier : String,
  from_file : String,
) -> String? {
  if module_specifier.has_prefix("./") || module_specifier.has_prefix("../") {
    // Relative import - resolve relative to the importing file
    let dir = get_directory(from_file)
    let resolved = resolve_relative_path(dir, module_specifier)
    // Try adding .ts extension if not present
    if resolved.has_suffix(".ts") || resolved.has_suffix(".tsx") {
      Some(resolved)
    } else {
      Some(resolved + ".ts")
    }
  } else {
    // Bare import (node_modules) - not tracked in dependency graph
    None
  }
}

///|
/// Resolve a reference path to an absolute file path
/// Reference paths are always relative and can include .d.ts files
pub fn resolve_reference_path(
  reference_path : String,
  from_file : String,
) -> String? {
  // Reference paths are always relative (unlike imports which can be bare)
  if reference_path.has_prefix("./") || reference_path.has_prefix("../") {
    let dir = get_directory(from_file)
    let resolved = resolve_relative_path(dir, reference_path)
    Some(resolved)
  } else {
    // Treat non-prefixed paths as relative to the current file
    let dir = get_directory(from_file)
    Some(dir + "/" + reference_path)
  }
}

///|
/// Get directory portion of a file path
fn get_directory(file_path : String) -> String {
  let bytes = file_path.to_array()
  let mut last_slash = -1
  for i = 0; i < bytes.length(); i = i + 1 {
    if bytes[i] == '/' {
      last_slash = i
    }
  }
  if last_slash >= 0 {
    let chars : Array[Char] = []
    for i = 0; i < last_slash; i = i + 1 {
      chars.push(bytes[i])
    }
    String::from_array(chars)
  } else {
    "."
  }
}

///|
/// Resolve a relative path from a base directory
fn resolve_relative_path(base_dir : String, relative : String) -> String {
  // Remove ./ prefix
  let path = if relative.has_prefix("./") {
    let chars = relative.to_array()
    let result : Array[Char] = []
    for i = 2; i < chars.length(); i = i + 1 {
      result.push(chars[i])
    }
    String::from_array(result)
  } else {
    relative
  }

  // Simple path resolution
  if path.has_prefix("../") {
    // Go up one directory
    let parent = get_directory(base_dir)
    let rest_chars = path.to_array()
    let rest : Array[Char] = []
    for i = 3; i < rest_chars.length(); i = i + 1 {
      rest.push(rest_chars[i])
    }
    resolve_relative_path(parent, String::from_array(rest))
  } else {
    base_dir + "/" + path
  }
}

///|
/// Resolve a relative import against the set of files being compiled,
/// honoring TypeScript resolution order (.ts/.tsx/.d.ts extensions, .js->.ts
/// substitution, and directory index files). Falls back to the naive
/// ".ts"-appending guess when nothing in the set matches, preserving the
/// previous behavior for files outside the compilation.
pub fn resolve_import_path_with_resolver(
  module_specifier : String,
  from_file : String,
  resolver : @compiler.ModuleResolver,
) -> String? {
  if module_specifier.has_prefix("./") || module_specifier.has_prefix("../") {
    match resolver.resolve_module_name(module_specifier, from_file) {
      Ok(resolved) => Some(resolved.resolved_file_name)
      Err(_) => resolve_import_path(module_specifier, from_file)
    }
  } else {
    // Bare import (node_modules) - not tracked in dependency graph
    None
  }
}

///|
/// Build the dependency graph from source files
pub fn build_dependency_graph(
  files : Array[(String, String)], // (path, source) pairs - matches read_files output
) -> DependencyDag {
  let dag = DependencyDag::new()

  // Resolver whose filesystem view is the set of files being compiled,
  // so relative imports resolve to the actual on-disk participants
  // (a.d.ts, dir/index.ts, ...) instead of a naive ".ts" guess.
  let file_paths : Array[String] = []
  for file in files {
    file_paths.push(file.0)
  }
  let resolver = @compiler.ModuleResolver::with_file_set(file_paths, ".")

  // Store resolved imports/references and content hash for each file
  let file_data : Array[(String, Array[String], Int64)] = []

  // First pass: extract imports and references, compute hash, and create empty nodes
  for file in files {
    let (path, source) = file // read_files returns (path, content)
    let result = extract_imports_and_references(source, path)
    let content_hash = hash_source(source)

    // Resolve imports to absolute paths
    let resolved_deps : Array[String] = []
    for module_spec in result.imports {
      match resolve_import_path_with_resolver(module_spec, path, resolver) {
        Some(resolved) => resolved_deps.push(resolved)
        None => () // Skip bare imports (node_modules)
      }
    }

    // Resolve reference paths to absolute paths
    for ref_path in result.references {
      match resolve_reference_path(ref_path, path) {
        Some(resolved) => resolved_deps.push(resolved)
        None => ()
      }
    }
    file_data.push((path, resolved_deps, content_hash))

    // Add node with no imports first (all edges_in empty)
    add_node(dag, path, [], content_hash)
  }

  // Second pass: add edges now that all nodes exist
  for data in file_data {
    let (path, deps, content_hash) = data
    // Re-add the node with its dependencies (imports + references), which will update edges properly
    add_node(dag, path, deps, content_hash)
  }
  dag
}

///|
/// Collect all triple-slash reference paths from source files
/// Returns the resolved absolute paths of referenced files (typically .d.ts)
pub fn collect_reference_paths(
  files : Array[(String, String)], // (path, source) pairs
) -> Array[String] {
  let references : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for file in files {
    let (path, source) = file
    let result = extract_imports_and_references(source, path)
    for ref_path in result.references {
      match resolve_reference_path(ref_path, path) {
        Some(resolved) =>
          // Only add if not already seen
          match seen.get(resolved) {
            Some(_) => ()
            None => {
              seen.set(resolved, true)
              references.push(resolved)
            }
          }
        None => ()
      }
    }
  }
  references
}

///|
/// Filter reference paths to only include files not already in the file set
pub fn filter_new_references(
  references : Array[String],
  existing_files : Array[String],
) -> Array[String] {
  let existing_set : Map[String, Bool] = Map([])
  for file in existing_files {
    existing_set.set(file, true)
  }
  let new_refs : Array[String] = []
  for reference in references {
    match existing_set.get(reference) {
      Some(_) => () // Already in the file set
      None => new_refs.push(reference)
    }
  }
  new_refs
}
