#!/usr/bin/env elixir

defmodule ConformanceTestRunner do
  @cli_path "/Users/srikanthkyatham/Personal/moonbit/pure-moonbit-cli/src/moonbit/target/native/release/build/cli/cli.exe"
  @ts_repo "/Users/srikanthkyatham/Personal/moonbit/typescript-repo"

  def main(args) do
    category = case args do
      [cat] -> cat
      [] ->
        IO.puts("Usage: ./run_conformance_tests.exs <category>")
        IO.puts("Example: ./run_conformance_tests.exs es6/computedProperties")
        System.halt(1)
    end

    test_dir = Path.join([@ts_repo, "tests/cases/conformance", category])
    baseline_dir = Path.join(@ts_repo, "tests/baselines/reference")

    unless File.dir?(test_dir) do
      IO.puts("Error: Test directory not found: #{test_dir}")
      System.halt(1)
    end

    IO.puts("\n=== Running TypeScript Conformance Tests ===")
    IO.puts("Category: #{category}")
    IO.puts("Test directory: #{test_dir}")
    IO.puts("")

    test_files = Path.wildcard("#{test_dir}/*.ts")

    results = Enum.map(test_files, fn file ->
      filename = Path.basename(file, ".ts")
      baseline = Path.join(baseline_dir, "#{filename}.errors.txt")

      # Run compiler
      {output, _exit_code} = System.cmd(@cli_path, [file, "--noEmit"], stderr_to_stdout: true)

      has_errors = String.contains?(output, " error(s)")
      expects_errors = File.exists?(baseline)

      passed = (has_errors and expects_errors) or (not has_errors and not expects_errors)

      unless passed do
        if expects_errors and not has_errors do
          IO.puts("❌ FAIL: #{filename} (expected errors, got none)")
        else
          IO.puts("❌ FAIL: #{filename} (expected no errors, got errors)")
        end
      end

      {filename, passed}
    end)

    passed_count = Enum.count(results, fn {_, passed} -> passed end)
    total_count = length(results)
    pass_rate = Float.round(passed_count / total_count * 100, 1)

    IO.puts("\n=== Test Results ===")
    IO.puts("Passed: #{passed_count}/#{total_count} (#{pass_rate}%)")
    IO.puts("Failed: #{total_count - passed_count}")

    if pass_rate == 100.0 do
      IO.puts("\n🎉 All tests passing!")
    end
  end
end

ConformanceTestRunner.main(System.argv())
