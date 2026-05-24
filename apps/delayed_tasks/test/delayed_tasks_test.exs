defmodule DelayedTasksTest do
  use ExUnit.Case, async: false

  alias DelayedTasks.Task

  @test_task_type :test_task

  setup do
    :ets.delete_all_objects(DelayedTasks.Handler)
    :ets.delete_all_objects(:delayed_tasks)
    :ok = DelayedTasks.Handler.register_handler(@test_task_type, DelayedTasks.TestHandler)
    :ok
  end

  describe "schedule/3" do
    test "schedules a task for future execution" do
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      params = %{test: "data"}

      assert {:ok, %Task{id: id}} =
               DelayedTasks.schedule(@test_task_type, params, execute_at: execute_at)

      assert {:ok, task} = DelayedTasks.status(id)
      assert task.type == @test_task_type
      assert task.params == params
      assert task.state == :scheduled
      assert DateTime.compare(task.execute_at, execute_at) == :eq
    end

    test "schedules a task using execute_in" do
      params = %{test: "data"}

      assert {:ok, %Task{id: id}} =
               DelayedTasks.schedule(@test_task_type, params, execute_in: 60)

      assert {:ok, task} = DelayedTasks.status(id)
      assert task.type == @test_task_type
      assert task.state == :scheduled
    end

    test "returns error for unsupported task type" do
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      assert {:error, _} = DelayedTasks.schedule(:unknown_type, %{}, execute_at: execute_at)
    end

    test "returns error when neither execute_at nor execute_in provided" do
      assert {:error, _} = DelayedTasks.schedule(@test_task_type, %{})
    end
  end

  describe "cancel/1" do
    test "cancels a scheduled task" do
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)

      {:ok, %Task{id: id}} =
        DelayedTasks.schedule(@test_task_type, %{}, execute_at: execute_at)

      assert :ok = DelayedTasks.cancel(id)
      assert {:ok, %Task{state: :cancelled}} = DelayedTasks.status(id)
    end

    test "returns error for non-existent task" do
      assert {:error, "Task not found"} = DelayedTasks.cancel("nonexistent_id")
    end
  end

  describe "status/1" do
    test "returns task status" do
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)

      {:ok, %Task{id: id}} =
        DelayedTasks.schedule(@test_task_type, %{}, execute_at: execute_at)

      assert {:ok, %Task{id: ^id}} = DelayedTasks.status(id)
    end

    test "returns error for non-existent task" do
      assert {:error, :not_found} = DelayedTasks.status("nonexistent_id")
    end
  end

  describe "list_tasks_by_state/1" do
    test "lists tasks by state" do
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)

      {:ok, %Task{id: task_id}} =
        DelayedTasks.schedule(@test_task_type, %{id: 1}, execute_at: execute_at)

      scheduled_tasks = DelayedTasks.list_tasks_by_state(:scheduled)

      assert length(scheduled_tasks) == 1
      assert Enum.any?(scheduled_tasks, &(&1.id == task_id))

      assert DelayedTasks.list_tasks_by_state(:processing) == []
      assert DelayedTasks.list_tasks_by_state(:completed) == []
      assert DelayedTasks.list_tasks_by_state(:failed) == []
      assert DelayedTasks.list_tasks_by_state(:cancelled) == []

      task = Enum.find(scheduled_tasks, &(&1.id == task_id))
      assert task.state == :scheduled
    end
  end

  describe "stats/0" do
    test "stats/0 returns task statistics" do
      {:ok, _} = DelayedTasks.schedule(@test_task_type, %{test: "data"}, execute_in: 60)
      {:ok, _} = DelayedTasks.schedule(@test_task_type, %{test: "data"}, execute_in: 120)

      stats = DelayedTasks.stats()

      assert stats.total == 2
      assert stats.by_state[:scheduled] == 2
    end
  end

  describe "task execution" do
    test "executes a task when due" do
      execute_at = DateTime.add(DateTime.utc_now(), 100, :millisecond)
      params = %{test: "data"}

      {:ok, %Task{id: id}} =
        DelayedTasks.schedule(@test_task_type, params, execute_at: execute_at)

      Process.sleep(300)

      assert {:ok, %Task{state: :completed}} = DelayedTasks.status(id)
    end

    test "schedules retry on failure" do
      execute_at = DateTime.add(DateTime.utc_now(), 100, :millisecond)

      defmodule FailingOnceHandler do
        @behaviour DelayedTasks.HandlerBehaviour

        def handle_task(_params) do
          if Process.get(:retry_count) do
            {:ok, %{result: :success_after_retry}}
          else
            Process.put(:retry_count, true)
            {:error, "Temporary failure"}
          end
        end
      end

      :ets.delete_all_objects(DelayedTasks.Handler)
      :ok = DelayedTasks.Handler.register_handler(:retry_test, FailingOnceHandler)

      {:ok, %Task{id: id, execute_at: original_execute_at}} =
        DelayedTasks.schedule(:retry_test, %{test: "data"},
          execute_at: execute_at,
          max_attempts: 3
        )

      Process.sleep(500)

      task = :ets.lookup_element(:delayed_tasks, id, 2)
      assert task.state == :processing or task.state == :scheduled

      Process.sleep(8_500)

      task = :ets.lookup_element(:delayed_tasks, id, 2)
      assert task.state == :scheduled, "Task should be scheduled for retry: #{task.state}"
      assert task.attempts in [1, 2], "Task should have 1 or 2 attempts: #{task.attempts}"

      assert DateTime.compare(task.execute_at, original_execute_at) == :gt,
             "Retry time should be in the future"
    end
  end
end
