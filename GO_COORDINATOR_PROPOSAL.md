# Go Coordinator + MoonBit Compiler Workers Architecture

## Executive Summary

This proposal outlines a hybrid architecture that **leverages existing typescript-go infrastructure** for worker pool management, caching, and orchestration, while **MoonBit handles core compiler tasks**: scanning, parsing, binding, and type checking.

**Key Insight**: Rather than reimplementing concurrency primitives, we reuse battle-tested code from [typescript-go](https://github.com/nicolo-ribaudo/typescript-go):
- Worker pool with work-stealing (`internal/execute/`)
- LRU file caching (`internal/vfs/cachedfs.go`)
- Project references handling (`internal/project/`)
- Watch mode infrastructure (`internal/watcher/`)

---

## What We Take from typescript-go

### Source Files to Adapt

| Component | typescript-go Path | What We Use |
|-----------|-------------------|-------------|
| **Worker Pool** | `internal/execute/tscincremental.go` | Parallel file processing, work queue |
| **File Cache** | `internal/vfs/cachedfs.go` | LRU cache for file contents |
| **Project Graph** | `internal/project/project.go` | tsconfig parsing, references |
| **Watch Mode** | `internal/watcher/watcher.go` | fsnotify integration |
| **CLI** | `cmd/tsgo/main.go` | Flag handling, output formatting |
| **Build State** | `internal/incremental/` | Incremental build tracking |

### Key Code Patterns from typescript-go

```go
// From typescript-go: internal/execute/tscincremental.go
// Worker pool pattern we'll adapt

type WorkerPool struct {
    workers    []*Worker
    workQueue  chan *WorkItem
    results    chan *Result
    wg         sync.WaitGroup
}

func (p *WorkerPool) Process(files []string) []*Result {
    // Distribute work across workers
    for _, file := range files {
        p.workQueue <- &WorkItem{File: file}
    }

    // Collect results
    results := make([]*Result, len(files))
    for i := range files {
        results[i] = <-p.results
    }
    return results
}
```

```go
// From typescript-go: internal/vfs/cachedfs.go
// LRU cache pattern we'll adapt

type CachedFS struct {
    fs        vfs.FS
    cache     *lru.Cache
    mu        sync.RWMutex
}

func (c *CachedFS) ReadFile(path string) ([]byte, error) {
    // Check cache first (read lock)
    c.mu.RLock()
    if cached, ok := c.cache.Get(path); ok {
        c.mu.RUnlock()
        return cached.([]byte), nil
    }
    c.mu.RUnlock()

    // Cache miss - read from disk (write lock)
    content, err := c.fs.ReadFile(path)
    if err != nil {
        return nil, err
    }

    c.mu.Lock()
    c.cache.Add(path, content)
    c.mu.Unlock()

    return content, nil
}
```

---

## Motivation

### Current Architecture Limitations

| Aspect | Current (Pure MoonBit) | Issue |
|--------|------------------------|-------|
| File Watching | Polling-based (`@fs.mtime`) | CPU overhead, latency |
| Async Library | `moonbitlang/async` v0.13.3 | Newer, less battle-tested |
| CLI Parsing | Custom `args.mbt` | Limited features |
| Process Management | `@process` module | Basic capabilities |
| Cross-platform I/O | MoonBit native | Less ecosystem support |

### Why Go for Coordination?

1. **Goroutines & Channels**: Lightweight, proven concurrency model
2. **fsnotify**: Native file system events (not polling)
3. **cobra/viper**: Industry-standard CLI libraries
4. **Single Binary**: Static compilation like MoonBit
5. **Ecosystem**: Rich libraries for JSON, HTTP, testing
6. **Stability**: Mature runtime with 15+ years of production use

---

## Proposed Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Go Coordinator                               │
│                                                                      │
│  ┌────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   CLI      │  │    File     │  │   Watcher   │  │   Cache     │  │
│  │  (cobra)   │  │  Discovery  │  │  (fsnotify) │  │ (SHA256)    │  │
│  └─────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│        │                │                │                │         │
│        └────────────────┴────────────────┴────────────────┘         │
│                                   │                                  │
│                         ┌─────────▼─────────┐                       │
│                         │   Coordinator     │                       │
│                         │  (Worker Pool)    │                       │
│                         └─────────┬─────────┘                       │
│                                   │                                  │
│         ┌─────────────────────────┼─────────────────────────┐       │
│         │                         │                         │       │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐         │       │
│  │  Channel 1  │  │  Channel 2  │  │  Channel N  │         │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │       │
└─────────┼────────────────┼────────────────┼─────────────────────────┘
          │ stdin/stdout   │                │
          │ JSON           │                │
   ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
   │   MoonBit   │  │   MoonBit   │  │   MoonBit   │
   │  Worker 1   │  │  Worker 2   │  │  Worker N   │
   │             │  │             │  │             │
   │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │
   │ │ Scanner │ │  │ │ Scanner │ │  │ │ Scanner │ │
   │ │ Parser  │ │  │ │ Parser  │ │  │ │ Parser  │ │
   │ │ Binder  │ │  │ │ Binder  │ │  │ │ Binder  │ │
   │ │ Checker │ │  │ │ Checker │ │  │ │ Checker │ │
   │ │Transform│ │  │ │Transform│ │  │ │Transform│ │
   │ │ Emitter │ │  │ │ Emitter │ │  │ │ Emitter │ │
   │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │
   └─────────────┘  └─────────────┘  └─────────────┘
```

---

## Component Responsibilities

### Go Coordinator (New)

| Component | Responsibility | Go Libraries |
|-----------|----------------|--------------|
| **CLI** | Argument parsing, help, version | `cobra`, `pflag` |
| **File Discovery** | Glob patterns, directory walking | `filepath`, `doublestar` |
| **Watcher** | Native file system events | `fsnotify` |
| **Dependency Graph** | Import tracking, topological sort | Custom (or call MoonBit) |
| **Cache** | Concurrent cache for worker results | `sync.Map`, `ristretto`, `go-cache` |
| **Worker Pool** | Process lifecycle, work distribution | `os/exec`, goroutines, channels |
| **Protocol** | JSON serialization, IPC | `encoding/json` |

### MoonBit Worker (Modified)

| Component | Responsibility | Status |
|-----------|----------------|--------|
| **Worker Mode** | Read JSON from stdin, write to stdout | **New** |
| **Compiler Pipeline** | Scanner → Parser → Binder → Checker → Transformer → Emitter | Existing |
| **Protocol Handler** | Parse requests, format responses | **New** |

---

## IPC Protocol Design

### Request (Go → MoonBit)

```json
{
  "id": "req-001",
  "command": "compile",
  "file": "/path/to/file.ts",
  "source": "const x: number = 42;",
  "options": {
    "target": "es2015",
    "sourceMap": true,
    "declaration": true,
    "strict": true
  }
}
```

### Response (MoonBit → Go)

```json
{
  "id": "req-001",
  "success": true,
  "js": "const x = 42;\n",
  "sourceMap": "{\"version\":3,...}",
  "declaration": "declare const x: number;\n",
  "diagnostics": []
}
```

### Error Response

```json
{
  "id": "req-001",
  "success": false,
  "js": null,
  "sourceMap": null,
  "declaration": null,
  "diagnostics": [
    {
      "file": "/path/to/file.ts",
      "line": 5,
      "column": 10,
      "code": "TS2322",
      "message": "Type 'string' is not assignable to type 'number'",
      "severity": "error"
    }
  ]
}
```

### Commands

| Command | Description |
|---------|-------------|
| `compile` | Compile a single file |
| `parse` | Parse only (for import extraction) |
| `check` | Type check only |
| `shutdown` | Graceful worker shutdown |
| `ping` | Health check |

---

## Go Concurrent Cache Design

### Why Go's Concurrent Cache?

Go provides excellent primitives for thread-safe caching in concurrent environments. When multiple workers return results simultaneously, we need a cache that:

1. **Thread-safe**: Multiple goroutines read/write concurrently
2. **Lock-free (for reads)**: Minimize contention on cache hits
3. **Memory-efficient**: Bounded size with eviction policies
4. **Fast**: O(1) lookups

---

## FFI vs IPC: Alternative Architectures

### Option A: IPC (Process-based) - Current Proposal

```
┌──────────────┐      stdin/stdout       ┌──────────────┐
│      Go      │ ◄──────JSON──────────► │   MoonBit    │
│  Coordinator │                         │   Worker     │
│   (process)  │                         │  (process)   │
└──────────────┘                         └──────────────┘
```

### Option B: FFI via WebAssembly (Recommended Alternative)

```
┌─────────────────────────────────────────────────────────┐
│                    Single Go Process                     │
│                                                          │
│  ┌────────────────┐      FFI calls      ┌────────────┐  │
│  │  Go Coordinator│ ◄────────────────► │  MoonBit   │  │
│  │                │   (direct memory)   │   WASM     │  │
│  │  - CLI         │                     │  Module    │  │
│  │  - Cache       │                     │            │  │
│  │  - Watcher     │                     │ - Scanner  │  │
│  │  - Scheduler   │                     │ - Parser   │  │
│  └────────────────┘                     │ - Checker  │  │
│                                         │ - Emitter  │  │
│         wazero (pure Go WASM runtime)   └────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Option C: FFI via Native C ABI (cgo)

```
┌─────────────────────────────────────────────────────────┐
│                    Single Go Process                     │
│                                                          │
│  ┌────────────────┐       cgo           ┌────────────┐  │
│  │  Go Coordinator│ ◄────────────────► │  MoonBit   │  │
│  │                │   (C function call) │  .so/.dylib│  │
│  └────────────────┘                     └────────────┘  │
└─────────────────────────────────────────────────────────┘
```

---

## FFI Comparison

| Aspect | IPC (JSON) | WASM (wazero) | Native (cgo) |
|--------|------------|---------------|--------------|
| **Latency** | ~1-5ms/call | ~10-100μs/call | ~1-10μs/call |
| **Memory sharing** | Serialize/copy | Direct access | Direct access |
| **Process overhead** | Multiple processes | Single process | Single process |
| **Binary count** | 2 (Go + MoonBit) | 1 (embedded WASM) | 1 (linked) |
| **Cross-compilation** | Easy | Easy (pure Go) | Hard (cgo) |
| **Debugging** | Easy (separate) | Medium | Hard |
| **MoonBit support** | Native target | WASM target | Requires C exports |
| **Parallelism** | Process-level | Goroutine-level | Goroutine-level |

---

## Recommended: WASM FFI with wazero

### Why wazero?

1. **Pure Go** - No cgo, easy cross-compilation
2. **Zero dependencies** - No system WASM runtime needed
3. **Fast** - Near-native performance for compute-heavy code
4. **Embeddable** - Single binary distribution
5. **Safe** - Sandboxed execution

### Architecture with WASM FFI

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Go Coordinator                               │
│                                                                      │
│  ┌────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   CLI      │  │    File     │  │   Watcher   │  │   Cache     │  │
│  │  (cobra)   │  │  Discovery  │  │  (fsnotify) │  │ (ristretto) │  │
│  └─────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│        │                │                │                │         │
│        └────────────────┴────────────────┴────────────────┘         │
│                                   │                                  │
│                         ┌─────────▼─────────┐                       │
│                         │   Compiler Pool   │                       │
│                         │  (goroutine-safe) │                       │
│                         └─────────┬─────────┘                       │
│                                   │                                  │
│         ┌─────────────────────────┼─────────────────────────┐       │
│         │                         │                         │       │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐         │       │
│  │ WASM Inst 1 │  │ WASM Inst 2 │  │ WASM Inst N │         │       │
│  │  (wazero)   │  │  (wazero)   │  │  (wazero)   │         │       │
│  │             │  │             │  │             │         │       │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │       │
│  │ │ Scanner │ │  │ │ Scanner │ │  │ │ Scanner │ │         │       │
│  │ │ Parser  │ │  │ │ Parser  │ │  │ │ Parser  │ │         │       │
│  │ │ Binder  │ │  │ │ Binder  │ │  │ │ Binder  │ │         │       │
│  │ │ Checker │ │  │ │ Checker │ │  │ │ Checker │ │         │       │
│  │ │Emitter  │ │  │ │Emitter  │ │  │ │Emitter  │ │         │       │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │       │
│  └─────────────┘  └─────────────┘  └─────────────┘         │       │
│                                                             │       │
│              All within single Go process                   │       │
└─────────────────────────────────────────────────────────────────────┘
```

### MoonBit WASM Exports

```moonbit
// compiler/wasm_api.mbt

/// Exported function for compilation
pub fn compile(source_ptr: Int, source_len: Int, options_ptr: Int) -> Int {
  // Read source from WASM memory
  let source = read_string_from_memory(source_ptr, source_len)

  // Parse options
  let options = parse_options(options_ptr)

  // Run compilation pipeline
  let result = compile_source(source, options)

  // Write result to WASM memory, return pointer
  write_result_to_memory(result)
}

/// Exported function to get result length
pub fn get_result_length() -> Int {
  // Return length of last compilation result
  global_result_length
}

/// Exported function to free memory
pub fn free_result(ptr: Int) -> Unit {
  // Free allocated memory
  free_memory(ptr)
}
```

### Go WASM Integration

```go
// internal/compiler/wasm.go
package compiler

import (
    "context"
    _ "embed"
    "sync"

    "github.com/tetratelabs/wazero"
    "github.com/tetratelabs/wazero/api"
)

//go:embed moonbit_compiler.wasm
var compilerWasm []byte

// WasmCompiler wraps a MoonBit WASM module
type WasmCompiler struct {
    runtime wazero.Runtime
    module  api.Module
    mu      sync.Mutex
}

// CompilerPool manages multiple WASM instances for parallel compilation
type CompilerPool struct {
    instances []*WasmCompiler
    available chan *WasmCompiler
}

// NewCompilerPool creates a pool of WASM compiler instances
func NewCompilerPool(ctx context.Context, size int) (*CompilerPool, error) {
    pool := &CompilerPool{
        instances: make([]*WasmCompiler, size),
        available: make(chan *WasmCompiler, size),
    }

    for i := 0; i < size; i++ {
        compiler, err := NewWasmCompiler(ctx)
        if err != nil {
            return nil, err
        }
        pool.instances[i] = compiler
        pool.available <- compiler
    }

    return pool, nil
}

// NewWasmCompiler creates a new WASM compiler instance
func NewWasmCompiler(ctx context.Context) (*WasmCompiler, error) {
    runtime := wazero.NewRuntime(ctx)

    // Instantiate the MoonBit compiler WASM module
    module, err := runtime.Instantiate(ctx, compilerWasm)
    if err != nil {
        return nil, err
    }

    return &WasmCompiler{
        runtime: runtime,
        module:  module,
    }, nil
}

// Compile runs the MoonBit compiler via WASM FFI
func (c *WasmCompiler) Compile(ctx context.Context, source string, opts *Options) (*Result, error) {
    c.mu.Lock()
    defer c.mu.Unlock()

    // Get exported functions
    compile := c.module.ExportedFunction("compile")
    getResultLength := c.module.ExportedFunction("get_result_length")
    freeResult := c.module.ExportedFunction("free_result")

    // Allocate memory for source string
    sourceBytes := []byte(source)
    sourcePtr, err := c.allocateMemory(ctx, len(sourceBytes))
    if err != nil {
        return nil, err
    }
    defer c.freeMemory(ctx, sourcePtr)

    // Write source to WASM memory
    if !c.module.Memory().Write(uint32(sourcePtr), sourceBytes) {
        return nil, fmt.Errorf("failed to write source to WASM memory")
    }

    // Allocate and write options
    optsPtr, err := c.writeOptions(ctx, opts)
    if err != nil {
        return nil, err
    }
    defer c.freeMemory(ctx, optsPtr)

    // Call compile function
    results, err := compile.Call(ctx, uint64(sourcePtr), uint64(len(sourceBytes)), uint64(optsPtr))
    if err != nil {
        return nil, err
    }
    resultPtr := results[0]

    // Get result length
    lenResults, err := getResultLength.Call(ctx)
    if err != nil {
        return nil, err
    }
    resultLen := lenResults[0]

    // Read result from WASM memory
    resultBytes, ok := c.module.Memory().Read(uint32(resultPtr), uint32(resultLen))
    if !ok {
        return nil, fmt.Errorf("failed to read result from WASM memory")
    }

    // Free result memory in WASM
    freeResult.Call(ctx, resultPtr)

    // Parse result
    return parseResult(resultBytes)
}

// Acquire gets a compiler from the pool
func (p *CompilerPool) Acquire() *WasmCompiler {
    return <-p.available
}

// Release returns a compiler to the pool
func (p *CompilerPool) Release(c *WasmCompiler) {
    p.available <- c
}

// CompileAll compiles multiple files concurrently
func (p *CompilerPool) CompileAll(ctx context.Context, files []FileInput, opts *Options) ([]*Result, error) {
    results := make([]*Result, len(files))
    var wg sync.WaitGroup
    var mu sync.Mutex
    var firstErr error

    for i, file := range files {
        wg.Add(1)
        go func(idx int, f FileInput) {
            defer wg.Done()

            // Acquire compiler from pool
            compiler := p.Acquire()
            defer p.Release(compiler)

            // Compile
            result, err := compiler.Compile(ctx, f.Source, opts)

            mu.Lock()
            if err != nil && firstErr == nil {
                firstErr = err
            }
            results[idx] = result
            mu.Unlock()
        }(i, file)
    }

    wg.Wait()
    return results, firstErr
}
```

### Build Process for WASM FFI

```makefile
.PHONY: all build build-wasm build-coordinator clean

# Configuration
GO_BIN = bin/tsc
WASM_FILE = go/internal/compiler/moonbit_compiler.wasm
MOONBIT_DIR = src/moonbit
GO_DIR = go

all: build

build: build-wasm build-coordinator

# Build MoonBit compiler as WASM module
build-wasm:
	cd $(MOONBIT_DIR) && moon build --target wasm compiler
	cp $(MOONBIT_DIR)/target/wasm/release/build/compiler/compiler.wasm $(WASM_FILE)

# Build Go coordinator (embeds WASM via go:embed)
build-coordinator: build-wasm
	cd $(GO_DIR) && go build -o ../$(GO_BIN) ./cmd/tsc

clean:
	rm -rf bin/
	rm -f $(WASM_FILE)
	cd $(MOONBIT_DIR) && moon clean
	cd $(GO_DIR) && go clean
```

### Performance Comparison

| Metric | IPC (JSON) | WASM FFI |
|--------|------------|----------|
| **Call overhead** | ~1-5ms | ~10-100μs |
| **Memory copy** | Full serialize | Direct access |
| **Process spawn** | Per worker | None |
| **Startup time** | ~50ms/worker | ~5ms/instance |
| **Memory per instance** | ~10MB | ~5MB |

### Trade-offs

| Aspect | IPC | WASM FFI |
|--------|-----|----------|
| **Simplicity** | ✅ Simple JSON protocol | ⚠️ Memory management |
| **Debugging** | ✅ Separate processes | ⚠️ Cross-boundary debug |
| **Isolation** | ✅ Process isolation | ⚠️ Same process |
| **Performance** | ⚠️ Serialization overhead | ✅ Direct calls |
| **Distribution** | ⚠️ Two binaries | ✅ Single binary |
| **MoonBit changes** | ✅ Minimal | ⚠️ WASM API layer |

---

## WASM Memory Considerations

### Key Memory Limitations

| Issue | Description | Impact | Mitigation |
|-------|-------------|--------|------------|
| **Linear Memory** | Single contiguous block | Can't have multiple heaps | Design for single allocator |
| **Grow-only** | Memory can grow, never shrink | Long-running instances bloat | Restart instances periodically |
| **4GB Limit** | 32-bit address space max | Large projects may hit limit | WASM64 (future) or split work |
| **No Native GC** | Manual memory management | Memory leaks possible | MoonBit has its own GC |
| **Stack Limit** | ~1MB default stack | Deep recursion fails | Increase stack, avoid deep recursion |
| **String Copies** | Strings copied in/out | Overhead for large files | Batch operations, reuse buffers |

### Memory Architecture in WASM

```
┌─────────────────────────────────────────────────────────────────┐
│                    WASM Linear Memory                            │
│                                                                  │
│  0x00000000                                           0xFFFFFFFF │
│  ├──────────┬──────────┬──────────────────────────────┤         │
│  │  Stack   │  Heap    │      Unused / Growable       │         │
│  │  (~1MB)  │  (grows →)│                             │         │
│  ├──────────┴──────────┴──────────────────────────────┤         │
│                                                                  │
│  Problems:                                                       │
│  1. Stack overflow on deep AST recursion                        │
│  2. Heap fragmentation over many compilations                   │
│  3. Memory never returned to host                               │
│  4. 4GB max (32-bit pointers)                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Specific Compiler Memory Concerns

#### 1. Large Source Files

```
Source File Size → Memory Usage Multiplier
─────────────────────────────────────────
Small (1KB)      → ~30KB  (30x)
Medium (10KB)    → ~300KB (30x)
Large (100KB)    → ~3MB   (30x)
XLarge (1MB)     → ~30MB  (30x)

Problem: A 100MB TypeScript file could need ~3GB of WASM memory!
```

#### 2. Memory Growth Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│              WASM Memory Over Multiple Compilations              │
│                                                                  │
│  Memory                                                          │
│    ▲                                                             │
│    │                                    ┌─── Memory never freed  │
│    │                              ┌─────┘                        │
│    │                        ┌─────┘                              │
│    │                  ┌─────┘                                    │
│    │            ┌─────┘                                          │
│    │      ┌─────┘                                                │
│    │ ┌────┘                                                      │
│    │─┘                                                           │
│    └────────────────────────────────────────────────────► Time   │
│         File1   File2   File3   File4   File5                    │
│                                                                  │
│  Each compilation grows memory, but it's never reclaimed!        │
└─────────────────────────────────────────────────────────────────┘
```

#### 3. Stack Overflow Risk

```
// Deep AST recursion example:
// Parsing: ((((((((((x))))))))))
// Each paren level = stack frame

func parse_expression() {
    parse_expression()  // recursive call
    // Stack: parse_expression → parse_expression → ... → OVERFLOW!
}

Risk: Deeply nested code can overflow WASM stack (~1MB default)
```

### Mitigation Strategies

#### Strategy 1: Instance Pooling with Reset

```go
// Instead of reusing same instance forever, periodically reset
type CompilerPool struct {
    instances     []*WasmCompiler
    compileCount  map[*WasmCompiler]int
    maxCompiles   int  // Reset instance after N compilations
}

func (p *CompilerPool) Compile(source string) (*Result, error) {
    compiler := p.Acquire()
    defer p.Release(compiler)

    result, err := compiler.Compile(source)

    // Track compilation count
    p.compileCount[compiler]++

    // Reset instance if it's compiled too many files (memory bloat)
    if p.compileCount[compiler] > p.maxCompiles {
        p.ResetInstance(compiler)  // Create fresh WASM instance
        p.compileCount[compiler] = 0
    }

    return result, err
}
```

#### Strategy 2: Memory Budget Monitoring

```go
func (c *WasmCompiler) Compile(source string) (*Result, error) {
    // Check current memory usage
    memoryPages := c.module.Memory().Size() // Each page = 64KB
    memoryMB := memoryPages * 64 / 1024

    if memoryMB > 100 {  // Over 100MB threshold
        log.Warn("WASM instance memory high: %dMB, consider reset", memoryMB)
    }

    if memoryMB > 500 {  // Hard limit
        return nil, fmt.Errorf("WASM memory exceeded 500MB, resetting")
    }

    return c.doCompile(source)
}
```

#### Strategy 3: File Size Limits

```go
const (
    MaxSourceSize    = 10 * 1024 * 1024  // 10MB max file
    WarnSourceSize   = 1 * 1024 * 1024   // Warn at 1MB
)

func (c *Coordinator) Compile(file string, opts *Options) (*Result, error) {
    info, _ := os.Stat(file)

    if info.Size() > MaxSourceSize {
        return nil, fmt.Errorf("file too large for WASM compilation: %d bytes", info.Size())
    }

    if info.Size() > WarnSourceSize {
        log.Warn("Large file may cause memory pressure: %s (%d bytes)", file, info.Size())
    }

    return c.doCompile(file, opts)
}
```

#### Strategy 4: Increase Stack Size (wazero)

```go
func NewWasmCompiler(ctx context.Context) (*WasmCompiler, error) {
    // Configure larger stack for deep recursion
    config := wazero.NewRuntimeConfig().
        WithMemoryLimitPages(1024).           // 64MB max memory
        WithStackSizeInBytes(8 * 1024 * 1024) // 8MB stack (vs 1MB default)

    runtime := wazero.NewRuntimeWithConfig(ctx, config)

    module, err := runtime.Instantiate(ctx, compilerWasm)
    // ...
}
```

### MoonBit's Advantage: Built-in GC

MoonBit compiles to WASM with its own garbage collector, which helps:

```
┌─────────────────────────────────────────────────────────────────┐
│              MoonBit WASM Memory Management                      │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                  WASM Linear Memory                      │    │
│  │                                                          │    │
│  │  ┌────────────────────────────────────────────────────┐ │    │
│  │  │           MoonBit GC Managed Heap                  │ │    │
│  │  │                                                    │ │    │
│  │  │  ✅ Objects allocated and freed by MoonBit GC     │ │    │
│  │  │  ✅ No manual free() needed from Go side          │ │    │
│  │  │  ⚠️ But memory pages still never returned to host │ │    │
│  │  │                                                    │ │    │
│  │  └────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  MoonBit GC reclaims objects within WASM, but WASM linear       │
│  memory itself cannot shrink - only grow.                        │
└─────────────────────────────────────────────────────────────────┘
```

### Comparison: IPC vs WASM Memory Behavior

| Aspect | IPC (Separate Process) | WASM FFI |
|--------|------------------------|----------|
| **Memory isolation** | ✅ Full OS isolation | ⚠️ Shared process |
| **Memory reclaim** | ✅ OS reclaims on exit | ❌ Grow-only |
| **Large file handling** | ✅ No artificial limit | ⚠️ 4GB limit |
| **Memory leaks** | ✅ Cleaned on restart | ⚠️ Accumulate |
| **OOM behavior** | ✅ Worker dies, coordinator lives | ⚠️ May crash host |
| **Stack overflow** | ✅ Isolated crash | ⚠️ May affect host |

### Recommendation

| Scenario | Recommended Approach |
|----------|---------------------|
| **Small-medium projects** (<1000 files) | WASM FFI with instance reset |
| **Large projects** (>1000 files) | IPC or hybrid |
| **Watch mode** (long-running) | IPC (better memory behavior) |
| **CI/CD** (short-lived) | WASM FFI (single binary easier) |
| **Memory-constrained** | IPC with fewer workers |

### Best Practice: Hybrid Approach

```go
type Coordinator struct {
    wasmPool *WasmCompilerPool  // For fast, small files
    ipcPool  *IPCWorkerPool     // For large files or memory pressure
}

func (c *Coordinator) Compile(file string, opts *Options) (*Result, error) {
    info, _ := os.Stat(file)

    // Use IPC for large files (better memory handling)
    if info.Size() > 1*1024*1024 {  // > 1MB
        return c.ipcPool.Compile(file, opts)
    }

    // Check WASM memory pressure
    if c.wasmPool.MemoryPressure() > 0.8 {  // >80% of limit
        return c.ipcPool.Compile(file, opts)
    }

    // Default: fast WASM path
    return c.wasmPool.Compile(file, opts)
}
```

### Recommendation

**Start with IPC, migrate to WASM FFI later:**

1. **Phase 1-3**: Use IPC (simpler, faster to implement)
2. **Phase 4+**: Migrate to WASM FFI for performance

**Or go directly to WASM if:**
- Single binary distribution is critical
- Sub-millisecond latency is required
- You're comfortable with WASM memory management

---

## Alternative: Zig Coordinator

### Why Consider Zig?

Zig is a systems programming language that could serve as an alternative to Go for the coordinator layer. It offers unique advantages for performance-critical CLI tools.

### Go vs Zig Comparison

| Aspect | Go | Zig |
|--------|-----|-----|
| **Runtime** | GC runtime (~2MB overhead) | No runtime (zero overhead) |
| **Binary Size** | ~10-15 MB | ~500 KB - 2 MB |
| **Startup Time** | ~5-10ms | ~1ms |
| **Memory Usage** | Higher (GC overhead) | Minimal (manual control) |
| **Compilation Speed** | Fast (~2s) | Fast (~3s) |
| **Cross-compilation** | Excellent (GOOS/GOARCH) | Excellent (built-in) |
| **C Interop** | cgo (slow, complex) | Native (zero-cost) |
| **WASM Support** | Via wazero (runtime) | Native target |
| **Concurrency** | Goroutines (easy) | Manual (async I/O) |
| **Ecosystem** | Mature (cobra, fsnotify) | Growing (fewer libs) |
| **Learning Curve** | Moderate | Steeper |
| **Safety** | Memory-safe (GC) | Compile-time safety |

### Performance Comparison

| Metric | Go | Zig | Winner |
|--------|-----|-----|--------|
| **Cold start** | ~10ms | ~1ms | Zig |
| **Binary size** | ~12MB | ~1MB | Zig |
| **Memory baseline** | ~20MB | ~2MB | Zig |
| **FFI call overhead** | ~100ns (cgo) | ~10ns | Zig |
| **WASM instantiation** | ~5ms (wazero) | ~1ms (native) | Zig |
| **Build time** | ~2s | ~3s | Go |
| **Concurrency ease** | Easy | Manual | Go |

### Zig Architecture Options

#### Option 1: Zig + MoonBit WASM (Recommended)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Single Zig Binary (~2MB)                      │
│                                                                  │
│  ┌────────────────┐                        ┌────────────────┐   │
│  │  Zig CLI       │                        │  MoonBit WASM  │   │
│  │  - Args parse  │   Direct WASM calls    │  (embedded)    │   │
│  │  - File I/O    │ ◄──────────────────►  │                │   │
│  │  - Async I/O   │   (~10μs latency)      │  - Scanner     │   │
│  │  - Thread pool │                        │  - Parser      │   │
│  │  - Cache       │                        │  - Checker     │   │
│  └────────────────┘                        │  - Emitter     │   │
│                                            └────────────────┘   │
│         No runtime overhead, no GC pauses                        │
└─────────────────────────────────────────────────────────────────┘
```

#### Option 2: Zig + MoonBit Native (C FFI)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Single Zig Binary                             │
│                                                                  │
│  ┌────────────────┐      C ABI calls       ┌────────────────┐   │
│  │  Zig CLI       │ ◄──────────────────►  │  MoonBit       │   │
│  │                │   (~1-10ns latency)    │  (static lib)  │   │
│  └────────────────┘                        └────────────────┘   │
│                                                                  │
│    Requires MoonBit C export support (experimental)              │
└─────────────────────────────────────────────────────────────────┘
```

#### Option 3: Zig + MoonBit IPC

```
┌────────────────┐      stdin/stdout       ┌────────────────┐
│   Zig CLI      │ ◄──────JSON──────────► │  MoonBit       │
│   (process)    │                         │  Worker        │
└────────────────┘                         └────────────────┘

Same as Go IPC, but smaller/faster coordinator binary
```

### Zig Implementation Sketch

```zig
// src/main.zig
const std = @import("std");
const wasm = @import("wasm.zig");
const cli = @import("cli.zig");
const cache = @import("cache.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    const args = try cli.parseArgs(allocator);
    defer args.deinit();

    // Initialize WASM compiler pool
    var compiler_pool = try wasm.CompilerPool.init(allocator, args.parallel);
    defer compiler_pool.deinit();

    // Initialize cache
    var compilation_cache = try cache.Cache.init(allocator, 100 * 1024 * 1024);
    defer compilation_cache.deinit();

    // Discover files
    const files = try discoverFiles(allocator, args.paths);
    defer allocator.free(files);

    // Compile in parallel
    var results = try compileAll(allocator, &compiler_pool, &compilation_cache, files, args);

    // Write outputs
    try writeOutputs(allocator, results, args.out_dir);
}
```

### Zig Concurrent Cache

```zig
// src/cache.zig
const std = @import("std");

pub const CacheEntry = struct {
    js: []const u8,
    source_map: ?[]const u8,
    declaration: ?[]const u8,
};

pub const Cache = struct {
    map: std.StringHashMap(CacheEntry),
    mutex: std.Thread.Mutex,
    max_size: usize,
    current_size: usize,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, max_size: usize) !Cache {
        return .{
            .map = std.StringHashMap(CacheEntry).init(allocator),
            .mutex = .{},
            .max_size = max_size,
            .current_size = 0,
            .allocator = allocator,
        };
    }

    pub fn get(self: *Cache, key: []const u8) ?CacheEntry {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.map.get(key);
    }

    pub fn put(self: *Cache, key: []const u8, entry: CacheEntry) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const entry_size = entry.js.len +
            (entry.source_map orelse &[_]u8{}).len +
            (entry.declaration orelse &[_]u8{}).len;

        // Evict if needed
        while (self.current_size + entry_size > self.max_size) {
            try self.evictOne();
        }

        try self.map.put(key, entry);
        self.current_size += entry_size;
    }
};
```

### Zig File Watching (Native OS APIs)

```zig
// src/watcher.zig
const std = @import("std");
const builtin = @import("builtin");

