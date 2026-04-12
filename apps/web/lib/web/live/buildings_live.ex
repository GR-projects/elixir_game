defmodule Web.BuildingsLive do
  use Web, :live_view

  alias BusinessLogic.Buildings

  @refresh_interval 5_000

  @impl true
  def mount(_params, session, socket) do
    user = session["user"]
    characters = Data.get_user_characters(user)
    selected_id = get_selected_character_id(session, characters)

    schedule_refresh()

    {:ok,
     assign(socket,
       user: user,
       characters: characters,
       character_id: selected_id,
       character: find_character(characters, selected_id),
       buildings: []
     )}
  end

  defp get_selected_character_id(session, characters) do
    with params_id when is_binary(params_id) <- session["character_id"],
         id <- String.to_integer(params_id),
         true <- Enum.any?(characters, fn c -> c.id == id end) do
      id
    else
      _ -> characters |> List.first() |> then(&(&1 && &1.id))
    end
  end

  defp find_character(characters, id) do
    Enum.find(characters, fn c -> c.id == id end)
  end

  defp schedule_refresh do
    Process.send_after(self(), :check_buildings, @refresh_interval)
  end

  @impl true
  def handle_event("select_character", %{"character_id" => char_id}, socket) do
    character = find_character(socket.assigns.characters, String.to_integer(char_id))

    {:noreply,
     socket
     |> assign(:character_id, String.to_integer(char_id))
     |> assign(:character, character)
     |> assign(:buildings, get_buildings(character))}
  end

  @impl true
  def handle_event("start_building", %{"type" => type_str}, socket) do
    character = socket.assigns.character

    if character do
      type = String.to_atom(type_str)

      case Buildings.start_building(character.id, type) do
        {:ok, result} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             "Building started! Level #{result.level} #{type} will be ready in #{result.build_time} seconds."
           )
           |> assign(:buildings, get_buildings(character))}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed: #{inspect(reason)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "No character found")}
    end
  end

  @impl true
  def handle_info(:check_buildings, socket) do
    schedule_refresh()
    {:noreply, assign(socket, :buildings, get_buildings(socket.assigns.character))}
  end

  @impl true
  def handle_info({:refresh_buildings}, socket) do
    {:noreply, assign(socket, :buildings, get_buildings(socket.assigns.character))}
  end

  defp get_buildings(nil), do: []

  defp get_buildings(character) do
    Buildings.get_character_buildings(character.id)
    |> Enum.map(fn b -> %{type: String.to_atom(b.type), level: b.level} end)
  end
end
