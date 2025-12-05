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
pub async fn load_project_graph(
  root_tsconfig : String,
) -> ProjectGraph raise Error {
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
    Some(refs) =>
      for reference in refs {
        // Resolve reference path relative to current project
        let ref_path = resolve_reference_path(reference.path, project_dir)
        dependencies.push(ref_path)

        // Recursively load referenced project
        load_project_recursive(ref_path, loaded, loading)
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
    Some(project) =>
      for dep in project.dependencies {
        visit_project(dep, project_map, visited, temp_visited, result)
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

// ============================================================================
// Project Validation
// ============================================================================

///|
/// Validation error for project references
pub(all) enum ProjectValidationError {
  /// Referenced project must have composite: true
  MissingComposite(String)
  /// Referenced project must have declaration: true
  MissingDeclaration(String)
  /// Circular reference detected
  CircularReference(String)
  /// Referenced project not found
  ProjectNotFound(String)
  /// Invalid project reference path
  InvalidReferencePath(String)
} derive(Show, Eq)

///|
/// Make ProjectValidationError public for testing
pub fn make_missing_composite(path : String) -> ProjectValidationError {
  MissingComposite(path)
}

///|
pub fn make_missing_declaration(path : String) -> ProjectValidationError {
  MissingDeclaration(path)
}

///|
pub fn make_circular_reference(path : String) -> ProjectValidationError {
  CircularReference(path)
}

///|
pub fn make_project_not_found(path : String) -> ProjectValidationError {
  ProjectNotFound(path)
}

///|
pub fn make_invalid_reference_path(path : String) -> ProjectValidationError {
  InvalidReferencePath(path)
}

///|
/// Result of validating a project graph
pub(all) struct ValidationResult {
  is_valid : Bool
  errors : Array[ProjectValidationError]
  warnings : Array[String]
} derive(Show)

///|
/// Make ValidationResult public for testing
pub fn make_validation_result(
  is_valid : Bool,
  errors : Array[ProjectValidationError],
  warnings : Array[String],
) -> ValidationResult {
  { is_valid, errors, warnings }
}

///|
/// Validate a project graph
/// Checks that all referenced projects have composite: true and declaration: true
pub fn validate_project_graph(graph : ProjectGraph) -> ValidationResult {
  let errors : Array[ProjectValidationError] = []
  let warnings : Array[String] = []

  // Build a map of all projects
  let project_map : Map[String, LoadedProject] = {}
  for project in graph.projects {
    project_map[project.path] = project
  }

  // Check each project that is referenced by others
  for project in graph.projects {
    // If this project has references, check that each referenced project is valid
    for dep_path in project.dependencies {
      match project_map.get(dep_path) {
        Some(dep_project) => {
          // Check composite flag
          if not(is_composite_project(dep_project.config)) {
            errors.push(MissingComposite(dep_path))
          }

          // Check declaration flag (composite implies declaration, but be explicit)
          match dep_project.config.compiler_options {
            Some(opts) =>
              // If composite is true, declaration is implicitly true
              // But if explicitly set to false, that's an error
              if opts.declaration is Some(false) {
                errors.push(MissingDeclaration(dep_path))
              }
            None =>
              // No compiler options means no declaration (unless composite)
              if not(is_composite_project(dep_project.config)) {
                errors.push(MissingDeclaration(dep_path))
              }
          }
        }
        None =>
          // Project not found in graph - should not happen if load worked
          errors.push(ProjectNotFound(dep_path))
      }
    }

    // Warn about projects without outDir (common issue)
    if project.dependencies.length() > 0 {
      match get_project_out_dir(project.config) {
        None =>
          warnings.push(
            "Project '\{project.path}' has references but no outDir specified",
          )
        Some(_) => ()
      }
    }
  }
  { is_valid: errors.length() == 0, errors, warnings }
}

// ============================================================================
// Cross-Project Module Resolution
// ============================================================================

///|
/// Information about a referenced project for module resolution
pub(all) struct ReferencedProjectInfo {
  /// Path to the tsconfig.json
  tsconfig_path : String
  /// Directory containing the project
  project_dir : String
  /// Output directory for .d.ts files
  declaration_dir : String?
  /// Base URL for path mapping
  base_url : String?
  /// Path mappings from the project
  paths : Map[String, Array[String]]?
} derive(Show)

///|
/// Make ReferencedProjectInfo for testing
pub fn make_referenced_project_info(
  tsconfig_path : String,
  project_dir : String,
  declaration_dir : String?,
  base_url : String?,
  paths : Map[String, Array[String]]?,
) -> ReferencedProjectInfo {
  { tsconfig_path, project_dir, declaration_dir, base_url, paths }
}

///|
/// Build a map of referenced projects for module resolution
pub fn build_project_resolution_map(
  graph : ProjectGraph,
) -> Map[String, ReferencedProjectInfo] {
  let result : Map[String, ReferencedProjectInfo] = {}
  for project in graph.projects {
    let project_dir = get_project_directory(project.path)
    let declaration_dir = get_project_declaration_dir(project.config)
    let (base_url, paths) = match project.config.compiler_options {
      Some(opts) => (opts.base_url, opts.paths)
      None => (None, None)
    }
    result[project.path] = {
      tsconfig_path: project.path,
      project_dir,
      declaration_dir,
      base_url,
      paths,
    }
  }
  result
}

///|
/// Resolve a module specifier to a declaration file in a referenced project
/// Returns the path to the .d.ts file if found
pub fn resolve_cross_project_import(
  specifier : String,
  from_project : LoadedProject,
  project_map : Map[String, ReferencedProjectInfo],
  file_exists : (String) -> Bool,
) -> String? {
  // Only try cross-project resolution for bare specifiers
  // Relative imports are resolved within the same project
  if specifier.has_prefix("./") || specifier.has_prefix("../") {
    return None
  }

  // Try to resolve in each dependency
  for dep_path in from_project.dependencies {
    match project_map.get(dep_path) {
      Some(dep_info) =>
        // Try to resolve using the dependency's declaration directory
        match dep_info.declaration_dir {
          Some(decl_dir) => {
            let decl_path = resolve_to_declaration(
              specifier,
              dep_info.project_dir,
              decl_dir,
              dep_info.base_url,
              dep_info.paths,
              file_exists,
            )
            match decl_path {
              Some(path) => return Some(path)
              None => ()
            }
          }
          None => ()
        }
      None => ()
    }
  }
  None
}

///|
/// Resolve a specifier to a declaration file path
fn resolve_to_declaration(
  specifier : String,
  project_dir : String,
  declaration_dir : String,
  base_url : String?,
  paths : Map[String, Array[String]]?,
  file_exists : (String) -> Bool,
) -> String? {
  // Resolve the declaration directory relative to project
  let abs_decl_dir = if declaration_dir.has_prefix("/") {
    declaration_dir
  } else {
    join_path_simple(project_dir, declaration_dir)
  }

  // First try paths mapping
  match paths {
    Some(path_map) =>
      for pattern, targets in path_map {
        match try_match_pattern(pattern, specifier) {
          Some(matched_part) =>
            for target in targets {
              // Replace * with matched part
              let resolved = replace_star(target, matched_part)
              // Try to find .d.ts file
              let decl_path = join_path_simple(abs_decl_dir, resolved + ".d.ts")
              if file_exists(decl_path) {
                return Some(decl_path)
              }
              // Try index.d.ts
              let index_path = join_path_simple(
                abs_decl_dir,
                resolved + "/index.d.ts",
              )
              if file_exists(index_path) {
                return Some(index_path)
              }
            }
          None => continue
        }
      }
    None => ()
  }

  // Try baseUrl resolution
  match base_url {
    Some(_) => {
      // Try direct resolution
      let direct_path = join_path_simple(abs_decl_dir, specifier + ".d.ts")
      if file_exists(direct_path) {
        return Some(direct_path)
      }
      // Try index.d.ts
      let index_path = join_path_simple(abs_decl_dir, specifier + "/index.d.ts")
      if file_exists(index_path) {
        return Some(index_path)
      }
    }
    None => ()
  }

  // Direct resolution in declaration dir
  let direct = join_path_simple(abs_decl_dir, specifier + ".d.ts")
  if file_exists(direct) {
    return Some(direct)
  }
  let index = join_path_simple(abs_decl_dir, specifier + "/index.d.ts")
  if file_exists(index) {
    return Some(index)
  }
  None
}

///|
/// Try to match a path pattern like "@/*" against a specifier
fn try_match_pattern(pattern : String, specifier : String) -> String? {
  let star_idx = find_char_in_string(pattern, '*')
  match star_idx {
    None =>
      // Exact match
      if pattern == specifier {
        Some("")
      } else {
        None
      }
    Some(idx) => {
      let prefix = @utils.substr(pattern, start=0, end=idx)
      let suffix = if idx + 1 < pattern.length() {
        @utils.substr(pattern, start=idx + 1)
      } else {
        ""
      }
      if specifier.has_prefix(prefix) {
        let after_prefix = @utils.substr(specifier, start=prefix.length())
        if suffix.length() == 0 {
          Some(after_prefix)
        } else if after_prefix.has_suffix(suffix) {
          let middle_end = after_prefix.length() - suffix.length()
          Some(@utils.substr(after_prefix, start=0, end=middle_end))
        } else {
          None
        }
      } else {
        None
      }
    }
  }
}

///|
/// Replace * in a string with replacement
fn replace_star(s : String, replacement : String) -> String {
  let result = StringBuilder::new()
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == '*' {
      result.write_string(replacement)
    } else {
      result.write_char(Int::unsafe_to_char(s[i]))
    }
  }
  result.to_string()
}

///|
/// Find character in string, returning index
fn find_char_in_string(s : String, c : Char) -> Int? {
  let code = c.to_int()
  for i = 0; i < s.length(); i = i + 1 {
    if s[i] == code {
      return Some(i)
    }
  }
  None
}

///|
/// Simple path joining
fn join_path_simple(base : String, relative : String) -> String {
  if relative.has_prefix("/") {
    return relative
  }
  let base_clean = if base.has_suffix("/") {
    @utils.substr(base, start=0, end=base.length() - 1)
  } else {
    base
  }
  if relative.has_prefix("./") {
    base_clean + "/" + @utils.substr(relative, start=2)
  } else if relative.has_prefix("../") {
    let parent = get_project_directory(base_clean)
    join_path_simple(parent, @utils.substr(relative, start=3))
  } else {
    base_clean + "/" + relative
  }
}

// ============================================================================
// Declaration File Discovery
// ============================================================================

///|
/// Discovered declaration files from a project
pub(all) struct ProjectDeclarations {
  /// Project path (tsconfig.json)
  project_path : String
  /// List of declaration file paths
  declaration_files : Array[String]
} derive(Show)

///|
/// Make ProjectDeclarations for testing
pub fn make_project_declarations(
  project_path : String,
  declaration_files : Array[String],
) -> ProjectDeclarations {
  { project_path, declaration_files }
}

///|
/// Discover all declaration files from referenced projects
/// This is used to gather type information from dependencies
pub async fn discover_project_declarations(
  graph : ProjectGraph,
) -> Array[ProjectDeclarations] raise Error {
  let result : Array[ProjectDeclarations] = []
  for project in graph.projects {
    // Skip projects with no dependencies (they are leaf projects)
    // We want declarations from projects that are depended upon
    let decl_dir = get_project_declaration_dir(project.config)
    match decl_dir {
      Some(dir) => {
        let project_dir = get_project_directory(project.path)
        let abs_dir = if dir.has_prefix("/") {
          dir
        } else {
          join_path_simple(project_dir, dir)
        }

        // Walk the declaration directory for .d.ts files
        let decl_files = discover_declaration_files_in_dir(abs_dir)
        if decl_files.length() > 0 {
          result.push({
            project_path: project.path,
            declaration_files: decl_files,
          })
        }
      }
      None => ()
    }
  }
  result
}

///|
/// Walk a directory and find all .d.ts files
async fn discover_declaration_files_in_dir(
  dir : String,
) -> Array[String] raise Error {
  let result : Array[String] = []

  // Check if directory exists
  let kind = @fs.kind(dir)
  if kind != @fs.FileKind::Directory {
    return result
  }

  // Walk the directory
  @fs.walk(dir, async fn(current_dir, entries) {
    for entry in entries {
      let full_path = current_dir + "/" + entry
      if full_path.has_suffix(".d.ts") {
        result.push(full_path)
      }
    }
  })
  result
}

// ============================================================================
// Build Mode Support
// ============================================================================

///|
/// Build status for a project
pub(all) enum ProjectBuildStatus {
  /// Project needs to be built
  NeedsBuild
  /// Project is up to date
  UpToDate
  /// Project was built successfully
  Built
  /// Project build failed
  Failed(String)
} derive(Show, Eq)

///|
/// Make ProjectBuildStatus for testing
pub fn make_needs_build() -> ProjectBuildStatus {
  NeedsBuild
}

///|
pub fn make_up_to_date() -> ProjectBuildStatus {
  UpToDate
}

///|
pub fn make_built() -> ProjectBuildStatus {
  Built
}

///|
pub fn make_failed(msg : String) -> ProjectBuildStatus {
  Failed(msg)
}

///|
/// Build state tracking for multi-project builds
pub(all) struct ProjectBuildState {
  /// Project path
  project_path : String
  /// Current build status
  status : ProjectBuildStatus
  /// Hash of source files (for change detection)
  source_hash : Int64
} derive(Show)

///|
/// Make ProjectBuildState for testing
pub fn make_project_build_state(
  project_path : String,
  status : ProjectBuildStatus,
  source_hash : Int64,
) -> ProjectBuildState {
  { project_path, status, source_hash }
}

///|
/// Multi-project build context
pub(all) struct BuildContext {
  /// The project graph
  graph : ProjectGraph
  /// Build states for each project
  states : Map[String, ProjectBuildState]
  /// Validation result
  validation : ValidationResult
} derive(Show)

///|
/// Make BuildContext for testing
pub fn make_build_context(
  graph : ProjectGraph,
  states : Map[String, ProjectBuildState],
  validation : ValidationResult,
) -> BuildContext {
  { graph, states, validation }
}

///|
/// Initialize a build context for a project graph
pub fn init_build_context(graph : ProjectGraph) -> BuildContext {
  let states : Map[String, ProjectBuildState] = {}

  // Initialize all projects as needing build
  for project_path in graph.build_order {
    states[project_path] = { project_path, status: NeedsBuild, source_hash: 0 }
  }

  // Validate the graph
  let validation = validate_project_graph(graph)
  { graph, states, validation }
}

///|
/// Get the next project that should be built
/// Returns None if all projects are built or there's an error
pub fn get_next_project_to_build(ctx : BuildContext) -> String? {
  // If validation failed, don't build
  if not(ctx.validation.is_valid) {
    return None
  }

  // Find the first project in build order that needs building
  // and has all dependencies built
  for project_path in ctx.graph.build_order {
    match ctx.states.get(project_path) {
      Some(state) =>
        if state.status is NeedsBuild {
          // Check if all dependencies are built
          let deps_built = are_dependencies_built(ctx, project_path)
          if deps_built {
            return Some(project_path)
          }
        }
      None => ()
    }
  }
  None
}

///|
/// Check if all dependencies of a project are built
fn are_dependencies_built(ctx : BuildContext, project_path : String) -> Bool {
  // Find the project
  for project in ctx.graph.projects {
    if project.path == project_path {
      // Check each dependency
      for dep_path in project.dependencies {
        match ctx.states.get(dep_path) {
          Some(dep_state) =>
            match dep_state.status {
              Built | UpToDate => continue
              _ => return false
            }
          None => return false
        }
      }
      return true
    }
  }
  true
}

///|
/// Mark a project as built
pub fn mark_project_built(ctx : BuildContext, project_path : String) -> Unit {
  match ctx.states.get(project_path) {
    Some(state) => ctx.states[project_path] = { ..state, status: Built }
    None => ()
  }
}

///|
/// Mark a project as failed
pub fn mark_project_failed(
  ctx : BuildContext,
  project_path : String,
  error_msg : String,
) -> Unit {
  match ctx.states.get(project_path) {
    Some(state) =>
      ctx.states[project_path] = { ..state, status: Failed(error_msg) }
    None => ()
  }
}

///|
/// Check if all projects are built successfully
pub fn all_projects_built(ctx : BuildContext) -> Bool {
  for _, state in ctx.states {
    match state.status {
      Built | UpToDate => continue
      _ => return false
    }
  }
  true
}

///|
/// Get all projects that failed to build
pub fn get_failed_projects(ctx : BuildContext) -> Array[String] {
  let result : Array[String] = []
  for path, state in ctx.states {
    if state.status is Failed(_) {
      result.push(path)
    }
  }
  result
}
