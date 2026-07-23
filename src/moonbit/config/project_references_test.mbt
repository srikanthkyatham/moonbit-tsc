// Tests for project references

///|
test "is_composite_project - returns true when composite is set" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  assert_true(is_composite_project(config))
}

///|
test "is_composite_project - returns false when not set" {
  let config = TSConfig::default()
  assert_false(is_composite_project(config))
}

///|
test "is_composite_project - returns false when explicitly false" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(false),
    }),
  }
  assert_false(is_composite_project(config))
}

///|
test "has_project_references - returns true when references exist" {
  let config : TSConfig = {
    ..TSConfig::default(),
    references: Some([{ path: "./packages/core", prepend: None }]),
  }
  assert_true(has_project_references(config))
}

///|
test "has_project_references - returns false when no references" {
  let config = TSConfig::default()
  assert_false(has_project_references(config))
}

///|
test "has_project_references - returns false when empty references" {
  let config : TSConfig = { ..TSConfig::default(), references: Some([]) }
  assert_false(has_project_references(config))
}

///|
test "get_project_out_dir - returns outDir when set" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      out_dir: Some("./dist"),
    }),
  }
  assert_eq(get_project_out_dir(config), Some("./dist"))
}

///|
test "get_project_out_dir - returns None when not set" {
  let config = TSConfig::default()
  assert_true(get_project_out_dir(config) is None)
}

///|
test "get_project_declaration_dir - prefers declarationDir" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      out_dir: Some("./dist"),
      declaration_dir: Some("./types"),
    }),
  }
  assert_eq(get_project_declaration_dir(config), Some("./types"))
}

///|
test "get_project_declaration_dir - falls back to outDir" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      out_dir: Some("./dist"),
    }),
  }
  assert_eq(get_project_declaration_dir(config), Some("./dist"))
}

///|
test "LoadedProject - can be created" {
  let config = TSConfig::default()
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: ["/project/packages/core/tsconfig.json"],
  }
  assert_eq(project.path, "/project/tsconfig.json")
  assert_eq(project.dependencies.length(), 1)
}

///|
test "ProjectGraph - can be created" {
  let config = TSConfig::default()
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [project],
    build_order: ["/project/tsconfig.json"],
  }
  assert_eq(graph.projects.length(), 1)
  assert_eq(graph.build_order.length(), 1)
}

///|
test "get_project_include - uses effective include" {
  let config : TSConfig = {
    ..TSConfig::default(),
    include_patterns: Some(["src/**/*"]),
  }
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  let incl_patterns = get_project_include(project)
  assert_eq(incl_patterns.length(), 1)
  assert_eq(incl_patterns[0], "src/**/*")
}

///|
test "get_project_exclude - uses effective exclude" {
  let config : TSConfig = {
    ..TSConfig::default(),
    exclude_patterns: Some(["node_modules", "dist"]),
  }
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  let exclude = get_project_exclude(project)
  assert_eq(exclude.length(), 2)
}

///|
test "get_project_files - returns files when set" {
  let config : TSConfig = {
    ..TSConfig::default(),
    files: Some(["src/index.ts", "src/utils.ts"]),
  }
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  guard get_project_files(project) is Some(files) else {
    assert_true(false)
    return
  }
  assert_eq(files.length(), 2)
}

// ============================================================================
// Project Validation Tests
// ============================================================================

