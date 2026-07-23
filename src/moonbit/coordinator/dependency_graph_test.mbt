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
  add_node(dag, "/src/a.ts", [], 1000L)
  assert_eq(dag.nodes.length(), 1)
  assert_true(dag.nodes.contains("/src/a.ts"))
}

///|
test "add node with imports" {
  let dag = DependencyDag::new()
  // First add the dependency
  add_node(dag, "/src/b.ts", [], 1000L)
  // Then add the file that imports it
  add_node(dag, "/src/a.ts", ["/src/b.ts"], 1000L)
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
  add_node(dag, "/src/c.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/c.ts"], 1000L)
  add_node(dag, "/src/a.ts", ["/src/b.ts"], 1000L)
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
  add_node(dag, "/src/d.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/d.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/d.ts"], 1000L)
  add_node(dag, "/src/a.ts", ["/src/b.ts", "/src/c.ts"], 1000L)
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
  add_node(dag, "/src/a.ts", ["/src/c.ts"], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)
  assert_true(has_cycle(dag))
  assert_true(topological_sort(dag) is None)
}

///|
test "get downstream dependents" {
  // a -> b -> c (c imports b, b imports a)
  // If a changes, both b and c need recompilation
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)
  let dependents = get_downstream_dependents(dag, "/src/a.ts")
  assert_eq(dependents.length(), 2)
  assert_true(contains_path(dependents, "/src/b.ts"))
  assert_true(contains_path(dependents, "/src/c.ts"))
}

///|
test "get upstream dependencies" {
  // a -> b -> c
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)
  let deps = get_upstream_dependencies(dag, "/src/c.ts")
  assert_eq(deps.length(), 2)
  assert_true(contains_path(deps, "/src/a.ts"))
  assert_true(contains_path(deps, "/src/b.ts"))
}

///|
test "get recompilation order" {
  // a -> b -> c
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)

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
  assert_true(needs_recompilation(dag, "/src/new.ts", 1000L))
}

///|
test "needs recompilation - same hash" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 12345L)
  // Same hash should not need recompilation
  assert_true(!(needs_recompilation(dag, "/src/a.ts", 12345L)))
}

///|
test "needs recompilation - different hash" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 12345L)
  // Different hash should need recompilation
  assert_true(needs_recompilation(dag, "/src/a.ts", 99999L))
}

///|
test "update content hash" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  update_content_hash(dag, "/src/a.ts", 2000L)

  // Verify hash was updated - old hash should need recompilation
  assert_true(needs_recompilation(dag, "/src/a.ts", 1000L))
  // New hash should not need recompilation
  assert_true(!(needs_recompilation(dag, "/src/a.ts", 2000L)))
}

///|
test "remove node" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  remove_node(dag, "/src/a.ts")
  assert_eq(dag.nodes.length(), 1)
  assert_true(!(dag.nodes.contains("/src/a.ts")))

  // b should no longer have a in its edges_out
  let imports_b = get_direct_imports(dag, "/src/b.ts")
  assert_eq(imports_b.length(), 0)
}

///|
test "update node imports" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", [], 1000L)
  add_node(dag, "/src/c.ts", ["/src/a.ts"], 1000L)

  // Update c to import b instead of a
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 2000L)

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
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", [], 1000L)
  add_node(dag, "/src/c.ts", [], 1000L)
  let files = get_all_files(dag)
  assert_eq(files.length(), 3)
  assert_true(contains_path(files, "/src/a.ts"))
  assert_true(contains_path(files, "/src/b.ts"))
  assert_true(contains_path(files, "/src/c.ts"))
}

///|
test "no cycle in empty DAG" {
  let dag = DependencyDag::new()
  assert_true(!(has_cycle(dag)))
}

///|
test "no cycle in single node" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  assert_true(!(has_cycle(dag)))
}

///|
test "independent nodes - parallel compilation possible" {
  // a, b, c with no dependencies - can all be compiled in parallel
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", [], 1000L)
  add_node(dag, "/src/c.ts", [], 1000L)
  match topological_sort(dag) {
    Some(order) => assert_eq(order.length(), 3)
    None => assert_true(false)
  }
}

