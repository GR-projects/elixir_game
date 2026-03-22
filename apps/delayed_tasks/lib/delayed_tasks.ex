defmodule DelayedTasks do
  @moduledoc """
  The main module for the DelayedTasks application.
  
  This module provides the public API for scheduling, canceling, and querying
  delayed tasks.
  """
  
  alias DelayedTasks.Task
  alias DelayedTasks.Manager
  
  @doc """
  Schedules a new task to be executed at a later time.
  
  ## Parameters
    * `type` - The type of the task (atom)
    * `params` - A map of parameters for the task
    * `opts` - Options for the task
      * `:execute_at` - When the task should be executed (required)
      * `:max_attempts` - Maximum number of attempts (default: 3)
      * `:priority` - Task priority (default: 0, higher numbers = higher priority)
      * `:metadata` - Additional metadata for the task
  
  ## Examples
      # Schedule a task to run in 5 minutes
      execute_at = DateTime.add(DateTime.utc_now(), 300, :second)
      {:ok, task} = DelayedTasks.schedule(:email_reminder, %{user_id: 1, email: "user@example.com"}, execute_at: execute_at)
  """
  @spec schedule(atom(), map(), keyword()) :: {:ok, Task.t()} | {:error, String.t()}
  def schedule(type, params, opts \\ []) do
    execute_at = Keyword.fetch!(opts, :execute_at)
    max_attempts = Keyword.get(opts, :max_attempts, 3)
    priority = Keyword.get(opts, :priority, 0)
    metadata = Keyword.get(opts, :metadata, %{})
    
    task = %Task{
      type: type,
      params: params,
      scheduled_at: DateTime.utc_now(),
      execute_at: execute_at,
      max_attempts: max_attempts,
      priority: priority,
      metadata: metadata
    }
    
    GenServer.call(Manager, {:schedule, task})
  end
  
  @doc """
  Cancels a scheduled task.
  
  ## Parameters
    * `task_id` - The ID of the task to cancel
  
  ## Examples
      :ok = DelayedTasks.cancel("task_123")
  """
  @spec cancel(String.t()) :: :ok | {:error, String.t()}
  def cancel(task_id) do
    GenServer.call(Manager, {:cancel, task_id})
  end
  
  @doc """
  Gets the status of a task.
  
  ## Parameters
    * `task_id` - The ID of the task to check
  
  ## Examples
      {:ok, task} = DelayedTasks.status("task_123")
      {:error, :not_found} = DelayedTasks.status("nonexistent_id")
  """
  @spec status(String.t()) :: {:ok, Task.t()} | {:error, :not_found}
  def status(task_id) do
    case :ets.lookup(:delayed_tasks, task_id) do
      [{^task_id, task}] -> {:ok, task}
      [] -> {:error, :not_found}
    end
  end
  
  @doc """
  Lists all tasks with the given state.
  """
  @spec list_tasks_by_state(atom()) :: [Task.t()]
  def list_tasks_by_state(state) when is_atom(state) do
    :ets.tab2list(Manager.table_name())
    |> Enum.filter(fn {_id, task} -> task.state == state end)
    |> Enum.map(fn {_id, task} -> task end)
  end
  
  @doc """
  Registers a handler module for a specific task type.
  
  ## Parameters
    * `type` - The task type (atom)
    * `handler` - The module that handles the task (must implement DelayedTasks.Handler)
  
  ## Examples
      defmodule MyApp.EmailHandler do
        @behaviour DelayedTasks.Handler
        
        @impl true
        def handle_task(%DelayedTasks.Task{type: :email_reminder, params: params}) do
          # Send email logic here
          {:ok, %{sent_at: DateTime.utc_now()}}
        end
      end
      
      # Register the handler
      DelayedTasks.register_handler(:email_reminder, MyApp.EmailHandler)
  """
  @spec register_handler(atom(), module()) :: :ok | {:error, String.t()}
  def register_handler(type, handler) do
    case Code.ensure_compiled(handler) do
      {:module, _} ->
        if function_exported?(handler, :handle_task, 1) do
          Registry.register(DelayedTasks.HandlerRegistry, type, handler)
          :ok
        else
          {:error, "Handler module must implement handle_task/1"}
        end
      
      {:error, reason} ->
        {:error, "Failed to compile handler module: #{inspect(reason)}"}
    end
  end
  
  @doc """
  Gets statistics about tasks.
  
  ## Examples
  """
  @spec stats() :: map()
  def stats do
    # Get all tasks
    all_tasks = :ets.tab2list(Manager.table_name())
    
    # Group tasks by state
    tasks_by_state = Enum.group_by(all_tasks, fn {_id, task} -> task.state end)
    
    # Count tasks by state
    task_counts = Enum.into(tasks_by_state, %{}, fn {state, tasks} ->
      {state, length(tasks)}
    end)
    
    # Calculate totals
    total = length(all_tasks)
    
    # Return stats
    %{
      total: total,
      by_state: task_counts
    }
  end
end
