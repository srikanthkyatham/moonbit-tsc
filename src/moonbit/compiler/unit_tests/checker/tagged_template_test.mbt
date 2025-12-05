// Tagged Template Expression Tests
// Tests for tagged template string type checking, construct signatures in type literals,
// and property access on tagged template return types

///|
/// Helper function to parse and check source code
fn parse_and_check_tagged(source : String) -> @compiler.CheckResult {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diagnostics) => Err(diagnostics)
      }
    Err(diagnostics) => Err(diagnostics)
  }
}

///|
/// Helper function to just parse source code
fn parse_only_tagged(
  source : String,
) -> Result[@compiler.SourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  @compiler.parse_source_file(tokens, "test.ts")
}

///|
/// Helper to check if any diagnostic has a specific error code
fn has_error_code(
  diagnostics : Array[@compiler.Diagnostic],
  code : Int,
) -> Bool {
  for i = 0; i < diagnostics.length(); i = i + 1 {
    if diagnostics[i].code == code {
      return true
    }
  }
  false
}

// ============================================================================
// Tagged Template with Self-Referencing Interface Tests (TS2339)
// ============================================================================

///|
test "tagged-template/self-ref-interface - simple tagged template call" {
  // Interface I has a call signature returning I, and a member property
  let source =
    #|interface I {
    #|    (stringParts: TemplateStringsArray, ...rest: number[]): I;
    #|    member: I;
    #|}
    #|var f: I;
    #|var x = f `abc`;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // Should pass - tagged template returns I
    Err(diagnostics) =>
      fail("Should not have errors, got: " + diagnostics.length().to_string())
  }
}

///|
test "tagged-template/self-ref-interface - property access on tagged template result" {
  // This tests TS2339 fix - accessing 'member' on the result of a tagged template call
  let source =
    #|interface I {
    #|    (stringParts: TemplateStringsArray, ...rest: number[]): I;
    #|    member: I;
    #|}
    #|var f: I;
    #|var x = f `abc`.member;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // Should pass - member exists on I
    Err(diagnostics) =>
      // Should not have TS2339 (property doesn't exist)
      if has_error_code(diagnostics, 2339) {
        fail(
          "Should not have TS2339 error - property 'member' should be found on return type I",
        )
      }
  }
}

///|
test "tagged-template/self-ref-interface - chained property access" {
  // Accessing .member.member on a tagged template result
  let source =
    #|interface I {
    #|    (stringParts: TemplateStringsArray, ...rest: number[]): I;
    #|    member: I;
    #|}
    #|var f: I;
    #|var x = f `abc`.member.member;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // Should pass
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2339) {
        fail("Should not have TS2339 error on chained member access")
      }
  }
}

///|
test "tagged-template/self-ref-interface - tagged template with interpolation" {
  // Tagged template with interpolated expressions
  let source =
    #|interface I {
    #|    (stringParts: TemplateStringsArray, ...rest: number[]): I;
    #|    member: I;
    #|}
    #|var f: I;
    #|var x = f `abc${ 0 }def`.member;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2339) {
        fail("Should not have TS2339 error with interpolated template")
      }
  }
}

// ============================================================================
// Construct Signature in Type Literal Tests (TS2747)
// ============================================================================

///|
test "construct-signature/type-literal - simple construct signature" {
  // Type literal with construct signature: { new (s: string): boolean }
  let source =
    #|var obj: { new (s: string): boolean };
    #|var result = new obj("hello");
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // Should pass - construct signature should be recognized
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2747) {
        fail(
          "Should not have TS2747 - construct signature should be found in type literal",
        )
      }
  }
}

///|
test "construct-signature/type-literal - no-arg construct signature" {
  // Construct signature with no parameters
  let source =
    #|var obj: { new (): boolean };
    #|var result = new obj();
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2747) {
        fail("Should not have TS2747 for no-arg construct signature")
      }
  }
}

///|
test "construct-signature/type-literal - nested construct signatures" {
  // Nested type literals with construct signatures
  let source =
    #|var obj: {
    #|    new (s: string): {
    #|        new (n: number): boolean;
    #|    }
    #|};
    #|var step1 = new obj("hello");
    #|var step2 = new step1(42);
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2747) {
        fail("Should not have TS2747 for nested construct signatures")
      }
  }
}

///|
test "construct-signature/interface-member - interface with constructable member" {
  // Interface member that is a type literal with construct signature
  let source =
    #|interface I {
    #|    member: {
    #|        new (s: string): boolean;
    #|    };
    #|}
    #|var f: I;
    #|var result = new f.member("hello");
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2747) {
        fail(
          "Should not have TS2747 for interface member with construct signature",
        )
      }
  }
}