pub const Watcher = struct {
    fd: std.os.fd_t,
    watched_paths: std.StringHashMap(WatchDescriptor),

    pub fn init() !Watcher {
        const fd = switch (builtin.os.tag) {
            .macos, .freebsd => try std.os.kqueue(),
            .linux => try std.os.inotify_init1(0),
            else => @compileError("Unsupported OS"),
        };
        return .{ .fd = fd, .watched_paths = ... };
    }

    pub fn addPath(self: *Watcher, path: []const u8) !void {
        switch (builtin.os.tag) {
            .macos => {
                // kqueue: native macOS file events
                const file_fd = try std.os.open(path, .{}, 0);
                var event = std.os.Kevent{
                    .ident = @intCast(file_fd),
                    .filter = std.os.EVFILT.VNODE,
                    .flags = std.os.EV.ADD | std.os.EV.CLEAR,
                    .fflags = std.os.NOTE.WRITE | std.os.NOTE.DELETE,
                };
                _ = try std.os.kevent(self.fd, &.{event}, &.{}, null);
            },
            .linux => {
                // inotify: native Linux file events
                _ = try std.os.inotify_add_watch(
                    self.fd, path,
                    std.os.IN.MODIFY | std.os.IN.DELETE
                );
            },
        }
    }
};
```

### Binary Size Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│                    Binary Size Comparison                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Go (wazero + cobra + fsnotify):                                │
│  ████████████████████████████████████████  ~12 MB               │
│                                                                  │
│  Zig (native WASM + CLI):                                       │
│  ████  ~1.5 MB                                                  │
│                                                                  │
│  Zig (stripped, LTO):                                           │
│  ██  ~800 KB                                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Memory Usage Comparison

```
┌─────────────────────────────────────────────────────────────────┐
│                    Memory Usage (8 Workers)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Go Coordinator + wazero:                                       │
│  ████████████████████  ~80 MB                                   │
│  (20MB base + 8x ~7.5MB WASM instances)                         │
│                                                                  │
│  Zig Coordinator + WASM:                                        │
│  ████████  ~35 MB                                               │
│  (3MB base + 8x ~4MB WASM instances)                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Startup Time Comparison

