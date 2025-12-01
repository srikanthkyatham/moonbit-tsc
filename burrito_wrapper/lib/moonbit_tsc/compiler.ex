defmodule MoonbitTsc.Compiler do
  @moduledoc """
  Port-based communication with MoonBit CLI binary.

  This module handles all interaction with the underlying MoonBit TypeScript
  compiler binary through Erlang Ports.
  """

  require Logger

  @cli_binary_name "moonbit-cli"

  # ============================================================================
  # Public API
  # ============================================================================

  @doc """
  Compile TypeScript files.
  """
  @spec compile([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def compile(files, opts \\ []) do
    args = build_compile_args(files, opts)
    run_cli(args)
  end

  @doc """
  Check TypeScript files for errors without emitting.
  """
  @spec check([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def check(files, opts \\ []) do
    args = build_check_args(files, opts)
    run_cli(args)
  end

  @doc """
  Get the path to the CLI binary.
  """
  @spec cli_path() :: String.t()
  def cli_path do
    case :code.priv_dir(:moonbit_tsc) do
      {:error, :bad_name} ->
        # Development fallback
        Path.join([File.cwd!(), "priv", "bin", @cli_binary_name])

      priv_dir ->
        Path.join([priv_dir, "bin", @cli_binary_name])
    end
  end

  @doc """
  Check if the CLI binary exists and is executable.
  """
  @spec cli_available?() :: boolean()
  def cli_available? do
    path = cli_path()
    File.exists?(path) and File.stat!(path).access in [:read_write, :read]
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp run_cli(args) do
    path = cli_path()

    unless cli_available?() do
      {:error, {:cli_not_found, path}}
    else
      start_time = System.monotonic_time(:millisecond)

      port_opts = [
        :binary,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout,
        args: args
      ]

      port = Port.open({:spawn_executable, path}, port_opts)

      result = collect_output(port, [])

      duration = System.monotonic_time(:millisecond) - start_time
      Logger.debug("CLI execution completed in #{duration}ms")

      result
    end
  end

  defp collect_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_output(port, [data | acc])

      {^port, {:exit_status, 0}} ->
        output = acc |> Enum.reverse() |> IO.iodata_to_binary()
        parse_output(output)

      {^port, {:exit_status, status}} ->
        output = acc |> Enum.reverse() |> IO.iodata_to_binary()
        {:error, %{exit_status: status, output: output, errors: parse_errors(output)}}
    after
      120_000 ->
        Port.close(port)
        {:error, :timeout}
    end
  end

  defp build_compile_args(files, opts) do
    base_args = files

    base_args
    |> add_opt(opts, :out_dir, "--outDir")
    |> add_opt(opts, :project, "--project")
    |> add_flag(opts, :source_map, "--sourceMap")
    |> add_flag(opts, :declaration, "--declaration")
    |> add_flag(opts, :verbose, "--verbose")
  end

  defp build_check_args(files, opts) do
    base_args = ["--noEmit" | files]

    base_args
    |> add_opt(opts, :project, "--project")
    |> add_flag(opts, :verbose, "--verbose")
  end

  defp add_opt(args, opts, key, flag) do
    case Keyword.get(opts, key) do
      nil -> args
      value -> args ++ [flag, to_string(value)]
    end
  end

  defp add_flag(args, opts, key, flag) do
    if Keyword.get(opts, key, false) do
      args ++ [flag]
    else
      args
    end
  end

  defp parse_output(output) do
    # Try to parse as JSON first
    case Jason.decode(output) do
      {:ok, json} ->
        {:ok, json}

      {:error, _} ->
        # Return raw output
        {:ok, %{output: output, files: [], errors: [], warnings: []}}
    end
  end

  defp parse_errors(output) do
    # Parse TypeScript-style error messages
    output
    |> String.split("\n")
    |> Enum.filter(&String.contains?(&1, "error"))
    |> Enum.map(&parse_error_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_error_line(line) do
    # Match patterns like: "src/file.ts(10,5): error TS2322: Type..."
    case Regex.run(~r/(.+)\((\d+),(\d+)\):\s*error\s+(\w+):\s*(.+)/, line) do
      [_, file, line_num, col, code, message] ->
        %{
          file: file,
          line: String.to_integer(line_num),
          column: String.to_integer(col),
          code: code,
          message: message
        }

      _ ->
        nil
    end
  end
end
