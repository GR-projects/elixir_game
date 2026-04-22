defmodule Runtime do
  def get_env(key, default \\ nil) do
    case System.get_env(key) do
      nil when default != nil -> default
      nil -> raise("Environment variable #{key} not set")
      value -> value
    end
  end
end
