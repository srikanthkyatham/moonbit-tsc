// JSX Scanning Tests
// Tests for JSX mode scanning support

///|
test "scan jsx - simple element" {
  let tokens = @compiler.scan_all_jsx("<div></div>", "test.tsx")
  // <, div, >, </, div, >, EOF
  assert_true(tokens.length() >= 5)
  match tokens[0] {
    @compiler.JsxTagOpen(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "div")
    _ => assert_true(false)
  }
  match tokens[2] {
    @compiler.JsxTagClose(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan jsx - self-closing element" {
  let tokens = @compiler.scan_all_jsx("<br/>", "test.tsx")
  // <, br, />, EOF
  assert_true(tokens.length() >= 3)
  match tokens[0] {
    @compiler.JsxTagOpen(_) => ()
    _ => assert_true(false)
  }
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "br")
    _ => assert_true(false)
  }
  match tokens[2] {
    @compiler.SlashGreaterThan(_) => ()
    _ => assert_true(false)
  }
}

///|
test "scan jsx - element with attribute" {
  let tokens = @compiler.scan_all_jsx(
    "<div className=\"container\"></div>", "test.tsx",
  )
  // <, div, className, =, "container", >, </, div, >, EOF
  assert_true(tokens.length() >= 6)
  match tokens[2] {
    @compiler.Identifier(name, _) => assert_eq(name, "className")
    _ => assert_true(false)
  }
  match tokens[3] {
    @compiler.Equals(_) => ()
    _ => assert_true(false)
  }
  match tokens[4] {
    @compiler.StringLiteral(value, _) => assert_eq(value, "container")
    _ => assert_true(false)
  }
}

///|
test "scan jsx - element with text content" {
  let tokens = @compiler.scan_all_jsx("<span>Hello World</span>", "test.tsx")
  // <, span, >, Hello World, </, span, >, EOF
  assert_true(tokens.length() >= 5)
  // Check for JsxText token after opening tag
  let mut found_text = false
  for token in tokens {
    match token {
      @compiler.JsxText(text, _) => {
        assert_eq(text, "Hello World")
        found_text = true
      }
      _ => ()
    }
  }
  assert_true(found_text)
}

///|
test "scan jsx - element with expression" {
  let tokens = @compiler.scan_all_jsx("<span>{name}</span>", "test.tsx")
  // <, span, >, {, name, }, </, span, >, EOF
  assert_true(tokens.length() >= 7)
  // Check for expression start and end
  let mut found_expr_start = false
  let mut found_expr_end = false
  let mut found_name = false
  for token in tokens {
    match token {
      @compiler.JsxExpressionStart(_) => found_expr_start = true
      @compiler.JsxExpressionEnd(_) => found_expr_end = true
      @compiler.Identifier(name, _) => if name == "name" { found_name = true }
      _ => ()
    }
  }
  assert_true(found_expr_start)
  assert_true(found_expr_end)
  assert_true(found_name)
}

///|
test "scan jsx - closing tag" {
  let tokens = @compiler.scan_all_jsx("<div></div>", "test.tsx")
  // Check for LessThanSlash
  let mut found_closing = false
  for token in tokens {
    match token {
      @compiler.LessThanSlash(_) => found_closing = true
      _ => ()
    }
  }
  assert_true(found_closing)
}

///|
test "scan jsx - multiple attributes" {
  let tokens = @compiler.scan_all_jsx("<input disabled checked />", "test.tsx")
  // <, input, disabled, checked, />, EOF
  assert_true(tokens.length() >= 5)

  // Check we have input, disabled, and checked identifiers
  let mut found_input = false
  let mut found_disabled = false
  let mut found_checked = false
  for token in tokens {
    match token {
      @compiler.Identifier(ident_name, _) => {
        if ident_name == "input" {
          found_input = true
        }
        if ident_name == "disabled" {
          found_disabled = true
        }
        if ident_name == "checked" {
          found_checked = true
        }
      }
      _ => ()
    }
  }
  assert_true(found_input)
  assert_true(found_disabled)
  assert_true(found_checked)
}

///|
test "scan jsx - nested elements" {
  let tokens = @compiler.scan_all_jsx(
    "<div><span>Text</span></div>", "test.tsx",
  )
  // Contains nested structure
  assert_true(tokens.length() >= 10)

  // Count opening tags
  let mut tag_open_count = 0
  for token in tokens {
    match token {
      @compiler.JsxTagOpen(_) => tag_open_count = tag_open_count + 1
      _ => ()
    }
  }
  assert_eq(tag_open_count, 2)
}

///|
test "scan jsx - expression attribute" {
  let tokens = @compiler.scan_all_jsx(
    "<button onClick={handleClick}>Click</button>", "test.tsx",
  )
  // Check for expression in attribute
  let mut found_expr_start = false
  let mut found_handleClick = false
  for token in tokens {
    match token {
      @compiler.JsxExpressionStart(_) => found_expr_start = true
      @compiler.Identifier(name, _) =>
        if name == "handleClick" {
          found_handleClick = true
        }
      _ => ()
    }
  }
  assert_true(found_expr_start)
  assert_true(found_handleClick)
}

///|
test "scan jsx - fragment" {
  let tokens = @compiler.scan_all_jsx(
    "<><span>A</span><span>B</span></>", "test.tsx",
  )
  // Contains fragments and elements
  assert_true(tokens.length() >= 8)
}

///|
test "scan jsx - component name" {
  let tokens = @compiler.scan_all_jsx("<MyComponent/>", "test.tsx")
  // <, MyComponent, />, EOF
  assert_true(tokens.length() >= 3)
  match tokens[1] {
    @compiler.Identifier(name, _) => assert_eq(name, "MyComponent")
    _ => assert_true(false)
  }
}

///|
test "scan jsx - scanner state mode is standard initially" {
  let state = @compiler.ScannerState::new("<div>", "test.tsx")
  // Check mode using match pattern
  match state.mode {
    @compiler.Standard => ()
    _ => assert_true(false)
  }
}

///|
test "scan jsx - enter jsx mode changes to JSXText" {
  let state = @compiler.ScannerState::new("<div>", "test.tsx")
  let new_state = @compiler.enter_jsx_mode(state)
  // Check mode using match pattern
  match new_state.mode {
    @compiler.JSXText => ()
    _ => assert_true(false)
  }
}

///|
test "scan jsx - single quotes in attribute" {
  let tokens = @compiler.scan_all_jsx("<div data-id='123'></div>", "test.tsx")
  // Check for string literal with single quotes
  let mut found_string = false
  for token in tokens {
    match token {
      @compiler.StringLiteral(value, _) => {
        assert_eq(value, "123")
        found_string = true
      }
      _ => ()
    }
  }
  assert_true(found_string)
}

///|
test "scan jsx - boolean attribute" {
  let tokens = @compiler.scan_all_jsx("<input disabled />", "test.tsx")
  // <, input, disabled, />, EOF
  assert_true(tokens.length() >= 4)
  match tokens[2] {
    @compiler.Identifier(name, _) => assert_eq(name, "disabled")
    _ => assert_true(false)
  }
}

///|
test "scan jsx - whitespace in text" {
  let tokens = @compiler.scan_all_jsx("<p>  Hello   World  </p>", "test.tsx")
  // Check that whitespace is preserved in text
  let mut found_text = false
  for token in tokens {
    match token {
      @compiler.JsxText(text, _) => {
        assert_true(text.contains("Hello"))
        assert_true(text.contains("World"))
        found_text = true
      }
      _ => ()
    }
  }
  assert_true(found_text)
}
