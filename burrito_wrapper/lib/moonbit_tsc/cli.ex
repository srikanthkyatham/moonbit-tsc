defmodule MoonbitTsc.CLI do
  @moduledoc """
  Command-line interface for MoonBit TypeScript Compiler.

  This module provides the entry point for the escript/Burrito binary.
  """

  @doc """
  Main entry point for CLI.
  """
  def main(args) do
    {opts, files, _} = OptionParser.parse(args,
      strict: [
        help: :boolean,
        version: :boolean,
        project: :string,
        out_dir: :string,
        source_map: :boolean,
        declaration: :boolean,
        watch: :boolean,
        no_emit: :boolean,
        verbose: :boolean
      ],
      aliases: [
        h: :help,
        v: :version,
        p: :project,
        o: :out_dir,
        w: :watch
      ]
    )

    cond do
      opts[:help] ->
        print_help()

      opts[:version] ->
        IO.puts("moonbit-tsc #{MoonbitTsc.version()}")

      opts[:watch] ->
        run_watch(files, opts)

      opts[:no_emit] ->
        run_check(files, opts)

      true ->
        run_compile(files, opts)
    end
  end

  defp run_compile(files, opts) do
    compile_opts = [
      out_dir: opts[:out_dir],
      project: opts[:project],
      source_map: opts[:source_map] || false,
      declaration: opts[:declaration] || false,
      verbose: opts[:verbose] || false
    ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

    case MoonbitTsc.compile(files ++ compile_opts) do
      {:ok, result} ->
        if opts[:verbose] do
          IO.puts("Compilation successful")
          IO.inspect(result, label: "Result")
        end
        System.halt(0)

      {:error, %{errors: errors}} when is_list(errors) ->
        Enum.each(errors, &print_error/1)
        System.halt(1)

      {:error, reason} ->
        IO.puts(:stderr, "Compilation failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_check(files, opts) do
    check_opts = [
      project: opts[:project],
      verbose: opts[:verbose] || false
    ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

    case MoonbitTsc.check(files, check_opts) do
      {:ok, %{errors: []}} ->
        IO.puts("No errors found")
        System.halt(0)

      {:ok, %{errors: errors}} ->
        Enum.each(errors, &print_error/1)
        System.halt(1)

      {:error, reason} ->
        IO.puts(:stderr, "Check failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_watch(patterns, opts) do
    IO.puts("Starting watch mode...")

    watch_opts = [
      out_dir: opts[:out_dir],
      project: opts[:project],
      source_map: opts[:source_map] || false,
      declaration: opts[:declaration] || false
    ] |> Enum.reject(fn {_, v} -> is_nil(v) end)

    case MoonbitTsc.watch(patterns, watch_opts) do
      {:ok, _pid} ->
        IO.puts("Watching for changes. Press Ctrl+C to stop.")
        # Keep the process alive
        Process.sleep(:infinity)

      {:error, reason} ->
        IO.puts(:stderr, "Watch failed: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp print_error(%{file: file, line: line, column: col, code: code, message: msg}) do
    IO.puts(:stderr, "#{file}(#{line},#{col}): error #{code}: #{msg}")
  end

  defp print_error(error) do
    IO.puts(:stderr, "Error: #{inspect(error)}")
  end

  defp print_help do
    IO.puts("""
    MoonBit TypeScript Compiler

    USAGE:
        moonbit-tsc [OPTIONS] [FILES...]

    OPTIONS:
        -h, --help          Show this help message
        -v, --version       Show version information
        -p, --project PATH  Path to tsconfig.json
        -o, --out-dir PATH  Output directory
        --source-map        Generate source maps
        --declaration       Generate .d.ts declaration files
        -w, --watch         Watch mode - recompile on file changes
        --no-emit           Type check only, don't emit files
        --verbose           Verbose output

    EXAMPLES:
        moonbit-tsc src/index.ts -o dist
        moonbit-tsc -p tsconfig.json
        moonbit-tsc --watch src/**/*.ts -o dist
        moonbit-tsc --no-emit src/**/*.ts
    """)
  end
end
