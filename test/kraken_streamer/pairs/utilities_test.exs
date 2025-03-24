defmodule KrakenStreamer.Pairs.UtilitiesTest do
  use ExUnit.Case, async: true

  alias KrakenStreamer.Pairs.Utilities

  describe "batch_pairs/1" do
    test "batches pairs into groups of correct size" do
      pairs = MapSet.new(["BTC/USD", "ETH/USD", "DOGE/USD"])
      batched_set = Utilities.batch_pairs(pairs)
      [{batched_pairs, _}] = batched_set

      assert length(batched_set) == 1
      assert pairs == MapSet.new(batched_pairs)
    end

    test "handles empty pair set" do
      pairs = MapSet.new([])
      assert Utilities.batch_pairs(pairs) == []
    end

    test "creates multiple batches when exceeding batch size" do
      # Create more pairs than @batch_size
      pairs = MapSet.new(for i <- 1..300, do: "PAIR#{i}/USD")
      batched = Utilities.batch_pairs(pairs)

      assert length(batched) == 2
      # First batch full
      assert length(elem(List.first(batched), 0)) == 250
      # Second batch partial
      assert length(elem(List.last(batched), 0)) == 50
    end
  end

  describe "normalize_pair/1" do
    test "normalizes XBT to BTC" do
      assert Utilities.normalize_pair("XBT/USD") == "BTC/USD"
    end

    test "normalizes XDG to DOGE" do
      assert Utilities.normalize_pair("XDG/USD") == "DOGE/USD"
    end

    test "leaves normal pairs unchanged" do
      assert Utilities.normalize_pair("ETH/USD") == "ETH/USD"
    end

    test "handles invalid pair format" do
      assert Utilities.normalize_pair("INVALID") == "INVALID"
    end
  end

  describe "normalize_symbol/1" do
    test "normalizes XBT to BTC" do
      assert Utilities.normalize_symbol("XBT") == "BTC"
    end

    test "normalizes XDG to DOGE" do
      assert Utilities.normalize_symbol("XDG") == "DOGE"
    end

    test "leaves other symbols unchanged" do
      assert Utilities.normalize_symbol("ETH") == "ETH"
    end
  end

  describe "normalize_pairs/1" do
    test "normalizes multiple pairs" do
      pairs = ["XBT/USD", "XDG/EUR", "ETH/USD"]
      normalized = Utilities.normalize_pairs(pairs)

      assert "BTC/USD" in normalized
      assert "DOGE/EUR" in normalized
      assert "ETH/USD" in normalized
    end

    test "handles empty list" do
      assert Utilities.normalize_pairs([]) == []
    end
  end

  describe "compare_pair_sets/2" do
    test "detects no changes" do
      pairs = MapSet.new(["BTC/USD", "ETH/USD"])
      assert Utilities.compare_pair_sets(pairs, pairs) == {:ok, :no_changes}
    end

    test "detects changes with different pairs" do
      old_pairs = MapSet.new(["BTC/USD", "ETH/USD"])
      new_pairs = MapSet.new(["BTC/USD", "DOGE/USD"])
      assert Utilities.compare_pair_sets(old_pairs, new_pairs) == {:ok, :changes}
    end

    test "detects changes with subset" do
      old_pairs = MapSet.new(["BTC/USD", "ETH/USD"])
      new_pairs = MapSet.new(["BTC/USD"])
      assert Utilities.compare_pair_sets(old_pairs, new_pairs) == {:ok, :changes}
    end

    test "detects changes with superset" do
      old_pairs = MapSet.new(["BTC/USD"])
      new_pairs = MapSet.new(["BTC/USD", "ETH/USD"])
      assert Utilities.compare_pair_sets(old_pairs, new_pairs) == {:ok, :changes}
    end

    test "handles empty sets" do
      empty_set = MapSet.new([])
      assert Utilities.compare_pair_sets(empty_set, empty_set) == {:ok, :no_changes}
    end
  end
end
