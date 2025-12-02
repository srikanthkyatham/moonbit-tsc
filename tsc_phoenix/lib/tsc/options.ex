defmodule TSC.Options do
  @moduledoc """
  Option schemas for the TypeScript Compiler using NimbleOptions.

  Provides validated, documented options for:
  - Project checking (`check_project_schema/0`)
  - File checking (`check_file_schema/0`)
  - CLI worker (`cli_worker_schema/0`)
  - API requests (`api_check_schema/0`)
  """

  # ============================================================================
  # Check Project Options
  # ============================================================================

  @check_project_schema NimbleOptions.new!([
    incremental: [
      type: :boolean,
      default: true,
      doc: "Only check changed files based on file modification times"
    ],
    concurrency: [
      type: :pos_integer,
      default: 4,
      doc: "Maximum number of concurrent file checks per dependency level"
    ],
    use_dependency_order: [
      type: :boolean,
      default: false,
      doc: "Build dependency graph and check files in topological order"
    ],
    verbose: [
      type: :boolean,
      default: false,
      doc: "Enable verbose output during compilation"
    ],
    report_diagnostics: [
      type: :boolean,
      default: true,
      doc: "Always report diagnostics even when compilation succeeds"
    ],
    target: [
      type: {:in, ~w(es5 es2015 es2016 es2017 es2018 es2019 es2020 esnext)},
      default: "es2015",
      doc: "ECMAScript target version"
    ],
    out_dir: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Output directory for compiled files"
    ],
    source_map: [
      type: :boolean,
      default: false,
      doc: "Generate source map files"
    ],
    declaration: [
      type: :boolean,
      default: false,
      doc: "Generate .d.ts declaration files"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for `check_project/2`.

  ## Options

  #{NimbleOptions.docs(@check_project_schema)}
  """
  def check_project_schema, do: @check_project_schema

  @doc """
  Validates options for `check_project/2`.

  Returns `{:ok, validated_options}` or `{:error, %NimbleOptions.ValidationError{}}`.
  """
  @spec validate_check_project(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_check_project(opts) do
    NimbleOptions.validate(opts, @check_project_schema)
  end

  @doc """
  Validates options for `check_project/2`, raising on error.
  """
  @spec validate_check_project!(keyword()) :: keyword()
  def validate_check_project!(opts) do
    NimbleOptions.validate!(opts, @check_project_schema)
  end

  # ============================================================================
  # Check File Options
  # ============================================================================

  @check_file_schema NimbleOptions.new!([
    content: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "File content (if nil, reads from disk)"
    ],
    imported_types: [
      type: {:custom, __MODULE__, :validate_imported_types, []},
      default: %{},
      doc: "Map of imported type definitions from dependencies (string keys for file paths)"
    ],
    verbose: [
      type: :boolean,
      default: false,
      doc: "Enable verbose output"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for `check_file/2`.

  ## Options

  #{NimbleOptions.docs(@check_file_schema)}
  """
  def check_file_schema, do: @check_file_schema

  @doc """
  Validates options for `check_file/2`.
  """
  @spec validate_check_file(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_check_file(opts) do
    NimbleOptions.validate(opts, @check_file_schema)
  end

  @doc """
  Validates options for `check_file/2`, raising on error.
  """
  @spec validate_check_file!(keyword()) :: keyword()
  def validate_check_file!(opts) do
    NimbleOptions.validate!(opts, @check_file_schema)
  end

  # ============================================================================
  # CLI Worker Options
  # ============================================================================

  @cli_worker_schema NimbleOptions.new!([
    worker_id: [
      type: :pos_integer,
      default: 1,
      doc: "Worker process identifier"
    ],
    binary_path: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Path to MoonBit CLI binary (uses config default if nil)"
    ],
    timeout: [
      type: :pos_integer,
      default: 60_000,
      doc: "Request timeout in milliseconds"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for CLI worker configuration.

  ## Options

  #{NimbleOptions.docs(@cli_worker_schema)}
  """
  def cli_worker_schema, do: @cli_worker_schema

  @doc """
  Validates CLI worker options.
  """
  @spec validate_cli_worker(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_cli_worker(opts) do
    NimbleOptions.validate(opts, @cli_worker_schema)
  end

  # ============================================================================
  # Worker Pool Supervisor Options
  # ============================================================================

  @pool_supervisor_schema NimbleOptions.new!([
    pool_size: [
      type: :pos_integer,
      default: 4,
      doc: "Number of worker processes in the pool"
    ],
    binary_path: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Path to MoonBit CLI binary (uses config default if nil)"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for pool supervisor configuration.

  ## Options

  #{NimbleOptions.docs(@pool_supervisor_schema)}
  """
  def pool_supervisor_schema, do: @pool_supervisor_schema

  @doc """
  Validates pool supervisor options.
  """
  @spec validate_pool_supervisor(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_pool_supervisor(opts) do
    NimbleOptions.validate(opts, @pool_supervisor_schema)
  end

  # ============================================================================
  # File Watcher Options
  # ============================================================================

  @file_watcher_schema NimbleOptions.new!([
    dirs: [
      type: {:list, :string},
      default: [],
      doc: "List of directories to watch for changes"
    ],
    debounce_ms: [
      type: :pos_integer,
      default: 100,
      doc: "Debounce delay in milliseconds before processing changes"
    ],
    extensions: [
      type: {:list, :string},
      default: [".ts", ".tsx"],
      doc: "File extensions to watch"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for file watcher configuration.

  ## Options

  #{NimbleOptions.docs(@file_watcher_schema)}
  """
  def file_watcher_schema, do: @file_watcher_schema

  @doc """
  Validates file watcher options.
  """
  @spec validate_file_watcher(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_file_watcher(opts) do
    NimbleOptions.validate(opts, @file_watcher_schema)
  end

  # ============================================================================
  # Cache Options
  # ============================================================================

  @cache_schema NimbleOptions.new!([
    persist_to_disk: [
      type: :boolean,
      default: true,
      doc: "Persist cache to disk for faster startup"
    ],
    cache_dir: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Directory for cache files (defaults to .tsc_cache in project root)"
    ],
    warm_on_startup: [
      type: :boolean,
      default: true,
      doc: "Load cache from disk on startup"
    ],
    max_entries: [
      type: :pos_integer,
      default: 10_000,
      doc: "Maximum number of entries to keep in cache"
    ],
    ttl_hours: [
      type: :pos_integer,
      default: 24,
      doc: "Time-to-live for cache entries in hours"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for cache configuration.

  ## Options

  #{NimbleOptions.docs(@cache_schema)}
  """
  def cache_schema, do: @cache_schema

  @doc """
  Validates cache options.
  """
  @spec validate_cache(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_cache(opts) do
    NimbleOptions.validate(opts, @cache_schema)
  end

  # ============================================================================
  # API Request Options
  # ============================================================================

  @api_check_schema NimbleOptions.new!([
    files: [
      type: {:list, :string},
      default: [],
      doc: "List of TypeScript file paths to check"
    ],
    project: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Project directory path for file discovery"
    ],
    tsconfig: [
      type: {:or, [:string, nil]},
      default: nil,
      doc: "Path to tsconfig.json for configuration and file discovery"
    ],
    incremental: [
      type: :boolean,
      default: true,
      doc: "Only check changed files"
    ],
    concurrency: [
      type: :pos_integer,
      default: 4,
      doc: "Maximum concurrent file checks"
    ],
    use_dependency_order: [
      type: :boolean,
      default: false,
      doc: "Build dependency graph and check files in topological order"
    ]
  ])

  @doc """
  Returns the NimbleOptions schema for API check requests.

  ## Options

  #{NimbleOptions.docs(@api_check_schema)}
  """
  def api_check_schema, do: @api_check_schema

  @doc """
  Validates API check request options.
  """
  @spec validate_api_check(keyword()) :: {:ok, keyword()} | {:error, NimbleOptions.ValidationError.t()}
  def validate_api_check(opts) do
    NimbleOptions.validate(opts, @api_check_schema)
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  @doc """
  Converts a map (e.g., from JSON) to keyword list for validation.

  Keys are atomized, and nested maps are recursively converted.
  Only converts keys that are known option names to prevent atom exhaustion.
  """
  @spec from_map(map(), atom()) :: keyword()
  def from_map(map, schema_type) when is_map(map) do
    allowed_keys = get_allowed_keys(schema_type)

    map
    |> Enum.filter(fn {k, _v} -> to_string(k) in allowed_keys end)
    |> Enum.map(fn {k, v} -> {String.to_existing_atom(to_string(k)), v} end)
  end

  defp get_allowed_keys(:check_project) do
    ~w(incremental concurrency use_dependency_order verbose report_diagnostics target out_dir source_map declaration)
  end

  defp get_allowed_keys(:check_file) do
    ~w(content imported_types verbose)
  end

  defp get_allowed_keys(:cli_worker) do
    ~w(worker_id binary_path timeout)
  end

  defp get_allowed_keys(:pool_supervisor) do
    ~w(pool_size binary_path)
  end

  defp get_allowed_keys(:file_watcher) do
    ~w(dirs debounce_ms extensions)
  end

  defp get_allowed_keys(:cache) do
    ~w(persist_to_disk cache_dir warm_on_startup max_entries ttl_hours)
  end

  defp get_allowed_keys(:api_check) do
    ~w(files project tsconfig incremental concurrency use_dependency_order)
  end

  defp get_allowed_keys(_), do: []

  # ============================================================================
  # Custom Type Validators
  # ============================================================================

  @doc """
  Custom validator for imported_types map (allows string keys for file paths).
  """
  def validate_imported_types(value) when is_map(value), do: {:ok, value}
  def validate_imported_types(value), do: {:error, "expected a map, got: #{inspect(value)}"}
end
