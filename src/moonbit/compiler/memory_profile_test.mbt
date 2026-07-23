// Memory profiling tests for the TypeScript compiler
// Measures memory consumption at each compilation phase

///|
/// Memory statistics for compilation phases
struct MemoryStats {
  file_name : String
  file_size : Int
  source_length : Int
  token_count : Int
  ast_node_count : Int
  statement_count : Int
  compilation_success : Bool
  estimated_memory_kb : Double
} derive(Debug)

///|
/// Count AST nodes recursively (simplified version)
fn count_ast_nodes(node : Node) -> Int {
  match node {
    // Common statements - simplified counting
    VariableStatement({ declarations, .. }) => 1 + declarations.length()
    FunctionDeclaration(_) => 5 // Rough estimate
    ClassDeclaration({ members, .. }) => 1 + members.length()
    InterfaceDeclaration({ members, .. }) => 1 + members.length()
    EnumDeclaration({ members, .. }) => 1 + members.length()
    TypeAliasDeclaration(_) => 1
    ImportDeclaration(_) => 1
    ExportDeclaration(_) => 1

    // Control flow
    IfStatement(_) => 3 // condition + then + else
    ForStatement(_) => 4 // init + cond + incr + body
    ForInStatement(_) => 3
    ForOfStatement(_) => 3
    WhileStatement(_) => 2
    DoWhileStatement(_) => 2
    SwitchStatement({ cases, .. }) => 1 + cases.length()

    // Other statements
    ReturnStatement(_) => 1
    BreakStatement(_) => 1
    ContinueStatement(_) => 1
    ThrowStatement(_) => 1
    TryStatement(_) => 3 // try + catch + finally
    BlockStatement({ statements, .. }) => 1 + statements.length()
    ExpressionStatement(_) => 1
    EmptyStatement(_) => 1
    LabeledStatement(_) => 1
    WithStatement(_) => 1

    // Expressions
    BinaryExpression(_) => 3 // left + op + right
    UnaryExpression(_) => 2
    ConditionalExpression(_) => 4
    CallExpression({ arguments, .. }) => 1 + arguments.length()
    PropertyAccessExpression(_) => 2
    ElementAccessExpression(_) => 2
    ArrayLiteralExpression({ elements, .. }) => 1 + elements.length()
    ObjectLiteralExpression({ properties, .. }) => 1 + properties.length()
    ArrowFunction({ parameters, .. }) => 1 + parameters.length()
    ParenthesizedExpression(_) => 1

    // Literals and identifiers
    Identifier(_) => 1
    NumericLiteral(_) => 1
    StringLiteral(_) => 1
    BooleanLiteral(_) => 1
    NullLiteral(_) => 1
    ThisExpression(_) => 1
    SuperExpression(_) => 1

    // Type nodes
    TypeReference(_) => 1
    UnionType({ types, .. }) => 1 + types.length()
    ArrayType(_) => 1
    KeywordType(_) => 1

    // Declarations
    Parameter(_) => 1
    PropertyDeclaration(_) => 1
    MethodDeclaration({ parameters, .. }) => 1 + parameters.length()
    ConstructorDeclaration({ parameters, .. }) => 1 + parameters.length()

    // Default for all other node types
    _ => 1
  }
}

///|
/// Estimate memory usage in KB based on data structure sizes
fn estimate_memory_kb(
  source_length : Int,
  token_count : Int,
  ast_node_count : Int,
) -> Double {
  // Rough estimates:
  // - Source string: 1 byte per character
  // - Token: ~100 bytes each (contains string slices, location info)
  // - AST Node: ~200 bytes each (larger due to nested structures)
  let source_kb = source_length.to_double() / 1024.0
  let tokens_kb = (token_count * 100).to_double() / 1024.0
  let ast_kb = (ast_node_count * 200).to_double() / 1024.0
  source_kb + tokens_kb + ast_kb
}

///|
/// Profile memory for a TypeScript file
fn profile_file(file_name : String, source : String) -> MemoryStats {
  let file_size = source.length()

  // Phase 1: Scanning
  let tokens = scan_all_v2(source, file_name)
  let token_count = tokens.length()

  // Phase 2: Parsing
  match parse_source_file(tokens, file_name) {
    Ok(source_file) => {
      // Count AST nodes
      let mut ast_node_count = 0
      for i = 0; i < source_file.statements.length(); i = i + 1 {
        ast_node_count = ast_node_count +
          count_ast_nodes(source_file.statements[i])
      }
      let estimated_memory = estimate_memory_kb(
        file_size, token_count, ast_node_count,
      )
      MemoryStats::{
        file_name,
        file_size,
        source_length: file_size,
        token_count,
        ast_node_count,
        statement_count: source_file.statements.length(),
        compilation_success: true,
        estimated_memory_kb: estimated_memory,
      }
    }
    Err(_) => {
      let estimated_memory = estimate_memory_kb(file_size, token_count, 0)
      MemoryStats::{
        file_name,
        file_size,
        source_length: file_size,
        token_count,
        ast_node_count: 0,
        statement_count: 0,
        compilation_success: false,
        estimated_memory_kb: estimated_memory,
      }
    }
  }
}

