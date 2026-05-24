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

  @default_check_interval 1_000
  @default_batch_size 10
  @table_name :delayed_tasks

  @doc """
  Returns the name of the ETS table used for task storage.
  """
  @spec table_name() :: atom()
  def table_name, do: @table_name

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
    check_interval =
      Keyword.get(
        opts,
        :check_interval,
        Application.get_env(:delayed_tasks, :check_interval_ms, @default_check_interval)
      )

    batch_size =
      Keyword.get(
        opts,
        :batch_size,
        Application.get_env(:delayed_tasks, :batch_size, @default_batch_size)
      )

    table = @table_name

    # Schedule the first check
    timer_ref = Process.send_after(self(), :check_due_tasks, check_interval)

    # Recover any pending tasks from the database
    recover_pending_tasks()

    {:ok,
     %{
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
        task_with_id =
          if validated_task.id do
            validated_task
          else
            id = Task.generate_id()
            %{validated_task | id: id}
          end

        :ets.insert(table, {task_with_id.id, task_with_id})

        persist_task(task_with_id)

        now = DateTime.utc_now()
        time_until_execute = DateTime.diff(task_with_id.execute_at, now, :millisecond)

        if time_until_execute <= state.check_interval do
          delay = max(time_until_execute, 0)

          if state.timer_ref do
            Process.cancel_timer(state.timer_ref)
          end

          timer_ref = Process.send_after(self(), :check_due_tasks, delay)
          {:reply, {:ok, task_with_id}, %{state | timer_ref: timer_ref}}
        else
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
  def handle_info(
        :check_due_tasks,
        %{table: table, batch_size: batch_size, check_interval: check_interval} = state
      ) do
    now = DateTime.utc_now()

    due_tasks =
      :ets.tab2list(table)
      |> Enum.filter(fn {_id, task} ->
        task.state == :scheduled and DateTime.compare(task.execute_at, now) != :gt
      end)
      |> Enum.take(batch_size)

    Enum.each(due_tasks, fn {id, task} ->
      processing_task = Task.mark_processing(task)
      :ets.insert(table, {id, processing_task})

      parent = self()

      spawn(fn ->
        result = execute_task_sync(processing_task)
        send(parent, {:task_result, id, result})
      end)
    end)

    timer_ref = Process.send_after(self(), :check_due_tasks, check_interval)

    {:noreply, %{state | timer_ref: timer_ref}}
  end

  @impl true
  def handle_info({:task_result, task_id, result}, %{table: table} = state) do
    case :ets.lookup(table, task_id) do
      [{^task_id, task}] ->
        case result do
          {:ok, result} ->
            updated_task = %{
              task
              | state: :completed,
                result: result,
                completed_at: DateTime.utc_now()
            }

            :ets.insert(table, {task_id, updated_task})
            update_task_in_db(updated_task)

          {:error, reason} ->
            handle_task_failure(task, reason)

          {:error, reason, retry?} ->
            if retry? do
              handle_task_failure(task, reason)
            else
              updated_task = %{
                task
                | state: :failed,
                  error: reason,
                  completed_at: DateTime.utc_now()
              }

              :ets.insert(table, {task_id, updated_task})
              update_task_in_db(updated_task)
              Logger.error("Task #{task_id} failed: #{inspect(reason)}")
            end
        end

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

  # Executes a task synchronously and returns the result
  defp execute_task_sync(%Task{} = task) do
    case Handler.get_handler(task.type) do
      {:ok, module} ->
        try do
          module.handle_task(task)
        rescue
          error ->
            {:error, "Unexpected error: #{inspect(error)}"}
        end

      {:error, :not_found} ->
        {:error, "No handler found for task type: #{inspect(task.type)}"}

      error ->
        {:error, "Error getting handler: #{inspect(error)}"}
    end
  end

  # Handles task failure and schedules a retry if appropriate
  defp handle_task_failure(task, reason) do
    no_handler_error = "No handler found for task type: #{inspect(task.type)}"

    # Special case: no handler registered for this task type
    # Mark as failed and delete from DB
    if reason == no_handler_error do
      failed_task = %{task | state: :failed, error: reason, completed_at: DateTime.utc_now()}
      :ets.insert(:delayed_tasks, {task.id, failed_task})
      delete_task_from_db(task.id)

      Logger.warning(
        "Task #{task.id} marked as failed - no handler registered for type #{inspect(task.type)}. Removed from DB."
      )
    else
      failed_task = Task.mark_failed(task, reason)
      :ets.insert(:delayed_tasks, {task.id, failed_task})
      update_task_in_db(failed_task)

      if failed_task.state == :scheduled do
        retry_at = Task.next_retry_time(failed_task)
        retry_task = %{failed_task | execute_at: retry_at, state: :scheduled}
        :ets.insert(:delayed_tasks, {retry_task.id, retry_task})
        persist_task(retry_task)
        Logger.info("Task #{task.id} scheduled for retry at #{inspect(retry_at)}")
      else
        Logger.error("Task #{task.id} failed after #{task.attempts} attempts: #{inspect(reason)}")
      end
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
    if Application.get_env(:delayed_tasks, :persistence_enabled, true) do
      if Code.ensure_loaded?(Data.DelayedTasks) do
        Logger.info("Recovering pending tasks from database")
        now = DateTime.utc_now()
        pending_tasks = Data.DelayedTasks.list_due_tasks(now, 100)

        Enum.each(pending_tasks, fn db_task ->
          attrs =
            Map.take(db_task, [
              :id,
              :type,
              :state,
              :params,
              :result,
              :error,
              :scheduled_at,
              :execute_at,
              :completed_at,
              :attempts,
              :max_attempts,
              :priority,
              :metadata
            ])

          attrs = %{attrs | type: String.to_atom(attrs.type), state: String.to_atom(attrs.state)}
          task = Task.new(attrs)
          :ets.insert(:delayed_tasks, {task.id, task})
        end)

        Logger.info("Recovered #{length(pending_tasks)} pending tasks from database")
      else
        Logger.info("Data module not available, skipping DB recovery")
      end
    end

    :ok
  end

  defp persist_task(task) do
    if Application.get_env(:delayed_tasks, :persistence_enabled, true) do
      attrs = %{
        id: task.id,
        type: Atom.to_string(task.type),
        state: Atom.to_string(task.state),
        params: task.params,
        scheduled_at: task.scheduled_at,
        execute_at: task.execute_at,
        attempts: task.attempts,
        max_attempts: task.max_attempts,
        priority: task.priority,
        metadata: task.metadata
      }

      case Data.DelayedTasks.get_task(task.id) do
        {:ok, _} ->
          Data.DelayedTasks.update_task_state(task.id, Atom.to_string(task.state))

        {:error, :not_found} ->
          Data.DelayedTasks.create_task(attrs)
      end
    end
  end

  defp update_task_in_db(task) do
    if Application.get_env(:delayed_tasks, :persistence_enabled, true) do
      if Code.ensure_loaded?(Data.DelayedTasks) do
        Data.DelayedTasks.update_task_state(task.id, Atom.to_string(task.state), task.result)
      end
    end
  end

  defp delete_task_from_db(task_id) do
    if Application.get_env(:delayed_tasks, :persistence_enabled, true) do
      if Code.ensure_loaded?(Data.DelayedTasks) do
        Data.DelayedTasks.delete_task(task_id)
      end
    end
  end
end
