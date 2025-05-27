defmodule Utils.ETS do
  use GenServer

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Create a new ETS table with given name and options
  def create_table(table_name, opts \\ [:named_table, :set, :public]) do
    GenServer.call(__MODULE__, {:create_table, table_name, opts})
  end

  # Insert a tuple into a specific ETS table
  def insert(table_name, tuple) do
    GenServer.call(__MODULE__, {:insert, table_name, tuple})
  end

  # Lookup key in a specific ETS table
  def lookup(table_name, key) do
    GenServer.call(__MODULE__, {:lookup, table_name, key})
  end

  # Delete a key from a specific ETS table
  def delete(table_name, key) do
    GenServer.call(__MODULE__, {:delete, table_name, key})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # State: Map of table_name => ets_table_ref
    tables = Application.get_env(:utils, Utils.ETS)[:tables]
    state = Enum.reduce(tables, %{}, fn table_name, acc ->
      tid = :ets.new(table_name, [:named_table, :set, :public])
      Map.put(acc, table_name, tid)
    end)
    {:ok, state}
  end

  @impl true
  def handle_call({:create_table, table_name, opts}, _from, state) do
    case Map.get(state, table_name) do
      nil ->
        tid = :ets.new(table_name, opts)
        {:reply, {:ok, tid}, Map.put(state, table_name, tid)}
      _ ->
        {:reply, {:error, :table_already_exists}, state}
    end
  end

  def handle_call({:insert, table_name, tuple}, _from, state) do
    case Map.fetch(state, table_name) do
      {:ok, tid} ->
        :ets.insert(tid, tuple)
        {:reply, :ok, state}

      :error ->
        {:reply, {:error, :table_not_found}, state}
    end
  end

  def handle_call({:lookup, table_name, key}, _from, state) do
    result =
      case Map.fetch(state, table_name) do
        {:ok, tid} ->
          case :ets.lookup(tid, key) do
            [{_key, value}] ->
              {:ok, value}
            [] ->
              {:error, :not_found}
          end
        :error ->
          {:error, :table_not_found}
      end

    {:reply, result, state}
  end

  def handle_call({:delete, table_name, key}, _from, state) do
    result = case Map.fetch(state, table_name) do
      {:ok, tid} ->
        :ets.delete(tid, key)
        :ok

      :error ->
        {:error, :table_not_found}
    end

    {:reply, result, state}
  end
end
