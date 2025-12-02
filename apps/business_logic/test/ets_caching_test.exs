defmodule BusinessLogic.ETSCachingTest do
  use ExUnit.Case, async: false

  describe "ETS module operations" do
    setup do
      table_name = :test_table
      :ets.new(table_name, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

      on_exit(fn ->
        if :ets.info(table_name) != :undefined do
          :ets.delete(table_name)
        end
      end)

      %{table_name: table_name}
    end

    test "init/1 creates ETS tables with specified names" do
      test_tables = [:test_init_table1, :test_init_table2]
      Utils.ETS.init(test_tables)

      # Verify tables were created by trying to insert
      assert true == Utils.ETS.insert(:test_init_table1, {:key1, "value1"})
      assert true == Utils.ETS.insert(:test_init_table2, {:key2, "value2"})

      # Cleanup
      :ets.delete(:test_init_table1)
      :ets.delete(:test_init_table2)
    end

    test "insert/2 stores a tuple in ETS table", %{table_name: table_name} do
      tuple = {"key1", "value1"}
      result = Utils.ETS.insert(table_name, tuple)
      assert result == true

      # Verify the tuple was stored
      assert [{"key1", "value1"}] = :ets.lookup(table_name, "key1")
    end

    test "lookup/2 returns {:ok, value} when key exists", %{table_name: table_name} do
      Utils.ETS.insert(table_name, {"test_key", "test_value"})

      result = Utils.ETS.lookup(table_name, "test_key")
      assert result == {:ok, "test_value"}
    end

    test "lookup/2 returns {:error, :not_found} when key does not exist", %{table_name: table_name} do
      result = Utils.ETS.lookup(table_name, "nonexistent_key")
      assert result == {:error, :not_found}
    end

    test "delete/2 removes a key from ETS table", %{table_name: table_name} do
      Utils.ETS.insert(table_name, {"key_to_delete", "value"})
      assert {:ok, "value"} = Utils.ETS.lookup(table_name, "key_to_delete")

      result = Utils.ETS.delete(table_name, "key_to_delete")
      assert result == true

      # Verify the key was deleted
      assert {:error, :not_found} = Utils.ETS.lookup(table_name, "key_to_delete")
    end

    test "clear/1 removes all entries from ETS table", %{table_name: table_name} do
      Utils.ETS.insert(table_name, {"key1", "value1"})
      Utils.ETS.insert(table_name, {"key2", "value2"})
      Utils.ETS.insert(table_name, {"key3", "value3"})

      # Verify all keys exist
      assert {:ok, "value1"} = Utils.ETS.lookup(table_name, "key1")
      assert {:ok, "value2"} = Utils.ETS.lookup(table_name, "key2")
      assert {:ok, "value3"} = Utils.ETS.lookup(table_name, "key3")

      result = Utils.ETS.clear(table_name)
      assert result == true

      # Verify all keys were cleared
      assert {:error, :not_found} = Utils.ETS.lookup(table_name, "key1")
      assert {:error, :not_found} = Utils.ETS.lookup(table_name, "key2")
      assert {:error, :not_found} = Utils.ETS.lookup(table_name, "key3")
    end

    test "insert/2 overwrites existing key with new value", %{table_name: table_name} do
      Utils.ETS.insert(table_name, {"same_key", "old_value"})
      assert {:ok, "old_value"} = Utils.ETS.lookup(table_name, "same_key")

      Utils.ETS.insert(table_name, {"same_key", "new_value"})
      assert {:ok, "new_value"} = Utils.ETS.lookup(table_name, "same_key")
    end

    test "multiple keys can coexist in the same table", %{table_name: table_name} do
      Utils.ETS.insert(table_name, {"key1", "value1"})
      Utils.ETS.insert(table_name, {"key2", "value2"})
      Utils.ETS.insert(table_name, {"key3", "value3"})

      assert {:ok, "value1"} = Utils.ETS.lookup(table_name, "key1")
      assert {:ok, "value2"} = Utils.ETS.lookup(table_name, "key2")
      assert {:ok, "value3"} = Utils.ETS.lookup(table_name, "key3")
    end

    test "lookup/2 works with complex data structures", %{table_name: table_name} do
      complex_value = %{
        id: 1,
        name: "Test",
        nested: %{deep: "value"},
        list: [1, 2, 3]
      }
      Utils.ETS.insert(table_name, {"complex_key", complex_value})

      result = Utils.ETS.lookup(table_name, "complex_key")
      assert {:ok, ^complex_value} = result
      assert result == {:ok, %{id: 1, name: "Test", nested: %{deep: "value"}, list: [1, 2, 3]}}
    end
  end
end
