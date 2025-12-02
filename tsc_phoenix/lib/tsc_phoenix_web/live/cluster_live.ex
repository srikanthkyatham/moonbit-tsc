defmodule TscPhoenixWeb.ClusterLive do
  @moduledoc """
  LiveView for cluster management and monitoring.
  """

  use TscPhoenixWeb, :live_view

  import TscPhoenixWeb.Live.Components.Navigation

  alias TSC.Cluster.{NodeRegistry, WorkDistributor, DistributedCache}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(TscPhoenix.PubSub, "cluster:updates")
      :timer.send_interval(2000, self(), :refresh)
    end

    socket =
      socket
      |> assign(:page_title, "Cluster")
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> assign(:cluster_stats, NodeRegistry.cluster_stats())
      |> assign(:work_stats, WorkDistributor.stats())
      |> assign(:cache_stats, DistributedCache.cluster_cache_stats())
      |> assign(:distribution_strategy, WorkDistributor.get_strategy())
      |> assign(:selected_node, nil)
      |> assign(:active_tab, :nodes)

    {:ok, socket}
  end

  @impl true
  def handle_info(:refresh, socket) do
    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> assign(:cluster_stats, NodeRegistry.cluster_stats())
      |> assign(:work_stats, WorkDistributor.stats())
      |> assign(:cache_stats, DistributedCache.cluster_cache_stats())

    {:noreply, socket}
  end

  @impl true
  def handle_info({:node_joined, node_info}, socket) do
    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> put_flash(:info, "Node joined: #{node_info.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:node_left, node_info}, socket) do
    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> put_flash(:warning, "Node left: #{node_info.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:node_disconnected, remote_node}, socket) do
    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> put_flash(:error, "Node disconnected: #{remote_node}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:node_timeout, node_info}, socket) do
    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> put_flash(:error, "Node timed out: #{node_info.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  @impl true
  def handle_event("register_node", %{"name" => name}, socket) do
    NodeRegistry.register(name: name, capabilities: [:compiler, :cache])

    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> assign(:cluster_stats, NodeRegistry.cluster_stats())
      |> put_flash(:info, "Node registered: #{name}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("unregister_node", _, socket) do
    NodeRegistry.unregister()

    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> assign(:cluster_stats, NodeRegistry.cluster_stats())
      |> put_flash(:info, "Node unregistered")

    {:noreply, socket}
  end

  @impl true
  def handle_event("drain_node", _, socket) do
    NodeRegistry.drain()

    socket =
      socket
      |> assign(:nodes, NodeRegistry.list_nodes())
      |> put_flash(:info, "Node set to draining mode")

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_strategy", %{"strategy" => strategy}, socket) do
    strategy_atom = String.to_existing_atom(strategy)
    WorkDistributor.set_strategy(strategy_atom)

    socket =
      socket
      |> assign(:distribution_strategy, strategy_atom)
      |> put_flash(:info, "Distribution strategy set to: #{strategy}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_cluster_cache", _, socket) do
    DistributedCache.clear_all()

    socket =
      socket
      |> assign(:cache_stats, DistributedCache.cluster_cache_stats())
      |> put_flash(:info, "Cluster cache cleared")

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_node", %{"node" => node_name}, socket) do
    node = NodeRegistry.get_node(String.to_atom(node_name))
    {:noreply, assign(socket, :selected_node, node)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-base-200">
      <header class="navbar bg-base-100 shadow-lg">
        <div class="flex-1 gap-4">
          <span class="text-xl font-bold px-4">TSC Dashboard</span>
          <.nav_tabs current_path="/cluster" />
        </div>
        <div class="flex-none gap-2">
          <%= if local_registered?(@nodes) do %>
            <button phx-click="drain_node" class="btn btn-warning btn-sm">
              Drain Node
            </button>
            <button phx-click="unregister_node" class="btn btn-error btn-sm">
              Unregister
            </button>
          <% else %>
            <form phx-submit="register_node" class="flex gap-2">
              <input
                type="text"
                name="name"
                placeholder="Node name..."
                value={to_string(node())}
                class="input input-bordered input-sm w-48"
              />
              <button type="submit" class="btn btn-primary btn-sm">
                Register Node
              </button>
            </form>
          <% end %>
        </div>
      </header>

      <main class="container mx-auto p-4">
        <!-- Cluster Stats -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <.stat_card title="Total Nodes" value={@cluster_stats.total_nodes} />
          <.stat_card title="Total Workers" value={@cluster_stats.total_workers} />
          <.stat_card title="Available Workers" value={@cluster_stats.available_workers} />
          <.stat_card title="Avg Load" value={"#{@cluster_stats.avg_load}%"} />
        </div>

        <!-- Tabs -->
        <div class="tabs tabs-boxed mb-4">
          <a
            class={"tab #{if @active_tab == :nodes, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="nodes"
          >
            Nodes
          </a>
          <a
            class={"tab #{if @active_tab == :distribution, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="distribution"
          >
            Distribution
          </a>
          <a
            class={"tab #{if @active_tab == :cache, do: "tab-active"}"}
            phx-click="switch_tab"
            phx-value-tab="cache"
          >
            Distributed Cache
          </a>
        </div>

        <%= case @active_tab do %>
          <% :nodes -> %>
            <.nodes_tab nodes={@nodes} selected_node={@selected_node} />
          <% :distribution -> %>
            <.distribution_tab work_stats={@work_stats} strategy={@distribution_strategy} />
          <% :cache -> %>
            <.cache_tab cache_stats={@cache_stats} />
        <% end %>
      </main>
    </div>
    """
  end

  # ============================================================================
  # Tab Components
  # ============================================================================

  defp nodes_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <!-- Nodes List -->
      <div class="card bg-base-100 shadow-xl lg:col-span-2">
        <div class="card-body">
          <h2 class="card-title">Cluster Nodes</h2>
          <%= if length(@nodes) > 0 do %>
            <div class="overflow-x-auto">
              <table class="table table-sm">
                <thead>
                  <tr>
                    <th>Node</th>
                    <th>Status</th>
                    <th>Workers</th>
                    <th>Load</th>
                    <th>Memory</th>
                    <th>Capabilities</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for node_info <- @nodes do %>
                    <tr
                      class={"cursor-pointer hover:bg-base-200 #{if @selected_node && @selected_node.node == node_info.node, do: "bg-primary/20"}"}
                      phx-click="select_node"
                      phx-value-node={node_info.node}
                    >
                      <td>
                        <div>
                          <span class="font-semibold"><%= node_info.name %></span>
                          <%= if node_info.node == node() do %>
                            <span class="badge badge-sm badge-primary ml-2">local</span>
                          <% end %>
                        </div>
                        <span class="text-xs text-base-content/60 font-mono"><%= node_info.node %></span>
                      </td>
                      <td>
                        <span class={"badge #{status_badge(node_info.status)}"}>
                          <%= node_info.status %>
                        </span>
                      </td>
                      <td>
                        <span class="font-mono"><%= node_info.available_workers %>/<%= node_info.workers %></span>
                      </td>
                      <td>
                        <div class="flex items-center gap-2">
                          <progress
                            class={"progress w-16 #{load_color(node_info.load)}"}
                            value={node_info.load}
                            max="100"
                          ></progress>
                          <span class="text-xs"><%= node_info.load %>%</span>
                        </div>
                      </td>
                      <td><span class="font-mono text-sm"><%= node_info.memory_mb %> MB</span></td>
                      <td>
                        <%= for cap <- node_info.capabilities do %>
                          <span class="badge badge-sm badge-ghost mr-1"><%= cap %></span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% else %>
            <p class="text-base-content/60">No nodes registered. Register this node to start.</p>
          <% end %>
        </div>
      </div>

      <!-- Node Details -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Node Details</h2>
          <%= if @selected_node do %>
            <div class="space-y-4">
              <div>
                <span class="text-sm text-base-content/60">Name</span>
                <p class="font-semibold"><%= @selected_node.name %></p>
              </div>
              <div>
                <span class="text-sm text-base-content/60">Node ID</span>
                <p class="font-mono text-sm"><%= @selected_node.node %></p>
              </div>
              <div>
                <span class="text-sm text-base-content/60">Status</span>
                <p><span class={"badge #{status_badge(@selected_node.status)}"}><%= @selected_node.status %></span></p>
              </div>
              <div>
                <span class="text-sm text-base-content/60">Connected At</span>
                <p><%= format_timestamp(@selected_node.connected_at) %></p>
              </div>
              <div>
                <span class="text-sm text-base-content/60">Last Heartbeat</span>
                <p><%= format_timestamp(@selected_node.last_heartbeat) %></p>
              </div>
              <div>
                <span class="text-sm text-base-content/60">Capabilities</span>
                <div class="flex flex-wrap gap-1 mt-1">
                  <%= for cap <- @selected_node.capabilities do %>
                    <span class="badge badge-primary"><%= cap %></span>
                  <% end %>
                </div>
              </div>
            </div>
          <% else %>
            <p class="text-base-content/60">Select a node to view details</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp distribution_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Distribution Stats -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Distribution Statistics</h2>
          <div class="stats stats-vertical shadow">
            <div class="stat">
              <div class="stat-title">Total Batches</div>
              <div class="stat-value"><%= @work_stats.total_batches %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Total Files</div>
              <div class="stat-value"><%= @work_stats.total_files %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Distributed</div>
              <div class="stat-value text-primary"><%= @work_stats.distributed_files %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Local</div>
              <div class="stat-value"><%= @work_stats.local_files %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Failed</div>
              <div class="stat-value text-error"><%= @work_stats.failed_files %></div>
            </div>
          </div>
        </div>
      </div>

      <!-- Strategy Settings -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Distribution Strategy</h2>
          <p class="text-base-content/60 mb-4">Select how work is distributed across nodes</p>

          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">
                <span class="font-semibold">Round Robin</span>
                <br/>
                <span class="text-xs text-base-content/60">Distribute files evenly in sequence</span>
              </span>
              <input
                type="radio"
                name="strategy"
                class="radio radio-primary"
                checked={@strategy == :round_robin}
                phx-click="set_strategy"
                phx-value-strategy="round_robin"
              />
            </label>
          </div>

          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">
                <span class="font-semibold">Least Loaded</span>
                <br/>
                <span class="text-xs text-base-content/60">Assign to nodes with lowest load</span>
              </span>
              <input
                type="radio"
                name="strategy"
                class="radio radio-primary"
                checked={@strategy == :least_loaded}
                phx-click="set_strategy"
                phx-value-strategy="least_loaded"
              />
            </label>
          </div>

          <div class="form-control">
            <label class="label cursor-pointer">
              <span class="label-text">
                <span class="font-semibold">Locality Aware</span>
                <br/>
                <span class="text-xs text-base-content/60">Group files by directory for cache locality</span>
              </span>
              <input
                type="radio"
                name="strategy"
                class="radio radio-primary"
                checked={@strategy == :locality_aware}
                phx-click="set_strategy"
                phx-value-strategy="locality_aware"
              />
            </label>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp cache_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- Cache Overview -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <div class="flex justify-between items-center">
            <h2 class="card-title">Cluster Cache</h2>
            <button phx-click="clear_cluster_cache" class="btn btn-error btn-sm">
              Clear All
            </button>
          </div>

          <div class="stats stats-vertical shadow mt-4">
            <div class="stat">
              <div class="stat-title">Total Type Entries</div>
              <div class="stat-value"><%= @cache_stats.total_type_entries %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Total File Entries</div>
              <div class="stat-value"><%= @cache_stats.total_file_entries %></div>
            </div>
            <div class="stat">
              <div class="stat-title">Total Memory</div>
              <div class="stat-value"><%= Float.round(@cache_stats.total_memory_mb, 2) %> MB</div>
            </div>
          </div>
        </div>
      </div>

      <!-- Per-Node Cache -->
      <div class="card bg-base-100 shadow-xl">
        <div class="card-body">
          <h2 class="card-title">Per-Node Cache</h2>
          <div class="overflow-x-auto">
            <table class="table table-sm">
              <thead>
                <tr>
                  <th>Node</th>
                  <th>Type Entries</th>
                  <th>File Entries</th>
                  <th>Memory</th>
                </tr>
              </thead>
              <tbody>
                <%= for node_cache <- @cache_stats.nodes do %>
                  <tr>
                    <td class="font-mono text-xs">
                      <%= node_cache.node %>
                      <%= if node_cache.node == node() do %>
                        <span class="badge badge-sm badge-primary">local</span>
                      <% end %>
                    </td>
                    <td><%= node_cache.type_cache.entries %></td>
                    <td><%= node_cache.file_cache.entries %></td>
                    <td>
                      <%= Float.round(node_cache.type_cache.memory_mb + node_cache.file_cache.memory_mb, 2) %> MB
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
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

  defp local_registered?(nodes) do
    Enum.any?(nodes, &(&1.node == node()))
  end

  defp status_badge(:online), do: "badge-success"
  defp status_badge(:offline), do: "badge-error"
  defp status_badge(:draining), do: "badge-warning"
  defp status_badge(_), do: "badge-ghost"

  defp load_color(load) when load > 80, do: "progress-error"
  defp load_color(load) when load > 50, do: "progress-warning"
  defp load_color(_), do: "progress-success"

  defp format_timestamp(ms) when is_integer(ms) do
    DateTime.from_unix!(div(ms, 1000))
    |> Calendar.strftime("%H:%M:%S")
  end
  defp format_timestamp(_), do: "-"
end
