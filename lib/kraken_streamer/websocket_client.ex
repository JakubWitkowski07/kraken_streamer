defmodule KrakenStreamer.WebSocketClient do
  @moduledoc """
  WebSocket client for connecting to Kraken's real-time cryptocurrency market data API.

  This module is responsible for:
  - Establishing and maintaining a WebSocket connection to Kraken's v2 WebSocket API
  - Subscribing to ticker data for specified cryptocurrency pairs
  - Processing incoming ticker updates and maintaining current state
  - Broadcasting ticker updates to LiveView components via Phoenix.PubSub
  - Implementing connection keep-alive with periodic pings

  ## PubSub Topics

  * Subscribes to: `"pairs:subscription"` - For receiving subscription commands:
    - `{:pairs_subscribe, pairs}` - Request to subscribe to a batch of pairs
    - `{:pairs_unsubscribe, pairs}` - Request to unsubscribe from a batch of pairs

  * Broadcasts to: `"tickers"` - Sends the latest ticker data as a map:
    - Format: `%{"BTC/USD" => %{ask: 50000.0, bid: 49900.0}, ...}`

  ## Ticker Data

  For each trading pair, the client stores the latest ask and bid prices.
  This data is automatically broadcast at regular intervals (#{1} second).

  The client automatically reconnects on disconnection and maintains subscriptions.
  """
  use WebSockex
  require Logger

  @kraken_ws_url "wss://ws.kraken.com/v2"
  # Kraken Docs: Ping should be sent at least every 60 seconds
  @ping_interval :timer.seconds(30)
  @tickers_update_interval :timer.seconds(1)

  @typedoc """
  Ticker data structure containing ask and bid prices
  """
  @type ticker :: %{
          ask: float(),
          bid: float()
        }

  @typedoc """
  Client state containing the map of all current tickers
  """
  @type state :: %{
          tickers: %{String.t() => ticker()}
        }

  # PUBLIC API

  @doc """
  Starts the WebSocket client and connects to Kraken's WebSocket API.

  Initializes an empty tickers map and establishes the WebSocket connection.

  ## Parameters

  - `opts`: Optional map of configuration options (not currently used)

  ## Returns

  - `{:ok, pid}` - Successfully started the WebSocket client
  - `{:error, term()}` - Failed to start the client
  """
  @spec start_link(map()) :: {:ok, pid()} | {:error, term()}
  def start_link(_opts \\ %{}) do
    WebSockex.start_link(@kraken_ws_url, __MODULE__, %{tickers: %{}}, name: __MODULE__)
  end

  # CALLBACKS

  @doc """
  Handles the successful WebSocket connection event.

  On connection:
  1. Subscribes to pair updates from PairsManager
  2. Schedules periodic pings to keep the connection alive
  3. Schedules ticker data broadcasts to LiveViews

  ## Parameters

  - `conn`: Connection information (unused)
  - `state`: Current client state

  ## Returns

  - `{:ok, state}` - Connection handled successfully
  """
  @spec handle_connect(map(), state()) :: {:ok, state()}
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

  @doc """
  Handles WebSocket disconnection events.

  Automatically attempts to reconnect when the connection is lost.

  ## Parameters

  - `disconnect_map`: Map containing the disconnect reason
  - `state`: Current client state

  ## Returns

  - `{:reconnect, state}` - Will attempt to reconnect with current state
  """
  @spec handle_disconnect(map(), state()) :: {:reconnect, state()}
  def handle_disconnect(%{reason: reason}, state) do
    Logger.debug("Disconnected from Kraken WebSocket server: #{inspect(reason)}")
    # Reconnect automatically
    {:reconnect, state}
  end

  # Handles pair subscription messages from PubSub.
  # Creates and sends a subscription request to the Kraken API.
  @spec handle_info({:pairs_subscribe, [String.t()]}, state()) ::
          {:reply, {:text, String.t()}, state()} | {:ok, state()}
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

  # Handles pair unsubscription messages from PubSub.
  # Creates and sends an unsubscription request to the Kraken API.
  @spec handle_info({:pairs_unsubscribe, [String.t()]}, state()) ::
          {:reply, {:text, String.t()}, state()} | {:ok, state()}
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

  # Sends a ping message to the Kraken API to keep the connection alive.
  # Automatically schedules the next ping.
  @spec handle_info(:ping, state()) ::
          {:reply, {:text, String.t()}, state()} | {:ok, state()}
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
  # Automatically schedules the next update.
  @spec handle_info(:tickers_update, state()) :: {:ok, state()}
  def handle_info(:tickers_update, state) do
    # Broadcast current ticker data to the LiveView
    Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", state.tickers)
    # Schedule the next update
    schedule_tickers_update()
    # Return the state unchanged
    {:ok, state}
  end

  # Processes WebSocket text frames received from the Kraken API.
  # Handles different message types including:
  # - Pong responses
  # - Subscription confirmations and failures
  # - Unsubscription confirmations and failures
  # - Ticker data updates
  @spec handle_frame({:text, String.t()}, state()) :: {:ok, state()}
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
        # Logger.debug("Received ticker message: #{inspect(ticker)}")
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
  @spec handle_frame({term(), String.t()}, state()) :: {:ok, state()}
  def handle_frame(frame, state) do
    Logger.debug("Received other frame: #{inspect(frame)}")
    {:ok, state}
  end

  # PRIVATE FUNCTIONS

  # Schedules the next ping message to keep the WebSocket connection alive.
  @spec schedule_ping() :: reference()
  defp schedule_ping do
    Process.send_after(self(), :ping, @ping_interval)
  end

  # Schedules the next ticker update broadcast to LiveView components.
  @spec schedule_tickers_update() :: reference()
  defp schedule_tickers_update do
    Process.send_after(self(), :tickers_update, @tickers_update_interval)
  end
end
