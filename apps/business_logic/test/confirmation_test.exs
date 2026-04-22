defmodule BusinessLogic.ConfirmationTest do
  use ExUnit.Case

  alias BusinessLogic
  alias Data
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

  describe "create_user/1" do
    test "creates user with hashed password" do
      params = %{
        "login" => "testuser",
        "email" => "test@example.com",
        "name" => "Test User",
        "password" => "password123"
      }

      assert {:ok, user} = BusinessLogic.create_user(params)
      assert user.login == "testuser"
      assert user.email == "test@example.com"
      assert user.password_hash != "password123"
      assert Bcrypt.verify_pass("password123", user.password_hash)
    end

    test "caches user in ETS after creation" do
      params = %{
        "login" => "etsuser",
        "email" => "ets@example.com",
        "name" => "ETS User",
        "password" => "password123"
      }

      {:ok, user} = BusinessLogic.create_user(params)

      assert {:ok, cached_user} = ETS.lookup(:users, user.id)
      assert cached_user.login == "etsuser"
    end

    test "returns error for invalid params" do
      params = %{"login" => "testuser"}

      assert {:error, _} = BusinessLogic.create_user(params)
    end
  end

  describe "confirm_user/1" do
    setup do
      params = %{
        "login" => "confirmtest",
        "email" => "confirm@example.com",
        "name" => "Confirm Test",
        "password" => "password123"
      }

      {:ok, user} = BusinessLogic.create_user(params)
      %{user: user}
    end

    test "confirms unconfirmed user", %{user: user} do
      assert is_nil(user.confirmed_at)

      assert {:ok, :confirmed} = BusinessLogic.confirm_user(user.login)

      updated_user = Data.get_user(user.login)
      assert updated_user.confirmed_at != nil

      assert {:ok, cached} = ETS.lookup(:users, user.id)
      assert cached.confirmed_at != nil
    end

    test "returns error for already confirmed user", %{user: user} do
      BusinessLogic.confirm_user(user.login)

      assert {:error, :already_confirmed} = BusinessLogic.confirm_user(user.login)
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = BusinessLogic.confirm_user("nonexistent")
    end
  end

  describe "resend_confirmation/1" do
    test "returns user for unconfirmed user" do
      params = %{
        "login" => "resendtest",
        "email" => "resend@example.com",
        "name" => "Resend Test",
        "password" => "password123"
      }

      {:ok, user} = BusinessLogic.create_user(params)

      assert {:ok, returned_user} = BusinessLogic.resend_confirmation(user.login)
      assert returned_user.id == user.id
    end

    test "returns error for already confirmed user" do
      params = %{
        "login" => "confirmedtest",
        "email" => "confirmed@example.com",
        "name" => "Confirmed Test",
        "password" => "password123"
      }

      {:ok, user} = BusinessLogic.create_user(params)
      BusinessLogic.confirm_user(user.login)

      assert {:error, :already_confirmed} = BusinessLogic.resend_confirmation(user.login)
    end

    test "returns error for non-existent user" do
      assert {:error, :not_found} = BusinessLogic.resend_confirmation("nonexistent")
    end
  end

  describe "authenticate_user/1" do
    setup do
      params = %{
        "login" => "authtest",
        "email" => "auth@example.com",
        "name" => "Auth Test",
        "password" => "mypassword"
      }

      {:ok, user} = BusinessLogic.create_user(params)
      BusinessLogic.confirm_user(user.login)
      %{user: user}
    end

    test "authenticates confirmed user with correct password", %{user: _user} do
      assert {:ok, user} =
               BusinessLogic.authenticate_user(%{
                 "login" => "authtest",
                 "password" => "mypassword"
               })

      assert user.login == "authtest"
    end

    test "returns error for wrong password" do
      assert {:error, :authentication_failed} =
               BusinessLogic.authenticate_user(%{
                 "login" => "authtest",
                 "password" => "wrongpassword"
               })
    end

    test "returns error for unconfirmed user" do
      params = %{
        "login" => "unconfirmed",
        "email" => "unconfirmed@example.com",
        "name" => "Unconfirmed",
        "password" => "password"
      }

      {:ok, _user} = BusinessLogic.create_user(params)

      assert {:error, :not_confirmed} =
               BusinessLogic.authenticate_user(%{
                 "login" => "unconfirmed",
                 "password" => "password"
               })
    end

    test "returns error for non-existent user" do
      assert {:error, :user_not_exists} =
               BusinessLogic.authenticate_user(%{
                 "login" => "nonexistent",
                 "password" => "password"
               })
    end

    test "caches user in ETS after successful authentication" do
      {:ok, user} =
        BusinessLogic.authenticate_user(%{"login" => "authtest", "password" => "mypassword"})

      assert {:ok, cached} = ETS.lookup(:users, user.id)
      assert cached.login == "authtest"
    end
  end
end
