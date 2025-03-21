defmodule KrakenStreamer.WebSocket.ClientTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureLog
  alias KrakenStreamer.WebSocket.Client

  setup do
    # Subscribe to PubSub topics we want to test
    Phoenix.PubSub.subscribe(KrakenStreamer.PubSub, "tickers")

    Logger.configure(level: :debug)
    # Initial test state
    test_state = %{tickers: %{}}
    # Generate unique name for each test
    test_name = :"Client#{System.unique_integer()}"

    {:ok, state: test_state, test_name: test_name}
  end

  describe "initialization and connection" do
    test "starts with empty tickers map", %{test_name: test_name} do
      {:ok, pid} = Client.start_link(%{name: test_name})
      assert :sys.get_state(pid) == %{tickers: %{}}
    end

    test "handles connection successfully", %{state: state} do
      log =
        capture_log(fn ->
          assert {:ok, ^state} = Client.handle_connect(%{}, state)
        end)

      assert log =~ "Connected to Kraken WebSocket server"
    end

    test "handles disconnection by attempting to reconnect", %{state: state} do
      log =
        capture_log(fn ->
          assert {:reconnect, ^state} =
                   Client.handle_disconnect(%{reason: "test disconnect"}, state)
        end)

      assert log =~ "Disconnected from Kraken WebSocket server"
    end
  end

  describe "subscription handling" do
    test "handles pair subscription request", %{state: state} do
      pairs = ["BTC/USD", "ETH/USD"]

      log =
        capture_log(fn ->
          assert {:reply, {:text, payload}, ^state} =
                   Client.handle_info({:pairs_subscribe, pairs}, state)

          decoded = Jason.decode!(payload)
          assert decoded["method"] == "subscribe"
          assert decoded["params"]["channel"] == "ticker"
          assert decoded["params"]["symbol"] == pairs
        end)

      assert log =~ "Subscribing to Kraken WebSocket server pairs"
    end

    test "handles pair unsubscription request", %{state: state} do
      pairs = ["BTC/USD", "ETH/USD"]

      log =
        capture_log(fn ->
          assert {:reply, {:text, payload}, ^state} =
                   Client.handle_info({:pairs_unsubscribe, pairs}, state)

          decoded = Jason.decode!(payload)
          assert decoded["method"] == "unsubscribe"
          assert decoded["params"]["channel"] == "ticker"
          assert decoded["params"]["symbol"] == pairs
        end)

      assert log =~ "Unsubscribing from Kraken WebSocket server pairs"
    end
  end

  describe "ping/pong handling" do
    test "sends ping message and schedules next ping", %{state: state} do
      log =
        capture_log(fn ->
          assert {:reply, {:text, payload}, ^state} = Client.handle_info(:ping, state)
          decoded = Jason.decode!(payload)
          assert decoded["method"] == "ping"
        end)

      assert log =~ "Sending ping"
    end
  end

  describe "ticker updates" do
    test "broadcasts formatted ticker updates", %{state: state} do
      state_with_tickers = %{
        state
        | tickers: %{
            "BTC/USD" => %{ask: 50000.0, bid: 49900.0},
            "ETH/USD" => %{ask: 2000.0, bid: 1990.0}
          }
      }

      # Trigger a ticker update
      Client.handle_info(:tickers_update, state_with_tickers)

      # Verify the broadcast
      assert_receive formatted_tickers
      assert formatted_tickers["BTC/USD"]
      assert formatted_tickers["ETH/USD"]
      assert formatted_tickers["BTC/USD"].ask == "50000.00"
      assert formatted_tickers["BTC/USD"].bid == "49900.00"
    end

    test "processes ticker WebSocket messages", %{state: state} do
      message = %{
        "channel" => "ticker",
        "type" => "update",
        "data" => [
          %{
            "symbol" => "BTC/USD",
            "ask" => "50000.00",
            "bid" => "49900.00"
          }
        ]
      }

      {:ok, new_state} = Client.handle_frame({:text, Jason.encode!(message)}, state)
      assert new_state.tickers["BTC/USD"]
      assert new_state.tickers["BTC/USD"].ask == "50000.00"
      assert new_state.tickers["BTC/USD"].bid == "49900.00"
    end
  end
end
