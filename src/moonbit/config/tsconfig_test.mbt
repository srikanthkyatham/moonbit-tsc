// Tests for TSConfig parsing

///|
test "ScriptTarget::from_string - parses valid targets" {
  assert_eq(ScriptTarget::from_string("es5"), Some(ScriptTarget::ES5))
  assert_eq(ScriptTarget::from_string("ES5"), Some(ScriptTarget::ES5))
  assert_eq(ScriptTarget::from_string("es2015"), Some(ScriptTarget::ES2015))
  assert_eq(ScriptTarget::from_string("es6"), Some(ScriptTarget::ES2015))
  assert_eq(ScriptTarget::from_string("esnext"), Some(ScriptTarget::ESNext))
  assert_eq(ScriptTarget::from_string("ESNext"), Some(ScriptTarget::ESNext))
}

///|
test "ScriptTarget::from_string - returns None for invalid" {
  assert_true(ScriptTarget::from_string("invalid") is None)
  assert_true(ScriptTarget::from_string("es4") is None)
}

///|
test "ScriptTarget::to_target_string - converts correctly" {
  assert_eq(ScriptTarget::ES5.to_target_string(), "es5")
  assert_eq(ScriptTarget::ES2015.to_target_string(), "es2015")
  assert_eq(ScriptTarget::ESNext.to_target_string(), "esnext")
}

///|
test "ModuleKind::from_string - parses valid modules" {
  assert_eq(ModuleKind::from_string("commonjs"), Some(ModuleKind::CommonJS))
  assert_eq(ModuleKind::from_string("es2015"), Some(ModuleKind::ES2015))
  assert_eq(ModuleKind::from_string("es6"), Some(ModuleKind::ES2015))
  assert_eq(ModuleKind::from_string("esnext"), Some(ModuleKind::ESNext))
  assert_eq(ModuleKind::from_string("nodenext"), Some(ModuleKind::NodeNext))
}

///|
test "JsxEmit::from_string - parses valid jsx modes" {
  assert_eq(JsxEmit::from_string("preserve"), Some(JsxEmit::Preserve))
  assert_eq(JsxEmit::from_string("react"), Some(JsxEmit::React))
  assert_eq(JsxEmit::from_string("react-jsx"), Some(JsxEmit::ReactJSX))
  assert_eq(JsxEmit::from_string("react-native"), Some(JsxEmit::ReactNative))
}

///|
test "CompilerOptions::default - creates empty options" {
  let opts = CompilerOptions::default()
  assert_true(opts.target is None)
  assert_true(opts.module_kind is None)
  assert_true(opts.out_dir is None)
  assert_true(opts.source_map is None)
  assert_true(opts.declaration is None)
}

///|
test "merge_compiler_options - override takes precedence" {
  let base : CompilerOptions = {
    ..CompilerOptions::default(),
    target: Some(ScriptTarget::ES5),
    source_map: Some(true),
    declaration: Some(false),
  }
  let override_ : CompilerOptions = {
    ..CompilerOptions::default(),
    target: Some(ScriptTarget::ES2020),
    declaration: Some(true),
  }
  let merged = merge_compiler_options(base, override_)
  assert_eq(merged.target, Some(ScriptTarget::ES2020))
  assert_eq(merged.source_map, Some(true)) // From base
  assert_eq(merged.declaration, Some(true)) // From override
}

///|
test "merge_compiler_options - base fills in missing" {
  let base : CompilerOptions = {
    ..CompilerOptions::default(),
    out_dir: Some("./dist"),
    strict: Some(true),
  }
  let override_ = CompilerOptions::default()
  let merged = merge_compiler_options(base, override_)
  assert_eq(merged.out_dir, Some("./dist"))
  assert_eq(merged.strict, Some(true))
}

///|
test "get_effective_target - returns default when not set" {
  let opts = CompilerOptions::default()
  assert_eq(get_effective_target(opts), ScriptTarget::ES2015)
}

///|
test "get_effective_target - returns set value" {
  let opts : CompilerOptions = {
    ..CompilerOptions::default(),
    target: Some(ScriptTarget::ES5),
  }
  assert_eq(get_effective_target(opts), ScriptTarget::ES5)
}

