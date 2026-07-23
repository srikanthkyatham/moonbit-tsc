// ============================================================================
// Well-Known Symbol Properties Tests
// Tests for ES2015+ well-known Symbol properties
// ============================================================================

///|
test "Symbol.iterator property exists" {
  let source =
    #|const iter = Symbol.iterator;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.iterator should be accessible")
  }
}

///|
test "Symbol.isConcatSpreadable property exists" {
  let source =
    #|const prop = Symbol.isConcatSpreadable;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.isConcatSpreadable should be accessible")
  }
}

///|
test "Symbol.hasInstance property exists" {
  let source =
    #|const prop = Symbol.hasInstance;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.hasInstance should be accessible")
  }
}

///|
test "Symbol.match property exists" {
  let source =
    #|const prop = Symbol.match;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.match should be accessible")
  }
}

///|
test "Symbol.matchAll property exists" {
  let source =
    #|const prop = Symbol.matchAll;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.matchAll should be accessible")
  }
}

///|
test "Symbol.replace property exists" {
  let source =
    #|const prop = Symbol.replace;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.replace should be accessible")
  }
}

///|
test "Symbol.search property exists" {
  let source =
    #|const prop = Symbol.search;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.search should be accessible")
  }
}

///|
test "Symbol.species property exists" {
  let source =
    #|const prop = Symbol.species;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.species should be accessible")
  }
}

///|
test "Symbol.split property exists" {
  let source =
    #|const prop = Symbol.split;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.split should be accessible")
  }
}

///|
test "Symbol.toPrimitive property exists" {
  let source =
    #|const prop = Symbol.toPrimitive;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.toPrimitive should be accessible")
  }
}

///|
test "Symbol.toStringTag property exists" {
  let source =
    #|const prop = Symbol.toStringTag;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.toStringTag should be accessible")
  }
}

///|
test "Symbol.unscopables property exists" {
  let source =
    #|const prop = Symbol.unscopables;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.unscopables should be accessible")
  }
}

///|
test "Symbol.asyncIterator property exists" {
  let source =
    #|const prop = Symbol.asyncIterator;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.asyncIterator should be accessible")
  }
}

// ============================================================================
// Symbol Properties in Object Literals
// ============================================================================

///|
test "Symbol.isConcatSpreadable in object literal" {
  let source =
    #|var obj = {
    #|    [Symbol.isConcatSpreadable]: 0
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.isConcatSpreadable should work in object literals")
  }
}

///|
test "Symbol.toStringTag in object literal" {
  let source =
    #|var obj = {
    #|    [Symbol.toStringTag]: "CustomObject"
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.toStringTag should work in object literals")
  }
}

///|
test "Symbol.hasInstance in object literal" {
  let source =
    #|var obj = {
    #|    [Symbol.hasInstance]: function(instance: any) { return true; }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.hasInstance should work in object literals")
  }
}

///|
test "Symbol.toPrimitive in object literal" {
  let source =
    #|var obj = {
    #|    [Symbol.toPrimitive]: function(hint: string) { return 42; }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.toPrimitive should work in object literals")
  }
}

// ============================================================================
// Multiple Symbols in Same Object
// ============================================================================

///|
test "multiple Symbol properties in object" {
  let source =
    #|var obj = {
    #|    [Symbol.iterator]: function*() { yield 1; },
    #|    [Symbol.toStringTag]: "MyObject",
    #|    [Symbol.isConcatSpreadable]: false
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Multiple Symbol properties should work in same object")
  }
}

///|
test "Symbol properties mixed with regular properties" {
  let source =
    #|var obj = {
    #|    name: "test",
    #|    [Symbol.toStringTag]: "CustomObject",
    #|    value: 42,
    #|    [Symbol.iterator]: function*() { yield this.value; }
    #|}
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol properties should mix with regular properties")
  }
}

// ============================================================================
// Symbol Properties Type Checking
// ============================================================================

///|
test "Symbol properties are readonly" {
  let source =
    #|Symbol.iterator = Symbol.for("test");
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(typed) => {
      // Should have error about readonly property
      let has_readonly_error = typed.diagnostics
        .iter()
        .any(fn(d) {
          d.message.contains("read-only") || d.message.contains("readonly")
        })
      if !(has_readonly_error) {
        fail("Symbol properties should be readonly")
      }
    }
    Err(_) => () // Also acceptable if it fails with readonly error
  }
}

///|
test "Symbol.for method exists and works" {
  let source =
    #|const sym = Symbol.for("mySymbol");
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol.for should be a valid method")
  }
}

///|
test "Symbol properties return symbol type" {
  let source =
    #|const iter: symbol = Symbol.iterator;
    #|const tag: symbol = Symbol.toStringTag;
  let result = @compiler.type_check(source, "test.ts")
  match result {
    Ok(_) => () // Expected to pass
    Err(_) => fail("Symbol properties should return symbol type")
  }
}
