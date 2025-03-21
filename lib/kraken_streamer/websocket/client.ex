defmodule KrakenStreamer.WebSocket.Client do
  @moduledoc """
  WebSocket client for Kraken's cryptocurrency market data API.

  Maintains a WebSocket connection to Kraken's API to receive real-time ticker data.
  Handles connection management, data subscriptions, and broadcasts updates via PubSub.

  ## PubSub Topics

  Subscribes to:
  * `"pairs:subscription"` - For subscription commands:
    - `{:pairs_subscribe, pairs}`
    - `{:pairs_unsubscribe, pairs}`

  Broadcasts to:
  * `"tickers"` - Latest ticker data:
    - `%{"BTC/USD" => %{ask: 50000.0, bid: 49900.0}}`
  """

  use WebSockex
  require Logger
  alias KrakenStreamer.WebSocket.{MessageHandler, TickerFormatter}

  @kraken_ws_url Application.compile_env(:kraken_streamer, KrakenStreamer.Websocket.Client)[:url]
  @ping_interval Application.compile_env(:kraken_streamer, KrakenStreamer.Websocket.Client)[:ping_interval]
  @tickers_update_interval Application.compile_env(:kraken_streamer, KrakenStreamer.Websocket.Client)[:tickers_update_interval]

  @type ticker :: %{ask: float(), bid: float()}
  @type state :: %{tickers: %{String.t() => ticker()}}

  @doc """
  Starts the WebSocket client and connects to Kraken's WebSocket API.

  ## Options
    * `:name` - Optional name for the process (default: `__MODULE__`) - used for testing


  ## Returns

  - `{:ok, pid}` - Successfully started the WebSocket client
  - `{:error, term()}` - Failed to start the client
  """
  @spec start_link(map()) :: {:ok, pid()} | {:error, term()}
  def start_link(opts \\ %{}) do
    name = Map.get(opts, :name, __MODULE__)
    WebSockex.start_link(@kraken_ws_url, __MODULE__, %{tickers: %{}}, name: name)
  end

  @doc """
  Handles successful WebSocket connection.
  Sets up PubSub subscriptions and schedules periodic tasks.
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

  # Handles WebSocket disconnection by attempting to reconnect.
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
    send_ping(state)
  end

  # Formats and broadcasts current ticker data to LiveView components via PubSub.
  # Automatically schedules the next update.
  @spec handle_info(:tickers_update, state()) :: {:ok, state()}
  def handle_info(:tickers_update, state) do
    # Validate and format tickers
    case TickerFormatter.validate_and_format_tickers(state.tickers) do
      {:ok, formatted_tickers} ->
        # Broadcast current ticker data to the LiveView
        Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", formatted_tickers)
        # Schedule the next update
        schedule_tickers_update()
        # Return the state unchanged
        {:ok, state}

      {:error, error} ->
        Logger.error("Failed to validate and format tickers: #{inspect(error)}")
        {:ok, state}
    end
  end

  # Processes incoming WebSocket frames using MessageHandler.
  @spec handle_frame({:text, String.t()}, state()) :: {:ok, state()}
  def handle_frame(frame, state) do
    MessageHandler.handle_frame(frame, state)
  end

  # Private Functions

  # Sends a ping message to the Kraken API to keep the connection alive.
  @doc false
  defp send_ping(state) do
    ping_msg = %{"method" => "ping"}

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

  # Schedules the next ping message to keep the WebSocket connection alive.
  @doc false
  @spec schedule_ping() :: reference()
  defp schedule_ping do
    Process.send_after(self(), :ping, @ping_interval)
  end

  # Schedules the next ticker update broadcast to LiveView components.
  @doc false
  @spec schedule_tickers_update() :: reference()
  defp schedule_tickers_update do
    Process.send_after(self(), :tickers_update, @tickers_update_interval)
  end
end
