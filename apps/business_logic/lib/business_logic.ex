defmodule BusinessLogic do
  @moduledoc """
  Documentation for `BusinessLogic`.
  """

  defdelegate user_changeset(params \\ %{}), to: Data.User, as: :changeset
  defdelegate character_changeset(params \\ %{}), to: Data.Character, as: :changeset

  def create_user(%{"password" => password} = params) do
    hashed_password = Bcrypt.hash_pwd_salt(password)

    params
    |> Map.put("password_hash", hashed_password)
    |> Data.create_user()
    |> case do
      {:ok, user} ->
        # Cache the user in ETS after successful insertion (preloaded)
        ets_user = Data.Repo.preload(user, characters: :items)
        Utils.ETS.insert(:users, {user.login, ets_user})
        {:ok, ets_user}
      error -> error
    end
  end

  def authenticate_user(%{"password" => pass, "login" => login}) do
    with user when not is_nil(user) <- Data.get_user(login),
         true <- Bcrypt.verify_pass(pass, user.password_hash) do
      {:ok, user}
    else
      nil -> {:error, :user_not_exists}
      false -> {:error, :authentication_failed}
    end
  end

  @spec get_user_items(Data.User.t()) :: [map()]
  def get_user_items(user = %{login: login}) do
    case Utils.ETS.lookup(:users, login) do
      {:ok, cached_user} ->
        cached_user
        |> Map.get(:characters) || []
        |> Enum.flat_map(&Map.get(&1, :items, []))
      {:error, :not_found} ->
        db_user = Data.Repo.get_by(Data.User, login: login)
        case db_user do
          nil ->
            []
          _ ->
            ets_user = db_user |> Data.Repo.preload(characters: :items)
            Utils.ETS.insert(:users, {login, ets_user})
            ets_user
            |> Map.get(:characters, [])
            |> Enum.flat_map(&Map.get(&1, :items, []))
        end
    end
  end

  def create_character(_user = %{id: user_id, login: login} = user, %{"type" => _type, "name" => _name} = params) do
    params
    |> Map.put("level", 1)
    |> Map.put("experience", 0)
    |> Map.put("user_id", user_id)
    |> Data.create_character()
    |> case do
      {:ok, character} ->
        # Update the cached user to include the new character
        preloaded_character = Data.Repo.preload(character, :items)
        case Utils.ETS.lookup(:users, login) do
          {:ok, cached_user} ->
            updated_characters = [preloaded_character | (cached_user.characters || [])]
            updated_user = %{cached_user | characters: updated_characters}
            Utils.ETS.insert(:users, {login, updated_user})
          {:error, :not_found} ->
            # If user not in cache, preload and cache with new character
            ets_user = user |> Data.Repo.preload(characters: :items)
            Utils.ETS.insert(:users, {login, ets_user})
        end
        {:ok, preloaded_character}
      error -> error
    end
  end

  def get_character(id) do
    Data.get_character(id)
  end

  def delete_character(id) do
    Data.delete_character(id)
  end
end
