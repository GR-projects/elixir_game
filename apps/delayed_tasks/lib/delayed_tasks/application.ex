defmodule DelayedTasks.Application do
  @moduledoc """
  This is the main Application module for the DelayedTasks OTP application.
  
  It defines the application's supervision tree and starts all the necessary
  processes when the application starts.
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    children = [
      # Task supervisor for executing tasks in separate processes
      {Task.Supervisor, name: DelayedTasks.TaskSupervisor},
      # The main manager process
      {DelayedTasks.Manager, name: DelayedTasks.Manager}
    ]

    opts = [strategy: :one_for_one, name: DelayedTasks.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  @doc """
  Starts the DelayedTasks application.
  
  This function is called when the application is started using
  `Application.start/2` or when included in a supervision tree.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  @doc """
  Returns a child specification for the application.
  
  This is required for proper supervision tree construction.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end
end
