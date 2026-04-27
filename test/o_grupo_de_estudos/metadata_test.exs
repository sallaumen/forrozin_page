defmodule OGrupoDeEstudos.MetadataTest do
  use OGrupoDeEstudos.DataCase, async: true

  alias OGrupoDeEstudos.Metadata

  describe "get/3 and set/3" do
    test "returns nil when key does not exist" do
      assert Metadata.get("test_key", "user", "nonexistent") == nil
    end

    test "sets and gets a value" do
      {:ok, _} = Metadata.set("test_key", "user", "abc-123", "hello")
      assert Metadata.get("test_key", "user", "abc-123") == "hello"
    end

    test "overwrites existing value" do
      {:ok, _} = Metadata.set("test_key", "user", "abc-123", "first")
      {:ok, _} = Metadata.set("test_key", "user", "abc-123", "second")
      assert Metadata.get("test_key", "user", "abc-123") == "second"
    end

    test "different keys are independent" do
      {:ok, _} = Metadata.set("key_a", "user", "id-1", "value_a")
      {:ok, _} = Metadata.set("key_b", "user", "id-1", "value_b")
      assert Metadata.get("key_a", "user", "id-1") == "value_a"
      assert Metadata.get("key_b", "user", "id-1") == "value_b"
    end
  end

  describe "get_integer/3" do
    test "returns 0 when key does not exist" do
      assert Metadata.get_integer("counter", "user", "missing") == 0
    end

    test "returns integer value" do
      {:ok, _} = Metadata.set("counter", "user", "id-1", "42")
      assert Metadata.get_integer("counter", "user", "id-1") == 42
    end
  end

  describe "increment/3" do
    test "creates with value 1 when key does not exist" do
      {:ok, val} = Metadata.increment("counter", "user", "new-id")
      assert val == 1
    end

    test "increments existing value atomically" do
      {:ok, 1} = Metadata.increment("counter", "user", "inc-id")
      {:ok, 2} = Metadata.increment("counter", "user", "inc-id")
      {:ok, 3} = Metadata.increment("counter", "user", "inc-id")
      assert Metadata.get_integer("counter", "user", "inc-id") == 3
    end

    test "does not affect other keys" do
      {:ok, _} = Metadata.increment("counter_a", "user", "id-1")
      {:ok, _} = Metadata.increment("counter_a", "user", "id-1")
      {:ok, _} = Metadata.increment("counter_b", "user", "id-1")

      assert Metadata.get_integer("counter_a", "user", "id-1") == 2
      assert Metadata.get_integer("counter_b", "user", "id-1") == 1
    end
  end

  describe "password_reset_count_name/0" do
    test "returns the registered name" do
      assert Metadata.password_reset_count_name() == "password_reset_count"
    end
  end
end