///|
test "is_source_map_enabled - checks both options" {
  let opts1 = CompilerOptions::default()
  assert_eq(is_source_map_enabled(opts1), false)
  let opts2 : CompilerOptions = {
    ..CompilerOptions::default(),
    source_map: Some(true),
  }
  assert_eq(is_source_map_enabled(opts2), true)
  let opts3 : CompilerOptions = {
    ..CompilerOptions::default(),
    inline_source_map: Some(true),
  }
  assert_eq(is_source_map_enabled(opts3), true)
}

///|
test "apply_strict_flag - applies to all strict options" {
  let opts : CompilerOptions = {
    ..CompilerOptions::default(),
    strict: Some(true),
  }
  let applied = apply_strict_flag(opts)
  assert_eq(applied.no_implicit_any, Some(true))
  assert_eq(applied.strict_null_checks, Some(true))
  assert_eq(applied.strict_function_types, Some(true))
  assert_eq(applied.always_strict, Some(true))
}

///|
test "apply_strict_flag - preserves explicit false" {
  let opts : CompilerOptions = {
    ..CompilerOptions::default(),
    strict: Some(true),
    no_implicit_any: Some(false),
  }
  let applied = apply_strict_flag(opts)
  // Explicit false should be preserved (unwrap_or uses the existing value)
  assert_eq(applied.no_implicit_any, Some(false))
}

///|
test "parse_tsconfig_text - parses minimal config" {
  let json = "{}"
  let config = parse_tsconfig_text(json, "tsconfig.json")
  assert_true(config.compiler_options is None)
  assert_true(config.files is None)
  assert_true(config.include_patterns is None)
}

///|
test "parse_tsconfig_text - parses basic compiler options" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    "target": "es2020",
    #|    "module": "esnext",
    #|    "outDir": "./dist",
    #|    "sourceMap": true,
    #|    "declaration": true
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.target, Some(ScriptTarget::ES2020))
  assert_eq(opts.module_kind, Some(ModuleKind::ESNext))
  assert_eq(opts.out_dir, Some("./dist"))
  assert_eq(opts.source_map, Some(true))
  assert_eq(opts.declaration, Some(true))
}

///|
test "parse_tsconfig_text - parses strict options" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    "strict": true,
    #|    "noImplicitAny": true,
    #|    "strictNullChecks": false
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.strict, Some(true))
  assert_eq(opts.no_implicit_any, Some(true))
  assert_eq(opts.strict_null_checks, Some(false))
}

///|
test "parse_tsconfig_text - parses files array" {
  let json =
    #|{
    #|  "files": ["src/index.ts", "src/utils.ts"]
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.files is Some(files) else {
    assert_true(false)
    return
  }
  assert_eq(files.length(), 2)
  assert_eq(files[0], "src/index.ts")
  assert_eq(files[1], "src/utils.ts")
}

///|
test "parse_tsconfig_text - parses include/exclude" {
  let json =
    #|{
    #|  "include": ["src/**/*"],
    #|  "exclude": ["node_modules", "dist"]
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.include_patterns is Some(incl) else {
    assert_true(false)
    return
  }
  guard config.exclude_patterns is Some(excl) else {
    assert_true(false)
    return
  }
  assert_eq(incl.length(), 1)
  assert_eq(incl[0], "src/**/*")
  assert_eq(excl.length(), 2)
}

///|
test "parse_tsconfig_text - parses extends" {
  let json =
    #|{
    #|  "extends": "./base.json"
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  assert_eq(config.extends, Some("./base.json"))
}

///|
test "parse_tsconfig_text - parses paths" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    "baseUrl": ".",
    #|    "paths": {
    #|      "@/*": ["./src/*"],
    #|      "@utils/*": ["./src/utils/*"]
    #|    }
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.base_url, Some("."))
  guard opts.paths is Some(paths) else {
    assert_true(false)
    return
  }
  assert_true(paths.contains("@/*"))
  assert_true(paths.contains("@utils/*"))
}

///|
test "parse_tsconfig_text - parses jsx options" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    "jsx": "react-jsx",
    #|    "jsxImportSource": "react"
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.jsx, Some(JsxEmit::ReactJSX))
  assert_eq(opts.jsx_import_source, Some("react"))
}

