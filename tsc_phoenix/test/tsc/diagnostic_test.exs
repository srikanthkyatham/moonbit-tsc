defmodule TSC.DiagnosticTest do
  use ExUnit.Case, async: true

  alias TSC.Diagnostic

  describe "parse/1" do
    test "parses single error diagnostic" do
      output = "src/foo.ts:10:5 - error TS2322: Type 'string' is not assignable to type 'number'"

      [diag] = Diagnostic.parse(output)

      assert diag.file == "src/foo.ts"
      assert diag.line == 10
      assert diag.column == 5
      assert diag.category == :error
      assert diag.code == "TS2322"
      assert diag.code_number == 2322
      assert diag.message == "Type 'string' is not assignable to type 'number'"
      assert diag.error_type == :type_assignment
    end

    test "parses warning diagnostic" do
      output = "src/bar.ts:5:1 - warning TS6133: 'unused' is declared but never used"

      [diag] = Diagnostic.parse(output)

      assert diag.category == :warning
      assert diag.code == "TS6133"
      assert diag.code_number == 6133
    end

    test "parses suggestion diagnostic" do
      output = "src/utils.ts:20:10 - suggestion TS80001: Consider using 'const' instead of 'let'"

      [diag] = Diagnostic.parse(output)

      assert diag.category == :suggestion
      assert diag.code == "TS80001"
    end

    test "parses multiple diagnostics" do
      output = """
      src/foo.ts:10:5 - error TS2322: Type 'string' is not assignable to type 'number'
      src/foo.ts:15:1 - error TS2304: Cannot find name 'undefined_var'
      Compiled 1 file(s) with 2 error(s) in 5ms
      """

      diagnostics = Diagnostic.parse(output)

      assert length(diagnostics) == 2
      assert Enum.at(diagnostics, 0).code == "TS2322"
      assert Enum.at(diagnostics, 1).code == "TS2304"
    end

    test "ignores non-diagnostic lines" do
      output = """
      Compiling src/foo.ts...
      src/foo.ts:10:5 - error TS2322: Type 'string' is not assignable to type 'number'
      Compiled 1 file(s) with 1 error(s) in 5ms
      Found 1 error(s)
      """

      diagnostics = Diagnostic.parse(output)

      assert length(diagnostics) == 1
    end

    test "handles empty output" do
      assert Diagnostic.parse("") == []
    end

    test "handles file paths with colons (Windows)" do
      output = "C:/Users/test/project/src/foo.ts:10:5 - error TS2322: Type error"

      [diag] = Diagnostic.parse(output)

      assert diag.file == "C:/Users/test/project/src/foo.ts"
      assert diag.line == 10
      assert diag.column == 5
    end
  end

  describe "parse_line/1" do
    test "returns nil for non-matching lines" do
      assert Diagnostic.parse_line("Compiling files...") == nil
      assert Diagnostic.parse_line("Found 5 errors") == nil
      assert Diagnostic.parse_line("") == nil
    end

    test "parses overload error" do
      line = "src/test.ts:11:1 - error TS2769: No overload matches this call. Arguments: (string, number)"

      diag = Diagnostic.parse_line(line)

      assert diag.code == "TS2769"
      assert diag.error_type == :overload_error
    end
  end

  describe "categorize_error/1" do
    test "categorizes name resolution errors" do
      assert Diagnostic.categorize_error(2304) == :name_resolution
      assert Diagnostic.categorize_error(2305) == :name_resolution
      # 2307 is in name_resolution range (2304..2318), not module_error
      assert Diagnostic.categorize_error(2307) == :name_resolution
    end

    test "categorizes type assignment errors" do
      assert Diagnostic.categorize_error(2322) == :type_assignment
      # 2339 is in type_assignment range (2320..2380)
      assert Diagnostic.categorize_error(2339) == :type_assignment
      # 2345 is also in type_assignment range
      assert Diagnostic.categorize_error(2345) == :type_assignment
    end

    test "categorizes special codes" do
      assert Diagnostic.categorize_error(2769) == :overload_error
      assert Diagnostic.categorize_error(2551) == :spelling_suggestion
      assert Diagnostic.categorize_error(2532) == :null_check
    end

    test "returns :other for unknown codes" do
      assert Diagnostic.categorize_error(9999) == :other
    end
  end

  describe "error_type_label/1" do
    test "returns human-readable labels" do
      assert Diagnostic.error_type_label(:name_resolution) == "Name Resolution"
      assert Diagnostic.error_type_label(:type_assignment) == "Type Assignment"
      assert Diagnostic.error_type_label(:overload_error) == "Overload Resolution"
      assert Diagnostic.error_type_label(:other) == "Other"
    end
  end

  describe "to_map/1" do
    test "converts diagnostic struct to map" do
      diag = %Diagnostic{
        file: "src/test.ts",
        line: 10,
        column: 5,
        end_line: nil,
        end_column: nil,
        category: :error,
        code: "TS2322",
        code_number: 2322,
        message: "Type error",
        error_type: :type_assignment
      }

      map = Diagnostic.to_map(diag)

      assert map.file == "src/test.ts"
      assert map.line == 10
      assert map.column == 5
      assert map.category == "error"
      assert map.code == "TS2322"
      assert map.code_number == 2322
      assert map.error_type == "type_assignment"
      assert map.error_type_label == "Type Assignment"
    end
  end

  describe "group_by_file/1" do
    test "groups diagnostics by file" do
      diagnostics = [
        %Diagnostic{file: "a.ts", line: 1, column: 1, category: :error, code: "TS1", code_number: 1, message: "", error_type: :other},
        %Diagnostic{file: "b.ts", line: 1, column: 1, category: :error, code: "TS2", code_number: 2, message: "", error_type: :other},
        %Diagnostic{file: "a.ts", line: 2, column: 1, category: :error, code: "TS3", code_number: 3, message: "", error_type: :other}
      ]

      grouped = Diagnostic.group_by_file(diagnostics)

      assert map_size(grouped) == 2
      assert length(grouped["a.ts"]) == 2
      assert length(grouped["b.ts"]) == 1
    end
  end

  describe "group_by_type/1" do
    test "groups diagnostics by error type" do
      diagnostics = [
        %Diagnostic{file: "a.ts", line: 1, column: 1, category: :error, code: "TS2322", code_number: 2322, message: "", error_type: :type_assignment},
        %Diagnostic{file: "a.ts", line: 2, column: 1, category: :error, code: "TS2304", code_number: 2304, message: "", error_type: :name_resolution},
        %Diagnostic{file: "a.ts", line: 3, column: 1, category: :error, code: "TS2339", code_number: 2339, message: "", error_type: :property_access}
      ]

      grouped = Diagnostic.group_by_type(diagnostics)

      assert map_size(grouped) == 3
      assert length(grouped[:type_assignment]) == 1
      assert length(grouped[:name_resolution]) == 1
    end
  end

  describe "filter_by_category/2" do
    test "filters by category" do
      diagnostics = [
        %Diagnostic{file: "a.ts", line: 1, column: 1, category: :error, code: "TS1", code_number: 1, message: "", error_type: :other},
        %Diagnostic{file: "a.ts", line: 2, column: 1, category: :warning, code: "TS2", code_number: 2, message: "", error_type: :other},
        %Diagnostic{file: "a.ts", line: 3, column: 1, category: :error, code: "TS3", code_number: 3, message: "", error_type: :other}
      ]

      errors = Diagnostic.filter_by_category(diagnostics, :error)
      warnings = Diagnostic.filter_by_category(diagnostics, :warning)

      assert length(errors) == 2
      assert length(warnings) == 1
    end
  end

  describe "count_by_category/1" do
    test "counts by category" do
      diagnostics = [
        %Diagnostic{file: "a.ts", line: 1, column: 1, category: :error, code: "TS1", code_number: 1, message: "", error_type: :other},
        %Diagnostic{file: "a.ts", line: 2, column: 1, category: :warning, code: "TS2", code_number: 2, message: "", error_type: :other},
        %Diagnostic{file: "a.ts", line: 3, column: 1, category: :error, code: "TS3", code_number: 3, message: "", error_type: :other}
      ]

      counts = Diagnostic.count_by_category(diagnostics)

      assert counts[:error] == 2
      assert counts[:warning] == 1
    end
  end

  describe "summary/1" do
    test "generates summary statistics" do
      diagnostics = [
        %Diagnostic{file: "a.ts", line: 1, column: 1, category: :error, code: "TS2322", code_number: 2322, message: "", error_type: :type_assignment},
        %Diagnostic{file: "b.ts", line: 2, column: 1, category: :warning, code: "TS6133", code_number: 6133, message: "", error_type: :other},
        %Diagnostic{file: "a.ts", line: 3, column: 1, category: :error, code: "TS2304", code_number: 2304, message: "", error_type: :name_resolution}
      ]

      summary = Diagnostic.summary(diagnostics)

      assert summary.total == 3
      assert summary.errors == 2
      assert summary.warnings == 1
      assert summary.files_with_errors == 2
      assert summary.by_type[:type_assignment] == 1
      assert summary.by_type[:name_resolution] == 1
    end

    test "handles empty list" do
      summary = Diagnostic.summary([])

      assert summary.total == 0
      assert summary.errors == 0
      assert summary.warnings == 0
      assert summary.files_with_errors == 0
    end
  end
end
