defmodule Utils.Application do
  use Application
  alias Utils.ETS

  def start(_type, _args) do
    children = []
    ETS.init()
    opts = [strategy: :one_for_one, name: Utils.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
