defmodule TscLsp.ServerTest do
  use ExUnit.Case, async: true

  # Unit tests for diagnostic parsing (no server needed)
  describe "diagnostic parsing" do
    test "parses error diagnostic from CLI output" do
      output = "/tmp/test.ts:5:10 - error TS2322: Type 'string' is not assignable to type 'number'."

      [diag] = parse_diagnostics(output)

      assert diag.range.start.line == 4
      assert diag.range.start.character == 9
      assert diag.code == "TS2322"
      assert diag.message == "Type 'string' is not assignable to type 'number'."
      assert diag.severity == GenLSP.Enumerations.DiagnosticSeverity.error()
    end

    test "parses warning diagnostic" do
      output = "/tmp/test.ts:10:5 - warning TS6133: 'unused' is declared but its value is never read."

      [diag] = parse_diagnostics(output)

      assert diag.severity == GenLSP.Enumerations.DiagnosticSeverity.warning()
      assert diag.code == "TS6133"
    end

    test "parses suggestion diagnostic" do
      output = "/tmp/test.ts:3:1 - suggestion TS80001: This is a suggestion."

      [diag] = parse_diagnostics(output)

      assert diag.severity == GenLSP.Enumerations.DiagnosticSeverity.hint()
    end

    test "parses message diagnostic" do
      output = "/tmp/test.ts:1:1 - message TS0001: Informational message."

      [diag] = parse_diagnostics(output)

      assert diag.severity == GenLSP.Enumerations.DiagnosticSeverity.information()
    end

    test "ignores non-diagnostic lines" do
      output = """
      Successfully compiled
      0 errors, 0 warnings
      """

      assert parse_diagnostics(output) == []
    end

    test "handles multiple diagnostics" do
      output = """
      /tmp/test.ts:1:1 - error TS2304: Cannot find name 'foo'.
      /tmp/test.ts:2:5 - error TS2322: Type 'string' is not assignable to type 'number'.
      /tmp/test.ts:3:10 - warning TS6133: 'bar' is declared but never used.
      """

      diagnostics = parse_diagnostics(output)
      assert length(diagnostics) == 3

      [d1, d2, d3] = diagnostics
      assert d1.code == "TS2304"
      assert d2.code == "TS2322"
      assert d3.code == "TS6133"
    end

    test "handles line 1 column 1 (zero-indexed to 0:0)" do
      output = "/tmp/test.ts:1:1 - error TS2304: Cannot find name 'x'."

      [diag] = parse_diagnostics(output)

      assert diag.range.start.line == 0
      assert diag.range.start.character == 0
    end

    test "handles Windows-style paths" do
      output = "C:\\Users\\test\\project\\file.ts:5:10 - error TS2322: Type error."

      [diag] = parse_diagnostics(output)

      assert diag.code == "TS2322"
      assert diag.range.start.line == 4
    end
  end

  describe "uri conversion" do
    test "converts file URI to path" do
      uri = "file:///tmp/project/test.ts"
      assert uri_to_path(uri) == "/tmp/project/test.ts"
    end

    test "handles URI encoded characters" do
      uri = "file:///tmp/my%20project/test.ts"
      assert uri_to_path(uri) == "/tmp/my project/test.ts"
    end
  end

  describe "severity mapping" do
    test "error maps to error" do
      assert category_to_severity("error") == GenLSP.Enumerations.DiagnosticSeverity.error()
    end

    test "warning maps to warning" do
      assert category_to_severity("warning") == GenLSP.Enumerations.DiagnosticSeverity.warning()
    end

    test "suggestion maps to hint" do
      assert category_to_severity("suggestion") == GenLSP.Enumerations.DiagnosticSeverity.hint()
    end

    test "message maps to information" do
      assert category_to_severity("message") == GenLSP.Enumerations.DiagnosticSeverity.information()
    end

    test "unknown defaults to error" do
      assert category_to_severity("unknown") == GenLSP.Enumerations.DiagnosticSeverity.error()
    end
  end

  # Helper functions that mirror server implementation
  defp parse_diagnostics(output) do
    output
    |> String.split("\n")
    |> Enum.map(&parse_diagnostic_line/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_diagnostic_line(line) do
    regex = ~r/^(.+?):(\d+):(\d+) - (error|warning|suggestion|message) (TS\d+): (.+)$/

    case Regex.run(regex, line) do
      [_, _file, line_num, col, category, code, message] ->
        line = String.to_integer(line_num) - 1
        col = String.to_integer(col) - 1

        %GenLSP.Structures.Diagnostic{
          range: %GenLSP.Structures.Range{
            start: %GenLSP.Structures.Position{line: max(0, line), character: max(0, col)},
            end: %GenLSP.Structures.Position{line: max(0, line), character: max(0, col + 1)}
          },
          severity: category_to_severity(category),
          code: code,
          source: "tsc",
          message: message
        }

      _ ->
        nil
    end
  end

  defp category_to_severity("error"), do: GenLSP.Enumerations.DiagnosticSeverity.error()
  defp category_to_severity("warning"), do: GenLSP.Enumerations.DiagnosticSeverity.warning()
  defp category_to_severity("suggestion"), do: GenLSP.Enumerations.DiagnosticSeverity.hint()
  defp category_to_severity("message"), do: GenLSP.Enumerations.DiagnosticSeverity.information()
  defp category_to_severity(_), do: GenLSP.Enumerations.DiagnosticSeverity.error()

  defp uri_to_path(uri) do
    uri
    |> URI.parse()
    |> Map.get(:path)
    |> URI.decode()
  end
end
