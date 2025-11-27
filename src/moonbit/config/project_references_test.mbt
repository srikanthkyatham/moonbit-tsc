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
