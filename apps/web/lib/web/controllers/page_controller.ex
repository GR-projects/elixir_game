defmodule Web.PageController do
  use Web, :controller

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
    dbg(items)
    render(conn, :equipment, equipment: items)
  end
end
