defmodule BusinessLogic do
  @moduledoc """
  Documentation for `BusinessLogic`.
  """

  defdelegate user_changeset(params \\ %{}), to: Data.User, as: :changeset

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
end
