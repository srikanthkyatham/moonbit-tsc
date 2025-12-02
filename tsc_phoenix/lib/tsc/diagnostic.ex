defmodule TSC.Diagnostic do
  @moduledoc """
  TypeScript diagnostic parsing and categorization.

  Parses CLI output and categorizes errors by type for better
  reporting and filtering.
  """

  @type t :: %__MODULE__{
          file: String.t(),
          line: pos_integer(),
          column: pos_integer(),
          end_line: pos_integer() | nil,
          end_column: pos_integer() | nil,
          category: :error | :warning | :suggestion | :message,
          code: String.t(),
          code_number: pos_integer(),
          message: String.t(),
          error_type: atom()
        }

  defstruct [
    :file,
    :line,
    :column,
    :end_line,
    :end_column,
    :category,
    :code,
    :code_number,
    :message,
    :error_type
  ]

  # Error code ranges for categorization
  @name_resolution_codes 2304..2318
  @type_assignment_codes 2320..2380
  @function_call_codes 2554..2575
  @property_access_codes 2339..2341
  @class_codes 2390..2420
  @module_codes 2306..2307
  @generic_codes 2314..2315

  @doc """
  Parse diagnostic output from CLI.
  """
  @spec parse(String.t()) :: [t()]
  def parse(output) when is_binary(output) do
    output
    |> String.split("\n")
    |> Enum.map(&parse_line/1)
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Parse a single diagnostic line.

  Format: `file:line:column - category TScode: message`
  """
  @spec parse_line(String.t()) :: t() | nil
  def parse_line(line) do
    # Primary format: file_path:line:column - category TScode: message
    regex = ~r/^(.+?):(\d+):(\d+) - (error|warning|suggestion|message) (TS(\d+)): (.+)$/

    case Regex.run(regex, line) do
      [_, file, line_num, col, category, code, code_num, message] ->
        code_number = String.to_integer(code_num)

        %__MODULE__{
          file: file,
          line: String.to_integer(line_num),
          column: String.to_integer(col),
          end_line: nil,
          end_column: nil,
          category: String.to_atom(category),
          code: code,
          code_number: code_number,
          message: message,
          error_type: categorize_error(code_number)
        }

      _ ->
        nil
    end
  end

  @doc """
  Categorize an error by its code number.
  """
  @spec categorize_error(pos_integer()) :: atom()
  def categorize_error(code) when code in @name_resolution_codes, do: :name_resolution
  def categorize_error(code) when code in @type_assignment_codes, do: :type_assignment
  def categorize_error(code) when code in @function_call_codes, do: :function_call
  def categorize_error(code) when code in @property_access_codes, do: :property_access
  def categorize_error(code) when code in @class_codes, do: :class_error
  def categorize_error(code) when code in @module_codes, do: :module_error
  def categorize_error(code) when code in @generic_codes, do: :generic_type
  def categorize_error(2769), do: :overload_error
  def categorize_error(2345), do: :argument_type
  def categorize_error(2551), do: :spelling_suggestion
  def categorize_error(2532), do: :null_check
  def categorize_error(2531), do: :null_check
  def categorize_error(_), do: :other

  @doc """
  Get a human-readable label for an error type.
  """
  @spec error_type_label(atom()) :: String.t()
  def error_type_label(:name_resolution), do: "Name Resolution"
  def error_type_label(:type_assignment), do: "Type Assignment"
  def error_type_label(:function_call), do: "Function Call"
  def error_type_label(:property_access), do: "Property Access"
  def error_type_label(:class_error), do: "Class Error"
  def error_type_label(:module_error), do: "Module Error"
  def error_type_label(:generic_type), do: "Generic Type"
  def error_type_label(:overload_error), do: "Overload Resolution"
  def error_type_label(:argument_type), do: "Argument Type"
  def error_type_label(:spelling_suggestion), do: "Spelling"
  def error_type_label(:null_check), do: "Null Check"
  def error_type_label(:other), do: "Other"

  @doc """
  Convert diagnostic struct to a map for JSON serialization.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = diag) do
    %{
      file: diag.file,
      line: diag.line,
      column: diag.column,
      end_line: diag.end_line,
      end_column: diag.end_column,
      category: to_string(diag.category),
      code: diag.code,
      code_number: diag.code_number,
      message: diag.message,
      error_type: to_string(diag.error_type),
      error_type_label: error_type_label(diag.error_type)
    }
  end

  @doc """
  Group diagnostics by file.
  """
  @spec group_by_file([t()]) :: %{String.t() => [t()]}
  def group_by_file(diagnostics) do
    Enum.group_by(diagnostics, & &1.file)
  end

  @doc """
  Group diagnostics by error type.
  """
  @spec group_by_type([t()]) :: %{atom() => [t()]}
  def group_by_type(diagnostics) do
    Enum.group_by(diagnostics, & &1.error_type)
  end

  @doc """
  Filter diagnostics by category.
  """
  @spec filter_by_category([t()], atom()) :: [t()]
  def filter_by_category(diagnostics, category) do
    Enum.filter(diagnostics, &(&1.category == category))
  end

  @doc """
  Count diagnostics by category.
  """
  @spec count_by_category([t()]) :: %{atom() => non_neg_integer()}
  def count_by_category(diagnostics) do
    diagnostics
    |> Enum.group_by(& &1.category)
    |> Enum.map(fn {k, v} -> {k, length(v)} end)
    |> Map.new()
  end

  @doc """
  Get summary statistics for diagnostics.
  """
  @spec summary([t()]) :: map()
  def summary(diagnostics) do
    by_category = count_by_category(diagnostics)
    by_type = diagnostics |> group_by_type() |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Map.new()
    by_file = diagnostics |> group_by_file() |> Enum.map(fn {k, v} -> {k, length(v)} end) |> Map.new()

    %{
      total: length(diagnostics),
      errors: Map.get(by_category, :error, 0),
      warnings: Map.get(by_category, :warning, 0),
      suggestions: Map.get(by_category, :suggestion, 0),
      by_type: by_type,
      files_with_errors: map_size(by_file)
    }
  end
end
