defmodule BusinessLogic.Application do
  @moduledoc """
  This is the main Application module for the BusinessLogic OTP application.
  
  It defines the application's supervision tree and starts all the necessary
  processes when the application starts.
  """
  
  use Application
  
  @impl true
  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Add your application's workers and supervisors here
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: BusinessLogic.Supervisor]
    Supervisor.start_link(children, opts)
  end
  
  @doc """
  Starts the BusinessLogic application.
  
  This function is called when the application is started using
  `Application.start/2` or when included in a supervision tree.
  """
  @spec start_link(keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end
end
