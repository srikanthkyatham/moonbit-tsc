// TSConfig - TypeScript configuration file parser
// Parses tsconfig.json files and provides project configuration

///|
/// Project reference for composite projects
pub(all) struct ProjectReference {
  path : String
  prepend : Bool?
} derive(Show)

///|
/// TSConfig root structure
pub(all) struct TSConfig {
  compiler_options : CompilerOptions?
  files : Array[String]?
  include_patterns : Array[String]?
  exclude_patterns : Array[String]?
  extends : String?
  references : Array[ProjectReference]?
  compile_on_save : Bool?
} derive(Show)

///|
/// Create default TSConfig
pub fn TSConfig::default() -> TSConfig {
  {
    compiler_options: None,
    files: None,
    include_patterns: None,
    exclude_patterns: None,
    extends: None,
    references: None,
    compile_on_save: None,
  }
}

///|
/// Parse tsconfig.json from file path
pub async fn parse_tsconfig_file(path : String) -> TSConfig {
  let data = @fs.read_file(path)
  let content = data.text()
  parse_tsconfig_text(content, path)
}

///|
/// Parse tsconfig.json from JSON string
pub fn parse_tsconfig_text(
  json_text : String,
  _file_path : String,
) -> TSConfig raise {
  // Strip comments before parsing (tsconfig.json supports JSON5 comments)
  let cleaned_text = strip_json_comments(json_text)
  let json = @json.parse(cleaned_text)
  parse_tsconfig_json(json)
}

///|
/// Strip single-line (//) and multi-line (/* */) comments from JSON text
/// This allows parsing tsconfig.json files which use JSON5-style comments
fn strip_json_comments(text : String) -> String {
  let result = StringBuilder::new()
  let len = text.length()
  let mut i = 0
  let mut in_string = false
  let mut escape_next = false
  let slash = '/'.to_int()
  let backslash = '\\'.to_int()
  let quote = '"'.to_int()
  let newline = '\n'.to_int()
  let star = '*'.to_int()
  while i < len {
    let c = text[i]

    // Handle string state (don't strip comments inside strings)
    if in_string {
      result.write_char(c.unsafe_to_char())
      if escape_next {
        escape_next = false
      } else if c == backslash {
        escape_next = true
      } else if c == quote {
        in_string = false
      }
      i = i + 1
      continue
    }

    // Check for string start
    if c == quote {
      in_string = true
      result.write_char(c.unsafe_to_char())
      i = i + 1
      continue
    }

    // Check for single-line comment //
    if c == slash && i + 1 < len && text[i + 1] == slash {
      // Skip until end of line
      i = i + 2
      while i < len && text[i] != newline {
        i = i + 1
      }
      // Keep the newline for proper line counting
      if i < len {
        result.write_char('\n')
        i = i + 1
      }
      continue
    }

    // Check for multi-line comment /* */
    if c == slash && i + 1 < len && text[i + 1] == star {
      i = i + 2
      // Skip until */
      while i + 1 < len {
        if text[i] == star && text[i + 1] == slash {
          i = i + 2
          break
        }
        // Preserve newlines for line counting
        if text[i] == newline {
          result.write_char('\n')
        }
        i = i + 1
      }
      continue
    }

    // Regular character
    result.write_char(c.unsafe_to_char())
    i = i + 1
  }
  result.to_string()
}