///|
test "topological levels - simple chain" {
  // a -> b -> c (c imports b, b imports a)
  // Level 0: a (no deps)
  // Level 1: b (depends on a)
  // Level 2: c (depends on b)
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)
  let files = ["/src/a.ts", "/src/b.ts", "/src/c.ts"]
  let levels = topological_levels(dag, files)
  assert_eq(levels.length(), 3)
  assert_eq(levels[0].length(), 1)
  assert_eq(levels[0][0], "/src/a.ts")
  assert_eq(levels[1].length(), 1)
  assert_eq(levels[1][0], "/src/b.ts")
  assert_eq(levels[2].length(), 1)
  assert_eq(levels[2][0], "/src/c.ts")
}

///|
test "topological levels - diamond dependency" {
  //     a
  //    / \
  //   b   c
  //    \ /
  //     d
  // Level 0: d (no deps)
  // Level 1: b, c (both depend only on d)
  // Level 2: a (depends on b and c)
  let dag = DependencyDag::new()
  add_node(dag, "/src/d.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/d.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/d.ts"], 1000L)
  add_node(dag, "/src/a.ts", ["/src/b.ts", "/src/c.ts"], 1000L)
  let files = ["/src/a.ts", "/src/b.ts", "/src/c.ts", "/src/d.ts"]
  let levels = topological_levels(dag, files)
  assert_eq(levels.length(), 3)

  // Level 0: d
  assert_eq(levels[0].length(), 1)
  assert_eq(levels[0][0], "/src/d.ts")

  // Level 1: b and c (can be compiled in parallel)
  assert_eq(levels[1].length(), 2)
  assert_true(contains_path(levels[1], "/src/b.ts"))
  assert_true(contains_path(levels[1], "/src/c.ts"))

  // Level 2: a
  assert_eq(levels[2].length(), 1)
  assert_eq(levels[2][0], "/src/a.ts")
}

///|
test "topological levels - independent files" {
  // a, b, c with no dependencies
  // All should be in level 0 (can all be compiled in parallel)
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", [], 1000L)
  add_node(dag, "/src/c.ts", [], 1000L)
  let files = ["/src/a.ts", "/src/b.ts", "/src/c.ts"]
  let levels = topological_levels(dag, files)
  assert_eq(levels.length(), 1)
  assert_eq(levels[0].length(), 3)
  assert_true(contains_path(levels[0], "/src/a.ts"))
  assert_true(contains_path(levels[0], "/src/b.ts"))
  assert_true(contains_path(levels[0], "/src/c.ts"))
}

///|
test "topological levels - partial file list" {
  // Full graph: a -> b -> c -> d
  // But we only want levels for [b, c, d]
  let dag = DependencyDag::new()
  add_node(dag, "/src/d.ts", [], 1000L)
  add_node(dag, "/src/c.ts", ["/src/d.ts"], 1000L)
  add_node(dag, "/src/b.ts", ["/src/c.ts"], 1000L)
  add_node(dag, "/src/a.ts", ["/src/b.ts"], 1000L)

  // Only interested in b, c, d
  let files = ["/src/b.ts", "/src/c.ts", "/src/d.ts"]
  let levels = topological_levels(dag, files)
  assert_eq(levels.length(), 3)
  assert_eq(levels[0][0], "/src/d.ts")
  assert_eq(levels[1][0], "/src/c.ts")
  assert_eq(levels[2][0], "/src/b.ts")
}

///|
test "topological levels - with cycle" {
  // a -> b -> c -> a (cycle)
  // Should handle gracefully by putting remaining in one level
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", ["/src/c.ts"], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)
  let files = ["/src/a.ts", "/src/b.ts", "/src/c.ts"]
  let levels = topological_levels(dag, files)

  // With a cycle, all files end up in a single level
  assert_eq(levels.length(), 1)
  assert_eq(levels[0].length(), 3)
}

///|
test "level count" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  add_node(dag, "/src/c.ts", ["/src/b.ts"], 1000L)
  let files = ["/src/a.ts", "/src/b.ts", "/src/c.ts"]
  assert_eq(level_count(dag, files), 3)
}

///|
test "get level - specific level" {
  let dag = DependencyDag::new()
  add_node(dag, "/src/a.ts", [], 1000L)
  add_node(dag, "/src/b.ts", ["/src/a.ts"], 1000L)
  let files = ["/src/a.ts", "/src/b.ts"]
  let level0 = get_level(dag, files, 0)
  assert_eq(level0.length(), 1)
  assert_eq(level0[0], "/src/a.ts")
  let level1 = get_level(dag, files, 1)
  assert_eq(level1.length(), 1)
  assert_eq(level1[0], "/src/b.ts")

  // Out of bounds returns empty
  let level2 = get_level(dag, files, 2)
  assert_eq(level2.length(), 0)
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
