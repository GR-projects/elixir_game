defmodule BusinessLogicTest do
  use BusinessLogic.Test.Support.DataCase, async: false

  # Setup and teardown for each test
  setup do
    # Clean up ETS tables before each test
    Utils.ETS.clear(:users)

    :ok
  end

  doctest BusinessLogic

  describe "user_changeset/1" do
    test "delegates to Data.User.changeset/1" do
      params = %{"name" => "Test User", "email" => "test@example.com"}
      changeset = BusinessLogic.user_changeset(params)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "character_changeset/1" do
    test "delegates to Data.Character.changeset/1" do
      params = %{"name" => "Test Character", "type" => "warrior"}
      changeset = BusinessLogic.character_changeset(params)
      assert %Ecto.Changeset{} = changeset
    end
  end

  describe "create_user/1" do
    test "creates user with hashed password" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      assert %{
        name: "Test User",
        email: "test@example.com",
        login: "testuser",
        password_hash: password_hash
      } = Map.take(user, [:name, :email, :login, :password_hash])
      assert Bcrypt.verify_pass("password123", password_hash)
    end
  end

  describe "authenticate_user/1" do
    test "authenticates valid user credentials" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => params["password"], "login" => params["login"]})
      assert result == {:ok, user}
    end

    test "returns error for non-existent user" do
      result = BusinessLogic.authenticate_user(%{"password" => "anypassword", "login" => "nonexistent"})
      assert result == {:error, :user_not_exists}
    end

    test "returns error for incorrect password" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, _user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "wrongpassword", "login" => params["login"]})
      assert result == {:error, :authentication_failed}
    end

    test "handles empty password gracefully" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, _user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "", "login" => params["login"]})
      assert result == {:error, :authentication_failed}
    end
  end

  describe "create_character/2" do
    test "creates character with default values" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})
      assert Map.take(character, [:type, :name, :level, :experience, :user_id]) == %{
        type: "mage",
        name: "Gandalf",
        level: 1,
        experience: 0.0,
        user_id: user.id
      }
    end
  end

  describe "get_character/1" do
    test "retrieves character by id" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})

      result = BusinessLogic.get_character(character.id)
      assert {:ok, character} == result
    end

    test "handles non-existent character" do
      character_id = 999

      result = BusinessLogic.get_character(character_id)
      assert result == {:error, nil}
    end
  end

  describe "delete_character/1" do
    test "deletes character by id" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})

      result = BusinessLogic.get_character(character.id)
      assert {:ok, character} == result

      result = BusinessLogic.delete_character(character.id)
      assert result == {:ok, character}

      result = BusinessLogic.get_character(character.id)
      assert result == {:error, nil}
    end

    test "handles deletion of non-existent character" do
      character_id = 999

      result = BusinessLogic.delete_character(character_id)
      assert result == {:error, nil}
    end
  end

  describe "edge cases and error handling" do
    test "create_user handles params without password" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser"}

      # This should raise a function clause error since the function requires "password" key
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.create_user(params)
      end
    end

    test "create_user handles empty params" do
      # This should raise a function clause error since the function requires "password" key
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.create_user(%{})
      end
    end

    test "authenticate_user handles malformed params" do
      # This should raise a function clause error since we're not matching the expected pattern
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.authenticate_user(%{"invalid" => "params"})
      end
    end
  end
end
