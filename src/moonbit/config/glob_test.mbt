// Tests for glob pattern matching

///|
test "glob_match - literal paths match exactly" {
  assert_true(glob_match("src/index.ts", "src/index.ts"))
  assert_true(glob_match("a/b/c.ts", "a/b/c.ts"))
  assert_false(glob_match("src/index.ts", "src/other.ts"))
}

///|
test "glob_match - single asterisk matches within directory" {
  assert_true(glob_match("*.ts", "index.ts"))
  assert_true(glob_match("*.ts", "foo.ts"))
  assert_false(glob_match("*.ts", "index.js"))
  assert_false(glob_match("*.ts", "src/index.ts")) // * doesn't cross /
}

///|
test "glob_match - single asterisk in middle of pattern" {
  assert_true(glob_match("src/*.ts", "src/index.ts"))
  assert_true(glob_match("src/*.ts", "src/utils.ts"))
  assert_false(glob_match("src/*.ts", "src/sub/index.ts"))
}

///|
test "glob_match - double asterisk matches across directories" {
  assert_true(glob_match("**/*.ts", "index.ts"))
  assert_true(glob_match("**/*.ts", "src/index.ts"))
  assert_true(glob_match("**/*.ts", "src/utils/helpers.ts"))
  assert_true(glob_match("**/*.ts", "a/b/c/d/e.ts"))
}

///|
test "glob_match - double asterisk at start" {
  assert_true(glob_match("**/test.ts", "test.ts"))
  assert_true(glob_match("**/test.ts", "src/test.ts"))
  assert_true(glob_match("**/test.ts", "src/sub/test.ts"))
  assert_false(glob_match("**/test.ts", "src/test.js"))
}

///|
test "glob_match - double asterisk at end" {
  assert_true(glob_match("src/**", "src/index.ts"))
  assert_true(glob_match("src/**", "src/utils/helpers.ts"))
  assert_true(glob_match("src/**", "src/a/b/c/d.ts"))
}

///|
test "glob_match - double asterisk in middle" {
  assert_true(glob_match("src/**/test.ts", "src/test.ts"))
  assert_true(glob_match("src/**/test.ts", "src/utils/test.ts"))
  assert_true(glob_match("src/**/test.ts", "src/a/b/c/test.ts"))
  assert_false(glob_match("src/**/test.ts", "lib/test.ts"))
}

///|
test "glob_match - question mark matches single character" {
  assert_true(glob_match("?.ts", "a.ts"))
  assert_true(glob_match("?.ts", "x.ts"))
  assert_false(glob_match("?.ts", "ab.ts"))
  assert_false(glob_match("?.ts", ".ts"))
}

///|
test "glob_match - question mark in path" {
  assert_true(glob_match("src/??.ts", "src/ab.ts"))
  assert_false(glob_match("src/??.ts", "src/abc.ts"))
  assert_false(glob_match("src/??.ts", "src/a.ts"))
}

///|
test "glob_match - bracket expression matches character set" {
  assert_true(glob_match("[abc].ts", "a.ts"))
  assert_true(glob_match("[abc].ts", "b.ts"))
  assert_true(glob_match("[abc].ts", "c.ts"))
  assert_false(glob_match("[abc].ts", "d.ts"))
}

///|
test "glob_match - bracket expression with range" {
  assert_true(glob_match("[a-z].ts", "a.ts"))
  assert_true(glob_match("[a-z].ts", "m.ts"))
  assert_true(glob_match("[a-z].ts", "z.ts"))
  assert_false(glob_match("[a-z].ts", "A.ts"))
  assert_false(glob_match("[a-z].ts", "1.ts"))
}

///|
test "glob_match - negated bracket expression" {
  assert_false(glob_match("[!abc].ts", "a.ts"))
  assert_false(glob_match("[!abc].ts", "b.ts"))
  assert_true(glob_match("[!abc].ts", "d.ts"))
  assert_true(glob_match("[!abc].ts", "x.ts"))
}

///|
test "glob_match - complex patterns" {
  assert_true(glob_match("src/**/*.test.ts", "src/utils.test.ts"))
  assert_true(glob_match("src/**/*.test.ts", "src/lib/utils.test.ts"))
  assert_true(glob_match("src/**/*.test.ts", "src/a/b/c.test.ts"))
  assert_false(glob_match("src/**/*.test.ts", "src/utils.ts"))
}

///|
test "glob_match - tsconfig include pattern" {
  let pattern = "src/**/*"
  assert_true(glob_match(pattern, "src/index.ts"))
  assert_true(glob_match(pattern, "src/utils/helpers.ts"))
  assert_true(glob_match(pattern, "src/components/Button.tsx"))
}

///|
test "glob_match - tsconfig exclude pattern" {
  let pattern = "**/*.test.ts"
  assert_true(glob_match(pattern, "index.test.ts"))
  assert_true(glob_match(pattern, "src/utils.test.ts"))
  assert_true(glob_match(pattern, "src/lib/helpers.test.ts"))
  assert_false(glob_match(pattern, "src/utils.ts"))
}

///|
test "matches_any_pattern - matches if any pattern matches" {
  let patterns = ["*.ts", "*.tsx"]
  assert_true(matches_any_pattern(patterns, "index.ts"))
  assert_true(matches_any_pattern(patterns, "App.tsx"))
  assert_false(matches_any_pattern(patterns, "index.js"))
}

///|
test "should_exclude - simple directory names" {
  let exclude = ["node_modules", "dist"]
  assert_true(should_exclude(exclude, "node_modules/package/index.js"))
  assert_true(should_exclude(exclude, "src/node_modules/foo.ts"))
  assert_true(should_exclude(exclude, "dist/index.js"))
  assert_false(should_exclude(exclude, "src/index.ts"))
}

///|
test "should_exclude - glob patterns" {
  let exclude = ["**/*.test.ts", "**/__tests__/**"]
  assert_true(should_exclude(exclude, "src/utils.test.ts"))
  assert_true(should_exclude(exclude, "src/__tests__/utils.ts"))
  assert_false(should_exclude(exclude, "src/utils.ts"))
}

///|
test "normalize_path - converts backslashes" {
  assert_eq(normalize_path("src\\utils\\index.ts"), "src/utils/index.ts")
  assert_eq(normalize_path("src/utils/index.ts"), "src/utils/index.ts")
}

///|
test "get_relative_path - extracts relative portion" {
  assert_eq(get_relative_path("/project", "/project/src/index.ts"), "src/index.ts")
  assert_eq(get_relative_path("/project/", "/project/src/index.ts"), "src/index.ts")
  assert_eq(get_relative_path(".", "./src/index.ts"), "src/index.ts")
}

///|
test "glob_match - path separator normalization" {
  assert_true(glob_match("src/index.ts", "src\\index.ts"))
  assert_true(glob_match("src\\index.ts", "src/index.ts"))
}