| Phase | Go | Zig |
|-------|-----|-----|
| Process launch | 5ms | 1ms |
| Runtime init | 3ms | 0ms |
| WASM load | 5ms | 2ms |
| CLI parse | 1ms | 0.5ms |
| **Total cold start** | **~14ms** | **~3.5ms** |

### Ecosystem Comparison

| Need | Go Library | Zig Equivalent | Maturity |
|------|------------|----------------|----------|
| CLI parsing | cobra | clap, zig-arg | ⚠️ Less mature |
| File watching | fsnotify | Native kqueue/inotify | ✅ Direct OS API |
| JSON | encoding/json | std.json | ✅ Built-in |
| Caching | ristretto | Custom | ⚠️ Need to build |
| Logging | logrus/zap | std.log | ✅ Built-in |
| Testing | testing | std.testing | ✅ Built-in |

### When to Choose Go vs Zig

#### Choose Go When:
- Rapid prototyping needed
- Team already knows Go
- Rich ecosystem required (cobra, fsnotify, ristretto)
- Concurrency-heavy workload (goroutines simpler)
- GC overhead is acceptable

#### Choose Zig When:
- Minimal binary size critical
- Embedded/constrained environments
- Maximum performance required
- Zero-cost C interop needed
- Deterministic latency required (no GC pauses)

