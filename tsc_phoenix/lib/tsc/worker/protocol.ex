defmodule TSC.Worker.Protocol do
  @moduledoc """
  JSON protocol for communicating with MoonBit workers.

  Defines request/response structures for the IPC protocol.
  """

  @doc """
  Encode a check request to JSON.
  """
  @spec encode_check_request(map()) :: String.t()
  def encode_check_request(request) do
    %{
      "jsonrpc" => "2.0",
      "id" => request[:id] || generate_id(),
      "method" => "check",
      "params" => %{
        "file" => request.file,
        "content" => request[:content],
        "imported_types" => request[:imported_types] || %{}
      }
    }
    |> Jason.encode!()
  end

  @doc """
  Encode a parse request to JSON.
  """
  @spec encode_parse_request(map()) :: String.t()
  def encode_parse_request(request) do
    %{
      "jsonrpc" => "2.0",
      "id" => request[:id] || generate_id(),
      "method" => "parse",
      "params" => %{
        "file" => request.file,
        "content" => request[:content]
      }
    }
    |> Jason.encode!()
  end

  @doc """
  Encode an extract imports request to JSON.
  """
  @spec encode_extract_imports_request(map()) :: String.t()
  def encode_extract_imports_request(request) do
    %{
      "jsonrpc" => "2.0",
      "id" => request[:id] || generate_id(),
      "method" => "extract_imports",
      "params" => %{
        "file" => request.file,
        "content" => request[:content]
      }
    }
    |> Jason.encode!()
  end

  @doc """
  Decode a JSON-RPC response from the worker.
  """
  @spec decode_response(String.t()) :: {:ok, map()} | {:error, term()}
  def decode_response(json) do
    case Jason.decode(json) do
      {:ok, %{"result" => result, "id" => id}} ->
        {:ok, %{id: id, result: parse_result(result)}}

      {:ok, %{"error" => error, "id" => id}} ->
        {:error, %{id: id, error: parse_error(error)}}

      {:error, reason} ->
        {:error, {:json_decode_error, reason}}
    end
  end

  @doc """
  Parse diagnostics from check result.
  """
  @spec parse_diagnostics(list()) :: list(map())
  def parse_diagnostics(diagnostics) when is_list(diagnostics) do
    Enum.map(diagnostics, fn d ->
      %{
        file: d["file"],
        line: d["line"],
        column: d["column"],
        end_line: d["endLine"],
        end_column: d["endColumn"],
        code: d["code"],
        category: parse_category(d["category"]),
        message: d["message"]
      }
    end)
  end

  def parse_diagnostics(_), do: []

  @doc """
  Parse exported types from check result.
  """
  @spec parse_exports(map() | nil) :: map()
  def parse_exports(nil), do: %{}
  def parse_exports(exports) when is_map(exports), do: exports

  # ============================================================================
  # Private Helpers
  # ============================================================================

  defp generate_id do
    :erlang.unique_integer([:positive])
  end

  defp parse_result(result) when is_map(result) do
    %{
      diagnostics: parse_diagnostics(result["diagnostics"]),
      exports: parse_exports(result["exports"]),
      imports: result["imports"] || [],
      parse_time_ms: result["parseTimeMs"],
      check_time_ms: result["checkTimeMs"]
    }
  end

  defp parse_result(result), do: result

  defp parse_error(%{"code" => code, "message" => message}) do
    %{code: code, message: message}
  end

  defp parse_error(error), do: error

  defp parse_category("error"), do: :error
  defp parse_category("warning"), do: :warning
  defp parse_category("suggestion"), do: :suggestion
  defp parse_category("message"), do: :message
  defp parse_category(_), do: :error
end
