defmodule DelayedTasksTest do
  use ExUnit.Case, async: false  # Set to false to avoid async issues with Mox
  import Mox
  
  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!
  
  # Alias the modules for convenience
  alias DelayedTasks.Task
  alias DelayedTasks.TestHandler
  
  # Define a test task type
  @test_task_type :test_task
  
  setup do
    # Start the Manager if not already started
    case Process.whereis(DelayedTasks.Manager) do
      nil ->
        {:ok, _pid} = DelayedTasks.Manager.start_link()
      _ ->
        :ok
    end
    
    # Clear any existing handlers
    :ets.delete_all_objects(DelayedTasks.Handler)
    
    # Register a test handler
    :ok = DelayedTasks.Handler.register_handler(@test_task_type, TestHandler)
    
    # Clear ETS table before each test
    case Process.whereis(DelayedTasks.Manager) do
      pid when is_pid(pid) ->
        :ets.delete_all_objects(:delayed_tasks)
      _ ->
        :ok
    end
    
    :ok
  end
  
  describe "schedule/3" do
    test "schedules a task for future execution" do
      # Set up test data
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      params = %{test: "data"}
      
      # Expect the handler to be called with the task
      expect(TestHandler, :handle_task, fn %Task{type: @test_task_type, params: ^params} ->
        {:ok, %{result: :success}}
      end)
      
      # Schedule the task
      assert {:ok, %Task{id: id}} = 
        DelayedTasks.schedule(@test_task_type, params, execute_at: execute_at)
      
      # Verify the task was stored
      assert {:ok, task} = DelayedTasks.status(id)
      assert task.type == @test_task_type
      assert task.params == params
      assert task.state == :scheduled
      assert DateTime.compare(task.execute_at, execute_at) == :eq
    end
    
    test "returns error for unsupported task type" do
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      assert {:error, _} = DelayedTasks.schedule(:unknown_type, %{}, execute_at: execute_at)
    end
  end
  
  describe "cancel/1" do
    test "cancels a scheduled task" do
      # Schedule a task
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      {:ok, %Task{id: id}} = 
        DelayedTasks.schedule(@test_task_type, %{}, execute_at: execute_at)
      
      # Cancel the task
      assert :ok = DelayedTasks.cancel(id)
      
      # Verify the task was marked as cancelled
      assert {:ok, %Task{state: :cancelled}} = DelayedTasks.status(id)
    end
    
    test "returns error for non-existent task" do
      assert {:error, "Task not found"} = DelayedTasks.cancel("nonexistent_id")
    end
  end
  
  describe "status/1" do
    test "returns task status" do
      # Schedule a task
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      {:ok, %Task{id: id}} = 
        DelayedTasks.schedule(@test_task_type, %{}, execute_at: execute_at)
      
      # Get the status
      assert {:ok, %Task{id: ^id}} = DelayedTasks.status(id)
    end
    
    test "returns error for non-existent task" do
      assert {:error, :not_found} = DelayedTasks.status("nonexistent_id")
    end
  end
  
  describe "list_tasks_by_state/1" do
    test "lists tasks by state" do
      # Schedule a task
      execute_at = DateTime.add(DateTime.utc_now(), 60, :second)
      {:ok, task_id} = DelayedTasks.schedule(@test_task_type, %{id: 1}, execute_at: execute_at)
      
      # Get scheduled tasks
      scheduled_tasks = DelayedTasks.list_tasks_by_state(:scheduled)
      
      # Verify the task is in the list
      assert length(scheduled_tasks) == 1
      assert Enum.any?(scheduled_tasks, &(&1.id == task_id))
      
      # Verify other states are empty
      assert DelayedTasks.list_tasks_by_state(:processing) == []
      assert DelayedTasks.list_tasks_by_state(:completed) == []
      assert DelayedTasks.list_tasks_by_state(:failed) == []
      assert DelayedTasks.list_tasks_by_state(:cancelled) == []
      
      # Verify the task has the correct state
      task = Enum.find(scheduled_tasks, &(&1.id == task_id))
      assert task.state == :scheduled
    end
  end
  
  describe "stats/0" do
    test "stats/0 returns task statistics" do
      # Schedule a couple of tasks
      {:ok, _} = DelayedTasks.schedule(@test_task_type, %{test: "data"}, execute_in: 60)
      {:ok, _} = DelayedTasks.schedule(@test_task_type, %{test: "data"}, execute_in: 120)
      
      # Get stats
      stats = DelayedTasks.stats()
      
      # Verify stats
      assert stats.total == 2
      assert stats.by_state[:scheduled] == 2
      assert stats.by_state[:completed] == nil || stats.by_state[:completed] == 0
      assert stats.by_state[:failed] == nil || stats.by_state[:failed] == 0
      assert stats.by_state[:cancelled] == nil || stats.by_state[:cancelled] == 0
      assert stats.by_state[:processing] == nil || stats.by_state[:processing] == 0
    end
  end
  
  describe "task execution" do
    test "executes a task when due" do
      # Set up test data
      execute_at = DateTime.add(DateTime.utc_now(), 100, :millisecond)
      params = %{test: "data"}
      
      # Expect the handler to be called with the task
      expect(TestHandler, :handle_task, fn %Task{type: @test_task_type, params: ^params} ->
        {:ok, %{result: :success}}
      end)
      
      # Schedule the task
      {:ok, %Task{id: id}} = 
        DelayedTasks.schedule(@test_task_type, params, execute_at: execute_at)
      
      # Wait for the task to be executed
      Process.sleep(200)
      
      # Verify the task was marked as completed
      assert {:ok, %Task{state: :completed}} = DelayedTasks.status(id)
    end
    
    test "retries failed tasks with exponential backoff" do
      # Set up test data
      execute_at = DateTime.utc_now()
      params = %{test: "data"}
      
      # Make the handler fail twice before succeeding
      expect(TestHandler, :handle_task, 3, fn %Task{attempts: attempts} ->
        if attempts < 2 do
          {:error, "Temporary failure"}
        else
          {:ok, %{result: :success_after_retry}}
        end
      end)
      
      # Schedule the task with a short retry delay for testing
      {:ok, %Task{id: id}} = 
        DelayedTasks.schedule(@test_task_type, params, 
          execute_at: execute_at,
          max_attempts: 3
        )
      
      # Wait for the task to be executed and retried
      Process.sleep(500)
      
      # Verify the task was eventually marked as completed
      assert {:ok, %Task{state: :completed, attempts: 3}} = DelayedTasks.status(id)
    end
  end
end
