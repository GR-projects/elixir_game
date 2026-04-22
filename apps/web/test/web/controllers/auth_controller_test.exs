defmodule Web.AuthControllerTest do
  use Web.ConnCase

  alias BusinessLogic
  alias Utils.ETS

  setup do
    :ets.new(:users, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    :ok
  end

  describe "GET /register" do
    test "renders registration form", %{conn: conn} do
      conn = get(conn, ~p"/register")
      assert html_response(conn, 200) =~ "Register"
    end
  end

  describe "POST /register" do
    test "creates user and redirects to registration-sent", %{conn: conn} do
      params = %{
        "user" => %{
          "login" => "newuser",
          "email" => "newuser@example.com",
          "name" => "New User",
          "password" => "password123"
        }
      }

      conn = post(conn, ~p"/register", params)

      assert redirected_to(conn) == "/registration-sent"
    end

    test "renders error for invalid params", %{conn: conn} do
      params = %{
        "user" => %{
          "login" => ""
        }
      }

      conn = post(conn, ~p"/register", params)

      assert html_response(conn, 200) =~ "Register"
    end
  end

  describe "GET /registration-sent" do
    test "renders registration sent page", %{conn: conn} do
      conn = get(conn, ~p"/registration-sent")
      assert html_response(conn, 200) =~ "Check Your Email"
    end
  end

  describe "GET /login" do
    test "renders login form", %{conn: conn} do
      conn = get(conn, ~p"/login")
      assert html_response(conn, 200) =~ "Login"
    end
  end

  describe "POST /login" do
    setup do
      params = %{
        "login" => "loginuser",
        "email" => "login@example.com",
        "name" => "Login User",
        "password" => "secretpass"
      }

      {:ok, user} = BusinessLogic.create_user(params)
      BusinessLogic.confirm_user(user.login)
      %{user: user}
    end

    test "logs in confirmed user", %{conn: conn} do
      params = %{
        "user" => %{
          "login" => "loginuser",
          "password" => "secretpass"
        }
      }

      conn = post(conn, ~p"/login", params)

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_id) != nil
    end

    test "redirects unconfirmed user to resend confirmation", %{conn: conn} do
      {:ok, unconfirmed} =
        BusinessLogic.create_user(%{
          "login" => "unconfirmed",
          "email" => "unconfirmed@example.com",
          "name" => "Unconfirmed",
          "password" => "password"
        })

      params = %{
        "user" => %{
          "login" => "unconfirmed",
          "password" => "password"
        }
      }

      conn = post(conn, ~p"/login", params)

      assert redirected_to(conn) == "/resend-confirmation"
    end

    test "shows error for invalid credentials", %{conn: conn} do
      params = %{
        "user" => %{
          "login" => "loginuser",
          "password" => "wrongpass"
        }
      }

      conn = post(conn, ~p"/login", params)

      assert html_response(conn, 200) =~ "Login"
    end
  end

  describe "GET /confirm/:token" do
    setup do
      params = %{
        "login" => "confirmtest",
        "email" => "confirm@example.com",
        "name" => "Confirm Test",
        "password" => "password"
      }

      {:ok, user} = BusinessLogic.create_user(params)
      %{user: user}
    end

    test "confirms user with valid token", %{conn: conn, user: user} do
      token =
        Phoenix.Token.sign(Web.Endpoint, "confirm", %{
          login: user.login,
          email: user.email,
          sent_at: DateTime.utc_now()
        })

      conn = get(conn, "/confirm/#{token}")

      assert redirected_to(conn) == "/login"
      assert get_flash(conn, :info) =~ "confirmed"

      confirmed_user =
        BusinessLogic.authenticate_user(%{"login" => "confirmtest", "password" => "password"})

      assert {:ok, _} = confirmed_user
    end

    test "shows error for invalid token", %{conn: conn} do
      conn = get(conn, "/confirm/invalid-token")

      assert redirected_to(conn) == "/login"
    end

    test "shows error for expired token", %{conn: conn, user: user} do
      old_time = DateTime.add(DateTime.utc_now(), -25 * 3600, :second)

      token =
        Phoenix.Token.sign(
          Web.Endpoint,
          "confirm",
          %{login: user.login, email: user.email, sent_at: old_time},
          signed_at: :os.system_time(:second) - 90000
        )

      conn = get(conn, "/confirm/#{token}")

      assert redirected_to(conn) == "/register"
    end
  end

  describe "GET /resend-confirmation" do
    test "renders resend confirmation form", %{conn: conn} do
      conn = get(conn, ~p"/resend-confirmation")
      assert html_response(conn, 200) =~ "Resend Confirmation"
    end
  end

  describe "POST /resend-confirmation" do
    setup do
      params = %{
        "login" => "resendtest",
        "email" => "resend@example.com",
        "name" => "Resend Test",
        "password" => "password"
      }

      {:ok, _user} = BusinessLogic.create_user(params)
      :ok
    end

    test "sends confirmation email for unconfirmed user", %{conn: conn} do
      params = %{"login" => "resendtest"}

      conn = post(conn, ~p"/resend-confirmation", params)

      assert redirected_to(conn) == "/login"
      assert get_flash(conn, :info) =~ "resent"
    end

    test "shows message for already confirmed user", %{conn: conn} do
      {:ok, user} =
        BusinessLogic.create_user(%{
          "login" => "alreadyconfirmed",
          "email" => "already@example.com",
          "name" => "Already Confirmed",
          "password" => "password"
        })

      BusinessLogic.confirm_user(user.login)

      params = %{"login" => "alreadyconfirmed"}

      conn = post(conn, ~p"/resend-confirmation", params)

      assert redirected_to(conn) == "/login"
      assert get_flash(conn, :info) =~ "already"
    end

    test "shows error for non-existent user", %{conn: conn} do
      params = %{"login" => "nonexistent"}

      conn = post(conn, ~p"/resend-confirmation", params)

      assert redirected_to(conn) == "/resend-confirmation"
    end
  end

  describe "POST /logout" do
    test "clears session and redirects to login", %{conn: conn} do
      conn = post(conn, ~p"/logout")

      assert redirected_to(conn) == "/login"
      assert get_session(conn, :user_id) == nil
    end
  end
end
