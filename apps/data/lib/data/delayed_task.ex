defmodule Data.DelayedTask do
  @moduledoc """
  Schema for delayed tasks in the database.
  """
  
  use Ecto.Schema
  import Ecto.Changeset
  
  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]
  
  schema "delayed_tasks" do
    field :type, :string
    field :state, :string, default: "scheduled"
    field :params, :map, default: %{}
    field :result, :map
    field :error, :string
    field :scheduled_at, :utc_datetime
    field :execute_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :attempts, :integer, default: 0
    field :max_attempts, :integer, default: 3
    field :priority, :integer, default: 0
    field :metadata, :map, default: %{}
    
    timestamps()
  end
  
  @doc """
  Creates a changeset for a delayed task.
  """
  @spec changeset(t() | map(), map()) :: Ecto.Changeset.t()
  def changeset(task, attrs) do
    task
    |> cast(attrs, [
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
    |> validate_required([:id, :type, :execute_at, :params])
    |> validate_inclusion(:state, ["scheduled", "processing", "completed", "failed"])
  end
  
  @doc """
  Converts a BusinessLogic.DelayedTask.Task to a Data.DelayedTask changeset.
  """
  @spec from_task(BusinessLogic.DelayedTask.Task.t()) :: Ecto.Changeset.t()
  def from_task(%BusinessLogic.DelayedTask.Task{} = task) do
    attrs = %{
      id: task.id,
      type: Atom.to_string(task.type),
      state: Atom.to_string(task.state),
      params: task.params,
      result: task.result,
      error: task.error,
      scheduled_at: task.scheduled_at,
      execute_at: task.execute_at,
      completed_at: task.completed_at,
      attempts: task.attempts,
      max_attempts: task.max_attempts,
      priority: task.priority,
      metadata: task.metadata
    }
    
    %__MODULE__{} 
    |> changeset(attrs)
  end
  
  @doc """
  Converts a Data.DelayedTask to a BusinessLogic.DelayedTask.Task.
  """
  @spec to_task(t()) :: BusinessLogic.DelayedTask.Task.t()
  def to_task(%__MODULE__{} = task) do
    %BusinessLogic.DelayedTask.Task{
      id: task.id,
      type: String.to_existing_atom(task.type),
      state: String.to_existing_atom(task.state),
      params: task.params || %{},
      result: task.result,
      error: task.error,
      scheduled_at: task.scheduled_at,
      execute_at: task.execute_at,
      completed_at: task.completed_at,
      attempts: task.attempts || 0,
      max_attempts: task.max_attempts || 3,
      priority: task.priority || 0,
      metadata: task.metadata || %{}
    }
  end
end
