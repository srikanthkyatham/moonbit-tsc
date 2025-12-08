# I built a TypeScript type checker from scratch in 12 days (61% conformance, 35K lines)

*How MoonBit's functional paradigm enabled rapid compiler development*

---

## TL;DR

- Built a TypeScript compiler in **MoonBit** (a new functional language)
- **12 days** of development, **420 commits**, averaging **35 commits/day**
- **35,000 lines** of code (21,800 compiler + 14,000 tests)
- **61.1% conformance** against TypeScript's official test suite (3,451/5,652 tests)
- **24 test categories at 100%** including arrow functions, template strings, classes, enums
- **1,996 internal unit tests**, all passing
- **Build time**: 5 seconds cold, <1 second warm. All tests run in <5 seconds.

---

## Why Build Another TypeScript Compiler?

TypeScript's official compiler (`tsc`) is a marvel of engineering—but it's also 100,000+ lines of TypeScript compiling itself. I wanted to understand: *what would it take to build a TypeScript type checker from scratch?*

More specifically, I was curious about:

1. **How complex is TypeScript's type system really?** (Spoiler: very)
2. **Can a functional language make compiler development faster?**
3. **What's the minimum viable implementation for real-world TypeScript?**

I chose [MoonBit](https://www.moonbitlang.com/)—a new functional language with algebraic data types, pattern matching, and a focus on performance. It felt like the right tool for tree-walking a complex AST.

### Why MoonBit?

MoonBit occupies a unique spot in the language landscape:

| Feature | MoonBit | Rust | Go | TypeScript |
|---------|---------|------|-----|------------|
| **Memory Management** | GC (no manual work) | Ownership/borrowing | GC | GC |
| **Performance** | Near-Rust speed | Fastest | Fast | Slow (interpreted) |
| **Type System** | Strong, algebraic | Strong, algebraic | Weak | Strong |
| **Pattern Matching** | First-class | First-class | None | None |
| **Compile Speed** | Very fast | Slow | Fast | Fast |
| **Compile Targets** | Native, WASM, JS | Native, WASM | Native | JS |
| **Debugging** | First-class | Good | Good | Good |

MoonBit gives you **Rust-level performance without the borrow checker complexity**. The GC handles memory, but the generated native code is close to bare metal. For a compiler—where you're constantly allocating AST nodes and walking trees—this is ideal.

**Multi-target compilation** is a killer feature. The same codebase compiles to:
- **Native** - Fast CLI tools, maximum performance
- **WebAssembly** - Run in browsers, edge functions, sandboxed environments
- **JavaScript** - Node.js integration, existing JS toolchains

I built this compiler targeting native for speed, but the same code could run in a browser via WASM—no rewrite needed.

**First-class debugging** means you get proper stack traces, breakpoints, and variable inspection. No "println debugging" as your only option.

**Development velocity proof:**
```
Cold compile (35K lines):  ~5 seconds
Warm compile:              <1 second
Full test suite (1,996):   <5 seconds
```

This tight feedback loop enabled 35 commits/day. Change code, run tests, see results—all under 5 seconds.

---

## The Architecture

Every compiler follows roughly the same pipeline. Here's how mine breaks down:

```
Source Code
    ↓
┌─────────────────────────────────────────────────────────┐
│  Scanner (1,284 lines)                                  │
│  Converts source text → token stream                    │
│  Handles: keywords, operators, string/template literals │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Parser (5,007 lines)                                   │
│  Converts tokens → Abstract Syntax Tree                 │
│  100+ node types, recursive descent with lookahead      │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Binder (2,284 lines)                                   │
│  Builds symbol tables, resolves names                   │
│  Control flow graph for unreachable code detection      │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Type Checker (5,465 lines)                             │
│  Type inference, type checking, 105+ error codes        │
│  Generics, overloads, mapped types, conditional types   │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Transformer (1,348 lines)                              │
│  Type erasure, ES5/ES2015+ downleveling                 │
│  Enum → object, JSX → React.createElement               │
└─────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────┐
│  Emitter (1,849 lines)                                  │
│  AST → JavaScript source code                           │
│  Source map v3 support, .d.ts generation                │
└─────────────────────────────────────────────────────────┘
    ↓
JavaScript Output + Source Maps + Declaration Files
```

The type checker is the heart of the system—it's where TypeScript's complexity lives.

---

## Why MoonBit Was the Right Choice

### 0. Blazing Fast Development Cycle

Before diving into language features, let's talk about what really matters for rapid development: **iteration speed**.

```
$ time moon build --target native
real    0m4.8s   # Cold build - 35K lines compiled

$ time moon build --target native
real    0m0.7s   # Warm build - incremental

$ time moon test --target native
real    0m4.2s   # 1,996 tests executed
```

Compare this to Rust, where a project this size might take 30+ seconds to compile. That difference compounds: at 35 commits/day, I saved hours of waiting.

MoonBit achieves this through:
- **No borrow checker analysis** - GC handles memory, no lifetime inference needed
- **Simple compilation model** - Native code generation without LLVM's overhead
- **Incremental by default** - Only recompile what changed

The result? A development experience closer to scripting languages, with compiled language performance.

### 1. Algebraic Data Types for AST Representation

TypeScript has 100+ syntax node types. In MoonBit, I represent them as a discriminated union:

```moonbit
pub enum Node {
  // Statements
  VariableStatement(VariableStatement)
  FunctionDeclaration(FunctionDeclaration)
  ClassDeclaration(ClassDeclaration)
  IfStatement(IfStatement)
  ForStatement(ForStatement)

  // Expressions
  BinaryExpression(BinaryExpression)
  CallExpression(CallExpression)
  ArrowFunction(ArrowFunction)
  PropertyAccessExpression(PropertyAccessExpression)

  // Types
  UnionType(UnionType)
  IntersectionType(IntersectionType)
  MappedType(MappedType)
  ConditionalType(ConditionalType)

  // ... 100+ more variants
}
```

This makes it impossible to forget a case—the compiler tells me when I haven't handled a node type.

### 2. Pattern Matching for Tree Traversal

Walking the AST becomes elegant:

```moonbit
fn infer_expression_type(expr: Node) -> Type {
  match expr {
    Identifier(id) => lookup_symbol(id.name)

    BinaryExpression(bin) => {
      let left = infer_expression_type(bin.left)
      let right = infer_expression_type(bin.right)
      check_binary_operator(bin.operator, left, right)
    }

    CallExpression(call) => {
      let callee_type = infer_expression_type(call.expression)
      check_call_arguments(callee_type, call.arguments)
    }

    ArrowFunction(arrow) => {
      infer_arrow_function_type(arrow)
    }

    _ => Type::Unknown
  }
}
```

No visitor pattern boilerplate. No `instanceof` chains. Just pattern matching.

### 3. The Type System Itself

TypeScript's type system maps naturally to MoonBit's enums:

```moonbit
pub enum Type {
  // Primitives
  Number(TypeInfo)
  String(TypeInfo)
  Boolean(TypeInfo)
  Void(TypeInfo)
  Null(TypeInfo)
  Undefined(TypeInfo)
  Any(TypeInfo)
  Unknown(TypeInfo)
  Never(TypeInfo)

  // Compound types
  Object(ObjectType)
  Function(FunctionType)
  Union(UnionType)
  Array(ArrayType)
  Tuple(TupleType)

  // Literal types
  StringLiteral(String, TypeInfo)
  NumberLiteral(Double, TypeInfo)
  BooleanLiteral(Bool, TypeInfo)

  // Advanced types
  Intersection(IntersectionType)
  Conditional(ConditionalType)    // T extends U ? X : Y
  Mapped(MappedType)              // { [K in keyof T]: T[K] }
  IndexAccess(IndexAccessType)    // T[K]
  TemplateLiteral(TemplateLiteralType)

  Error(TypeInfo)  // For graceful error recovery
}
```

Each variant carries exactly the data it needs. No null checks, no runtime type guards.

---

## The 12-Day Sprint

Here's how the development unfolded:

### Days 1-2: Foundation (48 commits)
- Scanner: tokenizing TypeScript source
- Parser: basic statements and expressions
- First passing tests

### Days 3-4: Symbol Resolution (90+ commits)
- Binder: symbol tables and scopes
- Name resolution across files
- Control flow graph infrastructure

### Days 5-8: The Type System (150+ commits)
- Type inference for expressions
- Generic types and type parameters
- Function overload resolution
- Module resolution (ESM and CommonJS)
- Class hierarchy checking

### Days 9-10: Error Codes (100+ commits)
- **Peak day: 77 commits on December 1st**
- Implemented 105+ TypeScript diagnostic codes
- TS2322: Type not assignable
- TS2339: Property does not exist
- TS2345: Argument not assignable
- ... and many more

### Days 11-12: Polish and Conformance (50+ commits)
- Multi-file test support
- Edge cases: globalThis, strict mode, hoisting
- Declaration file (.d.ts) generation

```
Commits per day:
Nov 23: ██████ 6
Nov 24: ██████████████████████████████████████████ 42
Nov 25: ███████████████████████████████████████████████████████████████████ 67 ← Peak
Nov 26: ████████████████████████████████ 32
Nov 27: ███████████████████████ 23
Nov 28: ██████████████████████ 22
Nov 29: █████████████████████████████████████████████ 45
Nov 30: ████████████████████████████████ 32
Dec 01: █████████████████████████████████████████████████████████████████████████████ 77 ← Error codes explosion
Dec 02: ██████████████████████████ 26
Dec 03: ██████████████████ 18
Dec 04: █████████████████████ 21
Dec 05: █████████ 9 (ongoing)
```

---

## Conformance: The Real Test

TypeScript's repository includes ~5,600 conformance tests. These test everything from basic syntax to obscure edge cases.

### Overall Results

| Metric | Value |
|--------|-------|
| **Total Tests** | 5,652 |
| **Passing** | 3,451 |
| **Pass Rate** | **61.1%** |

### Categories at 100%

These categories have perfect conformance:

| Category | Tests | What It Covers |
|----------|-------|----------------|
| Arrow Functions | 47/47 | `() => {}`, `this` binding, rest params |
| Template Strings | 178/178 | `` `hello ${name}` ``, tagged templates |
| Class Declarations | 27/27 | Inheritance, super calls, static members |
| Enums | 14/14 | Numeric, string, const enums |
| Unicode Escapes | 64/64 | `\u{1F600}` extended escapes |
| Variable Declarations | 13/13 | let, const, var scoping |
| Default Parameters | 8/8 | `function f(x = 10) {}` |
| Rest Parameters | 9/9 | `function f(...args) {}` |
| Shorthand Properties | 13/13 | `{ x, y }` object syntax |
| Export Declarations | 21/22 | Named, default, re-exports |

### The Journey to 100% Arrow Functions

Arrow functions were surprisingly tricky. Here's what it took:

1. **Basic parsing** - `(x) => x * 2`
2. **Lexical `this`** - Arrow functions don't have their own `this`
3. **globalThis typing** - At global scope, `this` is `typeof globalThis`
4. **TS2339 for restricted properties** - `this.name` errors in global arrow functions
5. **Function hoisting** - Forward references to nested functions
6. **TS1200** - Line terminator before arrow detection
7. **TS1210** - Strict mode reserved identifiers (`arguments`, `eval`)

Each fix came from a failing conformance test. The test suite is brutally thorough.

---

## Lessons Learned

### 1. TypeScript's Complexity is in the Details

The core type system isn't that hard. What's hard:
- **105+ specific error codes** with precise error messages
- **Edge cases**: `typeof globalThis`, `arguments` object, strict mode
- **Contextual typing**: The type of `x` in `arr.map(x => x + 1)` depends on `arr`

### 2. Functional Languages Excel at Compilers

Pattern matching eliminated entire classes of bugs:
- Exhaustiveness checking caught missing cases
- Discriminated unions made illegal states unrepresentable
- Immutability simplified reasoning about state

### 3. Iteration Speed is Everything

With 35 commits/day, I ran the build/test cycle hundreds of times. MoonBit's speed made this painless:

| Action | Time |
|--------|------|
| Save file → see type errors | <1 second |
| Run single test | <1 second |
| Run all 1,996 tests | <5 seconds |
| Full rebuild | ~5 seconds |

Compare this to a Rust project of similar size (30+ second builds) or a large TypeScript project (10+ seconds for tsc). The fast feedback loop directly enabled the commit velocity.

### 4. Tests Are Your Roadmap

The TypeScript conformance suite is a gift. Each failing test is a specification:
- What input should produce what output?
- What errors should be reported?
- What edge cases exist?

I spent more time reading failing tests than reading TypeScript's source code.

### 5. 80/20 Rule Applies

61% conformance covers the vast majority of real-world TypeScript:
- All basic types work
- Classes, interfaces, and generics work
- Most error messages are correct

The remaining 39% is edge cases: complex mapped types, advanced inference, obscure syntax.

---

## What's Missing (The 39%)

Areas with lower conformance:

| Category | Pass Rate | Gap |
|----------|-----------|-----|
| Spread operators | 44% | Complex rest/spread patterns |
| Computed properties | 42% | Dynamic property keys |
| Symbols | 57% | Symbol-based properties |
| Local types | 20% | Types defined inside functions |
| Yield expressions | 61% | Generator functions |

These are genuine gaps, not blockers for most code.

---

## Code Metrics

| Component | Lines | Tests | Purpose |
|-----------|-------|-------|---------|
| Scanner | 1,284 | 22 | Lexical analysis |
| Parser | 5,007 | 127 | Syntax analysis |
| Binder | 2,284 | 139 | Symbol resolution |
| Checker | 5,465 | 450 | Type checking |
| Transformer | 1,348 | 24 | Type erasure |
| Emitter | 1,849 | 57 | Code generation |
| Source Maps | 420 | 59 | Debug support |
| Declaration Emitter | 1,091 | 21 | .d.ts generation |
| CLI & Coordinator | 1,000 | 46 | Parallel compilation |
| **Total** | **~21,800** | **1,996** | |

Plus ~14,000 lines of test code. Total: **~35,000 lines**.

For comparison, TypeScript's `tsc` is 100,000+ lines—but it also handles project configuration, language service, and much more.

---

## Try It Yourself

The compiler runs as a native binary—no runtime, no VM, just machine code:

```bash
# Compile a TypeScript file
./moonbit-tsc src/index.ts

# With options
./moonbit-tsc --target es5 --sourceMap --declaration src/*.ts

# Watch mode
./moonbit-tsc --watch --outDir dist src/

# Parallel compilation (4 workers)
./moonbit-tsc --parallel 4 --outDir dist src/
```

### Build for Any Target

Thanks to MoonBit's multi-target compilation, you can build this compiler for different environments:

```bash
# Native binary (fastest)
moon build --target native

# WebAssembly (run in browser/edge)
moon build --target wasm

# JavaScript (Node.js compatible)
moon build --target js
```

Same codebase, three deployment options. Want a TypeScript type checker in your browser-based IDE? Compile to WASM. Need a fast CLI tool? Compile to native. Integrating with an existing Node.js toolchain? Compile to JS.

### Runtime Performance

Because MoonBit compiles to native code, the resulting binary is fast:

**Compilation speed (20 TypeScript files):**

| Workers | Time | Speedup |
|---------|------|---------|
| 1 | 34ms | baseline |
| 2 | 12ms | 2.8x |
| 4 | 13ms | 2.6x |

**Memory efficiency:**

| File Size | Memory Used | Ratio |
|-----------|-------------|-------|
| 2 KB | ~1 KB | 0.5x source |
| 8.6 KB | ~11 KB | 1.3x source |
| 91 KB | ~16 KB | 0.18x source |

Memory scales linearly at roughly ~30x source size—efficient for a compiler that builds full ASTs and type information.

### The MoonBit Advantage: GC + Native Speed

Here's the key insight: MoonBit gives you garbage collection (no manual memory management) while generating native code that runs at near-Rust speeds.

For compiler development, this is the sweet spot:
- **You allocate freely** - AST nodes, type objects, symbol tables—no ownership headaches
- **GC cleans up** - No use-after-free, no memory leaks, no borrow checker fights
- **Native speed** - The compiled binary is fast, not interpreted

It's the productivity of Go/TypeScript with performance closer to Rust/C++.

---

## What's Next

1. **Higher conformance** - Targeting 80% with focus on spread/rest operators
2. **Language server** - IDE integration via LSP
3. **Performance optimization** - Incremental compilation is already implemented
4. **Error message quality** - Elm/Rust-style helpful diagnostics

---

## Conclusion

Building a TypeScript compiler in 12 days sounds impossible—until you realize:

1. **The right language matters.** MoonBit's pattern matching and algebraic types made complex tree operations trivial. No visitor pattern boilerplate, no instanceof chains.

2. **Speed enables velocity.** Sub-second rebuilds and 5-second test runs meant I could iterate hundreds of times per day. MoonBit gave me scripting-language ergonomics with native-code performance.

3. **GC + Native is underrated.** You don't always need Rust's zero-cost abstractions. For compilers—which allocate constantly—MoonBit's GC eliminated memory bugs while still generating fast native binaries.

4. **Tests are documentation.** TypeScript's conformance suite told me exactly what to build.

5. **80/20 applies.** 61% conformance handles most real TypeScript code.

If you're considering a systems project but dreading Rust's learning curve, or finding Go's type system too limiting, give MoonBit a look. It occupies a genuinely useful middle ground: **the productivity of garbage-collected languages with performance approaching systems languages.**

The code is open source. If you've ever been curious about how type checkers work, I hope this helps demystify it.

---

*Have questions? Found a bug? The project is at [GitHub link]. PRs welcome.*

---

## Resources

- [MoonBit Language](https://www.moonbitlang.com/) - The language used to build this
- [TypeScript Compiler Source](https://github.com/microsoft/TypeScript) - The reference implementation
- [Crafting Interpreters](https://craftinginterpreters.com/) - Excellent book on compiler basics

---

## Appendix: Sample Error Messages

The compiler produces TypeScript-compatible diagnostics:

```
src/example.ts(5,10): error TS2322: Type 'string' is not assignable to type 'number'.

src/example.ts(12,5): error TS2339: Property 'foo' does not exist on type 'Bar'.

src/example.ts(20,1): error TS2345: Argument of type 'string' is not assignable to parameter of type 'number'.
```

Each error includes file, line, column, error code, and message—compatible with existing TypeScript tooling.