///|
/// Test: Profile small file
test "memory profile small file" {
  let source = "const x = 42;\nfunction add(a: number, b: number): number { return a + b; }"
  let stats = profile_file("small.ts", source)
  println("=== Small File Memory Profile ===")
  println("File: \{stats.file_name}")
  println("Source size: \{stats.file_size} bytes")
  println("Tokens: \{stats.token_count}")
  println("AST nodes: \{stats.ast_node_count}")
  println("Statements: \{stats.statement_count}")
  println("Estimated memory: \{stats.estimated_memory_kb} KB")
  let status = if stats.compilation_success { "Success" } else { "Failed" }
  println("Compilation: \{status}")
  assert_true(stats.compilation_success)
  assert_true(stats.token_count > 0)
  assert_true(stats.ast_node_count > 0)
}

///|
/// Test: Profile medium complexity code
test "memory profile medium complexity" {
  let source = "interface Point { x: number; y: number; }\nfunction distance(p1: Point, p2: Point): number {\n  const dx = p2.x - p1.x;\n  const dy = p2.y - p1.y;\n  return dx * dx + dy * dy;\n}\nconst p1 = { x: 0, y: 0 };\nconst p2 = { x: 3, y: 4 };\nconst dist = distance(p1, p2);"
  let stats = profile_file("medium.ts", source)
  println("\n=== Medium Complexity Memory Profile ===")
  println("File: \{stats.file_name}")
  println("Source size: \{stats.file_size} bytes")
  println("Tokens: \{stats.token_count}")
  println("AST nodes: \{stats.ast_node_count}")
  println("Statements: \{stats.statement_count}")
  println("Estimated memory: \{stats.estimated_memory_kb} KB")
  let status = if stats.compilation_success { "Success" } else { "Failed" }
  println("Compilation: \{status}")
  assert_true(stats.compilation_success)
  assert_true(stats.ast_node_count > 5)
}

///|
/// Test: Compare memory across different file sizes
test "memory profile comparison" {
  let small = "const x = 42;"
  let medium = "function fibonacci(n: number): number {\n  if (n <= 1) { return n; }\n  return fibonacci(n - 1) + fibonacci(n - 2);\n}\nconst result = fibonacci(10);"
  let large = "interface User { id: number; name: string; email: string; }\nfunction createUser(id: number, name: string, email: string): User {\n  const user = { id: id, name: name, email: email };\n  return user;\n}\nconst users: Array<User> = [];\nfunction addUser(user: User): void {\n  users.push(user);\n}\nfunction findUser(id: number): User {\n  for (let i = 0; i < users.length; i = i + 1) {\n    if (users[i].id === id) {\n      return users[i];\n    }\n  }\n  return null;\n}\nconst user1 = createUser(1, \"John\", \"john@example.com\");\naddUser(user1);"
  let stats_small = profile_file("small.ts", small)
  let stats_medium = profile_file("medium.ts", medium)
  let stats_large = profile_file("large.ts", large)
  println("\n=== Memory Profile Comparison ===")
  println("\nSmall file:")
  println("  Size: \{stats_small.file_size} bytes")
  println("  Tokens: \{stats_small.token_count}")
  println("  AST nodes: \{stats_small.ast_node_count}")
  println("  Memory: \{stats_small.estimated_memory_kb} KB")
  println("\nMedium file:")
  println("  Size: \{stats_medium.file_size} bytes")
  println("  Tokens: \{stats_medium.token_count}")
  println("  AST nodes: \{stats_medium.ast_node_count}")
  println("  Memory: \{stats_medium.estimated_memory_kb} KB")
  println("\nLarge file:")
  println("  Size: \{stats_large.file_size} bytes")
  println("  Tokens: \{stats_large.token_count}")
  println("  AST nodes: \{stats_large.ast_node_count}")
  println("  Memory: \{stats_large.estimated_memory_kb} KB")

  // Verify memory grows with file size
  assert_true(
    stats_medium.estimated_memory_kb > stats_small.estimated_memory_kb,
  )
  assert_true(
    stats_large.estimated_memory_kb > stats_medium.estimated_memory_kb,
  )
}

