defmodule Web.CharacterController do
  use Web, :controller
  alias Web.Messages

  def index(conn, _params) do
    user = get_user_from_session(conn)

    if user do
      changeset = BusinessLogic.character_changeset()

      conn
      |> assign(:user, user)
      |> render(:character, changeset: changeset)
    else
      redirect_to_login(conn)
    end
  end

  def new(conn, _params) do
    user = get_user_from_session(conn)

    if user do
      changeset = BusinessLogic.character_changeset()

      conn
      |> assign(:user, user)
      |> render(:character_new, changeset: changeset)
    else
      redirect_to_login(conn)
    end
  end

  def create(conn, %{"character" => params}) do
    user = get_user_from_session(conn)

    if user do
      case BusinessLogic.create_character(user, params) do
        {:ok, _character} ->
          conn
          |> redirect(to: ~p"/character")

        {:error, _error} ->
          conn
          |> assign(:user, user)
          |> put_flash(:error, Messages.character_create_failure())
          |> redirect(to: ~p"/character")
      end
    else
      redirect_to_login(conn)
    end
  end

  def show(conn, %{"id" => id}) do
    user = get_user_from_session(conn)

    if user do
      case BusinessLogic.get_character(id) do
        {:ok, character} ->
          conn
          |> assign(:user, user)
          |> render(:show, character: character)

        {:error, _error} ->
          conn
          |> assign(:user, user)
          |> put_flash(:error, Messages.character_get_failure())
          |> redirect(to: ~p"/character")
      end
    else
      redirect_to_login(conn)
    end
  end

  def delete(conn, %{"id" => id}) do
    user = get_user_from_session(conn)

    if user do
      case BusinessLogic.delete_character(id, user) do
        {:ok, _character} ->
          conn
          |> assign(:user, user)
          |> redirect(to: ~p"/character")

        {:error, _error} ->
          conn
          |> assign(:user, user)
          |> put_flash(:error, Messages.character_get_failure())
          |> redirect(to: ~p"/character")
      end
    else
      redirect_to_login(conn)
    end
  end

  defp get_user_from_session(conn) do
    user_id = get_session(conn, :user_id)
    if user_id, do: Data.get_user_by_id(user_id)
  end

  defp redirect_to_login(conn) do
    changeset = BusinessLogic.user_changeset()
    render(conn, :login, layout: false, changeset: changeset)
  end
end
