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
/// Extract import module specifiers from a parsed SourceFile
fn extract_imports_from_ast(source_file : @compiler.SourceFile) -> Array[String] {
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
/// Build the dependency graph from source files
pub fn build_dependency_graph(
  files : Array[(String, String)], // (path, source) pairs - matches read_files output
) -> DependencyDag {
  let dag = DependencyDag::new()

  // Store resolved imports and content hash for each file
  let file_data : Array[(String, Array[String], Int64)] = []

  // First pass: extract imports, compute hash, and create empty nodes
  for file in files {
    let (path, source) = file // read_files returns (path, content)
    let result = extract_imports(source, path)
    let content_hash = hash_source(source)

    // Resolve imports to absolute paths
    let resolved_imports : Array[String] = []
    for module_spec in result.imports {
      match resolve_import_path(module_spec, path) {
        Some(resolved) => resolved_imports.push(resolved)
        None => () // Skip bare imports (node_modules)
      }
    }

    file_data.push((path, resolved_imports, content_hash))

    // Add node with no imports first (all edges_in empty)
    add_node(dag, path, [], content_hash)
  }

  // Second pass: add edges now that all nodes exist
  for data in file_data {
    let (path, imports, content_hash) = data
    // Re-add the node with its imports, which will update edges properly
    add_node(dag, path, imports, content_hash)
  }

  dag
}