///|
/// Test: Parse and typecheck small.ts file
test "parse and typecheck small.ts" {
  // Source from test_memory_files/small.ts
  let source = "// Small TypeScript file (~100 lines, ~2KB)\n// Basic functions and variables\n\nconst greeting = \"Hello, World!\";\nlet count = 0;\nvar isActive = true;\n\nfunction add(a: number, b: number): number {\n  return a + b;\n}\n\nfunction subtract(a: number, b: number): number {\n  return a - b;\n}\n\nfunction multiply(a: number, b: number): number {\n  return a * b;\n}\n\nfunction divide(a: number, b: number): number {\n  if (b === 0) {\n    throw \"Division by zero\";\n  }\n  return a / b;\n}\n\nconst square = (x: number): number => x * x;\nconst cube = (x: number): number => x * x * x;\n\ninterface Point {\n  x: number;\n  y: number;\n}\n\ninterface Circle {\n  center: Point;\n  radius: number;\n}\n\nfunction distance(p1: Point, p2: Point): number {\n  const dx = p2.x - p1.x;\n  const dy = p2.y - p1.y;\n  return Math.sqrt(dx * dx + dy * dy);\n}\n\nfunction circleArea(circle: Circle): number {\n  return Math.PI * circle.radius * circle.radius;\n}\n\nclass Person {\n  name: string;\n  age: number;\n\n  constructor(name: string, age: number) {\n    this.name = name;\n    this.age = age;\n  }\n\n  greet(): string {\n    return \"Hello, I'm \" + this.name;\n  }\n\n  birthday(): void {\n    this.age = this.age + 1;\n  }\n}\n\nenum Color {\n  Red,\n  Green,\n  Blue\n}\n\ntype Status = \"active\" | \"inactive\" | \"pending\";\n\nfunction processStatus(status: Status): string {\n  switch (status) {\n    case \"active\":\n      return \"Processing active\";\n    case \"inactive\":\n      return \"Processing inactive\";\n    case \"pending\":\n      return \"Processing pending\";\n    default:\n      return \"Unknown status\";\n  }\n}\n\nfunction factorial(n: number): number {\n  if (n <= 1) {\n    return 1;\n  }\n  return n * factorial(n - 1);\n}\n\nfunction fibonacci(n: number): number {\n  if (n <= 1) {\n    return n;\n  }\n  return fibonacci(n - 1) + fibonacci(n - 2);\n}\n\nconst numbers = [1, 2, 3, 4, 5];\nconst doubled = numbers.map(x => x * 2);\nconst sum = numbers.reduce((acc, x) => acc + x, 0);"
  let file_path = "test_memory_files/small.ts"
  println("\n=== Parsing and Type Checking small.ts ===")
  println("File: \{file_path}")
  println("Source length: \{source.length()} bytes")

  // Phase 1: Scanning
  println("\n[Phase 1] Scanning...")
  let tokens = scan_all_v2(source, file_path)
  println("  Tokens generated: \{tokens.length()}")

  // Phase 2: Parsing
  println("\n[Phase 2] Parsing...")
  match parse_source_file(tokens, file_path) {
    Ok(source_file) => {
      println("  Parsing succeeded!")
      println("  Statements parsed: \{source_file.statements.length()}")

      // Count AST nodes
      let mut ast_node_count = 0
      for i = 0; i < source_file.statements.length(); i = i + 1 {
        ast_node_count = ast_node_count +
          count_ast_nodes(source_file.statements[i])
      }
      println("  AST nodes created: \{ast_node_count}")

      // Phase 3: Binding
      println("\n[Phase 3] Binding...")
      match bind_source_file(source_file) {
        Ok(bound) => {
          println("  Binding succeeded!")
          println("  Symbols created: \{bound.symbol_count}")
          println(
            "  Global scope symbols: \{bound.global_scope.symbols.length()}",
          )

          // Phase 4: Type Checking
          println("\n[Phase 4] Type Checking...")
          match check_source_file(bound) {
            Ok(typed) => {
              println("  Type checking succeeded!")
              println("  Types inferred: \{typed.types.length()}")
              if typed.diagnostics.length() > 0 {
                println("\n  Diagnostics:")
                for i = 0; i < typed.diagnostics.length(); i = i + 1 {
                  println("    - \{typed.diagnostics[i].message}")
                }
              } else {
                println("  No type errors!")
              }

              // Memory estimate
              let estimated_memory = estimate_memory_kb(
                source.length(),
                tokens.length(),
                ast_node_count,
              )
              println("\n[Summary]")
              println("  Estimated memory usage: \{estimated_memory} KB")
              println("  Compilation: SUCCESS")
              assert_true(true)
            }
            Err(diagnostics) => {
              println("  Type checking failed!")
              println("  Errors:")
              for i = 0; i < diagnostics.length(); i = i + 1 {
                println("    - \{diagnostics[i].message}")
              }
              assert_true(false)
            }
          }
        }
        Err(diagnostics) => {
          println("  Binding failed!")
          println("  Errors:")
          for i = 0; i < diagnostics.length(); i = i + 1 {
            println("    - \{diagnostics[i].message}")
          }
          assert_true(false)
        }
      }
    }
    Err(diagnostics) => {
      println("  Parsing failed!")
      println("  Errors:")
      for i = 0; i < diagnostics.length(); i = i + 1 {
        println("    - \{diagnostics[i].message}")
      }
      assert_true(false)
    }
  }
}
