defmodule BusinessLogic.TestHelpers do
  @moduledoc """
  Helper functions for testing business logic.
  """

  def create_test_user(attrs \\ %{}) do
    %{
      id: attrs[:id] || Faker.random_between(1, 1000),
      name: attrs[:name] || Faker.Person.name(),
      email: attrs[:email] || Faker.Internet.email(),
      login: attrs[:login] || Faker.Internet.user_name(),
      password_hash: Bcrypt.hash_pwd_salt(attrs[:password]) || Bcrypt.hash_pwd_salt("password123")
    }
  end

  def create_test_character(attrs \\ %{}) do
    %{
      id: attrs[:id] || Faker.random_between(1, 1000),
      name: attrs[:name] || Faker.Person.name(),
      type: attrs[:type] || "warrior",
      level: attrs[:level] || 1,
      experience: attrs[:experience] || 0.0,
      user_id: attrs[:user_id] || Faker.random_between(1, 1000),
      items: attrs[:items] || []
    }
  end

  def create_test_item(attrs \\ %{}) do
    %{
      id: attrs[:id] || Faker.random_between(1, 1000),
      name: attrs[:name] || "Sword",
      character_id: attrs[:character_id] || Faker.random_between(1, 1000)
    }
  end
end
