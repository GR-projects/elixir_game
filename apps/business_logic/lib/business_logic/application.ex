defmodule BusinessLogic.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = []

    opts = [strategy: :one_for_one, name: BusinessLogic.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def start_phase(:register_handlers, :normal, _phase_args) do
    BusinessLogic.Buildings.register_handler()
    :ok
  end
end
