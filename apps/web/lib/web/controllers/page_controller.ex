defmodule Web.PageController do
  use Web, :controller

  alias Web.Helpers

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def main(conn, _params) do
    render(conn, :main)
  end

  def equipment(conn, _params) do
    items =
      :users
      |> Utils.ETS.lookup(conn.assigns.user.login)
      |> case do
        {:ok, user} ->
          user
          |> Map.get(:characters)
          |> case do
            nil ->
              []
            characters ->
              characters
              |> Enum.map(&Data.get_character_items(&1))
              |> List.flatten()
          end
        {:error, _} ->
          []
      end


    # |> Data.get_character_items()

    dbg(items)

    # eq = [
    #   %{name: "Sword +0", type: :sword, stats: "3 ATT 0 DEF"}
    # ]

    render(conn, :equipment, equipment: items)
  end
end
