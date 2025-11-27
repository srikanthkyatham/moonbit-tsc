// Tests for Import Extractor

///|
test "extract imports - simple import" {
  let source = "import { foo } from \"./utils\";"
  let result = extract_imports(source, "/src/main.ts")
  assert_eq(result.imports.length(), 1)
  assert_eq(result.imports[0], "./utils")
  assert_eq(result.errors.length(), 0)
}

///|
test "extract imports - multiple imports" {
  let source =
    #|import { foo } from "./utils";
    #|import { bar } from "../lib/helpers";
    #|import React from "react";
  let result = extract_imports(source, "/src/main.ts")
  assert_eq(result.imports.length(), 3)
  assert_eq(result.imports[0], "./utils")
  assert_eq(result.imports[1], "../lib/helpers")
  assert_eq(result.imports[2], "react")
}

///|
test "extract imports - no imports" {
  let source =
    #|const x = 1;
    #|function foo() { return x; }
  let result = extract_imports(source, "/src/main.ts")
  assert_eq(result.imports.length(), 0)
}

///|
test "extract imports - side effect import" {
  let source = "import \"./polyfills\";"
  let result = extract_imports(source, "/src/main.ts")
  assert_eq(result.imports.length(), 1)
  assert_eq(result.imports[0], "./polyfills")
}

///|
test "extract imports - namespace import" {
  let source = "import * as utils from \"./utils\";"
  let result = extract_imports(source, "/src/main.ts")
  assert_eq(result.imports.length(), 1)
  assert_eq(result.imports[0], "./utils")
}

///|
test "resolve import path - relative same directory" {
  match resolve_import_path("./utils", "/src/main.ts") {
    Some(path) => assert_eq(path, "/src/utils.ts")
    None => assert_true(false)
  }
}

///|
test "resolve import path - relative parent directory" {
  match resolve_import_path("../lib/helpers", "/src/app/main.ts") {
    Some(path) => assert_eq(path, "/src/lib/helpers.ts")
    None => assert_true(false)
  }
}

///|
test "resolve import path - bare import returns None" {
  match resolve_import_path("react", "/src/main.ts") {
    Some(_) => assert_true(false)
    None => assert_true(true)
  }
}

///|
test "build dependency graph - simple" {
  // (path, source) pairs - matches read_files output
  let files : Array[(String, String)] = [
    ("/src/main.ts", "import { foo } from \"./utils\";"),
    ("/src/utils.ts", "export function foo() {}"),
  ]
  let dag = build_dependency_graph(files)

  // main.ts imports utils.ts
  let imports = get_direct_imports(dag, "/src/main.ts")
  assert_eq(imports.length(), 1)
  assert_eq(imports[0], "/src/utils.ts")

  // utils.ts has no imports
  let utils_imports = get_direct_imports(dag, "/src/utils.ts")
  assert_eq(utils_imports.length(), 0)
}

///|
test "build dependency graph - chain" {
  // (path, source) pairs - matches read_files output
  let files : Array[(String, String)] = [
    ("/src/a.ts", "import { foo } from \"./b\";"),
    ("/src/b.ts", "import { bar } from \"./c\";"),
    ("/src/c.ts", "export function bar() {}"),
  ]
  let dag = build_dependency_graph(files)

  // Verify DAG structure first
  assert_eq(get_all_files(dag).length(), 3)

  // Check imports
  let a_imports = get_direct_imports(dag, "/src/a.ts")
  assert_eq(a_imports.length(), 1)
  assert_eq(a_imports[0], "/src/b.ts")

  let b_imports = get_direct_imports(dag, "/src/b.ts")
  assert_eq(b_imports.length(), 1)
  assert_eq(b_imports[0], "/src/c.ts")

  let c_imports = get_direct_imports(dag, "/src/c.ts")
  assert_eq(c_imports.length(), 0)

  // Check importers (reverse edges)
  let a_importers = get_direct_importers(dag, "/src/a.ts")
  assert_eq(a_importers.length(), 0)

  let b_importers = get_direct_importers(dag, "/src/b.ts")
  assert_eq(b_importers.length(), 1)

  let c_importers = get_direct_importers(dag, "/src/c.ts")
  assert_eq(c_importers.length(), 1)

  // Check topological order
  match topological_sort(dag) {
    Some(order) => {
      assert_eq(order.length(), 3)
      let c_idx = find_in_array(order, "/src/c.ts")
      let b_idx = find_in_array(order, "/src/b.ts")
      let a_idx = find_in_array(order, "/src/a.ts")
      assert_true(c_idx < b_idx)
      assert_true(b_idx < a_idx)
    }
    None => assert_true(false)
  }
}

// Helper for tests
fn find_in_array(arr : Array[String], value : String) -> Int {
  for i = 0; i < arr.length(); i = i + 1 {
    if arr[i] == value {
      return i
    }
  }
  -1
}