///|
test "validate_project_graph - valid graph with composite projects" {
  // Create a composite project (the referenced one)
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
      declaration: Some(true),
      out_dir: Some("./dist"),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/packages/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }

  // Create the app project that references core
  let app_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      out_dir: Some("./dist"),
    }),
    references: Some([{ path: "../core", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/packages/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/packages/core/tsconfig.json"],
  }
  let graph : ProjectGraph = {
    projects: [core_project, app_project],
    build_order: [
      "/project/packages/core/tsconfig.json", "/project/packages/app/tsconfig.json",
    ],
  }
  let result = validate_project_graph(graph)
  assert_true(result.is_valid)
  assert_eq(result.errors.length(), 0)
}

///|
test "validate_project_graph - invalid: missing composite flag" {
  // Create a non-composite project (the referenced one)
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default()
      // composite is NOT set
      ,
      declaration: Some(true),
      out_dir: Some("./dist"),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/packages/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }

  // Create the app project that references core
  let app_config : TSConfig = {
    ..TSConfig::default(),
    references: Some([{ path: "../core", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/packages/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/packages/core/tsconfig.json"],
  }
  let graph : ProjectGraph = {
    projects: [core_project, app_project],
    build_order: [
      "/project/packages/core/tsconfig.json", "/project/packages/app/tsconfig.json",
    ],
  }
  let result = validate_project_graph(graph)
  assert_false(result.is_valid)
  assert_true(result.errors.length() > 0)
  // Should have MissingComposite error
  let has_missing_composite = result.errors
    .iter()
    .any(fn(e) { e is MissingComposite(_) })
  assert_true(has_missing_composite)
}

///|
test "validate_project_graph - warning for missing outDir" {
  // Create a project with references but no outDir
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/packages/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }

  // App project with references but no outDir
  let app_config : TSConfig = {
    ..TSConfig::default()
    // No compiler_options, so no outDir
    ,
    references: Some([{ path: "../core", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/packages/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/packages/core/tsconfig.json"],
  }
  let graph : ProjectGraph = {
    projects: [core_project, app_project],
    build_order: [
      "/project/packages/core/tsconfig.json", "/project/packages/app/tsconfig.json",
    ],
  }
  let result = validate_project_graph(graph)
  // Should have warnings about missing outDir
  assert_true(result.warnings.length() > 0)
}

// ============================================================================
// Cross-Project Module Resolution Tests
// ============================================================================

///|
test "build_project_resolution_map - builds map from graph" {
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
      out_dir: Some("./dist"),
      base_url: Some("."),
      paths: Some({ "@core/*": ["./src/*"] }),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/packages/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [core_project],
    build_order: ["/project/packages/core/tsconfig.json"],
  }
  let res_map = build_project_resolution_map(graph)
  assert_true(res_map.contains("/project/packages/core/tsconfig.json"))
  guard res_map.get("/project/packages/core/tsconfig.json") is Some(info) else {
    assert_true(false)
    return
  }
  assert_eq(info.project_dir, "/project/packages/core")
  assert_eq(info.declaration_dir, Some("./dist"))
  assert_eq(info.base_url, Some("."))
  assert_true(info.paths is Some(_))
}

///|
test "resolve_cross_project_import - relative imports return None" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
      out_dir: Some("./dist"),
    }),
  }
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  let project_map : Map[String, ReferencedProjectInfo] = Map([])

  // Relative imports should return None (handled by same-project resolution)
  let result = resolve_cross_project_import("./utils", project, project_map, fn(
    _,
  ) {
    false
  })
  assert_true(result is None)
  let result2 = resolve_cross_project_import(
    "../shared/utils",
    project,
    project_map,
    fn(_) { false },
  )
  assert_true(result2 is None)
}

