defmodule TSC.Telemetry.MetricsTest do
  use ExUnit.Case, async: true

  alias TSC.Telemetry.Metrics

  describe "event names" do
    test "file check events return correct event names" do
      assert Metrics.file_check_start() == [:tsc, :file, :check, :start]
      assert Metrics.file_check_stop() == [:tsc, :file, :check, :stop]
      assert Metrics.file_check_exception() == [:tsc, :file, :check, :exception]
    end

    test "level check events return correct event names" do
      assert Metrics.level_check_start() == [:tsc, :level, :check, :start]
      assert Metrics.level_check_stop() == [:tsc, :level, :check, :stop]
    end

    test "project check events return correct event names" do
      assert Metrics.project_check_start() == [:tsc, :project, :check, :start]
      assert Metrics.project_check_stop() == [:tsc, :project, :check, :stop]
    end

    test "cache events return correct event names" do
      assert Metrics.cache_hit() == [:tsc, :cache, :hit]
      assert Metrics.cache_miss() == [:tsc, :cache, :miss]
    end

    test "worker events return correct event names" do
      assert Metrics.worker_request_start() == [:tsc, :worker, :request, :start]
      assert Metrics.worker_request_stop() == [:tsc, :worker, :request, :stop]
      assert Metrics.worker_crash() == [:tsc, :worker, :crash]
    end

    test "phase events return correct event names" do
      assert Metrics.phase_start() == [:tsc, :phase, :start]
      assert Metrics.phase_stop() == [:tsc, :phase, :stop]
    end
  end

  describe "emit helpers" do
    setup do
      # Attach a test handler to capture events
      test_pid = self()

      handler = fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end

      events = [
        Metrics.file_check_start(),
        Metrics.file_check_stop(),
        Metrics.cache_hit(),
        Metrics.cache_miss(),
        Metrics.phase_start(),
        Metrics.phase_stop()
      ]

      Enum.each(events, fn event ->
        :telemetry.attach("test-#{inspect(event)}", event, handler, nil)
      end)

      on_exit(fn ->
        Enum.each(events, fn event ->
          :telemetry.detach("test-#{inspect(event)}")
        end)
      end)

      :ok
    end

    test "emit_file_check_start emits correct event" do
      Metrics.emit_file_check_start("/path/to/file.ts")

      assert_receive {:telemetry_event, [:tsc, :file, :check, :start], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.file == "/path/to/file.ts"
    end

    test "emit_file_check_stop emits correct event" do
      Metrics.emit_file_check_stop("/path/to/file.ts", 150, {:ok, %{}})

      assert_receive {:telemetry_event, [:tsc, :file, :check, :stop], measurements, metadata}
      assert measurements.duration == 150
      assert metadata.file == "/path/to/file.ts"
      assert metadata.result == {:ok, %{}}
    end

    test "emit_cache_hit emits correct event" do
      Metrics.emit_cache_hit(:type_cache, "/path/to/module.ts")

      assert_receive {:telemetry_event, [:tsc, :cache, :hit], measurements, metadata}
      assert measurements.count == 1
      assert metadata.cache == :type_cache
      assert metadata.key == "/path/to/module.ts"
    end

    test "emit_cache_miss emits correct event" do
      Metrics.emit_cache_miss(:type_cache, "/path/to/module.ts")

      assert_receive {:telemetry_event, [:tsc, :cache, :miss], measurements, metadata}
      assert measurements.count == 1
      assert metadata.cache == :type_cache
    end

    test "emit_phase_start emits correct event" do
      Metrics.emit_phase_start(:parse, %{file: "/test.ts"})

      assert_receive {:telemetry_event, [:tsc, :phase, :start], measurements, metadata}
      assert is_integer(measurements.system_time)
      assert metadata.phase == :parse
      assert metadata.file == "/test.ts"
    end

    test "emit_phase_stop emits correct event" do
      Metrics.emit_phase_stop(:parse, 50, %{file: "/test.ts"})

      assert_receive {:telemetry_event, [:tsc, :phase, :stop], measurements, metadata}
      assert measurements.duration == 50
      assert metadata.phase == :parse
    end
  end

  describe "measure_phase/3" do
    setup do
      test_pid = self()

      handler = fn event, measurements, metadata, _config ->
        send(test_pid, {:telemetry_event, event, measurements, metadata})
      end

      :telemetry.attach("test-phase-start", Metrics.phase_start(), handler, nil)
      :telemetry.attach("test-phase-stop", Metrics.phase_stop(), handler, nil)

      on_exit(fn ->
        :telemetry.detach("test-phase-start")
        :telemetry.detach("test-phase-stop")
      end)

      :ok
    end

    test "measures function duration and emits events" do
      result = Metrics.measure_phase(:check, %{file: "/test.ts"}, fn ->
        Process.sleep(10)
        {:ok, "result"}
      end)

      assert result == {:ok, "result"}

      assert_receive {:telemetry_event, [:tsc, :phase, :start], _, metadata_start}
      assert metadata_start.phase == :check

      assert_receive {:telemetry_event, [:tsc, :phase, :stop], measurements, metadata_stop}
      assert metadata_stop.phase == :check
      assert metadata_stop.status == :success
      assert measurements.duration >= 10
    end

    test "handles exceptions and still emits stop event" do
      assert_raise RuntimeError, fn ->
        Metrics.measure_phase(:parse, %{}, fn ->
          raise "test error"
        end)
      end

      assert_receive {:telemetry_event, [:tsc, :phase, :start], _, _}
      assert_receive {:telemetry_event, [:tsc, :phase, :stop], _, metadata}
      assert metadata.status == :error
    end
  end
end
