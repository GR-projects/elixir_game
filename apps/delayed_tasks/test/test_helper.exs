ExUnit.start()
Application.ensure_all_started(:delayed_tasks)

Application.put_env(:delayed_tasks, :handlers, [])
Application.put_env(:delayed_tasks, :persistence_enabled, false)

case DelayedTasks.Handler.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end

case DelayedTasks.Manager.start_link() do
  {:ok, _} -> :ok
  {:error, {:already_started, _}} -> :ok
end
