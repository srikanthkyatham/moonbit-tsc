// End-to-end integration tests for TypeScript compilation
// Tests complete compilation pipeline from source to JavaScript

///|
/// Helper to compile TypeScript source and get JavaScript output
/// Uses the same approach as emitter_integration_test.mbt
fn e2e_compile_to_js(source : String) -> String {
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let transform_ctx = TransformerContext::default()
      let emit_ctx = EmitterContext::default()

      // Transform and emit each statement
      let mut result = ""
      for i = 0; i < source_file.statements.length(); i = i + 1 {
        let stmt = source_file.statements[i]
        let transformed_stmt = transform(stmt, transform_ctx)
        let emitted = emit(transformed_stmt, emit_ctx)
        result = result + emitted
        if i < source_file.statements.length() - 1 {
          result = result + "\n"
        }
      }
      result
    }
    Err(_) => ""
  }
}

///|
/// Helper to check if parsing succeeds
fn e2e_parse_succeeds(source : String) -> Bool {
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(_) => true
    Err(_) => false
  }
}

// ============================================================================
// Basic Variable Declarations
// ============================================================================

///|
test "e2e: const declaration" {
  let js = e2e_compile_to_js("const x = 42;")
  assert_true(js.contains("const x = 42"))
}

///|
test "e2e: let declaration" {
  let js = e2e_compile_to_js("let y = 'hello';")
  assert_true(js.contains("let y"))
}

///|
test "e2e: var declaration" {
  let js = e2e_compile_to_js("var z = true;")
  assert_true(js.contains("var z = true"))
}

// ============================================================================
// Functions
// ============================================================================

///|
test "e2e: simple function" {
  let js = e2e_compile_to_js("function greet(name) { return 'Hello ' + name; }")
  assert_true(js.contains("function greet"))
}

///|
test "e2e: arrow function" {
  let js = e2e_compile_to_js("const add = (a, b) => a + b;")
  assert_true(js.contains("=>"))
}

// ============================================================================
// Classes
// ============================================================================

///|
test "e2e: class declaration" {
  let js = e2e_compile_to_js(
    "class Person { constructor(name) { this.name = name; } }",
  )
  assert_true(js.contains("class Person"))
}

// ============================================================================
// Control Flow
// ============================================================================

///|
test "e2e: if statement" {
  let js = e2e_compile_to_js("if (x > 0) { console.log('positive'); }")
  assert_true(js.contains("if"))
}

///|
test "e2e: for loop" {
  let js = e2e_compile_to_js("for (let i = 0; i < 10; i++) { sum += i; }")
  assert_true(js.contains("for"))
}

///|
test "e2e: while loop" {
  let js = e2e_compile_to_js("while (condition) { doSomething(); }")
  assert_true(js.contains("while"))
}

// ============================================================================
// Operators and Expressions
// ============================================================================

///|
test "e2e: binary operators" {
  let js = e2e_compile_to_js("const result = a + b * c;")
  assert_true(js.contains("+"))
}

///|
test "e2e: ternary operator" {
  let js = e2e_compile_to_js("const max = a > b ? a : b;")
  assert_true(js.contains("?"))
}

// ============================================================================
// Modules
// ============================================================================

///|
test "e2e: import statement" {
  let js = e2e_compile_to_js("import { foo } from './module';")
  assert_true(js.contains("import"))
}

///|
test "e2e: export statement" {
  let js = e2e_compile_to_js("export const PI = 3.14159;")
  assert_true(js.contains("export"))
}

// ============================================================================
// Literals
// ============================================================================

///|
test "e2e: integer literal" {
  let js = e2e_compile_to_js("const n = 42;")
  assert_true(js.contains("42"))
}

///|
test "e2e: boolean literal" {
  let js = e2e_compile_to_js("const b = true;")
  assert_true(js.contains("true"))
}

///|
test "e2e: null literal" {
  let js = e2e_compile_to_js("const n = null;")
  assert_true(js.contains("null"))
}

