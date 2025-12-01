defmodule MoonbitTsc.Options do
  @moduledoc """
  Options validation and normalization for MoonBit TypeScript Compiler.
  """

  @compile_schema [
    out_dir: [
      type: :string,
      doc: "Output directory for compiled files"
    ],
    project: [
      type: :string,
      doc: "Path to tsconfig.json"
    ],
    source_map: [
      type: :boolean,
      default: false,
      doc: "Generate source maps"
    ],
    declaration: [
      type: :boolean,
      default: false,
      doc: "Generate .d.ts declaration files"
    ],
    verbose: [
      type: :boolean,
      default: false,
      doc: "Enable verbose output"
    ],
    workers: [
      type: :pos_integer,
      default: System.schedulers_online(),
      doc: "Number of worker processes"
    ],
    timeout: [
      type: :timeout,
      default: 60_000,
      doc: "Compilation timeout in milliseconds"
    ]
  ]

  @check_schema [
    project: [
      type: :string,
      doc: "Path to tsconfig.json"
    ],
    verbose: [
      type: :boolean,
      default: false,
      doc: "Enable verbose output"
    ],
    timeout: [
      type: :timeout,
      default: 60_000,
      doc: "Check timeout in milliseconds"
    ]
  ]

  @watch_schema [
    out_dir: [
      type: :string,
      doc: "Output directory for compiled files"
    ],
    project: [
      type: :string,
      doc: "Path to tsconfig.json"
    ],
    source_map: [
      type: :boolean,
      default: false,
      doc: "Generate source maps"
    ],
    declaration: [
      type: :boolean,
      default: false,
      doc: "Generate .d.ts declaration files"
    ],
    poll_interval: [
      type: :pos_integer,
      default: 500,
      doc: "File polling interval in milliseconds"
    ]
  ]

  @doc """
  Validate and normalize compile options.
  """
  @spec validate_compile(keyword()) :: {:ok, keyword()} | {:error, term()}
  def validate_compile(opts) do
    NimbleOptions.validate(opts, @compile_schema)
  end

  @doc """
  Validate and normalize check options.
  """
  @spec validate_check(keyword()) :: {:ok, keyword()} | {:error, term()}
  def validate_check(opts) do
    NimbleOptions.validate(opts, @check_schema)
  end

  @doc """
  Validate and normalize watch options.
  """
  @spec validate_watch(keyword()) :: {:ok, keyword()} | {:error, term()}
  def validate_watch(opts) do
    NimbleOptions.validate(opts, @watch_schema)
  end

  @doc """
  Get compile options schema documentation.
  """
  @spec compile_docs() :: String.t()
  def compile_docs do
    NimbleOptions.docs(@compile_schema)
  end

  @doc """
  Get check options schema documentation.
  """
  @spec check_docs() :: String.t()
  def check_docs do
    NimbleOptions.docs(@check_schema)
  end

  @doc """
  Get watch options schema documentation.
  """
  @spec watch_docs() :: String.t()
  def watch_docs do
    NimbleOptions.docs(@watch_schema)
  end
end
