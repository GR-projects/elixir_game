defmodule DelayedTasks do
  @moduledoc """
  The main module for the DelayedTasks application.

  This module provides the public API for scheduling, canceling, and querying
  delayed tasks.
  """

  alias DelayedTasks.Task
  alias DelayedTasks.Manager
  alias DelayedTasks.Handler

  @doc """
  Schedules a new task to be executed at a later time.

  ## Parameters
    * `type` - The type of the task (atom)
    * `params` - A map of parameters for the task
    * `opts` - Options for the task
      * `:execute_at` - When the task should be executed (DateTime, required if :execute_in not provided)
      * `:execute_in` - Delay in seconds before execution (alternative to :execute_at)
      * `:max_attempts` - Maximum number of attempts (default: 3)
      * `:priority` - Task priority (default: 0, higher numbers = higher priority)
      * `:metadata` - Additional metadata for the task

  ## Examples
      # Schedule a task to run in 5 minutes using execute_at
      execute_at = DateTime.add(DateTime.utc_now(), 300, :second)
      {:ok, task} = DelayedTasks.schedule(:email_reminder, %{user_id: 1, email: "user@example.com"}, execute_at: execute_at)

      # Schedule a task to run in 5 minutes using execute_in
      {:ok, task} = DelayedTasks.schedule(:email_reminder, %{user_id: 1, email: "user@example.com"}, execute_in: 300)
  """
  @spec schedule(atom(), map(), keyword()) :: {:ok, Task.t()} | {:error, String.t()}
  def schedule(type, params, opts \\ []) do
    execute_at =
      case Keyword.fetch(opts, :execute_at) do
        {:ok, at} ->
          at

        :error ->
          execute_in = Keyword.get(opts, :execute_in)
          if execute_in, do: DateTime.add(DateTime.utc_now(), execute_in, :second), else: nil
      end

    if is_nil(execute_at) do
      {:error, "Either :execute_at or :execute_in must be provided"}
    else
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
    Handler.register_handler(type, handler)
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
    task_counts =
      Enum.into(tasks_by_state, %{}, fn {state, tasks} ->
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
