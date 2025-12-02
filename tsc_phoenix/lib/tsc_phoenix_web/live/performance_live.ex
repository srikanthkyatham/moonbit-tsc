defmodule TscPhoenixWeb.PerformanceLive do
  @moduledoc """
  LiveView for performance profiling and memory analysis.
  """

  use TscPhoenixWeb, :live_view

  import TscPhoenixWeb.Live.Components.Navigation

  alias TSC.Telemetry.{Profiler, MemoryAnalyzer}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(2000, self(), :refresh)
    end

    memory_report = MemoryAnalyzer.full_report()
    sessions = Profiler.list_sessions()

    socket =
      socket
      |> assign(:page_title, "Performance")
      |> assign(:memory_report, memory_report)
      |> assign(:sessions, sessions)
      |> assign(:selected_session, nil)
      |> assign(:realtime_metrics, Profiler.get_realtime_metrics())
      |> assign(:active_tab, :overview)

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> assign(:memory_report, MemoryAnalyzer.full_report())
      |> assign(:sessions, Profiler.list_sessions())
      |> assign(:realtime_metrics, Profiler.get_realtime_metrics())

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("start_session", %{"name" => name}, socket) do
    {:ok, session_id} = Profiler.start_session(name, sample_interval: 100)
    sessions = Profiler.list_sessions()

    socket =
      socket
      |> assign(:sessions, sessions)
      |> put_flash(:info, "Started profiling session: #{session_id}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_session", %{"id" => session_id}, socket) do
    case Profiler.stop_session(session_id) do
      {:ok, session} ->
        sessions = Profiler.list_sessions()

        socket =
          socket
          |> assign(:sessions, sessions)
          |> assign(:selected_session, session)
          |> put_flash(:info, "Session completed")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to stop session")}
    end
  end

  @impl true
  def handle_event("select_session", %{"id" => session_id}, socket) do
    session = Profiler.get_session(session_id)
    {:noreply, assign(socket, :selected_session, session)}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("clear_session", %{"id" => session_id}, socket) do
    # Sessions are stored in ETS, we would need to implement delete
    selected = if socket.assigns.selected_session && socket.assigns.selected_session.id == session_id do
      nil
    else
      socket.assigns.selected_session
    end

    {:noreply, assign(socket, :selected_session, selected)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-lg">
        <div class="flex-1 gap-4">
          <span class="text-xl font-bold px-4">TSC Dashboard</span>
          <.nav_tabs current_path="/performance" />
        </div>
        <div class="flex-none gap-2">
          <form phx-submit="start_session" class="flex gap-2">
            <input
              type="text"
              name="name"
              placeholder="Session name..."
              class="input input-bordered input-sm w-48"
            />
            <button type="submit" class="btn btn-primary btn-sm">
              Start Profiling
            </button>
          </form>
        </div>
      </header>

      <main class="container mx-auto p-4">
        <!-- Tabs -->
        <div class="tabs tabs-boxed mb-4">
          <a
            class={"tab #{if @active_tab == :overview, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="overview"
          >
            Overview
          </a>
          <a
            class={"tab #{if @active_tab == :memory, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="memory"
          >
            Memory
          </a>
          <a
            class={"tab #{if @active_tab == :sessions, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="sessions"
          >
            Sessions
          </a>
          <a
            class={"tab #{if @active_tab == :processes, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="processes"
          >
            Processes
          </a>
          <a
            class={"tab #{if @active_tab == :ets, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="ets"
          >
            ETS Tables
          </a>
        </div>

        <%= case @active_tab do %>
          <% :overview -> %>
            <.overview_tab memory_report={@memory_report} realtime_metrics={@realtime_metrics} />
          <% :memory -> %>
            <.memory_tab memory_report={@memory_report} />
          <% :sessions -> %>
            <.sessions_tab sessions={@sessions} selected_session={@selected_session} />
          <% :processes -> %>
            <.processes_tab processes={@memory_report.processes} />
          <% :ets -> %>
            <.ets_tab ets={@memory_report.ets} />
        <% end %>
      </main>
    </div>
    """
  end

  # ============================================================================
  # Tab Components
  # ============================================================================

  defp overview_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <.stat_card
        title="Total Memory"
        value={"#{@memory_report.system.total_mb} MB"}
        icon="memory"
      />
      <.stat_card
        title="Process Count"
        value={@realtime_metrics.process_count}
        icon="process"
      />
      <.stat_card
        title="Run Queue"
        value={@realtime_metrics.run_queue}
        icon="queue"
      />
      <.stat_card
        title="ETS Memory"
        value={"#{@memory_report.ets.total_mb} MB"}
        icon="database"
      />
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Memory Breakdown -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Memory Breakdown</h2>
          <div class="space-y-3">
            <%= for {name, data} <- @memory_report.beam do %>
              <div>
                <div class="flex justify-between text-sm mb-1">
                  <span class="capitalize"><%= name %></span>
                  <span><%= data.mb %> MB (<%= data.percentage %>%)</span>
                </div>
                <progress
                  class={"progress #{memory_color(data.percentage)} w-full"}
                  value={data.percentage}
                  max="100"
                ></progress>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Recommendations -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Recommendations</h2>
          <%= if length(@memory_report.recommendations) > 0 do %>
            <div class="space-y-2">
              <%= for rec <- @memory_report.recommendations do %>
                <div class={"alert #{priority_alert_class(rec.priority)}"}}>
                  <div>
                    <span class="badge badge-sm capitalize"><%= rec.category %></span>
                    <p class="font-semibold"><%= rec.issue %></p>
                    <p class="text-sm opacity-80"><%= rec.suggestion %></p>
                  </div>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-base-content/60">No recommendations at this time.</p>
          <% end %>
        </div>
      </div>

      <!-- Cache Usage -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Cache Usage</h2>
          <div class="stats stats-vertical shadow">
            <div class="stat">
              <div class="stat-title">Type Cache</div>
              <div class="stat-value text-lg"><%= @memory_report.caches.type_cache.entries %></div>
              <div class="stat-desc"><%= @memory_report.caches.type_cache.memory_mb %> MB</div>
            </div>
            <div class="stat">
              <div class="stat-title">File Cache</div>
              <div class="stat-value text-lg"><%= @memory_report.caches.file_cache.entries %></div>
              <div class="stat-desc"><%= @memory_report.caches.file_cache.memory_mb %> MB</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Scheduler Usage -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Scheduler Usage</h2>
          <div class="space-y-2">
            <%= for {scheduler_id, usage} <- Enum.sort(@realtime_metrics.scheduler_usage) do %>
              <div class="flex items-center gap-2">
                <span class="w-16 text-sm">Sched <%= scheduler_id %></span>
                <progress
                  class={"progress #{scheduler_color(usage)} flex-1"}
                  value={round(usage * 100)}
                  max="100"
                ></progress>
                <span class="w-12 text-sm text-right"><%= round(usage * 100) %>%</span>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp memory_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- System Memory -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">System Memory</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <tbody>
                <tr>
                  <td>Total</td>
                  <td class="text-right font-mono"><%= @memory_report.system.total_mb %> MB</td>
                </tr>
                <tr>
                  <td>System</td>
                  <td class="text-right font-mono"><%= @memory_report.system.system_mb %> MB</td>
                </tr>
                <tr>
                  <td>VM Limit</td>
                  <td class="text-right font-mono"><%= @memory_report.system.vm_limit %></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- BEAM Memory -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">BEAM Memory</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Category</th>
                  <th class="text-right">Size</th>
                  <th class="text-right">%</th>
                </tr>
              </thead>
              <tbody>
                <%= for {name, data} <- @memory_report.beam do %>
                  <tr>
                    <td class="capitalize"><%= name %></td>
                    <td class="text-right font-mono"><%= data.mb %> MB</td>
                    <td class="text-right font-mono"><%= data.percentage %>%</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- GC Stats -->
      <div class="card bg-base-100 shadow-xl col-span-full">
        <div class="card-body">
          <h2 class="card-title">Garbage Collection</h2>
          <div class="stats shadow">
            <div class="stat">
              <div class="stat-title">GC Count</div>
              <div class="stat-value"><%= @memory_report.gc_stats.number_of_gcs %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Words Reclaimed</div>
              <div class="stat-value"><%= format_number(@memory_report.gc_stats.words_reclaimed) %></div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp sessions_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Sessions List -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Profiling Sessions</h2>
          <%= if length(@sessions) > 0 do %>
            <div class="space-y-2">
              <%= for session <- @sessions do %>
                <div
                  class={"p-3 rounded-lg cursor-pointer hover:bg-base-200 #{if @selected_session && @selected_session.id == session.id, do: "bg-primary/20", else: "bg-base-200"}"}
                  phx-click="select_session"
                  phx-value-id={session.id}
                >
                  <div class="flex items-center justify-between">
                    <span class="font-semibold"><%= session.name %></span>
                    <span class={"badge #{status_badge_class(session.status)}"}>
                      <%= session.status %>
                    </span>
                  </div>
                  <p class="text-xs text-base-content/60 font-mono"><%= session.id %></p>
                  <%= if session.status == :running do %>
                    <button
                      class="btn btn-xs btn-warning mt-2"
                      phx-click="stop_session"
                      phx-value-id={session.id}
                    >
                      Stop
                    </button>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-base-content/60">No profiling sessions. Start one above.</p>
          <% end %>
        </div>
      </div>

      <!-- Session Details -->
      <div class="card bg-base-100 shadow-xl lg:col-span-2">
        <div class="card-body">
          <h2 class="card-title">Session Details</h2>
          <%= if @selected_session do %>
            <div class="space-y-4">
              <!-- Summary -->
              <%= if @selected_session.summary do %>
                <div class="stats shadow w-full">
                  <div class="stat">
                    <div class="stat-title">Duration</div>
                    <div class="stat-value text-lg"><%= @selected_session.summary.duration_ms %> ms</div>
                  </div>
                  <div class="stat">
                    <div class="stat-title">Samples</div>
                    <div class="stat-value text-lg"><%= @selected_session.summary.sample_count %></div>
                  </div>
                  <div class="stat">
                    <div class="stat-title">Operations</div>
                    <div class="stat-value text-lg"><%= @selected_session.summary.operations %></div>
                  </div>
                </div>

                <!-- Memory Summary -->
                <div class="overflow-x-auto">
                  <h3 class="font-semibold mb-2">Memory</h3>
                  <table class="table table-sm">
                    <thead>
                      <tr>
                        <th>Metric</th>
                        <th class="text-right">Value</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td>Initial</td>
                        <td class="text-right font-mono"><%= format_bytes(@selected_session.summary.memory.initial) %></td>
                      </tr>
                      <tr>
                        <td>Final</td>
                        <td class="text-right font-mono"><%= format_bytes(@selected_session.summary.memory.final) %></td>
                      </tr>
                      <tr>
                        <td>Peak</td>
                        <td class="text-right font-mono"><%= format_bytes(@selected_session.summary.memory.peak) %></td>
                      </tr>
                      <tr>
                        <td>Average</td>
                        <td class="text-right font-mono"><%= format_bytes(@selected_session.summary.memory.avg) %></td>
                      </tr>
                    </tbody>
                  </table>
                </div>
              <% else %>
                <p class="text-base-content/60">Session is still running...</p>
              <% end %>
            </div>
          <% else %>
            <p class="text-base-content/60">Select a session to view details</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp processes_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">Top Processes by Memory</h2>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>PID / Name</th>
                <th class="text-right">Memory</th>
                <th class="text-right">Heap</th>
                <th class="text-right">Msg Queue</th>
                <th class="text-right">Reductions</th>
                <th>Current Function</th>
              </tr>
            </thead>
            <tbody>
              <%= for proc <- @processes do %>
                <tr>
                  <td>
                    <span class="font-mono text-xs"><%= inspect(proc.pid) %></span>
                    <%= if proc.name do %>
                      <br/>
                      <span class="text-xs text-primary"><%= proc.name %></span>
                    <% end %>
                  </td>
                  <td class="text-right font-mono"><%= proc.memory_mb %> MB</td>
                  <td class="text-right font-mono"><%= proc.heap_size %></td>
                  <td class="text-right">
                    <span class={"badge badge-sm #{if proc.message_queue > 100, do: "badge-warning", else: "badge-ghost"}"}>
                      <%= proc.message_queue %>
                    </span>
                  </td>
                  <td class="text-right font-mono"><%= format_number(proc.reductions) %></td>
                  <td class="text-xs font-mono truncate max-w-xs"><%= proc.current_function %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp ets_tab(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow-xl">
      <div class="card-body">
        <h2 class="card-title">
          ETS Tables
          <span class="badge"><%= @ets.total_count %> tables</span>
          <span class="badge badge-primary"><%= @ets.total_mb %> MB total</span>
        </h2>
        <div class="overflow-x-auto">
          <table class="table table-sm">
            <thead>
              <tr>
                <th>Name</th>
                <th>Type</th>
                <th class="text-right">Size</th>
                <th class="text-right">Memory</th>
                <th>Protection</th>
              </tr>
            </thead>
            <tbody>
              <%= for table <- @ets.tables do %>
                <tr>
                  <td class="font-mono text-xs"><%= table.name %></td>
                  <td><span class="badge badge-sm badge-ghost"><%= table.type %></span></td>
                  <td class="text-right font-mono"><%= format_number(table.size) %></td>
                  <td class="text-right font-mono"><%= table.memory_mb %> MB</td>
                  <td><span class="badge badge-sm"><%= table.protection %></span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
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

  # ============================================================================
  # Helper Functions
  # ============================================================================

  defp memory_color(percentage) when percentage > 50, do: "progress-error"
  defp memory_color(percentage) when percentage > 30, do: "progress-warning"
  defp memory_color(_), do: "progress-success"

  defp scheduler_color(usage) when usage > 0.8, do: "progress-error"
  defp scheduler_color(usage) when usage > 0.5, do: "progress-warning"
  defp scheduler_color(_), do: "progress-success"

  defp priority_alert_class(:high), do: "alert-error"
  defp priority_alert_class(:medium), do: "alert-warning"
  defp priority_alert_class(_), do: "alert-info"

  defp status_badge_class(:running), do: "badge-warning"
  defp status_badge_class(:completed), do: "badge-success"
  defp status_badge_class(_), do: "badge-ghost"

  defp format_number(num) when is_number(num) and num >= 1_000_000 do
    "#{Float.round(num / 1_000_000, 1)}M"
  end
  defp format_number(num) when is_number(num) and num >= 1_000 do
    "#{Float.round(num / 1_000, 1)}K"
  end
  defp format_number(num), do: "#{num}"

  defp format_bytes(bytes) when is_number(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1_024 -> "#{Float.round(bytes / 1_024, 2)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_bytes(_), do: "N/A"
end
