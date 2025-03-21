defmodule KrakenStreamer.WebSocket.MessageHandler do
  @moduledoc """
  Handles incoming WebSocket messages from the Kraken API.

  This module is responsible for processing different types of WebSocket frames and messages:

  * Text frames containing JSON messages
  * Close frames for connection termination
  * Subscription/unsubscription confirmations
  * Ticker data updates
  * System messages (heartbeat, status)
  * Pong responses for connection keep-alive

  All message handlers maintain state and return standardized responses suitable
  for use with the WebSockex library.
  """

  require Logger

  @typedoc """
  WebSocket frame types that can be handled
  """
  @type frame ::
          {:text, String.t()}
          | {:close, integer(), String.t()}
          | {atom(), term()}

  @typedoc """
  Client state containing the map of current tickers
  """
  @type state :: %{
          tickers: %{String.t() => ticker()}
        }

  @typedoc """
  Ticker data structure containing ask and bid prices
  """
  @type ticker :: %{
          ask: String.t(),
          bid: String.t()
        }

  @typedoc """
  Standard return type for message handlers
  """
  @type handler_response :: {:ok, state()}

  @doc """
  Handles incoming WebSocket frames.

  Processes three types of frames:
  * Text frames: Decodes JSON and delegates to appropriate message handler
  * Close frames: Logs the close reason and code
  * Other frames: Logs unexpected frame types

  ## Parameters

  * `frame` - The WebSocket frame to process
  * `state` - Current client state

  ## Returns

  * `{:ok, state}` - Processing completed successfully

  ## Examples

      iex> handle_frame({:text, ~s({"method": "pong"})}, %{tickers: %{}})
      {:ok, %{tickers: %{}}}

      iex> handle_frame({:close, 1000, "normal"}, state)
      {:ok, state}
  """
  @spec handle_frame(frame(), state()) :: handler_response()
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, message} ->
        handle_message(message, state)

      {:error, error} ->
        Logger.error("Failed to decode WebSocket message: #{inspect(error)}")
        {:ok, state}
    end
  end

  def handle_frame({:close, code, reason}, state) do
    Logger.warning("Received close frame with code #{code}: #{reason}")
    {:ok, state}
  end

  def handle_frame(frame, state) do
    Logger.warning("Received unexpected frame type: #{inspect(frame)}")
    {:ok, state}
  end

  # Handles pong response messages
  @doc false
  @spec handle_message(%{String.t() => String.t()}, state()) :: handler_response()
  defp handle_message(%{"method" => "pong"}, state) do
    Logger.debug("Received pong")
    {:ok, state}
  end

  # Handles subscription confirmation messages
  @doc false
  @spec handle_message(
          %{
            String.t() => String.t(),
            String.t() => String.t(),
            String.t() => boolean()
          },
          state()
        ) :: handler_response()
  defp handle_message(
         %{
           "method" => "subscribe",
           "result" => %{"channel" => "ticker", "symbol" => symbol},
           "success" => success
         },
         state
       ) do
    if success do
      Logger.info("Successfully subscribed to #{symbol} pair")
      {:ok, state}
    else
      Logger.warning("Failed to subscribe to #{symbol} pair")
      {:ok, state}
    end
  end

  # Handles unsubscription confirmation messages
  @doc false
  @spec handle_message(
          %{
            String.t() => String.t(),
            String.t() => String.t(),
            String.t() => boolean()
          },
          state()
        ) :: handler_response()
  defp handle_message(
         %{
           "method" => "unsubscribe",
           "result" => %{"channel" => "ticker", "symbol" => symbol},
           "success" => success
         },
         state
       ) do
    if success do
      Logger.info("Successfully unsubscribed from #{symbol} pair")
      {:ok, state}
    else
      Logger.warning("Failed to unsubscribe from #{symbol} pair")
      {:ok, state}
    end
  end


  # Handles ticker update messages
  @doc false
  @spec handle_message(
          %{
            String.t() => String.t(),
            String.t() => String.t(),
            String.t() => list(map())
          },
          state()
        ) :: handler_response()
  defp handle_message(
         %{"channel" => "ticker", "type" => _type, "data" => [ticker | _]},
         state
       ) do
    symbol = ticker["symbol"]
    ask = ticker["ask"]
    bid = ticker["bid"]
    new_state = %{state | tickers: Map.put(state.tickers, symbol, %{ask: ask, bid: bid})}
    {:ok, new_state}
  end

  # Handles heartbeat messages
  @doc false
  @spec handle_message(%{String.t() => String.t()}, state()) :: handler_response()
  defp handle_message(%{"channel" => "heartbeat"}, state) do
    {:ok, state}
  end

  # Handles status messages
  @doc false
  @spec handle_message(%{String.t() => String.t()}, state()) :: handler_response()
  defp handle_message(%{"channel" => "status"}, state) do
    {:ok, state}
  end

  # Handles unrecognized messages
  @doc false
  @spec handle_message(map(), state()) :: handler_response()
  defp handle_message(msg, state) do
    Logger.debug("Received unhandled message type: #{inspect(msg)}")
    {:ok, state}
  end
end
