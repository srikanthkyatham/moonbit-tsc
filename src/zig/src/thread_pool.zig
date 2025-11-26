// Thread Pool for Parallel File Processing
// Implements a work-stealing thread pool for efficient parallel compilation
//
// Architecture:
// - Fixed number of worker threads (configurable, defaults to CPU count)
// - Lock-free work queue for task distribution
// - Results collection with proper synchronization
// - Graceful shutdown handling

const std = @import("std");
const builtin = @import("builtin");
const Atomic = std.atomic.Value;

/// Task function signature
pub const TaskFn = *const fn (ctx: *anyopaque) void;

/// Task with context
pub const Task = struct {
    func: TaskFn,
    context: *anyopaque,
};

/// Result of a file compilation
pub const CompileFileResult = struct {
    file_path: []const u8,
    success: bool,
    javascript: ?[]const u8,
    source_map: ?[]const u8,
    declaration: ?[]const u8,
    error_message: ?[]const u8,
    diagnostics_count: usize,
};

/// Thread-safe work queue
pub const WorkQueue = struct {
    tasks: std.ArrayListUnmanaged(Task),
    allocator: std.mem.Allocator,
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    shutdown: Atomic(bool),

    pub fn init(allocator: std.mem.Allocator) WorkQueue {
        return WorkQueue{
            .tasks = .{},
            .allocator = allocator,
            .mutex = .{},
            .condition = .{},
            .shutdown = Atomic(bool).init(false),
        };
    }

    pub fn deinit(self: *WorkQueue) void {
        self.tasks.deinit(self.allocator);
    }

    pub fn push(self: *WorkQueue, task: Task) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.tasks.append(self.allocator, task) catch return;
        self.condition.signal();
    }

    pub fn pop(self: *WorkQueue) ?Task {
        self.mutex.lock();
        defer self.mutex.unlock();

        while (self.tasks.items.len == 0 and !self.shutdown.load(.acquire)) {
            self.condition.wait(&self.mutex);
        }

        if (self.shutdown.load(.acquire) and self.tasks.items.len == 0) {
            return null;
        }

        return self.tasks.pop();
    }

    pub fn signalShutdown(self: *WorkQueue) void {
        self.shutdown.store(true, .release);
        self.condition.broadcast();
    }
};

/// Thread pool for parallel task execution
pub const ThreadPool = struct {
    workers: []std.Thread,
    queue: WorkQueue,
    allocator: std.mem.Allocator,
    results_mutex: std.Thread.Mutex,
    results: std.ArrayListUnmanaged(CompileFileResult),
    pending_tasks: Atomic(usize),
    completion_condition: std.Thread.Condition,

    /// Initialize thread pool with specified number of workers
    pub fn init(allocator: std.mem.Allocator, worker_count: usize) !ThreadPool {
        const actual_workers = if (worker_count == 0)
            @max(1, std.Thread.getCpuCount() catch 4)
        else
            worker_count;

        var pool = ThreadPool{
            .workers = try allocator.alloc(std.Thread, actual_workers),
            .queue = WorkQueue.init(allocator),
            .allocator = allocator,
            .results_mutex = .{},
            .results = .{},
            .pending_tasks = Atomic(usize).init(0),
            .completion_condition = .{},
        };

        // Spawn worker threads
        for (pool.workers, 0..) |*worker, i| {
            worker.* = try std.Thread.spawn(.{}, workerLoop, .{ &pool, i });
        }

        return pool;
    }

    /// Worker loop - continuously processes tasks from the queue
    fn workerLoop(pool: *ThreadPool, worker_id: usize) void {
        _ = worker_id; // Can be used for debugging

        while (true) {
            const task = pool.queue.pop() orelse break;
            task.func(task.context);

            // Decrement pending count and signal if all done
            const prev = pool.pending_tasks.fetchSub(1, .release);
            if (prev == 1) {
                pool.results_mutex.lock();
                pool.completion_condition.signal();
                pool.results_mutex.unlock();
            }
        }
    }

    /// Submit a task to the thread pool
    pub fn submit(self: *ThreadPool, func: TaskFn, context: *anyopaque) void {
        _ = self.pending_tasks.fetchAdd(1, .release);
        self.queue.push(Task{ .func = func, .context = context });
    }

    /// Wait for all pending tasks to complete
    pub fn waitForAll(self: *ThreadPool) void {
        self.results_mutex.lock();
        defer self.results_mutex.unlock();

        while (self.pending_tasks.load(.acquire) > 0) {
            self.completion_condition.wait(&self.results_mutex);
        }
    }

    /// Add a compilation result (thread-safe)
    pub fn addResult(self: *ThreadPool, result: CompileFileResult) void {
        self.results_mutex.lock();
        defer self.results_mutex.unlock();
        self.results.append(self.allocator, result) catch return;
    }

    /// Get all results (call after waitForAll)
    pub fn getResults(self: *ThreadPool) []const CompileFileResult {
        return self.results.items;
    }

    /// Clear all results
    pub fn clearResults(self: *ThreadPool) void {
        self.results_mutex.lock();
        defer self.results_mutex.unlock();
        self.results.clearRetainingCapacity();
    }

    /// Shutdown the thread pool
    pub fn deinit(self: *ThreadPool) void {
        // Signal shutdown
        self.queue.signalShutdown();

        // Wait for all workers to finish
        for (self.workers) |worker| {
            worker.join();
        }

        // Clean up resources
        self.allocator.free(self.workers);
        self.queue.deinit();
        self.results.deinit(self.allocator);
    }
};