///|
test "resolve_cross_project_import - resolves from dependency" {
  // Core project
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
      out_dir: Some("./dist"),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/packages/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }

  // App project depending on core
  let app_config : TSConfig = {
    ..TSConfig::default(),
    references: Some([{ path: "../core", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/packages/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/packages/core/tsconfig.json"],
  }

  // Build resolution map
  let graph : ProjectGraph = {
    projects: [core_project, app_project],
    build_order: [
      "/project/packages/core/tsconfig.json", "/project/packages/app/tsconfig.json",
    ],
  }
  let project_map = build_project_resolution_map(graph)

  // Mock file exists function - simulates utils.d.ts existing
  fn file_exists(path : String) -> Bool {
    path == "/project/packages/core/dist/utils.d.ts"
  }

  // Try to resolve "utils" from app project
  let result = resolve_cross_project_import(
    "utils", app_project, project_map, file_exists,
  )
  assert_eq(result, Some("/project/packages/core/dist/utils.d.ts"))
}

// ============================================================================
// Build Context Tests
// ============================================================================

///|
test "init_build_context - initializes all projects as NeedsBuild" {
  let config = TSConfig::default()
  let project1 : LoadedProject = {
    path: "/project/core/tsconfig.json",
    config,
    dependencies: [],
  }
  let project2 : LoadedProject = {
    path: "/project/app/tsconfig.json",
    config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [project1, project2],
    build_order: ["/project/core/tsconfig.json", "/project/app/tsconfig.json"],
  }
  let ctx = init_build_context(graph)
  assert_eq(ctx.states.length(), 2)
  guard ctx.states.get("/project/core/tsconfig.json") is Some(state1) else {
    assert_true(false)
    return
  }
  assert_true(state1.status is NeedsBuild)
  guard ctx.states.get("/project/app/tsconfig.json") is Some(state2) else {
    assert_true(false)
    return
  }
  assert_true(state2.status is NeedsBuild)
}

///|
test "get_next_project_to_build - returns first project with built deps" {
  // Core has no deps, app depends on core
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }
  let app_config : TSConfig = {
    ..TSConfig::default(),
    references: Some([{ path: "../core", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/core/tsconfig.json"],
  }
  let graph : ProjectGraph = {
    projects: [core_project, app_project],
    build_order: ["/project/core/tsconfig.json", "/project/app/tsconfig.json"],
  }
  let ctx = init_build_context(graph)

  // First project to build should be core (no deps)
  let next = get_next_project_to_build(ctx)
  assert_eq(next, Some("/project/core/tsconfig.json"))
}

///|
test "mark_project_built - updates status" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [project],
    build_order: ["/project/tsconfig.json"],
  }
  let ctx = init_build_context(graph)

  // Mark as built
  mark_project_built(ctx, "/project/tsconfig.json")
  guard ctx.states.get("/project/tsconfig.json") is Some(state) else {
    assert_true(false)
    return
  }
  assert_true(state.status is Built)
}

///|
test "mark_project_failed - updates status with error message" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let project : LoadedProject = {
    path: "/project/tsconfig.json",
    config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [project],
    build_order: ["/project/tsconfig.json"],
  }
  let ctx = init_build_context(graph)

  // Mark as failed
  mark_project_failed(ctx, "/project/tsconfig.json", "Type error in index.ts")
  guard ctx.states.get("/project/tsconfig.json") is Some(state) else {
    assert_true(false)
    return
  }
  assert_true(state.status is Failed(_))
}

///|
test "all_projects_built - returns true when all built" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let project1 : LoadedProject = {
    path: "/project/core/tsconfig.json",
    config,
    dependencies: [],
  }
  let project2 : LoadedProject = {
    path: "/project/app/tsconfig.json",
    config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [project1, project2],
    build_order: ["/project/core/tsconfig.json", "/project/app/tsconfig.json"],
  }
  let ctx = init_build_context(graph)

  // Initially not all built
  assert_false(all_projects_built(ctx))

  // Mark both as built
  mark_project_built(ctx, "/project/core/tsconfig.json")
  mark_project_built(ctx, "/project/app/tsconfig.json")

  // Now all should be built
  assert_true(all_projects_built(ctx))
}

///|
test "get_failed_projects - returns list of failed projects" {
  let config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let project1 : LoadedProject = {
    path: "/project/core/tsconfig.json",
    config,
    dependencies: [],
  }
  let project2 : LoadedProject = {
    path: "/project/app/tsconfig.json",
    config,
    dependencies: [],
  }
  let graph : ProjectGraph = {
    projects: [project1, project2],
    build_order: ["/project/core/tsconfig.json", "/project/app/tsconfig.json"],
  }
  let ctx = init_build_context(graph)

  // Mark core as built, app as failed
  mark_project_built(ctx, "/project/core/tsconfig.json")
  mark_project_failed(ctx, "/project/app/tsconfig.json", "Build error")
  let failed = get_failed_projects(ctx)
  assert_eq(failed.length(), 1)
  assert_eq(failed[0], "/project/app/tsconfig.json")
}

