// JSDoc Processing Tests
// Tests for the JSDoc parsing and processing functionality

///|
/// Helper function to create tokens from source
fn jsdoc_tokens_from_source(source : String) -> Array[@compiler.Token] {
  let scanner = @compiler.Scanner::new(source, "test.ts")
  @compiler.scan_all(scanner)
}

// ============================================================================
// JSDoc Comment Recognition Tests
// ============================================================================

///|
test "scan JSDoc comment token" {
  let source = "/** This is a JSDoc comment */"
  let tokens = jsdoc_tokens_from_source(source)
  // Find the JSDoc token
  let mut found = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(_, _) => {
        found = true
      }
      _ => ()
    }
  }
  assert_eq(found, true)
}

///|
test "scan multiline JSDoc comment" {
  let source = "/**\n * Line 1\n * Line 2\n */"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(_, _) => {
        found = true
      }
      _ => ()
    }
  }
  assert_eq(found, true)
}

///|
test "distinguish JSDoc from regular multiline comment" {
  let source = "/* This is a regular comment */"
  let tokens = jsdoc_tokens_from_source(source)
  let mut jsdoc_found = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(_, _) => {
        jsdoc_found = true
      }
      _ => ()
    }
  }
  // Regular comments should not be JSDoc
  assert_eq(jsdoc_found, false)
}

///|
test "JSDoc before function" {
  let source = "/** Description */\nfunction foo() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut jsdoc_found = false
  let mut function_found = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(_, _) => jsdoc_found = true
      @compiler.Token::KeywordFunction(_) => function_found = true
      _ => ()
    }
  }
  assert_eq(jsdoc_found, true)
  assert_eq(function_found, true)
}

// ============================================================================
// JSDoc Tag Recognition Tests
// ============================================================================

///|
test "JSDoc with @param tag" {
  let source = "/** @param {string} name The name */\nfunction foo(name) {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_param_content = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_param_content = content.contains("@param")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_param_content, true)
}

///|
test "JSDoc with @returns tag" {
  let source = "/** @returns {number} The result */\nfunction foo() { return 1; }"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_returns = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_returns = content.contains("@returns")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_returns, true)
}

///|
test "JSDoc with @type tag" {
  let source = "/** @type {string} */\nconst x = 'hello';"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_type = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_type = content.contains("@type")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_type, true)
}

///|
test "JSDoc with @deprecated tag" {
  let source = "/** @deprecated Use newFunction instead */\nfunction oldFunction() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_deprecated = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_deprecated = content.contains("@deprecated")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_deprecated, true)
}

///|
test "JSDoc with @template tag" {
  let source = "/** @template T */\nfunction identity(x) { return x; }"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_template = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_template = content.contains("@template")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_template, true)
}

///|
test "JSDoc with @throws tag" {
  let source = "/** @throws {Error} When something goes wrong */\nfunction risky() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_throws = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_throws = content.contains("@throws")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_throws, true)
}

// ============================================================================
// JSDoc Multiple Tags Tests
// ============================================================================

///|
test "JSDoc with multiple tags" {
  let source = "/**\n * @param {string} a First param\n * @param {number} b Second param\n * @returns {boolean} Result\n */\nfunction test(a, b) { return true; }"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_all_tags = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_all_tags = content.contains("@param") && content.contains("@returns")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_all_tags, true)
}

// ============================================================================
// JSDoc Edge Cases
// ============================================================================

///|
test "JSDoc empty comment" {
  let source = "/** */\nfunction foo() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(_, _) => {
        found_jsdoc = true
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
}

///|
test "JSDoc with code example" {
  let source = "/**\n * @example\n * const result = foo();\n * console.log(result);\n */\nfunction foo() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_example = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_example = content.contains("@example")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_example, true)
}

///|
test "JSDoc with @see tag" {
  let source = "/** @see https://example.com */\nfunction foo() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_see = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_see = content.contains("@see")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_see, true)
}

///|
test "JSDoc with @author tag" {
  let source = "/** @author John Doe */\nfunction foo() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_author = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_author = content.contains("@author")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_author, true)
}

///|
test "JSDoc with @typedef tag" {
  let source = "/**\n * @typedef {Object} Person\n * @property {string} name\n * @property {number} age\n */"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_typedef = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_typedef = content.contains("@typedef")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_typedef, true)
}

///|
test "JSDoc with access modifiers" {
  let source = "/** @public */\nfunction publicFunc() {}\n/** @private */\nfunction privateFunc() {}\n/** @protected */\nfunction protectedFunc() {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut public_found = false
  let mut private_found = false
  let mut protected_found = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        if content.contains("@public") {
          public_found = true
        }
        if content.contains("@private") {
          private_found = true
        }
        if content.contains("@protected") {
          protected_found = true
        }
      }
      _ => ()
    }
  }
  assert_eq(public_found, true)
  assert_eq(private_found, true)
  assert_eq(protected_found, true)
}

// ============================================================================
// JSDoc Complex Types Tests
// ============================================================================

///|
test "JSDoc with union type" {
  let source = "/** @param {string|number} value */\nfunction foo(value) {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_union = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_union = content.contains("string|number")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_union, true)
}

///|
test "JSDoc with array type" {
  let source = "/** @param {string[]} names */\nfunction foo(names) {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_array = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_array = content.contains("string[]")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_array, true)
}

///|
test "JSDoc with generic type" {
  let source = "/** @param {Array<string>} names */\nfunction foo(names) {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_generic = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_generic = content.contains("Array<string>")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_generic, true)
}

///|
test "JSDoc with optional parameter" {
  let source = "/** @param {string} [name] Optional name */\nfunction foo(name) {}"
  let tokens = jsdoc_tokens_from_source(source)
  let mut found_jsdoc = false
  let mut has_optional = false
  for token in tokens {
    match token {
      @compiler.Token::JSDocComment(content, _) => {
        found_jsdoc = true
        has_optional = content.contains("[name]")
      }
      _ => ()
    }
  }
  assert_eq(found_jsdoc, true)
  assert_eq(has_optional, true)
}
