defmodule TscLsp.Server do
  @moduledoc """
  Language Server Protocol implementation for the TypeScript compiler.

  This server provides IDE features like:
  - Real-time diagnostics (errors, warnings)
  - Document synchronization
  - Hover information
  - Go to definition
  - Document symbols

  ## Usage

  Start the server via the mix task:

      mix tsc_lsp

  Or programmatically:

      TscLsp.Server.start_link([])

  ## Supported LSP Features

  - `initialize` / `shutdown` - Server lifecycle
  - `textDocument/didOpen` - Track open documents
  - `textDocument/didChange` - Update document content
  - `textDocument/didSave` - Trigger type checking
  - `textDocument/didClose` - Clean up document state
  - `textDocument/publishDiagnostics` - Report errors/warnings
  - `textDocument/hover` - Show type information on hover
  - `textDocument/definition` - Go to definition
  - `textDocument/documentSymbol` - Document outline
  """

  use GenLSP

  alias GenLSP.Enumerations.{
    DiagnosticSeverity,
    SymbolKind,
    TextDocumentSyncKind
  }

  alias GenLSP.Structures.{
    Diagnostic,
    DocumentSymbol,
    Hover,
    InitializeParams,
    InitializeResult,
    Location,
    MarkupContent,
    Position,
    Range,
    ServerCapabilities,
    TextDocumentSyncOptions,
    SaveOptions
  }

  alias GenLSP.Requests.{
    Initialize,
    Shutdown,
    TextDocumentHover,
    TextDocumentDefinition,
    TextDocumentDocumentSymbol
  }

  alias GenLSP.Notifications.{
    Exit,
    Initialized,
    TextDocumentDidChange,
    TextDocumentDidClose,
    TextDocumentDidOpen,
    TextDocumentDidSave,
    TextDocumentPublishDiagnostics
  }

  require Logger

  @cli_path "/Users/srikanthkyatham/Personal/moonbit/pure-moonbit-cli/src/moonbit/target/native/release/build/cli/cli.exe"

  defstruct [
    :root_uri,
    :root_path,
    :client_capabilities,
    documents: %{},
    diagnostics_cache: %{},
    check_on_save: true,
    check_on_change: false
  ]

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(args) do
    {buffer, args} = Keyword.pop(args, :buffer)
    {assigns, args} = Keyword.pop(args, :assigns)
    {task_supervisor, args} = Keyword.pop(args, :task_supervisor)
    {name, args} = Keyword.pop(args, :name, __MODULE__)

    opts =
      [buffer: buffer, assigns: assigns, task_supervisor: task_supervisor, name: name]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    GenLSP.start_link(__MODULE__, args, opts)
  end

  # ============================================================================
  # GenLSP Callbacks
  # ============================================================================

  @impl true
  def init(lsp, args) do
    cli_path = Keyword.get(args, :cli_path, @cli_path)

    {:ok,
     assign(lsp,
       documents: %{},
       diagnostics_cache: %{},
       cli_path: cli_path,
       root_uri: nil,
       root_path: nil,
       exit_code: 1
     )}
  end

  # ============================================================================
  # Request Handlers
  # ============================================================================

  @impl true
  def handle_request(%Initialize{params: %InitializeParams{} = params}, lsp) do
    root_uri = params.root_uri

    root_path =
      if root_uri do
        URI.parse(root_uri).path
      else
        params.root_path
      end

    Logger.info("TscLsp initialized with root: #{root_path}")

    {:reply,
     %InitializeResult{
       capabilities: %ServerCapabilities{
         text_document_sync: %TextDocumentSyncOptions{
           open_close: true,
           change: TextDocumentSyncKind.full(),
           save: %SaveOptions{include_text: true}
         },
         hover_provider: true,
         definition_provider: true,
         document_symbol_provider: true,
         # Future capabilities
         completion_provider: nil,
         references_provider: false,
         document_formatting_provider: false,
         rename_provider: false,
         code_action_provider: false
       },
       server_info: %{
         name: "tsc-lsp",
         version: "0.1.0"
       }
     },
     assign(lsp,
       root_uri: root_uri,
       root_path: root_path,
       client_capabilities: params.capabilities
     )}
  end

  @impl true
  def handle_request(%Shutdown{}, lsp) do
    Logger.info("TscLsp shutting down")
    {:reply, nil, assign(lsp, exit_code: 0)}
  end

  @impl true
  def handle_request(
        %TextDocumentHover{
          params: %{text_document: %{uri: uri}, position: position}
        },
        lsp
      ) do
    Logger.debug("Hover request at #{uri}:#{position.line}:#{position.character}")

    file_path = uri_to_path(uri)

    hover_result =
      case get_hover_info(lsp.assigns.cli_path, file_path, position.line + 1, position.character + 1) do
        {:ok, info} ->
          %Hover{
            contents: %MarkupContent{
              kind: "markdown",
              value: "```typescript\n#{info}\n```"
            }
          }

        {:error, _} ->
          nil
      end

    {:reply, hover_result, lsp}
  end

  @impl true
  def handle_request(
        %TextDocumentDefinition{
          params: %{text_document: %{uri: uri}, position: position}
        },
        lsp
      ) do
    Logger.debug("Definition request at #{uri}:#{position.line}:#{position.character}")

    file_path = uri_to_path(uri)

    definition_result =
      case get_definition(lsp.assigns.cli_path, file_path, position.line + 1, position.character + 1) do
        {:ok, %{file: def_file, line: line, column: col}} ->
          %Location{
            uri: path_to_uri(def_file),
            range: %Range{
              start: %Position{line: max(0, line - 1), character: max(0, col - 1)},
              end: %Position{line: max(0, line - 1), character: col}
            }
          }

        {:error, _} ->
          nil
      end

    {:reply, definition_result, lsp}
  end

  @impl true
  def handle_request(
        %TextDocumentDocumentSymbol{
          params: %{text_document: %{uri: uri}}
        },
        lsp
      ) do
    Logger.debug("Document symbols request for #{uri}")

    file_path = uri_to_path(uri)

    symbols =
      case get_document_symbols(lsp.assigns.cli_path, file_path) do
        {:ok, symbols} -> symbols
        {:error, _} -> []
      end

    {:reply, symbols, lsp}
  end

  # Catch-all for unhandled requests
  @impl true
  def handle_request(request, lsp) do
    Logger.debug("Unhandled request: #{inspect(request.__struct__)}")
    {:reply, nil, lsp}
  end

  # ============================================================================
  # Notification Handlers
  # ============================================================================

  @impl true
  def handle_notification(%Initialized{}, lsp) do
    Logger.info("TscLsp client initialized")
    GenLSP.log(lsp, "[tsc-lsp] TypeScript Language Server ready")
    {:noreply, lsp}
  end

  @impl true
  def handle_notification(%Exit{}, lsp) do
    Logger.info("TscLsp exiting")
    System.halt(lsp.assigns.exit_code)
    {:noreply, lsp}
  end

  @impl true
  def handle_notification(
        %TextDocumentDidOpen{
          params: %{text_document: %{uri: uri, text: text}}
        },
        lsp
      ) do
    Logger.debug("Document opened: #{uri}")

    lsp =
      lsp
      |> put_document(uri, text)
      |> check_document(uri, text)

    {:noreply, lsp}
  end

  @impl true
  def handle_notification(
        %TextDocumentDidChange{
          params: %{text_document: %{uri: uri}, content_changes: changes}
        },
        lsp
      ) do
    Logger.debug("Document changed: #{uri}")

    # Full sync mode - take the last change which contains the full document
    text =
      case List.last(changes) do
        %{text: text} -> text
        _ -> get_document(lsp, uri) || ""
      end

    lsp = put_document(lsp, uri, text)

    # Optionally check on change (can be noisy)
    lsp =
      if lsp.assigns[:check_on_change] do
        check_document(lsp, uri, text)
      else
        lsp
      end

    {:noreply, lsp}
  end

  @impl true
  def handle_notification(
        %TextDocumentDidSave{
          params: %{text_document: %{uri: uri}} = params
        },
        lsp
      ) do
    Logger.debug("Document saved: #{uri}")

    text = Map.get(params, :text) || get_document(lsp, uri) || ""

    lsp =
      lsp
      |> put_document(uri, text)
      |> check_document(uri, text)

    {:noreply, lsp}
  end

  @impl true
  def handle_notification(
        %TextDocumentDidClose{
          params: %{text_document: %{uri: uri}}
        },
        lsp
      ) do
    Logger.debug("Document closed: #{uri}")

    # Clear diagnostics for closed document
    GenLSP.notify(lsp, %TextDocumentPublishDiagnostics{
      params: %{uri: uri, diagnostics: []}
    })

    {:noreply, remove_document(lsp, uri)}
  end

  @impl true
  def handle_notification(notification, lsp) do
    Logger.debug("Unhandled notification: #{inspect(notification.__struct__)}")
    {:noreply, lsp}
  end

  # ============================================================================
  # Private Helpers - Document Management
  # ============================================================================

  defp put_document(lsp, uri, text) do
    documents = Map.put(lsp.assigns.documents, uri, text)
    assign(lsp, documents: documents)
  end

  defp get_document(lsp, uri) do
    Map.get(lsp.assigns.documents, uri)
  end

  defp remove_document(lsp, uri) do
    documents = Map.delete(lsp.assigns.documents, uri)
    diagnostics_cache = Map.delete(lsp.assigns.diagnostics_cache, uri)
    assign(lsp, documents: documents, diagnostics_cache: diagnostics_cache)
  end

  # ============================================================================
  # Private Helpers - Type Checking
  # ============================================================================

  defp check_document(lsp, uri, _text) do
    file_path = uri_to_path(uri)

    if String.ends_with?(file_path, [".ts", ".tsx"]) do
      Task.start(fn ->
        diagnostics = run_type_check(lsp.assigns.cli_path, file_path)
        publish_diagnostics(lsp, uri, diagnostics)
      end)
    end

    lsp
  end

  defp run_type_check(cli_path, file_path) do
    Logger.debug("Running type check on: #{file_path}")

    args = [file_path, "--noEmit", "--reportDiagnostics"]

    case System.cmd(cli_path, args, stderr_to_stdout: true) do
      {output, _exit_code} ->
        parse_diagnostics(output, file_path)
    end
  rescue
    e ->
      Logger.error("Type check failed: #{inspect(e)}")
      []
  end

  defp parse_diagnostics(output, file_path) do
    output
    |> String.split("\n")
    |> Enum.map(&parse_diagnostic_line(&1, file_path))
    |> Enum.reject(&is_nil/1)
  end

  defp parse_diagnostic_line(line, _file_path) do
    # Format: file_path:line:column - category TScode: message
    regex = ~r/^(.+?):(\d+):(\d+) - (error|warning|suggestion|message) (TS\d+): (.+)$/

    case Regex.run(regex, line) do
      [_, _file, line_num, col, category, code, message] ->
        line = String.to_integer(line_num) - 1
        col = String.to_integer(col) - 1

        %Diagnostic{
          range: %Range{
            start: %Position{line: max(0, line), character: max(0, col)},
            end: %Position{line: max(0, line), character: max(0, col + 1)}
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

  defp category_to_severity("error"), do: DiagnosticSeverity.error()
  defp category_to_severity("warning"), do: DiagnosticSeverity.warning()
  defp category_to_severity("suggestion"), do: DiagnosticSeverity.hint()
  defp category_to_severity("message"), do: DiagnosticSeverity.information()
  defp category_to_severity(_), do: DiagnosticSeverity.error()

  defp publish_diagnostics(lsp, uri, diagnostics) do
    Logger.debug("Publishing #{length(diagnostics)} diagnostics for #{uri}")

    GenLSP.notify(lsp, %TextDocumentPublishDiagnostics{
      params: %{uri: uri, diagnostics: diagnostics}
    })
  end

  # ============================================================================
  # Private Helpers - Hover
  # ============================================================================

  defp get_hover_info(cli_path, file_path, line, column) do
    args = [file_path, "--quickinfo", "#{line}:#{column}"]

    case System.cmd(cli_path, args, stderr_to_stdout: true) do
      {output, 0} ->
        # Parse the quickinfo output
        info = String.trim(output)

        if info != "" and not String.contains?(info, "error") do
          {:ok, info}
        else
          {:error, :no_info}
        end

      _ ->
        {:error, :command_failed}
    end
  rescue
    _ -> {:error, :exception}
  end

  # ============================================================================
  # Private Helpers - Go to Definition
  # ============================================================================

  defp get_definition(cli_path, file_path, line, column) do
    args = [file_path, "--definition", "#{line}:#{column}"]

    case System.cmd(cli_path, args, stderr_to_stdout: true) do
      {output, 0} ->
        parse_definition_output(output)

      _ ->
        {:error, :command_failed}
    end
  rescue
    _ -> {:error, :exception}
  end

  defp parse_definition_output(output) do
    # Expected format: file:line:column
    regex = ~r/^(.+?):(\d+):(\d+)/

    case Regex.run(regex, String.trim(output)) do
      [_, file, line, col] ->
        {:ok, %{file: file, line: String.to_integer(line), column: String.to_integer(col)}}

      _ ->
        {:error, :parse_failed}
    end
  end

  # ============================================================================
  # Private Helpers - Document Symbols
  # ============================================================================

  defp get_document_symbols(cli_path, file_path) do
    args = [file_path, "--symbols", "--json"]

    case System.cmd(cli_path, args, stderr_to_stdout: true) do
      {output, 0} ->
        parse_symbols_output(output)

      _ ->
        {:error, :command_failed}
    end
  rescue
    _ -> {:error, :exception}
  end

  defp parse_symbols_output(output) do
    case Jason.decode(output) do
      {:ok, symbols} when is_list(symbols) ->
        {:ok, Enum.map(symbols, &parse_symbol/1)}

      _ ->
        {:error, :parse_failed}
    end
  end

  defp parse_symbol(%{"name" => name, "kind" => kind, "range" => range} = symbol) do
    %DocumentSymbol{
      name: name,
      kind: symbol_kind(kind),
      range: parse_range(range),
      selection_range: parse_range(Map.get(symbol, "selectionRange", range)),
      children: parse_children(Map.get(symbol, "children", []))
    }
  end

  defp parse_symbol(_), do: nil

  defp parse_children(children) when is_list(children) do
    children
    |> Enum.map(&parse_symbol/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_children(_), do: []

  defp parse_range(%{"start" => %{"line" => sl, "character" => sc}, "end" => %{"line" => el, "character" => ec}}) do
    %Range{
      start: %Position{line: sl, character: sc},
      end: %Position{line: el, character: ec}
    }
  end

  defp parse_range(_), do: nil

  defp symbol_kind("function"), do: SymbolKind.function()
  defp symbol_kind("class"), do: SymbolKind.class()
  defp symbol_kind("interface"), do: SymbolKind.interface()
  defp symbol_kind("enum"), do: SymbolKind.enum()
  defp symbol_kind("variable"), do: SymbolKind.variable()
  defp symbol_kind("constant"), do: SymbolKind.constant()
  defp symbol_kind("property"), do: SymbolKind.property()
  defp symbol_kind("method"), do: SymbolKind.method()
  defp symbol_kind("constructor"), do: SymbolKind.constructor()
  defp symbol_kind("type"), do: SymbolKind.type_parameter()
  defp symbol_kind("namespace"), do: SymbolKind.namespace()
  defp symbol_kind("module"), do: SymbolKind.module()
  defp symbol_kind(_), do: SymbolKind.variable()

  # ============================================================================
  # Private Helpers - URI/Path Conversion
  # ============================================================================

  defp uri_to_path(uri) do
    uri
    |> URI.parse()
    |> Map.get(:path)
    |> URI.decode()
  end

  defp path_to_uri(path) do
    "file://#{path}"
  end
end