///|
test "get_next_project_to_build - respects dependency order" {
  // Core has no deps, ui depends on core, app depends on ui
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }
  let ui_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
    }),
    references: Some([{ path: "../core", prepend: None }]),
  }
  let ui_project : LoadedProject = {
    path: "/project/ui/tsconfig.json",
    config: ui_config,
    dependencies: ["/project/core/tsconfig.json"],
  }
  let app_config : TSConfig = {
    ..TSConfig::default(),
    references: Some([{ path: "../ui", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/ui/tsconfig.json"],
  }
  let graph : ProjectGraph = {
    projects: [core_project, ui_project, app_project],
    build_order: [
      "/project/core/tsconfig.json", "/project/ui/tsconfig.json", "/project/app/tsconfig.json",
    ],
  }
  let ctx = init_build_context(graph)

  // First should be core
  let next1 = get_next_project_to_build(ctx)
  assert_eq(next1, Some("/project/core/tsconfig.json"))

  // After building core, next should be ui
  mark_project_built(ctx, "/project/core/tsconfig.json")
  let next2 = get_next_project_to_build(ctx)
  assert_eq(next2, Some("/project/ui/tsconfig.json"))

  // After building ui, next should be app
  mark_project_built(ctx, "/project/ui/tsconfig.json")
  let next3 = get_next_project_to_build(ctx)
  assert_eq(next3, Some("/project/app/tsconfig.json"))

  // After building app, no more projects to build
  mark_project_built(ctx, "/project/app/tsconfig.json")
  let next4 = get_next_project_to_build(ctx)
  assert_true(next4 is None)
}

// ============================================================================
// Pattern Matching Tests (Internal Helper Functions via Public API)
// ============================================================================

///|
test "resolve_cross_project_import - paths mapping resolution" {
  // Core project with paths mapping
  let core_config : TSConfig = {
    ..TSConfig::default(),
    compiler_options: Some({
      ..CompilerOptions::default(),
      composite: Some(true),
      out_dir: Some("./dist"),
      base_url: Some("."),
      paths: Some({ "@core/*": ["./src/*"] }),
    }),
  }
  let core_project : LoadedProject = {
    path: "/project/packages/core/tsconfig.json",
    config: core_config,
    dependencies: [],
  }

  // App project depending on core
  let app_config : TSConfig = {
    ..TSConfig::default(),
    references: Some([{ path: "../core", prepend: None }]),
  }
  let app_project : LoadedProject = {
    path: "/project/packages/app/tsconfig.json",
    config: app_config,
    dependencies: ["/project/packages/core/tsconfig.json"],
  }
  let graph : ProjectGraph = {
    projects: [core_project, app_project],
    build_order: [
      "/project/packages/core/tsconfig.json", "/project/packages/app/tsconfig.json",
    ],
  }
  let project_map = build_project_resolution_map(graph)

  // Mock file exists - core has utils under @core path
  fn file_exists(path : String) -> Bool {
    path == "/project/packages/core/dist/src/utils.d.ts"
  }

  // Try to resolve "@core/utils" from app project
  let result = resolve_cross_project_import(
    "@core/utils", app_project, project_map, file_exists,
  )
  assert_eq(result, Some("/project/packages/core/dist/src/utils.d.ts"))
}

///|
test "ProjectValidationError - constructors" {
  let e1 = make_missing_composite("/path")
  assert_true(e1 is MissingComposite(_))
  let e2 = make_missing_declaration("/path")
  assert_true(e2 is MissingDeclaration(_))
  let e3 = make_circular_reference("/path")
  assert_true(e3 is CircularReference(_))
  let e4 = make_project_not_found("/path")
  assert_true(e4 is ProjectNotFound(_))
  let e5 = make_invalid_reference_path("/path")
  assert_true(e5 is InvalidReferencePath(_))
}

///|
test "ProjectBuildStatus - constructors" {
  let s1 = make_needs_build()
  assert_true(s1 is NeedsBuild)
  let s2 = make_up_to_date()
  assert_true(s2 is UpToDate)
  let s3 = make_built()
  assert_true(s3 is Built)
  let s4 = make_failed("error")
  assert_true(s4 is Failed(_))
}

///|
test "ValidationResult - constructor" {
  let result = make_validation_result(true, [], ["warning1"])
  assert_true(result.is_valid)
  assert_eq(result.errors.length(), 0)
  assert_eq(result.warnings.length(), 1)
}

///|
test "ReferencedProjectInfo - constructor" {
  let info = make_referenced_project_info(
    "/project/tsconfig.json",
    "/project",
    Some("./dist"),
    Some("."),
    Some({ "@/*": ["./src/*"] }),
  )
  assert_eq(info.tsconfig_path, "/project/tsconfig.json")
  assert_eq(info.project_dir, "/project")
  assert_eq(info.declaration_dir, Some("./dist"))
  assert_eq(info.base_url, Some("."))
  assert_true(info.paths is Some(_))
}

///|
test "ProjectDeclarations - constructor" {
  let decls = make_project_declarations("/project/tsconfig.json", [
    "/project/dist/index.d.ts", "/project/dist/utils.d.ts",
  ])
  assert_eq(decls.project_path, "/project/tsconfig.json")
  assert_eq(decls.declaration_files.length(), 2)
}

///|
test "ProjectBuildState - constructor" {
  let state = make_project_build_state(
    "/project/tsconfig.json",
    NeedsBuild,
    12345L,
  )
  assert_eq(state.project_path, "/project/tsconfig.json")
  assert_true(state.status is NeedsBuild)
  assert_eq(state.source_hash, 12345L)
}

///|
test "BuildContext - constructor" {
  let graph : ProjectGraph = { projects: [], build_order: [] }
  let states : Map[String, ProjectBuildState] = Map([])
  let validation = make_validation_result(true, [], [])
  let ctx = make_build_context(graph, states, validation)
  assert_eq(ctx.graph.projects.length(), 0)
  assert_eq(ctx.states.length(), 0)
  assert_true(ctx.validation.is_valid)
}
