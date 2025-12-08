# I Built a TypeScript Type Checker in 12 Days. Here's What I Learned.

Let's be honest. Building a compiler sounds insane.

TypeScript's official compiler is 100,000+ lines. It's been developed by a world-class team for over a decade. Who looks at that and thinks "I'll just build one myself"?

Me, apparently. And honestly? **It was one of the most fun projects I've ever done.**

---

## The Frustration That Started This

At our company, we're huge TypeScript fans. We use it everywhere—backend, frontend, tooling. It's the foundation of everything we build.

But here's the thing.

I have a Windows PC with 8GB of RAM. It's not ancient, but it's not a beast either. Our frontend codebase is around 50,000 lines of TypeScript—decent size, nothing crazy.

And yet... **the lag is brutal.**

I'd make a change, wait for the red squiggles, and... nothing. Seconds pass. Sometimes 10+ seconds before TypeScript errors appear. The IDE feels frozen. After some profiling, the culprit was obvious: `tsc` eating RAM like it's going out of style.

On an 8GB machine, that's a death sentence for productivity.

---

## Then I Saw typescript-go

When Microsoft announced [typescript-go](https://github.com/nicknisi/typescript-go)—a native port of the TypeScript compiler—I got excited. Finally! A faster `tsc`!

Then I saw the timeline: **2026+**.

Two more years of lag. Two more years of waiting for squiggles.

That's when the crazy idea hit: **What if we could accelerate this?**

Not as a replacement for Microsoft's effort. As a side project. An experiment. Could modern tooling—AI assistants, fast functional languages—let a small team (or even one person) make meaningful progress on this problem?

---

## The Hypothesis

Go is fast. But it's not a great fit for compilers. No algebraic types. No pattern matching. Lots of `interface{}` and type assertions. The codebase would be harder to maintain as it grows.

**Could we do better?**

A statically-typed functional language should give us:
- **Performance** — Competitive with (or better than) Go
- **Maintainability** — Pattern matching, algebraic types, exhaustive checks
- **Iteration speed** — Fast compiles, instant feedback

I also wanted to understand TypeScript's internals. Not by reading source code. By building it myself.

---

## The Tools That Made This Possible

Two things made 12 days realistic: the right language and the right AI assistant.

### Claude Code — The Research & Coding Partner

[Claude Code](https://claude.ai/claude-code) handled the grunt work:

- **Codebase exploration** — "How does TypeScript handle conditional types?" → instant deep dives
- **Language research** — I explored Rust, Zig, Elixir before landing on MoonBit
- **Test generation** — Given a feature, Claude wrote the unit tests
- **Test execution** — Run tests, analyze failures, suggest fixes
- **Conformance analysis** — Parse TypeScript's 5,600 test files, categorize failures

The pattern: I'd describe what I wanted. Claude would research, write code, run tests, iterate. I stayed focused on architecture decisions.

This isn't "AI wrote my code." It's **AI as a senior pair programmer** who never gets tired and has read every compiler textbook.

### MoonBit — The Language

I needed something that could:

- **Move fast** — Sub-second rebuilds, not 30-second Rust compiles
- **Handle complexity** — Algebraic types, pattern matching, strong typing
- **Perform** — Native speed, not interpreted JavaScript
- **Not fight me** — GC handles memory, no borrow checker battles

[MoonBit](https://www.moonbitlang.com/) checked every box.

Think of it as **Rust's type system with Go's simplicity**. You get:

- **Rust-like types** — Algebraic data types, pattern matching, strong inference
- **Rust-like speed** — Compiles to native code, runs close to bare metal
- **GC simplicity** — No borrow checker, no lifetime annotations, just allocate

And it targets Native, WASM, and JavaScript from the same codebase.

### Code Organization That Scales

MoonBit encourages breaking code into **semantically meaningful blocks**. Each function, each type, each module is self-contained. The compiler doesn't care about file order—it resolves dependencies automatically.

This matters for maintainability. A 35,000 line codebase could be a nightmare. Instead, it's organized into clear blocks:

```
compiler/
  scanner.mbt      # Lexical analysis
  parser.mbt       # Syntax analysis
  binder.mbt       # Symbol resolution
  checker.mbt      # Type checking
  transformer.mbt  # Type erasure
  emitter.mbt      # Code generation
```

Each file is focused. Each block is testable in isolation. When something breaks, you know exactly where to look.

For a compiler—where you're constantly allocating AST nodes and walking trees—this is the sweet spot.

---

## What's in the Box

**The numbers:**

| Metric | Value |
|--------|-------|
| Development time | 12 days |
| Total commits | 420 |
| Lines of code | 35,000 |
| Conformance tests passing | 3,451 / 5,652 (**61.1%**) |
| Categories at 100% | 24 |
| Internal tests | 1,996 / 1,996 ✓ |

**What works perfectly:**

- ✅ Arrow functions (47/47 tests)
- ✅ Template strings (178/178 tests)
- ✅ Classes (27/27 tests)
- ✅ Enums (14/14 tests)
- ✅ Destructuring, default params, rest params
- ✅ Variable declarations, shorthand properties
- ✅ 105+ TypeScript error codes

**The full pipeline:**

```
Source → Scanner → Parser → Binder → Checker → Transformer → Emitter
```

Type erasure. ES5 downleveling. Source maps. Declaration files. It's all there.

---

## The Secret Sauce: Tight Feedback Loops

Here's what made 420 commits in 12 days possible:

```
Cold compile (35K lines):  ~5 seconds
Warm compile:              <1 second
Run all 1,996 tests:       <5 seconds
```

**That's the entire game.**

### The Workflow

Every change followed the same pattern:

1. **Write the feature**
2. **Write the unit test** (every feature gets tests, no exceptions)
3. **Run unit tests** (<5 seconds)
4. **Run conformance tests** (spot regressions immediately)
5. **Fix any regressions** (before moving on)

No feature shipped without tests. No regression went unnoticed for more than a few minutes.

### Why This Matters

When your feedback loop is instant, you catch problems while the context is fresh. You're not debugging code you wrote three days ago. You're debugging code you wrote three minutes ago.

Compare that to Rust (30+ second builds) or large TypeScript projects (10+ seconds for `tsc`). That friction adds up. By the time tests finish, you've context-switched. You've forgotten the edge case you were worried about.

MoonBit's speed + a strict "test everything" discipline = **regressions die fast**.

The 1,996 unit tests aren't just validation. They're a safety net that lets you move aggressively without breaking things.

### Debugging Tip: Isolate the Failing Case

When something breaks, here's the workflow that saved me hours:

1. **Create a single test file** with just the failing case
2. **Run only that file** — instant feedback, no noise
3. **Use MoonBit's debugger** — real breakpoints, step through, inspect variables
4. **Fix it in isolation** — no distractions from 1,995 other tests
5. **Run full suite** — confirm no regressions

```bash
# Run just one test file
moon test -f checker_debug_test.mbt

# Full suite after fix
moon test
```

This sounds obvious, but it's a game-changer. Debugging a single isolated test case is 10x faster than hunting through a massive test run. MoonBit's first-class debugging (breakpoints, stack traces, variable inspection) makes isolation even more powerful.

Don't debug in the noise. Isolate, fix, verify.

---

## Pattern Matching Changes Everything

TypeScript has 100+ AST node types. Here's how you handle them in MoonBit:

```moonbit
fn infer_type(expr: Node) -> Type {
  match expr {
    Identifier(id) => lookup_symbol(id.name)
    BinaryExpression(bin) => check_binary(bin)
    CallExpression(call) => check_call(call)
    ArrowFunction(arrow) => infer_arrow(arrow)
    _ => Type::Unknown
  }
}
```

No visitor pattern. No `instanceof` chains. No boilerplate.

And here's the magic: **the compiler tells you when you miss a case.** Forget to handle `YieldExpression`? Compile error. Miss `TaggedTemplateExpression`? Compile error.

You can't ship bugs you forgot to write code for.

---

## The Type System

Here's the actual representation:

```moonbit
pub enum Type {
  // Primitives
  Number | String | Boolean | Null | Undefined
  Any | Unknown | Never | Void

  // Compound
  Object(ObjectType)
  Function(FunctionType)
  Union(Array[Type])
  Array(Type)
  Tuple(Array[Type])

  // Literals
  StringLiteral(String)
  NumberLiteral(Double)

  // Advanced
  Conditional(ConditionalType)  // T extends U ? X : Y
  Mapped(MappedType)            // { [K in keyof T]: T[K] }
  IndexAccess(IndexAccessType)  // T[K]

  Error  // Graceful recovery
}
```

Each variant carries exactly what it needs. No nulls. No runtime checks. Just data.

---

## Multi-Target Compilation

Same codebase. Three outputs.

```bash
moon build --target native  # Fast CLI binary
moon build --target wasm    # Browser, edge functions
moon build --target js      # Node.js integration
```

Want a TypeScript type checker in your browser-based IDE? Compile to WASM. Need maximum CLI speed? Compile to native. Integrating with existing Node tooling? Compile to JS.

No rewrites. No ports. Same code.

---

## The Catch

We're not pretending this is complete.

**What's missing:**

| Category | Pass Rate | Why |
|----------|-----------|-----|
| Spread operators | 44% | Complex rest/spread patterns |
| Computed properties | 42% | Dynamic property keys |
| Generators | 61% | Yield expressions |
| Local types | 20% | Types defined inside functions |

These are real gaps. But they're also edge cases. The core TypeScript experience—the stuff you use every day—works.

---

## Why I Built This

Not to replace `tsc`. That would be absurd.

I built this to **understand**. How does type inference work? How do generics resolve? What makes TypeScript's error messages so good (and sometimes so confusing)?

Building it taught me more than reading ever could.

And along the way, I discovered something unexpected: **MoonBit made compiler development fun.**

Fast iteration. Expressive types. No memory headaches. First-class debugging with real breakpoints and stack traces.

If you've ever been curious about compilers but thought they were too hard—they're not. The right tools make hard things achievable.

---

## Try It

```bash
./moonbit-tsc src/index.ts
./moonbit-tsc --target es5 --sourceMap --declaration src/*.ts
./moonbit-tsc --watch --outDir dist src/
```

Standard TypeScript diagnostics:

```
src/app.ts(5,10): error TS2322: Type 'string' is not assignable to type 'number'.
src/app.ts(12,5): error TS2339: Property 'foo' does not exist on type 'Bar'.
```

Works with existing tooling.

---

## What's Next

- **Higher conformance** — Targeting 80%, focusing on spread/rest operators
- **Language server** — IDE integration via LSP
- **Better diagnostics** — Elm/Rust-style helpful error messages

---

## The Bottom Line

12 days. 35,000 lines. 61% conformance.

Not because I'm fast. Because **the right tools removed the friction.**

**Claude Code** handled:
- Research and exploration
- Writing unit tests
- Running and analyzing test failures
- Iterating on fixes

**MoonBit** provided:
- Sub-second rebuilds that kept me in flow
- Rust-like types without the borrow checker
- Rust-like speed with GC simplicity
- One codebase → Native, WASM, or JS

The combination is powerful. AI handles the breadth—exploring possibilities, generating tests, analyzing failures. A fast, expressive language handles the depth—letting you iterate at the speed of thought.

If you're considering a systems project, this stack is worth trying.

---

*The code is open source. Questions, bugs, PRs welcome.*

**Resources:**
- [Claude Code](https://claude.ai/claude-code) — AI coding assistant
- [MoonBit](https://www.moonbitlang.com/) — The language
- [TypeScript Tests](https://github.com/microsoft/TypeScript/tree/main/tests) — The conformance suite
- [Crafting Interpreters](https://craftinginterpreters.com/) — Great compiler resource
