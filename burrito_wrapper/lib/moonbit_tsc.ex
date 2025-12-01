defmodule MoonbitTsc do
  @moduledoc """
  MoonBit TypeScript Compiler wrapper.

  This module provides an Elixir interface to the MoonBit TypeScript compiler,
  enabling parallel compilation, caching, and integration with Elixir/OTP.
  """

  alias MoonbitTsc.Compiler

  @doc """
  Compile TypeScript files.

  ## Options
  - `:project` - Path to tsconfig.json
  - `:out_dir` - Output directory
  - `:source_map` - Generate source maps (default: true)
  - `:declaration` - Generate .d.ts files (default: false)
  - `:workers` - Number of worker processes (default: System.schedulers_online())

  ## Examples

      MoonbitTsc.compile(["src/index.ts", "src/utils.ts"], out_dir: "dist")
      MoonbitTsc.compile(project: "tsconfig.json")
  """
  @spec compile([String.t()] | keyword()) :: {:ok, map()} | {:error, term()}
  def compile(files_or_opts) when is_list(files_or_opts) do
    {files, opts} = case files_or_opts do
      [{key, _} | _] when is_atom(key) -> {[], files_or_opts}
      files -> {files, []}
    end

    Compiler.compile(files, opts)
  end

  @doc """
  Check TypeScript files for errors without emitting.

  ## Examples

      MoonbitTsc.check(["src/index.ts"])
      {:ok, %{errors: [], warnings: []}}
  """
  @spec check([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def check(files, opts \\ []) do
    Compiler.check(files, opts)
  end

  @doc """
  Watch files for changes and recompile.

  ## Examples

      MoonbitTsc.watch(["src/**/*.ts"], out_dir: "dist")
  """
  @spec watch([String.t()], keyword()) :: {:ok, pid()} | {:error, term()}
  def watch(patterns, opts \\ []) do
    MoonbitTsc.Watcher.start_watching(patterns, opts)
  end

  @doc """
  Get version information.
  """
  @spec version() :: String.t()
  def version do
    "0.1.0"
  end
end
