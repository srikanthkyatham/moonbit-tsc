// Tests for file-set-backed module resolution (T6):
// ModuleResolver::with_file_set + validate_multi_file_imports

// ============================================================================
// ModuleResolver::with_file_set — relative specifier resolution
// ============================================================================

///|
test "unit/module-resolver/fileset - resolves ./b to b.ts" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/b.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("./b", "/proj/a.ts") {
    Ok(resolved) => assert_eq(resolved.resolved_file_name, "/proj/b.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - resolves ./decl to decl.d.ts" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/main.ts", "/proj/decl.d.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("./decl", "/proj/main.ts") {
    Ok(resolved) => assert_eq(resolved.resolved_file_name, "/proj/decl.d.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - resolves ./sub to directory index" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/main.ts", "/proj/sub/index.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("./sub", "/proj/main.ts") {
    Ok(resolved) => assert_eq(resolved.resolved_file_name, "/proj/sub/index.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - resolves ../shared from nested dir" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/src/deep/a.ts", "/proj/src/shared.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("../shared", "/proj/src/deep/a.ts") {
    Ok(resolved) => assert_eq(resolved.resolved_file_name, "/proj/src/shared.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - substitutes ./b.js to b.ts" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/b.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("./b.js", "/proj/a.ts") {
    Ok(resolved) => assert_eq(resolved.resolved_file_name, "/proj/b.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - prefers .ts over index and d.ts" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/b.ts", "/proj/b.d.ts", "/proj/b/index.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("./b", "/proj/a.ts") {
    Ok(resolved) => assert_eq(resolved.resolved_file_name, "/proj/b.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - missing module reports searched candidates" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("./missing", "/proj/a.ts") {
    Ok(_) => assert_true(false)
    Err(@compiler.ModuleNotFound(spec, searched)) => {
      assert_eq(spec, "./missing")
      assert_true(searched.iter().any(fn(s) { s == "/proj/missing.ts" }))
      assert_true(searched.iter().any(fn(s) { s == "/proj/missing/index.ts" }))
    }
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// validate_multi_file_imports — cross-file import validation
// ============================================================================

///|
test "unit/multi-file-imports - valid imports produce no diagnostics" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"./b\";\nconst y = x;"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
}

///|
test "unit/multi-file-imports - missing member reports TS2305" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { nope } from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2305)
}

///|
test "unit/multi-file-imports - close misspelling reports TS2724 with suggestion" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { valeu } from \"./b\";"),
    ("/t/b.ts", "export const value: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2724)
  assert_true(v.diagnostics[0].message.contains("value"))
}

///|
test "unit/multi-file-imports - missing default export reports TS1192" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import b from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 1192)
}

///|
test "unit/multi-file-imports - unresolved relative import is deferred, not diagnosed" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"./missing\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 1)
  assert_eq(v.unresolved[0].specifier, "./missing")
  assert_eq(v.unresolved[0].file_path, "/t/a.ts")
  assert_true(
    v.unresolved[0].candidates.iter().any(fn(s) { s == "/t/missing.ts" }),
  )
}

///|
test "unit/multi-file-imports - import resolves through d.ts" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { n } from \"./decl\";"),
    ("/t/decl.d.ts", "export declare const n: number;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.unresolved.length(), 0)
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/multi-file-imports - export star from missing module is deferred" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "export * from \"./gone\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.unresolved.length(), 1)
  assert_eq(v.unresolved[0].specifier, "./gone")
}

///|
test "unit/multi-file-imports - non-relative imports are skipped" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import * as fs from \"fs\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
}

///|
test "unit/multi-file-imports - import equals require skips default validation" {
  // import x = require('./b') binds the whole module: no TS1192 even when
  // ./b has no default export
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import b = require(\"./b\");"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
}
