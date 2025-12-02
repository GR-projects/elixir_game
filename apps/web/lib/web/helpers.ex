defmodule Web.Helpers do
  @moduledoc """
  Helper functions for web controllers and views.
  """
  def get_user(conn) do
    conn.assigns.user
  end
end
