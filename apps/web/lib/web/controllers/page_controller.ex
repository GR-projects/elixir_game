defmodule Web.PageController do
  use Web, :controller
  alias Web.Messages

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

  def character(conn, _params) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :login, layout: false, changeset: changeset)

      user ->
        changeset = BusinessLogic.character_changeset()

        conn
        |> assign(:user, user)
        |> render(:character, changeset: changeset)
    end
  end

  def create_character(conn, %{"character" => params}) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :login, layout: false, changeset: changeset)

      user ->
        case BusinessLogic.create_character(user, params) do
          {:ok, character} ->
            conn
            |> redirect(to: ~p"/character")

          {:error, _error} ->
            conn
            |> assign(:user, user)
            |> put_flash(:error, Messages.character_create_failure())
            |> redirect(to: ~p"/character")
        end
    end




  end
end