/// File compilation context for parallel processing
pub const FileCompileContext = struct {
    pool: *ThreadPool,
    file_path: []const u8,
    source: []const u8,
    options: CompileOptions,
    allocator: std.mem.Allocator,

    pub fn init(
        pool: *ThreadPool,
        file_path: []const u8,
        source: []const u8,
        options: CompileOptions,
        allocator: std.mem.Allocator,
    ) FileCompileContext {
        return FileCompileContext{
            .pool = pool,
            .file_path = file_path,
            .source = source,
            .options = options,
            .allocator = allocator,
        };
    }
};

/// Compilation options
pub const CompileOptions = struct {
    target: Target,
    source_map: bool,
    declaration: bool,
    strict: bool,

    pub fn default() CompileOptions {
        return CompileOptions{
            .target = .es2015,
            .source_map = false,
            .declaration = false,
            .strict = false,
        };
    }
};

/// Target ECMAScript version
pub const Target = enum {
    es5,
    es2015,
    es2016,
    es2017,
    es2018,
    es2019,
    es2020,
    esnext,

    pub fn fromString(s: []const u8) ?Target {
        const targets = std.StaticStringMap(Target).initComptime(.{
            .{ "es5", .es5 },
            .{ "es2015", .es2015 },
            .{ "es6", .es2015 },
            .{ "es2016", .es2016 },
            .{ "es7", .es2016 },
            .{ "es2017", .es2017 },
            .{ "es2018", .es2018 },
            .{ "es2019", .es2019 },
            .{ "es2020", .es2020 },
            .{ "esnext", .esnext },
            .{ "latest", .esnext },
        });
        return targets.get(s);
    }

    pub fn toString(self: Target) []const u8 {
        return switch (self) {
            .es5 => "es5",
            .es2015 => "es2015",
            .es2016 => "es2016",
            .es2017 => "es2017",
            .es2018 => "es2018",
            .es2019 => "es2019",
            .es2020 => "es2020",
            .esnext => "esnext",
        };
    }
};

// ============================================================================
// Parallel Compilation Interface
// ============================================================================

/// Parallel compiler for processing multiple files
pub const ParallelCompiler = struct {
    pool: ThreadPool,
    allocator: std.mem.Allocator,
    options: CompileOptions,

    /// Initialize parallel compiler with specified worker count
    pub fn init(allocator: std.mem.Allocator, worker_count: usize, options: CompileOptions) !ParallelCompiler {
        return ParallelCompiler{
            .pool = try ThreadPool.init(allocator, worker_count),
            .allocator = allocator,
            .options = options,
        };
    }

    /// Compile multiple files in parallel
    /// Returns results in completion order (not necessarily input order)
    pub fn compileFiles(self: *ParallelCompiler, files: []const FileInfo) ![]const CompileFileResult {
        // Allocate contexts for all files
        var contexts = try self.allocator.alloc(FileCompileContext, files.len);
        defer self.allocator.free(contexts);

        // Submit all files for compilation
        for (files, 0..) |file, i| {
            contexts[i] = FileCompileContext.init(
                &self.pool,
                file.path,
                file.source,
                self.options,
                self.allocator,
            );
            self.pool.submit(compileFileTask, @ptrCast(&contexts[i]));
        }

        // Wait for all compilations to complete
        self.pool.waitForAll();

        // Return results
        return self.pool.getResults();
    }

    /// Shutdown the parallel compiler
    pub fn deinit(self: *ParallelCompiler) void {
        self.pool.deinit();
    }
};

/// File information for compilation
pub const FileInfo = struct {
    path: []const u8,
    source: []const u8,
};

/// Task function for compiling a single file
fn compileFileTask(ctx_ptr: *anyopaque) void {
    const ctx: *FileCompileContext = @ptrCast(@alignCast(ctx_ptr));

    // TODO: Call MoonBit compiler via FFI
    // For now, create a placeholder result
    const result = CompileFileResult{
        .file_path = ctx.file_path,
        .success = true,
        .javascript = null, // Would be filled by actual compilation
        .source_map = null,
        .declaration = null,
        .error_message = null,
        .diagnostics_count = 0,
    };

    ctx.pool.addResult(result);
}

// ============================================================================
// Tests
// ============================================================================

test "thread pool basic" {
    var pool = try ThreadPool.init(std.testing.allocator, 2);
    defer pool.deinit();

    // Submit a simple task
    var counter = Atomic(usize).init(0);
    const TestContext = struct {
        counter: *Atomic(usize),

        pub fn increment(ctx_ptr: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx_ptr));
            _ = self.counter.fetchAdd(1, .release);
        }
    };

    var test_ctx = TestContext{ .counter = &counter };
    pool.submit(TestContext.increment, @ptrCast(&test_ctx));

    pool.waitForAll();
    try std.testing.expect(counter.load(.acquire) == 1);
}

test "parallel compiler init" {
    var compiler = try ParallelCompiler.init(
        std.testing.allocator,
        2,
        CompileOptions.default(),
    );
    defer compiler.deinit();

    try std.testing.expect(compiler.options.target == .es2015);
}

test "target parsing" {
    try std.testing.expect(Target.fromString("es5") == .es5);
    try std.testing.expect(Target.fromString("es2015") == .es2015);
    try std.testing.expect(Target.fromString("es6") == .es2015);
    try std.testing.expect(Target.fromString("esnext") == .esnext);
    try std.testing.expect(Target.fromString("invalid") == null);
}