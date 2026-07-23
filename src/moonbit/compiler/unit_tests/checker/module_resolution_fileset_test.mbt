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
test "unit/multi-file-imports - unresolvable bare import is deferred to caller" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import * as fs from \"fs\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
  assert_eq(v.resolved_bare.length(), 0)
  assert_eq(v.unresolved_bare.length(), 1)
  assert_eq(v.unresolved_bare[0].specifier, "fs")
  // The per-file checker reports TS2307 for `import ... from` sites
  assert_true(v.unresolved_bare[0].checker_reports)
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

// ============================================================================
// ModuleResolver::with_file_set — bare specifier (node_modules) resolution
// ============================================================================

///|
test "unit/module-resolver/fileset - bare pkg resolves to node_modules index.d.ts" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/node_modules/pkg/index.d.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("pkg", "/proj/a.ts") {
    Ok(resolved) =>
      assert_eq(resolved.resolved_file_name, "/proj/node_modules/pkg/index.d.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - bare pkg walks up to parent node_modules" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/src/deep/a.ts", "/proj/node_modules/pkg/index.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("pkg", "/proj/src/deep/a.ts") {
    Ok(resolved) =>
      assert_eq(resolved.resolved_file_name, "/proj/node_modules/pkg/index.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - bare pkg subpath resolves with extension" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/node_modules/pkg/lib/util.d.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("pkg/lib/util", "/proj/a.ts") {
    Ok(resolved) =>
      assert_eq(
        resolved.resolved_file_name,
        "/proj/node_modules/pkg/lib/util.d.ts",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - falls back to @types package" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/node_modules/@types/pkg/index.d.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("pkg", "/proj/a.ts") {
    Ok(resolved) =>
      assert_eq(
        resolved.resolved_file_name,
        "/proj/node_modules/@types/pkg/index.d.ts",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - scoped pkg mangles to @types/scope__pkg" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/node_modules/@types/be__bop/index.d.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("@be/bop", "/proj/a.ts") {
    Ok(resolved) =>
      assert_eq(
        resolved.resolved_file_name,
        "/proj/node_modules/@types/be__bop/index.d.ts",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - scoped @types subpath resolves" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    ["/proj/a.ts", "/proj/node_modules/@types/be__bop/e/z.d.ts"],
    "/proj",
  )
  match resolver.resolve_module_name("@be/bop/e/z", "/proj/a.ts") {
    Ok(resolved) =>
      assert_eq(
        resolved.resolved_file_name,
        "/proj/node_modules/@types/be__bop/e/z.d.ts",
      )
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver/fileset - package itself wins over @types at same level" {
  let resolver = @compiler.ModuleResolver::with_file_set(
    [
      "/proj/a.ts",
      "/proj/node_modules/pkg/index.d.ts",
      "/proj/node_modules/@types/pkg/index.d.ts",
    ],
    "/proj",
  )
  match resolver.resolve_module_name("pkg", "/proj/a.ts") {
    Ok(resolved) =>
      assert_eq(resolved.resolved_file_name, "/proj/node_modules/pkg/index.d.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "unit/module-resolver - mangle_scoped_package_name" {
  assert_eq(@compiler.mangle_scoped_package_name("@be/bop"), "be__bop")
  assert_eq(@compiler.mangle_scoped_package_name("@angular/core"), "angular__core")
  assert_eq(@compiler.mangle_scoped_package_name("lodash"), "lodash")
}

// ============================================================================
// validate_multi_file_imports — bare specifiers and ambient modules
// ============================================================================

///|
test "unit/multi-file-imports - bare import resolves via file-set node_modules" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"pkg\";"),
    ("/t/node_modules/pkg/index.d.ts", "export declare const x: number;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved_bare.length(), 0)
  assert_eq(v.resolved_bare.length(), 1)
  assert_eq(v.resolved_bare[0].specifier, "pkg")
  assert_eq(
    v.resolved_bare[0].resolved_path,
    Some("/t/node_modules/pkg/index.d.ts"),
  )
}

///|
test "unit/multi-file-imports - bare import validates members (TS2305)" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { nope } from \"pkg\";"),
    ("/t/node_modules/pkg/index.d.ts", "export declare const x: number;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2305)
}

///|
test "unit/multi-file-imports - ambient module declaration satisfies bare import" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"foo\";"),
    (
      "/t/decl.d.ts",
      "declare module \"foo\" { export const x: number; }",
    ),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved_bare.length(), 0)
  assert_eq(v.resolved_bare.length(), 1)
  assert_eq(v.resolved_bare[0].specifier, "foo")
  assert_true(v.resolved_bare[0].resolved_path is None)
}

///|
test "unit/multi-file-imports - wildcard ambient module matches" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"config/prod\";"),
    ("/t/decl.d.ts", "declare module \"config/*\";"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.unresolved_bare.length(), 0)
  assert_eq(v.resolved_bare.length(), 1)
}

///|
test "unit/multi-file-imports - import equals bare specifier is deferred without checker report" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import foo = require(\"gone\");"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.unresolved_bare.length(), 1)
  assert_eq(v.unresolved_bare[0].specifier, "gone")
  // The per-file checker does not report TS2307 for import= sites
  assert_true(!(v.unresolved_bare[0].checker_reports))
}

///|
test "unit/multi-file-imports - export from bare specifier is deferred" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "export * from \"gone\";"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.unresolved_bare.length(), 1)
  assert_eq(v.unresolved_bare[0].specifier, "gone")
  assert_true(!(v.unresolved_bare[0].checker_reports))
}

///|
test "unit/multi-file-imports - dot specifier resolves and is recorded for suppression" {
  let files : Array[(String, String)] = [
    ("/t/a/b.ts", "import { indexInA } from \".\";"),
    ("/t/a/index.ts", "export const indexInA = 0;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
  // "." resolves relatively, but the checker treats it as a bare specifier,
  // so the resolution is recorded for TS2307 suppression
  assert_eq(v.resolved_bare.length(), 1)
  assert_eq(v.resolved_bare[0].specifier, ".")
  assert_eq(v.resolved_bare[0].resolved_path, Some("/t/a/index.ts"))
}

///|
test "unit/multi-file-imports - ambient module names collected and matched" {
  let files : Array[(String, String)] = [
    (
      "/t/decl.d.ts",
      "declare module \"one\" {}\ndeclare module \"two\" { export const b: string; }",
    ),
    ("/t/a.ts", "import \"one\";\nimport { b } from \"two\";"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.resolved_bare.length(), 2)
  assert_eq(v.unresolved_bare.length(), 0)
}
