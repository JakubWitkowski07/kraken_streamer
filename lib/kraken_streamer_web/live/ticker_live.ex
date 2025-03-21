defmodule KrakenStreamerWeb.TickerLive do
  @moduledoc """
  LiveView for displaying real-time cryptocurrency ticker data.
  Shows current ask and bid prices for trading pairs from Kraken.
  """

  use Phoenix.LiveView
  require Logger

  @type ticker :: %{
          String.t() => %{
            ask: String.t(),
            bid: String.t()
          }
        }

  @doc """
  Initializes the LiveView with an empty ticker state.
  Subscribes to ticker updates when the socket is connected.
  """
  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(KrakenStreamer.PubSub, "tickers")
    end

    {:ok, assign(socket, ticker: %{})}
  end

  @doc """
  Handles incoming ticker updates from PubSub.
  Updates the socket assigns with new ticker data.
  """
  @spec handle_info(ticker(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_info(ticker_state, socket) when is_map(ticker_state) do
    {:noreply, assign(socket, ticker: ticker_state)}
  end

  @doc """
  Renders the ticker data in a responsive table format.
  Shows ask/bid prices and pair count with loading state.
  """
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <div class="mb-8 text-center">
        <h1 class="text-3xl font-bold text-gray-800 mb-2">Kraken Price Streamer</h1>
        <p class="text-gray-600">Real-time prices from Kraken exchange</p>
      </div>

      <div class="bg-white rounded-lg shadow-lg overflow-hidden">
        <div class="p-4 bg-gradient-to-r from-blue-600 to-indigo-700 text-white flex justify-between items-center">
          <h2 class="text-xl font-semibold">Live Ticker Data</h2>
          <span class="text-sm bg-blue-800 rounded-full px-3 py-1">
            {Enum.count(@ticker)} pairs
          </span>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full bg-white">
            <thead>
              <tr class="bg-gray-100 border-b border-gray-200">
                <th class="py-3 px-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  #
                </th>
                <th class="py-3 px-4 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Trading Pair
                </th>
                <th class="py-3 px-4 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Ask (Sell)
                </th>
                <th class="py-3 px-4 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Bid (Buy)
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <%= if Enum.empty?(@ticker) do %>
                <tr>
                  <td colspan="5" class="px-4 py-8 text-center text-gray-500 italic">
                    Waiting for market data...
                  </td>
                </tr>
              <% else %>
                <%= for {{symbol, data}, index} <- Enum.with_index(@ticker, 1) do %>
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="px-4 py-3 text-sm text-gray-700">{index}</td>
                    <td class="px-4 py-3">
                      <div class="font-medium text-gray-900">{symbol}</div>
                    </td>
                    <td class="px-4 py-3 text-right">
                      <div class="font-mono text-red-600 font-medium">{data.ask}</div>
                    </td>
                    <td class="px-4 py-3 text-right">
                      <div class="font-mono text-green-600 font-medium">{data.bid}</div>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="mt-6 text-center text-sm text-gray-500">
        <p>Data refreshes automatically every second</p>
      </div>
    </div>
    """
  end
end