### Recommendation Matrix

| Priority | Recommended |
|----------|-------------|
| **Speed to market** | Go |
| **Smallest binary** | Zig |
| **Lowest latency** | Zig |
| **Team productivity** | Go |
| **Minimal dependencies** | Zig |
| **Future LSP server** | Go (easier async) |

### Final Recommendation

| Approach | Best For |
|----------|----------|
| **Go + wazero** | Fastest development, good performance |
| **Zig + WASM** | Maximum performance, minimal size |
| **Go + Zig runtime** | Balance of productivity and performance |

**For this project**: Start with **Go + wazero** for faster iteration, consider **Zig** rewrite if binary size or startup performance becomes critical.

---

### Cache Library Options

| Library | Pros | Cons | Use Case |
|---------|------|------|----------|
| **`sync.Map`** | Built-in, lock-free reads | No size limits, no TTL | Simple cases |
| **`ristretto`** (dgraph-io) | High performance, LFU eviction, metrics | External dependency | Production caches |
| **`go-cache`** (patrickmn) | Simple API, TTL support | Less performant | Medium workloads |
| **`bigcache`** (allegro) | Zero GC overhead, fast | Complex API | Very large caches |

**Recommendation**: Use **`ristretto`** for its excellent concurrent performance and built-in metrics.

