defmodule Web.PageController do
  use Web, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def main(conn, _params) do
    user = get_session(conn, :user)

    conn
    |> assign(:user, user)
    |> render(:main)
  end
end
