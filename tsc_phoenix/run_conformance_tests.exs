# Conformance Test Runner
# Tests the compiler against TypeScript conformance test cases
# Usage:
#   elixir run_conformance_tests.exs                           # Run all tests
#   elixir run_conformance_tests.exs es6/classDeclaration      # Run specific category
#   elixir run_conformance_tests.exs es6/templates 100         # Run with limit

defmodule ConformanceTestRunner do
  @conformance_dir "/Users/srikanthkyatham/Personal/moonbit/typescript-repo/tests/cases/conformance"
  @baselines_dir "/Users/srikanthkyatham/Personal/moonbit/typescript-repo/tests/baselines/reference"
  @cli_path "/Users/srikanthkyatham/Personal/moonbit/pure-moonbit-cli/src/moonbit/target/native/release/build/cli/cli.exe"
  @temp_dir "/tmp/conformance_multifile"

  def run(path \\ nil, limit \\ :all) do
    test_dir = if path, do: "#{@conformance_dir}/#{path}", else: @conformance_dir

    IO.puts("Starting conformance test run...")
    IO.puts("Test dir: #{test_dir}")
    IO.puts("CLI path: #{@cli_path}")
    IO.puts("")

    # Setup temp directory for multi-file tests
    File.rm_rf!(@temp_dir)
    File.mkdir_p!(@temp_dir)

    # Find all .ts files (excluding .d.ts)
    files = find_test_files(test_dir, limit)
    IO.puts("Found #{length(files)} test files")
    IO.puts("")

    # Run tests in parallel
    results = files
    |> Task.async_stream(&run_test/1, max_concurrency: 8, timeout: 30_000)
    |> Enum.map(fn {:ok, result} -> result end)

    # Categorize results based on baseline expectations
    {passed, failed} = Enum.split_with(results, fn r -> r.status == :passed end)

    # Further categorize failures
    should_pass_but_failed = Enum.filter(failed, fn r -> r.failure_type == :should_pass end)
    should_error_but_passed = Enum.filter(failed, fn r -> r.failure_type == :should_error end)

    # Categorize by error type for should_pass failures
    parse_errors = Enum.filter(should_pass_but_failed, fn r -> r.error_type == :parse_error end)
    type_errors = Enum.filter(should_pass_but_failed, fn r -> r.error_type == :type_error end)
    crash_errors = Enum.filter(should_pass_but_failed, fn r -> r.error_type == :crash end)
    other_errors = Enum.filter(should_pass_but_failed, fn r -> r.error_type == :other end)

    # Print summary
    IO.puts("\n" <> String.duplicate("=", 80))
    IO.puts("CONFORMANCE TEST RESULTS")
    IO.puts(String.duplicate("=", 80))
    IO.puts("")
    IO.puts("Total tests: #{length(results)}")
    IO.puts("Passed: #{length(passed)} (#{Float.round(length(passed) / max(length(results), 1) * 100, 1)}%)")
    IO.puts("Failed: #{length(failed)}")
    IO.puts("")
    IO.puts("Failure breakdown:")
    IO.puts("  Should PASS but failed: #{length(should_pass_but_failed)}")
    IO.puts("    - Parse errors: #{length(parse_errors)}")
    IO.puts("    - Type errors: #{length(type_errors)}")
    IO.puts("    - Crashes: #{length(crash_errors)}")
    IO.puts("    - Other: #{length(other_errors)}")
    IO.puts("  Should ERROR but passed: #{length(should_error_but_passed)}")
    IO.puts("")

    # Print details for should_error_but_passed
    if length(should_error_but_passed) > 0 do
      print_should_error_failures(should_error_but_passed)
    end

    # Analyze parse error patterns
    if length(parse_errors) > 0 do
      analyze_parse_errors(parse_errors)
    end

    # Analyze type error patterns
    if length(type_errors) > 0 do
      analyze_type_errors(type_errors)
    end

    # Print crashes
    print_category("CRASHES", crash_errors, 20)

    # Print detailed failures
    print_detailed_failures(should_pass_but_failed, 30)

    # Return results for further analysis
    %{
      total: length(results),
      passed: length(passed),
      should_pass_but_failed: should_pass_but_failed,
      should_error_but_passed: should_error_but_passed,
      parse_errors: parse_errors,
      type_errors: type_errors,
      crash_errors: crash_errors,
      other_errors: other_errors
    }
  end

  defp find_test_files(test_dir, limit) do
    files = Path.wildcard("#{test_dir}/**/*.ts")
    |> Enum.reject(&String.ends_with?(&1, ".d.ts"))

    case limit do
      :all -> files
      n when is_integer(n) -> Enum.take(files, n)
    end
  end

  defp has_error_baseline?(file) do
    basename = Path.basename(file, ".ts")
    error_file = "#{@baselines_dir}/#{basename}.errors.txt"
    File.exists?(error_file)
  end

  # Parse a test file that may contain multiple virtual files via @filename directives
  defp parse_multifile_test(file) do
    content = File.read!(file)
    lines = String.split(content, "\n")

    # Check if this is a multi-file test
    has_filename_directive = Enum.any?(lines, fn line ->
      String.match?(line, ~r/^\/\/\s*@filename:/i)
    end)

    if has_filename_directive do
      parse_multifile_content(file, lines)
    else
      # Single file test - return as-is
      {:single, file, nil}
    end
  end

  defp parse_multifile_content(original_file, lines) do
    # Extract header options (before first @filename)
    {header_lines, rest_lines} = Enum.split_while(lines, fn line ->
      not String.match?(line, ~r/^\/\/\s*@filename:/i)
    end)

    header_options = parse_header_options(header_lines)

    # Parse virtual files
    virtual_files = parse_virtual_files(rest_lines)

    {:multi, original_file, header_options, virtual_files}
  end

  defp parse_header_options(lines) do
    lines
    # Match lines with @ directives, handling possible BOM at start of file
    |> Enum.filter(fn line ->
      # Strip BOM if present (UTF-8 BOM is \uFEFF)
      clean_line = String.replace(line, ~r/^\xEF\xBB\xBF/, "")
      String.match?(clean_line, ~r/^\/\/\s*@\w+:/)
    end)
    |> Enum.map(fn line ->
      # Strip BOM if present before parsing
      clean_line = String.replace(line, ~r/^\xEF\xBB\xBF/, "")
      case Regex.run(~r/^\/\/\s*@(\w+):\s*(.*)$/, clean_line) do
        [_, key, value] -> {key, String.trim(value)}
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp parse_virtual_files(lines) do
    # Split by @filename directives
    {files, current_file, current_content} = Enum.reduce(lines, {[], nil, []}, fn line, {files, current_name, content} ->
      case Regex.run(~r/^\/\/\s*@filename:\s*(.+)$/i, line) do
        [_, new_filename] ->
          # Start a new file
          if current_name do
            # Save the previous file
            {[{current_name, Enum.reverse(content) |> Enum.join("\n")} | files], String.trim(new_filename), []}
          else
            {files, String.trim(new_filename), []}
          end
        _ ->
          # Add line to current file
          {files, current_name, [line | content]}
      end
    end)

    # Don't forget the last file
    final_files = if current_file do
      [{current_file, Enum.reverse(current_content) |> Enum.join("\n")} | files]
    else
      files
    end

    Enum.reverse(final_files)
  end

  # Write virtual files to temp directory and return their paths
  defp setup_multifile_test(original_file, virtual_files) do
    # Create a unique subdirectory for this test
    test_name = Path.basename(original_file, ".ts")
    test_dir = "#{@temp_dir}/#{test_name}_#{:erlang.phash2(original_file)}"
    File.mkdir_p!(test_dir)

    # Write each virtual file
    written_files = Enum.map(virtual_files, fn {filename, content} ->
      # Handle absolute paths (like /a.js) by making them relative
      clean_filename = String.trim_leading(filename, "/")
      file_path = "#{test_dir}/#{clean_filename}"

      # Create subdirectories if needed
      File.mkdir_p!(Path.dirname(file_path))

      # Write the file
      File.write!(file_path, content)
      file_path
    end)

    # Return only .ts files (not .js or .json)
    ts_files = Enum.filter(written_files, fn path ->
      String.ends_with?(path, ".ts") and not String.ends_with?(path, ".d.ts")
    end)

    {test_dir, ts_files, written_files}
  end

  defp run_test(file) do
    case parse_multifile_test(file) do
      {:single, file, _} ->
        run_single_file_test(file)

      {:multi, original_file, header_options, virtual_files} ->
        run_multifile_test(original_file, header_options, virtual_files)
    end
  rescue
    e ->
      %{
        file: file,
        status: :failed,
        failure_type: :should_pass,
        error_type: :crash,
        message: inspect(e)
      }
  end

  # Parse test file options like @target, @module, etc.
  defp parse_test_options(file) do
    content = File.read!(file)
    lines = String.split(content, "\n")
    parse_header_options(lines)
  end

  # Build CLI args from test options
  defp build_cli_args_from_options(options) do
    args = []

    # Handle @target directive
    args = case Map.get(options, "target") do
      nil -> args
      target -> args ++ ["--target", String.upcase(target)]
    end

    # Handle @module directive
    args = case Map.get(options, "module") do
      nil -> args
      mod -> args ++ ["--module", mod]
    end

    # Handle @strict directive
    args = case Map.get(options, "strict") do
      "true" -> args ++ ["--strict"]
      _ -> args
    end

    # Handle @noImplicitAny directive
    args = case Map.get(options, "noImplicitAny") do
      "true" -> args ++ ["--noImplicitAny"]
      _ -> args
    end

    args
  end

  defp run_single_file_test(file) do
    options = parse_test_options(file)
    option_args = build_cli_args_from_options(options)
    args = ["--noEmit", "--reportDiagnostics"] ++ option_args ++ [file]
    should_error = has_error_baseline?(file)

    case System.cmd(@cli_path, args, stderr_to_stdout: true) do
      {output, _code} ->
        compiled_ok = String.contains?(output, "Successfully compiled")

        cond do
          # Test should pass (no error baseline) and it did
          not should_error and compiled_ok ->
            %{
              file: file,
              status: :passed,
              error_type: nil,
              failure_type: nil,
              message: nil
            }

          # Test should error (has error baseline) and it did
          should_error and not compiled_ok ->
            %{
              file: file,
              status: :passed,
              error_type: nil,
              failure_type: nil,
              message: nil
            }

          # Test should pass but failed
          not should_error and not compiled_ok ->
            first_error = extract_first_error(output)
            error_type = categorize_error(first_error)
            %{
              file: file,
              status: :failed,
              failure_type: :should_pass,
              error_type: error_type,
              message: first_error,
              output: String.slice(output, 0, 1000)
            }

          # Test should error but passed
          should_error and compiled_ok ->
            %{
              file: file,
              status: :failed,
              failure_type: :should_error,
              error_type: :missing_error,
              message: "Should produce errors but compiled successfully"
            }
        end
    end
  end

  defp run_multifile_test(original_file, header_options, virtual_files) do
    should_error = has_error_baseline?(original_file)

    # Setup temp files
    {_test_dir, ts_files, _all_files} = setup_multifile_test(original_file, virtual_files)

    if ts_files == [] do
      # No .ts files to compile (might be all .js or .json)
      %{
        file: original_file,
        status: :passed,
        error_type: nil,
        failure_type: nil,
        message: "Multi-file test with no .ts files"
      }
    else
      # Build CLI args from header options (like @target)
      option_args = build_cli_args_from_options(header_options)
      # Run compiler on all .ts files at once
      args = ["--noEmit", "--reportDiagnostics"] ++ option_args ++ ts_files

      case System.cmd(@cli_path, args, stderr_to_stdout: true) do
        {output, _code} ->
          compiled_ok = String.contains?(output, "Successfully compiled") or
                        String.contains?(output, "0 error")

          cond do
            # Test should pass (no error baseline) and it did
            not should_error and compiled_ok ->
              %{
                file: original_file,
                status: :passed,
                error_type: nil,
                failure_type: nil,
                message: nil
              }

            # Test should error (has error baseline) and it did
            should_error and not compiled_ok ->
              %{
                file: original_file,
                status: :passed,
                error_type: nil,
                failure_type: nil,
                message: nil
              }

            # Test should pass but failed
            not should_error and not compiled_ok ->
              first_error = extract_first_error(output)
              error_type = categorize_error(first_error)
              %{
                file: original_file,
                status: :failed,
                failure_type: :should_pass,
                error_type: error_type,
                message: first_error,
                output: String.slice(output, 0, 1000)
              }

            # Test should error but passed
            should_error and compiled_ok ->
              %{
                file: original_file,
                status: :failed,
                failure_type: :should_error,
                error_type: :missing_error,
                message: "Should produce errors but compiled successfully"
              }
          end
      end
    end
  end

  defp extract_first_error(output) do
    case Regex.run(~r/error TS\d+: .+/, output) do
      [match] -> match
      _ -> String.slice(output, 0, 200)
    end
  end

  defp categorize_error(message) do
    cond do
      String.contains?(message, ["Unexpected token", "Expected", "Unterminated",
                                  "Scanner error", "Parse error", "Invalid character",
                                  "expected", "Cannot use namespace"]) ->
        :parse_error
      String.contains?(message, ["Cannot find", "not assignable", "Property",
                                  "Argument", "has no", "is not a", "does not exist"]) ->
        :type_error
      true ->
        :other
    end
  end

  defp print_category(title, items, limit) do
    if length(items) > 0 do
      IO.puts("\n#{String.duplicate("-", 80)}")
      IO.puts("#{title} (showing #{min(length(items), limit)} of #{length(items)})")
      IO.puts(String.duplicate("-", 80))

      items
      |> Enum.take(limit)
      |> Enum.each(fn item ->
        relative_path = String.replace(item.file, @conformance_dir <> "/", "")
        IO.puts("\n  #{relative_path}")
        IO.puts("    #{String.slice(item.message || "", 0, 200)}")
      end)
    end
  end

  defp print_should_error_failures(items) do
    IO.puts("\n#{String.duplicate("-", 80)}")
    IO.puts("MISSING ERRORS (should error but passed) - #{length(items)} tests")
    IO.puts(String.duplicate("-", 80))

    items
    |> Enum.take(20)
    |> Enum.each(fn item ->
      relative_path = String.replace(item.file, @conformance_dir <> "/", "")
      IO.puts("  #{relative_path}")
    end)
  end

  defp print_detailed_failures(items, limit) do
    if length(items) > 0 do
      IO.puts("\n#{String.duplicate("-", 80)}")
      IO.puts("DETAILED FAILURES (showing #{min(length(items), limit)} of #{length(items)})")
      IO.puts(String.duplicate("-", 80))

      items
      |> Enum.take(limit)
      |> Enum.each(fn item ->
        relative_path = String.replace(item.file, @conformance_dir <> "/", "")
        IO.puts("\n[#{item.error_type}] #{relative_path}")
        IO.puts("  #{item.message}")
      end)
    end
  end

  defp analyze_parse_errors(errors) do
    IO.puts("\n#{String.duplicate("-", 80)}")
    IO.puts("PARSE ERROR ANALYSIS (#{length(errors)} errors)")
    IO.puts(String.duplicate("-", 80))

    # Group by error message pattern
    patterns = errors
    |> Enum.map(fn e ->
      msg = e.message || ""
      cond do
        String.contains?(msg, "Unexpected token") -> "Unexpected token"
        String.contains?(msg, "'}' expected") -> "'}' expected"
        String.contains?(msg, "')' expected") -> "')' expected"
        String.contains?(msg, "',' expected") -> "',' expected"
        String.contains?(msg, "';' expected") -> "';' expected"
        String.contains?(msg, "Expected") -> "Expected ..."
        String.contains?(msg, "Identifier expected") -> "Identifier expected"
        String.contains?(msg, "Expected type") -> "Expected type"
        String.contains?(msg, "Unterminated") -> "Unterminated ..."
        String.contains?(msg, "Invalid") -> "Invalid ..."
        String.contains?(msg, "Cannot use namespace") -> "Cannot use namespace as value"
        true -> "Other: #{String.slice(msg, 0, 50)}"
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)

    IO.puts("\nError patterns:")
    Enum.each(patterns, fn {pattern, count} ->
      IO.puts("  #{String.pad_trailing(pattern, 40)} #{count}")
    end)

    # Group by directory
    by_dir = errors
    |> Enum.map(fn e ->
      parts = String.split(e.file, "/")
      idx = Enum.find_index(parts, &(&1 == "conformance"))
      if idx && length(parts) > idx + 1 do
        Enum.at(parts, idx + 1)
      else
        "unknown"
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(20)

    IO.puts("\nMost affected directories:")
    Enum.each(by_dir, fn {dir, count} ->
      IO.puts("  #{String.pad_trailing(dir, 30)} #{count}")
    end)
  end

  defp analyze_type_errors(errors) do
    IO.puts("\n#{String.duplicate("-", 80)}")
    IO.puts("TYPE ERROR ANALYSIS (#{length(errors)} errors)")
    IO.puts(String.duplicate("-", 80))

    # Group by error message pattern
    patterns = errors
    |> Enum.map(fn e ->
      msg = e.message || ""
      cond do
        String.contains?(msg, "Cannot find name") -> "Cannot find name"
        String.contains?(msg, "does not exist on type") -> "Property does not exist"
        String.contains?(msg, "not assignable to") -> "Type not assignable"
        String.contains?(msg, "has no exported member") -> "No exported member"
        String.contains?(msg, "is not a function") -> "Not a function"
        String.contains?(msg, "Argument of type") -> "Argument type mismatch"
        true -> "Other: #{String.slice(msg, 0, 40)}"
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)

    IO.puts("\nError patterns:")
    Enum.each(patterns, fn {pattern, count} ->
      IO.puts("  #{String.pad_trailing(pattern, 40)} #{count}")
    end)

    # Group by directory
    by_dir = errors
    |> Enum.map(fn e ->
      parts = String.split(e.file, "/")
      idx = Enum.find_index(parts, &(&1 == "conformance"))
      if idx && length(parts) > idx + 1 do
        Enum.at(parts, idx + 1)
      else
        "unknown"
      end
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(15)

    IO.puts("\nMost affected directories:")
    Enum.each(by_dir, fn {dir, count} ->
      IO.puts("  #{String.pad_trailing(dir, 30)} #{count}")
    end)
  end

  defp analyze_other_errors(errors) do
    IO.puts("\n#{String.duplicate("-", 80)}")
    IO.puts("OTHER ERROR ANALYSIS (#{length(errors)} errors)")
    IO.puts(String.duplicate("-", 80))

    # Group by error message pattern
    patterns = errors
    |> Enum.map(fn e ->
      msg = e.message || ""
      String.slice(msg, 0, 60)
    end)
    |> Enum.frequencies()
    |> Enum.sort_by(fn {_, count} -> -count end)
    |> Enum.take(20)

    IO.puts("\nError patterns:")
    Enum.each(patterns, fn {pattern, count} ->
      IO.puts("  #{String.pad_trailing(pattern, 60)} #{count}")
    end)
  end
end

# Parse command line arguments and run
case System.argv() do
  [] ->
    # Run all tests
    ConformanceTestRunner.run()
  [path] ->
    # Run tests in specific path
    ConformanceTestRunner.run(path)
  [path, limit_str] ->
    # Run tests in path with limit
    {limit, _} = Integer.parse(limit_str)
    ConformanceTestRunner.run(path, limit)
  _ ->
    IO.puts("Usage: elixir run_conformance_tests.exs [path] [limit]")
    IO.puts("  path  - Relative path under conformance dir (e.g., es6/classDeclaration)")
    IO.puts("  limit - Maximum number of tests to run")
end
