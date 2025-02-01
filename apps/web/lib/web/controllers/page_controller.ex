defmodule Web.PageController do
  use Web, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def main(conn, _params) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :login, layout: false, changeset: changeset)

      user ->
        conn
        |> assign(:user, user)
        |> render(:main)
    end
  end
end
