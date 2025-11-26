// Unicode Identifier Tests
// Tests for Unicode identifier support in the scanner

///|
test "scan unicode identifier - greek letters" {
  let tokens = @compiler.scan_all_v2("αβγδ", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "αβγδ")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - cyrillic letters" {
  let tokens = @compiler.scan_all_v2("привет", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "привет")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - chinese characters" {
  let tokens = @compiler.scan_all_v2("你好世界", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "你好世界")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - japanese hiragana" {
  let tokens = @compiler.scan_all_v2("こんにちは", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "こんにちは")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - mixed with ascii" {
  let tokens = @compiler.scan_all_v2("myVar_αβ123", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "myVar_αβ123")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - korean hangul" {
  let tokens = @compiler.scan_all_v2("안녕하세요", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "안녕하세요")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - arabic letters" {
  let tokens = @compiler.scan_all_v2("مرحبا", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "مرحبا")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - hebrew letters" {
  let tokens = @compiler.scan_all_v2("שלום", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "שלום")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - variable declaration" {
  let tokens = @compiler.scan_all_v2("const μ = 42;", "test.ts")
  // const, identifier, =, number, ;, EOF
  assert_eq(tokens.length(), 6)
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "μ")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - function name" {
  let tokens = @compiler.scan_all_v2("function 计算() { }", "test.ts")
  // function, identifier, (, ), {, }, EOF
  assert_eq(tokens.length(), 7)
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "计算")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - thai characters" {
  let tokens = @compiler.scan_all_v2("สวัสดี", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "สวัสดี")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier - devanagari" {
  let tokens = @compiler.scan_all_v2("नमस्ते", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "नमस्ते")
    _ => assert_true(false)
  }
}

///|
test "scan unicode identifier with unicode digits" {
  // Test identifiers that include Unicode digits after start
  let tokens = @compiler.scan_all_v2("var١٢٣", "test.ts")
  assert_eq(tokens.length(), 2) // identifier + EOF
  match tokens[0] {
    @compiler.Identifier(name, _) => assert_eq(name, "var١٢٣")
    _ => assert_true(false)
  }
}

///|
test "scan multiple unicode identifiers" {
  let tokens = @compiler.scan_all_v2("α + β * γ", "test.ts")
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