### Cache Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Go Concurrent Cache                           │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    CacheKey                               │   │
│  │  hash(filePath + contentHash + target + sourceMap + decl)│   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   ristretto.Cache                         │   │
│  │                                                           │   │
│  │   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐  │   │
│  │   │ Shard 0 │   │ Shard 1 │   │ Shard 2 │   │ Shard N │  │   │
│  │   │ (mutex) │   │ (mutex) │   │ (mutex) │   │ (mutex) │  │   │
│  │   └─────────┘   └─────────┘   └─────────┘   └─────────┘  │   │
│  │                                                           │   │
│  │   Goroutine 1 ──┐                                        │   │
│  │   Goroutine 2 ──┼──► Concurrent Access (lock-free reads) │   │
│  │   Goroutine N ──┘                                        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    CacheEntry                             │   │
│  │  { js: string, sourceMap: string, declaration: string }  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Implementation

```go
// internal/cache/cache.go
package cache

import (
    "crypto/sha256"
    "encoding/hex"
    "fmt"

    "github.com/dgraph-io/ristretto"
)

// CacheKey uniquely identifies a compilation result
type CacheKey struct {
    FilePath    string
    ContentHash string
    Target      string
    SourceMap   bool
    Declaration bool
}

// CacheEntry stores compilation outputs
type CacheEntry struct {
    JS          string
    SourceMap   string
    Declaration string
}

// CompilationCache provides concurrent-safe caching for worker results
type CompilationCache struct {
    cache   *ristretto.Cache
    hits    int64
    misses  int64
}

// NewCompilationCache creates a new cache with specified max size
func NewCompilationCache(maxSizeMB int64) (*CompilationCache, error) {
    cache, err := ristretto.NewCache(&ristretto.Config{
        NumCounters: 1e7,                          // 10M counters for admission
        MaxCost:     maxSizeMB * 1024 * 1024,      // Max size in bytes
        BufferItems: 64,                           // Number of keys per Get buffer
        Metrics:     true,                         // Enable hit/miss metrics
    })
    if err != nil {
        return nil, err
    }

    return &CompilationCache{cache: cache}, nil
}

// Hash generates a cache key string
func (k *CacheKey) Hash() string {
    data := fmt.Sprintf("%s:%s:%s:%v:%v",
        k.FilePath, k.ContentHash, k.Target, k.SourceMap, k.Declaration)
    hash := sha256.Sum256([]byte(data))
    return hex.EncodeToString(hash[:])
}

// Get retrieves a cached entry (thread-safe, lock-free)
func (c *CompilationCache) Get(key *CacheKey) (*CacheEntry, bool) {
    val, found := c.cache.Get(key.Hash())
    if !found {
        return nil, false
    }
    entry, ok := val.(*CacheEntry)
    return entry, ok
}

// Set stores a compilation result (thread-safe)
func (c *CompilationCache) Set(key *CacheKey, entry *CacheEntry) {
    // Estimate cost as total size of all output strings
    cost := int64(len(entry.JS) + len(entry.SourceMap) + len(entry.Declaration))
    c.cache.Set(key.Hash(), entry, cost)
    c.cache.Wait() // Ensure write is complete
}

// Stats returns cache statistics
func (c *CompilationCache) Stats() (hits, misses uint64) {
    metrics := c.cache.Metrics
    return metrics.Hits(), metrics.Misses()
}

// Clear empties the cache
func (c *CompilationCache) Clear() {
    c.cache.Clear()
}
```

