defmodule KrakenStreamer.WebSocket.MessageHandlerTest do
  use ExUnit.Case, async: true
  alias KrakenStreamer.WebSocket.MessageHandler

  import ExUnit.CaptureLog

  setup do
    # Configure logger to capture debug messages
    Logger.configure(level: :debug)
    # Initial state with empty tickers map
    state = %{tickers: %{}}
    {:ok, state: state}
  end

  describe "handle_frame/2 with text frames" do
    test "handles valid JSON messages", %{state: state} do
      message = Jason.encode!(%{"method" => "pong"})

      assert capture_log([level: :debug], fn ->
               assert {:ok, ^state} = MessageHandler.handle_frame({:text, message}, state)
             end) =~ "Received pong"
    end

    test "handles invalid JSON", %{state: state} do
      assert capture_log([level: :error], fn ->
               assert {:ok, ^state} = MessageHandler.handle_frame({:text, "invalid json"}, state)
             end) =~ "Failed to decode WebSocket message"
    end
  end

  describe "handle_frame/2 with close frames" do
    test "handles close frame", %{state: state} do
      assert capture_log([level: :warning], fn ->
               assert {:ok, ^state} =
                        MessageHandler.handle_frame({:close, 1000, "normal closure"}, state)
             end) =~ "Received close frame with code 1000: normal closure"
    end
  end

  describe "handle_frame/2 with unexpected frames" do
    test "handles unexpected frame type", %{state: state} do
      assert capture_log([level: :warning], fn ->
               assert {:ok, ^state} = MessageHandler.handle_frame({:unexpected, "data"}, state)
             end) =~ "Received unexpected frame type"
    end
  end

  describe "handle_message/2 subscription messages" do
    test "handles successful subscription", %{state: state} do
      message = %{
        "method" => "subscribe",
        "result" => %{"channel" => "ticker", "symbol" => "BTC/USD"},
        "success" => true
      }

      assert capture_log([level: :info], fn ->
               assert {:ok, ^state} =
                        MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
             end) =~ "Successfully subscribed to BTC/USD pair"
    end

    test "handles failed subscription", %{state: state} do
      message = %{
        "method" => "subscribe",
        "result" => %{"channel" => "ticker", "symbol" => "BTC/USD"},
        "success" => false
      }

      assert capture_log([level: :warning], fn ->
               assert {:ok, ^state} =
                        MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
             end) =~ "Failed to subscribe to BTC/USD pair"
    end
  end

  describe "handle_message/2 unsubscription messages" do
    test "handles successful unsubscription", %{state: state} do
      message = %{
        "method" => "unsubscribe",
        "result" => %{"channel" => "ticker", "symbol" => "BTC/USD"},
        "success" => true
      }

      assert capture_log([level: :info], fn ->
               assert {:ok, ^state} =
                        MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
             end) =~ "Successfully unsubscribed from BTC/USD pair"
    end

    test "handles failed unsubscription", %{state: state} do
      message = %{
        "method" => "unsubscribe",
        "result" => %{"channel" => "ticker", "symbol" => "BTC/USD"},
        "success" => false
      }

      assert capture_log([level: :warning], fn ->
               assert {:ok, ^state} =
                        MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
             end) =~ "Failed to unsubscribe from BTC/USD pair"
    end
  end

  describe "handle_message/2 ticker messages" do
    test "updates state with new ticker data", %{state: state} do
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

      assert {:ok, new_state} =
               MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)

      assert new_state.tickers["BTC/USD"] == %{
               ask: "50000.00",
               bid: "49900.00"
             }
    end

    test "handles multiple ticker updates", %{state: state} do
      # First update
      message1 = %{
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

      {:ok, state_after_first} =
        MessageHandler.handle_frame({:text, Jason.encode!(message1)}, state)

      # Second update
      message2 = %{
        "channel" => "ticker",
        "type" => "update",
        "data" => [
          %{
            "symbol" => "ETH/USD",
            "ask" => "2000.00",
            "bid" => "1990.00"
          }
        ]
      }

      {:ok, final_state} =
        MessageHandler.handle_frame({:text, Jason.encode!(message2)}, state_after_first)

      assert final_state.tickers["BTC/USD"] == %{ask: "50000.00", bid: "49900.00"}
      assert final_state.tickers["ETH/USD"] == %{ask: "2000.00", bid: "1990.00"}
    end
  end

  describe "handle_message/2 system messages" do
    test "handles heartbeat message", %{state: state} do
      message = %{"channel" => "heartbeat"}

      assert {:ok, ^state} = MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
    end

    test "handles status message", %{state: state} do
      message = %{"channel" => "status"}

      assert {:ok, ^state} = MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
    end

    test "handles unrecognized message type", %{state: state} do
      message = %{"channel" => "unknown", "data" => "test"}

      assert capture_log([level: :debug], fn ->
               assert {:ok, ^state} =
                        MessageHandler.handle_frame({:text, Jason.encode!(message)}, state)
             end) =~ "Received unhandled message type"
    end
  end
end
