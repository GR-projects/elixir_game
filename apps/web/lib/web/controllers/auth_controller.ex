defmodule Web.AuthController do
  use Web, :controller
  alias Web.Messages
  alias Web.Emails.Sender
  alias Utils.ETS

  @confirmation_valid_hours 24

  defp get_user_from_session(conn) do
    with user_id when not is_nil(user_id) <- get_session(conn, :user_id),
         {:ok, user} <- ETS.lookup(:users, user_id) do
      {:ok, user}
    else
      _ -> nil
    end
  end

  defp create_confirmation_token(login, email) do
    Phoenix.Token.sign(
      Web.Endpoint,
      "confirm",
      %{login: login, email: email, sent_at: DateTime.utc_now()}
    )
  end

  defp verify_confirmation_token(token) do
    Phoenix.Token.verify(
      Web.Endpoint,
      "confirm",
      token,
      max_age: 3600 * @confirmation_valid_hours
    )
  end

  def register(conn, %{"user" => params}) do
    case BusinessLogic.create_user(params) do
      {:ok, user} ->
        token = create_confirmation_token(user.login, user.email)
        send_confirmation_email(user, token)

        conn
        |> redirect(to: ~p"/registration-sent")

      {:error, _error} ->
        conn
        |> put_flash(:error, Messages.user_registration_failure())
        |> redirect(to: ~p"/register")
    end
  end

  def logout(conn, _params) do
    conn
    |> delete_session(:user_id)
    |> redirect(to: ~p"/login")
  end

  def login(conn, %{"user" => params}) do
    case BusinessLogic.authenticate_user(params) do
      {:ok, user} ->
        conn
        |> put_session(:user_id, user.id)
        |> put_flash(:info, Messages.user_login_success())
        |> redirect(to: ~p"/")

      {:error, :not_confirmed} ->
        conn
        |> put_flash(:error, Messages.user_not_confirmed())
        |> redirect(to: ~p"/resend-confirmation")

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

  def registration_sent(conn, _params) do
    render(conn, :registration_sent, layout: false)
  end

  def register_page(conn, _params) do
    case get_user_from_session(conn) do
      nil ->
        changeset = BusinessLogic.user_changeset()
        render(conn, :register, layout: false, changeset: changeset)

      {:ok, _user} ->
        redirect(conn, to: ~p"/")
    end
  end

  def confirm(conn, %{"token" => token}) do
    case verify_confirmation_token(token) do
      {:ok, %{login: login}} ->
        case BusinessLogic.confirm_user(login) do
          {:ok, :confirmed} ->
            conn
            |> put_flash(:info, Messages.user_confirmed())
            |> redirect(to: ~p"/login")

          {:error, :not_found} ->
            conn
            |> put_flash(:error, Messages.confirmation_invalid())
            |> redirect(to: ~p"/login")

          {:error, :already_confirmed} ->
            conn
            |> put_flash(:info, Messages.user_already_confirmed())
            |> redirect(to: ~p"/login")

          {:error, _} ->
            conn
            |> put_flash(:error, Messages.confirmation_invalid())
            |> redirect(to: ~p"/login")
        end

      {:error, :expired} ->
        conn
        |> put_flash(:error, Messages.confirmation_expired())
        |> redirect(to: ~p"/register")

      {:error, _} ->
        conn
        |> put_flash(:error, Messages.confirmation_invalid())
        |> redirect(to: ~p"/login")
    end
  end

  def resend_confirmation_page(conn, _params) do
    render(conn, :resend_confirmation, layout: false)
  end

  def resend_confirmation(conn, %{"login" => login}) do
    case BusinessLogic.resend_confirmation(login) do
      {:ok, user} ->
        token = create_confirmation_token(user.login, user.email)
        send_confirmation_email(user, token)

        conn
        |> put_flash(:info, Messages.confirmation_resent())
        |> redirect(to: ~p"/login")

      {:error, :already_confirmed} ->
        conn
        |> put_flash(:info, Messages.user_already_confirmed())
        |> redirect(to: ~p"/login")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, Messages.user_not_found())
        |> redirect(to: ~p"/resend-confirmation")
    end
  end

  defp send_confirmation_email(user, token) do
    base_url = Application.get_env(:web, :base_url, "http://localhost:4000")
    Task.start_link(fn -> Sender.deliver_confirmation_email(user, token, base_url) end)
  end
end
