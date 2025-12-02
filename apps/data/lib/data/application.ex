defmodule Data.Application do
  @moduledoc """
  Application module for the Data application.
  """
  use Application

  def start(_type, _args) do
    children = [
      # Start the Repo
      Data.Repo
    ]

    opts = [strategy: :one_for_one, name: Data.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
