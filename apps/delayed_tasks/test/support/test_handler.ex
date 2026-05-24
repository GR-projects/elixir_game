defmodule DelayedTasks.TestHandler do
  @behaviour DelayedTasks.HandlerBehaviour

  @impl true
  def handle_task(params) do
    {:ok, %{processed_at: DateTime.utc_now(), params: params}}
  end
end
