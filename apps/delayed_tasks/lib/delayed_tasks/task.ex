defmodule DelayedTasks.Task do
  @moduledoc """
  Defines the Task struct and related types for the delayed task system.
  """

  @typedoc """
  Task state can be one of:
  - `:scheduled` - Task is scheduled for future execution
  - `:processing` - Task is currently being processed
  - `:completed` - Task completed successfully
  - `:failed` - Task failed after all retries
  - `:cancelled` - Task was cancelled
  """
  @type state :: :scheduled | :processing | :completed | :failed | :cancelled

  @typedoc """
  Task priority (lower numbers = higher priority)
  """
  @type priority :: integer()

  @typedoc """
  Task result (can be any term, but must be serializable)
  """
  @type result :: any()

  @typedoc """
  Task error information
  """
  @type error :: String.t() | map() | atom() | {atom(), String.t()}

  @typedoc """
  Task metadata (can be any map)
  """
  @type metadata :: map()

  @typedoc """
  Task parameters (can be any map)
  """
  @type params :: map()

  @typedoc """
  The Task struct that represents a delayed task.
  """
  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          state: state(),
          params: params(),
          result: result() | nil,
          error: error() | nil,
          scheduled_at: DateTime.t(),
          execute_at: DateTime.t(),
          completed_at: DateTime.t() | nil,
          attempts: non_neg_integer(),
          max_attempts: pos_integer(),
          priority: priority(),
          metadata: metadata()
        }

  defstruct [
    :id,
    :type,
    :params,
    :result,
    :error,
    :scheduled_at,
    :execute_at,
    :completed_at,
    state: :scheduled,
    attempts: 0,
    max_attempts: 3,
    priority: 0,
    metadata: %{}
  ]

  @doc """
  Creates a new Task struct with the given attributes.

  ## Parameters
    * `attrs` - A map or keyword list of attributes
    
  ## Examples
      iex> task = DelayedTasks.Task.new(type: :email, params: %{to: "user@example.com"}, execute_at: ~U[2023-01-01T00:00:00Z])
      iex> task.type
      :email
      iex> task.state
      :scheduled
  """
  @spec new(keyword() | map()) :: t()
  def new(attrs) when is_list(attrs) or is_map(attrs) do
    attrs = Map.new(attrs)

    id = attrs[:id] || generate_id()
    scheduled_at = attrs[:scheduled_at] || DateTime.utc_now()

    struct!(__MODULE__,
      id: id,
      type: attrs[:type],
      params: attrs[:params] || %{},
      scheduled_at: scheduled_at,
      execute_at: attrs[:execute_at] || scheduled_at,
      max_attempts: attrs[:max_attempts] || 3,
      priority: attrs[:priority] || 0,
      metadata: attrs[:metadata] || %{}
    )
  end

  @doc """
  Generates a unique ID for a task.
  """
  @spec generate_id() :: String.t()
  def generate_id do
    ("task_" <>
       :crypto.strong_rand_bytes(16))
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 16)
  end

  @doc """
  Marks a task as processing and increments the attempt counter.
  """
  @spec mark_processing(t()) :: t()
  def mark_processing(%__MODULE__{} = task) do
    %{task | state: :processing, attempts: task.attempts + 1}
  end

  @doc """
  Marks a task as completed with the given result.
  """
  @spec mark_completed(t(), any()) :: t()
  def mark_completed(%__MODULE__{} = task, result) do
    %{task | state: :completed, result: result, completed_at: DateTime.utc_now()}
  end

  @doc """
  Marks a task as failed with the given error.
  """
  @spec mark_failed(t(), error()) :: t()
  def mark_failed(%__MODULE__{} = task, error) do
    %{
      task
      | state: if(task.attempts >= task.max_attempts, do: :failed, else: :scheduled),
        error: error,
        completed_at: if(task.attempts >= task.max_attempts, do: DateTime.utc_now(), else: nil)
    }
  end

  @doc """
  Calculates the next execution time for a failed task using exponential backoff with jitter.
  """
  @spec next_retry_time(t()) :: DateTime.t()
  def next_retry_time(%__MODULE__{attempts: attempts, max_attempts: max_attempts})
      when attempts >= max_attempts do
    raise "No more retries available"
  end

  def next_retry_time(%__MODULE__{attempts: attempts} = _task) do
    # Exponential backoff with jitter: 2^attempts * (0.8 + 0.4 * random())
    # Start with 5s, then 10s, 20s, 40s, etc.
    base_delay = :math.pow(2, attempts) * 5
    jitter = 0.8 + 0.4 * :rand.uniform()
    delay_seconds = round(base_delay * jitter)

    # Add some randomness to spread out retries
    # -2 to +2 seconds
    jitter = :rand.uniform(5) - 3

    DateTime.add(DateTime.utc_now(), delay_seconds + jitter, :second)
  end
end
