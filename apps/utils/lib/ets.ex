defmodule Utils.ETS do
  @moduledoc """
  Utility module for ETS (Erlang Term Storage) operations.
  Provides a simplified interface for common ETS operations.
  """

  @doc """
  Initializes ETS tables based on configuration.
  Creates named, public tables with read and write concurrency enabled.
  """
  @spec init([atom()] | nil) :: :ok
  def init(tables \\ nil) do
    tables = tables || Application.get_env(:utils, Utils.ETS)[:tables] || []
    |> dbg()
    Enum.each(tables, fn table_name ->
      :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])
    end)
  end

  @doc """
  Inserts a tuple into the specified ETS table.
  """
  @spec insert(atom(), tuple()) :: true
  def insert(table_name, tuple) do
    :ets.insert(table_name, tuple)
  end

  @doc """
  Looks up a key in the specified ETS table.
  Returns {:ok, value} if found, {:error, :not_found} otherwise.
  """
  @spec lookup(atom(), term()) :: {:ok, term()} | {:error, :not_found}
  def lookup(table_name, key) do
    case :ets.lookup(table_name, key) do
      [{_key, value}] ->
        {:ok, value}
      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Deletes a key from the specified ETS table.
  """
  @spec delete(atom(), term()) :: true
  def delete(table_name, key) do
    :ets.delete(table_name, key)
  end
end