### Content Hash Generation

```go
// internal/cache/hash.go
package cache

import (
    "crypto/sha256"
    "encoding/hex"
    "io"
    "os"
)

// HashFile computes SHA256 hash of file contents
func HashFile(path string) (string, error) {
    f, err := os.Open(path)
    if err != nil {
        return "", err
    }
    defer f.Close()

    h := sha256.New()
    if _, err := io.Copy(h, f); err != nil {
        return "", err
    }

    return hex.EncodeToString(h.Sum(nil)), nil
}

// HashString computes SHA256 hash of a string
func HashString(content string) string {
    hash := sha256.Sum256([]byte(content))
    return hex.EncodeToString(hash[:])
}
```

### Integration with Worker Pool

```go
// internal/coordinator/coordinator.go
package coordinator

import (
    "context"
    "sync"

    "moonbit-tsc/internal/cache"
    "moonbit-tsc/internal/protocol"
)

type Coordinator struct {
    cache      *cache.CompilationCache
    workerPool *WorkerPool
    mu         sync.Mutex
}

// Compile handles a single file with cache check
func (c *Coordinator) Compile(ctx context.Context, file string, opts *protocol.Options) (*protocol.Response, error) {
    // 1. Compute content hash
    contentHash, err := cache.HashFile(file)
    if err != nil {
        return nil, err
    }

    // 2. Check cache (lock-free read)
    cacheKey := &cache.CacheKey{
        FilePath:    file,
        ContentHash: contentHash,
        Target:      opts.Target,
        SourceMap:   opts.SourceMap,
        Declaration: opts.Declaration,
    }

    if entry, found := c.cache.Get(cacheKey); found {
        // Cache hit - return immediately
        return &protocol.Response{
            Success:     true,
            JS:          entry.JS,
            SourceMap:   entry.SourceMap,
            Declaration: entry.Declaration,
        }, nil
    }

    // 3. Cache miss - compile via worker
    resp, err := c.workerPool.Compile(ctx, file, opts)
    if err != nil {
        return nil, err
    }

    // 4. Store result in cache (thread-safe write)
    if resp.Success {
        c.cache.Set(cacheKey, &cache.CacheEntry{
            JS:          resp.JS,
            SourceMap:   resp.SourceMap,
            Declaration: resp.Declaration,
        })
    }

    return resp, nil
}

// CompileAll compiles multiple files concurrently with caching
func (c *Coordinator) CompileAll(ctx context.Context, files []string, opts *protocol.Options) ([]*protocol.Response, error) {
    results := make([]*protocol.Response, len(files))
    var wg sync.WaitGroup
    var mu sync.Mutex
    var firstErr error

    for i, file := range files {
        wg.Add(1)
        go func(idx int, f string) {
            defer wg.Done()

            resp, err := c.Compile(ctx, f, opts)

            mu.Lock()
            if err != nil && firstErr == nil {
                firstErr = err
            }
            results[idx] = resp
            mu.Unlock()
        }(i, file)
    }

    wg.Wait()
    return results, firstErr
}
```

