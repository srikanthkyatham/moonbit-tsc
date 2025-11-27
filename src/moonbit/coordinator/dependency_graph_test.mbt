// Tests for Dependency DAG
// Tests for the Directed Acyclic Graph used for incremental compilation

///|
test "create empty DAG" {
  let dag = DependencyDag::new()
  assert_eq(dag.nodes.length(), 0)
}

///|
test "add single node" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  assert_eq(dag.nodes.length(), 1)
  assert_true(dag.nodes.contains("/src/a.ts"))
}

///|
test "add node with imports" {
  let dag = DependencyDag::new()
  // First add the dependency
  add_node(dag, "/src/b.ts", [], 1000L, 0)
  // Then add the file that imports it
  add_node(dag, "/src/a.ts", ["/src/b.ts"], 1000L, 0)

  assert_eq(dag.nodes.length(), 2)

  // Check edges_out (a imports b)
  let imports_a = get_direct_imports(dag, "/src/a.ts")
  assert_eq(imports_a.length(), 1)
  assert_eq(imports_a[0], "/src/b.ts")

  // Check edges_in (b is imported by a)
  let importers_b = get_direct_importers(dag, "/src/b.ts")
  assert_eq(importers_b.length(), 1)
  assert_eq(importers_b[0], "/src/a.ts")
}

///|
test "topological sort - simple chain" {
  // a -> b -> c (a imports b, b imports c)
  let dag = DependencyDag::new()
  add_node(dag, "/src/c.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/c.ts"], 1000L, 0)
  add_node(dag, "/src/a.ts", ["/src/b.ts"], 1000L, 0)

  match topological_sort(dag) {
    Some(order) => {
      assert_eq(order.length(), 3)
      // c should come before b, b before a
      let c_idx = find_index(order, "/src/c.ts")
      let b_idx = find_index(order, "/src/b.ts")
      let a_idx = find_index(order, "/src/a.ts")
      assert_true(c_idx < b_idx)
      assert_true(b_idx < a_idx)
    }
    None => assert_true(false) // Should not be a cycle
  }
}

///|
test "topological sort - diamond dependency" {
  //     a
  //    / \
  //   b   c
  //    \ /
  //     d
  let dag = DependencyDag::new()
  add_node(dag, "/src/d.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/d.ts"], 1000L, 0)
  add_node(dag, "/src/c.ts", ["/src/d.ts"], 1000L, 0)
  add_node(dag, "/src/a.ts", ["/src/b.ts", "/src/c.ts"], 1000L, 0)

  match topological_sort(dag) {
    Some(order) => {
      assert_eq(order.length(), 4)
      // d should come before both b and c, both before a
      let d_idx = find_index(order, "/src/d.ts")
      let b_idx = find_index(order, "/src/b.ts")
      let c_idx = find_index(order, "/src/c.ts")
      let a_idx = find_index(order, "/src/a.ts")
      assert_true(d_idx < b_idx)
      assert_true(d_idx < c_idx)
      assert_true(b_idx < a_idx)
      assert_true(c_idx < a_idx)
    }
    None => assert_true(false) // Should not be a cycle
  }
}

///|
test "cycle detection" {
  // a -> b -> c -> a (cycle)
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", ["/src/c.ts"], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L, 0)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L, 0)

  assert_true(has_cycle(dag))
  assert_true(topological_sort(dag) is None)
}

///|
test "get downstream dependents" {
  // a -> b -> c (c imports b, b imports a)
  // If a changes, both b and c need recompilation
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L, 0)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L, 0)

  let dependents = get_downstream_dependents(dag, "/src/a.ts")
  assert_eq(dependents.length(), 2)
  assert_true(contains_path(dependents, "/src/b.ts"))
  assert_true(contains_path(dependents, "/src/c.ts"))
}

///|
test "get upstream dependencies" {
  // a -> b -> c
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L, 0)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L, 0)

  let deps = get_upstream_dependencies(dag, "/src/c.ts")
  assert_eq(deps.length(), 2)
  assert_true(contains_path(deps, "/src/a.ts"))
  assert_true(contains_path(deps, "/src/b.ts"))
}

