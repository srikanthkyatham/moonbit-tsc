///|
/// Unit tests for parser handling of [Symbol.iterator]() and [Symbol.asyncIterator]()
/// Tests that computed property names are correctly parsed

///|
test "parser: class with [Symbol.iterator]() method parses successfully" {
  let source =
    #|class MyIterator {
    #|    [Symbol.iterator]() {
    #|        return this;
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors for [Symbol.iterator](): \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: class with [Symbol.asyncIterator]() method parses successfully" {
  let source =
    #|class AsyncIter {
    #|    [Symbol.asyncIterator]() {
    #|        return this;
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors for [Symbol.asyncIterator](): \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: object literal with [Symbol.iterator]() parses successfully" {
  let source =
    #|const obj = {
    #|    [Symbol.iterator]() {
    #|        return this;
    #|    }
    #|};

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: static [Symbol.iterator]() method parses successfully" {
  let source =
    #|class StaticIter {
    #|    static [Symbol.iterator]() {
    #|        return [];
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: generator with [Symbol.iterator]() parses successfully" {
  let source =
    #|class GenIter {
    #|    *[Symbol.iterator]() {
    #|        yield 1;
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: [Symbol.iterator]() with return type annotation parses successfully" {
  let source =
    #|class TypedIter {
    #|    [Symbol.iterator](): TypedIter {
    #|        return this;
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: async [Symbol.asyncIterator]() parses successfully" {
  let source =
    #|class AsyncGen {
    #|    async *[Symbol.asyncIterator]() {
    #|        yield 1;
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: multiple Symbol methods in same class parse successfully" {
  let source =
    #|class MultiSymbol {
    #|    [Symbol.iterator]() {
    #|        return this;
    #|    }
    #|    [Symbol.asyncIterator]() {
    #|        return this;
    #|    }
    #|    next() {
    #|        return { value: 1, done: false };
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: [Symbol.iterator]() in nested class parses successfully" {
  let source =
    #|class Outer {
    #|    inner = class Inner {
    #|        [Symbol.iterator]() {
    #|            return this;
    #|        }
    #|    };
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}

///|
test "parser: [Symbol.iterator]() with complex return type parses successfully" {
  let source =
    #|class ComplexReturn {
    #|    [Symbol.iterator](): IterableIterator<string> {
    #|        return null as any;
    #|    }
    #|}

  match parse_only(source) {
    Ok(_) => assert_true(true)
    Err(diagnostics) => {
      println("Parse errors: \{diagnostics}")
      assert_true(false)
    }
  }
}