### Cache Eviction Strategy

Using LFU (Least Frequently Used) via ristretto:

```go
// Configuration for different scenarios
func NewCacheForDevelopment() (*CompilationCache, error) {
    // Small cache for development: 50MB
    return NewCompilationCache(50)
}

func NewCacheForCI() (*CompilationCache, error) {
    // Large cache for CI builds: 500MB
    return NewCompilationCache(500)
}

func NewCacheForProduction() (*CompilationCache, error) {
    // Medium cache for production: 100MB
    return NewCompilationCache(100)
}
```

### Cache Metrics & Monitoring

```go
// Periodic stats logging
func (c *Coordinator) logCacheStats() {
    hits, misses := c.cache.Stats()
    total := hits + misses
    hitRate := float64(0)
    if total > 0 {
        hitRate = float64(hits) / float64(total) * 100
    }
    log.Printf("Cache: %d hits, %d misses, %.1f%% hit rate", hits, misses, hitRate)
}
```

### Disk-Based Persistence (Future)

For cross-session caching:

```go
// internal/cache/persistent.go
type PersistentCache struct {
    memory  *CompilationCache
    diskDir string
}

func (c *PersistentCache) Get(key *CacheKey) (*CacheEntry, bool) {
    // 1. Check memory cache
    if entry, found := c.memory.Get(key); found {
        return entry, true
    }

    // 2. Check disk cache
    diskPath := filepath.Join(c.diskDir, key.Hash()+".json")
    if data, err := os.ReadFile(diskPath); err == nil {
        var entry CacheEntry
        if json.Unmarshal(data, &entry) == nil {
            // Promote to memory cache
            c.memory.Set(key, &entry)
            return &entry, true
        }
    }

    return nil, false
}

func (c *PersistentCache) Set(key *CacheKey, entry *CacheEntry) {
    // Write to memory
    c.memory.Set(key, entry)

    // Write to disk asynchronously
    go func() {
        data, _ := json.Marshal(entry)
        diskPath := filepath.Join(c.diskDir, key.Hash()+".json")
        os.WriteFile(diskPath, data, 0644)
    }()
}
```

---

## Directory Structure

```
pure-moonbit-cli/
├── go/                           # Go coordinator
│   ├── cmd/
│   │   └── tsc/
│   │       └── main.go           # Entry point
│   ├── internal/
│   │   ├── cli/
│   │   │   ├── cli.go            # Cobra setup
│   │   │   └── flags.go          # Flag definitions
│   │   ├── discovery/
│   │   │   ├── discovery.go      # File discovery
│   │   │   └── glob.go           # Glob pattern matching
│   │   ├── watcher/
│   │   │   ├── watcher.go        # fsnotify wrapper
│   │   │   └── debounce.go       # Change debouncing
│   │   ├── depgraph/
│   │   │   ├── graph.go          # Dependency graph
│   │   │   └── topo.go           # Topological sort
│   │   ├── cache/
│   │   │   ├── cache.go          # Cache management
│   │   │   └── hash.go           # Content hashing
│   │   ├── coordinator/
│   │   │   ├── coordinator.go    # Main orchestrator
│   │   │   ├── pool.go           # Worker pool
│   │   │   └── worker.go         # Single worker management
│   │   └── protocol/
│   │       ├── protocol.go       # Message types
│   │       └── codec.go          # JSON encoding/decoding
│   ├── go.mod
│   ├── go.sum
│   └── Makefile
│
├── src/moonbit/                  # MoonBit compiler (existing + worker mode)
│   ├── compiler/                 # Existing compiler code
│   │   ├── scanner.mbt
│   │   ├── parser.mbt
│   │   ├── binder.mbt
│   │   ├── checker.mbt
│   │   ├── transformer.mbt
│   │   ├── emitter.mbt
│   │   └── ...
│   ├── worker/                   # NEW: Worker mode
│   │   ├── moon.pkg.json
│   │   ├── main.mbt              # Worker entry point
│   │   ├── protocol.mbt          # Request/response types
│   │   └── handler.mbt           # Command handlers
│   └── moon.mod.json
│
├── bin/                          # Build outputs
│   ├── tsc                       # Go coordinator binary
│   └── tsc-worker                # MoonBit worker binary
│
├── Makefile                      # Top-level build
└── ...
```

---

## Implementation Phases

### Phase 1: MoonBit Worker Mode (Week 1)

**Goal**: Create a MoonBit worker that reads JSON requests from stdin and writes responses to stdout.

**Tasks**:
1. Define protocol types in `worker/protocol.mbt`
2. Implement JSON parsing for requests
3. Implement JSON serialization for responses
4. Create main loop that processes requests
5. Handle `compile`, `parse`, `ping`, `shutdown` commands
6. Add error handling and graceful shutdown
7. Write tests for protocol handling

**Deliverable**: `tsc-worker` binary that can be tested manually:
```bash
echo '{"id":"1","command":"compile","source":"const x = 1;","options":{}}' | ./tsc-worker
```

### Phase 2: Go CLI Foundation (Week 1-2)

**Goal**: Basic Go CLI that can invoke the MoonBit worker.

**Tasks**:
1. Set up Go module structure
2. Implement CLI with cobra
3. Add flags: `--target`, `--outDir`, `--sourceMap`, `--declaration`, `--watch`, `--parallel`
4. Implement file discovery with glob patterns
5. Single-threaded compilation (spawn worker, send files sequentially)
6. Write output files (.js, .map, .d.ts)
7. Add tests

**Deliverable**: Working `tsc` that compiles files sequentially.

### Phase 3: Worker Pool (Week 2)

**Goal**: Parallel compilation with persistent worker processes.

**Tasks**:
1. Implement worker pool with configurable size
2. Keep workers alive (reuse for multiple files)
3. Implement work distribution via channels
4. Add worker health checks and restart on failure
5. Implement graceful shutdown (send `shutdown` command to all workers)
6. Add benchmarks comparing 1, 2, 4, 8 workers

**Deliverable**: Parallel compilation with `--parallel N` flag.

