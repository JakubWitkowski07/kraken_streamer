defmodule KrakenStreamer.Pairs.SubscriptionTest do
  use ExUnit.Case, async: true

  alias KrakenStreamer.Pairs.Subscription

  setup do
    # start_supervised!({Phoenix.PubSub, name: KrakenStreamer.PubSub})
    test_batches = [
      {["BTC/USD", "ETH/USD"], 0},
      {["DOT/USD", "ADA/USD"], 1}
    ]

    # Subscribe to test topic
    Phoenix.PubSub.subscribe(KrakenStreamer.PubSub, "pairs:subscriptiontest")

    {:ok, %{test_batches: test_batches}}
  end

  describe "subscribe_batches/2" do
    test "handles single batch subscription" do
      single_batch = [{["BTC/USD"], 0}]
      result = Subscription.subscribe_batches(single_batch, "pairs:subscriptiontest")

      assert result == :ok
      assert_received {:pairs_subscribe, ["BTC/USD"]}
      refute_received {:pairs_subscribe, _}, 100
    end

    test "subscribes to the batches", %{test_batches: test_batches} do
      result = Subscription.subscribe_batches(test_batches, "pairs:subscriptiontest")
      assert result == :ok
      assert_received {:pairs_subscribe, ["BTC/USD", "ETH/USD"]}
      assert_received {:pairs_subscribe, ["DOT/USD", "ADA/USD"]}
    end

    test "handles empty batch list" do
      Phoenix.PubSub.subscribe(KrakenStreamer.PubSub, "pairs:subscriptiontest")

      result = Subscription.subscribe_batches([], "pairs:subscriptiontest")

      assert result == {:error, :invalid_batches}
      refute_received _, 100
    end
  end

  describe "unsubscribe_batches/2" do
    test "handles single batch subscription" do
      single_batch = [{["BTC/USD"], 0}]
      result = Subscription.unsubscribe_batches(single_batch, "pairs:subscriptiontest")

      assert result == :ok
      assert_received {:pairs_unsubscribe, ["BTC/USD"]}
      refute_received {:pairs_unsubscribe, _}, 100
    end

    test "unsubscribes to the batches", %{test_batches: test_batches} do
      result = Subscription.unsubscribe_batches(test_batches, "pairs:subscriptiontest")
      assert result == :ok
      assert_received {:pairs_unsubscribe, ["BTC/USD", "ETH/USD"]}
      assert_received {:pairs_unsubscribe, ["DOT/USD", "ADA/USD"]}
    end

    test "handles empty batch list" do
      Phoenix.PubSub.unsubscribe(KrakenStreamer.PubSub, "pairs:subscriptiontest")

      result = Subscription.unsubscribe_batches([], "pairs:subscriptiontest")

      assert result == {:error, :invalid_batches}
      refute_received _, 100
    end
  end
end
