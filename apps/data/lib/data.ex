defmodule Data do
  alias Data.Repo
  alias Data.Character
  import Ecto.Query

  @spec create_user(map()) :: {:ok, User.t()} | {:error, list()}
  def create_user(params) do
    changeset = Data.User.changeset(%Data.User{}, params)

    case Repo.insert(changeset) do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  def get_user(login) do
    Repo.get_by(Data.User, login: login)
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

  def get_user_characters(_user = %{id: id}) do
    Character.base_query()
    |> where([{^Character.binding_name(), c}], c.user_id == ^id)
    |> Repo.all()
  end

  @spec create_character(map()) :: {:ok, Character.t()} | {:error, list()}
  def create_character(params) do
    changeset = Data.Character.changeset(%Data.Character{}, params)

    case Repo.insert(changeset) do
      {:ok, character} -> {:ok, character}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end
end