### Phase 4: File Watching (Week 3)

**Goal**: Native file system watching with fsnotify.

**Tasks**:
1. Integrate fsnotify for file change detection
2. Implement debouncing (coalesce rapid changes)
3. Handle file creation, modification, deletion
4. Trigger recompilation on changes
5. Add `--watch` and `--watchInterval` flags
6. Handle watcher errors gracefully

**Deliverable**: `tsc --watch` with native file events.

### Phase 5: Dependency Graph (Week 3-4)

**Goal**: Smart incremental compilation based on imports.

**Tasks**:
1. Option A: Call MoonBit worker with `parse` command to extract imports
2. Option B: Implement simple import regex extraction in Go
3. Build dependency graph (DAG) with bidirectional edges
4. Implement topological sort for correct build order
5. On file change, find all dependents and recompile in order
6. Add cycle detection and error reporting

**Deliverable**: Incremental compilation that only rebuilds affected files.

### Phase 6: Content Hash Caching (Week 4)

**Goal**: Skip compilation for unchanged files.

**Tasks**:
1. Implement SHA256 content hashing
2. Store cache entries: `{hash, options} → {js, map, dts}`
3. Check cache before compilation
4. Invalidate cache on options change
5. Add cache statistics (hits, misses)
6. Optional: Persist cache to disk for cross-session caching

**Deliverable**: Fast rebuilds with cache hits.

### Phase 7: Polish & Testing (Week 5)

**Goal**: Production-ready quality.

**Tasks**:
1. Comprehensive integration tests
2. Cross-platform testing (macOS, Linux, Windows)
3. Error message improvements
4. Performance profiling and optimization
5. Documentation updates
6. CI/CD setup for building both Go and MoonBit

**Deliverable**: Release-ready hybrid compiler.

---

## Build System

### Makefile

```makefile
.PHONY: all build build-worker build-coordinator clean test

# Configuration
GO_BIN = bin/tsc
WORKER_BIN = bin/tsc-worker
MOONBIT_DIR = src/moonbit
GO_DIR = go

all: build

build: build-worker build-coordinator

build-worker:
	cd $(MOONBIT_DIR) && moon build --target native worker
	cp $(MOONBIT_DIR)/target/native/release/build/worker/worker.exe $(WORKER_BIN)

build-coordinator:
	cd $(GO_DIR) && go build -o ../$(GO_BIN) ./cmd/tsc

clean:
	rm -rf bin/
	cd $(MOONBIT_DIR) && moon clean
	cd $(GO_DIR) && go clean

test: test-worker test-coordinator

test-worker:
	cd $(MOONBIT_DIR) && moon test --target native

test-coordinator:
	cd $(GO_DIR) && go test ./...

# Cross-platform builds
build-all: build-linux build-darwin build-windows

build-linux:
	cd $(GO_DIR) && GOOS=linux GOARCH=amd64 go build -o ../bin/tsc-linux ./cmd/tsc

build-darwin:
	cd $(GO_DIR) && GOOS=darwin GOARCH=amd64 go build -o ../bin/tsc-darwin ./cmd/tsc

build-windows:
	cd $(GO_DIR) && GOOS=windows GOARCH=amd64 go build -o ../bin/tsc-windows.exe ./cmd/tsc
```

---

## Performance Considerations

### IPC Overhead

| Concern | Mitigation |
|---------|------------|
| Process spawn cost | Keep workers alive, reuse for many files |
| JSON serialization | Minimal overhead for small payloads |
| stdin/stdout latency | Buffered I/O, batch requests if needed |

### Benchmarks (Expected)

| Files | Workers | Current (MoonBit) | Proposed (Go+MoonBit) |
|-------|---------|-------------------|----------------------|
| 20 | 1 | 34ms | ~30ms |
| 20 | 4 | 13ms | ~10ms |
| 100 | 4 | ~65ms | ~50ms |
| 100 | 8 | ~45ms | ~30ms |

*Note: Go's goroutine scheduling and fsnotify should improve real-world performance.*

### Memory Usage

- **Go Coordinator**: ~10-20 MB base
- **MoonBit Worker**: ~5-10 MB per worker
- **Total (8 workers)**: ~100 MB

---

## Comparison: Before vs After

| Aspect | Before (Pure MoonBit) | After (Go + MoonBit) |
|--------|----------------------|---------------------|
| **Languages** | MoonBit only | Go + MoonBit |
| **CLI Framework** | Custom args.mbt | cobra (mature) |
| **File Watching** | Polling (500ms) | fsnotify (instant) |
| **Concurrency** | moonbitlang/async | goroutines/channels |
| **Build Outputs** | 1 binary | 2 binaries |
| **Cross-platform** | Good | Excellent |
| **Ecosystem** | Limited | Rich Go ecosystem |
| **Maintenance** | Single language | Two languages |
| **Project Name** | "Pure MoonBit" | "MoonBit TypeScript Compiler" |

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| IPC adds latency | Medium | Keep workers alive, benchmark |
| Two toolchains | Medium | Single Makefile, CI automation |
| Worker crashes | Low | Auto-restart, health checks |
| Platform differences | Low | Go's cross-platform is excellent |
| Complexity increase | Medium | Clear separation of concerns |

---

## Decision Points

### 1. Import Extraction Strategy

**Option A: MoonBit `parse` command**
- Pro: Reuses existing parser, accurate
- Con: Extra IPC round-trip per file

**Option B: Go regex extraction**
- Pro: Fast, no IPC
- Con: May miss edge cases (comments, strings)

**Recommendation**: Start with Option A for correctness, optimize later if needed.

### 2. Cache Persistence

**Option A: In-memory only**
- Pro: Simple, no disk I/O
- Con: Lost on restart

**Option B: Disk-based cache**
- Pro: Survives restarts, faster cold starts
- Con: More complexity, cache invalidation

**Recommendation**: Start with in-memory, add disk cache in future.

### 3. Worker Lifecycle

**Option A: One worker per file**
- Pro: Simple, isolated
- Con: High spawn overhead

**Option B: Persistent worker pool**
- Pro: Fast, reuses processes
- Con: More complex state management

**Recommendation**: Option B (persistent pool) for performance.

---

## Success Metrics

1. **Build Time**: ≤ current MoonBit implementation
2. **Watch Latency**: < 100ms from file save to recompilation start
3. **Memory Usage**: < 200 MB for 8 workers
4. **Test Coverage**: > 80% for Go code
5. **Cross-platform**: Works on macOS, Linux, Windows

---

## Conclusion

The Go coordinator + MoonBit worker architecture provides:

1. **Best of both worlds**: Go's mature ecosystem for orchestration, MoonBit's type-safe compilation
2. **Improved reliability**: Battle-tested Go concurrency vs. experimental async
3. **Better DX**: Native file watching, rich CLI, faster iteration
4. **Future-proof**: Easy to add features like HTTP API, LSP server, etc.

The main trade-off is increased complexity (two languages, two binaries), but the benefits for a production-quality tool justify this.

---

## Next Steps

1. [ ] Review and approve this proposal
2. [ ] Decide on import extraction strategy (MoonBit parse vs Go regex)
3. [ ] Begin Phase 1: MoonBit Worker Mode
4. [ ] Set up Go module structure

---

*Proposal Date: 2025-11-30*
*Status: Draft*