///|
/// Parse TSConfig from JSON value
fn parse_tsconfig_json(json : Json) -> TSConfig raise {
  guard json is Object(obj) else { fail("TSConfig must be an object") }
  let compiler_options : CompilerOptions? = match obj.get("compilerOptions") {
    Some(opts) => Some(parse_compiler_options(opts))
    _ => None
  }
  let files = match obj.get("files") {
    Some(Array(arr)) => Some(parse_string_array(arr))
    _ => None
  }
  let include_patterns = match obj.get("include") {
    Some(Array(arr)) => Some(parse_string_array(arr))
    _ => None
  }
  let exclude_patterns = match obj.get("exclude") {
    Some(Array(arr)) => Some(parse_string_array(arr))
    _ => None
  }
  let extends = match obj.get("extends") {
    Some(String(s)) => Some(s)
    _ => None
  }
  let references = match obj.get("references") {
    Some(Array(arr)) => Some(parse_project_references(arr))
    _ => None
  }
  let compile_on_save = match obj.get("compileOnSave") {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
  {
    compiler_options,
    files,
    include_patterns,
    exclude_patterns,
    extends,
    references,
    compile_on_save,
  }
}

///|
/// Parse compilerOptions object
fn parse_compiler_options(json : Json) -> CompilerOptions {
  guard json is Object(obj) else { return CompilerOptions::default() }

  // Parse target
  let target = match obj.get("target") {
    Some(String(s)) => ScriptTarget::from_string(s)
    _ => None
  }

  // Parse module
  let module_kind = match obj.get("module") {
    Some(String(s)) => ModuleKind::from_string(s)
    _ => None
  }

  // Parse outDir
  let out_dir = get_string(obj, "outDir")

  // Parse outFile
  let out_file = get_string(obj, "outFile")

  // Parse rootDir
  let root_dir = get_string(obj, "rootDir")

  // Source map options
  let source_map = get_bool(obj, "sourceMap")
  let inline_source_map = get_bool(obj, "inlineSourceMap")
  let inline_sources = get_bool(obj, "inlineSources")
  let source_root = get_string(obj, "sourceRoot")
  let map_root = get_string(obj, "mapRoot")

  // Declaration options
  let declaration = get_bool(obj, "declaration")
  let declaration_map = get_bool(obj, "declarationMap")
  let declaration_dir = get_string(obj, "declarationDir")
  let emit_declaration_only = get_bool(obj, "emitDeclarationOnly")

  // Module resolution
  let module_resolution = match obj.get("moduleResolution") {
    Some(String(s)) => ModuleResolutionKind::from_string(s)
    _ => None
  }
  let base_url = get_string(obj, "baseUrl")
  let paths = parse_paths_map(obj)
  let root_dirs = get_string_array(obj, "rootDirs")
  let resolve_json_module = get_bool(obj, "resolveJsonModule")
  let type_roots = get_string_array(obj, "typeRoots")
  let types = get_string_array(obj, "types")

  // Strict options
  let strict = get_bool(obj, "strict")
  let no_implicit_any = get_bool(obj, "noImplicitAny")
  let strict_null_checks = get_bool(obj, "strictNullChecks")
  let strict_function_types = get_bool(obj, "strictFunctionTypes")
  let strict_bind_call_apply = get_bool(obj, "strictBindCallApply")
  let strict_property_initialization = get_bool(
    obj, "strictPropertyInitialization",
  )
  let no_implicit_this = get_bool(obj, "noImplicitThis")
  let use_unknown_in_catch_variables = get_bool(
    obj, "useUnknownInCatchVariables",
  )
  let always_strict = get_bool(obj, "alwaysStrict")

  // Additional type checking
  let no_unused_locals = get_bool(obj, "noUnusedLocals")
  let no_unused_parameters = get_bool(obj, "noUnusedParameters")
  let no_implicit_returns = get_bool(obj, "noImplicitReturns")
  let no_fallthrough_cases_in_switch = get_bool(
    obj, "noFallthroughCasesInSwitch",
  )
  let no_unchecked_indexed_access = get_bool(obj, "noUncheckedIndexedAccess")
  let no_implicit_override = get_bool(obj, "noImplicitOverride")

  // Emit options
  let remove_comments = get_bool(obj, "removeComments")
  let no_emit = get_bool(obj, "noEmit")
  let no_emit_on_error = get_bool(obj, "noEmitOnError")
  let no_emit_helpers = get_bool(obj, "noEmitHelpers")
  let import_helpers = get_bool(obj, "importHelpers")
  let downlevel_iteration = get_bool(obj, "downlevelIteration")
  let preserve_const_enums = get_bool(obj, "preserveConstEnums")

  // JSX options
  let jsx = match obj.get("jsx") {
    Some(String(s)) => JsxEmit::from_string(s)
    _ => None
  }
  let jsx_factory = get_string(obj, "jsxFactory")
  let jsx_fragment_factory = get_string(obj, "jsxFragmentFactory")
  let jsx_import_source = get_string(obj, "jsxImportSource")

  // Interop options
  let es_module_interop = get_bool(obj, "esModuleInterop")
  let allow_synthetic_default_imports = get_bool(
    obj, "allowSyntheticDefaultImports",
  )
  let isolated_modules = get_bool(obj, "isolatedModules")
  let verbatim_module_syntax = get_bool(obj, "verbatimModuleSyntax")

  // Library options
  let lib = get_string_array(obj, "lib")
  let no_lib = get_bool(obj, "noLib")

  // Misc options
  let skip_lib_check = get_bool(obj, "skipLibCheck")
  let skip_default_lib_check = get_bool(obj, "skipDefaultLibCheck")
  let allow_js = get_bool(obj, "allowJs")
  let check_js = get_bool(obj, "checkJs")
  let experimental_decorators = get_bool(obj, "experimentalDecorators")
  let emit_decorator_metadata = get_bool(obj, "emitDecoratorMetadata")

  // Incremental options
  let incremental = get_bool(obj, "incremental")
  let composite = get_bool(obj, "composite")
  let ts_build_info_file = get_string(obj, "tsBuildInfoFile")
  {
    target,
    module_kind,
    out_dir,
    out_file,
    root_dir,
    source_map,
    inline_source_map,
    inline_sources,
    source_root,
    map_root,
    declaration,
    declaration_map,
    declaration_dir,
    emit_declaration_only,
    module_resolution,
    base_url,
    paths,
    root_dirs,
    resolve_json_module,
    type_roots,
    types,
    strict,
    no_implicit_any,
    strict_null_checks,
    strict_function_types,
    strict_bind_call_apply,
    strict_property_initialization,
    no_implicit_this,
    use_unknown_in_catch_variables,
    always_strict,
    no_unused_locals,
    no_unused_parameters,
    no_implicit_returns,
    no_fallthrough_cases_in_switch,
    no_unchecked_indexed_access,
    no_implicit_override,
    remove_comments,
    no_emit,
    no_emit_on_error,
    no_emit_helpers,
    import_helpers,
    downlevel_iteration,
    preserve_const_enums,
    jsx,
    jsx_factory,
    jsx_fragment_factory,
    jsx_import_source,
    es_module_interop,
    allow_synthetic_default_imports,
    isolated_modules,
    verbatim_module_syntax,
    lib,
    no_lib,
    skip_lib_check,
    skip_default_lib_check,
    allow_js,
    check_js,
    experimental_decorators,
    emit_decorator_metadata,
    incremental,
    composite,
    ts_build_info_file,
  }
}

///|
/// Get string value from object
fn get_string(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(String(s)) => Some(s)
    _ => None
  }
}

