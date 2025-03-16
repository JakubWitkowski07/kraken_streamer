defmodule KrakenStreamer.WebSocketClient do
  use WebSockex
  require Logger

  @kraken_ws_url "wss://ws.kraken.com/v2"
  # Kraken Docs: Ping should be sent at least every 60 seconds
  @ping_interval :timer.seconds(2)

  # PUBLIC API

  def start_link(opts \\ %{}) do
    WebSockex.start_link(@kraken_ws_url, __MODULE__, %{tickers: %{}}, name: __MODULE__)
  end

  # CALLBACKS

  def handle_connect(_conn, state) do
    Logger.info("Connected to Kraken WebSocket server")
    # Schedule a ping to keep the connection alive
    schedule_ping()
    {:ok, state}
  end

  def handle_disconnect(%{reason: reason}, state) do
    Logger.debug("Disconnected from Kraken WebSocket server: #{inspect(reason)}")
    # Reconnect automatically
    {:reconnect, state}
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


  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, %{"method" => "pong", "time_in" => _time_in, "time_out" => _time_out}} ->
        Logger.debug("Pong received")
        {:ok, state}

      {:ok, other_message} ->
        # Handle other types of messages
        Logger.debug("Received other WebSocket message: #{inspect(other_message)}")
        {:ok, state}

      {:error, error} ->
        Logger.error("Failed to decode WebSocket message: #{inspect(error)}")
        {:ok, state}
      end
  end

  # PRIVATE FUNCTIONS

  defp schedule_ping do
    Process.send_after(self(), :ping, @ping_interval)
  end
end
