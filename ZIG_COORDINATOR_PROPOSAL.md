# Zig Coordinator for MoonBit TypeScript Compiler

## Executive Summary

This proposal outlines a **Zig-based coordination layer** to replace the current Elixir/Phoenix (`tsc_phoenix/`) coordinator. Zig offers significant advantages in binary size, startup time, memory usage, and deterministic performance—all critical for a CLI tool.

**Key Benefits**:
- **Binary size**: ~1-2MB (vs 20-30MB with Elixir/Burrito)
- **Startup time**: ~1-3ms (vs ~20-50ms)
- **Memory baseline**: ~2-5MB (vs ~50-100MB)
- **No runtime**: Zero GC pauses, deterministic latency
- **Native file watching**: Direct kqueue/inotify access

---

## Current Architecture (tsc_phoenix)

```
┌──────────────────────────────────────────────────────────────────┐
│                   Burrito Wrapper (Zig)                           │
│                   Extracts & launches Elixir                      │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                    ┌────────▼────────────────┐
                    │  Elixir Phoenix App     │
                    │  (tsc_phoenix/)         │
                    │  - TSC.Coordinator      │
                    │  - TSC.Graph            │
                    │  - TSC.Worker.Pool      │
                    │  - TSC.Watcher          │
                    │  - TSC.Cache            │
                    └────────┬────────────────┘
                             │ JSON-RPC stdin/stdout
                    ┌────────▼──────────┐
                    │  MoonBit Worker   │
                    │  (native binary)  │
                    └───────────────────┘
```

### Current Elixir Components to Replace

| Component | Elixir Module | Responsibility |
|-----------|---------------|----------------|
| Coordinator | `TSC.Coordinator` | Orchestrates compilation pipeline |
| Dependency Graph | `TSC.Graph.DependencyGraph` | DAG with topological sort |
| Worker Pool | `TSC.Worker.PoolSupervisor` | Manages MoonBit worker processes |
| Worker Port | `TSC.Worker.MoonbitPort` | GenServer for IPC communication |
| File Watcher | `TSC.Watcher.FileWatcher` | File system change detection |
| Type Cache | `TSC.Cache.TypeCache` | Caches exported types |
| File Cache | `TSC.Cache.FileCache` | Tracks file modification times |
| Protocol | `TSC.Worker.Protocol` | JSON-RPC message encoding |

---

## Proposed Zig Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Zig Coordinator (~1-2MB binary)                   │
│                                                                      │
│  ┌────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │   CLI      │  │    File     │  │   Watcher   │  │   Cache     │  │
│  │  (clap)    │  │  Discovery  │  │ kqueue/     │  │ (HashMap)   │  │
│  │            │  │  (glob)     │  │ inotify     │  │             │  │
│  └─────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  │
│        │                │                │                │         │
│        └────────────────┴────────────────┴────────────────┘         │
│                                   │                                  │
│                         ┌─────────▼─────────┐                       │
│                         │   Coordinator     │                       │
│                         │  (Thread Pool)    │                       │
│                         └─────────┬─────────┘                       │
│                                   │                                  │
│         ┌─────────────────────────┼─────────────────────────┐       │
│         │                         │                         │       │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐         │       │
│  │  Worker 1   │  │  Worker 2   │  │  Worker N   │         │       │
│  │  (child     │  │  (child     │  │  (child     │         │       │
│  │   process)  │  │   process)  │  │   process)  │         │       │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘         │       │
└─────────┼────────────────┼────────────────┼─────────────────────────┘
          │ stdin/stdout   │                │
          │ JSON           │                │
   ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
   │   MoonBit   │  │   MoonBit   │  │   MoonBit   │
   │  Worker 1   │  │  Worker 2   │  │  Worker N   │
   │  (native)   │  │  (native)   │  │  (native)   │
   └─────────────┘  └─────────────┘  └─────────────┘
```

---

## Directory Structure

```
pure-moonbit-cli/
├── zig_coordinator/              # NEW: Zig coordinator
│   ├── build.zig                 # Build configuration
│   ├── build.zig.zon             # Package dependencies
│   ├── src/
│   │   ├── main.zig              # Entry point
│   │   ├── cli.zig               # CLI argument parsing
│   │   ├── coordinator.zig       # Main orchestrator
│   │   ├── worker_pool.zig       # Worker process management
│   │   ├── worker.zig            # Single worker handling
│   │   ├── protocol.zig          # JSON-RPC protocol
│   │   ├── graph.zig             # Dependency graph
│   │   ├── watcher.zig           # File system watcher
│   │   ├── cache.zig             # Compilation cache
│   │   ├── discovery.zig         # File discovery (glob)
│   │   └── utils/
│   │       ├── json.zig          # JSON helpers
│   │       ├── hash.zig          # Content hashing
│   │       └── log.zig           # Logging
│   └── tests/
│       ├── protocol_test.zig
│       ├── graph_test.zig
│       └── ...
│
├── src/moonbit/                  # Existing MoonBit compiler
│   ├── compiler/
│   ├── worker/                   # Worker mode (already exists)
│   └── ...
│
└── ...
```

---

## Component Specifications

### 1. CLI Parser (`cli.zig`)

```zig
const std = @import("std");
const clap = @import("clap");

pub const Options = struct {
    // Compilation options
    target: Target = .es2020,
    module: ModuleKind = .esm,
    source_map: bool = false,
    declaration: bool = false,
    no_emit: bool = false,
    strict: bool = false,

    // Coordinator options
    parallel: u8 = 4,
    incremental: bool = true,
    watch: bool = false,
    debounce_ms: u32 = 100,

    // Paths
    out_dir: ?[]const u8 = null,
    root_dir: ?[]const u8 = null,
    files: []const []const u8 = &.{},

    pub const Target = enum {
        es5, es6, es2015, es2016, es2017, es2018, es2019, es2020, es2021, es2022, esnext,
    };

    pub const ModuleKind = enum { esm, commonjs };
};

