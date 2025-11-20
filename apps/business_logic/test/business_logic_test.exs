defmodule BusinessLogicTest do
  use ExUnit.Case, async: false
  import BusinessLogic.TestHelpers

  # Setup and teardown for each test
  setup do
    # Start a transaction for this test
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Data.Repo)

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
      assert user.name == "Test User"
      assert user.email == "test@example.com"
      assert user.login == "testuser"
      assert Bcrypt.verify_pass("password123", user.password_hash)
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
      {:ok, user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "wrongpassword", "login" => params["login"]})
      assert result == {:error, :authentication_failed}
    end

    test "handles empty password gracefully" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "", "login" => params["login"]})
      assert result == {:error, :authentication_failed}
    end
  end

  describe "get_user_items/1" do
    test "retrieves items from cached user data" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      # Seed ETS cache for this user with a character and an item
      assert {:ok, cached_user} = Utils.ETS.lookup(:users, params["login"])
      updated_user = %{cached_user | characters: [%{items: [%{name: "Sword"}]}]}
      Utils.ETS.insert(:users, {params["login"], updated_user})
      assert {:ok, ets_user} = Utils.ETS.lookup(:users, params["login"])
      assert is_list(ets_user.characters)
      assert length(ets_user.characters) == 1

      items = BusinessLogic.get_user_items(user)
      assert length(items) == 1
      assert hd(items).name == "Sword"
    end

    test "retrieves items from database when not cached" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "warrior", "name" => "Aragorn"})
      {:ok, _item} = Data.Repo.insert(%Data.Item{name: "Sword", type: :sword, position: :right_hand, equipped?: false, character_id: character.id})

      {:ok, user} = Utils.ETS.lookup(:users, params["login"])
      # Ensure we are not using ETS cache
      Utils.ETS.delete(:users, params["login"])
      {:error, :not_found} = Utils.ETS.lookup(:users, params["login"])


      Data.Repo.all(Data.User) |> Data.Repo.preload(:characters)
      Data.Repo.all(Data.Character) |> Data.Repo.preload(:items)

      items = BusinessLogic.get_user_items(user)
      assert length(items) == 1
      assert hd(items).name == "Sword"
    end

    test "returns empty list for user with no characters" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      chars = Data.get_user_characters(user)
      assert chars == []
      items = BusinessLogic.get_user_items(user)
      assert items == []
    end

    test "returns empty list for user with characters but no items" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, _character} = BusinessLogic.create_character(user, %{"type" => "warrior", "name" => "Aragorn"})

      # Verify user is cached in ETS and contains the new character
      assert {:ok, cached_user} = Utils.ETS.lookup(:users, params["login"])
      assert Enum.any?(cached_user.characters || [], fn c ->
        c.name == "Aragorn" and c.type == "warrior"
      end)

      [character] = Data.get_user_characters(user)
      assert character.name == "Aragorn"
      assert character.type == "warrior"

      items = BusinessLogic.get_user_items(user)
      assert items == []
    end
  end

  describe "create_character/2" do
    test "creates character with default values" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})
      assert character.type == "mage"
      assert character.name == "Gandalf"
      assert character.level == 1
      assert character.experience == 0.0
      assert character.user_id == user.id
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

    test "get_user_items handles user with nil characters gracefully" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      # Manually set characters to nil in ETS cache to test edge case
      assert {:ok, cached_user} = Utils.ETS.lookup(:users, params["login"])
      updated_user = %{cached_user | characters: nil}
      Utils.ETS.insert(:users, {params["login"], updated_user})

      # Should handle nil gracefully and return empty list
      items = BusinessLogic.get_user_items(user)
      assert items == []
    end
  end
end
