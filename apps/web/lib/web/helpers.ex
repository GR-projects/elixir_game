defmodule Web.Helpers do
  def get_user(conn) do
    conn.assigns.user
  end
end
