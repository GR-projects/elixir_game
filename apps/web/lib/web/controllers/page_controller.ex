defmodule Web.PageController do
  use Web, :controller

  defmacrop with_user_logged_in(conn, do: do_block) do
    quote do
      case get_user(unquote(conn)) do
        nil ->
          changeset = BusinessLogic.user_changeset()
          render(unquote(conn), :login, layout: false, changeset: changeset)

        user ->
          unquote(do_block)
          |> assign(:user, user)
      end
    end
  end

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def main(conn, _params) do
    with_user_logged_in(conn) do
      render(conn, :main)
    end
  end

  def equipment(conn, _params) do
    with_user_logged_in(conn) do
      user = get_user(conn)

      eq = [
        %{name: "Sword +0", type: :sword, stats: "3 ATT 0 DEF"}
      ]

      render(conn, :equipment, equipment: eq)
    end
  end

  defp get_user(conn) do
    get_session(conn, :user)
  end
end
