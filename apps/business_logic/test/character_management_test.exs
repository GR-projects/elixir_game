defmodule BusinessLogic.CharacterManagementTest do
  use ExUnit.Case, async: false
  import Mock
  import BusinessLogic.TestHelpers

  describe "character creation" do
    test "creates character with default values" do
      user = create_test_user(%{id: 123})
      params = %{"type" => "mage", "name" => "Gandalf"}

      with_mock Data, [create_character: fn character_params ->
        assert character_params["type"] == "mage"
        assert character_params["name"] == "Gandalf"
        assert character_params["level"] == 1
        assert character_params["experience"] == 0
        assert character_params["user_id"] == 123
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, params)
        assert character.type == "mage"
        assert character.name == "Gandalf"
        assert character.level == 1
        assert character.experience == 0.0
        assert character.user_id == 123
      end
    end

    test "creates character with different types" do
      user = create_test_user(%{id: 456})
      params = %{"type" => "archer", "name" => "Legolas"}

      with_mock Data, [create_character: fn character_params ->
        assert character_params["type"] == "archer"
        assert character_params["name"] == "Legolas"
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, params)
        assert character.type == "archer"
        assert character.name == "Legolas"
      end
    end

    test "creates character with custom name" do
      user = create_test_user(%{id: 789})
      params = %{"type" => "warrior", "name" => "Aragorn"}

      with_mock Data, [create_character: fn character_params ->
        assert character_params["name"] == "Aragorn"
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, params)
        assert character.name == "Aragorn"
      end
    end

    test "sets user_id from provided user" do
      user = create_test_user(%{id: 999})
      params = %{"type" => "rogue", "name" => "Bilbo"}

      with_mock Data, [create_character: fn character_params ->
        assert character_params["user_id"] == 999
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, params)
        assert character.user_id == 999
      end
    end
  end

  describe "character retrieval" do
    test "retrieves character by id" do
      character_id = 123
      character = create_test_character(%{id: character_id})

      with_mock Data, [get_character: fn ^character_id -> {:ok, character} end] do
        result = BusinessLogic.get_character(character_id)
        assert result == {:ok, character}
      end
    end

    test "handles non-existent character" do
      character_id = 999

      with_mock Data, [get_character: fn ^character_id -> {:error, nil} end] do
        result = BusinessLogic.get_character(character_id)
        assert result == {:error, nil}
      end
    end

    test "retrieves character with different id" do
      character_id = 456
      character = create_test_character(%{id: character_id})

      with_mock Data, [get_character: fn ^character_id -> {:ok, character} end] do
        result = BusinessLogic.get_character(character_id)
        assert result == {:ok, character}
        assert elem(result, 1).id == 456
      end
    end
  end

  describe "character deletion" do
    test "deletes character by id" do
      character_id = 123
      character = create_test_character(%{id: character_id})

      with_mock Data, [delete_character: fn ^character_id -> {:ok, character} end] do
        result = BusinessLogic.delete_character(character_id)
        assert result == {:ok, character}
      end
    end

    test "handles deletion of non-existent character" do
      character_id = 999

      with_mock Data, [delete_character: fn ^character_id -> {:error, nil} end] do
        result = BusinessLogic.delete_character(character_id)
        assert result == {:error, nil}
      end
    end

    test "deletes character with different id" do
      character_id = 789
      character = create_test_character(%{id: character_id})

      with_mock Data, [delete_character: fn ^character_id -> {:ok, character} end] do
        result = BusinessLogic.delete_character(character_id)
        assert result == {:ok, character}
        assert elem(result, 1).id == 789
      end
    end
  end

  describe "parameter handling" do
    test "handles empty params" do
      user = create_test_user(%{id: 123})

      with_mock Data, [create_character: fn character_params ->
        assert character_params["type"] == "warrior"
        assert character_params["name"] == "Character 123"
        assert character_params["level"] == 1
        assert character_params["experience"] == 0
        assert character_params["user_id"] == 123
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, %{})
        assert character.type == "warrior"
        assert character.name == "Character 123"
      end
    end

    test "handles params with only type" do
      user = create_test_user(%{id: 456})
      params = %{"type" => "mage"}

      with_mock Data, [create_character: fn character_params ->
        assert character_params["type"] == "mage"
        assert character_params["name"] == "Character 456"
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, params)
        assert character.type == "mage"
        assert character.name == "Character 456"
      end
    end

    test "handles params with only name" do
      user = create_test_user(%{id: 789})
      params = %{"name" => "CustomName"}

      with_mock Data, [create_character: fn character_params ->
        assert character_params["type"] == "warrior"
        assert character_params["name"] == "CustomName"
        # Use test helper with atom keys
        create_test_character(%{
          name: character_params["name"],
          type: character_params["type"],
          level: character_params["level"],
          experience: character_params["experience"],
          user_id: character_params["user_id"]
        })
      end] do
        {:ok, character} = BusinessLogic.create_character(user, params)
        assert character.type == "warrior"
        assert character.name == "CustomName"
      end
    end
  end
end
