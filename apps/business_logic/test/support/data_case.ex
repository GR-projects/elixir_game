defmodule BusinessLogic.Test.Support.DataCase do
  @moduledoc """
  This module defines the test case to be used by tests that require
  setting up a connection to the database.
  """

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
