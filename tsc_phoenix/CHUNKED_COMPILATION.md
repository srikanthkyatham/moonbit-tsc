# Chunked Compilation Strategy

## Overview

The TypeScript type checker now uses an optimized **chunked compilation** approach that distributes files efficiently across worker processes, maximizing throughput while maintaining fault tolerance.

## Key Parameters

- **Max Files Per Chunk**: 10 files
- **Worker Pool Size**: 4 workers (configurable)
- **Max Concurrency**: `pool_size * 2` (allows queuing for load balancing)
- **Chunk Timeout**: 2 minutes per chunk
- **Retry Attempts**: 3 with exponential backoff

## Architecture

### Before (Single-File Approach)
```
1000 files → Task.async_stream(max_concurrency: 4)
├─ Only 4 files checked at once
├─ 1000 CLI invocations
├─ 1000 process spawns
└─ High overhead
```

### After (Chunked Approach)
```
1000 files → 100 chunks of 10 files each
├─ Distributed across 4 workers (round-robin)
├─ Only 100 CLI invocations (10x reduction)
├─ All 4 workers utilized simultaneously
└─ Better fault tolerance (max 10 files lost per chunk failure)
```

## How It Works

### 1. File Chunking
```elixir
files = [file1, file2, ..., file1000]
chunks = Enum.chunk_every(files, 10)
# Result: 100 chunks of 10 files each
```

### 2. Round-Robin Distribution
```
Worker 1: Chunk 1, 5, 9, 13, ...   (25 chunks)
Worker 2: Chunk 2, 6, 10, 14, ...  (25 chunks)
Worker 3: Chunk 3, 7, 11, 15, ...  (25 chunks)
Worker 4: Chunk 4, 8, 12, 16, ...  (25 chunks)
```

### 3. Parallel Execution
```
Timeline: [====================================]
Worker 1: [C1][C5][C9][C13][C17][C21][C25]...
Worker 2: [C2][C6][C10][C14][C18][C22][C26]...
Worker 3: [C3][C7][C11][C15][C19][C23][C27]...
Worker 4: [C4][C8][C12][C16][C20][C24][C28]...

Each [Cx] = 10 files in one CLI batch call
```

## Performance Comparison

### Example: 1000 Files

| Metric | Per-File | All-to-One | Chunked (NEW) |
|--------|----------|------------|---------------|
| CLI Invocations | 1000 | 1 | 100 |
| Workers Utilized | 4 | 1 | 4 |
| Max Concurrency | 4 files | 1000 files | 40 files (4×10) |
| Fault Loss | 1 file | 1000 files | 10 files |
| Estimated Time* | 25s | 100s | 15-20s |

*Assuming 100ms per file, with overhead reduction for batch processing

## Progress Tracking

The chunked approach provides fine-grained progress updates:

```elixir
# Progress broadcast every 10 chunks or at completion
%{
  completed: 50,           # Chunks completed
  total: 100,              # Total chunks
  progress: 50.0,          # Percentage
  files_checked: 500       # Approximate files checked
}
```

## Fault Tolerance

### Retry Logic
When a chunk fails, it's retried up to 3 times with exponential backoff:

1. **Attempt 1**: Immediate retry
2. **Attempt 2**: 1 second delay
3. **Attempt 3**: 2 seconds delay
4. **After 3 failures**: Log error and skip chunk (max 10 files lost)

### Crash Recovery
- If a worker crashes, only the current chunk (max 10 files) is lost
- Supervisor restarts the worker automatically
- Remaining chunks continue processing on other workers

## Type Sharing

Each chunk benefits from the shared type cache:

```elixir
# Before checking a chunk, all previously cached types are available
options = %{use_cached_types: true}

# Worker fetches types from TypeCache (ETS)
external_types = %{
  "modules" => %{
    "/path/to/module1.ts" => {...types...},
    "/path/to/module2.ts" => {...types...}
  },
  "module_mappings" => %{
    "lodash" => "/path/to/node_modules/lodash/index.d.ts"
  }
}

# CLI receives types as --external-types JSON
CLI --json file1 file2 ... file10 --external-types '{...}'
```

## Configuration

### Adjusting Chunk Size

To change the max files per chunk, modify the module attribute:

```elixir
# In coordinator.ex
@max_files_per_chunk 10  # Change this value
```

**Recommendations:**
- **Smaller chunks (5)**: More granular progress, higher overhead
- **Medium chunks (10)**: Balanced (current default)
- **Larger chunks (20)**: Less overhead, coarser progress

### Adjusting Worker Pool Size

```elixir
# In config/config.exs
config :tsc_phoenix,
  worker_pool_size: 4  # Adjust based on CPU cores
```

**Recommendations:**
- **CPU-bound**: Set to number of CPU cores
- **I/O-bound**: Set to 2× CPU cores
- **Memory-constrained**: Reduce to avoid OOM

## Monitoring

### Logs

```bash
# Chunked compilation start
[info] Checking 1000 files in 100 chunks (max 10 files/chunk) using 4 workers

# Progress updates (every 10 chunks)
[info] Progress: 10/100 chunks (10.0%)
[info] Progress: 20/100 chunks (20.0%)
...

# Chunk failures
[warning] Chunk 42 failed: timeout, retrying...
[info] Retrying chunk (attempt 2/3) with 10 files...
```

### Metrics

The following Telemetry events are emitted:

- `[:tsc, :level_check, :start]` - Level check started
- `[:tsc, :level_check, :stop]` - Level check completed
- `[:tsc, :file_check, :start]` - Individual file check started
- `[:tsc, :file_check, :stop]` - Individual file check completed

### LiveView Progress

Subscribe to progress updates in LiveView:

```elixir
# In your LiveView mount/3
Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "compiler:progress")

# Handle progress updates
def handle_info({:chunk_complete, progress}, socket) do
  {:noreply, assign(socket, progress: progress)}
end
```

## Benefits Summary

✅ **10x fewer CLI invocations** (100 vs 1000)
✅ **4x worker utilization** (all workers busy)
✅ **Fine-grained progress** (100 checkpoints)
✅ **Better fault tolerance** (max 10 files lost)
✅ **Automatic load balancing** (round-robin + queuing)
✅ **Exponential backoff retry** (3 attempts)
✅ **Type cache sharing** (via ETS)
✅ **PubSub progress updates** (for LiveView)

## Future Enhancements

### Work Stealing
Instead of static round-robin, workers could pull chunks from a shared queue:
- Faster workers automatically get more work
- Better handling of variable file complexity
- More even load distribution

### Adaptive Chunk Size
Dynamically adjust chunk size based on:
- File complexity (AST node count)
- Available memory
- Worker processing speed
- Historical timing data

### Predictive Scheduling
Use file metadata to schedule chunks:
- Large/complex files in separate chunks
- Dependencies checked before dependents
- Frequently changing files prioritized
