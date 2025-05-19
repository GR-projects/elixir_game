defmodule Web.CharacterController do
  use Web, :controller
  alias Web.Messages

  def index(conn, _params) do
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

  def new(conn, _params) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :login, layout: false, changeset: changeset)

      user ->
        changeset = BusinessLogic.character_changeset()

        conn
        |> assign(:user, user)
        |> render(:character_new, changeset: changeset)
    end
  end

  def create(conn, %{"character" => params}) do
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

  def show(conn, %{"id" => id}) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :login, layout: false, changeset: changeset)

      user ->
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
    end
  end
  def edit(conn, %{"id" => id}) do
    nil
  end

  def update(conn, %{"id" => id, "character" => char_params}) do
    nil
  end

  def delete(conn, %{"id" => id}) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :login, layout: false, changeset: changeset)

      user ->
        case BusinessLogic.delete_character(id) do
          {:ok, character} ->
            character

          {:error, _error} ->
            conn
            |> assign(:user, user)
            |> put_flash(:error, Messages.character_get_failure())
            |> redirect(to: ~p"/character")
        end
    end
  end
end