pub fn parse(allocator: std.mem.Allocator) !Options {
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display help
        \\-w, --watch            Watch for file changes
        \\-p, --parallel <N>     Number of parallel workers (default: 4)
        \\--target <TARGET>      ECMAScript target version
        \\--module <MODULE>      Module system (esm, commonjs)
        \\--sourceMap            Generate source maps
        \\--declaration          Generate .d.ts files
        \\--noEmit               Don't emit output files
        \\--strict               Enable strict mode
        \\--outDir <DIR>         Output directory
        \\--incremental          Enable incremental compilation
        \\<FILES>...             Input files or directories
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, params, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report();
        return err;
    };
    defer res.deinit();

    return Options{
        .parallel = res.args.parallel orelse 4,
        .watch = res.args.watch != 0,
        .target = res.args.target orelse .es2020,
        .module = res.args.module orelse .esm,
        .source_map = res.args.sourceMap != 0,
        .declaration = res.args.declaration != 0,
        .no_emit = res.args.noEmit != 0,
        .strict = res.args.strict != 0,
        .out_dir = res.args.outDir,
        .incremental = res.args.incremental orelse true,
        .files = res.positionals,
    };
}
```

### 2. Worker Pool (`worker_pool.zig`)

```zig
const std = @import("std");
const Worker = @import("worker.zig").Worker;
const Protocol = @import("protocol.zig");

pub const WorkerPool = struct {
    allocator: std.mem.Allocator,
    workers: []Worker,
    available: std.atomic.Queue(*Worker),
    pending_requests: std.fifo.LinearFifo(Request, .Dynamic),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    shutdown: std.atomic.Value(bool),

    const Request = struct {
        id: u64,
        file_path: []const u8,
        content: []const u8,
        options: Protocol.CompileOptions,
        callback: *const fn (*const Protocol.Response) void,
    };

    pub fn init(allocator: std.mem.Allocator, worker_count: u8, worker_binary: []const u8) !WorkerPool {
        var workers = try allocator.alloc(Worker, worker_count);
        errdefer allocator.free(workers);

        for (workers, 0..) |*w, i| {
            w.* = try Worker.spawn(allocator, worker_binary, @intCast(i));
        }

        return WorkerPool{
            .allocator = allocator,
            .workers = workers,
            .available = std.atomic.Queue(*Worker).init(),
            .pending_requests = std.fifo.LinearFifo(Request, .Dynamic).init(allocator),
            .mutex = .{},
            .condition = .{},
            .shutdown = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *WorkerPool) void {
        self.shutdown.store(true, .seq_cst);

        for (self.workers) |*w| {
            w.sendShutdown() catch {};
            w.deinit();
        }

        self.allocator.free(self.workers);
        self.pending_requests.deinit();
    }

    /// Submit a compile request
    pub fn compile(self: *WorkerPool, request: Request) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.pending_requests.writeItem(request);
        self.condition.signal();
    }

    /// Get next available worker (blocks if none available)
    pub fn acquireWorker(self: *WorkerPool) ?*Worker {
        while (true) {
            if (self.shutdown.load(.seq_cst)) return null;

            if (self.available.pop()) |node| {
                return node.data;
            }

            self.mutex.lock();
            self.condition.wait(&self.mutex);
            self.mutex.unlock();
        }
    }

    /// Return worker to the pool
    pub fn releaseWorker(self: *WorkerPool, worker: *Worker) void {
        self.available.push(&worker.node);
        self.condition.signal();
    }

    /// Process all pending requests (called by worker threads)
    pub fn processRequests(self: *WorkerPool) void {
        while (!self.shutdown.load(.seq_cst)) {
            const worker = self.acquireWorker() orelse break;
            defer self.releaseWorker(worker);

            self.mutex.lock();
            const request = self.pending_requests.readItem();
            self.mutex.unlock();

            if (request) |req| {
                const response = worker.compile(req.file_path, req.content, req.options) catch |err| {
                    std.log.err("Worker compile error: {}", .{err});
                    continue;
                };
                req.callback(&response);
            } else {
                // No pending requests, wait
                self.mutex.lock();
                self.condition.wait(&self.mutex);
                self.mutex.unlock();
            }
        }
    }
};
```

### 3. Single Worker (`worker.zig`)

```zig
const std = @import("std");
const Protocol = @import("protocol.zig");

