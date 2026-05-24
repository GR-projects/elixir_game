defmodule Data do
  alias Data.Item
  alias Data.Repo
  alias Data.User
  alias Data.Character
  alias Data.Building
  alias Utils.ETS

  import Ecto.Query

  @spec create_user(map()) :: {:ok, User.t()} | {:error, list()}
  def create_user(params) do
    changeset = User.changeset(%User{}, params)

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  @spec get_user(String.t()) :: User.t()
  def get_user(login) do
    case Repo.get_by(User, login: login) do
      nil ->
        nil

      user ->
        ets_user =
          user
          |> Repo.preload(characters: [items: :stats])

        ETS.insert(:users, {ets_user.id, ets_user})
        ets_user
    end
  end

  @spec get_user_by_id(integer()) :: User.t() | nil
  def get_user_by_id(user_id) do
    case ETS.lookup(:users, user_id) do
      {:ok, user} ->
        user

      {:error, :not_found} ->
        user = Repo.get(User, user_id)

        case user do
          nil ->
            nil

          user ->
            ets_user = Repo.preload(user, characters: [items: :stats])
            ETS.insert(:users, {user_id, ets_user})
            ets_user
        end
    end
  end

  @spec get_character_items(Character.t()) :: [map()]
  def get_character_items(character) do
    (i in Item)
    |> from(as: :item)
    |> preload(:stats)
    |> where([item: i], i.character_id == ^character.id)
    |> Repo.all()
  end

  def has_characters?(_user = %{id: id}) do
    Character.base_query()
    |> where([{^Character.binding_name(), c}], c.user_id == ^id)
    |> select([{^Character.binding_name(), c}], count(c.id))
    |> Repo.one()
    |> case do
      0 -> false
      _ -> true
    end
  end

@spec get_user_characters(User.t()) :: [Character.t()]
  def get_user_characters(%{id: user_id}) do
    case ETS.lookup(:users, user_id) do
      {:ok, cached_user} ->
        cached_user.characters

      {:error, :not_found} ->
        case reload_user_cache(user_id) do
          {:ok, ets_user} ->
            ets_user.characters

          _ ->
            []
        end
    end
  end

  @spec get_user_items(Data.User.t()) :: [map()]
  def get_user_items(_user = %{id: user_id}) do
    case ETS.lookup(:users, user_id) do
      {:ok, cached_user} ->
        cached_user
        |> Map.get(:characters, [])
        |> Enum.flat_map(&Map.get(&1, :items, []))

      {:error, :not_found} ->
        case reload_user_cache(user_id) do
          {:ok, ets_user} ->
            ets_user
            |> Map.get(:characters, [])
            |> Enum.flat_map(&Map.get(&1, :items, []))

          _ ->
            []
        end
    end
  end

  @spec create_character(map()) :: {:ok, Character.t()} | {:error, list()}
  def create_character(params) do
    changeset = Data.Character.changeset(%Data.Character{}, params)

    case Repo.insert(changeset) do
      {:ok, character} ->
        # Reload the owning user and replace the cache entry so it's authoritative
        case Repo.get(User, character.user_id) do
          nil ->
            :ok

          user ->
            ets_user = Repo.preload(user, characters: [items: :stats])
            ETS.insert(:users, {user.id, ets_user})
        end

        {:ok, character}

      {:error, changeset} ->
        {:error, changeset.errors}
    end
  end

  @spec get_character(integer()) :: {:ok, Character.t()} | {:error, list()}
  def get_character(id) do
    Character.base_query()
    |> where([{^Character.binding_name(), c}], c.id == ^id)
    |> Repo.one()
    |> case do
      nil -> {:error, nil}
      character -> {:ok, character}
    end
  end

  @spec delete_character(integer()) :: {:ok, Character.t()} | {:error, list()}
  def delete_character(id) do
    case get_character(id) do
      {:error, _} = error ->
        error

      {:ok, character} = result ->
        # attempt DB delete and, on success, update ETS cache for the owning user
        case Repo.delete(character) do
          {:ok, _deleted} ->
            # Reload the owning user and replace the cache entry so it's authoritative
            case Repo.get(User, character.user_id) do
              nil ->
                :ok

              user ->
                ets_user = Repo.preload(user, characters: [items: :stats])
                ETS.insert(:users, {user.id, ets_user})
            end

          _ ->
            :ok
        end

        result
    end
  end

  # Reload the user from DB and update ETS cache (preloading characters -> items -> stats).
  # Returns {:ok, ets_user} or {:error, :not_found}.
  defp reload_user_cache(user_id) when is_integer(user_id) do
    case Repo.get(User, user_id) do
      nil ->
        {:error, :not_found}

      user ->
        ets_user = Repo.preload(user, characters: [items: :stats])
        ETS.insert(:users, {user.id, ets_user})
        {:ok, ets_user}
    end
  end

  def get_character_buildings(character_id) do
    Building
    |> where([b], b.character_id == ^character_id)
    |> Repo.all()
  end

  def get_character_building(character_id, type) do
    Building
    |> where([b], b.character_id == ^character_id and b.type == ^type)
    |> Repo.one()
  end

  @spec create_building(map()) :: {:ok, Building.t()} | {:error, Ecto.Changeset.t()}
  def create_building(attrs) do
    %Building{}
    |> Building.changeset(attrs)
    |> Repo.insert()
  end

  def update_building(%Building{} = building, attrs) do
    building
    |> Building.changeset(attrs)
    |> Repo.update()
  end

  def delete_building(%Building{} = building) do
    Repo.delete(building)
  end
end
