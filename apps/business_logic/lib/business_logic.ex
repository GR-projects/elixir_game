defmodule BusinessLogic do
  @moduledoc """
  The main BusinessLogic module.

  This module provides the public API for the BusinessLogic application.
  """

  @doc """
  Returns an empty changeset for the user schema.
  Used for rendering empty forms.
  """
  def user_changeset do
    Data.User.changeset(%Data.User{}, %{})
  end

  @doc """
  Returns an empty changeset for the character schema.
  Used for rendering empty forms.
  """
  def character_changeset do
    Data.Character.changeset(%Data.Character{}, %{})
  end

  @doc """
  Gets a character by ID.
  """
  @spec get_character(integer() | String.t()) :: map() | nil
  def get_character(id) when is_integer(id) do
    Data.get_character(id)
  end

  def get_character(id) when is_binary(id) do
    Data.get_character(String.to_integer(id))
  end

  @doc """
  Deletes a character by ID.
  """
  @spec delete_character(integer(), map() | nil) ::
          {:ok, Data.Character.t()} | {:error, String.t()}
  def delete_character(id, user \\ nil) do
    result = Data.delete_character(id)

    if user do
      case result do
        {:ok, character} ->
          case Utils.ETS.lookup(:users, user.id) do
            {:ok, cached_user} ->
              updated_user =
                Map.update!(cached_user, :characters, fn chars ->
                  Enum.reject(chars, &(&1.id == character.id))
                end)

              Utils.ETS.insert(:users, {user.id, updated_user})

            {:error, :not_found} ->
              :ok
          end

        {:error, _} ->
          :ok
      end
    end

    result
  end

  def create_user(%{"password" => password} = params) do
    hashed_password = Bcrypt.hash_pwd_salt(password)

    params
    |> Map.put("password_hash", hashed_password)
    |> Data.create_user()
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
  def get_user_items(user = %{id: user_id}) do
    case Utils.ETS.lookup(:users, user_id) do
      {:ok, cached_user} ->
        characters = Map.get(cached_user, :characters, [])

        characters_with_items =
          Enum.map(characters, fn char ->
            case char.items do
              %Ecto.Association.NotLoaded{} ->
                Data.Repo.preload(char, :items)

              _items ->
                char
            end
          end)

        Enum.flat_map(characters_with_items, &Map.get(&1, :items, []))

      {:error, :not_found} ->
        ets_user = user |> Data.Repo.preload(characters: :items)
        Utils.ETS.insert(:users, {user.id, ets_user})

        ets_user
        |> Map.get(:characters, [])
        |> Enum.flat_map(&Map.get(&1, :items, []))
    end
  end

  def create_character(
        %{id: user_id},
        %{"type" => _type, "name" => _name} = params
      ) do
    result =
      params
      |> Map.put("level", 1)
      |> Map.put("experience", 0)
      |> Map.put("user_id", user_id)
      |> Data.create_character()

    result
  end
end
