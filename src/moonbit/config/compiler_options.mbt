// CompilerOptions - TypeScript compiler options from tsconfig.json
// Mirrors the essential options from TypeScript's CompilerOptions interface

///|
/// ECMAScript target version
pub(all) enum ScriptTarget {
  ES3
  ES5
  ES2015
  ES2016
  ES2017
  ES2018
  ES2019
  ES2020
  ES2021
  ES2022
  ES2023
  ESNext
} derive(Eq, Debug)

///|
/// Parse target string to ScriptTarget
pub fn ScriptTarget::from_string(s : String) -> ScriptTarget? {
  match s.to_lower() {
    "es3" => Some(ES3)
    "es5" => Some(ES5)
    "es6" | "es2015" => Some(ES2015)
    "es7" | "es2016" => Some(ES2016)
    "es2017" => Some(ES2017)
    "es2018" => Some(ES2018)
    "es2019" => Some(ES2019)
    "es2020" => Some(ES2020)
    "es2021" => Some(ES2021)
    "es2022" => Some(ES2022)
    "es2023" => Some(ES2023)
    "esnext" => Some(ESNext)
    _ => None
  }
}

///|
/// Convert ScriptTarget to string
pub fn ScriptTarget::to_target_string(self : ScriptTarget) -> String {
  match self {
    ES3 => "es3"
    ES5 => "es5"
    ES2015 => "es2015"
    ES2016 => "es2016"
    ES2017 => "es2017"
    ES2018 => "es2018"
    ES2019 => "es2019"
    ES2020 => "es2020"
    ES2021 => "es2021"
    ES2022 => "es2022"
    ES2023 => "es2023"
    ESNext => "esnext"
  }
}

///|
/// Module system
pub(all) enum ModuleKind {
  ModuleNone
  CommonJS
  AMD
  UMD
  System
  ES2015
  ES2020
  ES2022
  ESNext
  Node16
  NodeNext
  Preserve
} derive(Eq, Debug)

///|
/// Parse module string to ModuleKind
pub fn ModuleKind::from_string(s : String) -> ModuleKind? {
  match s.to_lower() {
    "none" => Some(ModuleNone)
    "commonjs" => Some(CommonJS)
    "amd" => Some(AMD)
    "umd" => Some(UMD)
    "system" => Some(System)
    "es6" | "es2015" => Some(ES2015)
    "es2020" => Some(ES2020)
    "es2022" => Some(ES2022)
    "esnext" => Some(ESNext)
    "node16" => Some(Node16)
    "nodenext" => Some(NodeNext)
    "preserve" => Some(Preserve)
    _ => Some(ESNext) // Default fallback
  }
}

///|
/// Module resolution strategy
pub(all) enum ModuleResolutionKind {
  Classic
  Node10
  Node16
  NodeNext
  Bundler
} derive(Eq, Debug)

///|
/// Parse moduleResolution string
pub fn ModuleResolutionKind::from_string(s : String) -> ModuleResolutionKind? {
  match s.to_lower() {
    "classic" => Some(Classic)
    "node" | "node10" => Some(Node10)
    "node16" => Some(Node16)
    "nodenext" => Some(NodeNext)
    "bundler" => Some(Bundler)
    _ => None
  }
}

///|
/// JSX emit mode
pub(all) enum JsxEmit {
  JsxNone
  Preserve
  React
  ReactNative
  ReactJSX
  ReactJSXDev
} derive(Eq, Debug)

///|
/// Parse jsx string
pub fn JsxEmit::from_string(s : String) -> JsxEmit? {
  match s.to_lower() {
    "preserve" => Some(Preserve)
    "react" => Some(React)
    "react-native" => Some(ReactNative)
    "react-jsx" => Some(ReactJSX)
    "react-jsxdev" => Some(ReactJSXDev)
    _ => None
  }
}

///|
/// Compiler options from tsconfig.json compilerOptions
pub(all) struct CompilerOptions {
  // Output Options
  target : ScriptTarget?
  module_kind : ModuleKind?
  out_dir : String?
  out_file : String?
  root_dir : String?

