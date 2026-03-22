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
            ets_user = user |> Repo.preload(characters: :items)
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
        ets_user = user |> Repo.preload(characters: :items)
        ETS.insert(:users, {login, ets_user})
        ets_user.characters
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
            ets_user = Repo.preload(user, characters: :items)
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
    |> IO.inspect(label: "get char")
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
                ets_user = Repo.preload(user, characters: :items)
                ETS.insert(:users, {user.login, ets_user})
            end

          _ ->
            :ok
        end

        result
    end
  end
end
