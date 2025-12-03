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

  describe "get_user_items/1" do
    test "retrieves items from cached user data" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)

      # Seed ETS cache for this user with a character and an item
      assert {:ok, cached_user} = Utils.ETS.lookup(:users, params["login"])
      updated_user = %{cached_user | characters: [%{items: [%{name: "Sword"}]}]}
      Utils.ETS.insert(:users, {params["login"], updated_user})
      assert {:ok, ets_user} = Utils.ETS.lookup(:users, params["login"])
      assert [character] = ets_user.characters
      assert [cached_item] = character.items
      assert Map.take(cached_item, [:name]) == %{name: "Sword"}

      items = BusinessLogic.get_user_items(user)
      assert [item] = items
      assert Map.take(item, [:name]) == %{name: "Sword"}
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
      assert [item] = items
      assert Map.take(item, [:name, :type, :position, :equipped?]) == %{
        name: "Sword",
        type: :sword,
        position: :right_hand,
        equipped?: false
      }
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
      assert [character] = cached_user.characters || []
      assert Map.take(character, [:name, :type]) == %{
        name: "Aragorn",
        type: "warrior"
      }

      [character] = Data.get_user_characters(user)
      assert Map.take(character, [:name, :type]) == %{
        name: "Aragorn",
        type: "warrior"
      }

      items = BusinessLogic.get_user_items(user)
      assert items == []
    end

    test "caches user data after first database lookup" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser_cache1", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "warrior", "name" => "Aragorn"})
      {:ok, _item} = Data.Repo.insert(%Data.Item{name: "Sword", type: :sword, position: :right_hand, equipped?: false, character_id: character.id})

      # Clear cache to simulate cache miss
      Utils.ETS.delete(:users, params["login"])
      {:error, :not_found} = Utils.ETS.lookup(:users, params["login"])

      # First call: cache miss, should hit database and populate cache
      items = BusinessLogic.get_user_items(user)
      assert [item] = items
      assert Map.take(item, [:name, :type, :position, :equipped?]) == %{
        name: "Sword",
        type: :sword,
        position: :right_hand,
        equipped?: false
      }

      # Verify cache was populated
      assert {:ok, cached_user} = Utils.ETS.lookup(:users, params["login"])
      assert [character] = cached_user.characters
      assert Map.take(character, [:name, :type]) == %{
        name: "Aragorn",
        type: "warrior"
      }
      assert [cached_item] = character.items
      assert Map.take(cached_item, [:name, :type, :position, :equipped?]) == %{
        name: "Sword",
        type: :sword,
        position: :right_hand,
        equipped?: false
      }

      # Second call: cache hit, should use cached data
      items2 = BusinessLogic.get_user_items(user)
      assert [item2] = items2
      assert Map.take(item2, [:name, :type, :position, :equipped?]) == %{
        name: "Sword",
        type: :sword,
        position: :right_hand,
        equipped?: false
      }
    end

    test "handles cache invalidation gracefully" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser_cache2", "password" => "password123"}
      {:ok, user} = BusinessLogic.create_user(params)
      {:ok, character} = BusinessLogic.create_character(user, %{"type" => "mage", "name" => "Gandalf"})
      {:ok, _item} = Data.Repo.insert(%Data.Item{name: "Staff", type: :staff, position: :right_hand, equipped?: false, character_id: character.id})

      # Clear cache to simulate cache miss
      Utils.ETS.delete(:users, params["login"])
      {:error, :not_found} = Utils.ETS.lookup(:users, params["login"])

      # First call: cache miss, should hit database
      items = BusinessLogic.get_user_items(user)
      assert [item] = items
      assert Map.take(item, [:name, :type, :position, :equipped?]) == %{
        name: "Staff",
        type: :staff,
        position: :right_hand,
        equipped?: false
      }

      # Verify cache was populated
      assert {:ok, _cached_user} = Utils.ETS.lookup(:users, params["login"])

      # Cache cleared, should hit database again
      Utils.ETS.delete(:users, params["login"])
      {:error, :not_found} = Utils.ETS.lookup(:users, params["login"])

      items2 = BusinessLogic.get_user_items(user)
      assert [item2] = items2
      assert Map.take(item2, [:name, :type, :position, :equipped?]) == %{
        name: "Staff",
        type: :staff,
        position: :right_hand,
        equipped?: false
      }
    end

    test "caches different users separately" do
      params1 = %{"name" => "Test User 1", "email" => "test1@example.com", "login" => "testuser_cache3", "password" => "password123"}
      params2 = %{"name" => "Test User 2", "email" => "test2@example.com", "login" => "testuser_cache4", "password" => "password123"}

      {:ok, user1} = BusinessLogic.create_user(params1)
      {:ok, user2} = BusinessLogic.create_user(params2)

      {:ok, character1} = BusinessLogic.create_character(user1, %{"type" => "warrior", "name" => "Aragorn"})
      {:ok, character2} = BusinessLogic.create_character(user2, %{"type" => "archer", "name" => "Legolas"})

      {:ok, _item1} = Data.Repo.insert(%Data.Item{name: "Sword", type: :sword, position: :right_hand, equipped?: false, character_id: character1.id})
      {:ok, _item2} = Data.Repo.insert(%Data.Item{name: "Bow", type: :bow, position: :right_hand, equipped?: false, character_id: character2.id})

      # Clear cache for both users
      Utils.ETS.delete(:users, params1["login"])
      Utils.ETS.delete(:users, params2["login"])

      # First call for user1: cache miss, should hit database and cache
      items1 = BusinessLogic.get_user_items(user1)
      assert [item1] = items1
      assert Map.take(item1, [:name, :type, :position, :equipped?]) == %{
        name: "Sword",
        type: :sword,
        position: :right_hand,
        equipped?: false
      }

      # First call for user2: cache miss, should hit database and cache
      items2 = BusinessLogic.get_user_items(user2)
      assert [item2] = items2
      assert Map.take(item2, [:name, :type, :position, :equipped?]) == %{
        name: "Bow",
        type: :bow,
        position: :right_hand,
        equipped?: false
      }

      # Verify both users are cached separately
      assert {:ok, cached_user1} = Utils.ETS.lookup(:users, params1["login"])
      assert {:ok, cached_user2} = Utils.ETS.lookup(:users, params2["login"])

      assert [character1] = cached_user1.characters
      assert Map.take(character1, [:name, :type]) == %{
        name: "Aragorn",
        type: "warrior"
      }

      assert [character2] = cached_user2.characters
      assert Map.take(character2, [:name, :type]) == %{
        name: "Legolas",
        type: "archer"
      }

      # Retrieve from cache - should still get correct items
      cached_items1 = BusinessLogic.get_user_items(user1)
      assert [cached_item1] = cached_items1
      assert Map.take(cached_item1, [:name, :type, :position, :equipped?]) == %{
        name: "Sword",
        type: :sword,
        position: :right_hand,
        equipped?: false
      }

      cached_items2 = BusinessLogic.get_user_items(user2)
      assert [cached_item2] = cached_items2
      assert Map.take(cached_item2, [:name, :type, :position, :equipped?]) == %{
        name: "Bow",
        type: :bow,
        position: :right_hand,
        equipped?: false
      }
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