  // Source Maps
  source_map : Bool?
  inline_source_map : Bool?
  inline_sources : Bool?
  source_root : String?
  map_root : String?

  // Declaration Files
  declaration : Bool?
  declaration_map : Bool?
  declaration_dir : String?
  emit_declaration_only : Bool?

  // Module Resolution
  module_resolution : ModuleResolutionKind?
  base_url : String?
  paths : Map[String, Array[String]]?
  root_dirs : Array[String]?
  resolve_json_module : Bool?
  type_roots : Array[String]?
  types : Array[String]?

  // Type Checking - Strict Options
  strict : Bool?
  no_implicit_any : Bool?
  strict_null_checks : Bool?
  strict_function_types : Bool?
  strict_bind_call_apply : Bool?
  strict_property_initialization : Bool?
  no_implicit_this : Bool?
  use_unknown_in_catch_variables : Bool?
  always_strict : Bool?

  // Type Checking - Additional
  no_unused_locals : Bool?
  no_unused_parameters : Bool?
  no_implicit_returns : Bool?
  no_fallthrough_cases_in_switch : Bool?
  no_unchecked_indexed_access : Bool?
  no_implicit_override : Bool?

  // Emit Options
  remove_comments : Bool?
  no_emit : Bool?
  no_emit_on_error : Bool?
  no_emit_helpers : Bool?
  import_helpers : Bool?
  downlevel_iteration : Bool?
  preserve_const_enums : Bool?

  // JSX
  jsx : JsxEmit?
  jsx_factory : String?
  jsx_fragment_factory : String?
  jsx_import_source : String?

  // Interop
  es_module_interop : Bool?
  allow_synthetic_default_imports : Bool?
  isolated_modules : Bool?
  verbatim_module_syntax : Bool?

  // Libraries
  lib : Array[String]?
  no_lib : Bool?

  // Misc
  skip_lib_check : Bool?
  skip_default_lib_check : Bool?
  allow_js : Bool?
  check_js : Bool?
  experimental_decorators : Bool?
  emit_decorator_metadata : Bool?

  // Incremental
  incremental : Bool?
  composite : Bool?
  ts_build_info_file : String?
} derive(Debug)

///|
/// Create default compiler options
pub fn CompilerOptions::default() -> CompilerOptions {
  {
    target: None,
    module_kind: None,
    out_dir: None,
    out_file: None,
    root_dir: None,
    source_map: None,
    inline_source_map: None,
    inline_sources: None,
    source_root: None,
    map_root: None,
    declaration: None,
    declaration_map: None,
    declaration_dir: None,
    emit_declaration_only: None,
    module_resolution: None,
    base_url: None,
    paths: None,
    root_dirs: None,
    resolve_json_module: None,
    type_roots: None,
    types: None,
    strict: None,
    no_implicit_any: None,
    strict_null_checks: None,
    strict_function_types: None,
    strict_bind_call_apply: None,
    strict_property_initialization: None,
    no_implicit_this: None,
    use_unknown_in_catch_variables: None,
    always_strict: None,
    no_unused_locals: None,
    no_unused_parameters: None,
    no_implicit_returns: None,
    no_fallthrough_cases_in_switch: None,
    no_unchecked_indexed_access: None,
    no_implicit_override: None,
    remove_comments: None,
    no_emit: None,
    no_emit_on_error: None,
    no_emit_helpers: None,
    import_helpers: None,
    downlevel_iteration: None,
    preserve_const_enums: None,
    jsx: None,
    jsx_factory: None,
    jsx_fragment_factory: None,
    jsx_import_source: None,
    es_module_interop: None,
    allow_synthetic_default_imports: None,
    isolated_modules: None,
    verbatim_module_syntax: None,
    lib: None,
    no_lib: None,
    skip_lib_check: None,
    skip_default_lib_check: None,
    allow_js: None,
    check_js: None,
    experimental_decorators: None,
    emit_decorator_metadata: None,
    incremental: None,
    composite: None,
    ts_build_info_file: None,
  }
}

