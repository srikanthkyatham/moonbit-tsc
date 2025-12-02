defmodule TSC.Telemetry.MemoryAnalyzer do
  @moduledoc """
  Memory analysis utilities for TSC.

  Provides detailed memory breakdown and leak detection.
  """

  alias TSC.Cache.{TypeCache, FileCache}

  @doc """
  Get comprehensive memory report.
  """
  @spec full_report() :: map()
  def full_report do
    %{
      system: system_memory(),
      beam: beam_memory(),
      caches: cache_memory(),
      ets: ets_memory(),
      processes: top_processes(10),
      gc_stats: gc_stats(),
      recommendations: generate_recommendations()
    }
  end

  @doc """
  Get system memory info.
  """
  @spec system_memory() :: map()
  def system_memory do
    total = :erlang.memory(:total)
    system = :erlang.memory(:system)

    %{
      total_bytes: total,
      total_mb: bytes_to_mb(total),
      system_bytes: system,
      system_mb: bytes_to_mb(system),
      vm_limit: get_vm_memory_limit()
    }
  end

  @doc """
  Get BEAM memory breakdown.
  """
  @spec beam_memory() :: map()
  def beam_memory do
    memory = :erlang.memory()

    %{
      processes: %{
        bytes: memory[:processes],
        mb: bytes_to_mb(memory[:processes]),
        used: memory[:processes_used],
        percentage: percentage(memory[:processes], memory[:total])
      },
      ets: %{
        bytes: memory[:ets],
        mb: bytes_to_mb(memory[:ets]),
        percentage: percentage(memory[:ets], memory[:total])
      },
      binary: %{
        bytes: memory[:binary],
        mb: bytes_to_mb(memory[:binary]),
        percentage: percentage(memory[:binary], memory[:total])
      },
      atom: %{
        bytes: memory[:atom],
        mb: bytes_to_mb(memory[:atom]),
        used: memory[:atom_used],
        percentage: percentage(memory[:atom], memory[:total])
      },
      code: %{
        bytes: memory[:code],
        mb: bytes_to_mb(memory[:code]),
        percentage: percentage(memory[:code], memory[:total])
      }
    }
  end

  @doc """
  Get TSC cache memory usage.
  """
  @spec cache_memory() :: map()
  def cache_memory do
    type_cache = TypeCache.stats()
    file_cache = FileCache.stats()

    %{
      type_cache: %{
        entries: type_cache.entries,
        memory_mb: type_cache.memory_mb
      },
      file_cache: %{
        entries: file_cache.entries,
        memory_mb: file_cache.memory_mb
      },
      total_mb: type_cache.memory_mb + file_cache.memory_mb
    }
  end

  @doc """
  Get detailed ETS table memory usage.
  """
  @spec ets_memory() :: map()
  def ets_memory do
    word_size = :erlang.system_info(:wordsize)

    tables = :ets.all()
    |> Enum.map(fn table ->
      info = :ets.info(table)

      if info do
        memory = (info[:memory] || 0) * word_size

        %{
          name: info[:name] || table,
          id: table,
          type: info[:type] || :unknown,
          size: info[:size] || 0,
          memory_bytes: memory,
          memory_mb: bytes_to_mb(memory),
          owner: info[:owner],
          protection: info[:protection]
        }
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory_bytes, :desc)

    total_memory = Enum.sum(Enum.map(tables, & &1.memory_bytes))

    %{
      tables: Enum.take(tables, 20),
      total_count: length(tables),
      total_bytes: total_memory,
      total_mb: bytes_to_mb(total_memory)
    }
  end

  @doc """
  Get top memory-consuming processes.
  """
  @spec top_processes(pos_integer()) :: [map()]
  def top_processes(limit \\ 10) do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:memory, :message_queue_len, :heap_size, :stack_size, :reductions, :registered_name, :current_function, :initial_call]) do
        nil ->
          nil

        info ->
          %{
            pid: pid,
            name: info[:registered_name],
            memory_bytes: info[:memory] || 0,
            memory_mb: bytes_to_mb(info[:memory] || 0),
            heap_size: info[:heap_size] || 0,
            stack_size: info[:stack_size] || 0,
            message_queue: info[:message_queue_len] || 0,
            reductions: info[:reductions] || 0,
            current_function: format_mfa(info[:current_function]),
            initial_call: format_mfa(info[:initial_call])
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory_bytes, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Get garbage collection statistics.
  """
  @spec gc_stats() :: map()
  def gc_stats do
    gc_tuple = :erlang.statistics(:garbage_collection)

    %{
      number_of_gcs: elem(gc_tuple, 0),
      words_reclaimed: elem(gc_tuple, 1),
      gc_time_ms: 0  # Not directly available, would need tracing
    }
  end

  @doc """
  Analyze memory trend over samples.
  """
  @spec analyze_trend([map()]) :: map()
  def analyze_trend(samples) when length(samples) < 2 do
    %{trend: :insufficient_data, samples: length(samples)}
  end

  def analyze_trend(samples) do
    memory_values = Enum.map(samples, & &1.memory.total)

    first = List.first(memory_values)
    last = List.last(memory_values)
    avg = Enum.sum(memory_values) / length(memory_values)
    max = Enum.max(memory_values)
    min = Enum.min(memory_values)

    growth_rate = (last - first) / max(first, 1) * 100

    trend = cond do
      growth_rate > 20 -> :growing
      growth_rate < -20 -> :shrinking
      true -> :stable
    end

    %{
      trend: trend,
      growth_rate: Float.round(growth_rate, 2),
      first: first,
      last: last,
      avg: Float.round(avg, 2),
      max: max,
      min: min,
      samples: length(samples)
    }
  end

  @doc """
  Detect potential memory leaks.
  """
  @spec detect_leaks([map()]) :: [map()]
  def detect_leaks(samples) when length(samples) < 10 do
    []
  end

  def detect_leaks(samples) do
    memory_values = Enum.map(samples, & &1.memory.total)
    ets_samples = Enum.map(samples, & &1.memory.ets)
    process_counts = Enum.map(samples, & (&1[:process_count] || 0))

    leaks = []

    # Check for monotonically increasing memory
    leaks = if monotonically_increasing?(memory_values) do
      [%{
        type: :total_memory,
        severity: :high,
        description: "Total memory is monotonically increasing",
        growth: List.last(memory_values) - List.first(memory_values)
      } | leaks]
    else
      leaks
    end

    # Check for growing ETS tables
    leaks = if monotonically_increasing?(ets_samples) and (List.last(ets_samples) - List.first(ets_samples)) > 1_000_000 do
      [%{
        type: :ets_memory,
        severity: :medium,
        description: "ETS memory is steadily growing",
        growth: List.last(ets_samples) - List.first(ets_samples)
      } | leaks]
    else
      leaks
    end

    # Check for growing process count
    if monotonically_increasing?(process_counts) and List.last(process_counts) > List.first(process_counts) + 100 do
      [%{
        type: :process_count,
        severity: :medium,
        description: "Process count is steadily growing",
        growth: List.last(process_counts) - List.first(process_counts)
      } | leaks]
    else
      leaks
    end
  end

  @doc """
  Generate memory optimization recommendations.
  """
  @spec generate_recommendations() :: [map()]
  def generate_recommendations do
    memory = beam_memory()
    caches = cache_memory()
    process_count = length(Process.list())

    recommendations = []

    # Check if ETS is too large
    recommendations = if memory.ets.percentage > 30 do
      [%{
        category: :ets,
        priority: :high,
        issue: "ETS tables using #{memory.ets.percentage}% of total memory",
        suggestion: "Consider clearing old cache entries or implementing LRU eviction"
      } | recommendations]
    else
      recommendations
    end

    # Check if binary memory is high
    recommendations = if memory.binary.percentage > 25 do
      [%{
        category: :binary,
        priority: :medium,
        issue: "Binary heap using #{memory.binary.percentage}% of total memory",
        suggestion: "Check for binary leaks, consider using binary:copy/1 to force copying"
      } | recommendations]
    else
      recommendations
    end

    # Check cache sizes
    recommendations = if caches.type_cache.entries > 10000 do
      [%{
        category: :cache,
        priority: :medium,
        issue: "Type cache has #{caches.type_cache.entries} entries",
        suggestion: "Consider implementing cache eviction or size limits"
      } | recommendations]
    else
      recommendations
    end

    # Check for many processes
    if process_count > 1000 do
      [%{
        category: :processes,
        priority: :low,
        issue: "#{process_count} processes running",
        suggestion: "Review if all processes are necessary"
      } | recommendations]
    else
      recommendations
    end
  end

  # ============================================================================
  # Private Functions
  # ============================================================================

  defp bytes_to_mb(bytes) when is_number(bytes) do
    Float.round(bytes / 1_048_576, 2)
  end
  defp bytes_to_mb(_), do: 0.0

  defp percentage(part, total) when total > 0 do
    Float.round(part / total * 100, 2)
  end
  defp percentage(_, _), do: 0.0

  defp get_vm_memory_limit do
    case System.get_env("ERL_MAX_MEMORY") do
      nil -> :unlimited
      value -> String.to_integer(value)
    end
  end

  defp format_mfa(nil), do: nil
  defp format_mfa({m, f, a}), do: "#{inspect(m)}.#{f}/#{a}"
  defp format_mfa(other), do: inspect(other)

  defp monotonically_increasing?(list) when length(list) < 2, do: false
  defp monotonically_increasing?(list) do
    list
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b >= a end)
  end
end
