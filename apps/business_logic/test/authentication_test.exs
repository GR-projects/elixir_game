defmodule BusinessLogic.AuthenticationTest do
  use BusinessLogic.Test.Support.DataCase, async: false

  # Setup and teardown for each test
  setup do
    # Clean up ETS tables before each test
    Utils.ETS.clear(:users)

    :ok
  end

  describe "password hashing" do
    test "hashes password when creating user" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser_hash", "password" => "mypassword123"}
      {:ok, user} = BusinessLogic.create_user(params)

      # Test that password was properly hashed
      assert user.password_hash != "mypassword123"
      assert Bcrypt.verify_pass("mypassword123", user.password_hash)
    end

    test "verifies password correctly" do
      password = "correctpassword"
      hashed_password = Bcrypt.hash_pwd_salt(password)

      assert Bcrypt.verify_pass(password, hashed_password) == true
      assert Bcrypt.verify_pass("wrongpassword", hashed_password) == false
    end
  end

  describe "user authentication" do
    test "authenticates valid credentials" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser1", "password" => "correctpassword"}
      {:ok, user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "correctpassword", "login" => "testuser1"})
      assert result == {:ok, user}
    end

    test "rejects invalid credentials" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser2", "password" => "correctpassword"}
      {:ok, _user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "wrongpassword", "login" => "testuser2"})
      assert result == {:error, :authentication_failed}
    end

    test "handles non-existent user" do
      result = BusinessLogic.authenticate_user(%{"password" => "anypassword", "login" => "nonexistent"})
      assert result == {:error, :user_not_exists}
    end
  end

  describe "edge cases" do
    test "handles empty password" do
      params = %{"name" => "Test User", "email" => "test@example.com", "login" => "testuser3", "password" => "password123"}
      {:ok, _user} = BusinessLogic.create_user(params)

      result = BusinessLogic.authenticate_user(%{"password" => "", "login" => "testuser3"})
      assert result == {:error, :authentication_failed}
    end
  end

  describe "bcrypt security properties" do
    test "generates different hashes for same password" do
      password = "samepassword"
      params1 = %{"name" => "Test User 1", "email" => "test1@example.com", "login" => "testuser_hash1", "password" => password}
      params2 = %{"name" => "Test User 2", "email" => "test2@example.com", "login" => "testuser_hash2", "password" => password}

      {:ok, user1} = BusinessLogic.create_user(params1)
      {:ok, user2} = BusinessLogic.create_user(params2)

      # Both hashes should verify the same password
      assert Bcrypt.verify_pass(password, user1.password_hash)
      assert Bcrypt.verify_pass(password, user2.password_hash)
      # But they should be different hashes (bcrypt generates different salts)
      assert user1.password_hash != user2.password_hash
    end

    test "verifies password with different hash instances" do
      password = "testpassword"
      hash1 = Bcrypt.hash_pwd_salt(password)
      hash2 = Bcrypt.hash_pwd_salt(password)

      # Both hashes should verify the same password
      assert Bcrypt.verify_pass(password, hash1) == true
      assert Bcrypt.verify_pass(password, hash2) == true
      # But they should be different hashes
      assert hash1 != hash2
    end
  end
end
