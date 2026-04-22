defmodule Data do
  alias Data.Item
  alias Data.Repo
  alias Data.User
  alias Data.Character
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

  @spec update_user(User.t(), map()) :: {:ok, User.t()} | {:error, list()}
  def update_user(user, params) do
    changeset = User.changeset(user, params, required: [])

    case Repo.update(changeset) do
      {:ok, updated_user} ->
        ETS.delete(:users, user.login)
        {:ok, updated_user}

      {:error, changeset} ->
        {:error, changeset.errors}
    end
  end

  @spec get_user(String.t()) :: User.t()
  def get_user(login) do
    case ETS.lookup(:users, login) do
      {:ok, user} ->
        user

      {:error, :not_found} ->
        user = Repo.get_by(User, login: login)

        case user do
          nil ->
            nil

          user ->
            ets_user =
              user
              |> Repo.preload(characters: [items: :stats])

            ETS.insert(:users, {login, ets_user})
            user
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

  def get_user_characters(user = %{login: login}) do
    case ETS.lookup(:users, login) do
      {:ok, %{characters: characters}} ->
        characters

      {:error, :not_found} ->
        ets_user = user |> Repo.preload(characters: [items: :stats])
        ETS.insert(:users, {login, ets_user})
        ets_user.characters
    end
  end

  @spec get_user_items(Data.User.t()) :: [map()]
  def get_user_items(_user = %{login: login}) do
    case ETS.lookup(:users, login) do
      {:ok, cached_user} ->
        cached_user
        |> Map.get(:characters, [])
        |> Enum.flat_map(&Map.get(&1, :items, []))

      {:error, :not_found} ->
        case reload_user_cache(login) do
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
            ETS.insert(:users, {user.login, ets_user})
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
                ETS.insert(:users, {user.login, ets_user})
            end

          _ ->
            :ok
        end

        result
    end
  end

  @spec delete_user(integer()) :: {:ok, User.t()} | {:error, list()}
  def delete_user(id) do
    case Repo.get(User, id) do
      nil ->
        {:error, :not_found}

      user ->
        ETS.delete(:users, user.login)
        Repo.delete(user)
    end
  end

  # Reloads the user from DB and updates ETS cache (preloading characters -> items -> stats).
  # Accepts either a user id (integer) or login (binary).
  # Returns {:ok, ets_user} or {:error, :not_found}.
  defp reload_user_cache(identifier) when is_integer(identifier) do
    case Repo.get(User, identifier) do
      nil ->
        {:error, :not_found}

      user ->
        ets_user = Repo.preload(user, characters: [items: :stats])
        ETS.insert(:users, {user.login, ets_user})
        {:ok, ets_user}
    end
  end

  defp reload_user_cache(identifier) when is_binary(identifier) do
    case Repo.get_by(User, login: identifier) do
      nil ->
        {:error, :not_found}

      user ->
        ets_user = Repo.preload(user, characters: [items: :stats])
        ETS.insert(:users, {identifier, ets_user})
        {:ok, ets_user}
    end
  end
end
