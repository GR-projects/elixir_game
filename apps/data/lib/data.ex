defmodule Data do
  alias Data.Item
  alias Data.Repo
  alias Data.User
  alias Data.Character

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
    Repo.get_by(User, login: login)
    |> Repo.preload(:characters)
  end

  @spec get_character_items(Character.t()) :: [map()]
  def get_character_items(character) do
    (i in Item)
    |> from(as: :item)
    |> preload(:stats)
    |> where([item: i], i.character_id == ^character.id)
    |> Repo.all()
  end

  @spec get_user_characters(User.t()) :: nil
  def get_user_characters(user) do
  end
end
