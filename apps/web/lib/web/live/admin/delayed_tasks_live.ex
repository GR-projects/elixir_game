defmodule Web.Admin.DelayedTasksLive do
  use Web, :live_view

  alias Data.DelayedTasks

  @refresh_interval 10_000

  @impl true
  def mount(_params, session, socket) do
    user_id = session["user_id"]
    user = Data.get_user_by_id(user_id)

    if user do
      schedule_refresh()

      {:ok,
       assign(socket,
         user: user,
         tasks: list_recent_tasks(),
         refresh_interval: @refresh_interval
       )}
    else
      {:ok, put_flash(socket, :error, "Access denied.")}
    end
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh_tasks, @refresh_interval)
  end

  @impl true
  def handle_event("delete_task", %{"id" => task_id}, socket) do
    case DelayedTasks.delete_task(task_id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Task deleted")
         |> assign(:tasks, list_recent_tasks())}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info(:refresh_tasks, socket) do
    schedule_refresh()
    {:noreply, assign(socket, :tasks, list_recent_tasks())}
  end

  defp list_recent_tasks do
    DelayedTasks.list_recent_tasks(50)
    |> Enum.map(fn task ->
      %{
        id: task.id,
        type: task.type,
        state: task.state,
        params: task.params,
        result: task.result,
        error: task.error,
        scheduled_at: format_datetime(task.scheduled_at),
        execute_at: format_datetime(task.execute_at),
        completed_at: format_datetime(task.completed_at),
        attempts: task.attempts,
        metadata: task.metadata
      }
    end)
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(dt) do
    dt
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  defp state_class("scheduled"), do: "px-2 py-1 rounded text-xs bg-yellow-900/30 text-yellow-400"
  defp state_class("processing"), do: "px-2 py-1 rounded text-xs bg-blue-900/30 text-blue-400"
  defp state_class("completed"), do: "px-2 py-1 rounded text-xs bg-green-900/30 text-green-400"
  defp state_class("failed"), do: "px-2 py-1 rounded text-xs bg-crimson-900/30 text-crimson-400"
  defp state_class(_), do: "px-2 py-1 rounded text-xs bg-dark-600/30 text-gray-400"
end
