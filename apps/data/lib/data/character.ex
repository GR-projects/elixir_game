defmodule Data.Character do
  use Ecto.Schema

  @type t :: %__MODULE__{}

  schema "characters" do
    belongs_to(:user, Data.User)
  end
end