///|
test "parse_tsconfig_text - parses project references" {
  let json =
    #|{
    #|  "references": [
    #|    { "path": "./packages/core" },
    #|    { "path": "./packages/utils", "prepend": true }
    #|  ]
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.references is Some(refs) else {
    assert_true(false)
    return
  }
  assert_eq(refs.length(), 2)
  assert_eq(refs[0].path, "./packages/core")
  assert_true(refs[0].prepend is None)
  assert_eq(refs[1].path, "./packages/utils")
  assert_eq(refs[1].prepend, Some(true))
}

///|
test "get_default_include - returns default patterns" {
  let incl = get_default_include()
  assert_eq(incl.length(), 1)
  assert_eq(incl[0], "**/*")
}

///|
test "get_default_exclude - returns default patterns without outDir" {
  let excl = get_default_exclude(None)
  assert_eq(excl.length(), 3)
  assert_true(excl.contains("node_modules"))
}

///|
test "get_default_exclude - includes outDir when set" {
  let excl = get_default_exclude(Some("dist"))
  assert_eq(excl.length(), 4)
  assert_true(excl.contains("dist"))
}

///|
test "get_effective_include - uses default when not set" {
  let config = TSConfig::default()
  let incl = get_effective_include(config)
  assert_eq(incl[0], "**/*")
}

///|
test "get_effective_include - uses config value when set" {
  let config : TSConfig = {
    ..TSConfig::default(),
    include_patterns: Some(["src/**/*.ts"]),
  }
  let incl = get_effective_include(config)
  assert_eq(incl.length(), 1)
  assert_eq(incl[0], "src/**/*.ts")
}

///|
test "get_effective_include - returns empty when files is set" {
  let config : TSConfig = {
    ..TSConfig::default(),
    files: Some(["src/index.ts"]),
  }
  let incl = get_effective_include(config)
  assert_eq(incl.length(), 0)
}

///|
test "has_files_list - returns false when not set" {
  let config = TSConfig::default()
  assert_eq(has_files_list(config), false)
}

///|
test "has_files_list - returns false when empty" {
  let config : TSConfig = { ..TSConfig::default(), files: Some([]) }
  assert_eq(has_files_list(config), false)
}

///|
test "has_files_list - returns true when has files" {
  let config : TSConfig = { ..TSConfig::default(), files: Some(["index.ts"]) }
  assert_eq(has_files_list(config), true)
}

///|
test "merge_tsconfigs - merges compiler options" {
  let base : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      target: Some(ScriptTarget::ES5),
      source_map: Some(true),
    }),
  }
  let override_ : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      target: Some(ScriptTarget::ES2020),
      declaration: Some(true),
    }),
  }
  let merged = merge_tsconfigs(base, override_)
  guard merged.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  // Override takes precedence for target
  assert_eq(opts.target, Some(ScriptTarget::ES2020))
  // Base fills in source_map
  assert_eq(opts.source_map, Some(true))
  // Override adds declaration
  assert_eq(opts.declaration, Some(true))
}

///|
test "merge_tsconfigs - files override replaces base" {
  let base : TSConfig = { ..TSConfig::default(), files: Some(["base.ts"]) }
  let override_ : TSConfig = {
    ..TSConfig::default(),
    files: Some(["override.ts"]),
  }
  let merged = merge_tsconfigs(base, override_)
  guard merged.files is Some(files) else {
    assert_true(false)
    return
  }
  assert_eq(files.length(), 1)
  assert_eq(files[0], "override.ts")
}

///|
test "merge_tsconfigs - preserves base when override not set" {
  let base : TSConfig = {
    ..TSConfig::default(),
    files: Some(["base.ts"]),
    include_patterns: Some(["src/**/*"]),
    exclude_patterns: Some(["node_modules"]),
  }
  let override_ = TSConfig::default()
  let merged = merge_tsconfigs(base, override_)
  guard merged.files is Some(files) else {
    assert_true(false)
    return
  }
  assert_eq(files[0], "base.ts")
  guard merged.include_patterns is Some(incl) else {
    assert_true(false)
    return
  }
  assert_eq(incl[0], "src/**/*")
}

///|
test "merge_tsconfigs - clears extends after merge" {
  let base : TSConfig = { ..TSConfig::default(), extends: Some("./other.json") }
  let override_ : TSConfig = {
    ..TSConfig::default(),
    extends: Some("./base.json"),
  }
  let merged = merge_tsconfigs(base, override_)
  assert_true(merged.extends is None)
}

