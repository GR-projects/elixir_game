defmodule BusinessLogic.AuthenticationTest do
  use ExUnit.Case, async: false
  import Mock
  import BusinessLogic.TestHelpers

  describe "password hashing" do
    test "hashes password when creating user" do
      params = %{"password" => "mypassword123"}

      with_mock Data, [create_user: fn user_params ->
        # Test that password was properly hashed
        assert Map.has_key?(user_params, "password_hash")
        assert user_params["password_hash"] != "mypassword123"
        assert Bcrypt.verify_pass("mypassword123", user_params["password_hash"])

        # Test that original password is preserved
        assert user_params["password"] == "mypassword123"

        # Use test helper with atom keys
        create_test_user(%{password_hash: user_params["password_hash"]})
      end] do
        BusinessLogic.create_user(params)
      end
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
      password = "correctpassword"
      login = "testuser"
      hashed_password = Bcrypt.hash_pwd_salt(password)
      user = create_test_user(%{login: login, password_hash: hashed_password})

      with_mock Data, [get_user: fn ^login -> user end] do
        result = BusinessLogic.authenticate_user(%{"password" => password, "login" => login})
        assert result == {:ok, user}
      end
    end

    test "rejects invalid credentials" do
      login = "testuser"
      hashed_password = Bcrypt.hash_pwd_salt("correctpassword")
      user = create_test_user(%{login: login, password_hash: hashed_password})

      with_mock Data, [get_user: fn ^login -> user end] do
        result = BusinessLogic.authenticate_user(%{"password" => "wrongpassword", "login" => login})
        assert result == {:error, :authentication_failed}
      end
    end

    test "handles non-existent user" do
      with_mock Data, [get_user: fn "nonexistent" -> nil end] do
        result = BusinessLogic.authenticate_user(%{"password" => "anypassword", "login" => "nonexistent"})
        assert result == {:error, :user_not_exists}
      end
    end
  end

  describe "edge cases" do
    test "handles empty password" do
      login = "testuser"
      user = create_test_user(%{login: login, password_hash: "somehash"})

      with_mock Data, [get_user: fn ^login -> user end] do
        result = BusinessLogic.authenticate_user(%{"password" => "", "login" => login})
        assert result == {:error, :authentication_failed}
      end
    end

    test "handles nil password" do
      login = "testuser"
      user = create_test_user(%{login: login, password_hash: "somehash"})

      with_mock Data, [get_user: fn ^login -> user end] do
        result = BusinessLogic.authenticate_user(%{"password" => nil, "login" => login})
        assert result == {:error, :authentication_failed}
      end
    end

    test "handles missing password key" do
      login = "testuser"
      user = create_test_user(%{login: login, password_hash: "somehash"})

      with_mock Data, [get_user: fn ^login -> user end] do
        result = BusinessLogic.authenticate_user(%{"login" => login})
        assert result == {:error, :authentication_failed}
      end
    end
  end

  describe "input validation" do
    test "validates login parameter" do
      with_mock Data, [get_user: fn nil -> nil end] do
        result = BusinessLogic.authenticate_user(%{"password" => "password", "login" => nil})
        assert result == {:error, :user_not_exists}
      end
    end

    test "handles malformed params" do
      assert_raise FunctionClauseError, fn ->
        BusinessLogic.authenticate_user(%{"invalid" => "params"})
      end
    end
  end

  describe "bcrypt security properties" do
    test "generates different hashes for same password" do
      password = "samepassword"
      hash1 = nil
      hash2 = nil

      with_mock Data, [create_user: fn user_params1 ->
        hash1 = user_params1["password_hash"]
        assert Bcrypt.verify_pass(password, hash1)
        # Use test helper with atom keys
        create_test_user(%{password_hash: hash1})
      end] do
        {:ok, _user1} = BusinessLogic.create_user(%{"password" => password})
      end

      with_mock Data, [create_user: fn user_params2 ->
        hash2 = user_params2["password_hash"]
        assert Bcrypt.verify_pass(password, hash2)
        # Use test helper with atom keys
        create_test_user(%{password_hash: hash2})
      end] do
        {:ok, _user2} = BusinessLogic.create_user(%{"password" => password})
      end

      # Both hashes should verify the same password
      assert Bcrypt.verify_pass(password, hash1)
      assert Bcrypt.verify_pass(password, hash2)
      # But they should be different hashes (bcrypt generates different salts)
      assert hash1 != hash2
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
