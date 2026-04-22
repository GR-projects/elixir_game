defmodule BusinessLogic do
  @moduledoc """
  Documentation for `BusinessLogic`.
  """

  alias Utils.ETS

  defdelegate user_changeset(params \\ %{}), to: Data.User, as: :changeset
  defdelegate character_changeset(params \\ %{}), to: Data.Character, as: :changeset

  def create_user(%{"password" => password} = params) do
    hashed_password = Bcrypt.hash_pwd_salt(password)

    params
    |> Map.put("password_hash", hashed_password)
    |> Data.create_user()
    |> case do
      {:ok, user} ->
        Utils.ETS.insert(:users, {user.id, user})
        {:ok, user}

      error ->
        error
    end
  end

  def confirm_user(login) when is_binary(login) do
    user = Data.get_user(login)

    case user do
      nil ->
        {:error, :not_found}

      %{confirmed_at: %DateTime{}} ->
        {:error, :already_confirmed}

      user ->
        Data.update_user(user, %{"confirmed_at" => DateTime.utc_now()})
        |> case do
          {:ok, updated_user} ->
            :ok = ETS.insert(:users, {updated_user.id, updated_user})
            {:ok, :confirmed}

          error ->
            error
        end
    end
  end

  def resend_confirmation(login) when is_binary(login) do
    user = Data.get_user(login)

    case user do
      nil ->
        {:error, :not_found}

      %{confirmed_at: %DateTime{}} ->
        {:error, :already_confirmed}

      user ->
        {:ok, user}
    end
  end

  def authenticate_user(%{"password" => pass, "login" => login}) do
    with user when not is_nil(user) <- Data.get_user(login),
         true <- Bcrypt.verify_pass(pass, user.password_hash),
         false <- is_nil(user.confirmed_at) do
      :ok = ETS.insert(:users, {user.id, user})
      {:ok, user}
    else
      nil -> {:error, :user_not_exists}
      false -> {:error, :authentication_failed}
      true -> {:error, :not_confirmed}
    end
  end

  def create_character(_user = %{id: user_id}, %{"type" => _type, "name" => _name} = params) do
    params
    |> Map.put("level", 1)
    |> Map.put("experience", 0)
    |> Map.put("user_id", user_id)
    |> Data.create_character()
  end

  def get_character(id) when is_integer(id) do
    Data.get_character(id)
  end

  def get_character(id) when is_binary(id) do
    # convert string id to integer for downstream Data.get_character/1
    Data.get_character(String.to_integer(id))
  end

  def delete_character(id) do
    Data.delete_character(id)
  end
end