pub const Worker = struct {
    id: u8,
    process: std.process.Child,
    stdin: std.fs.File,
    stdout: std.fs.File,
    reader: std.io.BufferedReader(4096, std.fs.File.Reader),
    allocator: std.mem.Allocator,
    request_id: std.atomic.Value(u64),
    pending: std.AutoHashMap(u64, *PendingRequest),
    mutex: std.Thread.Mutex,

    const PendingRequest = struct {
        response: ?Protocol.Response,
        completed: std.Thread.ResetEvent,
    };

    pub fn spawn(allocator: std.mem.Allocator, binary_path: []const u8, id: u8) !Worker {
        var process = std.process.Child.init(.{
            .argv = &.{ binary_path, "--worker" },
            .stdin_behavior = .Pipe,
            .stdout_behavior = .Pipe,
            .stderr_behavior = .Inherit,
        }, allocator);

        try process.spawn();

        return Worker{
            .id = id,
            .process = process,
            .stdin = process.stdin.?,
            .stdout = process.stdout.?,
            .reader = std.io.bufferedReader(process.stdout.?.reader()),
            .allocator = allocator,
            .request_id = std.atomic.Value(u64).init(0),
            .pending = std.AutoHashMap(u64, *PendingRequest).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *Worker) void {
        _ = self.process.kill() catch {};
        _ = self.process.wait() catch {};
        self.pending.deinit();
    }

    pub fn compile(
        self: *Worker,
        file_path: []const u8,
        content: []const u8,
        options: Protocol.CompileOptions,
    ) !Protocol.Response {
        const id = self.request_id.fetchAdd(1, .seq_cst);

        // Create pending request
        var pending = PendingRequest{
            .response = null,
            .completed = std.Thread.ResetEvent{},
        };

        {
            self.mutex.lock();
            defer self.mutex.unlock();
            try self.pending.put(id, &pending);
        }
        defer {
            self.mutex.lock();
            defer self.mutex.unlock();
            _ = self.pending.remove(id);
        }

        // Send request
        const request = Protocol.CompileRequest{
            .id = id,
            .file_path = file_path,
            .content = content,
            .options = options,
        };

        var json_buffer: [64 * 1024]u8 = undefined;
        const json = try Protocol.encodeRequest(request, &json_buffer);
        try self.stdin.writeAll(json);
        try self.stdin.writeAll("\n");

        // Wait for response
        pending.completed.wait();

        return pending.response orelse error.NoResponse;
    }

    /// Read responses from stdout (run in separate thread)
    pub fn readResponses(self: *Worker) !void {
        var line_buffer: [1024 * 1024]u8 = undefined;

        while (true) {
            const line = self.reader.reader().readUntilDelimiter(&line_buffer, '\n') catch |err| {
                if (err == error.EndOfStream) break;
                return err;
            };

            const response = try Protocol.decodeResponse(line);

            self.mutex.lock();
            defer self.mutex.unlock();

            if (self.pending.get(response.id)) |pending| {
                pending.response = response;
                pending.completed.set();
            }
        }
    }

    pub fn sendShutdown(self: *Worker) !void {
        const shutdown_msg =
            \\{"jsonrpc":"2.0","id":0,"method":"shutdown","params":{}}
        ;
        try self.stdin.writeAll(shutdown_msg);
        try self.stdin.writeAll("\n");
    }

    pub fn ping(self: *Worker) !bool {
        const ping_msg =
            \\{"jsonrpc":"2.0","id":0,"method":"ping","params":{}}
        ;
        try self.stdin.writeAll(ping_msg);
        try self.stdin.writeAll("\n");

        // Read response with timeout
        var buf: [256]u8 = undefined;
        const response = self.reader.reader().readUntilDelimiter(&buf, '\n') catch return false;

        return std.mem.indexOf(u8, response, "\"pong\"") != null;
    }
};
```

### 4. Dependency Graph (`graph.zig`)

```zig
const std = @import("std");

pub const DependencyGraph = struct {
    allocator: std.mem.Allocator,

    /// Forward edges: file -> [dependencies]
    forward: std.StringHashMap(std.ArrayList([]const u8)),

    /// Reverse edges: file -> [dependents]
    reverse: std.StringHashMap(std.ArrayList([]const u8)),

    /// All known files
    files: std.StringHashMap(void),

    mutex: std.Thread.RwLock,

    pub fn init(allocator: std.mem.Allocator) DependencyGraph {
        return .{
            .allocator = allocator,
            .forward = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .reverse = std.StringHashMap(std.ArrayList([]const u8)).init(allocator),
            .files = std.StringHashMap(void).init(allocator),
            .mutex = .{},
        };
    }

    pub fn deinit(self: *DependencyGraph) void {
        var it = self.forward.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.forward.deinit();

        it = self.reverse.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.reverse.deinit();

        self.files.deinit();
    }

    /// Add a file and its dependencies
    pub fn add(self: *DependencyGraph, file: []const u8, dependencies: []const []const u8) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Add to files set
        try self.files.put(file, {});

        // Store forward dependencies
        var deps_list = self.forward.get(file) orelse std.ArrayList([]const u8).init(self.allocator);
        deps_list.clearRetainingCapacity();
        for (dependencies) |dep| {
            try deps_list.append(try self.allocator.dupe(u8, dep));

            // Add reverse edge
            var rev_list = self.reverse.get(dep) orelse std.ArrayList([]const u8).init(self.allocator);
            try rev_list.append(try self.allocator.dupe(u8, file));
            try self.reverse.put(dep, rev_list);
        }
        try self.forward.put(file, deps_list);
    }

    /// Get direct dependencies of a file
    pub fn getDependencies(self: *DependencyGraph, file: []const u8) []const []const u8 {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        if (self.forward.get(file)) |deps| {
            return deps.items;
        }
        return &.{};
    }

    /// Get files that depend on the given file
    pub fn getDependents(self: *DependencyGraph, file: []const u8) []const []const u8 {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        if (self.reverse.get(file)) |deps| {
            return deps.items;
        }
        return &.{};
    }

    /// Get all transitive dependents (files affected by a change)
    pub fn getAffectedFiles(self: *DependencyGraph, changed_files: []const []const u8) ![]const []const u8 {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        var visited = std.StringHashMap(void).init(self.allocator);
        defer visited.deinit();

        var result = std.ArrayList([]const u8).init(self.allocator);

        for (changed_files) |file| {
            try self.collectDependentsRecursive(file, &visited, &result);
        }

        return result.toOwnedSlice();
    }

    fn collectDependentsRecursive(
        self: *DependencyGraph,
        file: []const u8,
        visited: *std.StringHashMap(void),
        result: *std.ArrayList([]const u8),
    ) !void {
        if (visited.contains(file)) return;
        try visited.put(file, {});
        try result.append(file);

        for (self.getDependents(file)) |dependent| {
            try self.collectDependentsRecursive(dependent, visited, result);
        }
    }

    /// Compute topological levels for parallel compilation
    /// Returns list of levels, where files in each level can be compiled in parallel
    pub fn topologicalLevels(self: *DependencyGraph, files: []const []const u8) ![]const []const []const u8 {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        var file_set = std.StringHashMap(void).init(self.allocator);
        defer file_set.deinit();
        for (files) |f| try file_set.put(f, {});

        // Build in-degree map
        var in_degree = std.StringHashMap(usize).init(self.allocator);
        defer in_degree.deinit();

        for (files) |file| {
            var count: usize = 0;
            for (self.getDependencies(file)) |dep| {
                if (file_set.contains(dep)) count += 1;
            }
            try in_degree.put(file, count);
        }

        var levels = std.ArrayList([]const []const u8).init(self.allocator);
        var remaining = files.len;

        while (remaining > 0) {
            var level = std.ArrayList([]const u8).init(self.allocator);

            // Find all files with in-degree 0
            var it = in_degree.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.* == 0) {
                    try level.append(entry.key_ptr.*);
                }
            }

            if (level.items.len == 0) {
                // Cycle detected - add remaining as single level
                it = in_degree.iterator();
                while (it.next()) |entry| {
                    if (entry.value_ptr.* > 0) {
                        try level.append(entry.key_ptr.*);
                    }
                }
                try levels.append(level.toOwnedSlice());
                break;
            }

            // Remove processed files and update in-degrees
            for (level.items) |file| {
                _ = in_degree.remove(file);
                remaining -= 1;

                // Decrement in-degree of files that depend on this one
                for (self.getDependents(file)) |dependent| {
                    if (in_degree.getPtr(dependent)) |deg| {
                        if (deg.* > 0) deg.* -= 1;
                    }
                }
            }

            try levels.append(level.toOwnedSlice());
        }

        return levels.toOwnedSlice();
    }

    pub fn clear(self: *DependencyGraph) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.forward.clearRetainingCapacity();
        self.reverse.clearRetainingCapacity();
        self.files.clearRetainingCapacity();
    }

    pub fn stats(self: *DependencyGraph) struct { files: usize, edges: usize } {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        var edges: usize = 0;
        var it = self.forward.iterator();
        while (it.next()) |entry| {
            edges += entry.value_ptr.items.len;
        }

        return .{ .files = self.files.count(), .edges = edges };
    }
};
```

### 5. File Watcher (`watcher.zig`)

```zig
const std = @import("std");
const builtin = @import("builtin");