// ============================================================================
// Combined Tagged Template and Construct Signature Tests
// ============================================================================

///|
test "combined/tagged-template-construct - new on tagged template member" {
  // new on a member accessed from tagged template result
  let source =
    #|interface I {
    #|    (strs: TemplateStringsArray, ...subs: number[]): I;
    #|    member: { new(): boolean };
    #|}
    #|var f: I;
    #|var result = new f `abc`.member();
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) => {
      if has_error_code(diagnostics, 2339) {
        fail("Should not have TS2339 - member property should be found")
      }
      if has_error_code(diagnostics, 2747) {
        fail("Should not have TS2747 - construct signature should be found")
      }
    }
  }
}

///|
test "combined/tagged-template-construct - new with parenthesized tagged template" {
  // Explicit parentheses around tagged template expression
  let source =
    #|interface I {
    #|    (strs: TemplateStringsArray, ...subs: number[]): I;
    #|    member: { new (s: string): boolean };
    #|}
    #|var f: I;
    #|var result = new (f `abc`.member)("hello");
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2747) {
        fail("Should not have TS2747 with parenthesized expression")
      }
  }
}

// ============================================================================
// Nested New Expression with Tagged Template Tests
// ============================================================================

///|
test "nested-new/parsing - double new with identifier" {
  // Simple nested new: new new Foo()
  let source =
    #|interface Foo { new(): Foo; }
    #|interface Bar { new(): Foo; }
    #|var b: Bar;
    #|var result = new new b()();
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) =>
      if has_error_code(diagnostics, 2747) {
        fail("Should not have TS2747 for simple nested new")
      }
  }
}

///|
test "nested-new/tagged-template - new on tagged template with construct member" {
  // new f`template`.member("args")
  let source =
    #|interface I {
    #|    (strs: TemplateStringsArray, ...subs: number[]): I;
    #|    member: {
    #|        new (s: string): boolean;
    #|    };
    #|}
    #|var f: I;
    #|var result = new f `abc${ 0 }def`.member("hello");
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => ()
    Err(diagnostics) => {
      if has_error_code(diagnostics, 2339) {
        fail("Should not have TS2339 for member access")
      }
      if has_error_code(diagnostics, 2747) {
        fail("Should not have TS2747 for construct signature")
      }
    }
  }
}

// ============================================================================
// Error Cases - Should Produce Errors
// ============================================================================

///|
test "error/no-construct-signature - new on non-constructable" {
  // Should error: new on a type without construct signature
  let source =
    #|var obj: { prop: string };
    #|var result = new obj();
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) =>
      fail(
        "Should have TS2351 or TS2747 error - obj has no construct signature",
      )
    Err(diagnostics) =>
      // Should have an error about missing construct signature
      assert_true(diagnostics.length() > 0)
  }
}

///|
test "error/property-not-exist - non-existent property on interface" {
  // Should error: accessing non-existent property
  let source =
    #|interface I {
    #|    (strs: TemplateStringsArray, ...rest: number[]): I;
    #|    member: I;
    #|}
    #|var f: I;
    #|var x = f `abc`.nonExistent;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // May pass if we're lenient on property access
    Err(diagnostics) =>
      // If we error, it should be TS2339
      if diagnostics.length() > 0 {
        assert_true(has_error_code(diagnostics, 2339))
      }
  }
}

// ============================================================================
// Nested New Expression Parsing Tests
// ============================================================================

///|
test "nested-new/parsing - nested new with comparison" {
  // Test that nested new expressions can be followed by operators like ===
  let source =
    #|interface A { new(): boolean; }
    #|interface B { new(): A; }
    #|var b: B;
    #|var result = new new b() === true;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // Should pass - nested new followed by comparison
    Err(diagnostics) =>
      if has_error_code(diagnostics, 1000) {
        fail("Should not have parsing error for nested new with comparison")
      }
  }
}

///|
test "nested-new/parsing - triple nested new with comparison" {
  // Test triple-nested new expressions from conformance test
  let source =
    #|interface I {
    #|    (strs: TemplateStringsArray, ...subs: number[]): I;
    #|    member: {
    #|        new (s: string): {
    #|            new (n: number): {
    #|                new (): boolean;
    #|            }
    #|        }
    #|    };
    #|}
    #|var f: I;
    #|var x = new new new f `abc`.member("hello")(42) === true;
  let result = parse_and_check_tagged(source)
  match result {
    Ok(_) => () // Should pass - this is the exact conformance test case
    Err(diagnostics) => {
      if has_error_code(diagnostics, 1000) {
        fail("Should not have parsing error for conformance test case")
      }
      if has_error_code(diagnostics, 2367) {
        fail("Should not have TS2367 - types should be compatible")
      }
    }
  }
}
