defmodule KrakenStreamer.WebSocketClient do
  use WebSockex
  require Logger

  @kraken_ws_url "wss://ws.kraken.com/v2"
  # Kraken Docs: Ping should be sent at least every 60 seconds
  @ping_interval :timer.seconds(2)
  @tickers_update_interval :timer.seconds(1)
  # PUBLIC API

  def start_link(_opts \\ %{}) do
    WebSockex.start_link(@kraken_ws_url, __MODULE__, %{tickers: %{}}, name: __MODULE__)
  end

  # CALLBACKS

  def handle_connect(_conn, state) do
    Logger.info("Connected to Kraken WebSocket server")
    # Subscribe to pair updates from PairsManager
    Phoenix.PubSub.subscribe(KrakenStreamer.PubSub, "pairs:subscription")
    # Schedule a ping to keep the connection alive
    schedule_ping()
    # Schedule ticker data broadcasts to LiveView
    schedule_tickers_update()
    {:ok, state}
  end

  def handle_disconnect(%{reason: reason}, state) do
    Logger.debug("Disconnected from Kraken WebSocket server: #{inspect(reason)}")
    # Reconnect automatically
    {:reconnect, state}
  end

  def handle_info({:pairs_subscribe, pairs}, state) do
    Logger.debug("Subscribing to Kraken WebSocket server pairs: #{inspect(pairs)}")

    subscribe_message = %{
      "method" => "subscribe",
      "params" => %{
        "channel" => "ticker",
        "symbol" => pairs,
        "event_trigger" => "bbo"
      }
    }

    case Jason.encode(subscribe_message) do
      {:ok, payload} ->
        {:reply, {:text, payload}, state}

      {:error, error} ->
        Logger.error("Failed to encode subscribe message: #{inspect(error)}")
        {:ok, state}
    end
  end

  def handle_info({:pairs_unsubscribe, pairs}, state) do
    Logger.debug("Unsubscribing from Kraken WebSocket server pairs: #{inspect(pairs)}")

    unsubscribe_message = %{
      "method" => "unsubscribe",
      "params" => %{
        "channel" => "ticker",
        "symbol" => pairs
      }
    }

    case Jason.encode(unsubscribe_message) do
      {:ok, payload} ->
        {:reply, {:text, payload}, state}

      {:error, error} ->
        Logger.error("Failed to encode unsubscribe message: #{inspect(error)}")
        {:ok, state}
    end
  end

  def handle_info(:ping, state) do
    ping_msg = %{
      "method" => "ping"
    }

    case Jason.encode(ping_msg) do
      {:ok, payload} ->
        # Schedule next ping
        schedule_ping()
        # Send the ping
        Logger.debug("Sending ping")
        {:reply, {:text, payload}, state}

      {:error, error} ->
        Logger.error("Failed to encode ping message: #{inspect(error)}")
        # Schedule next ping even on error
        schedule_ping()
        {:ok, state}
    end
  end

  # Broadcasts current ticker data to LiveView components via PubSub.
  def handle_info(:tickers_update, state) do
    # Broadcast current ticker data to the LiveView
    Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", state.tickers)
    # Schedule the next update
    schedule_tickers_update()
    # Return the state unchanged
    {:ok, state}
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      # Handle pong messages
      {:ok, %{"method" => "pong", "time_in" => _time_in, "time_out" => _time_out}} ->
        Logger.debug("Pong received")
        {:ok, state}

      # Handle successful subscription messages
      {:ok,
       %{
         "method" => "subscribe",
         "result" => %{"channel" => "ticker", "symbol" => symbol},
         "success" => true
       }} ->
        Logger.info("Successfully subscribed to #{symbol} pair")
        {:ok, state}

      # Handle failed subscription messages
      {:ok,
       %{
         "method" => "subscribe",
         "result" => %{"channel" => "ticker", "symbol" => symbol},
         "success" => false
       }} ->
        Logger.warning("Failed to subscribe to #{symbol} pair")
        {:ok, state}

      # Handle successful unsubscription messages
      {:ok,
       %{
         "method" => "unsubscribe",
         "result" => %{"channel" => "ticker", "symbol" => symbol},
         "success" => true
       }} ->
        Logger.info("Successfully unsubscribed from #{symbol} pair")
        {:ok, state}

      # Handle failed unsubscription messages
      {:ok,
       %{
         "method" => "unsubscribe",
         "result" => %{"channel" => "ticker", "symbol" => symbol},
         "success" => false
       }} ->
        Logger.warning("Failed to unsubscribe from #{symbol} pair")
        {:ok, state}

      # Handle ticker messages
      {:ok, %{"channel" => "ticker", "type" => _type, "data" => [ticker | _]}} ->
        #Logger.debug("Received ticker message: #{inspect(ticker)}")
        symbol = ticker["symbol"]
        ask = ticker["ask"]
        bid = ticker["bid"]
        state = %{state | tickers: Map.put(state.tickers, symbol, %{ask: ask, bid: bid})}
        {:ok, state}

      # Handle other messages of :text type
      {:ok, other_message} ->
        Logger.debug("Received other WebSocket message: #{inspect(other_message)}")
        {:ok, state}

      # Handle errors
      {:error, error} ->
        Logger.error("Failed to decode WebSocket message: #{inspect(error)}")
        {:ok, state}
      end
  end

  # Handle other types of frames
  def handle_frame(frame, state) do
    Logger.debug("Received other frame: #{inspect(frame)}")
    {:ok, state}
  end

  # PRIVATE FUNCTIONS

  defp schedule_ping do
    Process.send_after(self(), :ping, @ping_interval)
  end

  defp schedule_tickers_update do
    Process.send_after(self(), :tickers_update, @tickers_update_interval)
  end
end