// ============================================================================
// Basic Statements
// ============================================================================

///|
test "e2e: empty source" {
  let success = e2e_parse_succeeds("")
  assert_true(success)
}

///|
test "e2e: comment only" {
  let success = e2e_parse_succeeds("// This is a comment")
  assert_true(success)
}

// ============================================================================
// More Control Flow
// ============================================================================

///|
test "e2e: if-else statement" {
  let js = e2e_compile_to_js("if (x > 0) { y = 1; } else { y = 0; }")
  assert_true(js.contains("else"))
}

///|
test "e2e: do-while loop" {
  let js = e2e_compile_to_js("do { x++; } while (x < 10);")
  assert_true(js.contains("do"))
}

///|
test "e2e: switch statement" {
  let js = e2e_compile_to_js("switch (day) { case 0: break; default: break; }")
  assert_true(js.contains("switch"))
}

///|
test "e2e: try-catch" {
  let js = e2e_compile_to_js("try { riskyOp(); } catch (e) { handle(e); }")
  assert_true(js.contains("try"))
  assert_true(js.contains("catch"))
}

// ============================================================================
// More Operators
// ============================================================================

///|
test "e2e: comparison operators" {
  let js = e2e_compile_to_js("const isEqual = a === b;")
  assert_true(js.contains("==="))
}

///|
test "e2e: logical operators" {
  let js = e2e_compile_to_js("const result = a && b || c;")
  assert_true(js.contains("&&"))
}

///|
test "e2e: unary negation" {
  let js = e2e_compile_to_js("const neg = -x;")
  assert_true(js.contains("-x"))
}

///|
test "e2e: logical not" {
  let js = e2e_compile_to_js("const notX = !x;")
  assert_true(js.contains("!x"))
}

///|
test "e2e: typeof operator" {
  let js = e2e_compile_to_js("const t = typeof x;")
  assert_true(js.contains("typeof"))
}

///|
test "e2e: increment operator" {
  let js = e2e_compile_to_js("x++;")
  assert_true(js.contains("++"))
}

// ============================================================================
// Objects and Arrays
// ============================================================================

///|
test "e2e: object literal" {
  let js = e2e_compile_to_js("const obj = { name: 'test', value: 42 };")
  assert_true(js.contains("name"))
}

///|
test "e2e: array literal" {
  let js = e2e_compile_to_js("const arr = [1, 2, 3, 4, 5];")
  assert_true(js.contains("["))
}

///|
test "e2e: property access" {
  let js = e2e_compile_to_js("const value = obj.prop;")
  assert_true(js.contains("prop"))
}

///|
test "e2e: index access" {
  let js = e2e_compile_to_js("const item = arr[0];")
  assert_true(js.contains("[0]"))
}

// ============================================================================
// Function Calls
// ============================================================================

///|
test "e2e: function call" {
  let js = e2e_compile_to_js("const result = func(arg1, arg2);")
  assert_true(js.contains("func"))
}

///|
test "e2e: method call" {
  let js = e2e_compile_to_js("const result = obj.method(arg);")
  assert_true(js.contains("method"))
}

///|
test "e2e: new expression" {
  let js = e2e_compile_to_js("const instance = new MyClass();")
  assert_true(js.contains("new"))
}

// ============================================================================
// Statement Keywords
// ============================================================================

///|
test "e2e: return statement" {
  let js = e2e_compile_to_js("function f() { return 42; }")
  assert_true(js.contains("return 42"))
}

///|
test "e2e: throw statement" {
  let js = e2e_compile_to_js("throw new Error('message');")
  assert_true(js.contains("throw"))
}

///|
test "e2e: break statement" {
  let js = e2e_compile_to_js(
    "for (let i = 0; i < 10; i++) { if (i === 5) break; }",
  )
  assert_true(js.contains("break"))
}

///|
test "e2e: continue statement" {
  let js = e2e_compile_to_js(
    "for (let i = 0; i < 10; i++) { if (i === 5) continue; sum += i; }",
  )
  assert_true(js.contains("continue"))
}

