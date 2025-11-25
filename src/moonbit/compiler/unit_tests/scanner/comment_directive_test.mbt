// Comment Directive Tests
// Tests for TypeScript comment directives (@ts-ignore, @ts-expect-error, etc.)

///|
test "scan comment directive - ts-ignore" {
  let scanner = @compiler.Scanner::new("// @ts-ignore\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsIgnore, _, _)) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - ts-expect-error" {
  let scanner = @compiler.Scanner::new("// @ts-expect-error\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsExpectError, _, _)) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - ts-nocheck" {
  let scanner = @compiler.Scanner::new("// @ts-nocheck\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsNocheck, _, _)) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - ts-check" {
  let scanner = @compiler.Scanner::new("// @ts-check\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsCheck, _, _)) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - ts-ignore with message" {
  let scanner = @compiler.Scanner::new("// @ts-ignore This is intentional\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsIgnore, arg, _)) => {
      assert_true(arg.contains("This is intentional"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - ts-expect-error with error code" {
  let scanner = @compiler.Scanner::new("// @ts-expect-error TS2322: Type mismatch\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsExpectError, arg, _)) => {
      assert_true(arg.contains("TS2322"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - triple slash reference" {
  let scanner = @compiler.Scanner::new("/// <reference path=\"./types.d.ts\" />\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TripleSlashRef, content, _)) => {
      assert_true(content.contains("reference"))
      assert_true(content.contains("path"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - triple slash types reference" {
  let scanner = @compiler.Scanner::new("/// <reference types=\"node\" />\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TripleSlashRef, content, _)) => {
      assert_true(content.contains("types"))
      assert_true(content.contains("node"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - triple slash lib reference" {
  let scanner = @compiler.Scanner::new("/// <reference lib=\"es2020\" />\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TripleSlashRef, content, _)) => {
      assert_true(content.contains("lib"))
      assert_true(content.contains("es2020"))
    }
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - not a directive (regular comment)" {
  let scanner = @compiler.Scanner::new("// This is a regular comment\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    None => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - with whitespace before @" {
  let scanner = @compiler.Scanner::new("//   @ts-ignore\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsIgnore, _, _)) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - source location" {
  let scanner = @compiler.Scanner::new("// @ts-ignore\n", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(_, _, loc)) => {
      assert_eq(loc.start.line, 1)
      assert_eq(loc.start.column, 1)
      assert_eq(loc.start.offset, 0)
    }
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - ts-ignore without newline" {
  let scanner = @compiler.Scanner::new("// @ts-ignore", "test.ts")
  let (directive, _) = @compiler.scan_comment_directive(scanner)
  match directive {
    Some(@compiler.CommentDirective(@compiler.TsIgnore, _, _)) => ()
    _ => assert_true(false)
  }
}

///|
test "scan comment directive - multiple directives in sequence" {
  let source = "// @ts-ignore\nconst x = 1;\n// @ts-expect-error\nconst y = 2;"
  let scanner = @compiler.Scanner::new(source, "test.ts")
  let (directive1, scanner2) = @compiler.scan_comment_directive(scanner)
  match directive1 {
    Some(@compiler.CommentDirective(@compiler.TsIgnore, _, _)) => ()
    _ => assert_true(false)
  }
  // Skip to next line and check we can continue scanning
  let tokens = @compiler.scan_all(scanner2)
  // Remaining: const, x, =, 1, ;, (next line: comment directive should be skipped normally), const, y, =, 2, ;, EOF
  assert_true(tokens.length() >= 6)
}