///|
/// Helper to merge optional values (override takes precedence)
fn[T] merge_option(override_ : T?, base : T?) -> T? {
  match override_ {
    Some(_) => override_
    None => base
  }
}

///|
/// Merge two CompilerOptions, with override taking precedence
pub fn merge_compiler_options(
  base : CompilerOptions,
  override_ : CompilerOptions,
) -> CompilerOptions {
  {
    target: merge_option(override_.target, base.target),
    module_kind: merge_option(override_.module_kind, base.module_kind),
    out_dir: merge_option(override_.out_dir, base.out_dir),
    out_file: merge_option(override_.out_file, base.out_file),
    root_dir: merge_option(override_.root_dir, base.root_dir),
    source_map: merge_option(override_.source_map, base.source_map),
    inline_source_map: merge_option(
      override_.inline_source_map,
      base.inline_source_map,
    ),
    inline_sources: merge_option(override_.inline_sources, base.inline_sources),
    source_root: merge_option(override_.source_root, base.source_root),
    map_root: merge_option(override_.map_root, base.map_root),
    declaration: merge_option(override_.declaration, base.declaration),
    declaration_map: merge_option(
      override_.declaration_map,
      base.declaration_map,
    ),
    declaration_dir: merge_option(
      override_.declaration_dir,
      base.declaration_dir,
    ),
    emit_declaration_only: merge_option(
      override_.emit_declaration_only,
      base.emit_declaration_only,
    ),
    module_resolution: merge_option(
      override_.module_resolution,
      base.module_resolution,
    ),
    base_url: merge_option(override_.base_url, base.base_url),
    paths: merge_option(override_.paths, base.paths),
    root_dirs: merge_option(override_.root_dirs, base.root_dirs),
    resolve_json_module: merge_option(
      override_.resolve_json_module,
      base.resolve_json_module,
    ),
    type_roots: merge_option(override_.type_roots, base.type_roots),
    types: merge_option(override_.types, base.types),
    strict: merge_option(override_.strict, base.strict),
    no_implicit_any: merge_option(
      override_.no_implicit_any,
      base.no_implicit_any,
    ),
    strict_null_checks: merge_option(
      override_.strict_null_checks,
      base.strict_null_checks,
    ),
    strict_function_types: merge_option(
      override_.strict_function_types,
      base.strict_function_types,
    ),
    strict_bind_call_apply: merge_option(
      override_.strict_bind_call_apply,
      base.strict_bind_call_apply,
    ),
    strict_property_initialization: merge_option(
      override_.strict_property_initialization,
      base.strict_property_initialization,
    ),
    no_implicit_this: merge_option(
      override_.no_implicit_this,
      base.no_implicit_this,
    ),
    use_unknown_in_catch_variables: merge_option(
      override_.use_unknown_in_catch_variables,
      base.use_unknown_in_catch_variables,
    ),
    always_strict: merge_option(override_.always_strict, base.always_strict),
    no_unused_locals: merge_option(
      override_.no_unused_locals,
      base.no_unused_locals,
    ),
    no_unused_parameters: merge_option(
      override_.no_unused_parameters,
      base.no_unused_parameters,
    ),
    no_implicit_returns: merge_option(
      override_.no_implicit_returns,
      base.no_implicit_returns,
    ),
    no_fallthrough_cases_in_switch: merge_option(
      override_.no_fallthrough_cases_in_switch,
      base.no_fallthrough_cases_in_switch,
    ),
    no_unchecked_indexed_access: merge_option(
      override_.no_unchecked_indexed_access,
      base.no_unchecked_indexed_access,
    ),
    no_implicit_override: merge_option(
      override_.no_implicit_override,
      base.no_implicit_override,
    ),
    remove_comments: merge_option(
      override_.remove_comments,
      base.remove_comments,
    ),
    no_emit: merge_option(override_.no_emit, base.no_emit),
    no_emit_on_error: merge_option(
      override_.no_emit_on_error,
      base.no_emit_on_error,
    ),
    no_emit_helpers: merge_option(
      override_.no_emit_helpers,
      base.no_emit_helpers,
    ),
    import_helpers: merge_option(override_.import_helpers, base.import_helpers),
    downlevel_iteration: merge_option(
      override_.downlevel_iteration,
      base.downlevel_iteration,
    ),
    preserve_const_enums: merge_option(
      override_.preserve_const_enums,
      base.preserve_const_enums,
    ),
    jsx: merge_option(override_.jsx, base.jsx),
    jsx_factory: merge_option(override_.jsx_factory, base.jsx_factory),
    jsx_fragment_factory: merge_option(
      override_.jsx_fragment_factory,
      base.jsx_fragment_factory,
    ),
    jsx_import_source: merge_option(
      override_.jsx_import_source,
      base.jsx_import_source,
    ),
    es_module_interop: merge_option(
      override_.es_module_interop,
      base.es_module_interop,
    ),
    allow_synthetic_default_imports: merge_option(
      override_.allow_synthetic_default_imports,
      base.allow_synthetic_default_imports,
    ),
    isolated_modules: merge_option(
      override_.isolated_modules,
      base.isolated_modules,
    ),
    verbatim_module_syntax: merge_option(
      override_.verbatim_module_syntax,
      base.verbatim_module_syntax,
    ),
    lib: merge_option(override_.lib, base.lib),
    no_lib: merge_option(override_.no_lib, base.no_lib),
    skip_lib_check: merge_option(override_.skip_lib_check, base.skip_lib_check),
    skip_default_lib_check: merge_option(
      override_.skip_default_lib_check,
      base.skip_default_lib_check,
    ),
    allow_js: merge_option(override_.allow_js, base.allow_js),
    check_js: merge_option(override_.check_js, base.check_js),
    experimental_decorators: merge_option(
      override_.experimental_decorators,
      base.experimental_decorators,
    ),
    emit_decorator_metadata: merge_option(
      override_.emit_decorator_metadata,
      base.emit_decorator_metadata,
    ),
    incremental: merge_option(override_.incremental, base.incremental),
    composite: merge_option(override_.composite, base.composite),
    ts_build_info_file: merge_option(
      override_.ts_build_info_file,
      base.ts_build_info_file,
    ),
  }
}

