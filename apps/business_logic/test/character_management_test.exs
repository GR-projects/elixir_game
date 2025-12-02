defmodule BusinessLogic.CharacterManagementTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox

  # Setup and teardown for each test
  setup do
    # Start a transaction for this test
    :ok = Sandbox.checkout(Data.Repo)

    # Clean up ETS tables before each test
    Utils.ETS.clear(:users)

    :ok
  end

  describe "character creation" do
    test "creates character with default values" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser1", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      character_params = %{"type" => "mage", "name" => "Gandalf"}

      {:ok, character} = BusinessLogic.create_character(user, character_params)
      assert Map.take(character, [:type, :name, :level, :experience, :user_id]) == %{
        type: "mage",
        name: "Gandalf",
        level: 1,
        experience: 0.0,
        user_id: user.id
      }
    end

    test "creates character with different types" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser2", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      character_params = %{"type" => "archer", "name" => "Legolas"}

      {:ok, character} = BusinessLogic.create_character(user, character_params)
      assert Map.take(character, [:type, :name, :level, :experience, :user_id]) == %{
        type: "archer",
        name: "Legolas",
        level: 1,
        experience: 0.0,
        user_id: user.id
      }
    end

    test "creates character with custom name" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser3", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      character_params = %{"type" => "warrior", "name" => "Aragorn"}

      {:ok, character} = BusinessLogic.create_character(user, character_params)
      assert Map.take(character, [:type, :name, :level, :experience, :user_id]) == %{
        type: "warrior",
        name: "Aragorn",
        level: 1,
        experience: 0.0,
        user_id: user.id
      }
    end

    test "sets user_id from provided user" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser4", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      character_params = %{"type" => "rogue", "name" => "Bilbo"}

      {:ok, character} = BusinessLogic.create_character(user, character_params)
      assert Map.take(character, [:type, :name, :level, :experience, :user_id]) == %{
        type: "rogue",
        name: "Bilbo",
        level: 1,
        experience: 0.0,
        user_id: user.id
      }
    end
  end

  describe "character retrieval" do
    test "retrieves character by id" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser5", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})

      result = BusinessLogic.get_character(character.id)
      assert result == {:ok, character}
      assert elem(result, 1).id == character.id
    end

    test "handles non-existent character" do
      character_id = 999

      result = BusinessLogic.get_character(character_id)
      assert result == {:error, nil}
    end

    test "retrieves character with different id" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser6", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "warrior", "name" => "Aragorn"})

      result = BusinessLogic.get_character(character.id)
      assert result == {:ok, character}
      assert elem(result, 1).id == character.id
    end
  end

  describe "character deletion" do
    test "deletes character by id" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser7", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})

      result = BusinessLogic.get_character(character.id)
      assert result == {:ok, character}

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

    test "deletes character with different id" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser8", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "warrior", "name" => "Aragorn"})

      result = BusinessLogic.delete_character(character.id)
      assert result == {:ok, character}
      assert elem(result, 1).id == character.id

      result = BusinessLogic.get_character(character.id)
      assert result == {:error, nil}
    end
  end

  describe "parameter handling" do
    test "handles empty params" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser9", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      # Empty params should raise a function clause error since both "type" and "name" are required
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.create_character(user, %{})
      end
    end

    test "handles params with only type" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser10", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      character_params = %{"type" => "mage"}

      # Should raise a function clause error since "name" is required
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.create_character(user, character_params)
      end
    end

    test "handles params with only name" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser11", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      character_params = %{"name" => "CustomName"}

      # Should raise a function clause error since "type" is required
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.create_character(user, character_params)
      end
    end
  end
end
