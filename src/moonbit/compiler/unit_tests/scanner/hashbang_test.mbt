// Hashbang Support Tests
// Tests for hashbang (#!/usr/bin/env node) scanning

///|
test "scan hashbang - basic node" {
  let scanner = @compiler.Scanner::new("#!/usr/bin/env node\n", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) => assert_eq(text, "#!/usr/bin/env node")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - with code after" {
  let scanner = @compiler.Scanner::new(
    "#!/usr/bin/env node\nconst x = 1;", "test.ts",
  )
  let tokens = @compiler.scan_all(scanner)
  // Hashbang, const, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 7)
  match tokens[0] {
    @compiler.Hashbang(text, _) => assert_eq(text, "#!/usr/bin/env node")
    _ => assert_true(false)
  }
  match tokens[1] {
    @compiler.KeywordConst(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - ts-node" {
  let scanner = @compiler.Scanner::new("#!/usr/bin/env ts-node\n", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) =>
      assert_eq(text, "#!/usr/bin/env ts-node")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - direct path" {
  let scanner = @compiler.Scanner::new("#!/usr/bin/node\n", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) => assert_eq(text, "#!/usr/bin/node")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - with arguments" {
  let scanner = @compiler.Scanner::new(
    "#!/usr/bin/env node --experimental-modules\n", "test.ts",
  )
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) =>
      assert_eq(text, "#!/usr/bin/env node --experimental-modules")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - not at start returns none" {
  let scanner = @compiler.Scanner::new(
    "const x = 1;\n#!/usr/bin/env node", "test.ts",
  )
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    None => ()
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - empty file no hashbang" {
  let scanner = @compiler.Scanner::new("", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    None => ()
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - just hash no bang" {
  let scanner = @compiler.Scanner::new("#field", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    None => () // # followed by identifier is private identifier
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - preserves position for next token" {
  let scanner = @compiler.Scanner::new(
    "#!/usr/bin/env node\nlet x = 1;", "test.ts",
  )
  let tokens = @compiler.scan_all(scanner)
  // Hashbang, let, x, =, 1, ;, EOF
  assert_eq(tokens.length(), 7)
  match tokens[1] {
    @compiler.KeywordLet(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - deno" {
  let scanner = @compiler.Scanner::new(
    "#!/usr/bin/env -S deno run\n", "test.ts",
  )
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) =>
      assert_eq(text, "#!/usr/bin/env -S deno run")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - bun" {
  let scanner = @compiler.Scanner::new("#!/usr/bin/env bun\n", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) => assert_eq(text, "#!/usr/bin/env bun")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - without newline at end" {
  let scanner = @compiler.Scanner::new("#!/usr/bin/env node", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(text, _)) => assert_eq(text, "#!/usr/bin/env node")
    _ => assert_true(false)
  }
}

///|
test "scan hashbang - source location" {
  let scanner = @compiler.Scanner::new("#!/usr/bin/env node\n", "test.ts")
  let (hashbang, _) = @compiler.scan_hashbang(scanner)
  match hashbang {
    Some(@compiler.Hashbang(_, loc)) => {
      assert_eq(loc.start.line, 1)
      assert_eq(loc.start.column, 1)
      assert_eq(loc.start.offset, 0)
    }
    _ => assert_true(false)
  }
}
