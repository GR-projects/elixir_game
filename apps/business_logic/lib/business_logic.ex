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
  def get_user_items(user) do
  end

  def create_character(_user = %{id: user_id}, %{"type" => _type, "name" => _name} = params) do
    params
    |> Map.put("level", 1)
    |> Map.put("experience", 0)
    |> Map.put("user_id", user_id)
    |> Data.create_character()
  end

  def get_character(id) do
    Data.get_character(id)
  end

  def delete_character(id) do
    Data.delete_character(id)
  end
end
