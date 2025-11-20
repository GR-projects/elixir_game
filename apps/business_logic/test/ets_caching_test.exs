defmodule BusinessLogic.ETSCachingTest do
  use ExUnit.Case, async: false
  import Mock
  import BusinessLogic.TestHelpers

  describe "ETS caching behavior" do
    test "caches user data after first database lookup" do
      user = create_test_user(%{login: "testuser"})
      character = create_test_character(%{user_id: user.id, items: [create_test_item()]})
      db_user = %{user | characters: [character]}

      # First call: cache miss, should hit database
      with_mocks([
        {Utils.ETS, [lookup: fn :users, "testuser" -> {:error, :not_found} end]},
        {Data.Repo, [preload: fn user, [characters: :items] ->
          %{user | characters: [create_test_character(%{user_id: user.id, items: [create_test_item()]})]}
        end]},
        {Utils.ETS, [insert: fn :users, {"testuser", ^db_user} -> true end]}
      ]) do
        items = BusinessLogic.get_user_items(user)
        assert length(items) == 1
      end

      # Second call: cache hit, should not hit database again
      cached_user = %{user | characters: [character]}
      with_mock Utils.ETS, [lookup: fn :users, "testuser" -> {:ok, cached_user} end] do
        items = BusinessLogic.get_user_items(user)
        assert length(items) == 1
      end
    end

    test "handles cache invalidation gracefully" do
      user = create_test_user(%{login: "testuser"})

      # Simulate cache being cleared between calls
      with_mocks([
        {Utils.ETS, [lookup: fn :users, "testuser" -> {:error, :not_found} end]},
        {Data.Repo, [preload: fn user, [characters: :items] ->
          %{user | characters: [create_test_character(%{user_id: user.id, items: [create_test_item()]})]}
        end]},
        {Utils.ETS, [insert: fn :users, {"testuser", _db_user} -> true end]}
      ]) do
        items = BusinessLogic.get_user_items(user)
        assert length(items) == 1
      end

      # Cache cleared, should hit database again
      with_mocks([
        {Utils.ETS, [lookup: fn :users, "testuser" -> {:error, :not_found} end]},
        {Data.Repo, [preload: fn user, [characters: :items] ->
          %{user | characters: [create_test_character(%{user_id: user.id, items: [create_test_item()]})]}
        end]},
        {Utils.ETS, [insert: fn :users, {"testuser", _db_user} -> true end]}
      ]) do
        items = BusinessLogic.get_user_items(user)
        assert length(items) == 1
      end
    end

    test "caches different users separately" do
      user1 = create_test_user(%{login: "user1"})
      user2 = create_test_user(%{login: "user2"})

      character1 = create_test_character(%{user_id: user1.id, items: [create_test_item(%{name: "Sword"})]})
      character2 = create_test_character(%{user_id: user2.id, items: [create_test_item(%{name: "Bow"})]})

      db_user1 = %{user1 | characters: [character1]}
      db_user2 = %{user2 | characters: [character2]}

      # Cache user1
      with_mocks([
        {Utils.ETS, [lookup: fn :users, "user1" -> {:error, :not_found} end]},
        {Data.Repo, [preload: fn user, [characters: :items] ->
          %{user | characters: [character1]}
        end]},
        {Utils.ETS, [insert: fn :users, {"user1", ^db_user1} -> true end]}
      ]) do
        items1 = BusinessLogic.get_user_items(user1)
        assert length(items1) == 1
        assert hd(items1).name == "Sword"
      end

      # Cache user2
      with_mocks([
        {Utils.ETS, [lookup: fn :users, "user2" -> {:error, :not_found} end]},
        {Data.Repo, [preload: fn user, [characters: :items] ->
          %{user | characters: [character2]}
        end]},
        {Utils.ETS, [insert: fn :users, {"user2", ^db_user2} -> true end]}
      ]) do
        items2 = BusinessLogic.get_user_items(user2)
        assert length(items2) == 1
        assert hd(items2).name == "Bow"
      end

      # Retrieve from cache
      with_mock Utils.ETS, [lookup: fn :users, "user1" -> {:ok, db_user1} end] do
        cached_items1 = BusinessLogic.get_user_items(user1)
        assert hd(cached_items1).name == "Sword"
      end

      with_mock Utils.ETS, [lookup: fn :users, "user2" -> {:ok, db_user2} end] do
        cached_items2 = BusinessLogic.get_user_items(user2)
        assert hd(cached_items2).name == "Bow"
      end
    end
  end
end