///|
/// Get effective target (with default)
pub fn get_effective_target(options : CompilerOptions) -> ScriptTarget {
  options.target.unwrap_or(ScriptTarget::ES2015)
}

///|
/// Get effective target as string for the compiler
pub fn get_target_string(options : CompilerOptions) -> String {
  get_effective_target(options).to_target_string()
}

///|
/// Check if source maps are enabled
pub fn is_source_map_enabled(options : CompilerOptions) -> Bool {
  options.source_map.unwrap_or(false) ||
  options.inline_source_map.unwrap_or(false)
}

///|
/// Check if declarations are enabled
pub fn is_declaration_enabled(options : CompilerOptions) -> Bool {
  options.declaration.unwrap_or(false)
}

///|
/// Check if strict mode is enabled (affects emit of "use strict")
pub fn is_strict_enabled(options : CompilerOptions) -> Bool {
  options.strict.unwrap_or(false) || options.always_strict.unwrap_or(false)
}

///|
/// Apply strict flag to individual strict options
pub fn apply_strict_flag(options : CompilerOptions) -> CompilerOptions {
  if !(options.strict.unwrap_or(false)) {
    return options
  }
  // When strict is true, set all strict-related flags to true if not explicitly set
  {
    ..options,
    no_implicit_any: Some(options.no_implicit_any.unwrap_or(true)),
    strict_null_checks: Some(options.strict_null_checks.unwrap_or(true)),
    strict_function_types: Some(options.strict_function_types.unwrap_or(true)),
    strict_bind_call_apply: Some(options.strict_bind_call_apply.unwrap_or(true)),
    strict_property_initialization: Some(
      options.strict_property_initialization.unwrap_or(true),
    ),
    no_implicit_this: Some(options.no_implicit_this.unwrap_or(true)),
    use_unknown_in_catch_variables: Some(
      options.use_unknown_in_catch_variables.unwrap_or(true),
    ),
    always_strict: Some(options.always_strict.unwrap_or(true)),
  }
}
