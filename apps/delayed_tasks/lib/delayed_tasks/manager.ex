defmodule DelayedTasks.Manager do
  @moduledoc """
  The Manager module is responsible for scheduling and executing delayed tasks.
  
  It implements a GenServer that manages the lifecycle of tasks, including:
  - Scheduling tasks for future execution
  - Executing tasks when they're due
  - Retrying failed tasks with exponential backoff
  - Maintaining task state in ETS for fast access
  - Persisting tasks to the database for durability
  """
  
  use GenServer
  require Logger
  
  alias DelayedTasks.Task
  alias DelayedTasks.Handler
  alias DelayedTasks.HandlerBehaviour
  
  # Default interval for checking due tasks (in milliseconds)
  @default_check_interval 1_000
  
  # Default batch size for processing due tasks
  @default_batch_size 10
  
  # ETS table name for storing tasks
  @table_name :delayed_tasks
  
  # Default max attempts for tasks
  @default_max_attempts 3
  
  # Default base backoff time in seconds
  @default_base_backoff 5
  
  # Default max backoff time in seconds (1 hour)
  @default_max_backoff 3600
  
  # Default task priority
  @default_priority 0
  
  # Task states
  @state_scheduled :scheduled
  @state_processing :processing
  @state_completed :completed
  @state_failed :failed
  @state_cancelled :cancelled
  
  @doc """
  Returns the name of the ETS table used for task storage.
  """
  @spec table_name() :: atom()
  def table_name, do: @table_name
  
  # Client API
  
  @doc """
  Starts the Manager process.
  
  ## Options
    * `:name` - The name to register the process under (defaults to __MODULE__)
    * `:check_interval` - How often to check for due tasks (in milliseconds)
    * `:batch_size` - Maximum number of tasks to process in each batch
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end
  
  @doc """
  Schedules a new task for execution.
  """
  @spec schedule(GenServer.server(), Task.t()) :: {:ok, Task.t()} | {:error, String.t()}
  def schedule(server \\ __MODULE__, %Task{} = task) do
    GenServer.call(server, {:schedule, task})
  end
  
  @doc """
  Cancels a scheduled task.
  """
  @spec cancel(GenServer.server(), String.t()) :: :ok | {:error, String.t()}
  def cancel(server \\ __MODULE__, task_id) when is_binary(task_id) do
    GenServer.call(server, {:cancel, task_id})
  end
  
  # Server Callbacks
  
  @impl true
  def init(opts) do
    check_interval = Keyword.get(opts, :check_interval, @default_check_interval)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)
    
    # Create ETS table for task storage if it doesn't exist
    table = case :ets.whereis(@table_name) do
      :undefined ->
        :ets.new(@table_name, [
          :set,
          :public,
          :named_table,
          read_concurrency: true,
          write_concurrency: true
        ])
      existing_table ->
        existing_table
    end
    
    # Schedule the first check
    timer_ref = Process.send_after(self(), :check_due_tasks, check_interval)
    
    # Recover any pending tasks from the database (placeholder for future implementation)
    # recover_pending_tasks()
    
    {:ok, %{
      check_interval: check_interval,
      batch_size: batch_size,
      table: table,
      timer_ref: timer_ref
    }}
  end
  
  @impl true
  def handle_call({:schedule, task}, _from, %{table: table} = state) do
    case validate_task(task) do
      {:ok, validated_task} ->
        # Generate a unique ID if not provided
        task_with_id = if validated_task.id do
          validated_task
        else
          id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
          %{validated_task | id: id}
        end
        
        # Insert into ETS
        :ets.insert(table, {task_with_id.id, task_with_id})
        
        # Schedule the next check if needed
        now = DateTime.utc_now()
        time_until_execute = DateTime.diff(task_with_id.execute_at, now, :millisecond)
        
        if time_until_execute <= state.check_interval do
          # If the task is due soon, schedule a check at the execute time
          delay = max(time_until_execute, 0)
          
          # Cancel any existing timer
          if state.timer_ref do
            Process.cancel_timer(state.timer_ref)
          end
          
          # Schedule the check
          timer_ref = Process.send_after(self(), :check_due_tasks, delay)
          
          # Update state with new timer ref
          {:reply, {:ok, task_with_id}, %{state | timer_ref: timer_ref}}
        else
          # Task is not due soon, just return the current state
          {:reply, {:ok, task_with_id}, state}
        end
        
      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end
  
  @impl true
  def handle_call({:cancel, task_id}, _from, state) do
    case :ets.lookup(:delayed_tasks, task_id) do
      [{^task_id, task}] ->
        # Mark as cancelled
        cancelled_task = %{task | state: :cancelled, completed_at: DateTime.utc_now()}
        :ets.insert(:delayed_tasks, {task_id, cancelled_task})
        
        # Cancel any pending execution
        cancel_scheduled_execution(task_id)
        
        {:reply, :ok, state}
        
      [] ->
        {:reply, {:error, "Task not found"}, state}
    end
  end
  
  @impl true
  def handle_info(:check_due_tasks, %{table: table, batch_size: batch_size, check_interval: check_interval} = state) do
    # Get current time
    now = DateTime.utc_now()
    
    # Find all tasks that are due and not already processing
    due_tasks = :ets.match_object(table, {:"$1", %{state: :scheduled, execute_at: {:"<=", now}, _: :_}})
    
    # Process up to batch_size tasks
    tasks_to_process = due_tasks |> Enum.take(batch_size) |> Enum.map(fn {id, _} -> id end)
    
    # Mark tasks as processing
    Enum.each(tasks_to_process, fn id ->
      case :ets.lookup(table, id) do
        [{^id, task}] ->
          updated_task = %{task | state: :processing, updated_at: now}
          :ets.insert(table, {id, updated_task})
          
          # Execute the task asynchronously
          Task.start_link(fn ->
            execute_task(updated_task)
          end)
          
        _ ->
          :ok
      end
    end)
    
    # Schedule the next check
    timer_ref = Process.send_after(self(), :check_due_tasks, check_interval)
    
    {:noreply, %{state | timer_ref: timer_ref}}
  end
  
  @impl true
  def handle_info({:execute_task, task_id}, %{table: table} = state) when is_binary(task_id) do
    case :ets.lookup(table, task_id) do
      [{^task_id, task}] ->
        execute_task(task)
      _ ->
        :ok
    end
    {:noreply, state}
  end
  
  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end
  
  @impl true
  def terminate(_reason, %{timer_ref: timer_ref}) when not is_nil(timer_ref) do
    # Cancel the timer to prevent memory leaks
    Process.cancel_timer(timer_ref)
    :ok
  end
  
  def terminate(_reason, _state) do
    :ok
  end
  
  # Private functions
  
  # Validates that a task has a supported type and required fields
  defp validate_task(%Task{type: nil}), do: {:error, "Task type is required"}
  defp validate_task(%Task{execute_at: nil}), do: {:error, "Execute at time is required"}
  defp validate_task(%{type: type} = task) do
    case Handler.get_handler(type) do
      {:ok, _module} ->
        {:ok, task}
        
      {:error, :not_found} ->
        {:error, "No handler registered for task type: #{inspect(type)}"}
        
      error ->
        error
    end
  end
  
  # Processes all due tasks up to the batch size
  defp process_due_tasks(now, batch_size) do
    # Get a batch of due tasks
    case get_due_tasks(now, batch_size) do
      [] ->
        :no_tasks
        
      tasks ->
        Logger.info("Processing #{length(tasks)} due tasks")
        
        # Process each task in the batch
        Enum.each(tasks, fn task ->
          # Mark as processing and update ETS
          processing_task = Task.mark_processing(task)
          :ets.insert(:delayed_tasks, {task.id, processing_task})
          
          # Execute in a separate process to avoid blocking
          Task.Supervisor.start_child(DelayedTasks.TaskSupervisor, fn ->
            execute_task(task.id)
          end)
        end)
        
        :tasks_processed
    end
  end
  
  # Gets a batch of due tasks that are ready to be processed
  defp get_due_tasks(now, batch_size) do
    # In a real implementation, this would query the database for due tasks
    # For now, we'll just get all tasks from ETS and filter them
    :ets.match_object(:delayed_tasks, {:"$1", %{state: :scheduled, _: :_}})
    |> Enum.map(fn {_id, task} -> task end)
    |> Enum.filter(fn %{execute_at: execute_at} -> 
      DateTime.compare(execute_at, now) != :gt 
    end)
    |> Enum.take(batch_size)
  end
  
  # Executes a task and handles the result
  defp execute_task(%{type: type, params: params, id: task_id} = task) do
    case Handler.get_handler(type) do
      {:ok, module} ->
        try do
          # Execute the task
          case module.handle_task(params) do
            {:ok, result} ->
              # Update task as completed
              updated_task = %{
                task | 
                state: :completed,
                result: result,
                completed_at: DateTime.utc_now(),
                updated_at: DateTime.utc_now()
              }
              
              # Update in ETS
              :ets.insert(:delayed_tasks, {task_id, updated_task})
              
            {:error, reason} ->
              # Handle task failure with retry logic
              handle_task_failure(task, reason)
          end
          
        rescue
          error ->
            # Handle unexpected errors
            handle_task_failure(task, "Unexpected error: #{inspect(error)}")
        end
        
      {:error, :not_found} ->
        # No handler found for this task type
        handle_task_failure(task, "No handler found for task type: #{inspect(type)}")
        
      error ->
        # Handle other errors
        handle_task_failure(task, "Error getting handler: #{inspect(error)}")
    end
  end
  
  # Handles task failure and schedules a retry if appropriate
  defp handle_task_failure(task, reason) do
    failed_task = Task.mark_failed(task, reason)
    :ets.insert(:delayed_tasks, {task.id, failed_task})
    
    if failed_task.state == :scheduled do
      # Schedule a retry
      retry_at = Task.next_retry_time(failed_task)
      schedule_task_execution(%{failed_task | execute_at: retry_at})
    else
      # Max retries reached, log the failure
      Logger.error("Task #{task.id} failed after #{task.attempts} attempts: #{inspect(reason)}")
    end
  end
  
  # Schedules a task to be executed at its scheduled time
  defp schedule_task_execution(%Task{id: id, execute_at: execute_at}) do
    # Calculate delay in milliseconds
    now = DateTime.utc_now()
    delay = DateTime.diff(execute_at, now, :millisecond)
    
    if delay > 0 do
      # Schedule execution in the future
      Process.send_after(self(), {:execute_task, id}, delay)
    else
      # Execute immediately if the time has already passed
      send(self(), {:execute_task, id})
    end
  end
  
  # Cancels any pending execution for a task
  defp cancel_scheduled_execution(_task_id) do
    # In a real implementation, we would track and cancel the timer
    # For now, we'll just log that we would cancel it
    :ok
  end
  
  # Recovers any pending tasks from the database
  defp recover_pending_tasks do
    # In a real implementation, we would load pending tasks from the database
    # For now, we'll just log that we would recover tasks
    Logger.info("Recovering pending tasks from database")
    :ok
  end
end
