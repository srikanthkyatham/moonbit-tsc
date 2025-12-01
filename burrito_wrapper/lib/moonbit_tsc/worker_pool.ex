defmodule MoonbitTsc.WorkerPool do
  @moduledoc """
  Worker pool for parallel TypeScript compilation.

  Uses a simple pooling strategy to manage concurrent compilation tasks
  without overloading system resources.
  """

  use GenServer

  require Logger

  @default_pool_size System.schedulers_online()

  # ============================================================================
  # Public API
  # ============================================================================

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submit a compilation job to the pool.
  Returns immediately with a reference that can be used to await results.
  """
  @spec submit(atom(), [String.t()], keyword()) :: {:ok, reference()} | {:error, term()}
  def submit(operation, files, opts \\ []) do
    GenServer.call(__MODULE__, {:submit, operation, files, opts})
  end

  @doc """
  Wait for a job to complete.
  """
  @spec await(reference(), timeout()) :: {:ok, term()} | {:error, term()}
  def await(ref, timeout \\ 60_000) do
    receive do
      {:job_result, ^ref, result} -> result
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Submit and wait for a compilation job.
  """
  @spec run(atom(), [String.t()], keyword()) :: {:ok, term()} | {:error, term()}
  def run(operation, files, opts \\ []) do
    case submit(operation, files, opts) do
      {:ok, ref} -> await(ref, Keyword.get(opts, :timeout, 60_000))
      error -> error
    end
  end

  @doc """
  Get pool statistics.
  """
  @spec stats() :: map()
  def stats do
    GenServer.call(__MODULE__, :stats)
  end

  # ============================================================================
  # GenServer Callbacks
  # ============================================================================

  @impl true
  def init(opts) do
    pool_size = Keyword.get(opts, :pool_size, @default_pool_size)

    state = %{
      pool_size: pool_size,
      active_jobs: %{},
      pending_jobs: :queue.new(),
      stats: %{
        total_jobs: 0,
        completed_jobs: 0,
        failed_jobs: 0,
        total_time_ms: 0
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:submit, operation, files, opts}, {from_pid, _}, state) do
    ref = make_ref()

    job = %{
      ref: ref,
      operation: operation,
      files: files,
      opts: opts,
      from: from_pid,
      submitted_at: System.monotonic_time(:millisecond)
    }

    new_state = if map_size(state.active_jobs) < state.pool_size do
      start_job(job, state)
    else
      # Queue the job
      %{state | pending_jobs: :queue.in(job, state.pending_jobs)}
    end

    {:reply, {:ok, ref}, new_state}
  end

  @impl true
  def handle_call(:stats, _from, state) do
    stats = Map.merge(state.stats, %{
      active_jobs: map_size(state.active_jobs),
      pending_jobs: :queue.len(state.pending_jobs),
      pool_size: state.pool_size
    })
    {:reply, stats, state}
  end

  @impl true
  def handle_info({:job_done, task_ref, result}, state) do
    case Map.pop(state.active_jobs, task_ref) do
      {nil, _} ->
        {:noreply, state}

      {job, remaining_jobs} ->
        duration = System.monotonic_time(:millisecond) - job.submitted_at

        # Send result to caller
        send(job.from, {:job_result, job.ref, result})

        # Update stats
        {completed, failed} = case result do
          {:ok, _} -> {1, 0}
          {:error, _} -> {0, 1}
        end

        new_stats = %{state.stats |
          completed_jobs: state.stats.completed_jobs + completed,
          failed_jobs: state.stats.failed_jobs + failed,
          total_time_ms: state.stats.total_time_ms + duration
        }

        # Start next pending job if any
        new_state = case :queue.out(state.pending_jobs) do
          {{:value, next_job}, remaining_queue} ->
            started = start_job(next_job, %{state |
              active_jobs: remaining_jobs,
              pending_jobs: remaining_queue,
              stats: new_stats
            })
            started

          {:empty, _} ->
            %{state |
              active_jobs: remaining_jobs,
              stats: new_stats
            }
        end

        {:noreply, new_state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp start_job(job, state) do
    parent = self()

    task = Task.async(fn ->
      result = execute_job(job)
      result
    end)

    # Monitor the task
    Process.monitor(task.pid)

    # Store with task ref
    new_active = Map.put(state.active_jobs, task.ref, job)

    # Spawn watcher to handle task completion
    spawn(fn ->
      result = Task.await(task, :infinity)
      send(parent, {:job_done, task.ref, result})
    end)

    %{state |
      active_jobs: new_active,
      stats: %{state.stats | total_jobs: state.stats.total_jobs + 1}
    }
  end

  defp execute_job(job) do
    case job.operation do
      :compile ->
        MoonbitTsc.Compiler.compile(job.files, job.opts)

      :check ->
        MoonbitTsc.Compiler.check(job.files, job.opts)

      _ ->
        {:error, {:unknown_operation, job.operation}}
    end
  end
end
