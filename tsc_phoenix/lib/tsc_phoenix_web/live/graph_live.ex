defmodule TscPhoenixWeb.GraphLive do
  @moduledoc """
  LiveView for dependency graph visualization.
  """

  use TscPhoenixWeb, :live_view

  import TscPhoenixWeb.Live.Components.Navigation

  alias TSC.Graph.DependencyGraph
  alias TSC.Parser.ImportExtractor
  alias TSC.Project.TsConfig

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Dependency Graph")
      |> assign(:nodes, [])
      |> assign(:edges, [])
      |> assign(:stats, %{files: 0, edges: 0, avg_deps: 0.0})
      |> assign(:project_path, "")
      |> assign(:selected_node, nil)
      |> assign(:node_info, nil)
      |> assign(:loading, false)
      |> assign(:view_mode, :list)
      |> assign(:search, "")
      |> assign(:sort_by, :dependents)

    {:ok, socket}
  end

  @impl true
  def handle_event("load_project", %{"project" => project}, socket) do
    socket =
      socket
      |> assign(:loading, true)
      |> assign(:project_path, project)

    send(self(), {:build_graph, project})
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"file" => file}, socket) do
    dependencies = DependencyGraph.get_dependencies(file)
    dependents = DependencyGraph.get_dependents(file)
    affected = DependencyGraph.get_affected_files([file])

    node_info = %{
      file: file,
      basename: Path.basename(file),
      directory: Path.dirname(file),
      dependencies: dependencies,
      dependents: dependents,
      affected: affected
    }

    {:noreply, assign(socket, selected_node: file, node_info: node_info)}
  end

  @impl true
  def handle_event("clear_selection", _, socket) do
    {:noreply, assign(socket, selected_node: nil, node_info: nil)}
  end

  @impl true
  def handle_event("set_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, String.to_existing_atom(mode))}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    {:noreply, assign(socket, :search, search)}
  end

  @impl true
  def handle_event("sort_by", %{"field" => field}, socket) do
    {:noreply, assign(socket, :sort_by, String.to_existing_atom(field))}
  end

  @impl true
  def handle_event("refresh", _, socket) do
    if socket.assigns.project_path != "" do
      send(self(), {:build_graph, socket.assigns.project_path})
      {:noreply, assign(socket, :loading, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:build_graph, project}, socket) do
    files = discover_files(project)

    # Build the graph
    DependencyGraph.clear()

    Enum.each(files, fn file ->
      case ImportExtractor.extract(file) do
        {:ok, imports} ->
          dependencies =
            imports
            |> Enum.map(fn imp -> ImportExtractor.resolve(file, imp.specifier) end)
            |> Enum.reject(&is_nil/1)

          DependencyGraph.add(file, dependencies)

        {:error, _} ->
          DependencyGraph.add(file, [])
      end
    end)

    # Get graph data
    all_files = DependencyGraph.all_files()

    nodes =
      all_files
      |> Enum.map(fn file ->
        deps = DependencyGraph.get_dependencies(file)
        dependents = DependencyGraph.get_dependents(file)

        %{
          id: file,
          label: Path.basename(file),
          directory: Path.dirname(file),
          dependencies_count: length(deps),
          dependents_count: length(dependents)
        }
      end)

    edges =
      all_files
      |> Enum.flat_map(fn file ->
        DependencyGraph.get_dependencies(file)
        |> Enum.map(fn dep -> %{source: file, target: dep} end)
      end)

    stats = DependencyGraph.stats()

    socket =
      socket
      |> assign(:nodes, nodes)
      |> assign(:edges, edges)
      |> assign(:stats, stats)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-lg">
        <div class="flex-1 gap-4">
          <span class="text-xl font-bold px-4">TSC Dashboard</span>
          <.nav_tabs current_path="/graph" />
        </div>
        <div class="flex-none gap-2">
          <form phx-submit="load_project" class="flex gap-2">
            <input
              type="text"
              name="project"
              placeholder="Project path..."
              value={@project_path}
              class="input input-bordered input-sm w-64"
            />
            <button type="submit" class="btn btn-primary btn-sm" disabled={@loading}>
              <%= if @loading do %>
                <span class="loading loading-spinner loading-sm"></span>
              <% else %>
                Load
              <% end %>
            </button>
          </form>
          <%= if length(@nodes) > 0 do %>
            <button phx-click="refresh" class="btn btn-ghost btn-sm" disabled={@loading}>
              Refresh
            </button>
          <% end %>
        </div>
      </header>

      <main class="container mx-auto p-4">
        <!-- Stats Overview -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <.stat_card title="Files" value={@stats.files} />
          <.stat_card title="Edges" value={@stats.edges} />
          <.stat_card title="Avg Deps" value={Float.round(@stats.avg_deps || 0.0, 2)} />
          <.stat_card title="Selected" value={if @selected_node, do: Path.basename(@selected_node), else: "-"} />
        </div>

        <%= if length(@nodes) == 0 and not @loading do %>
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body text-center">
              <h2 class="card-title justify-center">No Graph Loaded</h2>
              <p class="text-base-content/60">Enter a project path above to analyze dependencies.</p>
              <p class="text-sm text-base-content/40">
                Example: /Users/you/project or ./relative/path
              </p>
            </div>
          </div>
        <% else %>
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
            <!-- Files List -->
            <div class="lg:col-span-2">
              <div class="card bg-base-100 shadow-xl">
                <div class="card-body">
                  <div class="flex justify-between items-center mb-4">
                    <h2 class="card-title">Files (<%= length(@nodes) %>)</h2>
                    <div class="flex gap-2">
                      <input
                        type="text"
                        phx-keyup="search"
                        phx-debounce="200"
                        name="search"
                        value={@search}
                        placeholder="Search..."
                        class="input input-bordered input-sm w-40"
                      />
                      <div class="btn-group">
                        <button
                          class={"btn btn-sm #{if @sort_by == :dependents, do: "btn-active"}"}
                          phx-click="sort_by"
                          phx-value-field="dependents"
                        >
                          Most Used
                        </button>
                        <button
                          class={"btn btn-sm #{if @sort_by == :dependencies, do: "btn-active"}"}
                          phx-click="sort_by"
                          phx-value-field="dependencies"
                        >
                          Most Deps
                        </button>
                        <button
                          class={"btn btn-sm #{if @sort_by == :name, do: "btn-active"}"}
                          phx-click="sort_by"
                          phx-value-field="name"
                        >
                          Name
                        </button>
                      </div>
                    </div>
                  </div>

                  <div class="overflow-y-auto max-h-[600px]">
                    <table class="table table-sm table-pin-rows">
                      <thead>
                        <tr>
                          <th>File</th>
                          <th class="text-center">Dependents</th>
                          <th class="text-center">Dependencies</th>
                        </tr>
                      </thead>
                      <tbody>
                        <%= for node <- filtered_and_sorted_nodes(@nodes, @search, @sort_by) do %>
                          <tr
                            class={"cursor-pointer hover:bg-base-200 #{if @selected_node == node.id, do: "bg-primary/20"}"}
                            phx-click="select_node"
                            phx-value-file={node.id}
                          >
                            <td>
                              <div>
                                <span class={"font-medium #{if node.dependents_count > 5, do: "text-primary"}"}><%= node.label %></span>
                              </div>
                              <span class="text-xs text-base-content/50"><%= truncate_path(node.directory) %></span>
                            </td>
                            <td class="text-center">
                              <span class={"badge #{dependents_badge_class(node.dependents_count)}"}><%= node.dependents_count %></span>
                            </td>
                            <td class="text-center">
                              <span class="badge badge-ghost"><%= node.dependencies_count %></span>
                            </td>
                          </tr>
                        <% end %>
                      </tbody>
                    </table>
                  </div>
                </div>
              </div>
            </div>

            <!-- Node Details -->
            <div class="card bg-base-100 shadow-xl">
              <div class="card-body">
                <div class="flex justify-between items-center">
                  <h2 class="card-title">File Details</h2>
                  <%= if @node_info do %>
                    <button phx-click="clear_selection" class="btn btn-ghost btn-xs">Clear</button>
                  <% end %>
                </div>

                <%= if @node_info do %>
                  <div class="space-y-4">
                    <div>
                      <span class="text-sm text-base-content/60">File</span>
                      <p class="font-semibold break-all"><%= @node_info.basename %></p>
                      <p class="text-xs text-base-content/50 break-all"><%= @node_info.directory %></p>
                    </div>

                    <div class="divider"></div>

                    <div>
                      <span class="text-sm text-base-content/60 flex items-center gap-2">
                        Dependents
                        <span class="badge badge-sm badge-primary"><%= length(@node_info.dependents) %></span>
                      </span>
                      <p class="text-xs text-base-content/40 mb-2">Files that import this file</p>
                      <%= if length(@node_info.dependents) > 0 do %>
                        <ul class="text-sm space-y-1 max-h-32 overflow-y-auto">
                          <%= for dep <- @node_info.dependents do %>
                            <li
                              class="flex items-center gap-2 p-1 hover:bg-base-200 rounded cursor-pointer"
                              phx-click="select_node"
                              phx-value-file={dep}
                            >
                              <span class="text-primary">←</span>
                              <span class="truncate"><%= Path.basename(dep) %></span>
                            </li>
                          <% end %>
                        </ul>
                      <% else %>
                        <p class="text-sm text-base-content/40">No files depend on this</p>
                      <% end %>
                    </div>

                    <div>
                      <span class="text-sm text-base-content/60 flex items-center gap-2">
                        Dependencies
                        <span class="badge badge-sm badge-ghost"><%= length(@node_info.dependencies) %></span>
                      </span>
                      <p class="text-xs text-base-content/40 mb-2">Files imported by this file</p>
                      <%= if length(@node_info.dependencies) > 0 do %>
                        <ul class="text-sm space-y-1 max-h-32 overflow-y-auto">
                          <%= for dep <- @node_info.dependencies do %>
                            <li
                              class="flex items-center gap-2 p-1 hover:bg-base-200 rounded cursor-pointer"
                              phx-click="select_node"
                              phx-value-file={dep}
                            >
                              <span class="text-secondary">→</span>
                              <span class="truncate"><%= Path.basename(dep) %></span>
                            </li>
                          <% end %>
                        </ul>
                      <% else %>
                        <p class="text-sm text-base-content/40">No dependencies</p>
                      <% end %>
                    </div>

                    <%= if length(@node_info.affected) > 0 do %>
                      <div>
                        <span class="text-sm text-base-content/60 flex items-center gap-2">
                          Impact
                          <span class="badge badge-sm badge-warning"><%= length(@node_info.affected) %></span>
                        </span>
                        <p class="text-xs text-base-content/40 mb-2">Files affected by changes</p>
                        <ul class="text-sm space-y-1 max-h-32 overflow-y-auto">
                          <%= for file <- Enum.take(@node_info.affected, 10) do %>
                            <li
                              class="flex items-center gap-2 p-1 hover:bg-base-200 rounded cursor-pointer"
                              phx-click="select_node"
                              phx-value-file={file}
                            >
                              <span class="text-warning">⚡</span>
                              <span class="truncate"><%= Path.basename(file) %></span>
                            </li>
                          <% end %>
                          <%= if length(@node_info.affected) > 10 do %>
                            <li class="text-xs text-base-content/40">
                              ...and <%= length(@node_info.affected) - 10 %> more
                            </li>
                          <% end %>
                        </ul>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-base-content/60">Select a file to view details</p>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Topological Levels -->
          <%= if length(@nodes) > 0 do %>
            <div class="card bg-base-100 shadow-xl mt-6">
              <div class="card-body">
                <h2 class="card-title">Compilation Order (Topological Levels)</h2>
                <p class="text-sm text-base-content/60 mb-4">
                  Files within the same level can be compiled in parallel.
                </p>
                <.levels_view files={Enum.map(@nodes, & &1.id)} />
              </div>
            </div>
          <% end %>
        <% end %>
      </main>
    </div>
    """
  end

  # ============================================================================
  # Helper Components
  # ============================================================================

  defp stat_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body p-4">
        <p class="text-base-content/70 text-sm"><%= @title %></p>
        <p class="text-2xl font-bold"><%= @value %></p>
      </div>
    </div>
    """
  end

  defp levels_view(assigns) do
    levels = DependencyGraph.topological_levels(assigns.files)
    assigns = assign(assigns, :levels, levels)

    ~H"""
    <div class="space-y-4">
      <%= for {level_files, index} <- Enum.with_index(@levels) do %>
        <div class="flex items-start gap-4">
          <div class="badge badge-primary badge-lg w-16 shrink-0">L<%= index + 1 %></div>
          <div class="flex flex-wrap gap-2">
            <%= for file <- Enum.take(level_files, 20) do %>
              <span class="badge badge-outline badge-sm"><%= Path.basename(file) %></span>
            <% end %>
            <%= if length(level_files) > 20 do %>
              <span class="badge badge-ghost badge-sm">+<%= length(level_files) - 20 %> more</span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp discover_files(project_path) when is_binary(project_path) do
    # Check if there's a tsconfig.json
    tsconfig_path = Path.join(project_path, "tsconfig.json")

    files =
      if File.exists?(tsconfig_path) do
        case TsConfig.load(tsconfig_path) do
          {:ok, config} -> TsConfig.get_files(config)
          {:error, _} -> scan_directory(project_path)
        end
      else
        scan_directory(project_path)
      end

    # Limit to reasonable number for visualization
    Enum.take(files, 500)
  end

  defp discover_files(_), do: []

  defp scan_directory(path) do
    Path.wildcard(Path.join(path, "**/*.{ts,tsx}"))
    |> Enum.reject(&String.contains?(&1, "node_modules"))
  end

  defp filtered_and_sorted_nodes(nodes, search, sort_by) do
    nodes
    |> filter_nodes(search)
    |> sort_nodes(sort_by)
  end

  defp filter_nodes(nodes, "") do
    nodes
  end

  defp filter_nodes(nodes, search) do
    search_lower = String.downcase(search)
    Enum.filter(nodes, fn node ->
      String.contains?(String.downcase(node.label), search_lower) or
        String.contains?(String.downcase(node.directory), search_lower)
    end)
  end

  defp sort_nodes(nodes, :dependents) do
    Enum.sort_by(nodes, & &1.dependents_count, :desc)
  end

  defp sort_nodes(nodes, :dependencies) do
    Enum.sort_by(nodes, & &1.dependencies_count, :desc)
  end

  defp sort_nodes(nodes, :name) do
    Enum.sort_by(nodes, & &1.label)
  end

  defp truncate_path(path) do
    if String.length(path) > 40 do
      "..." <> String.slice(path, -37..-1//1)
    else
      path
    end
  end

  defp dependents_badge_class(count) when count > 10, do: "badge-error"
  defp dependents_badge_class(count) when count > 5, do: "badge-warning"
  defp dependents_badge_class(count) when count > 0, do: "badge-primary"
  defp dependents_badge_class(_), do: "badge-ghost"
end
