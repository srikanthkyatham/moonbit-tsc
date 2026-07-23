// Global Augmentation Checker Tests
// Tests for type checking with `declare global { }` blocks

///|
/// Helper to parse, bind, and check source code
fn check_source_with_global_aug(
  source : String,
) -> Result[@compiler.TypedFile, Array[@compiler.Diagnostic]] {
  let tokens = @compiler.scan_all_v2(source, "test.ts")
  match @compiler.parse_source_file(tokens, "test.ts") {
    Ok(source_file) =>
      match @compiler.bind_source_file(source_file) {
        Ok(bound) => @compiler.check_source_file(bound)
        Err(diags) => Err(diags)
      }
    Err(_) => Err([])
  }
}

///|
test "global augmentation SymbolConstructor property access" {
  // Can access custom symbol properties after global augmentation
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
    #|const observable = Symbol.obs
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true) // Should succeed
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation SymbolConstructor typeof" {
  // Can use typeof with augmented symbol property
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
    #|const observable: typeof Symbol.obs = Symbol.obs
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation SymbolConstructor in computed property" {
  // Can use augmented symbol in computed property names
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
    #|const obj = { [Symbol.obs]: 42 }
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation SymbolConstructor with export" {
  // Global augmentation works in module files (with export)
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
    #|export const observable = Symbol.obs
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation custom interface" {
  // Can augment custom interfaces
  let source =
    #|declare global {
    #|  interface MyGlobal {
    #|    myApp: string;
    #|  }
    #|}
    #|const x: MyGlobal = { myApp: "test" }
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation variable declaration" {
  // Can declare global variables
  let source =
    #|declare global {
    #|  var myGlobal: number;
    #|}
    #|const x: number = myGlobal
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation type alias" {
  // Can declare global type aliases
  let source =
    #|declare global {
    #|  type GlobalString = string;
    #|}
    #|const x: GlobalString = "hello"
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation namespace" {
  // Can declare global namespaces
  let source =
    #|declare global {
    #|  namespace MyNamespace {
    #|    interface Config {
    #|      setting: boolean;
    #|    }
    #|  }
    #|}
    #|const cfg: MyNamespace.Config = { setting: true }
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "multiple global augmentations same interface" {
  // Multiple global augmentations can extend the same interface
  let source =
    #|declare global {
    #|  interface Foo {
    #|    prop1: string;
    #|  }
    #|}
    #|declare global {
    #|  interface Foo {
    #|    prop2: number;
    #|  }
    #|}
    #|const f: Foo = { prop1: "a", prop2: 1 }
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation union type alias" {
  // Can declare global type aliases with unions
  let source =
    #|declare global {
    #|  type MyType = string | number;
    #|}
    #|const x: MyType = "hello"
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("Unexpected errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}

///|
test "global augmentation error - non-existent property" {
  // Should still error for non-existent properties
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
    #|const bad = Symbol.nonExistent
  match check_source_with_global_aug(source) {
    Ok(_) => {
      println("Should have failed")
      assert_true(false)
    }
    Err(diags) => {
      // Should have TS2339 error
      assert_true(diags.length() > 0)
      assert_eq(diags[0].code, 2339)
    }
  }
}

///|
test "symbolProperty61.ts conformance" {
  // Full test case from symbolProperty61.ts
  let source =
    #|declare global {
    #|  interface SymbolConstructor {
    #|    readonly obs: symbol
    #|  }
    #|}
    #|
    #|const observable: typeof Symbol.obs = Symbol.obs
    #|
    #|export class MyObservable<T> {
    #|    constructor(private _val: T) {}
    #|
    #|    subscribe(next: (val: T) => void) {
    #|        next(this._val)
    #|    }
    #|
    #|    [observable]() {
    #|        return this
    #|    }
    #|}
    #|
    #|type InteropObservable<T> = {
    #|    [Symbol.obs]: () => { subscribe(next: (val: T) => void): void }
    #|}
    #|
    #|function from<T>(obs: InteropObservable<T>) {
    #|    return obs[Symbol.obs]()
    #|}
    #|
    #|from(new MyObservable(42))
  match check_source_with_global_aug(source) {
    Ok(_) => assert_true(true)
    Err(diags) => {
      println("symbolProperty61 errors: \{@debug.to_string(diags)}")
      assert_true(false)
    }
  }
}
