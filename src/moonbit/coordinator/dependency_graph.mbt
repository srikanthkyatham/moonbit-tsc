// Directed Acyclic Graph (DAG) for incremental compilation
// Tracks import relationships and provides topological ordering

///|
/// Represents a node in the DAG
struct DagNode {
  path : String // Absolute file path
  edges_out : Array[String] // Files this file imports (outgoing edges)
  edges_in : Array[String] // Files that import this file (incoming edges)
  content_hash : Int64 // Hash of file content for change detection
}

///|
/// Directed Acyclic Graph for dependency tracking
pub struct DependencyDag {
  nodes : Map[String, DagNode]
}

///|
/// Create a new empty DAG
pub fn DependencyDag::new() -> DependencyDag {
  { nodes: {} }
}

///|
/// Add or update a file node in the DAG
/// `imports` are the files this file depends on (edges pointing out)
/// `content_hash` is the hash of file content for change detection
pub fn add_node(
  dag : DependencyDag,
  path : String,
  imports : Array[String],
  content_hash : Int64,
) -> Unit {
  // Remove old edges if node exists
  match dag.nodes.get(path) {
    Some(old_node) => {
      // Remove this node from edges_in of all its imports
      for imported_path in old_node.edges_out {
        match dag.nodes.get(imported_path) {
          Some(imported_node) => {
            array_remove(imported_node.edges_in, path)
            // Put modified node back in map
            dag.nodes[imported_path] = imported_node
          }
          None => ()
        }
      }
    }
    None => ()
  }

  // Preserve existing edges_in if node exists
  let existing_edges_in : Array[String] = match dag.nodes.get(path) {
    Some(old_node) => old_node.edges_in.copy()
    None => []
  }

  // Create new node
  let node : DagNode = {
    path,
    edges_out: imports.copy(),
    edges_in: existing_edges_in,
    content_hash,
  }
  dag.nodes[path] = node

  // Add reverse edges (this file is imported by...)
  for imported_path in imports {
    match dag.nodes.get(imported_path) {
      Some(imported_node) => {
        if not(array_contains(imported_node.edges_in, path)) {
          imported_node.edges_in.push(path)
          // Put modified node back in map
          dag.nodes[imported_path] = imported_node
        }
      }
      None => ()
    }
  }
}

///|
/// Get all downstream dependents (files that transitively import this file)
/// Uses BFS traversal following edges_in (reverse edges)
pub fn get_downstream_dependents(
  dag : DependencyDag,
  path : String,
) -> Array[String] {
  let dependents : Array[String] = []
  let visited : Map[String, Bool] = {}
  let queue : Array[String] = [path]
  visited[path] = true

  while queue.length() > 0 {
    let current = queue.remove(0)

    match dag.nodes.get(current) {
      Some(node) => {
        for dependent in node.edges_in {
          if not(visited.contains(dependent)) {
            visited[dependent] = true
            dependents.push(dependent)
            queue.push(dependent)
          }
        }
      }
      None => ()
    }
  }

  dependents
}

///|
/// Get all upstream dependencies (files this file transitively imports)
/// Uses BFS traversal following edges_out
pub fn get_upstream_dependencies(
  dag : DependencyDag,
  path : String,
) -> Array[String] {
  let dependencies : Array[String] = []
  let visited : Map[String, Bool] = {}
  let queue : Array[String] = [path]
  visited[path] = true

  while queue.length() > 0 {
    let current = queue.remove(0)

    match dag.nodes.get(current) {
      Some(node) => {
        for dep in node.edges_out {
          if not(visited.contains(dep)) {
            visited[dep] = true
            dependencies.push(dep)
            queue.push(dep)
          }
        }
      }
      None => ()
    }
  }

  dependencies
}

///|
/// Topological sort using Kahn's algorithm
/// Returns files in compilation order (dependencies first)
pub fn topological_sort(dag : DependencyDag) -> Array[String]? {
  // Calculate in-degree for each node
  let in_degree : Map[String, Int] = {}
  for path, node in dag.nodes {
    in_degree[path] = node.edges_out.length()
  }

  // Find all nodes with no dependencies (in_degree == 0)
  let queue : Array[String] = []
  for path, degree in in_degree {
    if degree == 0 {
      queue.push(path)
    }
  }

  let sorted : Array[String] = []

  while queue.length() > 0 {
    let current = queue.remove(0)
    sorted.push(current)

    // Decrease in-degree of all dependents
    match dag.nodes.get(current) {
      Some(node) => {
        for dependent in node.edges_in {
          match in_degree.get(dependent) {
            Some(deg) => {
              let new_degree = deg - 1
              in_degree[dependent] = new_degree
              if new_degree == 0 {
                queue.push(dependent)
              }
            }
            None => ()
          }
        }
      }
      None => ()
    }
  }

  // Check for cycles
  if sorted.length() != dag.nodes.length() {
    return None // Cycle detected
  }

  Some(sorted)
}

///|
/// Get files that need recompilation given changed files
/// Returns files in topological order (dependencies compiled first)
pub fn get_recompilation_order(
  dag : DependencyDag,
  changed_files : Array[String],
) -> Array[String] {
  // Collect all files that need recompilation
  let needs_recompile : Map[String, Bool] = {}

  // Add changed files
  for file in changed_files {
    needs_recompile[file] = true
  }

  // Add all downstream dependents
  for file in changed_files {
    let dependents = get_downstream_dependents(dag, file)
    for dep in dependents {
      needs_recompile[dep] = true
    }
  }

  // Get topological order of all files
  let topo_order = topological_sort(dag)

  // Filter to only files that need recompilation, preserving order
  let result : Array[String] = []
  match topo_order {
    Some(order) => {
      for path in order {
        if needs_recompile.contains(path) {
          result.push(path)
        }
      }
    }
    None => {
      // Cycle detected, just return changed files + dependents
      for path, _ in needs_recompile {
        result.push(path)
      }
    }
  }

  result
}