pub const FileWatcher = struct {
    allocator: std.mem.Allocator,
    fd: std.posix.fd_t,
    watched_paths: std.StringHashMap(WatchInfo),
    callback: *const fn (event: Event) void,
    thread: ?std.Thread,
    running: std.atomic.Value(bool),

    const WatchInfo = switch (builtin.os.tag) {
        .macos, .freebsd, .netbsd, .openbsd => struct {
            fd: std.posix.fd_t,
        },
        .linux => struct {
            wd: i32,
        },
        else => @compileError("Unsupported OS for file watching"),
    };

    pub const Event = struct {
        path: []const u8,
        kind: EventKind,
    };

    pub const EventKind = enum {
        modified,
        created,
        deleted,
        renamed,
    };

    pub fn init(allocator: std.mem.Allocator, callback: *const fn (Event) void) !FileWatcher {
        const fd = switch (builtin.os.tag) {
            .macos, .freebsd, .netbsd, .openbsd => try std.posix.kqueue(),
            .linux => try std.posix.inotify_init1(0),
            else => @compileError("Unsupported OS"),
        };

        return FileWatcher{
            .allocator = allocator,
            .fd = fd,
            .watched_paths = std.StringHashMap(WatchInfo).init(allocator),
            .callback = callback,
            .thread = null,
            .running = std.atomic.Value(bool).init(false),
        };
    }

    pub fn deinit(self: *FileWatcher) void {
        self.stop();
        std.posix.close(self.fd);

        // Close watched file descriptors (kqueue)
        if (builtin.os.tag == .macos) {
            var it = self.watched_paths.iterator();
            while (it.next()) |entry| {
                std.posix.close(entry.value_ptr.fd);
            }
        }

        self.watched_paths.deinit();
    }

    pub fn addPath(self: *FileWatcher, path: []const u8) !void {
        switch (builtin.os.tag) {
            .macos, .freebsd, .netbsd, .openbsd => {
                const file_fd = try std.posix.open(path, .{ .ACCMODE = .RDONLY }, 0);

                var event = std.posix.Kevent{
                    .ident = @intCast(file_fd),
                    .filter = std.posix.system.EVFILT.VNODE,
                    .flags = std.posix.system.EV.ADD | std.posix.system.EV.CLEAR,
                    .fflags = std.posix.system.NOTE.WRITE |
                              std.posix.system.NOTE.DELETE |
                              std.posix.system.NOTE.RENAME,
                    .data = 0,
                    .udata = @ptrToInt(path.ptr),
                };

                _ = try std.posix.kevent(self.fd, &.{event}, &.{}, null);

                try self.watched_paths.put(path, .{ .fd = file_fd });
            },
            .linux => {
                const wd = try std.posix.inotify_add_watch(
                    self.fd,
                    path,
                    std.posix.system.IN.MODIFY |
                    std.posix.system.IN.DELETE |
                    std.posix.system.IN.CREATE |
                    std.posix.system.IN.MOVE,
                );

                try self.watched_paths.put(path, .{ .wd = wd });
            },
            else => @compileError("Unsupported OS"),
        }
    }

    pub fn removePath(self: *FileWatcher, path: []const u8) void {
        if (self.watched_paths.fetchRemove(path)) |entry| {
            switch (builtin.os.tag) {
                .macos, .freebsd, .netbsd, .openbsd => {
                    std.posix.close(entry.value.fd);
                },
                .linux => {
                    _ = std.posix.inotify_rm_watch(self.fd, entry.value.wd) catch {};
                },
                else => {},
            }
        }
    }

    pub fn start(self: *FileWatcher) !void {
        if (self.running.load(.seq_cst)) return;

        self.running.store(true, .seq_cst);
        self.thread = try std.Thread.spawn(.{}, watchLoop, .{self});
    }

    pub fn stop(self: *FileWatcher) void {
        if (!self.running.load(.seq_cst)) return;

        self.running.store(false, .seq_cst);

        if (self.thread) |t| {
            t.join();
            self.thread = null;
        }
    }

    fn watchLoop(self: *FileWatcher) void {
        while (self.running.load(.seq_cst)) {
            switch (builtin.os.tag) {
                .macos, .freebsd, .netbsd, .openbsd => {
                    self.processKqueueEvents();
                },
                .linux => {
                    self.processInotifyEvents();
                },
                else => {},
            }
        }
    }

    fn processKqueueEvents(self: *FileWatcher) void {
        var events: [16]std.posix.Kevent = undefined;
        const timeout = std.posix.timespec{ .tv_sec = 0, .tv_nsec = 100_000_000 }; // 100ms

        const n = std.posix.kevent(self.fd, &.{}, &events, &timeout) catch return;

        for (events[0..n]) |event| {
            const path: []const u8 = @ptrFromInt(event.udata);

            const kind: EventKind = if (event.fflags & std.posix.system.NOTE.DELETE != 0)
                .deleted
            else if (event.fflags & std.posix.system.NOTE.RENAME != 0)
                .renamed
            else
                .modified;

            self.callback(.{ .path = path, .kind = kind });
        }
    }

    fn processInotifyEvents(self: *FileWatcher) void {
        var buf: [4096]u8 align(@alignOf(std.posix.system.inotify_event)) = undefined;

        const len = std.posix.read(self.fd, &buf) catch return;
        if (len == 0) return;

        var offset: usize = 0;
        while (offset < len) {
            const event: *const std.posix.system.inotify_event = @ptrCast(&buf[offset]);
            offset += @sizeOf(std.posix.system.inotify_event) + event.len;

            // Find path from watch descriptor
            var it = self.watched_paths.iterator();
            while (it.next()) |entry| {
                if (entry.value_ptr.wd == event.wd) {
                    const kind: EventKind =
                        if (event.mask & std.posix.system.IN.DELETE != 0) .deleted
                        else if (event.mask & std.posix.system.IN.CREATE != 0) .created
                        else if (event.mask & std.posix.system.IN.MOVE != 0) .renamed
                        else .modified;

                    self.callback(.{ .path = entry.key_ptr.*, .kind = kind });
                    break;
                }
            }
        }
    }
};
```

### 6. Protocol Handler (`protocol.zig`)

```zig
const std = @import("std");

pub const CompileRequest = struct {
    jsonrpc: []const u8 = "2.0",
    id: u64,
    method: []const u8 = "compile",
    params: struct {
        file: []const u8,
        content: ?[]const u8 = null,
        options: CompileOptions = .{},
        imported_types: ?[]const u8 = null, // JSON string of external types
    },
};

pub const CompileOptions = struct {
    target: []const u8 = "es2020",
    module: []const u8 = "esm",
    source_map: bool = false,
    declaration: bool = false,
    no_emit: bool = false,
    strict: bool = false,
    always_strict: bool = false,
    es_module_interop: bool = true,
};

