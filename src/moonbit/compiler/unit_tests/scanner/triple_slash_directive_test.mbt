// Triple-Slash Directive Tests
// Tests for TypeScript triple-slash directive comment scanning

///|
test "scan triple-slash reference types directive" {
  let source = "/// <reference types=\"node\" />\nconst x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_true(tokens.length() >= 2)
  match tokens[0] {
    @compiler.CommentDirective(@compiler.TripleSlashRef, content, _) => {
      assert_true(content.contains("<reference"))
      assert_true(content.contains("types"))
      assert_true(content.contains("node"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan triple-slash reference lib directive" {
  let source = "/// <reference lib=\"es2015\" />\nconst x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_true(tokens.length() >= 2)
  match tokens[0] {
    @compiler.CommentDirective(@compiler.TripleSlashRef, content, _) => {
      assert_true(content.contains("<reference"))
      assert_true(content.contains("lib"))
      assert_true(content.contains("es2015"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan triple-slash reference path directive" {
  let source = "/// <reference path=\"./utils.d.ts\" />\nconst x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_true(tokens.length() >= 2)
  match tokens[0] {
    @compiler.CommentDirective(@compiler.TripleSlashRef, content, _) => {
      assert_true(content.contains("<reference"))
      assert_true(content.contains("path"))
      assert_true(content.contains("./utils.d.ts"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan multiple triple-slash directives" {
  let source = "/// <reference types=\"node\" />\n/// <reference lib=\"es2015\" />\n/// <reference path=\"./utils.d.ts\" />\nconst x = 1;"
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  assert_true(tokens.length() >= 4)

  // First directive - types
  match tokens[0] {
    @compiler.CommentDirective(@compiler.TripleSlashRef, content, _) => {
      assert_true(content.contains("types"))
      assert_true(content.contains("node"))
    }
    _ => assert_true(false)
  }

  // Second directive - lib
  match tokens[1] {
    @compiler.CommentDirective(@compiler.TripleSlashRef, content, _) => {
      assert_true(content.contains("lib"))
      assert_true(content.contains("es2015"))
    }
    _ => assert_true(false)
  }

  // Third directive - path
  match tokens[2] {
    @compiler.CommentDirective(@compiler.TripleSlashRef, content, _) => {
      assert_true(content.contains("path"))
      assert_true(content.contains("./utils.d.ts"))
    }
    _ => assert_true(false)
  }
}
