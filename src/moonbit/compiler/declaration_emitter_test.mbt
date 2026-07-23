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

///|
/// Test: Index signature in type alias
test "emit type alias with index signature" {
  let source = "type StringMap = { [key: string]: string };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nIndex signature type alias output:")
      println(output)

      // Should contain the index signature
      assert_true(output.contains("type StringMap"))
      assert_true(output.contains("[key: string]: string"))
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
/// Test: Index signature with number key
test "emit type alias with number index signature" {
  let source = "type NumberArray = { [index: number]: string };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nNumber index signature type alias output:")
      println(output)

      // Should contain the index signature with number key
      assert_true(output.contains("type NumberArray"))
      assert_true(output.contains("[index: number]: string"))
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
/// Test: Type literal with properties and index signature
test "emit type literal with properties and index signature" {
  let source = "type Config = { name: string; [key: string]: string | number };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nType literal with properties and index signature output:")
      println(output)

      // Should contain both property and index signature
      assert_true(output.contains("type Config"))
      assert_true(output.contains("name: string"))
      assert_true(output.contains("[key: string]:"))
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
/// Test: Recursive type with index signature (JSON-like)
test "emit recursive type with index signature" {
  let source = "type JsonObject = { [key: string]: string | number | JsonObject };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nRecursive type with index signature output:")
      println(output)

      // Should contain the recursive type with index signature
      assert_true(output.contains("type JsonObject"))
      assert_true(output.contains("[key: string]:"))
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
/// Test: Readonly index signature
test "emit readonly index signature" {
  let source = "type ReadonlyMap = { readonly [key: string]: number };"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nReadonly index signature output:")
      println(output)

      // Should contain readonly index signature
      assert_true(output.contains("type ReadonlyMap"))
      assert_true(output.contains("readonly [key: string]: number"))
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
// Declaration Merging Tests
// ============================================================================

///|
/// Test: Declaration merging - multiple interfaces with same name
test "emit declaration merging - interfaces" {
  let source = "interface User { name: string; } interface User { age: number; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nDeclaration merging - interfaces output:")
      println(output)

      // Should merge both interface declarations
      assert_true(output.contains("interface User"))
      assert_true(output.contains("name: string"))
      assert_true(output.contains("age: number"))
      // Should only have one interface User declaration
      let count = count_occurrences(output, "interface User")
      assert_true(count == 1)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Declaration merging - three interfaces with same name
test "emit declaration merging - three interfaces" {
  let source = "interface Config { host: string; } interface Config { port: number; } interface Config { ssl: boolean; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nDeclaration merging - three interfaces output:")
      println(output)

      // Should merge all three interface declarations
      assert_true(output.contains("interface Config"))
      assert_true(output.contains("host: string"))
      assert_true(output.contains("port: number"))
      assert_true(output.contains("ssl: boolean"))
      // Should only have one interface Config declaration
      let count = count_occurrences(output, "interface Config")
      assert_true(count == 1)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

// ============================================================================
// Private Member Stripping Tests
// ============================================================================

///|
/// Test: Private member stripping - class with private property
test "emit private member stripping - property" {
  let source = "class User { private secret: string; public name: string; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nPrivate member stripping - property output:")
      println(output)

      // Should strip private property
      assert_false(output.contains("secret"))
      // Should keep public property
      assert_true(output.contains("name"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Private member stripping - class with private method
test "emit private member stripping - method" {
  let source = "class Api { private doAuth(): void {} public fetch(): void {} }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)
      println("\nPrivate member stripping - method output:")
      println(output)

      // Should strip private method
      assert_false(output.contains("doAuth"))
      // Should keep public method
      assert_true(output.contains("fetch"))
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

// ============================================================================
// TypeV2 to TypeScript String Conversion Tests (via factory functions)
// ============================================================================

///|
/// Test: TypeV2 to string - using factory functions
test "type_v2_to_ts_string via factories" {
  // Test primitives via factory functions
  assert_eq(type_v2_to_ts_string(create_string_type()), "string")
  assert_eq(type_v2_to_ts_string(create_number_type()), "number")
  assert_eq(type_v2_to_ts_string(create_boolean_type()), "boolean")
  assert_eq(type_v2_to_ts_string(create_any_type()), "any")
  assert_eq(type_v2_to_ts_string(create_void_type()), "void")
  assert_eq(type_v2_to_ts_string(create_null_type()), "null")
  assert_eq(type_v2_to_ts_string(create_undefined_type()), "undefined")
  println("TypeV2 to string via factories passed")
}

///|
/// Test: TypeV2 to string - literal types
test "type_v2_to_ts_string literals via factories" {
  assert_eq(
    type_v2_to_ts_string(create_literal_string_type("hello")),
    "\"hello\"",
  )
  assert_eq(type_v2_to_ts_string(create_literal_number_type(42.0)), "42")
  assert_eq(type_v2_to_ts_string(create_literal_bool_type(true)), "true")
  assert_eq(type_v2_to_ts_string(create_literal_bool_type(false)), "false")
  println("TypeV2 literals to string passed")
}

///|
/// Test: TypeV2 to string - union types
test "type_v2_to_ts_string union via factories" {
  let union = create_union_type([create_string_type(), create_number_type()])
  assert_eq(type_v2_to_ts_string(union), "string | number")
  println("TypeV2 union to string passed")
}

///|
/// Test: TypeV2 to string - array types
test "type_v2_to_ts_string array via factories" {
  let arr = create_array_type(create_string_type())
  assert_eq(type_v2_to_ts_string(arr), "string[]")
  println("TypeV2 array to string passed")
}

///|
/// Test: TypeV2 to string - generic instance
test "type_v2_to_ts_string generic via factories" {
  let generic = create_generic_instance("Promise", [create_string_type()])
  assert_eq(type_v2_to_ts_string(generic), "Promise<string>")
  let map_type = create_generic_instance("Map", [
    create_string_type(),
    create_number_type(),
  ])
  assert_eq(type_v2_to_ts_string(map_type), "Map<string, number>")
  println("TypeV2 generic to string passed")
}

///|
/// Test: TypeV2 to string - type parameter
test "type_v2_to_ts_string type_param via factories" {
  let type_param = create_type_param("T", None)
  assert_eq(type_v2_to_ts_string(type_param), "T")
  println("TypeV2 type param to string passed")
}

// Helper function to count occurrences of a substring

///|
fn count_occurrences(haystack : String, needle : String) -> Int {
  let mut count = 0
  let mut pos = 0
  let haystack_len = haystack.length()
  let needle_len = needle.length()
  while pos <= haystack_len - needle_len {
    let found = check_substring_at(haystack, needle, pos)
    if found {
      count = count + 1
      pos = pos + needle_len
    } else {
      pos = pos + 1
    }
  }
  count
}

// Helper to check if a substring exists at a position

///|
fn check_substring_at(haystack : String, needle : String, pos : Int) -> Bool {
  let needle_len = needle.length()
  let sub = @utils.substr(haystack, start=pos, end=pos + needle_len)
  sub == needle
}

///|
/// Test: Interface with call signature (generic)
test "emit interface with call signature" {
  let source = "interface Callable { <T>(x: T): T; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain interface with call signature
      assert_true(output.contains("interface Callable"))
      assert_true(output.contains("<T>"))
      assert_true(output.contains("(x: T)"))
      assert_true(output.contains(": T"))
      // Should NOT have a method name before <T>
      assert_true(!(output.contains("?<T>")))
      println("\nInterface with call signature output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Type alias with qualified type name
test "emit type alias with qualified name" {
  let source = "type Widget = Sample.Thing.IWidget;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain type alias with qualified name preserved
      assert_true(output.contains("type Widget"))
      assert_true(output.contains("Sample.Thing.IWidget"))
      println("\nType alias with qualified name output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Function type with qualified parameter type
test "emit function type with qualified parameter type" {
  let source = "type Handler = (widget: Foo.Bar.Widget) => void;"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain function type with qualified parameter type
      assert_true(output.contains("type Handler"))
      assert_true(output.contains("Foo.Bar.Widget"))
      assert_true(output.contains("=> void"))
      println("\nFunction type with qualified parameter type output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}

///|
/// Test: Interface with multiple call signatures
test "emit interface with multiple call signatures" {
  let source = "interface Overloaded { (x: number): number; (x: string): string; }"
  let tokens = scan_all_v2(source, "test.ts")
  match parse_source_file(tokens, "test.ts") {
    Ok(source_file) => {
      let ctx = DeclarationEmitterContext::default()
      let output = emit_declaration_file(source_file, ctx)

      // Should contain interface with both call signatures
      assert_true(output.contains("interface Overloaded"))
      assert_true(output.contains("(x: number): number"))
      assert_true(output.contains("(x: string): string"))
      println("\nInterface with multiple call signatures output:")
      println(output)
    }
    Err(diagnostics) => {
      println("Parse error:")
      for d in diagnostics {
        println("  " + d.message)
      }
      assert_true(false)
    }
  }
}
