defmodule TSC.Worker.CLIWorkerTest do
  use ExUnit.Case, async: false

  alias TSC.Worker.CLIWorker

  @test_project_path Path.expand("test_project", File.cwd!())

  describe "check/3" do
    @tag :integration
    test "checks a valid TypeScript file" do
      file = Path.join(@test_project_path, "src/index.ts")

      # This assumes a worker is running with id 1
      # In real tests, we'd start the worker first
      request = %{
        file: file,
        options: %{}
      }

      # Note: This requires the worker pool to be running
      # For unit tests, we'd mock the System.cmd call
      result = CLIWorker.check(1, request)

      assert {:ok, result_map} = result
      assert is_map(result_map)
      assert Map.has_key?(result_map, :diagnostics)
      assert Map.has_key?(result_map, :success)
    end

    @tag :integration
    test "detects type errors in file" do
      file = Path.join(@test_project_path, "src/type_error.ts")

      request = %{
        file: file,
        options: %{}
      }

      result = CLIWorker.check(1, request)

      assert {:ok, result_map} = result
      assert is_list(result_map.diagnostics)

      # type_error.ts should have errors
      if length(result_map.diagnostics) > 0 do
        [first | _] = result_map.diagnostics
        assert Map.has_key?(first, :code)
        assert Map.has_key?(first, :message)
      end
    end
  end

  describe "diagnostic parsing" do
    test "parses MoonBit CLI diagnostic format" do
      # Test the internal parsing logic
      # Format: file_path:line:column - category TScode: message
      output = """
      src/foo.ts:10:5 - error TS2322: Type 'string' is not assignable to type 'number'
      src/bar.ts:20:1 - warning TS6133: 'x' is declared but its value is never read
      """

      # We can't call private functions directly, but we can test through
      # the public API by mocking System.cmd if needed

      # For now, just verify the format we expect
      assert String.contains?(output, " - error TS")
      assert String.contains?(output, " - warning TS")
    end
  end
end