pub const CompileResponse = struct {
    jsonrpc: []const u8,
    id: u64,
    result: ?Result = null,
    @"error": ?Error = null,

    pub const Result = struct {
        success: bool,
        diagnostics: []const Diagnostic,
        exports: ?std.json.Value = null,
        js: ?[]const u8 = null,
        source_map: ?[]const u8 = null,
        declaration: ?[]const u8 = null,
        compile_time_ms: ?u64 = null,
    };

    pub const Error = struct {
        code: i32,
        message: []const u8,
    };
};

pub const Diagnostic = struct {
    file: []const u8,
    line: u32,
    column: u32,
    end_line: ?u32 = null,
    end_column: ?u32 = null,
    code: []const u8,
    category: Category,
    message: []const u8,

    pub const Category = enum {
        @"error",
        warning,
        suggestion,
        message,
    };
};

pub fn encodeRequest(request: CompileRequest, buffer: []u8) ![]u8 {
    var stream = std.io.fixedBufferStream(buffer);
    try std.json.stringify(request, .{}, stream.writer());
    return stream.getWritten();
}

pub fn decodeResponse(json: []const u8) !CompileResponse {
    var parsed = try std.json.parseFromSlice(CompileResponse, std.heap.page_allocator, json, .{});
    return parsed.value;
}