///|
/// Get bool value from object
fn get_bool(obj : Map[String, Json], key : String) -> Bool? {
  match obj.get(key) {
    Some(True) => Some(true)
    Some(False) => Some(false)
    _ => None
  }
}

///|
/// Get string array value from object
fn get_string_array(obj : Map[String, Json], key : String) -> Array[String]? {
  match obj.get(key) {
    Some(Array(arr)) => Some(parse_string_array(arr))
    _ => None
  }
}

///|
/// Parse array of strings
fn parse_string_array(arr : Array[Json]) -> Array[String] {
  let result : Array[String] = []
  for item in arr {
    match item {
      String(s) => result.push(s)
      _ => ()
    }
  }
  result
}

///|
/// Parse paths map (e.g., { "@/*": ["./src/*"] })
fn parse_paths_map(obj : Map[String, Json]) -> Map[String, Array[String]]? {
  match obj.get("paths") {
    Some(Object(paths_obj)) => {
      let result : Map[String, Array[String]] = {}
      for key, value in paths_obj {
        match value {
          Array(arr) => result[key] = parse_string_array(arr)
          _ => ()
        }
      }
      if result.is_empty() {
        None
      } else {
        Some(result)
      }
    }
    _ => None
  }
}

///|
/// Parse project references array
fn parse_project_references(arr : Array[Json]) -> Array[ProjectReference] {
  let result : Array[ProjectReference] = []
  for item in arr {
    match item {
      Object(obj) => {
        let path = match obj.get("path") {
          Some(String(s)) => s
          _ => continue
        }
        let prepend = get_bool(obj, "prepend")
        result.push({ path, prepend })
      }
      _ => ()
    }
  }
  result
}

///|
/// Get default include patterns
pub fn get_default_include() -> Array[String] {
  ["**/*"]
}

///|
/// Get default exclude patterns
pub fn get_default_exclude(out_dir : String?) -> Array[String] {
  let result : Array[String] = [
    "node_modules", "bower_components", "jspm_packages",
  ]
  match out_dir {
    Some(dir) => {
      result.push(dir)
      result
    }
    None => result
  }
}

///|
/// Get effective include patterns from config
pub fn get_effective_include(config : TSConfig) -> Array[String] {
  match config.include_patterns {
    Some(patterns) if patterns.length() > 0 => patterns
    _ =>
      match config.files {
        Some(files) if files.length() > 0 => [] // When files is set, don't use include
        _ => get_default_include()
      }
  }
}

///|
/// Get effective exclude patterns from config
pub fn get_effective_exclude(config : TSConfig) -> Array[String] {
  let out_dir = match config.compiler_options {
    Some(opts) => opts.out_dir
    None => None
  }
  match config.exclude_patterns {
    Some(patterns) if patterns.length() > 0 => patterns
    _ => get_default_exclude(out_dir)
  }
}

