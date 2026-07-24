// Tests for the node16/nodenext resolver's pure pieces:
// package.json parsing, exports/imports map matching (conditions,
// wildcards, blocked subpaths), and triple-slash types-reference scanning.

// ============================================================================
// parse_package_json_node16
// ============================================================================

///|
test "node16/package-json - basic fields" {
  let pkg = parse_package_json_node16(
    "{ \"name\": \"pkg\", \"types\": \"./index.d.ts\", \"main\": \"./index.js\", \"type\": \"module\" }",
  )
  match pkg {
    Some(p) => {
      assert_eq(p.name, Some("pkg"))
      assert_eq(p.types, Some("./index.d.ts"))
      assert_eq(p.main, Some("./index.js"))
      assert_eq(p.type_field, Some("module"))
      assert_true(p.exports is None)
      assert_true(p.imports is None)
    }
    None => fail("expected parsed package.json")
  }
}

///|
test "node16/package-json - typings fallback and empty string" {
  let pkg = parse_package_json_node16(
    "{ \"types\": \"\", \"typings\": \"./t.d.ts\" }",
  )
  match pkg {
    Some(p) => assert_eq(p.types, Some("./t.d.ts"))
    None => fail("expected parsed package.json")
  }
}

///|
test "node16/package-json - invalid json returns None" {
  assert_true(parse_package_json_node16("// comment\n{}") is None)
  assert_true(parse_package_json_node16("not json") is None)
}

// ============================================================================
// lookup_exports
// ============================================================================

///|
fn exports_of(json : String) -> Json {
  match parse_package_json_node16(json) {
    Some(p) =>
      match p.exports {
        Some(e) => e
        None => abort("test package.json has no exports")
      }
    None => abort("invalid test package.json")
  }
}

///|
let esm_conditions : Array[String] = ["node", "import", "types"]

///|
let cjs_conditions : Array[String] = ["node", "require", "types"]

///|
test "node16/exports - string exports matches only the root subpath" {
  let e = exports_of("{ \"exports\": \"./index.js\" }")
  assert_eq(lookup_exports(e, ".", esm_conditions), Found("./index.js"))
  assert_eq(lookup_exports(e, "./sub", esm_conditions), NoMatch)
}

///|
test "node16/exports - subpath map with exact keys" {
  let e = exports_of(
    "{ \"exports\": { \"./cjs\": \"./index.cjs\", \"./mjs\": \"./index.mjs\", \".\": \"./index.js\" } }",
  )
  assert_eq(lookup_exports(e, "./cjs", esm_conditions), Found("./index.cjs"))
  assert_eq(lookup_exports(e, ".", esm_conditions), Found("./index.js"))
  // Blocked by omission: subpath not present in the map
  assert_eq(lookup_exports(e, "./other", esm_conditions), NoMatch)
}

///|
test "node16/exports - condition object selects import/require" {
  let e = exports_of(
    "{ \"exports\": { \".\": { \"import\": \"./a.mjs\", \"require\": \"./a.cjs\" } } }",
  )
  assert_eq(lookup_exports(e, ".", esm_conditions), Found("./a.mjs"))
  assert_eq(lookup_exports(e, ".", cjs_conditions), Found("./a.cjs"))
}

///|
test "node16/exports - conditions are checked in declaration order" {
  // "require" listed first wins for a CJS importer even though "node"
  // also matches later
  let e = exports_of(
    "{ \"exports\": { \"./a\": { \"require\": \"./r.cjs\", \"node\": \"./n.mjs\" } } }",
  )
  assert_eq(lookup_exports(e, "./a", cjs_conditions), Found("./r.cjs"))
  // ESM importer: "require" inactive, "node" matches
  assert_eq(lookup_exports(e, "./a", esm_conditions), Found("./n.mjs"))
}

///|
test "node16/exports - nested condition objects" {
  let e = exports_of(
    "{ \"exports\": { \"./types\": { \"types\": { \"import\": \"./i.d.mts\", \"require\": \"./i.d.cts\" }, \"node\": \"./n.js\" } } }",
  )
  assert_eq(lookup_exports(e, "./types", esm_conditions), Found("./i.d.mts"))
  assert_eq(lookup_exports(e, "./types", cjs_conditions), Found("./i.d.cts"))
}

