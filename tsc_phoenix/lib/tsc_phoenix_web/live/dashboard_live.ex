defmodule TscPhoenixWeb.DashboardLive do
  @moduledoc """
  Main dashboard LiveView for monitoring TypeScript compilation.
  """

  use TscPhoenixWeb, :live_view

  import TscPhoenixWeb.Live.Components.BuildProgress
  import TscPhoenixWeb.Live.Components.Navigation

  alias TSC.Telemetry.Reporter
  alias TSC.Cache.{TypeCache, FileCache}
  alias TSC.Worker.PoolSupervisor
  alias TSC.Watcher.FileWatcher
  alias TSC.Coordinator

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to compiler updates
      Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "compiler:updates")

      # Periodic refresh
      :timer.send_interval(1000, self(), :refresh)
    end

    metrics = Reporter.get_metrics()

    socket =
      socket
      |> assign(:page_title, "TSC Dashboard")
      |> assign(:metrics, metrics)
      |> assign(:phases, Map.get(metrics, :phases, %{}))
      |> assign(:active_checks, Reporter.get_active_checks())
      |> assign(:type_cache_stats, TypeCache.stats())
      |> assign(:file_cache_stats, FileCache.stats())
      |> assign(:worker_status, PoolSupervisor.status())
      |> assign(:current_build, Reporter.get_current_build())
      |> assign(:recent_errors, [])
      |> assign(:watch_mode, FileWatcher.watching?())
      |> assign(:project_path, "")

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    metrics = Reporter.get_metrics()

    socket =
      socket
      |> assign(:metrics, metrics)
      |> assign(:phases, Map.get(metrics, :phases, %{}))
      |> assign(:active_checks, Reporter.get_active_checks())
      |> assign(:type_cache_stats, TypeCache.stats())
      |> assign(:file_cache_stats, FileCache.stats())
      |> assign(:worker_status, PoolSupervisor.status())
      |> assign(:current_build, Reporter.get_current_build())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:file_check_start, data}, socket) do
    active = [data.file | socket.assigns.active_checks] |> Enum.take(20)
    {:noreply, assign(socket, :active_checks, active)}
  end

  @impl true
  def handle_info({:file_check_stop, data}, socket) do
    active = List.delete(socket.assigns.active_checks, data.file)

    # Add errors to recent list
    recent_errors =
      case data do
        %{result: {:ok, %{diagnostics: diags}}} when is_list(diags) ->
          errors = Enum.filter(diags, &(&1.category == :error))
          (errors ++ socket.assigns.recent_errors) |> Enum.take(50)
        _ ->
          socket.assigns.recent_errors
      end

    socket =
      socket
      |> assign(:active_checks, active)
      |> assign(:recent_errors, recent_errors)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:project_check_start, data}, socket) do
    {:noreply, assign(socket, :current_build, %{status: :in_progress, files_count: data.files_count})}
  end

  @impl true
  def handle_info({:project_check_stop, data}, socket) do
    {:noreply, assign(socket, :current_build, %{status: :complete, duration: data.duration, files_count: data.files_count})}
  end

  @impl true
  def handle_info({:incremental_check_complete, result}, socket) do
    recent_errors = result.diagnostics
    |> Enum.filter(&(&1.category == :error))
    |> Enum.take(50)

    socket =
      socket
      |> assign(:recent_errors, recent_errors)
      |> assign(:current_build, %{status: :complete, stats: result.stats})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:files_changed, files}, socket) do
    # Flash notification about changed files
    socket = put_flash(socket, :info, "#{length(files)} file(s) changed, recompiling...")
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def handle_event("toggle_watch", _, socket) do
    watch_mode = !socket.assigns.watch_mode

    if watch_mode do
      dirs = if socket.assigns.project_path != "" do
        [socket.assigns.project_path]
      else
        ["./src"]
      end
      FileWatcher.watch(dirs)
    else
      FileWatcher.stop_watching()
    end

    {:noreply, assign(socket, :watch_mode, watch_mode)}
  end

  @impl true
  def handle_event("run_check", _, socket) do
    path = if socket.assigns.project_path != "" do
      socket.assigns.project_path
    else
      "./"
    end

    files = Path.wildcard(Path.join(path, "**/*.{ts,tsx}"))

    Task.start(fn ->
      Coordinator.check_project(files, incremental: false)
    end)

    socket = put_flash(socket, :info, "Started checking #{length(files)} files...")
    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_cache", _, socket) do
    TypeCache.clear()
    FileCache.clear()

    socket =
      socket
      |> assign(:type_cache_stats, TypeCache.stats())
      |> assign(:file_cache_stats, FileCache.stats())
      |> put_flash(:info, "Cache cleared")

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_project_path", %{"path" => path}, socket) do
    {:noreply, assign(socket, :project_path, path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-lg">
        <div class="flex-1 gap-4">
          <span class="text-xl font-bold px-4">TSC Dashboard</span>
          <.nav_tabs current_path="/" />
        </div>
        <div class="flex-none gap-2">
          <input
            type="text"
            placeholder="Project path..."
            class="input input-bordered w-64"
            value={@project_path}
            phx-blur="update_project_path"
            phx-value-path={@project_path}
          />
          <button phx-click="run_check" class="btn btn-primary">
            Run Check
          </button>
          <button
            phx-click="toggle_watch"
            class={"btn #{if @watch_mode, do: "btn-success", else: "btn-ghost"}"}
          >
            Watch: <%= if @watch_mode, do: "ON", else: "OFF" %>
          </button>
          <button phx-click="clear_cache" class="btn btn-ghost">
            Clear Cache
          </button>
        </div>
      </header>

      <main class="container mx-auto p-4">
        <!-- Metrics Cards -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <.metric_card title="Files Checked" value={@metrics.file_checks} icon="document" />
          <.metric_card
            title="Avg Check Time"
            value={"#{@metrics.avg_duration_ms}ms"}
            icon="clock"
          />
          <.metric_card
            title="Cache Hit Rate"
            value={"#{@metrics.cache_hit_rate}%"}
            icon="server"
          />
          <.metric_card
            title="Errors"
            value={@metrics.errors_count}
            icon="exclamation-circle"
            class={if @metrics.errors_count > 0, do: "border-error"}
          />
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <!-- Build Progress -->
          <.build_progress
            current_build={@current_build}
            active_checks={@active_checks}
            phases={@phases}
            errors_count={@metrics.errors_count}
            warnings_count={Map.get(@metrics, :warnings_count, 0)}
          />

          <!-- Worker Status -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Workers</h2>
              <div class="overflow-x-auto">
                <table class="table table-sm">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Status</th>
                      <th>Processed</th>
                      <th>Uptime</th>
                    </tr>
                  </thead>
                  <tbody>
                    <%= for worker <- @worker_status do %>
                      <tr>
                        <td><%= worker.worker_id %></td>
                        <td>
                          <span class={"badge #{worker_status_class(worker.status)}"}>
                            <%= worker.status %>
                          </span>
                        </td>
                        <td><%= worker[:processed_count] || 0 %></td>
                        <td><%= format_uptime(worker[:uptime_seconds]) %></td>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          <!-- Cache Stats -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">Cache</h2>
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <h3 class="font-semibold">Type Cache</h3>
                  <p>Entries: <%= @type_cache_stats.entries %></p>
                  <p>Memory: <%= @type_cache_stats.memory_mb %> MB</p>
                </div>
                <div>
                  <h3 class="font-semibold">File Cache</h3>
                  <p>Entries: <%= @file_cache_stats.entries %></p>
                  <p>Memory: <%= @file_cache_stats.memory_mb %> MB</p>
                </div>
              </div>
              <div class="mt-4">
                <p>Hit Rate: <%= @metrics.cache_hit_rate %>%</p>
                <progress
                  class="progress progress-success w-full"
                  value={@metrics.cache_hit_rate}
                  max="100"
                ></progress>
              </div>
            </div>
          </div>

          <!-- Recent Errors -->
          <div class="card bg-base-100 shadow-xl">
            <div class="card-body">
              <h2 class="card-title">
                Recent Errors
                <span class="badge badge-error"><%= length(@recent_errors) %></span>
              </h2>
              <%= if length(@recent_errors) > 0 do %>
                <div class="overflow-y-auto max-h-64">
                  <%= for error <- Enum.take(@recent_errors, 10) do %>
                    <div class="alert alert-error mb-2 text-sm">
                      <div>
                        <p class="font-mono text-xs"><%= error[:file] %>:<%= error[:line] %>:<%= error[:column] %></p>
                        <p><%= error[:message] %></p>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% else %>
                <p class="text-base-content/60">No errors</p>
              <% end %>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp metric_card(assigns) do
    assigns = assign_new(assigns, :class, fn -> "" end)

    ~H"""
    <div class={"card bg-base-100 shadow-xl #{@class}"}>
      <div class="card-body p-4">
        <div class="flex items-center gap-2">
          <.metric_icon name={@icon} class="w-5 h-5 text-primary" />
          <span class="text-base-content/70 text-sm"><%= @title %></span>
        </div>
        <p class="text-2xl font-bold"><%= @value %></p>
      </div>
    </div>
    """
  end

  defp metric_icon(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class={@class}>
      <%= case @name do %>
        <% "document" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 00-3.375-3.375h-1.5A1.125 1.125 0 0113.5 7.125v-1.5a3.375 3.375 0 00-3.375-3.375H8.25m2.25 0H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 00-9-9z" />
        <% "clock" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 11-18 0 9 9 0 0118 0z" />
        <% "server" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M5.25 14.25h13.5m-13.5 0a3 3 0 01-3-3m3 3a3 3 0 100 6h13.5a3 3 0 100-6m-16.5-3a3 3 0 013-3h13.5a3 3 0 013 3m-19.5 0a4.5 4.5 0 01.9-2.7L5.737 5.1a3.375 3.375 0 012.7-1.35h7.126c1.062 0 2.062.5 2.7 1.35l2.587 3.45a4.5 4.5 0 01.9 2.7m0 0a3 3 0 01-3 3m0 3h.008v.008h-.008v-.008zm0-6h.008v.008h-.008v-.008zm-3 6h.008v.008h-.008v-.008zm0-6h.008v.008h-.008v-.008z" />
        <% "exclamation-circle" -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z" />
        <% _ -> %>
          <path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
      <% end %>
    </svg>
    """
  end

  defp worker_status_class(:ready), do: "badge-success"
  defp worker_status_class(:busy), do: "badge-warning"
  defp worker_status_class(:down), do: "badge-error"
  defp worker_status_class(_), do: "badge-ghost"

  defp format_uptime(nil), do: "-"
  defp format_uptime(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_uptime(seconds) do
    minutes = div(seconds, 60)
    secs = rem(seconds, 60)
    "#{minutes}m #{secs}s"
  end
end
