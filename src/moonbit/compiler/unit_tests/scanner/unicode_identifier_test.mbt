// Unicode Identifier Tests
// Tests for Unicode identifier support in the scanner

///|
test "scan unicode identifier - greek letters" {
  let scanner = @compiler.Scanner::new("αβγδ", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "αβγδ")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - cyrillic letters" {
  let scanner = @compiler.Scanner::new("привет", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "привет")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - chinese characters" {
  let scanner = @compiler.Scanner::new("你好世界", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "你好世界")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - japanese hiragana" {
  let scanner = @compiler.Scanner::new("こんにちは", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "こんにちは")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - mixed with ascii" {
  let scanner = @compiler.Scanner::new("myVar_αβ123", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "myVar_αβ123")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - korean hangul" {
  let scanner = @compiler.Scanner::new("안녕하세요", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "안녕하세요")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - arabic letters" {
  let scanner = @compiler.Scanner::new("مرحبا", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "مرحبا")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - hebrew letters" {
  let scanner = @compiler.Scanner::new("שלום", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "שלום")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - variable declaration" {
  let scanner = @compiler.Scanner::new("const μ = 42;", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  // const, identifier, =, number, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "μ")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - function name" {
  let scanner = @compiler.Scanner::new("function 计算() { }", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  // function, identifier, (, ), {, }, EOF
  assert_eq(tokens.length(), 7)
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "计算")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - thai characters" {
  let scanner = @compiler.Scanner::new("สวัสดี", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "สวัสดี")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - devanagari" {
  let scanner = @compiler.Scanner::new("नमस्ते", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "नमस्ते")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier with unicode digits" {
  // Test identifiers that include Unicode digits after start
  let scanner = @compiler.Scanner::new("var١٢٣", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "var١٢٣")
    _ => assert_true(false)
  }
}

///|
test "scan multiple unicode identifiers" {
  let scanner = @compiler.Scanner::new("α + β * γ", "test.ts")
  let tokens = @compiler.scan_all(scanner)
  // α, +, β, *, γ, EOF
  assert_eq(tokens.length(), 6)
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "α")
    _ => assert_true(false)
  }
  match tokens[2] {
    @compiler.Identifier(name, _) => assert_eq(name, "β")
    _ => assert_true(false)
  }
  match tokens[4] {
    @compiler.Identifier(name, _) => assert_eq(name, "γ")
    _ => assert_true(false)
  }
}