// Encode check request (matches current Elixir protocol)
pub fn encodeCheckRequest(
    allocator: std.mem.Allocator,
    id: u64,
    file: []const u8,
    content: ?[]const u8,
    imported_types: ?[]const u8,
) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    var writer = buffer.writer();

    try writer.print(
        \\{{"jsonrpc":"2.0","id":{},"method":"check","params":{{"file":"{}",
    , .{ id, std.json.encodeJsonString(file) });

    if (content) |c| {
        try writer.print("\"content\":{},", .{std.json.encodeJsonString(c)});
    }

    if (imported_types) |it| {
        try writer.print("\"imported_types\":{}", .{it});
    } else {
        try writer.writeAll("\"imported_types\":{}");
    }

    try writer.writeAll("}}");

    return buffer.toOwnedSlice();
}

// Encode parse request for import extraction
pub fn encodeParseRequest(
    allocator: std.mem.Allocator,
    id: u64,
    file: []const u8,
    content: ?[]const u8,
) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    var writer = buffer.writer();

    try writer.print(
        \\{{"jsonrpc":"2.0","id":{},"method":"parse","params":{{"file":"{}"
    , .{ id, std.json.encodeJsonString(file) });

    if (content) |c| {
        try writer.print(",\"content\":{}", .{std.json.encodeJsonString(c)});
    }

    try writer.writeAll("}}");

    return buffer.toOwnedSlice();
}

// Encode extract_imports request
pub fn encodeExtractImportsRequest(
    allocator: std.mem.Allocator,
    id: u64,
    file: []const u8,
    content: ?[]const u8,
) ![]u8 {
    var buffer = std.ArrayList(u8).init(allocator);
    var writer = buffer.writer();

    try writer.print(
        \\{{"jsonrpc":"2.0","id":{},"method":"extract_imports","params":{{"file":"{}"
    , .{ id, std.json.encodeJsonString(file) });

    if (content) |c| {
        try writer.print(",\"content\":{}", .{std.json.encodeJsonString(c)});
    }

    try writer.writeAll("}}");

    return buffer.toOwnedSlice();
}
```

### 7. Cache (`cache.zig`)

```zig
const std = @import("std");

pub const CompilationCache = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(CacheEntry),
    mutex: std.Thread.RwLock,
    max_size_bytes: usize,
    current_size_bytes: usize,
    hits: std.atomic.Value(u64),
    misses: std.atomic.Value(u64),

    pub const CacheEntry = struct {
        js: []const u8,
        source_map: ?[]const u8,
        declaration: ?[]const u8,
        exports_json: ?[]const u8,
        created_at: i64,
    };

    pub const CacheKey = struct {
        file_path: []const u8,
        content_hash: [32]u8,
        options_hash: [32]u8,

        pub fn hash(self: CacheKey) u64 {
            var hasher = std.hash.Wyhash.init(0);
            hasher.update(self.file_path);
            hasher.update(&self.content_hash);
            hasher.update(&self.options_hash);
            return hasher.final();
        }

        pub fn toString(self: CacheKey, allocator: std.mem.Allocator) ![]u8 {
            return std.fmt.allocPrint(allocator, "{s}:{x}:{x}", .{
                self.file_path,
                self.content_hash,
                self.options_hash,
            });
        }
    };

    pub fn init(allocator: std.mem.Allocator, max_size_mb: usize) CompilationCache {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(CacheEntry).init(allocator),
            .mutex = .{},
            .max_size_bytes = max_size_mb * 1024 * 1024,
            .current_size_bytes = 0,
            .hits = std.atomic.Value(u64).init(0),
            .misses = std.atomic.Value(u64).init(0),
        };
    }

    pub fn deinit(self: *CompilationCache) void {
        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.freeEntry(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.entries.deinit();
    }

    pub fn get(self: *CompilationCache, key: CacheKey) ?CacheEntry {
        const key_str = key.toString(self.allocator) catch return null;
        defer self.allocator.free(key_str);

        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        if (self.entries.get(key_str)) |entry| {
            _ = self.hits.fetchAdd(1, .monotonic);
            return entry;
        }

        _ = self.misses.fetchAdd(1, .monotonic);
        return null;
    }

    pub fn put(self: *CompilationCache, key: CacheKey, entry: CacheEntry) !void {
        const key_str = try key.toString(self.allocator);
        errdefer self.allocator.free(key_str);

        const entry_size = self.entrySize(entry);

        self.mutex.lock();
        defer self.mutex.unlock();

        // Evict if necessary
        while (self.current_size_bytes + entry_size > self.max_size_bytes) {
            if (!self.evictOldest()) break;
        }

        // Remove existing entry if present
        if (self.entries.fetchRemove(key_str)) |old| {
            self.current_size_bytes -= self.entrySize(old.value);
            self.freeEntry(old.value);
            self.allocator.free(old.key);
        }

        // Copy entry data
        const new_entry = CacheEntry{
            .js = try self.allocator.dupe(u8, entry.js),
            .source_map = if (entry.source_map) |sm| try self.allocator.dupe(u8, sm) else null,
            .declaration = if (entry.declaration) |d| try self.allocator.dupe(u8, d) else null,
            .exports_json = if (entry.exports_json) |e| try self.allocator.dupe(u8, e) else null,
            .created_at = std.time.timestamp(),
        };

        try self.entries.put(key_str, new_entry);
        self.current_size_bytes += entry_size;
    }

    pub fn invalidate(self: *CompilationCache, file_path: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        // Remove all entries for this file (any content/options hash)
        var keys_to_remove = std.ArrayList([]const u8).init(self.allocator);
        defer keys_to_remove.deinit();

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (std.mem.startsWith(u8, entry.key_ptr.*, file_path)) {
                keys_to_remove.append(entry.key_ptr.*) catch continue;
            }
        }

        for (keys_to_remove.items) |key| {
            if (self.entries.fetchRemove(key)) |old| {
                self.current_size_bytes -= self.entrySize(old.value);
                self.freeEntry(old.value);
            }
        }
    }

    pub fn clear(self: *CompilationCache) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            self.freeEntry(entry.value_ptr.*);
            self.allocator.free(entry.key_ptr.*);
        }
        self.entries.clearRetainingCapacity();
        self.current_size_bytes = 0;
    }

    pub fn stats(self: *CompilationCache) struct {
        entries: usize,
        size_mb: f64,
        hits: u64,
        misses: u64,
        hit_rate: f64,
    } {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        const hits = self.hits.load(.monotonic);
        const misses = self.misses.load(.monotonic);
        const total = hits + misses;

        return .{
            .entries = self.entries.count(),
            .size_mb = @as(f64, @floatFromInt(self.current_size_bytes)) / (1024 * 1024),
            .hits = hits,
            .misses = misses,
            .hit_rate = if (total > 0) @as(f64, @floatFromInt(hits)) / @as(f64, @floatFromInt(total)) else 0,
        };
    }

    fn entrySize(self: *CompilationCache, entry: CacheEntry) usize {
        _ = self;
        var size = entry.js.len;
        if (entry.source_map) |sm| size += sm.len;
        if (entry.declaration) |d| size += d.len;
        if (entry.exports_json) |e| size += e.len;
        return size;
    }

    fn freeEntry(self: *CompilationCache, entry: CacheEntry) void {
        self.allocator.free(entry.js);
        if (entry.source_map) |sm| self.allocator.free(sm);
        if (entry.declaration) |d| self.allocator.free(d);
        if (entry.exports_json) |e| self.allocator.free(e);
    }

    fn evictOldest(self: *CompilationCache) bool {
        var oldest_key: ?[]const u8 = null;
        var oldest_time: i64 = std.math.maxInt(i64);

        var it = self.entries.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.created_at < oldest_time) {
                oldest_time = entry.value_ptr.created_at;
                oldest_key = entry.key_ptr.*;
            }
        }

        if (oldest_key) |key| {
            if (self.entries.fetchRemove(key)) |old| {
                self.current_size_bytes -= self.entrySize(old.value);
                self.freeEntry(old.value);
                return true;
            }
        }

        return false;
    }
};

pub fn hashContent(content: []const u8) [32]u8 {
    return std.crypto.hash.sha2.Sha256.hash(content, .{});
}

pub fn hashFile(path: []const u8) ![32]u8 {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();

    var hasher = std.crypto.hash.sha2.Sha256.init(.{});

    var buf: [4096]u8 = undefined;
    while (true) {
        const n = try file.read(&buf);
        if (n == 0) break;
        hasher.update(buf[0..n]);
    }

    return hasher.finalResult();
}
```

### 8. Main Coordinator (`coordinator.zig`)

```zig
const std = @import("std");
const Cli = @import("cli.zig");
const WorkerPool = @import("worker_pool.zig").WorkerPool;
const DependencyGraph = @import("graph.zig").DependencyGraph;
const FileWatcher = @import("watcher.zig").FileWatcher;
const Cache = @import("cache.zig").CompilationCache;
const Protocol = @import("protocol.zig");

pub const Coordinator = struct {
    allocator: std.mem.Allocator,
    options: Cli.Options,
    worker_pool: WorkerPool,
    graph: DependencyGraph,
    watcher: ?FileWatcher,
    cache: Cache,

    pub fn init(allocator: std.mem.Allocator, options: Cli.Options) !Coordinator {
        const worker_binary = options.worker_binary orelse "moonbit-worker";

        var coordinator = Coordinator{
            .allocator = allocator,
            .options = options,
            .worker_pool = try WorkerPool.init(allocator, options.parallel, worker_binary),
            .graph = DependencyGraph.init(allocator),
            .watcher = null,
            .cache = Cache.init(allocator, 100), // 100 MB cache
        };

        if (options.watch) {
            coordinator.watcher = try FileWatcher.init(allocator, handleFileChange);
        }

        return coordinator;
    }

    pub fn deinit(self: *Coordinator) void {
        self.worker_pool.deinit();
        self.graph.deinit();
        if (self.watcher) |*w| w.deinit();
        self.cache.deinit();
    }

    /// Run the full compilation pipeline
    pub fn run(self: *Coordinator) !CompilationResult {
        const start_time = std.time.milliTimestamp();

        // 1. Discover files
        const files = try self.discoverFiles();
        defer self.allocator.free(files);

        std.log.info("Discovered {} files", .{files.len});

        // 2. Build dependency graph (extract imports)
        try self.buildDependencyGraph(files);

        const graph_stats = self.graph.stats();
        std.log.info("Dependency graph: {} files, {} edges", .{ graph_stats.files, graph_stats.edges });

        // 3. Get topological levels for parallel compilation
        const levels = try self.graph.topologicalLevels(files);
        defer self.allocator.free(levels);

        std.log.info("Compiling in {} levels", .{levels.len});

        // 4. Compile level by level
        var all_diagnostics = std.ArrayList(Protocol.Diagnostic).init(self.allocator);

        for (levels, 0..) |level, i| {
            std.log.info("Level {}: {} files", .{ i + 1, level.len });
            const level_diagnostics = try self.compileLevel(level);
            try all_diagnostics.appendSlice(level_diagnostics);
        }

        const duration_ms = std.time.milliTimestamp() - start_time;

        // 5. Start watch mode if enabled
        if (self.options.watch) {
            try self.startWatching(files);

            // Wait for interrupt
            std.log.info("Watching for changes... (Ctrl+C to stop)", .{});
            // Block until interrupted
        }

        return CompilationResult{
            .success = !hasErrors(all_diagnostics.items),
            .diagnostics = all_diagnostics.toOwnedSlice(),
            .files_compiled = files.len,
            .duration_ms = @intCast(duration_ms),
        };
    }

    /// Compile a single level (files can be compiled in parallel)
    fn compileLevel(self: *Coordinator, files: []const []const u8) ![]Protocol.Diagnostic {
        var all_diagnostics = std.ArrayList(Protocol.Diagnostic).init(self.allocator);
        var wg = std.Thread.WaitGroup{};
        var mutex = std.Thread.Mutex{};

        for (files) |file| {
            wg.add(1);

            _ = try std.Thread.spawn(.{}, struct {
                fn compile(
                    coord: *Coordinator,
                    file_path: []const u8,
                    diagnostics: *std.ArrayList(Protocol.Diagnostic),
                    m: *std.Thread.Mutex,
                    wait_group: *std.Thread.WaitGroup,
                ) void {
                    defer wait_group.done();

                    const result = coord.compileFile(file_path) catch |err| {
                        std.log.err("Failed to compile {s}: {}", .{ file_path, err });
                        return;
                    };

                    m.lock();
                    defer m.unlock();
                    diagnostics.appendSlice(result.diagnostics) catch {};
                }
            }.compile, .{ self, file, &all_diagnostics, &mutex, &wg });
        }

        wg.wait();

        return all_diagnostics.toOwnedSlice();
    }

    /// Compile a single file
    fn compileFile(self: *Coordinator, file_path: []const u8) !Protocol.CompileResponse.Result {
        // Check cache first
        const content = try std.fs.cwd().readFileAlloc(self.allocator, file_path, 10 * 1024 * 1024);
        defer self.allocator.free(content);

        const cache_key = Cache.CacheKey{
            .file_path = file_path,
            .content_hash = Cache.hashContent(content),
            .options_hash = self.hashOptions(),
        };

        if (self.cache.get(cache_key)) |cached| {
            // Return cached result (no diagnostics stored, so empty)
            return Protocol.CompileResponse.Result{
                .success = true,
                .diagnostics = &.{},
                .js = cached.js,
                .source_map = cached.source_map,
                .declaration = cached.declaration,
            };
        }

        // Get imported types from dependencies
        const imported_types = try self.getImportedTypes(file_path);
        defer if (imported_types) |it| self.allocator.free(it);

        // Compile via worker
        const worker = self.worker_pool.acquireWorker() orelse return error.NoWorkerAvailable;
        defer self.worker_pool.releaseWorker(worker);

        const response = try worker.compile(file_path, content, .{
            .target = @tagName(self.options.target),
            .module = @tagName(self.options.module),
            .source_map = self.options.source_map,
            .declaration = self.options.declaration,
            .no_emit = self.options.no_emit,
            .strict = self.options.strict,
        });

        // Cache successful result
        if (response.result) |result| {
            if (result.success) {
                try self.cache.put(cache_key, .{
                    .js = result.js orelse "",
                    .source_map = result.source_map,
                    .declaration = result.declaration,
                    .exports_json = null, // TODO: serialize exports
                    .created_at = std.time.timestamp(),
                });
            }
            return result;
        }

        return error.CompilationFailed;
    }

    fn discoverFiles(self: *Coordinator) ![]const []const u8 {
        var files = std.ArrayList([]const u8).init(self.allocator);

        for (self.options.files) |pattern| {
            // Check if it's a directory
            const stat = std.fs.cwd().statFile(pattern) catch {
                // Treat as glob pattern
                try self.globFiles(pattern, &files);
                continue;
            };

            if (stat.kind == .directory) {
                // Recursively find .ts files
                try self.walkDirectory(pattern, &files);
            } else {
                try files.append(try self.allocator.dupe(u8, pattern));
            }
        }

        return files.toOwnedSlice();
    }

    fn walkDirectory(self: *Coordinator, dir_path: []const u8, files: *std.ArrayList([]const u8)) !void {
        var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
        defer dir.close();

        var walker = dir.walk(self.allocator) catch return;
        defer walker.deinit();

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;

            // Check for .ts or .tsx extension
            if (std.mem.endsWith(u8, entry.path, ".ts") or
                std.mem.endsWith(u8, entry.path, ".tsx"))
            {
                // Skip node_modules
                if (std.mem.indexOf(u8, entry.path, "node_modules") != null) continue;

                const full_path = try std.fs.path.join(self.allocator, &.{ dir_path, entry.path });
                try files.append(full_path);
            }
        }
    }

    fn globFiles(self: *Coordinator, pattern: []const u8, files: *std.ArrayList([]const u8)) !void {
        // Simple glob implementation - expand ** and *
        _ = self;
        _ = pattern;
        _ = files;
        // TODO: Implement proper glob matching
    }

    fn buildDependencyGraph(self: *Coordinator, files: []const []const u8) !void {
        self.graph.clear();

        for (files) |file| {
            const imports = try self.extractImports(file);
            defer self.allocator.free(imports);

            const resolved = try self.resolveImports(file, imports);
            defer self.allocator.free(resolved);

            try self.graph.add(file, resolved);
        }
    }

    fn extractImports(self: *Coordinator, file_path: []const u8) ![]const []const u8 {
        const worker = self.worker_pool.acquireWorker() orelse return &.{};
        defer self.worker_pool.releaseWorker(worker);

        // Use worker's extract_imports command
        const content = std.fs.cwd().readFileAlloc(self.allocator, file_path, 10 * 1024 * 1024) catch return &.{};
        defer self.allocator.free(content);

        // Send extract_imports request to worker
        // Parse response and return import specifiers
        _ = content;

        // TODO: Implement actual extraction
        return &.{};
    }

    fn resolveImports(self: *Coordinator, source_file: []const u8, imports: []const []const u8) ![]const []const u8 {
        var resolved = std.ArrayList([]const u8).init(self.allocator);
        const source_dir = std.fs.path.dirname(source_file) orelse ".";

        for (imports) |import_spec| {
            // Handle relative imports
            if (std.mem.startsWith(u8, import_spec, ".")) {
                const base_path = try std.fs.path.join(self.allocator, &.{ source_dir, import_spec });
                defer self.allocator.free(base_path);

                // Try extensions: .ts, .tsx, /index.ts, /index.tsx
                const extensions = [_][]const u8{ ".ts", ".tsx", "/index.ts", "/index.tsx" };

                for (extensions) |ext| {
                    const full_path = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_path, ext });

                    if (std.fs.cwd().access(full_path, .{})) |_| {
                        try resolved.append(full_path);
                        break;
                    } else |_| {
                        self.allocator.free(full_path);
                    }
                }
            }
            // Skip node_modules imports for now
        }

        return resolved.toOwnedSlice();
    }

    fn getImportedTypes(self: *Coordinator, file_path: []const u8) !?[]const u8 {
        const deps = self.graph.getDependencies(file_path);
        if (deps.len == 0) return null;

        // Build JSON object of imported types from cache
        var types = std.json.ObjectMap.init(self.allocator);

        for (deps) |dep| {
            // Get exports from cache
            const content = std.fs.cwd().readFileAlloc(self.allocator, dep, 10 * 1024 * 1024) catch continue;
            defer self.allocator.free(content);

            const cache_key = Cache.CacheKey{
                .file_path = dep,
                .content_hash = Cache.hashContent(content),
                .options_hash = self.hashOptions(),
            };

            if (self.cache.get(cache_key)) |cached| {
                if (cached.exports_json) |exports| {
                    const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, exports, .{}) catch continue;
                    try types.put(dep, parsed.value);
                }
            }
        }

        // Serialize to JSON string
        var buffer = std.ArrayList(u8).init(self.allocator);
        try std.json.stringify(std.json.Value{ .object = types }, .{}, buffer.writer());

        return buffer.toOwnedSlice();
    }

    fn hashOptions(self: *Coordinator) [32]u8 {
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        hasher.update(@tagName(self.options.target));
        hasher.update(@tagName(self.options.module));
        hasher.update(if (self.options.source_map) "1" else "0");
        hasher.update(if (self.options.declaration) "1" else "0");
        hasher.update(if (self.options.strict) "1" else "0");
        return hasher.finalResult();
    }

    fn startWatching(self: *Coordinator, files: []const []const u8) !void {
        if (self.watcher) |*w| {
            for (files) |file| {
                try w.addPath(file);
            }
            try w.start();
        }
    }

    fn handleFileChange(event: FileWatcher.Event) void {
        std.log.info("File changed: {s} ({s})", .{ event.path, @tagName(event.kind) });
        // TODO: Trigger incremental recompilation
    }

    fn hasErrors(diagnostics: []const Protocol.Diagnostic) bool {
        for (diagnostics) |d| {
            if (d.category == .@"error") return true;
        }
        return false;
    }
};