///|
/// Check if file needs recompilation based on content hash
pub fn needs_recompilation(
  dag : DependencyDag,
  path : String,
  new_content_hash : Int64,
) -> Bool {
  match dag.nodes.get(path) {
    Some(node) => node.content_hash != new_content_hash
    None => true // New file
  }
}

///|
/// Update content hash for a file
pub fn update_content_hash(
  dag : DependencyDag,
  path : String,
  content_hash : Int64,
) -> Unit {
  match dag.nodes.get(path) {
    Some(old_node) =>
      dag.nodes[path] = {
        path: old_node.path,
        edges_out: old_node.edges_out,
        edges_in: old_node.edges_in,
        content_hash,
      }
    None => ()
  }
}

///|
/// Remove a file from the DAG
pub fn remove_node(dag : DependencyDag, path : String) -> Unit {
  match dag.nodes.get(path) {
    Some(node) => {
      // Remove from edges_in of all imports
      for imported_path in node.edges_out {
        match dag.nodes.get(imported_path) {
          Some(imported_node) => {
            array_remove(imported_node.edges_in, path)
            dag.nodes[imported_path] = imported_node
          }
          None => ()
        }
      }

      // Remove from edges_out of all dependents
      for dependent_path in node.edges_in {
        match dag.nodes.get(dependent_path) {
          Some(dependent_node) => {
            array_remove(dependent_node.edges_out, path)
            dag.nodes[dependent_path] = dependent_node
          }
          None => ()
        }
      }

      dag.nodes.remove(path)
    }
    None => ()
  }
}

///|
/// Get all files in the DAG
pub fn get_all_files(dag : DependencyDag) -> Array[String] {
  let files : Array[String] = []
  for path, _ in dag.nodes {
    files.push(path)
  }
  files
}

///|
/// Get direct imports of a file
pub fn get_direct_imports(dag : DependencyDag, path : String) -> Array[String] {
  match dag.nodes.get(path) {
    Some(node) => node.edges_out.copy()
    None => []
  }
}

///|
/// Get files that directly import this file
pub fn get_direct_importers(dag : DependencyDag, path : String) -> Array[String] {
  match dag.nodes.get(path) {
    Some(node) => node.edges_in.copy()
    None => []
  }
}

///|
/// Check if DAG has a cycle (for validation)
pub fn has_cycle(dag : DependencyDag) -> Bool {
  topological_sort(dag) is None
}

///|
/// Compute topological levels for parallel type checking.
/// Returns a list of levels, where each level contains files that can be
/// checked in parallel (all their dependencies are in earlier levels).
/// Level 0 = leaf nodes (no dependencies), Level 1 = depend only on level 0, etc.
pub fn topological_levels(dag : DependencyDag, files : Array[String]) -> Array[Array[String]] {
  // Build a set of files we're interested in
  let file_set : Map[String, Bool] = {}
  for file in files {
    file_set[file] = true
  }

  // Build filtered dependency map (only deps within our file set)
  let deps_map : Map[String, Array[String]] = {}
  for file in files {
    match dag.nodes.get(file) {
      Some(node) => {
        let filtered_deps : Array[String] = []
        for dep in node.edges_out {
          if file_set.contains(dep) {
            filtered_deps.push(dep)
          }
        }
        deps_map[file] = filtered_deps
      }
      None => deps_map[file] = []
    }
  }

  // Compute levels iteratively
  let levels : Array[Array[String]] = []
  let processed : Map[String, Bool] = {}

  while processed.length() < files.length() {
    // Find files with no remaining unprocessed dependencies (roots at this level)
    let current_level : Array[String] = []

    for file in files {
      if not(processed.contains(file)) {
        let deps = deps_map.get(file).unwrap_or([])
        let all_deps_processed = deps.iter().all(fn(dep) { processed.contains(dep) })
        if all_deps_processed {
          current_level.push(file)
        }
      }
    }

    // If no files can be added to current level, we have a cycle
    // Add remaining files as a single level to avoid infinite loop
    if current_level.length() == 0 {
      let remaining : Array[String] = []
      for file in files {
        if not(processed.contains(file)) {
          remaining.push(file)
        }
      }
      if remaining.length() > 0 {
        levels.push(remaining)
      }
      break
    }

    // Mark current level files as processed
    for file in current_level {
      processed[file] = true
    }

    levels.push(current_level)
  }

  levels
}

///|
/// Get files at a specific level (0-indexed)
pub fn get_level(dag : DependencyDag, files : Array[String], level_index : Int) -> Array[String] {
  let levels = topological_levels(dag, files)
  if level_index >= 0 && level_index < levels.length() {
    levels[level_index]
  } else {
    []
  }
}

///|
/// Get the number of levels in the dependency graph
pub fn level_count(dag : DependencyDag, files : Array[String]) -> Int {
  topological_levels(dag, files).length()
}

// Helper functions

///|
fn array_remove(arr : Array[String], value : String) -> Unit {
  let mut i = 0
  while i < arr.length() {
    if arr[i] == value {
      let mut j = i
      while j < arr.length() - 1 {
        arr[j] = arr[j + 1]
        j = j + 1
      }
      let _ = arr.pop()
    } else {
      i = i + 1
    }
  }
}

///|
fn array_contains(arr : Array[String], value : String) -> Bool {
  for item in arr {
    if item == value {
      return true
    }
  }
  false
}
