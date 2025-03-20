defmodule KrakenStreamerWeb.TickerLive do
  use Phoenix.LiveView
  require Logger

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(KrakenStreamer.PubSub, "tickers")
    end

    {:ok, assign(socket, ticker: %{})}
  end

  # This will match any map that comes in (which is your ticker state)
  def handle_info(ticker_state, socket) when is_map(ticker_state) do
    # Logger.debug("Ticker state: #{inspect(ticker_state)}")

    {:noreply, assign(socket, ticker: ticker_state)}
  end

  def render(assigns) do
    ~H"""
    <h1>Kraken Real-Time Prices</h1>
    <table align="center" border="1" cellpadding="8">
      <thead>
        <tr>
          <th>Index</th>
          <th>Pair</th>
          <th>Sell Price (Ask)</th>
          <th>Buy Price (Bid)</th>
        </tr>
      </thead>
      <tbody>
        <%= for {{symbol, data}, index} <- Enum.with_index(@ticker, 1) do %>
          <tr>
            <td>{index}</td>
            <td>{symbol}</td>
            <td>{data.ask}</td>
            <td>{data.bid}</td>
          </tr>
        <% end %>
      </tbody>
    </table>
    """
  end
end
