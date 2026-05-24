defmodule BusinessLogic.Buildings.Handler do
  @behaviour DelayedTasks.HandlerBehaviour

  @impl true
  def handle_task(%DelayedTasks.Task{params: %{
        character_id: character_id,
        building_type: building_type,
        action: action,
        level: level
      }}) do
    result =
      case action do
        :create ->
          Data.create_building(%{
            type: Atom.to_string(building_type),
            level: level,
            character_id: character_id
          })

        :upgrade ->
          case Data.get_character_building(character_id, Atom.to_string(building_type)) do
            nil ->
              {:error, :building_not_found}

            building ->
              Data.update_building(building, %{level: level})
          end
      end

    case result do
      {:ok, building} ->
        {:ok,
         %{
           building: %{id: building.id, type: building.type, level: building.level},
           action: action,
           type: building_type,
           level: level
         }}

      {:error, changeset} ->
        {:error, changeset}
    end
  end
end
