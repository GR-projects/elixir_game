defmodule Data.DelayedTasks do
  @moduledoc """
  Context module for managing delayed tasks in the database.
  """
  
  import Ecto.Query, warn: false
  alias Data.Repo
  alias Data.DelayedTask
  
  @doc """
  Gets a single delayed task by ID.
  """
  @spec get_task(String.t()) :: {:ok, DelayedTask.t()} | {:error, :not_found}
  def get_task(id) do
    case Repo.get(DelayedTask, id) do
      nil -> {:error, :not_found}
      task -> {:ok, task}
    end
  end
  
  @doc """
  Inserts a new delayed task.
  """
  @spec create_task(map()) :: {:ok, DelayedTask.t()} | {:error, Ecto.Changeset.t()}
  def create_task(attrs) do
    %DelayedTask{}
    |> DelayedTask.changeset(attrs)
    |> Repo.insert()
  end
  
  @doc """
  Updates a delayed task.
  """
  @spec update_task(DelayedTask.t(), map()) :: {:ok, DelayedTask.t()} | {:error, Ecto.Changeset.t()}
  def update_task(%DelayedTask{} = task, attrs) do
    task
    |> DelayedTask.changeset(attrs)
    |> Repo.update()
  end
  
  @doc """
  Deletes a delayed task.
  """
  @spec delete_task(DelayedTask.t()) :: {:ok, DelayedTask.t()} | {:error, Ecto.Changeset.t()}
  def delete_task(%DelayedTask{} = task) do
    Repo.delete(task)
  end
  
  @doc """
  Lists all tasks that are scheduled to be executed before the given time.
  """
  @spec list_due_tasks(DateTime.t(), integer()) :: [DelayedTask.t()]
  def list_due_tasks(now, limit \\ 100) do
    DelayedTask
    |> where([t], t.state == "scheduled" and t.execute_at <= ^now)
    |> order_by([t], asc: t.priority, asc: t.execute_at)
    |> limit(^limit)
    |> Repo.all()
  end
  
  @doc """
  Lists all tasks with the given state.
  """
  @spec list_tasks_by_state(String.t(), integer() | nil) :: [DelayedTask.t()]
  def list_tasks_by_state(state, limit \\ nil) do
    query = 
      from t in DelayedTask,
      where: t.state == ^state,
      order_by: [asc: t.execute_at]
      
    query = if limit, do: limit(query, ^limit), else: query
    
    Repo.all(query)
  end
  
  @doc """
  Updates the state of a task.
  """
  @spec update_task_state(String.t(), String.t(), map() | nil) :: {:ok, DelayedTask.t()} | {:error, any()}
  def update_task_state(task_id, state, result \\ nil) do
    attrs = %{
      state: state,
      completed_at: if(state in ["completed", "failed"], do: DateTime.utc_now(), else: nil),
      result: if(result, do: result, else: nil)
    }
    
    with {:ok, task} <- get_task(task_id) do
      update_task(task, attrs)
    end
  end
  
  @doc """
  Increments the attempt counter for a task.
  """
  @spec increment_attempts(String.t()) :: {:ok, DelayedTask.t()} | {:error, any()}
  def increment_attempts(task_id) do
    with {:ok, task} <- get_task(task_id) do
      update_task(task, %{attempts: (task.attempts || 0) + 1})
    end
  end
  
  @doc """
  Locks a task for processing to prevent duplicate processing.
  """
  @spec lock_for_processing(String.t()) :: {:ok, DelayedTask.t()} | {:error, :already_processing | :not_found}
  def lock_for_processing(task_id) do
    Repo.transaction(fn ->
      case Repo.one(
        from t in DelayedTask,
        where: t.id == ^task_id and t.state == "scheduled",
        lock: "FOR UPDATE SKIP LOCKED"
      ) do
        nil ->
          Repo.rollback(:not_found)
          
        task ->
          case update_task(task, %{state: "processing"}) do
            {:ok, updated_task} -> updated_task
            {:error, _} -> Repo.rollback(:update_failed)
          end
      end
    end)
  end
end