///|
test "parse_tsconfig_text - full realistic config" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    "target": "es2020",
    #|    "module": "es2020",
    #|    "lib": ["es2020", "dom"],
    #|    "outDir": "./dist",
    #|    "rootDir": "./src",
    #|    "strict": true,
    #|    "esModuleInterop": true,
    #|    "skipLibCheck": true,
    #|    "forceConsistentCasingInFileNames": true,
    #|    "declaration": true,
    #|    "declarationMap": true,
    #|    "sourceMap": true,
    #|    "moduleResolution": "bundler",
    #|    "resolveJsonModule": true
    #|  },
    #|  "include": ["src/**/*"],
    #|  "exclude": ["node_modules", "dist", "**/*.test.ts"]
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  // Verify key options
  assert_eq(opts.target, Some(ScriptTarget::ES2020))
  assert_eq(opts.module_kind, Some(ModuleKind::ES2020))
  assert_eq(opts.out_dir, Some("./dist"))
  assert_eq(opts.root_dir, Some("./src"))
  assert_eq(opts.strict, Some(true))
  assert_eq(opts.es_module_interop, Some(true))
  assert_eq(opts.skip_lib_check, Some(true))
  assert_eq(opts.declaration, Some(true))
  assert_eq(opts.declaration_map, Some(true))
  assert_eq(opts.source_map, Some(true))
  assert_eq(opts.module_resolution, Some(ModuleResolutionKind::Bundler))
  assert_eq(opts.resolve_json_module, Some(true))

  // Verify lib array
  guard opts.lib is Some(lib) else {
    assert_true(false)
    return
  }
  assert_eq(lib.length(), 2)
  assert_eq(lib[0], "es2020")
  assert_eq(lib[1], "dom")

  // Verify include/exclude
  guard config.include_patterns is Some(incl) else {
    assert_true(false)
    return
  }
  assert_eq(incl.length(), 1)
  guard config.exclude_patterns is Some(excl) else {
    assert_true(false)
    return
  }
  assert_eq(excl.length(), 3)
}

///|
test "parse_tsconfig_text - handles single-line comments" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    // This is a comment
    #|    "target": "es2020"
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.target, Some(ScriptTarget::ES2020))
}

///|
test "parse_tsconfig_text - handles multi-line comments" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    /* This setting controls
    #|       the ECMAScript target */
    #|    "target": "es2020"
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.target, Some(ScriptTarget::ES2020))
}

///|
test "parse_tsconfig_text - handles trailing comments" {
  let json =
    #|{
    #|  "compilerOptions": {
    #|    "target": "es2020" // Set the target
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.target, Some(ScriptTarget::ES2020))
}

///|
test "parse_tsconfig_text - real world config with comments" {
  // This matches the actual tsconfig.json that was causing issues
  let json =
    #|{
    #|  "include": [
    #|    "**/*.ts",
    #|    "**/*.tsx"
    #|  ],
    #|  "compilerOptions": {
    #|    "lib": ["DOM", "ES2022"],
    #|    "types": ["vite/client"],
    #|    "isolatedModules": true,
    #|    "esModuleInterop": true,
    #|    "jsx": "react-jsx",
    #|    "module": "ESNext",
    #|    "moduleResolution": "Bundler",
    #|    "resolveJsonModule": true,
    #|    "target": "ES2022",
    #|    "strict": true,
    #|    "allowJs": true,
    #|    "skipLibCheck": true,
    #|    "baseUrl": ".",
    #|    "paths": {
    #|      "~/*": ["./app/*"]
    #|    },
    #|
    #|    // Vite takes care of building everything, not tsc.
    #|    "noEmit": true
    #|  }
    #|}
  let config = parse_tsconfig_text(json, "tsconfig.json")
  guard config.compiler_options is Some(opts) else {
    assert_true(false)
    return
  }
  assert_eq(opts.target, Some(ScriptTarget::ES2022))
  assert_eq(opts.no_emit, Some(true))
  assert_eq(opts.jsx, Some(JsxEmit::ReactJSX))
  assert_eq(opts.isolated_modules, Some(true))
}
