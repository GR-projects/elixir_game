defmodule BusinessLogic do
  @moduledoc """
  The main BusinessLogic module.
  
  This module provides the public API for the BusinessLogic application.
  """
  
  # Add your business logic functions here
  
  @doc """
  Example function that demonstrates business logic.
  """
  @spec example_function(String.t()) :: String.t()
  def example_function(name) do
    "Hello, #{name}!"
  end
  
  # Add other business logic functions here
  
  # Data access functions
  
  @doc """
  Gets a character by ID.
  """
  @spec get_character(integer()) :: map() | nil
  def get_character(id) do
    Data.get_character(id)
  end
  
  @doc """
  Deletes a character by ID.
  """
  @spec delete_character(integer()) :: :ok | {:error, String.t()}
  def delete_character(id) do
    Data.delete_character(id)
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
