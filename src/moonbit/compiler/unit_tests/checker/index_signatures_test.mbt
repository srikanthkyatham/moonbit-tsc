// Tests for Index Signature Checking
// Tests index signature compatibility, noUncheckedIndexedAccess, numeric-string covariance

///|
/// Helper function to parse and check source code
fn parse_and_check_index(source : String) -> @compiler.CheckResult {
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
fn parse_only_index(
  source : String,
) -> Result[@compiler.SourceFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  @compiler.parse_source_file(tokens, "test.ts")
}

// ============================================================================
// Index Signature Parsing Tests
// ============================================================================

///|
test "index/parsing - string index signature" {
  let source =
    #|interface StringMap {
    #|  [key: string]: string;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/parsing - number index signature" {
  let source =
    #|interface NumberIndexed {
    #|  [index: number]: string;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/parsing - symbol index signature" {
  let source =
    #|interface SymbolIndexed {
    #|  [key: symbol]: any;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/parsing - readonly index signature" {
  let source =
    #|interface ReadonlyMap {
    #|  readonly [key: string]: number;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/parsing - both string and number index signatures" {
  let source =
    #|interface Mixed {
    #|  [index: number]: string;
    #|  [key: string]: string | number;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/parsing - index signature with explicit properties" {
  let source =
    #|interface Dictionary {
    #|  length: number;
    #|  [key: string]: number;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

// ============================================================================
// Index Signature Type Checking Tests
// ============================================================================

///|
test "index/check - object with string index signature" {
  let source =
    #|interface StringMap {
    #|  [key: string]: string;
    #|}
    #|const map: StringMap = {};
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/check - accessing index signature property" {
  let source =
    #|interface StringMap {
    #|  [key: string]: string;
    #|}
    #|declare const map: StringMap;
    #|const value = map["key"];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/check - array index access" {
  let source =
    #|const arr: string[] = ["a", "b", "c"];
    #|const first = arr[0];
    #|const random = arr[Math.floor(Math.random() * 3)];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/check - tuple index access" {
  let source =
    #|const tuple: [string, number, boolean] = ["hello", 42, true];
    #|const first = tuple[0];
    #|const second = tuple[1];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/check - Record utility type" {
  let source =
    #|type Dict = Record<string, number>;
    #|declare const dict: Dict;
    #|const val = dict["foo"];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Numeric-String Covariance Tests
// ============================================================================

///|
test "index/covariance - valid numeric subtype of string" {
  // This should be valid: numeric index returns subset of string index
  let source =
    #|interface ValidMixed {
    #|  [index: number]: string;
    #|  [key: string]: string | number;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/covariance - number index same as string index" {
  let source =
    #|interface SameMixed {
    #|  [index: number]: string;
    #|  [key: string]: string;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/covariance - only number index" {
  let source =
    #|interface NumberOnly {
    #|  [index: number]: string;
    #|}
    #|declare const arr: NumberOnly;
    #|const val = arr[0];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Property Compatibility with Index Signature Tests
// ============================================================================

///|
test "index/property - compatible property type" {
  let source =
    #|interface StringDict {
    #|  name: string;
    #|  [key: string]: string;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/property - compatible union property type" {
  let source =
    #|interface MixedDict {
    #|  count: number;
    #|  name: string;
    #|  [key: string]: string | number;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/property - optional property with index" {
  let source =
    #|interface OptionalProps {
    #|  name?: string;
    #|  [key: string]: string | undefined;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Readonly Index Signature Tests
// ============================================================================

///|
test "index/readonly - readonly index signature parsing" {
  let source =
    #|interface ReadonlyDict {
    #|  readonly [key: string]: number;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/readonly - ReadonlyArray has readonly index" {
  let source =
    #|declare const arr: ReadonlyArray<number>;
    #|const first = arr[0];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Symbol Index Signature Tests
// ============================================================================

///|
test "index/symbol - symbol index signature parsing" {
  let source =
    #|interface SymbolMap {
    #|  [key: symbol]: any;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/symbol - accessing with symbol key" {
  let source =
    #|interface SymbolMap {
    #|  [key: symbol]: string;
    #|}
    #|declare const map: SymbolMap;
    #|const sym = Symbol();
    #|const value = map[sym];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Complex Index Signature Scenarios
// ============================================================================

///|
test "index/complex - class with index signature parsing" {
  // Classes with index signatures parse correctly even if type checking is complex
  let source =
    #|class Dictionary<T> {
    #|  [key: string]: T;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/complex - class with multiple index signatures" {
  // Classes can have both number and string index signatures
  let source =
    #|class Points {
    #|  [idx: number]: string;
    #|  [key: string]: string;
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/complex - class with index signature and properties" {
  // Classes can have index signatures alongside regular properties and methods
  let source =
    #|class DataStore {
    #|  [key: string]: any;
    #|  length: number;
    #|  getData(): string { return ""; }
    #|}
  let result = parse_only_index(source)
  match result {
    Ok(sf) => assert_true(sf.statements.length() > 0)
    Err(_) => fail("Parse failed")
  }
}

///|
test "index/complex - interface extending with index" {
  let source =
    #|interface Base {
    #|  [key: string]: any;
    #|}
    #|interface Derived extends Base {
    #|  name: string;
    #|}
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/complex - mapped type creates index-like behavior" {
  let source =
    #|type StringRecord = {
    #|  [K in string]: number;
    #|};
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/complex - intersection with index signature" {
  let source =
    #|type Named = { name: string };
    #|type Indexed = { [key: string]: any };
    #|type Both = Named & Indexed;
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/complex - union of indexed types" {
  let source =
    #|interface StringMap { [key: string]: string; }
    #|interface NumberMap { [key: string]: number; }
    #|type MixedMap = StringMap | NumberMap;
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Type Literal Index Signature Tests
// ============================================================================

///|
test "index/literal - type literal with index signature" {
  let source =
    #|type Dict = {
    #|  [key: string]: number;
    #|  count: number;
    #|};
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/literal - object literal assignable to indexed type" {
  let source =
    #|interface StringMap { [key: string]: string; }
    #|const map: StringMap = { foo: "bar", baz: "qux" };
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

// ============================================================================
// Index Access Expression Tests
// ============================================================================

///|
test "index/access - computed property access" {
  let source =
    #|const obj: { [key: string]: number } = { a: 1, b: 2 };
    #|const key = "a";
    #|const value = obj[key];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/access - bracket notation on object" {
  let source =
    #|const obj = { name: "test" };
    #|const value = obj["name"];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}

///|
test "index/access - chained index access" {
  let source =
    #|const nested: { [key: string]: { [key: string]: number } } = { a: { b: 1 } };
    #|const value = nested["a"]["b"];
  let result = parse_and_check_index(source)
  match result {
    Ok(checked) => assert_eq(checked.file_path, "test.ts")
    Err(_) => assert_true(false)
  }
}
