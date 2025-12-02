defmodule TscPhoenixWeb.Live.Components.CodePreview do
  @moduledoc """
  Code preview component with error highlighting.

  Displays source code with highlighted error lines and inline diagnostics.
  """

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  @doc """
  Renders a code preview with error highlighting.

  ## Assigns
  - file_path: Path to the file being displayed
  - content: File content as string
  - errors: List of errors for this file
  - focus_line: Line number to scroll to (optional)
  """
  attr :file_path, :string, required: true
  attr :content, :string, default: nil
  attr :errors, :list, default: []
  attr :focus_line, :integer, default: nil

  def code_preview(assigns) do
    content = assigns.content || read_file(assigns.file_path)
    lines = if content, do: String.split(content, "\n"), else: []
    error_lines = MapSet.new(Enum.map(assigns.errors, & &1[:line]))

    assigns =
      assigns
      |> assign(:lines, lines)
      |> assign(:error_lines, error_lines)
      |> assign(:errors_by_line, group_errors_by_line(assigns.errors))

    ~H"""
    <div class="code-preview bg-base-100 rounded-lg shadow overflow-hidden">
      <!-- Header -->
      <div class="p-2 bg-base-200 font-mono text-sm flex items-center gap-2 border-b border-base-300">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4" />
        </svg>
        <span class="truncate flex-1"><%= Path.basename(@file_path) %></span>
        <%= if length(@errors) > 0 do %>
          <span class="badge badge-error badge-sm"><%= length(@errors) %> issues</span>
        <% end %>
      </div>

      <!-- Code Content -->
      <%= if length(@lines) > 0 do %>
        <div class="overflow-auto max-h-[500px]" id={"code-preview-#{hash(@file_path)}"}>
          <table class="w-full font-mono text-sm">
            <tbody>
              <%= for {line, idx} <- Enum.with_index(@lines, 1) do %>
                <% has_error = MapSet.member?(@error_lines, idx) %>
                <% line_errors = Map.get(@errors_by_line, idx, []) %>
                <tr
                  id={"line-#{idx}"}
                  class={"hover:bg-base-200 #{if has_error, do: "bg-error/10", else: ""}"}
                >
                  <!-- Line number -->
                  <td class={"w-12 text-right px-2 py-0.5 select-none text-base-content/40 border-r border-base-300 #{if has_error, do: "bg-error/20 text-error"}"}>
                    <%= idx %>
                  </td>
                  <!-- Error indicator -->
                  <td class="w-6 text-center">
                    <%= if has_error do %>
                      <span class="tooltip tooltip-right" data-tip={error_tooltip(line_errors)}>
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-error" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                        </svg>
                      </span>
                    <% end %>
                  </td>
                  <!-- Code content -->
                  <td class="px-2 py-0.5 whitespace-pre">
                    <.highlight_code line={line} errors={line_errors} />
                  </td>
                </tr>
                <!-- Inline error messages -->
                <%= if has_error do %>
                  <%= for error <- line_errors do %>
                    <tr class="bg-error/5">
                      <td colspan="3" class="px-4 py-1">
                        <div class="flex items-start gap-2 text-error text-xs">
                          <span class="badge badge-error badge-xs mt-0.5"><%= error[:code] %></span>
                          <span><%= error[:message] %></span>
                        </div>
                      </td>
                    </tr>
                  <% end %>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      <% else %>
        <div class="p-4 text-center text-base-content/60">
          <%= if @content == nil do %>
            <p>Unable to read file</p>
          <% else %>
            <p>Empty file</p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :line, :string, required: true
  attr :errors, :list, default: []

  defp highlight_code(assigns) do
    # Basic syntax highlighting for TypeScript
    highlighted = apply_syntax_highlighting(assigns.line)
    assigns = assign(assigns, :highlighted, highlighted)

    ~H"""
    <%= raw(@highlighted) %>
    """
  end

  defp apply_syntax_highlighting(line) do
    line
    |> html_escape()
    |> highlight_strings()
    |> highlight_comments()
    |> highlight_keywords()
    |> highlight_types()
    |> highlight_numbers()
  end

  defp html_escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp highlight_strings(text) do
    # Match single and double quoted strings
    Regex.replace(~r/(['"`])(.*?)\1/, text, fn _, quote, content ->
      ~s(<span class="text-green-500">#{quote}#{content}#{quote}</span>)
    end)
  end

  defp highlight_comments(text) do
    # Match // comments
    Regex.replace(~r/(\/\/.*)$/, text, fn _, comment ->
      ~s(<span class="text-base-content/50 italic">#{comment}</span>)
    end)
  end

  defp highlight_keywords(text) do
    keywords = ~w(
      const let var function class interface type enum
      if else for while do switch case break continue return
      import export from default as async await
      try catch finally throw new this super
      extends implements
      public private protected static readonly
      true false null undefined
    )

    Enum.reduce(keywords, text, fn keyword, acc ->
      Regex.replace(~r/\b(#{keyword})\b/, acc, fn _, word ->
        ~s(<span class="text-purple-500 font-semibold">#{word}</span>)
      end)
    end)
  end

  defp highlight_types(text) do
    types = ~w(string number boolean any void never unknown object)

    Enum.reduce(types, text, fn type_name, acc ->
      Regex.replace(~r/:\s*(#{type_name})\b/, acc, fn full, type ->
        String.replace(full, type, ~s(<span class="text-blue-400">#{type}</span>))
      end)
    end)
  end

  defp highlight_numbers(text) do
    Regex.replace(~r/\b(\d+\.?\d*)\b/, text, fn _, num ->
      ~s(<span class="text-orange-400">#{num}</span>)
    end)
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> nil
    end
  end

  defp group_errors_by_line(errors) do
    errors
    |> Enum.group_by(& &1[:line])
  end

  defp error_tooltip(errors) do
    errors
    |> Enum.map(& &1[:message])
    |> Enum.join("\n")
  end

  defp hash(string) do
    :crypto.hash(:md5, string) |> Base.encode16(case: :lower) |> String.slice(0..7)
  end
end