pub const CompilationResult = struct {
    success: bool,
    diagnostics: []Protocol.Diagnostic,
    files_compiled: usize,
    duration_ms: u64,
};
```

### 9. Main Entry Point (`main.zig`)

```zig
const std = @import("std");
const Cli = @import("cli.zig");
const Coordinator = @import("coordinator.zig").Coordinator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse CLI arguments
    const options = Cli.parse(allocator) catch |err| {
        std.log.err("Failed to parse arguments: {}", .{err});
        std.process.exit(1);
    };

    // Initialize coordinator
    var coordinator = Coordinator.init(allocator, options) catch |err| {
        std.log.err("Failed to initialize coordinator: {}", .{err});
        std.process.exit(1);
    };
    defer coordinator.deinit();

    // Run compilation
    const result = coordinator.run() catch |err| {
        std.log.err("Compilation failed: {}", .{err});
        std.process.exit(1);
    };

    // Print diagnostics
    for (result.diagnostics) |d| {
        const prefix = switch (d.category) {
            .@"error" => "error",
            .warning => "warning",
            .suggestion => "suggestion",
            .message => "info",
        };

        std.debug.print("{s}({d},{d}): {s} {s}: {s}\n", .{
            d.file,
            d.line,
            d.column,
            prefix,
            d.code,
            d.message,
        });
    }

    // Print summary
    std.debug.print("\nCompiled {} files in {}ms\n", .{
        result.files_compiled,
        result.duration_ms,
    });

    if (!result.success) {
        std.process.exit(1);
    }
}
```

---

## Build Configuration

### `build.zig`

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "tsc-zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add clap dependency
    const clap = b.dependency("clap", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("clap", clap.module("clap"));

    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the TypeScript compiler");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

### `build.zig.zon`

```zig
.{
    .name = "zig-coordinator",
    .version = "0.1.0",
    .dependencies = .{
        .clap = .{
            .url = "https://github.com/Hejsil/zig-clap/archive/refs/tags/0.18.0.tar.gz",
            .hash = "...",
        },
    },
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

---

## Performance Comparison

| Metric | Elixir (Current) | Zig (Proposed) | Improvement |
|--------|------------------|----------------|-------------|
| **Binary size** | ~25 MB | ~1.5 MB | **17x smaller** |
| **Cold start** | ~30 ms | ~2 ms | **15x faster** |
| **Memory baseline** | ~80 MB | ~5 MB | **16x less** |
| **Per-request latency** | ~2-5 ms | ~50-200 μs | **10-25x faster** |
| **GC pauses** | Yes (BEAM) | None | **Deterministic** |
| **File watch latency** | ~100-500 ms (polling) | ~1-10 ms (native) | **50x faster** |

---

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Project structure and build.zig
- [ ] CLI argument parsing
- [ ] Worker process spawning
- [ ] JSON-RPC protocol implementation
- [ ] Basic single-file compilation

### Phase 2: Parallelization
- [ ] Worker pool implementation
- [ ] Thread-safe request queue
- [ ] Parallel file compilation

### Phase 3: Dependency Management
- [ ] Dependency graph implementation
- [ ] Topological sort for levels
- [ ] Import extraction via workers
- [ ] Import resolution

### Phase 4: Caching
- [ ] Content hash caching
- [ ] Type cache for exports
- [ ] Cache invalidation

### Phase 5: File Watching
- [ ] kqueue implementation (macOS)
- [ ] inotify implementation (Linux)
- [ ] Debouncing and batch processing
- [ ] Incremental recompilation

### Phase 6: Polish
- [ ] Error handling improvements
- [ ] Logging and diagnostics
- [ ] Cross-platform testing
- [ ] Documentation

---

## Migration Strategy

1. **Parallel development**: Build Zig coordinator alongside Elixir
2. **Compatibility**: Use same JSON-RPC protocol as Elixir
3. **Testing**: Run both coordinators against same test suite
4. **Gradual rollout**: CLI flag to select coordinator
5. **Deprecation**: Remove Elixir/Burrito once Zig is stable

---

## Conclusion

The Zig coordinator offers significant improvements in:
- **Distribution**: Single small binary, no runtime dependencies
- **Performance**: Faster startup, lower latency, less memory
- **Reliability**: No GC pauses, deterministic behavior
- **Developer experience**: Faster iteration with watch mode

The main trade-off is development complexity (Zig is lower-level than Elixir), but the resulting tool will be substantially more efficient and easier to distribute.

---

*Proposal Date: 2025-12-04*
*Status: Draft*
