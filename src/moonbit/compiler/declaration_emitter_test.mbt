// Tests for TypeScript Declaration File Emitter

///|
/// Test: Basic function declaration
test "emit function declaration" {
  let source = "function add(a: number, b: number): number { return a + b; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain declare function
      assert_true(output.contains("declare function add"))
      assert_true(output.contains("a: number, b: number"))
      assert_true(output.contains(": number;"))
      println("Function declaration output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Interface declaration
test "emit interface declaration" {
  let source = "interface Point { x: number; y: number; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain interface
      assert_true(output.contains("interface Point"))
      assert_true(output.contains("x: number"))
      assert_true(output.contains("y: number"))
      println("\nInterface declaration output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Type alias declaration
test "emit type alias" {
  let source = "type Status = \"active\" | \"inactive\" | \"pending\";"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain type alias
      assert_true(output.contains("type Status"))
      assert_true(output.contains("|"))
      println("\nType alias output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Enum declaration
test "emit enum declaration" {
  let source = "enum Color { Red, Green, Blue }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain enum
      assert_true(output.contains("enum Color"))
      assert_true(output.contains("Red"))
      assert_true(output.contains("Green"))
      assert_true(output.contains("Blue"))
      println("\nEnum declaration output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Class declaration
test "emit class declaration" {
  let source = "class Person { name: string; age: number; constructor(name: string, age: number) {} greet(): string { return ''; } }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain class declaration
      assert_true(output.contains("declare class Person"))
      assert_true(output.contains("name: "))
      assert_true(output.contains("age: "))
      assert_true(output.contains("constructor"))
      assert_true(output.contains("greet"))
      println("\nClass declaration output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Variable declaration
test "emit variable declaration" {
  let source = "const message: string = 'hello';"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain declare const
      assert_true(output.contains("declare const message"))
      assert_true(output.contains(": string"))
      println("\nVariable declaration output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Generic function
test "emit generic function" {
  let source = "function identity<T>(value: T): T { return value; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain generic function
      assert_true(output.contains("function identity"))
      assert_true(output.contains("<T>"))
      assert_true(output.contains("value: T"))
      assert_true(output.contains(": T;"))
      println("\nGeneric function output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Generic interface
test "emit generic interface" {
  let source = "interface Result<T, E> { value: T; error: E; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain generic interface
      assert_true(output.contains("interface Result"))
      assert_true(output.contains("<T, E>"))
      assert_true(output.contains("value: T"))
      assert_true(output.contains("error: E"))
      println("\nGeneric interface output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Multiple declarations
test "emit multiple declarations" {
  let source = "interface User { id: number; name: string; }\nfunction getUser(id: number): User { return null; }\ntype UserID = number;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain all declarations
      assert_true(output.contains("interface User"))
      assert_true(output.contains("declare function getUser"))
      assert_true(output.contains("type UserID"))
      println("\nMultiple declarations output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Optional parameters
test "emit optional parameters" {
  let source = "function greet(name: string, greeting?: string): string { return ''; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain optional parameter marker
      assert_true(output.contains("greeting?"))
      assert_true(output.contains("name: string"))
      println("\nOptional parameters output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Arrow function type
test "emit arrow function type" {
  let source = "type Handler = (event: string) => void;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain arrow function type
      assert_true(output.contains("type Handler"))
      assert_true(output.contains("=>"))
      assert_true(output.contains("void"))
      println("\nArrow function type output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Array types
test "emit array types" {
  let source = "function process(items: string[]): number[] { return []; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain array types
      assert_true(output.contains("string[]"))
      assert_true(output.contains("number[]"))
      println("\nArray types output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Comprehensive declaration file
test "emit comprehensive declaration file" {
  let source = "interface Config { host: string; port: number; }\nclass Server { config: Config; start(): void {} stop(): void {} }\nenum Status { Running, Stopped }\nfunction createServer(config: Config): Server { return null; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Check header
      assert_true(output.contains("// Type definitions for"))
      assert_true(
        output.contains("// Generated by MoonBit TypeScript Compiler"),
      )

      // Check all declarations are present
      assert_true(output.contains("interface Config"))
      assert_true(output.contains("declare class Server"))
      assert_true(output.contains("enum Status"))
      assert_true(output.contains("declare function createServer"))
      println("\nComprehensive declaration file output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Interface with extends clause
test "emit interface with extends" {
  let source = "interface Base { id: number; }\ninterface Extended extends Base { name: string; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain extends clause
      assert_true(output.contains("interface Extended extends Base"))
      assert_true(output.contains("name: string"))
      println("\nInterface with extends output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Const enum
test "emit const enum" {
  let source = "const enum Direction { Up, Down, Left, Right }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain const enum
      assert_true(output.contains("const enum Direction"))
      assert_true(output.contains("Up"))
      assert_true(output.contains("Down"))
      println("\nConst enum output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Enum with initializers
test "emit enum with initializers" {
  let source = "enum HttpStatus { OK = 200, NotFound = 404, ServerError = 500 }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain enum with values
      assert_true(output.contains("enum HttpStatus"))
      assert_true(
        output.contains("OK = 200") || output.contains("OK = \"200\""),
      )
      println("\nEnum with initializers output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Export default function
test "emit export default function" {
  let source = "export default function greet(name: string): string { return 'Hello ' + name; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain export default declaration
      assert_true(output.contains("export default"))
      assert_true(output.contains("function greet"))
      assert_true(output.contains("name: string"))
      assert_true(output.contains(": string"))
      println("\nExport default function output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Export default class
test "emit export default class" {
  let source = "export default class User { name: string; age: number; constructor(name: string, age: number) {} }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain export default class
      assert_true(output.contains("export default"))
      assert_true(output.contains("class User"))
      assert_true(output.contains("name: string"))
      assert_true(output.contains("age: number"))
      println("\nExport default class output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Readonly modifiers
test "emit readonly modifiers" {
  let source = "interface Config { readonly host: string; readonly port: number; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain readonly modifiers
      assert_true(output.contains("readonly host"))
      assert_true(output.contains("readonly port"))
      println("\nReadonly modifiers output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Static class members
test "emit static class members" {
  let source = "class MathUtils { static PI: number; static abs(x: number): number { return x; } }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain static members
      assert_true(output.contains("static PI"))
      assert_true(output.contains("static abs"))
      println("\nStatic class members output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Async functions
test "emit async functions" {
  let source = "async function fetchData(url: string): Promise<string> { return ''; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain async keyword (or at least the function signature)
      assert_true(output.contains("function fetchData"))
      assert_true(output.contains("url: string"))
      assert_true(output.contains("Promise"))
      println("\nAsync functions output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Tuple types
test "emit tuple types" {
  let source = "type Point = [number, number]; type NamedPoint = [x: number, y: number];"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain tuple types
      assert_true(output.contains("type Point"))
      assert_true(output.contains("["))
      assert_true(output.contains("number"))
      println("\nTuple types output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Intersection types
test "emit intersection types" {
  let source = "type Named = { name: string }; type Aged = { age: number }; type Person = Named & Aged;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain intersection types
      assert_true(output.contains("type Person"))
      assert_true(output.contains("&"))
      assert_true(output.contains("Named"))
      assert_true(output.contains("Aged"))
      println("\nIntersection types output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Index signatures
test "emit index signatures" {
  let source = "interface StringMap { [key: string]: string; } interface NumberMap { [index: number]: number; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain index signatures
      assert_true(output.contains("interface StringMap"))
      assert_true(output.contains("["))
      assert_true(output.contains("key"))
      assert_true(output.contains("string"))
      println("\nIndex signatures output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Indexed access types
test "emit indexed access types" {
  let source = "type PersonName = Person['name']; type ArrayElement = Array[number]; type TypeAtKey<T, K> = T[K];"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain indexed access type syntax
      assert_true(output.contains("Person["))
      assert_true(output.contains("Array["))
      assert_true(output.contains("T[K]"))
      println("\nIndexed access types output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Conditional types
test "emit conditional types" {
  let source = "type IsString<T> = T extends string ? string : number; type NonNullable<T> = T extends number ? string : T;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain conditional type syntax
      assert_true(output.contains(" extends "))
      assert_true(output.contains(" ? "))
      assert_true(output.contains(" : "))
      println("\nConditional types output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Mapped types
test "emit mapped types" {
  let source = "type MyMapped<K> = { [P in K]: string }; type AnotherMapped<T, K> = { [P in K]: T };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain mapped type syntax
      assert_true(output.contains("[P in "))
      assert_true(output.contains("{ [P in "))
      println("\nMapped types output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Type assertions with 'as' keyword
test "emit as expressions" {
  let source = "const value = getValue() as string; const num = getNum() as number;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Type assertions should be parsed and emitted
      assert_true(output.contains("value"))
      assert_true(output.contains("num"))
      println("\nAs expressions output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Type assertions with angle brackets
test "emit type assertion expressions" {
  let source = "const value = <string>getValue(); const num = <number>getNum();"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Type assertions should be parsed and emitted
      assert_true(output.contains("value"))
      assert_true(output.contains("num"))
      println("\nType assertion expressions output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Non-null assertions
test "emit non-null expressions" {
  let source = "const value = getValue()!; const prop = obj.property!;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Non-null assertions should be parsed and emitted
      assert_true(output.contains("value"))
      assert_true(output.contains("prop"))
      println("\nNon-null expressions output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

// ============ Optional Property Tests ============

///|
/// Test: Interface with optional properties
test "emit interface with optional properties" {
  let source = "interface User { name: string; email?: string; age?: number; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain optional property markers
      assert_true(output.contains("interface User"))
      assert_true(output.contains("name: string"))
      assert_true(output.contains("email?: string"))
      assert_true(output.contains("age?: number"))
      println("\nInterface with optional properties output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Generic interface with optional properties
test "emit generic interface with optional properties" {
  let source = "interface Result<T> { success: boolean; data?: T; error?: string; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain generic interface with optional markers
      assert_true(output.contains("interface Result<T>"))
      assert_true(output.contains("success: boolean"))
      assert_true(output.contains("data?: T"))
      assert_true(output.contains("error?: string"))
      println("\nGeneric interface with optional properties output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Interface with readonly optional property
test "emit interface with readonly optional property" {
  let source = "interface Config { readonly version?: string; name: string; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain readonly optional property
      assert_true(output.contains("interface Config"))
      assert_true(output.contains("readonly version?: string"))
      assert_true(output.contains("name: string"))
      println("\nInterface with readonly optional property output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Generic interface with multiple type parameters and optional properties
test "emit generic interface with multiple type params and optional" {
  let source = "interface Response<T, E = Error> { loading: boolean; data?: T; error?: E; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain generic interface with optional markers
      assert_true(output.contains("interface Response"))
      assert_true(output.contains("loading: boolean"))
      assert_true(output.contains("data?: T"))
      assert_true(output.contains("error?: E"))
      println("\nGeneric interface with multiple type params output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

// ============ Optional Method Tests ============

///|
/// Test: Interface with optional method
test "emit interface with optional method" {
  let source = "interface Logger { log(message: string): void; warn?(message: string): void; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain optional method marker
      assert_true(output.contains("interface Logger"))
      assert_true(output.contains("log(message: string): void"))
      assert_true(output.contains("warn?(message: string): void"))
      println("\nInterface with optional method output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Interface with multiple optional methods
test "emit interface with multiple optional methods" {
  let source = "interface EventHandler { required(): void; optional1?(): void; optional2?(x: number): string; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain both required and optional methods
      assert_true(output.contains("interface EventHandler"))
      assert_true(output.contains("required(): void"))
      assert_true(output.contains("optional1?(): void"))
      assert_true(output.contains("optional2?(x: number): string"))
      println("\nInterface with multiple optional methods output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Interface with optional properties and methods combined
test "emit interface with optional properties and methods" {
  let source = "interface Config { name: string; version?: string; init(): void; validate?(): boolean; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain both optional properties and methods
      assert_true(output.contains("interface Config"))
      assert_true(output.contains("name: string"))
      assert_true(output.contains("version?: string"))
      assert_true(output.contains("init(): void"))
      assert_true(output.contains("validate?(): boolean"))
      println("\nInterface with optional properties and methods output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

// ============================================================================
// Mapped Type Key Remapping Tests (Computed Property Names)
// ============================================================================

///|
/// Test: Mapped type with key remapping (as clause)
test "emit mapped type with key remapping" {
  let source = "type Getters<T> = { [K in keyof T as `get${string}`]: () => T[K] };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nMapped type with key remapping output:")
      println(output)

      // Should contain 'as' clause
      assert_true(output.contains(" as "))
      assert_true(output.contains("[K in keyof T as"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Mapped type with readonly modifier
test "emit mapped type with readonly" {
  let source = "type ReadonlyRecord<K, V> = { readonly [P in K]: V };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nMapped type with readonly output:")
      println(output)

      // Should contain readonly modifier
      assert_true(output.contains("readonly [P in K]"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Mapped type with optional modifier
test "emit mapped type with optional" {
  let source = "type Optional<T> = { [P in keyof T]?: T[P] };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nMapped type with optional output:")
      println(output)

      // Should contain optional modifier after ]
      assert_true(output.contains("]?:"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

// ============================================================================
// Labeled Tuple Elements Tests
// ============================================================================

///|
/// Test: Labeled tuple type
test "emit labeled tuple type" {
  let source = "type Point = [x: number, y: number];"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nLabeled tuple type output:")
      println(output)

      // Should contain labeled tuple syntax
      assert_true(output.contains("x: number"))
      assert_true(output.contains("y: number"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Labeled tuple with optional element
test "emit labeled tuple with optional" {
  let source = "type Result = [success: boolean, data?: string];"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nLabeled tuple with optional output:")
      println(output)

      // Should contain labeled tuple syntax with optional
      assert_true(output.contains("success: boolean"))
      assert_true(output.contains("data?: string"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Labeled tuple in function signature
test "emit labeled tuple in function" {
  let source = "function getPoint(): [x: number, y: number] { return [0, 0]; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nLabeled tuple in function output:")
      println(output)

      // Should contain labeled tuple as return type
      assert_true(output.contains("x: number"))
      assert_true(output.contains("y: number"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("  " + diagnostics[i].message)
      }
      assert_true(false)
    }
  }
}
