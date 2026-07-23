// Tests for file-set-aware import resolution in the dependency graph (T6)

///|
test "coordinator/fileset - dependency edge resolves to d.ts file" {
  let files : Array[(String, String)] = [
    ("/t/main.ts", "import { n } from \"./decl\";\nconst x = n;"),
    ("/t/decl.d.ts", "export declare const n: number;"),
  ]
  let dag = build_dependency_graph(files)
  let imports = get_direct_imports(dag, "/t/main.ts")
  assert_true(imports.contains("/t/decl.d.ts"))
}

///|
test "coordinator/fileset - dependency edge resolves to directory index" {
  let files : Array[(String, String)] = [
    ("/t/main.ts", "import { s } from \"./sub\";\nconst x = s;"),
    ("/t/sub/index.ts", "export const s: string = \"hi\";"),
  ]
  let dag = build_dependency_graph(files)
  let imports = get_direct_imports(dag, "/t/main.ts")
  assert_true(imports.contains("/t/sub/index.ts"))
}

///|
test "coordinator/fileset - plain ts edge still resolves" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"./b\";"),
    ("/t/b.ts", "export const x: number = 1;"),
  ]
  let dag = build_dependency_graph(files)
  let imports = get_direct_imports(dag, "/t/a.ts")
  assert_true(imports.contains("/t/b.ts"))
}

///|
test "coordinator/fileset - unresolved import falls back to naive guess" {
  let files : Array[(String, String)] = [
    ("/t/a.ts", "import { x } from \"./missing\";"),
  ]
  let dag = build_dependency_graph(files)
  let imports = get_direct_imports(dag, "/t/a.ts")
  // Falls back to the historical ".ts"-appending guess
  assert_true(imports.contains("/t/missing.ts"))
}