///|
/// Check if the config has explicit files list
pub fn has_files_list(config : TSConfig) -> Bool {
  match config.files {
    Some(files) => files.length() > 0
    None => false
  }
}

///|
/// Load tsconfig.json with extends resolution
/// Handles circular extends detection
pub async fn load_tsconfig_with_extends(path : String) -> TSConfig raise Error {
  let seen : Array[String] = []
  load_tsconfig_recursive(path, seen)
}

///|
/// Internal recursive loader for extends support
async fn load_tsconfig_recursive(
  path : String,
  seen : Array[String],
) -> TSConfig raise Error {
  // Get real path for circular detection
  let real_path = @fs.realpath(path)

  // Check for circular extends
  for visited in seen {
    if visited == real_path {
      fail("Circular extends detected: " + path)
    }
  }
  seen.push(real_path)

  // Parse the current config
  let config = parse_tsconfig_file(path)

  // If no extends, return as-is
  guard config.extends is Some(extends_path) else { return config }

  // Resolve the extends path relative to current config directory
  let config_dir = get_config_directory(path)
  let resolved_extends = resolve_extends_path(extends_path, config_dir)

  // Load the base config recursively
  let base_config = load_tsconfig_recursive(resolved_extends, seen)

  // Merge base into current (current takes precedence)
  merge_tsconfigs(base_config, config)
}

///|
/// Merge two TSConfig objects (override takes precedence)
pub fn merge_tsconfigs(base : TSConfig, override_ : TSConfig) -> TSConfig {
  // Merge compiler options
  let merged_options = match
    (base.compiler_options, override_.compiler_options) {
    (Some(base_opts), Some(override_opts)) =>
      Some(merge_compiler_options(base_opts, override_opts))
    (None, Some(opts)) => Some(opts)
    (Some(opts), None) => Some(opts)
    (None, None) => None
  }

  // Files: override completely replaces base if present
  let files = match override_.files {
    Some(_) => override_.files
    None => base.files
  }

  // Include: override completely replaces base if present
  let include_patterns = match override_.include_patterns {
    Some(_) => override_.include_patterns
    None => base.include_patterns
  }

  // Exclude: override completely replaces base if present
  let exclude_patterns = match override_.exclude_patterns {
    Some(_) => override_.exclude_patterns
    None => base.exclude_patterns
  }

  // References: override completely replaces base if present
  let references = match override_.references {
    Some(_) => override_.references
    None => base.references
  }

  // CompileOnSave: override takes precedence
  let compile_on_save = match override_.compile_on_save {
    Some(_) => override_.compile_on_save
    None => base.compile_on_save
  }
  {
    compiler_options: merged_options,
    files,
    include_patterns,
    exclude_patterns,
    extends: None, // Clear extends after merge
    references,
    compile_on_save,
  }
}

///|
/// Resolve extends path (handles relative paths and package references)
fn resolve_extends_path(extends_path : String, config_dir : String) -> String {
  // Handle relative paths
  if extends_path.has_prefix("./") || extends_path.has_prefix("../") {
    join_paths(config_dir, extends_path)
  } else if extends_path.has_prefix("/") {
    // Absolute path
    extends_path
  } else {
    // Package reference (e.g., "@tsconfig/node18")
    // For now, try to resolve from node_modules
    let node_modules_path = join_paths(
      config_dir,
      "node_modules/" + extends_path,
    )
    // Check if it's a package with tsconfig.json
    if not(extends_path.has_suffix(".json")) {
      join_paths(node_modules_path, "tsconfig.json")
    } else {
      node_modules_path
    }
  }
}

///|
/// Get directory from config file path
fn get_config_directory(path : String) -> String {
  let mut last_slash = -1
  for i = 0; i < path.length(); i = i + 1 {
    if path[i] == '/' || path[i] == '\\' {
      last_slash = i
    }
  }
  if last_slash == -1 {
    "."
  } else if last_slash == 0 {
    "/"
  } else {
    @utils.substr(path, start=0, end=last_slash)
  }
}

///|
/// Join two path segments
fn join_paths(base : String, relative : String) -> String {
  // Remove trailing slash from base
  let base_clean = if base.has_suffix("/") || base.has_suffix("\\") {
    @utils.substr(base, start=0, end=base.length() - 1)
  } else {
    base
  }

  // Handle . and ..
  if relative == "." {
    return base_clean
  }
  if relative.has_prefix("./") {
    return base_clean + "/" + @utils.substr(relative, start=2)
  }
  if relative.has_prefix("../") {
    // Go up one directory
    let parent_dir = get_config_directory(base_clean)
    return join_paths(parent_dir, @utils.substr(relative, start=3))
  }
  base_clean + "/" + relative
}
