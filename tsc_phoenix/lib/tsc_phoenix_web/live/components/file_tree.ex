defmodule TscPhoenixWeb.Live.Components.FileTree do
  @moduledoc """
  File tree component with error indicators.

  Displays project files in a tree structure with visual indicators
  for files containing errors or warnings.
  """

  use Phoenix.Component

  @doc """
  Renders a file tree with error indicators.

  ## Assigns
  - files: List of file paths
  - errors_by_file: Map of file path to list of errors
  - selected_file: Currently selected file path
  - on_select: Event name to send when file is selected
  """
  attr :files, :list, required: true
  attr :errors_by_file, :map, default: %{}
  attr :selected_file, :string, default: nil

  def file_tree(assigns) do
    tree = build_tree(assigns.files, assigns.errors_by_file)
    assigns = assign(assigns, :tree, tree)

    ~H"""
    <div class="file-tree bg-base-100 rounded-lg shadow overflow-hidden">
      <div class="p-2 bg-base-200 font-semibold text-sm flex items-center gap-2">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
        </svg>
        Project Files
      </div>
      <div class="overflow-auto max-h-96">
        <.tree_node node={@tree} level={0} selected={@selected_file} errors_by_file={@errors_by_file} />
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :level, :integer, required: true
  attr :selected, :string, default: nil
  attr :errors_by_file, :map, default: %{}

  defp tree_node(assigns) do
    ~H"""
    <div>
      <%= for {name, child} <- Enum.sort(@node) do %>
        <%= if is_map(child) and not Map.has_key?(child, :path) do %>
          <!-- Directory -->
          <details class="group" open={@level < 2}>
            <summary class={"flex items-center gap-1 px-2 py-1 hover:bg-base-200 cursor-pointer text-sm"} style={"padding-left: #{(@level + 1) * 12}px"}>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-warning group-open:rotate-90 transition-transform" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-warning" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-6l-2-2H5a2 2 0 00-2 2z" />
              </svg>
              <span class="truncate"><%= name %></span>
              <.directory_error_badge node={child} errors_by_file={@errors_by_file} />
            </summary>
            <.tree_node node={child} level={@level + 1} selected={@selected} errors_by_file={@errors_by_file} />
          </details>
        <% else %>
          <!-- File -->
          <% errors = Map.get(@errors_by_file, child.path, []) %>
          <% error_count = Enum.count(errors, &(&1[:category] == :error)) %>
          <% warning_count = Enum.count(errors, &(&1[:category] == :warning)) %>
          <button
            phx-click="select_file"
            phx-value-path={child.path}
            class={"flex items-center gap-1 px-2 py-1 hover:bg-base-200 cursor-pointer w-full text-left text-sm #{if @selected == child.path, do: "bg-primary/20"}"}
            style={"padding-left: #{(@level + 1) * 12 + 16}px"}
          >
            <.file_icon extension={Path.extname(name)} />
            <span class="truncate flex-1"><%= name %></span>
            <%= if error_count > 0 do %>
              <span class="badge badge-error badge-xs"><%= error_count %></span>
            <% end %>
            <%= if warning_count > 0 do %>
              <span class="badge badge-warning badge-xs"><%= warning_count %></span>
            <% end %>
          </button>
        <% end %>
      <% end %>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :errors_by_file, :map, required: true

  defp directory_error_badge(assigns) do
    # Count errors in all files under this directory
    {errors, warnings} = count_errors_in_tree(assigns.node, assigns.errors_by_file)
    assigns = assign(assigns, errors: errors, warnings: warnings)

    ~H"""
    <span class="flex-1"></span>
    <%= if @errors > 0 do %>
      <span class="badge badge-error badge-xs"><%= @errors %></span>
    <% end %>
    <%= if @warnings > 0 do %>
      <span class="badge badge-warning badge-xs"><%= @warnings %></span>
    <% end %>
    """
  end

  attr :extension, :string, required: true

  defp file_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" class={"h-4 w-4 #{file_icon_color(@extension)}"} fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """
  end

  defp file_icon_color(".ts"), do: "text-blue-500"
  defp file_icon_color(".tsx"), do: "text-blue-400"
  defp file_icon_color(".js"), do: "text-yellow-500"
  defp file_icon_color(".jsx"), do: "text-yellow-400"
  defp file_icon_color(".json"), do: "text-green-500"
  defp file_icon_color(_), do: "text-base-content/60"

  # Build a nested map representing the file tree
  defp build_tree(files, _errors_by_file) do
    files
    |> Enum.reduce(%{}, fn file, acc ->
      parts = Path.split(file)
      insert_path(acc, parts, file)
    end)
  end

  defp insert_path(tree, [name], full_path) do
    Map.put(tree, name, %{path: full_path})
  end

  defp insert_path(tree, [dir | rest], full_path) do
    subtree = Map.get(tree, dir, %{})
    Map.put(tree, dir, insert_path(subtree, rest, full_path))
  end

  defp count_errors_in_tree(node, errors_by_file) when is_map(node) do
    node
    |> Enum.reduce({0, 0}, fn {_name, child}, {errors, warnings} ->
      if Map.has_key?(child, :path) do
        # It's a file
        file_errors = Map.get(errors_by_file, child.path, [])
        e = Enum.count(file_errors, &(&1[:category] == :error))
        w = Enum.count(file_errors, &(&1[:category] == :warning))
        {errors + e, warnings + w}
      else
        # It's a directory
        {e, w} = count_errors_in_tree(child, errors_by_file)
        {errors + e, warnings + w}
      end
    end)
  end
end
