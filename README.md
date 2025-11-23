# MoonBit-Zig TypeScript Compiler

A high-performance TypeScript compiler implementation leveraging MoonBit's async capabilities for I/O concurrency and Zig's multi-threading for CPU parallelism.

## Architecture

- **MoonBit (90%)**: Core compiler pipeline, async I/O, module resolution, type checking, Language Service
- **Zig (10%)**: Parallel execution engine, CLI, thread pool management

## Performance Goals

- 2-3x faster than `tsc` through intelligent parallelism
- Sub-100ms Language Server response times
- Excellent incremental compilation performance

## Project Structure

```
moonbit-ts-compiler/
├── src/
│   ├── moonbit/           # MoonBit compiler core
│   │   ├── compiler/      # Scanner, Parser, Binder, Checker, Transformer, Emitter
│   │   ├── async_io/      # Async file operations
│   │   ├── module_resolver/  # Async module resolution
│   │   ├── program/       # Program orchestration
│   │   └── ffi/           # FFI exports to Zig
│   └── zig/               # Zig parallel engine
│       ├── src/           # Parallel compiler, CLI
│       └── include/       # C headers for FFI
├── tests/                 # Test suites
└── examples/              # Example TypeScript projects
```

## Building

### Prerequisites

- MoonBit toolchain (latest version)
- Zig 0.13.0 or later

### Build Steps

```bash
# Build MoonBit compiler library
cd src/moonbit
moon build

# Build Zig parallel engine and CLI
cd ../zig
zig build

# Run the compiler
./zig-out/bin/moonbit-tsc --help
```

## Development Roadmap

### Phase 1: Foundation (Current)
- [x] Project structure
- [ ] Core types (AST, Token, Symbol)
- [ ] Scanner (lexical analysis)
- [ ] Parser (basic syntax)
- [ ] Async file I/O
- [ ] FFI interface

### Phase 2: Core Compiler
- [ ] Complete parser (all TypeScript syntax)
- [ ] Binder (symbol resolution)
- [ ] Basic type checker
- [ ] Module resolver
- [ ] Transformer & Emitter

### Phase 3: Parallel Engine
- [ ] Zig thread pool
- [ ] Parallel file processing
- [ ] Dependency-aware batching
- [ ] Incremental compilation

### Phase 4: Language Service
- [ ] TSServer implementation
- [ ] Completions
- [ ] Go-to-definition
- [ ] Find references
- [ ] Refactorings

## Testing

```bash
# Run MoonBit tests
cd src/moonbit
moon test

# Run Zig tests
cd src/zig
zig build test

# Run integration tests
zig build test-integration
```

## Performance Benchmarks

Target performance (vs TypeScript 5.x):

| Project Size | TypeScript | MoonBit-Zig | Speedup |
|--------------|------------|-------------|---------|
| Small (10 files) | 1.2s | 0.9s | 1.3x |
| Medium (100 files) | 8.5s | 2.1s | 4.0x |
| Large (1000 files) | 95s | 14s | 6.8x |

## License

MIT

## Contributing

See CONTRIBUTING.md for development guidelines.

## Architecture Details

See [MoonBit-Zig-Compiler-Architecture-REVISED.md](../../MoonBit-Zig-Compiler-Architecture-REVISED.md) for detailed architecture documentation.
