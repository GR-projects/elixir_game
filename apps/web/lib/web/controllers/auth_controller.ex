defmodule Web.AuthController do
  use Web, :controller
  alias Web.Messages

  def register(conn, %{"user" => params}) do
    case BusinessLogic.create_user(params) do
      {:ok, user} ->
        conn
        |> put_session(:user, user)
        |> put_flash(:info, Messages.user_registration_success())
        |> redirect(to: ~p"/")

      {:error, _error} ->
        conn
        |> put_flash(:error, Messages.user_registration_failure())
        |> redirect(to: ~p"/register")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:user)
    |> redirect(to: ~p"/login")
  end

  def login(conn, %{"user" => params}) do
    case BusinessLogic.authenticate_user(params) do
      {:ok, user} ->
        conn
        |> put_session(:user, user)
        |> put_flash(:info, Messages.user_login_success())
        |> redirect(to: ~p"/")


      {:error, _} ->
        changeset = BusinessLogic.user_changeset()

        conn
        |> put_flash(:error, Messages.user_login_failure())
        |> render(:login, layout: false, changeset: changeset)
    end
  end

  def login_page(conn, _params) do
    changeset = BusinessLogic.user_changeset()
    render(conn, :login, layout: false, changeset: changeset)
  end

  def show(conn, _params) do
    render(conn, :show)
  end

  def register_page(conn, _params) do
    case get_session(conn, :user) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :register, layout: false, changeset: changeset)

      _user ->
        redirect(conn, to: ~p"/")
    end
  end
end
