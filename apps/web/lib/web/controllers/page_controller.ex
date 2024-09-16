defmodule Web.PageController do
  use Web, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def login(conn, _params) do
    render(conn, :login, layout: false)
  end

  def register(conn, _params) do
    render(conn, :register, layout: false)
  end
end
