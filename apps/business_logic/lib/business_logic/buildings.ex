defmodule BusinessLogic.Buildings do
  @moduledoc """
  Business logic for building management.
  """

  alias BusinessLogic.Buildings.Handler
  alias Data.Building

  @building_types %{
    house: %{
      name: "House",
      description: "Provides housing for your population",
      base_build_time: 60,
      time_per_level: 30,
      base_cost: 100
    },
    armory: %{
      name: "Armory",
      description: "Stores weapons and armor",
      base_build_time: 120,
      time_per_level: 60,
      base_cost: 200
    }
  }

  def building_types, do: @building_types

  def get_building_info(type) when is_atom(type), do: Map.get(@building_types, type)

  def calculate_build_time(type, level) when is_atom(type) and is_integer(level) do
    case Map.get(@building_types, type) do
      nil -> {:error, :unknown_building_type}
      info -> {:ok, info.base_build_time + info.time_per_level * (level - 1)}
    end
  end

  def get_character_buildings(character_id) do
    Data.get_character_buildings(character_id)
  end

  def get_character_building(character_id, type) do
    Data.get_character_building(character_id, type)
  end

  def get_pending_building_tasks(character_id) do
    Data.DelayedTasks.list_pending_building_tasks(character_id)
    |> Enum.map(fn task ->
      type = task.params["building_type"]
      level = task.params["level"]
      state = task.state
      execute_at = DateTime.to_unix(task.execute_at)
      {type, level, state, execute_at}
    end)
    |> Enum.reject(fn p -> p == {} end)
  end

  def start_building(character_id, type) when is_atom(type) do
    case get_building_info(type) do
      nil ->
        {:error, :unknown_building_type}

      _info ->
        existing = get_character_building(character_id, Atom.to_string(type))

        if existing do
          upgrade_building(existing)
        else
          create_building(character_id, type)
        end
    end
  end

  defp create_building(character_id, type) do
    case calculate_build_time(type, 1) do
      {:ok, build_time} ->
        case DelayedTasks.schedule(
               :build_building,
               %{
                 character_id: character_id,
                 building_type: type,
                 action: :create,
                 level: 1
               },
               execute_in: build_time
             ) do
          {:ok, task} ->
            {:ok, %{task_id: task.id, build_time: build_time, action: :create, level: 1}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _} = error ->
        error
    end
  end

  defp upgrade_building(%Building{} = building) do
    type = String.to_atom(building.type)
    new_level = building.level + 1

    case calculate_build_time(type, new_level) do
      {:ok, build_time} ->
        case DelayedTasks.schedule(
               :build_building,
               %{
                 character_id: building.character_id,
                 building_type: type,
                 action: :upgrade,
                 level: new_level,
                 building_id: building.id
               },
               execute_in: build_time
             ) do
          {:ok, task} ->
            {:ok, %{task_id: task.id, build_time: build_time, action: :upgrade, level: new_level}}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _} = error ->
        error
    end
  end

  def register_handler do
    DelayedTasks.register_handler(:build_building, Handler)
  end
end