///|
test "node16/exports - top-level condition object applies to root only" {
  let e = exports_of(
    "{ \"exports\": { \"import\": \"./import.js\", \"require\": \"./require.js\" } }",
  )
  assert_eq(lookup_exports(e, ".", esm_conditions), Found("./import.js"))
  assert_eq(lookup_exports(e, ".", cjs_conditions), Found("./require.js"))
  assert_eq(lookup_exports(e, "./x", esm_conditions), NoMatch)
}

///|
test "node16/exports - wildcard pattern substitutes the star" {
  let e = exports_of(
    "{ \"exports\": { \"./cjs/*\": \"./*.cjs\", \"./js/*.js\": \"./*.js\" } }",
  )
  assert_eq(lookup_exports(e, "./cjs/index", esm_conditions), Found("./index.cjs"))
  // Pattern with a suffix: "./js/*.js" matches "./js/index.js"
  assert_eq(lookup_exports(e, "./js/index.js", esm_conditions), Found("./index.js"))
}

///|
test "node16/exports - null pattern blocks a subpath" {
  let e = exports_of(
    "{ \"exports\": { \"./cjs/*\": \"./*.cjs\", \"./cjs/exclude/*\": null } }",
  )
  assert_eq(lookup_exports(e, "./cjs/ok", esm_conditions), Found("./ok.cjs"))
  // Longest-prefix pattern wins, and its null target blocks resolution
  assert_eq(lookup_exports(e, "./cjs/exclude/x", esm_conditions), NoMatch)
}

///|
test "node16/exports - double asterisk keys never match" {
  let e = exports_of("{ \"exports\": { \"./a/*/b/*\": \"./x.js\" } }")
  // Not even a literal lookup of the same string
  assert_eq(lookup_exports(e, "./a/*/b/*", esm_conditions), NoMatch)
  assert_eq(lookup_exports(e, "./a/1/b/2", esm_conditions), NoMatch)
}

///|
test "node16/exports - legacy trailing-slash key maps a directory" {
  let e = exports_of("{ \"exports\": { \"./lib/\": \"./src/\" } }")
  assert_eq(lookup_exports(e, "./lib/util.js", esm_conditions), Found("./src/util.js"))
}

///|
test "node16/exports - imports map matches # specifiers" {
  let pkg = parse_package_json_node16(
    "{ \"imports\": { \"#dep\": \"./dep.js\", \"#/*\": \"./src/*\" } }",
  )
  match pkg {
    Some(p) =>
      match p.imports {
        Some(imports) => {
          assert_eq(lookup_exports(imports, "#dep", esm_conditions), Found("./dep.js"))
          assert_eq(
            lookup_exports(imports, "#/nested/deep.js", esm_conditions),
            Found("./src/nested/deep.js"),
          )
        }
        None => fail("expected imports map")
      }
    None => fail("expected parsed package.json")
  }
}

// ============================================================================
// scan_types_references
// ============================================================================

///|
test "node16/types-references - basic and resolution-mode" {
  let source = "/// <reference types=\"pkg\" />\n" +
    "/// <reference types=\"other\" resolution-mode=\"require\" />\n" +
    "foo;\n" +
    "/// <reference types=\"late\" />\n"
  let refs = scan_types_references(source)
  assert_eq(refs.length(), 2) // directives after real code are ignored
  assert_eq(refs[0].0, "pkg")
  assert_true(refs[0].1 is None)
  assert_eq(refs[1].0, "other")
  assert_eq(refs[1].1, Some("require"))
}

///|
test "node16/types-references - other comments do not stop the scan" {
  let source = "// @module: node16\n// a comment\n/// <reference types=\"pkg\" resolution-mode=\"import\" />\nexport {};\n"
  let refs = scan_types_references(source)
  assert_eq(refs.length(), 1)
  assert_eq(refs[0].0, "pkg")
  assert_eq(refs[0].1, Some("import"))
}

///|
test "node16/types-references - reference path directives are ignored" {
  let refs = scan_types_references("/// <reference path=\"./x.d.ts\" />\n")
  assert_eq(refs.length(), 0)
}
