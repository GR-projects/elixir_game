defmodule Data.DelayedTask do
  @moduledoc """
  Schema for delayed tasks in the database.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :string, autogenerate: false}
  @timestamps_opts [type: :utc_datetime]

  schema "delayed_tasks" do
    field(:type, :string)
    field(:state, :string, default: "scheduled")
    field(:params, :map, default: %{})
    field(:result, :map)
    field(:error, :string)
    field(:scheduled_at, :utc_datetime)
    field(:execute_at, :utc_datetime)
    field(:completed_at, :utc_datetime)
    field(:attempts, :integer, default: 0)
    field(:max_attempts, :integer, default: 3)
    field(:priority, :integer, default: 0)
    field(:metadata, :map, default: %{})

    timestamps()
  end

  @type t :: %__MODULE__{}

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
end
