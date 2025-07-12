defmodule Web.PageController do
  use Web, :controller

  alias Utils.ETS

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def main(conn, _params) do
    render(conn, :main)
  end

  def equipment(conn, _params) do
    items = BusinessLogic.get_user_items(conn.assigns.user)
      # :users
      # |> ETS.lookup(conn.assigns.user.login)
      # |> dbg()
      # |> case do
      #   {:ok, user} ->
      #     user
      #     |> Map.get(:characters)
      #     |> case do
      #       nil ->
      #         []
      #       [] ->
      #         []
      #       characters ->
      #         characters
      #         |> Enum.flat_map(&Map.get(&1, :items, []))
      #     end
      #   {:error, _} ->
      #     []
      # end


    # |> Data.get_character_items()

    dbg(items)

    # eq = [
    #   %{name: "Sword +0", type: :sword, stats: "3 ATT 0 DEF"}
    # ]

    render(conn, :equipment, equipment: items)
  end
end
