defmodule BusinessLogic.Test.Support.DataCase do
  alias Ecto.Adapters.SQL.Sandbox

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Data.Repo
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import BusinessLogic.Test.Support.DataCase
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Data.Repo)

    unless tags[:async] do
      Sandbox.mode(Data.Repo, {:shared, self()})
    end

    :ok
  end
end