// ============================================================================
// Jest-Style Test Syntax
// ============================================================================

///|
test "e2e: jest describe block" {
  let js = e2e_compile_to_js("describe('User tests', () => { });")
  assert_true(js.contains("describe"))
}

///|
test "e2e: jest test function" {
  let js = e2e_compile_to_js(
    "test('should add numbers', () => { expect(1 + 1).toBe(2); });",
  )
  assert_true(js.contains("test"))
  assert_true(js.contains("expect"))
}

///|
test "e2e: jest it function" {
  let js = e2e_compile_to_js(
    "it('should work correctly', () => { expect(true).toBeTruthy(); });",
  )
  assert_true(js.contains("it"))
}

///|
test "e2e: jest nested describe" {
  let js = e2e_compile_to_js(
    "describe('Outer', () => { describe('Inner', () => { test('nested test', () => {}); }); });",
  )
  assert_true(js.contains("describe"))
}

///|
test "e2e: jest async test" {
  let js = e2e_compile_to_js(
    "test('async test', async () => { const result = await fetchData(); expect(result).toBeDefined(); });",
  )
  assert_true(js.contains("async"))
  assert_true(js.contains("await"))
}

///|
test "e2e: jest beforeEach" {
  let js = e2e_compile_to_js("beforeEach(() => { setup(); });")
  assert_true(js.contains("beforeEach"))
}

///|
test "e2e: jest afterEach" {
  let js = e2e_compile_to_js("afterEach(() => { cleanup(); });")
  assert_true(js.contains("afterEach"))
}

///|
test "e2e: jest beforeAll" {
  let js = e2e_compile_to_js(
    "beforeAll(async () => { await initializeDatabase(); });",
  )
  assert_true(js.contains("beforeAll"))
}

///|
test "e2e: jest afterAll" {
  let js = e2e_compile_to_js(
    "afterAll(async () => { await closeConnection(); });",
  )
  assert_true(js.contains("afterAll"))
}

///|
test "e2e: jest expect matchers" {
  let js = e2e_compile_to_js(
    "expect(value).toBe(expected); expect(arr).toContain(item); expect(obj).toEqual({ a: 1 });",
  )
  assert_true(js.contains("toBe"))
  assert_true(js.contains("toContain"))
  assert_true(js.contains("toEqual"))
}

///|
test "e2e: jest test.each" {
  let js = e2e_compile_to_js(
    "test.each([[1, 2, 3], [2, 3, 5]])('add(%i, %i) = %i', (a, b, expected) => { expect(a + b).toBe(expected); });",
  )
  assert_true(js.contains("test.each"))
}

///|
test "e2e: jest describe.each" {
  let js = e2e_compile_to_js(
    "describe.each([['mobile'], ['desktop']])('on %s', (viewport) => { test('renders correctly', () => {}); });",
  )
  assert_true(js.contains("describe.each"))
}

///|
test "e2e: jest mock functions" {
  let js = e2e_compile_to_js("const mockFn = jest.fn(); jest.mock('./module');")
  assert_true(js.contains("jest.fn"))
  assert_true(js.contains("jest.mock"))
}

// ============================================================================
// Playwright-Style Test Syntax
// ============================================================================

///|
test "e2e: playwright test.describe" {
  let js = e2e_compile_to_js("test.describe('Different users', () => { });")
  assert_true(js.contains("test.describe"))
}

///|
test "e2e: playwright test with page fixture" {
  let js = e2e_compile_to_js(
    "test('should display data', async ({ page }) => { await page.goto('/'); });",
  )
  assert_true(js.contains("page"))
  assert_true(js.contains("goto"))
}

///|
test "e2e: playwright test with destructured fixtures" {
  let js = e2e_compile_to_js(
    "test('admin test', async ({ page, context, browser }) => { });",
  )
  assert_true(js.contains("page"))
  assert_true(js.contains("context"))
  assert_true(js.contains("browser"))
}

