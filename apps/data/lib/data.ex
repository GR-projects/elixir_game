defmodule Data do
  alias Data.Repo

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
end