///|
test "get recompilation order" {
  // a -> b -> c
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L, 0)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L, 0)

  // If a changes, recompile a, b, c in that order
  let order = get_recompilation_order(dag, ["/src/a.ts"])
  assert_eq(order.length(), 3)
  let a_idx = find_index(order, "/src/a.ts")
  let b_idx = find_index(order, "/src/b.ts")
  let c_idx = find_index(order, "/src/c.ts")
  assert_true(a_idx < b_idx)
  assert_true(b_idx < c_idx)
}

///|
test "needs recompilation - new file" {
  let dag = DependencyDag::new()
  // File not in DAG should need recompilation
  assert_true(needs_recompilation(dag, "/src/new.ts", 1000L, 0))
}

///|
test "needs recompilation - same mtime" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 500)
  // Same mtime should not need recompilation
  assert_true(not(needs_recompilation(dag, "/src/a.ts", 1000L, 500)))
}

///|
test "needs recompilation - different mtime" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 500)
  // Different mtime should need recompilation
  assert_true(needs_recompilation(dag, "/src/a.ts", 1001L, 0))
}

///|
test "update mtime" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  update_mtime(dag, "/src/a.ts", 2000L, 100)

  // Verify mtime was updated - old mtime should need recompilation
  assert_true(needs_recompilation(dag, "/src/a.ts", 1000L, 0))
  // New mtime should not need recompilation
  assert_true(not(needs_recompilation(dag, "/src/a.ts", 2000L, 100)))
}

///|
test "remove node" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L, 0)

  remove_node(dag, "/src/a.ts")
  assert_eq(dag.nodes.length(), 1)
  assert_true(not(dag.nodes.contains("/src/a.ts")))

  // b should no longer have a in its edges_out
  let imports_b = get_direct_imports(dag, "/src/b.ts")
  assert_eq(imports_b.length(), 0)
}

///|
test "update node imports" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", [], 1000L, 0)
  add_node(dag, "/src/c.ts", ["/src/a.ts"], 1000L, 0)

  // Update c to import b instead of a
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 2000L, 0)

  // c should now import b, not a
  let imports_c = get_direct_imports(dag, "/src/c.ts")
  assert_eq(imports_c.length(), 1)
  assert_eq(imports_c[0], "/src/b.ts")

  // a should not be imported by c anymore
  let importers_a = get_direct_importers(dag, "/src/a.ts")
  assert_eq(importers_a.length(), 0)

  // b should now be imported by c
  let importers_b = get_direct_importers(dag, "/src/b.ts")
  assert_eq(importers_b.length(), 1)
  assert_eq(importers_b[0], "/src/c.ts")
}

///|
test "get all files" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", [], 1000L, 0)
  add_node(dag, "/src/c.ts", [], 1000L, 0)

  let files = get_all_files(dag)
  assert_eq(files.length(), 3)
  assert_true(contains_path(files, "/src/a.ts"))
  assert_true(contains_path(files, "/src/b.ts"))
  assert_true(contains_path(files, "/src/c.ts"))
}

///|
test "no cycle in empty DAG" {
  let dag = DependencyDag::new()
  assert_true(not(has_cycle(dag)))
}

///|
test "no cycle in single node" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  assert_true(not(has_cycle(dag)))
}

///|
test "independent nodes - parallel compilation possible" {
  // a, b, c with no dependencies - can all be compiled in parallel
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L, 0)
  add_node(dag, "/src/b.ts", [], 1000L, 0)
  add_node(dag, "/src/c.ts", [], 1000L, 0)

  match topological_sort(dag) {
    Some(order) => assert_eq(order.length(), 3)
    None => assert_true(false)
  }
}

// Helper functions for tests

///|
fn find_index(arr : Array[String], value : String) -> Int {
  for i = 0; i < arr.length(); i = i + 1 {
    if arr[i] == value {
      return i
    }
  }
  -1
}

///|
fn contains_path(arr : Array[String], value : String) -> Bool {
  for item in arr {
    if item == value {
      return true
    }
  }
  false
}