///|
test "e2e: playwright page interactions" {
  let js = e2e_compile_to_js(
    "test('clicks button', async ({ page }) => { await page.click('button'); await page.fill('input', 'text'); });",
  )
  assert_true(js.contains("click"))
  assert_true(js.contains("fill"))
}

///|
test "e2e: playwright locators" {
  let js = e2e_compile_to_js(
    "test('finds element', async ({ page }) => { const btn = page.locator('button'); await btn.click(); });",
  )
  assert_true(js.contains("locator"))
}

///|
test "e2e: playwright expect assertions" {
  let js = e2e_compile_to_js(
    "test('visible element', async ({ page }) => { await expect(page.locator('h1')).toBeVisible(); });",
  )
  assert_true(js.contains("expect"))
  assert_true(js.contains("toBeVisible"))
}

///|
test "e2e: playwright test.beforeEach" {
  let js = e2e_compile_to_js(
    "test.beforeEach(async ({ page }) => { await page.goto('/login'); });",
  )
  assert_true(js.contains("test.beforeEach"))
}

///|
test "e2e: playwright test.afterEach" {
  let js = e2e_compile_to_js(
    "test.afterEach(async ({ page }) => { await page.close(); });",
  )
  assert_true(js.contains("test.afterEach"))
}

///|
test "e2e: playwright test.use" {
  let js = e2e_compile_to_js("test.use({ storageState: 'auth.json' });")
  assert_true(js.contains("test.use"))
}

///|
test "e2e: playwright test.skip" {
  let js = e2e_compile_to_js(
    "test.skip('skipped test', async ({ page }) => { });",
  )
  assert_true(js.contains("test.skip"))
}

///|
test "e2e: playwright test.only" {
  let js = e2e_compile_to_js(
    "test.only('focused test', async ({ page }) => { });",
  )
  assert_true(js.contains("test.only"))
}

///|
test "e2e: playwright complex page operations" {
  let source =
    #|test('table data', async ({ page }) => {
    #|  await page.goto('/admin');
    #|  await expect(page.locator('table')).toBeVisible();
    #|  const rows = page.locator('tr');
    #|  await expect(rows).toHaveCount(5);
    #|});
  let js = e2e_compile_to_js(source)
  assert_true(js.contains("goto"))
  assert_true(js.contains("locator"))
  assert_true(js.contains("toHaveCount"))
}

///|
test "e2e: playwright nested describe blocks" {
  let source =
    #|test.describe('Different users', () => {
    #|  test.describe('Admin', () => {
    #|    test('should display areas table', async ({ page }) => {
    #|      await page.goto('/admin/areas');
    #|    });
    #|  });
    #|});
  let js = e2e_compile_to_js(source)
  assert_true(js.contains("test.describe"))
  assert_true(js.contains("Admin"))
}

// ============================================================================
// Hashbang (Shebang) Tests
// ============================================================================

///|
/// Helper to compile TypeScript source with hashbang support using compile_source_file
fn e2e_compile_with_hashbang(source : String) -> String {
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let transform_ctx = TransformerContext::default()
      let emit_ctx = EmitterContext::default()
      // Use compile_source_file which properly handles hashbang
      compile_source_file(source_file, transform_ctx, emit_ctx)
    }
    Err(_) => ""
  }
}

///|
test "e2e: hashbang is preserved in output" {
  let js = e2e_compile_with_hashbang("#!/usr/bin/env node\nconst x = 1;")
  assert_true(js.contains("#!/usr/bin/env node"))
  assert_true(js.contains("const x = 1"))
}

///|
test "e2e: hashbang at start of output" {
  let js = e2e_compile_with_hashbang("#!/usr/bin/env node\nconst x = 1;")
  assert_true(js.has_prefix("#!/usr/bin/env node"))
}

///|
test "e2e: file without hashbang works" {
  let js = e2e_compile_with_hashbang("const x = 1;")
  assert_false(js.contains("#!"))
  assert_true(js.contains("const x = 1"))
}
