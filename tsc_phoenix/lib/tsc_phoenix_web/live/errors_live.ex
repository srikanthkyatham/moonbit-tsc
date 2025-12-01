defmodule TscPhoenixWeb.ErrorsLive do
  @moduledoc """
  Enhanced error browser page for viewing and filtering diagnostics
  with file tree navigation and code preview.
  """

  use TscPhoenixWeb, :live_view

  import TscPhoenixWeb.Live.Components.FileTree
  import TscPhoenixWeb.Live.Components.CodePreview

  alias TSC.Cache.ErrorStore

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "compiler:updates")
    end

    # Load projects and errors from ETS
    projects = ErrorStore.list_projects()
    {selected_project, errors} = load_latest_errors()

    socket =
      socket
      |> assign(:page_title, "Errors")
      |> assign(:projects, projects)
      |> assign(:selected_project, selected_project)
      |> assign(:errors, errors)
      |> assign(:filter_category, "all")
      |> assign(:filter_type, "all")
      |> assign(:search, "")
      |> assign(:selected_file, nil)
      |> assign(:selected_file_content, nil)
      |> assign(:sort_by, :file)
      |> assign(:sort_dir, :asc)
      |> assign(:view_mode, :list)  # :list or :split

    {:ok, socket}
  end

  defp load_latest_errors do
    case ErrorStore.get_latest() do
      {:ok, project, diagnostics, _timestamp} ->
        {project, Enum.map(diagnostics, &format_diagnostic/1)}
      :not_found ->
        {nil, []}
    end
  end

  defp load_project_errors(project_path) do
    case ErrorStore.get(project_path) do
      {:ok, diagnostics, _timestamp} ->
        Enum.map(diagnostics, &format_diagnostic/1)
      :not_found ->
        []
    end
  end

  @impl true
  def handle_info({:file_check_stop, data}, socket) do
    new_errors =
      case data do
        %{result: {:ok, %{diagnostics: diags}}} when is_list(diags) ->
          # Convert diagnostics to maps if needed
          formatted = Enum.map(diags, &format_diagnostic/1)
          formatted ++ socket.assigns.errors
        _ ->
          socket.assigns.errors
      end
      |> Enum.uniq_by(fn error ->
        {Map.get(error, :file), Map.get(error, :line), Map.get(error, :column), Map.get(error, :code)}
      end)
      |> Enum.take(500)

    {:noreply, assign(socket, :errors, new_errors)}
  end

  @impl true
  def handle_info({:incremental_check_complete, result}, socket) do
    formatted = Enum.map(result.diagnostics, &format_diagnostic/1)
    projects = ErrorStore.list_projects()
    {selected_project, _} = load_latest_errors()

    socket =
      socket
      |> assign(:errors, formatted)
      |> assign(:projects, projects)
      |> assign(:selected_project, selected_project)

    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("filter_category", %{"category" => category}, socket) do
    {:noreply, assign(socket, :filter_category, category)}
  end

  @impl true
  def handle_event("filter_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :filter_type, type)}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("select_project", %{"project" => project}, socket) do
    errors = load_project_errors(project)

    socket =
      socket
      |> assign(:selected_project, project)
      |> assign(:errors, errors)
      |> assign(:selected_file, nil)
      |> assign(:selected_file_content, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear", _, socket) do
    socket =
      socket
      |> assign(:errors, [])
      |> assign(:selected_file, nil)
      |> assign(:selected_file_content, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_file", %{"path" => path}, socket) do
    content = case File.read(path) do
      {:ok, content} -> content
      {:error, _} -> nil
    end

    socket =
      socket
      |> assign(:selected_file, path)
      |> assign(:selected_file_content, content)
      |> assign(:view_mode, :split)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_error", %{"file" => file, "line" => line}, socket) do
    content = case File.read(file) do
      {:ok, content} -> content
      {:error, _} -> nil
    end

    socket =
      socket
      |> assign(:selected_file, file)
      |> assign(:selected_file_content, content)
      |> assign(:focus_line, String.to_integer(line))
      |> assign(:view_mode, :split)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_preview", _, socket) do
    socket =
      socket
      |> assign(:selected_file, nil)
      |> assign(:selected_file_content, nil)
      |> assign(:view_mode, :list)

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_view", _, socket) do
    new_mode = if socket.assigns.view_mode == :list, do: :split, else: :list
    {:noreply, assign(socket, :view_mode, new_mode)}
  end

  @impl true
  def handle_event("sort", %{"by" => by}, socket) do
    by_atom = String.to_existing_atom(by)

    {sort_by, sort_dir} =
      if socket.assigns.sort_by == by_atom do
        # Toggle direction
        new_dir = if socket.assigns.sort_dir == :asc, do: :desc, else: :asc
        {by_atom, new_dir}
      else
        {by_atom, :asc}
      end

    {:noreply, assign(socket, sort_by: sort_by, sort_dir: sort_dir)}
  end

  @impl true
  def render(assigns) do
    filtered_errors = filter_and_sort_errors(
      assigns.errors,
      assigns.filter_category,
      assigns.filter_type,
      assigns.search,
      assigns.sort_by,
      assigns.sort_dir
    )

    errors_by_file = group_by_file(assigns.errors)
    files = errors_by_file |> Map.keys() |> Enum.sort()
    error_types = get_error_types(assigns.errors)

    selected_file_errors = if assigns.selected_file do
      Map.get(errors_by_file, assigns.selected_file, [])
    else
      []
    end

    assigns =
      assigns
      |> assign(:filtered_errors, filtered_errors)
      |> assign(:errors_by_file, errors_by_file)
      |> assign(:files, files)
      |> assign(:error_types, error_types)
      |> assign(:selected_file_errors, selected_file_errors)

    ~H"""
    <div class="min-h-screen bg-base-200">
      <!-- Header -->
      <header class="navbar bg-base-100 shadow-lg sticky top-0 z-50">
        <div class="flex-1">
          <a href="/" class="btn btn-ghost text-xl">TSC Dashboard</a>
          <span class="text-xl font-bold px-4">/ Errors</span>
        </div>
        <div class="flex-none gap-2">
          <!-- Project Selector -->
          <%= if length(@projects) > 0 do %>
            <select class="select select-bordered" phx-change="select_project" name="project">
              <%= for proj <- @projects do %>
                <option value={proj.project} selected={@selected_project == proj.project}>
                  <%= Path.basename(proj.project) %> (<%= proj.errors %> errors)
                </option>
              <% end %>
            </select>
          <% end %>

          <!-- Search -->
          <div class="form-control">
            <input
              type="text"
              placeholder="Search..."
              class="input input-bordered w-48"
              value={@search}
              phx-keyup="search"
              phx-debounce="300"
              name="search"
            />
          </div>

          <!-- Category Filter -->
          <select class="select select-bordered" phx-change="filter_category" name="category">
            <option value="all" selected={@filter_category == "all"}>All Categories</option>
            <option value="error" selected={@filter_category == "error"}>Errors</option>
            <option value="warning" selected={@filter_category == "warning"}>Warnings</option>
            <option value="suggestion" selected={@filter_category == "suggestion"}>Suggestions</option>
          </select>

          <!-- Type Filter -->
          <select class="select select-bordered" phx-change="filter_type" name="type">
            <option value="all" selected={@filter_type == "all"}>All Types</option>
            <%= for type <- @error_types do %>
              <option value={type} selected={@filter_type == type}><%= format_error_type(type) %></option>
            <% end %>
          </select>

          <!-- View Toggle -->
          <button phx-click="toggle_view" class="btn btn-ghost btn-square">
            <%= if @view_mode == :split do %>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16" />
              </svg>
            <% else %>
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 17V7m0 10a2 2 0 01-2 2H5a2 2 0 01-2-2V7a2 2 0 012-2h2a2 2 0 012 2m0 10a2 2 0 002 2h2a2 2 0 002-2M9 7a2 2 0 012-2h2a2 2 0 012 2m0 10V7m0 10a2 2 0 002 2h2a2 2 0 002-2V7a2 2 0 00-2-2h-2a2 2 0 00-2 2" />
              </svg>
            <% end %>
          </button>

          <button phx-click="clear" class="btn btn-ghost">Clear All</button>
        </div>
      </header>

      <main class="container mx-auto p-4">
        <!-- Summary Badges -->
        <div class="mb-4 flex flex-wrap gap-2">
          <div class="badge badge-error gap-2 badge-lg">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <%= Enum.count(@errors, &(to_string(&1[:category]) == "error")) %> Errors
          </div>
          <div class="badge badge-warning gap-2 badge-lg">
            <%= Enum.count(@errors, &(to_string(&1[:category]) == "warning")) %> Warnings
          </div>
          <div class="badge badge-info gap-2 badge-lg">
            <%= length(@files) %> Files
          </div>
          <div class="badge gap-2 badge-lg">
            <%= length(@filtered_errors) %> Showing
          </div>
        </div>

        <!-- Main Content -->
        <div class={"grid gap-4 #{if @view_mode == :split, do: "grid-cols-1 lg:grid-cols-2", else: "grid-cols-1"}"}>
          <!-- Left Panel: File Tree + Error List -->
          <div class="space-y-4">
            <!-- File Tree (collapsible) -->
            <%= if length(@files) > 0 do %>
              <details class="bg-base-100 rounded-lg shadow" open>
                <summary class="p-3 cursor-pointer font-semibold">
                  Files with Issues (<%= length(@files) %>)
                </summary>
                <div class="p-2 pt-0">
                  <.file_tree
                    files={@files}
                    errors_by_file={@errors_by_file}
                    selected_file={@selected_file}
                  />
                </div>
              </details>
            <% end %>

            <!-- Error List -->
            <div class="bg-base-100 rounded-lg shadow">
              <div class="p-3 bg-base-200 font-semibold flex items-center justify-between">
                <span>Diagnostics</span>
                <div class="flex gap-2">
                  <button
                    phx-click="sort"
                    phx-value-by="file"
                    class={"btn btn-xs #{if @sort_by == :file, do: "btn-primary", else: "btn-ghost"}"}
                  >
                    File <%= sort_indicator(@sort_by, @sort_dir, :file) %>
                  </button>
                  <button
                    phx-click="sort"
                    phx-value-by="category"
                    class={"btn btn-xs #{if @sort_by == :category, do: "btn-primary", else: "btn-ghost"}"}
                  >
                    Severity <%= sort_indicator(@sort_by, @sort_dir, :category) %>
                  </button>
                  <button
                    phx-click="sort"
                    phx-value-by="code"
                    class={"btn btn-xs #{if @sort_by == :code, do: "btn-primary", else: "btn-ghost"}"}
                  >
                    Code <%= sort_indicator(@sort_by, @sort_dir, :code) %>
                  </button>
                </div>
              </div>

              <%= if length(@filtered_errors) > 0 do %>
                <div class="divide-y divide-base-200 max-h-[600px] overflow-y-auto">
                  <%= for error <- Enum.take(@filtered_errors, 100) do %>
                    <div
                      class={"p-3 hover:bg-base-200 cursor-pointer #{error_row_class(error[:category])} #{if @selected_file == error[:file], do: "bg-primary/10"}"}
                      phx-click="select_error"
                      phx-value-file={error[:file]}
                      phx-value-line={error[:line]}
                    >
                      <div class="flex items-start gap-2">
                        <.category_icon category={error[:category]} />
                        <div class="flex-1 min-w-0">
                          <div class="flex items-center gap-2 flex-wrap">
                            <span class="font-mono text-xs text-base-content/60 truncate max-w-xs">
                              <%= error[:file] %>:<%= error[:line] %>:<%= error[:column] %>
                            </span>
                            <span class="badge badge-sm"><%= error[:code] %></span>
                            <%= if error[:error_type] do %>
                              <span class="badge badge-ghost badge-xs"><%= format_error_type(error[:error_type]) %></span>
                            <% end %>
                          </div>
                          <p class="text-sm mt-1"><%= error[:message] %></p>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>
                <%= if length(@filtered_errors) > 100 do %>
                  <div class="p-2 text-center text-sm text-base-content/60">
                    Showing 100 of <%= length(@filtered_errors) %> diagnostics
                  </div>
                <% end %>
              <% else %>
                <div class="p-8 text-center text-base-content/60">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-2 opacity-50" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                  </svg>
                  <p>No diagnostics to display</p>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Right Panel: Code Preview -->
          <%= if @view_mode == :split and @selected_file do %>
            <div class="sticky top-20">
              <div class="relative">
                <button
                  phx-click="close_preview"
                  class="btn btn-ghost btn-sm btn-circle absolute right-2 top-2 z-10"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
                <.code_preview
                  file_path={@selected_file}
                  content={@selected_file_content}
                  errors={@selected_file_errors}
                  focus_line={assigns[:focus_line]}
                />
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  attr :category, :atom, required: true

  defp category_icon(assigns) do
    category_str = to_string(assigns.category)
    assigns = assign(assigns, :category_str, category_str)

    ~H"""
    <%= case @category_str do %>
      <% "error" -> %>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-error flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
      <% "warning" -> %>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-warning flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
        </svg>
      <% _ -> %>
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-info flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
    <% end %>
    """
  end

  # Helper functions

  defp format_diagnostic(%TSC.Diagnostic{} = d) do
    TSC.Diagnostic.to_map(d)
  end

  defp format_diagnostic(%{__struct__: _} = d) do
    # Handle any other struct by converting to map
    Map.from_struct(d)
  end

  defp format_diagnostic(d) when is_map(d), do: d
  defp format_diagnostic(_), do: %{}

  defp filter_and_sort_errors(errors, category, type, search, sort_by, sort_dir) do
    errors
    |> Enum.filter(fn error ->
      category_match = category == "all" or to_string(error[:category]) == category

      type_match = type == "all" or to_string(error[:error_type]) == type

      search_match = search == "" or
        String.contains?(String.downcase(error[:message] || ""), String.downcase(search)) or
        String.contains?(String.downcase(error[:file] || ""), String.downcase(search)) or
        String.contains?(String.downcase(error[:code] || ""), String.downcase(search))

      category_match and type_match and search_match
    end)
    |> Enum.sort_by(&sort_key(&1, sort_by), sort_dir)
  end

  defp sort_key(error, :file), do: {error[:file] || "", error[:line] || 0}
  defp sort_key(error, :category), do: category_order(error[:category])
  defp sort_key(error, :code), do: error[:code] || ""
  defp sort_key(error, _), do: error[:file] || ""

  defp category_order(:error), do: 0
  defp category_order(:warning), do: 1
  defp category_order(_), do: 2

  defp group_by_file(errors) do
    Enum.group_by(errors, & &1[:file])
  end

  defp get_error_types(errors) do
    errors
    |> Enum.map(& &1[:error_type])
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.map(&to_string/1)
    |> Enum.sort()
  end

  defp format_error_type(type) when is_atom(type) do
    type
    |> to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_error_type(type) when is_binary(type) do
    type
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_error_type(_), do: "Unknown"

  defp error_row_class(category) do
    case to_string(category) do
      "error" -> "border-l-4 border-error"
      "warning" -> "border-l-4 border-warning"
      _ -> "border-l-4 border-info"
    end
  end

  defp sort_indicator(current, dir, target) when current == target do
    if dir == :asc, do: "↑", else: "↓"
  end

  defp sort_indicator(_, _, _), do: ""
end
