// Project References support for composite TypeScript projects
// Handles loading and building multiple related projects in correct order

///|
/// A loaded project with its config and path
pub(all) struct LoadedProject {
  path : String // Path to tsconfig.json
  config : TSConfig
  dependencies : Array[String] // Paths to referenced projects
} derive(Show)

///|
/// Result of resolving project references
pub(all) struct ProjectGraph {
  projects : Array[LoadedProject]
  build_order : Array[String] // Topologically sorted project paths
} derive(Show)

///|
/// Load a project and all its references recursively
pub async fn load_project_graph(root_tsconfig : String) -> ProjectGraph raise Error {
  let loaded : Map[String, LoadedProject] = {}
  let loading : Array[String] = [] // For cycle detection

  // Load root project and all references
  load_project_recursive(root_tsconfig, loaded, loading)

  // Convert to array
  let projects : Array[LoadedProject] = []
  for _, project in loaded {
    projects.push(project)
  }

  // Compute build order (topological sort)
  let build_order = topological_sort(projects)

  { projects, build_order }
}

///|
/// Recursively load a project and its references
async fn load_project_recursive(
  tsconfig_path : String,
  loaded : Map[String, LoadedProject],
  loading : Array[String],
) -> Unit raise Error {
  // Get real path for consistent keys
  let real_path = @fs.realpath(tsconfig_path)

  // Check if already loaded
  if loaded.contains(real_path) {
    return
  }

  // Check for cycles
  for path in loading {
    if path == real_path {
      fail("Circular project reference detected: " + tsconfig_path)
    }
  }
  loading.push(real_path)

  // Load the config with extends resolution
  let config = load_tsconfig_with_extends(tsconfig_path)

  // Get project directory
  let project_dir = get_project_directory(tsconfig_path)

  // Collect dependencies (referenced projects)
  let dependencies : Array[String] = []

  match config.references {
    Some(refs) => {
      for ref in refs {
        // Resolve reference path relative to current project
        let ref_path = resolve_reference_path(ref.path, project_dir)
        dependencies.push(ref_path)

        // Recursively load referenced project
        load_project_recursive(ref_path, loaded, loading)
      }
    }
    None => ()
  }

  // Remove from loading stack
  let new_loading : Array[String] = []
  for path in loading {
    if path != real_path {
      new_loading.push(path)
    }
  }
  // Note: Can't reassign loading, but this is fine for cycle detection

  // Store loaded project
  loaded[real_path] = { path: real_path, config, dependencies }
}

///|
/// Topological sort of projects for correct build order
/// Projects with no dependencies come first
fn topological_sort(projects : Array[LoadedProject]) -> Array[String] {
  let result : Array[String] = []
  let visited : Map[String, Bool] = {}
  let temp_visited : Map[String, Bool] = {}

  // Build adjacency map
  let project_map : Map[String, LoadedProject] = {}
  for project in projects {
    project_map[project.path] = project
  }

  // Visit each project
  for project in projects {
    if not(visited.get(project.path).unwrap_or(false)) {
      visit_project(project.path, project_map, visited, temp_visited, result)
    }
  }

  result
}

///|
/// DFS visit for topological sort
fn visit_project(
  path : String,
  project_map : Map[String, LoadedProject],
  visited : Map[String, Bool],
  temp_visited : Map[String, Bool],
  result : Array[String],
) -> Unit {
  // Check for cycle (shouldn't happen if load_project_recursive worked)
  if temp_visited.get(path).unwrap_or(false) {
    return // Cycle detected, skip
  }

  if visited.get(path).unwrap_or(false) {
    return // Already processed
  }

  temp_visited[path] = true

  // Visit dependencies first
  match project_map.get(path) {
    Some(project) => {
      for dep in project.dependencies {
        visit_project(dep, project_map, visited, temp_visited, result)
      }
    }
    None => ()
  }

  temp_visited[path] = false
  visited[path] = true
  result.push(path)
}

///|
/// Resolve a reference path relative to the project directory
fn resolve_reference_path(ref_path : String, project_dir : String) -> String {
  if ref_path.has_prefix("/") {
    // Absolute path
    ref_path
  } else {
    // Relative path - join with project directory
    let joined = if project_dir.has_suffix("/") {
      project_dir + ref_path
    } else {
      project_dir + "/" + ref_path
    }

    // Add tsconfig.json if path is a directory
    if not(ref_path.has_suffix(".json")) {
      if joined.has_suffix("/") {
        joined + "tsconfig.json"
      } else {
        joined + "/tsconfig.json"
      }
    } else {
      joined
    }
  }
}

///|
/// Get project directory from tsconfig path
fn get_project_directory(tsconfig_path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < tsconfig_path.length(); i = i + 1 {
    if tsconfig_path[i] == '/' || tsconfig_path[i] == '\\' {
      last_slash = i
    }
  }
  if last_slash <= 0 {
    "."
  } else {
    @utils.substr(tsconfig_path, start=0, end=last_slash)
  }
}

///|
/// Check if a project is a composite project (has composite: true)
pub fn is_composite_project(config : TSConfig) -> Bool {
  match config.compiler_options {
    Some(opts) => opts.composite.unwrap_or(false)
    None => false
  }
}

///|
/// Check if a project has references
pub fn has_project_references(config : TSConfig) -> Bool {
  match config.references {
    Some(refs) => refs.length() > 0
    None => false
  }
}

///|
/// Get the output directory for a project (for finding .d.ts files)
pub fn get_project_out_dir(config : TSConfig) -> String? {
  match config.compiler_options {
    Some(opts) => opts.out_dir
    None => None
  }
}

///|
/// Get declaration directory for a project
pub fn get_project_declaration_dir(config : TSConfig) -> String? {
  match config.compiler_options {
    Some(opts) =>
      match opts.declaration_dir {
        Some(dir) => Some(dir)
        None => opts.out_dir // Fall back to outDir
      }
    None => None
  }
}

///|
/// Get files from a project for compilation
pub fn get_project_files(project : LoadedProject) -> Array[String]? {
  project.config.files
}

///|
/// Get include patterns from a project
pub fn get_project_include(project : LoadedProject) -> Array[String] {
  get_effective_include(project.config)
}

///|
/// Get exclude patterns from a project
pub fn get_project_exclude(project : LoadedProject) -> Array[String] {
  get_effective_exclude(project.config)
}
