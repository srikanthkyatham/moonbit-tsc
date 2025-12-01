defmodule TSC.Cluster.WorkDistributor do
  @moduledoc """
  Distributes compilation work across cluster nodes.

  Implements load balancing strategies:
  - Round-robin
  - Least-loaded
  - Locality-aware (prefer nodes with cached files)
  """

  use GenServer

  alias TSC.Cluster.NodeRegistry
  alias TSC.Telemetry.Metrics

  require Logger

  @work_table :tsc_distributed_work

  # ============================================================================
  # Types
  # ============================================================================

  @type strategy :: :round_robin | :least_loaded | :locality_aware
  @type work_item :: %{
    id: String.t(),
    files: [String.t()],
    options: map(),
    assigned_node: node() | nil,
    status: :pending | :assigned | :in_progress | :completed | :failed,
    created_at: integer(),
    started_at: integer() | nil,
    completed_at: integer() | nil,
    result: any()
  }

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Distribute files across cluster for type checking.
  Returns a work batch ID.
  """
  @spec distribute_check([String.t()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def distribute_check(files, opts \\ []) do
    GenServer.call(__MODULE__, {:distribute, files, opts}, 30_000)
  end

  @doc """
  Get status of a work batch.
  """
  @spec get_batch_status(String.t()) :: map() | nil
  def get_batch_status(batch_id) do
    GenServer.call(__MODULE__, {:get_batch_status, batch_id})
  end

  @doc """
  Wait for a batch to complete.
  """
  @spec await_batch(String.t(), timeout()) :: {:ok, map()} | {:error, :timeout}
  def await_batch(batch_id, timeout \\ 60_000) do
    GenServer.call(__MODULE__, {:await_batch, batch_id, timeout}, timeout + 5_000)
  end

  @doc """
  Execute work item locally (called by remote nodes).
  """
  @spec execute_local(map()) :: {:ok, map()} | {:error, term()}
  def execute_local(work_item) do
    GenServer.call(__MODULE__, {:execute_local, work_item}, 120_000)
  end

  @doc """
  Report work completion (called by worker nodes).
  """
  @spec report_completion(String.t(), String.t(), any()) :: :ok
  def report_completion(batch_id, work_id, result) do
    GenServer.cast(__MODULE__, {:work_completed, batch_id, work_id, result})
  end

  @doc """
  Get current distribution strategy.
  """
  @spec get_strategy() :: strategy()
  def get_strategy do
    GenServer.call(__MODULE__, :get_strategy)
  end

  @doc """
  Set distribution strategy.
  """
  @spec set_strategy(strategy()) :: :ok
  def set_strategy(strategy) do
    GenServer.call(__MODULE__, {:set_strategy, strategy})
  end

  @doc """
  Get distribution statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(_opts) do
    :ets.new(@work_table, [:named_table, :public, :set])

    state = %{
      strategy: :least_loaded,
      round_robin_index: 0,
      batches: %{},
      waiters: %{},
      stats: %{
        total_batches: 0,
        total_files: 0,
        distributed_files: 0,
        local_files: 0,
        failed_files: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:distribute, files, opts}, from, state) do
    strategy = Keyword.get(opts, :strategy, state.strategy)
    batch_id = generate_batch_id()

    nodes = get_available_nodes()

    if length(nodes) == 0 do
      {:reply, {:error, :no_nodes_available}, state}
    else
      # Partition files among nodes
      work_items = partition_files(files, nodes, strategy, state)

      batch = %{
        id: batch_id,
        total_files: length(files),
        work_items: work_items,
        completed_items: [],
        failed_items: [],
        status: :in_progress,
        created_at: System.system_time(:millisecond),
        options: Map.new(opts)
      }

      # Store batch
      new_batches = Map.put(state.batches, batch_id, batch)

      # Dispatch work to nodes
      dispatch_work(batch_id, work_items)

      # Update stats
      distributed = Enum.count(work_items, &(&1.assigned_node != node()))
      local = length(work_items) - distributed

      new_stats = %{state.stats |
        total_batches: state.stats.total_batches + 1,
        total_files: state.stats.total_files + length(files),
        distributed_files: state.stats.distributed_files + distributed,
        local_files: state.stats.local_files + local
      }

      # Update round robin index
      new_rr_index = rem(state.round_robin_index + length(work_items), max(length(nodes), 1))

      new_state = %{state |
        batches: new_batches,
        stats: new_stats,
        round_robin_index: new_rr_index
      }

      Logger.info("Distributed batch #{batch_id}: #{length(files)} files across #{length(nodes)} nodes")

      {:reply, {:ok, batch_id}, new_state}
    end
  end

  @impl true
  def handle_call({:get_batch_status, batch_id}, _from, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:reply, nil, state}

      batch ->
        status = %{
          id: batch.id,
          status: batch.status,
          total_files: batch.total_files,
          completed: length(batch.completed_items),
          failed: length(batch.failed_items),
          pending: length(batch.work_items) - length(batch.completed_items) - length(batch.failed_items),
          created_at: batch.created_at
        }
        {:reply, status, state}
    end
  end

  @impl true
  def handle_call({:await_batch, batch_id, timeout}, from, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      %{status: :completed} = batch ->
        {:reply, {:ok, compile_batch_result(batch)}, state}

      %{status: :failed} = batch ->
        {:reply, {:error, compile_batch_result(batch)}, state}

      _batch ->
        # Add to waiters
        timer_ref = Process.send_after(self(), {:await_timeout, batch_id, from}, timeout)
        waiters = Map.update(state.waiters, batch_id, [{from, timer_ref}], &[{from, timer_ref} | &1])
        {:noreply, %{state | waiters: waiters}}
    end
  end

  @impl true
  def handle_call({:execute_local, work_item}, _from, state) do
    # Execute type checking locally
    result = do_local_check(work_item)
    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_strategy, _from, state) do
    {:reply, state.strategy, state}
  end

  @impl true
  def handle_call({:set_strategy, strategy}, _from, state) do
    {:reply, :ok, %{state | strategy: strategy}}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    cluster_stats = NodeRegistry.cluster_stats()

    stats = Map.merge(state.stats, %{
      active_batches: map_size(state.batches),
      cluster: cluster_stats
    })

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:work_completed, batch_id, work_id, result}, state) do
    case Map.get(state.batches, batch_id) do
      nil ->
        {:noreply, state}

      batch ->
        # Update batch
        {status, completed, failed} = case result do
          {:ok, _} ->
            {:ok, [%{work_id: work_id, result: result} | batch.completed_items], batch.failed_items}

          {:error, _} ->
            {:error, batch.completed_items, [%{work_id: work_id, result: result} | batch.failed_items]}
        end

        total_done = length(completed) + length(failed)
        batch_status = if total_done >= length(batch.work_items) do
          if length(failed) > 0, do: :failed, else: :completed
        else
          :in_progress
        end

        updated_batch = %{batch |
          completed_items: completed,
          failed_items: failed,
          status: batch_status
        }

        new_batches = Map.put(state.batches, batch_id, updated_batch)

        # Notify waiters if complete
        new_waiters = if batch_status in [:completed, :failed] do
          notify_waiters(state.waiters, batch_id, updated_batch)
          Map.delete(state.waiters, batch_id)
        else
          state.waiters
        end

        # Update stats on failure
        new_stats = case status do
          :error -> %{state.stats | failed_files: state.stats.failed_files + 1}
          _ -> state.stats
        end

        {:noreply, %{state | batches: new_batches, waiters: new_waiters, stats: new_stats}}
    end
  end

  @impl true
  def handle_info({:await_timeout, batch_id, from}, state) do
    GenServer.reply(from, {:error, :timeout})

    # Remove from waiters
    new_waiters = Map.update(state.waiters, batch_id, [], fn waiters ->
      Enum.reject(waiters, fn {f, _} -> f == from end)
    end)

    {:noreply, %{state | waiters: new_waiters}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp generate_batch_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp get_available_nodes do
    NodeRegistry.nodes_with_capability(:compiler)
    |> Enum.filter(&(&1.status == :online))
    |> Enum.filter(&(&1.available_workers > 0))
  end

  defp partition_files(files, nodes, strategy, state) do
    case strategy do
      :round_robin ->
        partition_round_robin(files, nodes, state.round_robin_index)

      :least_loaded ->
        partition_least_loaded(files, nodes)

      :locality_aware ->
        partition_locality_aware(files, nodes)
    end
  end

  defp partition_round_robin(files, nodes, start_index) do
    node_list = Enum.map(nodes, & &1.node)
    node_count = length(node_list)

    files
    |> Enum.with_index(start_index)
    |> Enum.map(fn {file, idx} ->
      assigned_node = Enum.at(node_list, rem(idx, node_count))
      create_work_item([file], assigned_node)
    end)
  end

  defp partition_least_loaded(files, nodes) do
    # Sort nodes by load (ascending)
    sorted_nodes = Enum.sort_by(nodes, & &1.load)

    # Assign files to least loaded nodes, respecting available workers
    {work_items, _} = Enum.reduce(files, {[], sorted_nodes}, fn file, {items, available_nodes} ->
      case available_nodes do
        [] ->
          # All nodes busy, assign to first node anyway
          node = hd(sorted_nodes).node
          {[create_work_item([file], node) | items], sorted_nodes}

        [node | rest] ->
          item = create_work_item([file], node.node)
          # Move used node to end with increased load
          updated = %{node | available_workers: node.available_workers - 1}
          new_available = if updated.available_workers > 0 do
            rest ++ [updated]
          else
            rest
          end
          {[item | items], new_available}
      end
    end)

    Enum.reverse(work_items)
  end

  defp partition_locality_aware(files, nodes) do
    # Group files by directory for locality
    grouped = Enum.group_by(files, &Path.dirname/1)

    # Assign each group to a node
    node_list = Enum.map(nodes, & &1.node)
    node_count = length(node_list)

    grouped
    |> Enum.with_index()
    |> Enum.flat_map(fn {{_dir, dir_files}, idx} ->
      assigned_node = Enum.at(node_list, rem(idx, node_count))
      # Create one work item per file in the group
      Enum.map(dir_files, fn file ->
        create_work_item([file], assigned_node)
      end)
    end)
  end

  defp create_work_item(files, assigned_node) do
    %{
      id: :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower),
      files: files,
      assigned_node: assigned_node,
      status: :pending,
      created_at: System.system_time(:millisecond),
      started_at: nil,
      completed_at: nil,
      result: nil
    }
  end

  defp dispatch_work(batch_id, work_items) do
    Enum.each(work_items, fn item ->
      if item.assigned_node == node() do
        # Execute locally
        Task.start(fn ->
          result = do_local_check(item)
          report_completion(batch_id, item.id, result)
        end)
      else
        # Send to remote node
        Task.start(fn ->
          result = execute_remote(item.assigned_node, item)
          report_completion(batch_id, item.id, result)
        end)
      end
    end)
  end

  defp execute_remote(remote_node, work_item) do
    try do
      GenServer.call({__MODULE__, remote_node}, {:execute_local, work_item}, 60_000)
    catch
      :exit, reason ->
        Logger.error("Remote execution failed on #{remote_node}: #{inspect(reason)}")
        {:error, {:remote_failure, reason}}
    end
  end

  defp do_local_check(work_item) do
    Metrics.emit_file_check_start(hd(work_item.files))
    start_time = System.monotonic_time(:millisecond)

    try do
      # Use the coordinator for actual checking
      result = Enum.map(work_item.files, &TSC.Coordinator.check_file(&1, []))

      duration = System.monotonic_time(:millisecond) - start_time
      Metrics.emit_file_check_stop(hd(work_item.files), duration, result)

      {:ok, %{
        files: work_item.files,
        result: result,
        duration_ms: duration
      }}
    rescue
      e ->
        duration = System.monotonic_time(:millisecond) - start_time
        Metrics.emit_file_check_stop(hd(work_item.files), duration, {:error, e})

        {:error, %{
          files: work_item.files,
          error: Exception.message(e),
          duration_ms: duration
        }}
    end
  end

  defp compile_batch_result(batch) do
    %{
      id: batch.id,
      status: batch.status,
      total_files: batch.total_files,
      completed: length(batch.completed_items),
      failed: length(batch.failed_items),
      results: Enum.map(batch.completed_items, & &1.result),
      errors: Enum.map(batch.failed_items, & &1.result),
      duration_ms: System.system_time(:millisecond) - batch.created_at
    }
  end

  defp notify_waiters(waiters, batch_id, batch) do
    case Map.get(waiters, batch_id) do
      nil ->
        :ok

      waiting ->
        result = compile_batch_result(batch)
        reply = if batch.status == :completed, do: {:ok, result}, else: {:error, result}

        Enum.each(waiting, fn {from, timer_ref} ->
          Process.cancel_timer(timer_ref)
          GenServer.reply(from, reply)
        end)
    end
  end
end
