defmodule TSC.Cluster.NodeRegistry do
  @moduledoc """
  Registry for tracking nodes in the TSC cluster.

  Manages node discovery, health monitoring, and capability tracking.
  Each node can have different capabilities (workers, caches, etc).
  """

  use GenServer

  require Logger

  @registry_table :tsc_node_registry
  @heartbeat_interval 5_000
  @node_timeout 15_000

  # ============================================================================
  # Types
  # ============================================================================

  @type node_info :: %{
    node: node(),
    name: String.t(),
    status: :online | :offline | :draining,
    capabilities: [atom()],
    workers: non_neg_integer(),
    available_workers: non_neg_integer(),
    load: float(),
    memory_mb: float(),
    connected_at: integer(),
    last_heartbeat: integer(),
    metadata: map()
  }

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Register the current node with capabilities.
  """
  @spec register(keyword()) :: :ok
  def register(opts \\ []) do
    GenServer.call(__MODULE__, {:register, opts})
  end

  @doc """
  Unregister the current node.
  """
  @spec unregister() :: :ok
  def unregister do
    GenServer.call(__MODULE__, :unregister)
  end

  @doc """
  Get all registered nodes.
  """
  @spec list_nodes() :: [node_info()]
  def list_nodes do
    :ets.tab2list(@registry_table)
    |> Enum.map(fn {_node, info} -> info end)
    |> Enum.sort_by(& &1.connected_at)
  end

  @doc """
  Get online nodes only.
  """
  @spec online_nodes() :: [node_info()]
  def online_nodes do
    list_nodes()
    |> Enum.filter(&(&1.status == :online))
  end

  @doc """
  Get nodes with specific capability.
  """
  @spec nodes_with_capability(atom()) :: [node_info()]
  def nodes_with_capability(capability) do
    online_nodes()
    |> Enum.filter(&(capability in &1.capabilities))
  end

  @doc """
  Get info for a specific node.
  """
  @spec get_node(node()) :: node_info() | nil
  def get_node(node_name) do
    case :ets.lookup(@registry_table, node_name) do
      [{^node_name, info}] -> info
      [] -> nil
    end
  end

  @doc """
  Get the local node info.
  """
  @spec local_node() :: node_info() | nil
  def local_node do
    get_node(node())
  end

  @doc """
  Update node load metrics.
  """
  @spec update_load(float(), non_neg_integer()) :: :ok
  def update_load(load, available_workers) do
    GenServer.cast(__MODULE__, {:update_load, load, available_workers})
  end

  @doc """
  Set node to draining mode (no new work).
  """
  @spec drain() :: :ok
  def drain do
    GenServer.call(__MODULE__, :drain)
  end

  @doc """
  Get cluster statistics.
  """
  @spec cluster_stats() :: map()
  def cluster_stats do
    nodes = online_nodes()

    %{
      total_nodes: length(nodes),
      total_workers: Enum.sum(Enum.map(nodes, & &1.workers)),
      available_workers: Enum.sum(Enum.map(nodes, & &1.available_workers)),
      total_memory_mb: Enum.sum(Enum.map(nodes, & &1.memory_mb)),
      avg_load: safe_avg(Enum.map(nodes, & &1.load)),
      capabilities: nodes
        |> Enum.flat_map(& &1.capabilities)
        |> Enum.uniq()
    }
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    # Create ETS table
    :ets.new(@registry_table, [:named_table, :public, :set])

    # Monitor node connections/disconnections
    :net_kernel.monitor_nodes(true, [:nodedown_reason])

    # Start heartbeat
    schedule_heartbeat()

    # Auto-register this node
    state = %{
      registered: false,
      capabilities: [:compiler, :cache],
      workers: System.schedulers_online()
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:register, opts}, _from, state) do
    capabilities = Keyword.get(opts, :capabilities, [:compiler, :cache])
    workers = Keyword.get(opts, :workers, System.schedulers_online())
    name = Keyword.get(opts, :name, to_string(node()))
    metadata = Keyword.get(opts, :metadata, %{})

    now = System.system_time(:millisecond)
    memory = :erlang.memory(:total) / 1_048_576

    node_info = %{
      node: node(),
      name: name,
      status: :online,
      capabilities: capabilities,
      workers: workers,
      available_workers: workers,
      load: 0.0,
      memory_mb: Float.round(memory, 2),
      connected_at: now,
      last_heartbeat: now,
      metadata: metadata
    }

    :ets.insert(@registry_table, {node(), node_info})

    # Broadcast to other nodes
    broadcast_node_update(:node_joined, node_info)

    Logger.info("Node registered: #{name} with capabilities: #{inspect(capabilities)}")

    new_state = %{state |
      registered: true,
      capabilities: capabilities,
      workers: workers
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:unregister, _from, state) do
    if state.registered do
      node_info = get_node(node())

      if node_info do
        broadcast_node_update(:node_left, node_info)
      end

      :ets.delete(@registry_table, node())
      Logger.info("Node unregistered: #{node()}")
    end

    {:reply, :ok, %{state | registered: false}}
  end

  @impl true
  def handle_call(:drain, _from, state) do
    case :ets.lookup(@registry_table, node()) do
      [{_, info}] ->
        updated = %{info | status: :draining}
        :ets.insert(@registry_table, {node(), updated})
        broadcast_node_update(:node_draining, updated)
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_registered}, state}
    end
  end

  @impl true
  def handle_cast({:update_load, load, available_workers}, state) do
    case :ets.lookup(@registry_table, node()) do
      [{_, info}] ->
        memory = :erlang.memory(:total) / 1_048_576
        updated = %{info |
          load: Float.round(load, 2),
          available_workers: available_workers,
          memory_mb: Float.round(memory, 2),
          last_heartbeat: System.system_time(:millisecond)
        }
        :ets.insert(@registry_table, {node(), updated})

      [] ->
        :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:remote_node_update, action, node_info}, state) do
    case action do
      :node_joined ->
        :ets.insert(@registry_table, {node_info.node, node_info})
        Logger.info("Remote node joined: #{node_info.name}")

      :node_left ->
        :ets.delete(@registry_table, node_info.node)
        Logger.info("Remote node left: #{node_info.name}")

      :node_draining ->
        :ets.insert(@registry_table, {node_info.node, node_info})
        Logger.info("Remote node draining: #{node_info.name}")

      :heartbeat ->
        # Update remote node's heartbeat
        case :ets.lookup(@registry_table, node_info.node) do
          [{_, existing}] ->
            updated = %{existing |
              last_heartbeat: node_info.last_heartbeat,
              load: node_info.load,
              available_workers: node_info.available_workers,
              memory_mb: node_info.memory_mb
            }
            :ets.insert(@registry_table, {node_info.node, updated})

          [] ->
            # Node not known, add it
            :ets.insert(@registry_table, {node_info.node, node_info})
        end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:heartbeat, state) do
    if state.registered do
      # Update local heartbeat
      case :ets.lookup(@registry_table, node()) do
        [{_, info}] ->
          memory = :erlang.memory(:total) / 1_048_576
          updated = %{info |
            last_heartbeat: System.system_time(:millisecond),
            memory_mb: Float.round(memory, 2)
          }
          :ets.insert(@registry_table, {node(), updated})

          # Broadcast heartbeat to other nodes
          broadcast_node_update(:heartbeat, updated)

        [] ->
          :ok
      end

      # Check for timed out nodes
      check_node_timeouts()
    end

    schedule_heartbeat()
    {:noreply, state}
  end

  @impl true
  def handle_info({:nodeup, remote_node, _info}, state) do
    Logger.info("Node connected: #{remote_node}")

    # Request their registration info
    if state.registered do
      local_info = get_node(node())
      if local_info do
        send_to_node(remote_node, {:remote_node_update, :node_joined, local_info})
      end
    end

    {:noreply, state}
  end

  @impl true
  def handle_info({:nodedown, remote_node, info}, state) do
    Logger.warning("Node disconnected: #{remote_node}, reason: #{inspect(info)}")

    # Remove from registry
    :ets.delete(@registry_table, remote_node)

    # Broadcast the disconnection
    Phoenix.PubSub.broadcast(
      TscPhoenix.PubSub,
      "cluster:updates",
      {:node_disconnected, remote_node}
    )

    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  defp broadcast_node_update(action, node_info) do
    # Broadcast to local PubSub
    Phoenix.PubSub.broadcast(
      TscPhoenix.PubSub,
      "cluster:updates",
      {action, node_info}
    )

    # Send to all connected nodes
    for remote_node <- Node.list() do
      send_to_node(remote_node, {:remote_node_update, action, node_info})
    end
  end

  defp send_to_node(remote_node, message) do
    # Send to the NodeRegistry on the remote node
    GenServer.cast({__MODULE__, remote_node}, message)
  end

  defp check_node_timeouts do
    now = System.system_time(:millisecond)
    cutoff = now - @node_timeout

    list_nodes()
    |> Enum.filter(fn info ->
      info.node != node() and info.last_heartbeat < cutoff
    end)
    |> Enum.each(fn info ->
      Logger.warning("Node timed out: #{info.name}")
      :ets.delete(@registry_table, info.node)

      Phoenix.PubSub.broadcast(
        TscPhoenix.PubSub,
        "cluster:updates",
        {:node_timeout, info}
      )
    end)
  end

  defp safe_avg([]), do: 0.0
  defp safe_avg(list), do: Float.round(Enum.sum(list) / length(list), 2)
end
