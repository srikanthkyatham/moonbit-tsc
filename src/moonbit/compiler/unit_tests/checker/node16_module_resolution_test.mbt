// Unit tests for node16/nodenext module-resolution rules in
// validate_multi_file_imports:
// - ESM-format relative imports need explicit extensions (TS2835/TS2834)
// - "./" / "../" specifiers are unresolvable in ESM (TS2307)
// - CJS-format files may not `import` ES modules (TS1479, node16/node18)
// - require-semantics sites may not resolve to ES modules (TS1471)
// - import.meta is not allowed in CJS-format files (TS1470)
// - bare specifiers skip file-set resolution (deferred to the caller's
//   exports-aware filesystem resolution)

///|
fn node16_formats(
  entries : Array[(String, @compiler.ModuleFormat)],
) -> Map[String, @compiler.ModuleFormat] {
  let m : Map[String, @compiler.ModuleFormat] = Map([])
  for e in entries {
    m.set(e.0, e.1)
  }
  m
}

///|
test "unit/node16 - extensionless relative import in ESM file reports TS2835" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2835)
  assert_true(v.diagnostics[0].message.contains("./b.js"))
}

///|
test "unit/node16 - directory relative import in ESM file reports TS2834" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"./sub\";"),
    ("/t/sub/index.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2834)
}

///|
test "unit/node16 - './' import in ESM file reports TS2307" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import * as m from \"./\";"),
    ("/t/index.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2307)
}

///|
test "unit/node16 - explicit .js extension resolves to .ts source in ESM" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"./b.js\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
}

///|
test "unit/node16 - explicit .mjs extension resolves to .mts source" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"./b.mjs\";"),
    ("/t/b.mts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/node16 - CJS file importing ESM file reports TS1479" {
  let files : Array[(String, String)] = [
    ("/t/index.cts", "import { x } from \"./b.mjs\";"),
    ("/t/b.mts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 1479)
}

///|
test "unit/node16 - TS1479 not reported when require(esm) is allowed (node20+)" {
  let files : Array[(String, String)] = [
    ("/t/index.cts", "import { x } from \"./b.mjs\";"),
    ("/t/b.mts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(
    files,
    node16=true,
    cjs_require_esm_errors=false,
  )
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/node16 - type-only import from CJS to ESM has no TS1479" {
  let files : Array[(String, String)] = [
    ("/t/index.cts", "import type { X } from \"./b.mjs\";"),
    ("/t/b.mts", "export type X = number;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/node16 - import equals require of ESM reports TS1471" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import b = require(\"./b\");"),
    ("/t/b.mts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 1471)
}

///|
test "unit/node16 - CJS extensionless relative import resolves (no 2835)" {
  // require semantics keep extension/index resolution
  let files : Array[(String, String)] = [
    ("/t/index.cts", "import { x } from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/node16 - .ts file format comes from the caller's format map" {
  // /t/index.ts marked ESM (e.g. package.json "type": "module"): the
  // extension rules apply even though the extension alone says nothing
  let files : Array[(String, String)] = [
    ("/t/index.ts", "import { x } from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let formats = node16_formats([
    ("/t/index.ts", @compiler.ModuleFormat::esm()),
    ("/t/b.ts", @compiler.ModuleFormat::esm()),
  ])
  let v = @compiler.validate_multi_file_imports(
    files,
    node16=true,
    file_formats=formats,
  )
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 2835)
}

///|
test "unit/node16 - import.meta in CJS-format file reports TS1470" {
  let files : Array[(String, String)] = [
    ("/t/index.cts", "const u = import.meta.url;\nexport const x = u;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 1)
  assert_eq(v.diagnostics[0].code, 1470)
}

///|
test "unit/node16 - import.meta in ESM-format file is allowed" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "const u = import.meta.url;\nexport const x = u;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/node16 - bare specifiers skip file-set resolution" {
  // Under node16, exports maps gate bare-package resolution, so even a
  // file-set hit under node_modules is deferred to the caller
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"pkg\";"),
    ("/t/node_modules/pkg/index.d.ts", "export declare const x: number;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.resolved_bare.length(), 0)
  assert_eq(v.unresolved_bare.length(), 1)
  assert_eq(v.unresolved_bare[0].specifier, "pkg")
  assert_true(v.unresolved_bare[0].importer_esm)
  assert_true(!(v.unresolved_bare[0].require_like))
}

///|
test "unit/node16 - hash specifier is deferred with importer format" {
  let files : Array[(String, String)] = [
    ("/t/index.cts", "import { x } from \"#thing\";"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.unresolved_bare.length(), 1)
  assert_eq(v.unresolved_bare[0].specifier, "#thing")
  assert_true(!(v.unresolved_bare[0].importer_esm))
}

///|
test "unit/node16 - ambient module still matches under node16" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"fancy\";"),
    ("/t/decl.d.ts", "declare module \"fancy\" { export const x: number; }"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.unresolved_bare.length(), 0)
  assert_eq(v.resolved_bare.length(), 1)
  assert_eq(v.resolved_bare[0].specifier, "fancy")
}

///|
test "unit/node16 - default import from CJS-format target skips TS1192" {
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import mod from \"./sub/index.js\";"),
    ("/t/sub/index.ts", "export const a: number = 1;"),
  ]
  let formats = node16_formats([
    ("/t/index.mts", @compiler.ModuleFormat::esm()),
    ("/t/sub/index.ts", @compiler.ModuleFormat::cjs()),
  ])
  let v = @compiler.validate_multi_file_imports(
    files,
    node16=true,
    file_formats=formats,
  )
  assert_eq(v.diagnostics.length(), 0)
}

///|
test "unit/node16 - declare global value names are collected per file" {
  let files : Array[(String, String)] = [
    (
      "/t/globals.d.ts",
      "export {};\ndeclare global {\n  var foo: number;\n  function bar(): void;\n}",
    ),
    ("/t/index.mts", "export const x = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files, node16=true)
  assert_eq(v.global_value_names.length(), 2)
  assert_eq(v.global_value_names[0].0, "/t/globals.d.ts")
  assert_eq(v.global_value_names[0].1, "foo")
  assert_eq(v.global_value_names[1].1, "bar")
}

///|
test "unit/node16 - node10 mode is unchanged by default" {
  // Same input as the TS2835 test, but without node16: extensionless
  // relative imports resolve normally
  let files : Array[(String, String)] = [
    ("/t/index.mts", "import { x } from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let v = @compiler.validate_multi_file_imports(files)
  assert_eq(v.diagnostics.length(), 0)
  assert_eq(v.unresolved.length(), 0)
}
