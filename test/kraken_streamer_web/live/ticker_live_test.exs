defmodule KrakenStreamerWeb.TickerLiveTest do
  use KrakenStreamerWeb.ConnCase
  import Plug.Conn
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  describe "TickerLive" do
    test "disconnected and connected render", %{conn: conn} do
      # Test initial render (disconnected)
      {:ok, page_live, disconnected_html} = live(conn, "/tickers")
      assert disconnected_html =~ "Kraken Price Streamer"
      assert disconnected_html =~ "Waiting for market data"

      # Test connected render
      assert render(page_live) =~ "Kraken Price Streamer"
      assert render(page_live) =~ "Waiting for market data"
    end

    test "subscribes to ticker updates", %{conn: conn} do
      # Connect to the LiveView
      {:ok, view, _html} = live(conn, "/tickers")

      # Simulate receiving ticker data via PubSub
      ticker_data = %{
        "BTC/USD" => %{ask: "50000.0", bid: "49900.0"},
        "ETH/USD" => %{ask: "3000.0", bid: "2990.0"}
      }

      Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", ticker_data)

      # Wait for the view to update and verify the content
      assert render(view) =~ "BTC/USD"
      assert render(view) =~ "50000.0"
      assert render(view) =~ "49900.0"
      assert render(view) =~ "ETH/USD"
      assert render(view) =~ "3000.0"
      assert render(view) =~ "2990.0"
    end

    test "displays empty state when no tickers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tickers")

      # Simulate empty ticker data
      Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", %{})

      # Verify empty state message
      assert render(view) =~ "Waiting for market data"
    end

    test "updates ticker count", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/tickers")

      # Send ticker data with two pairs
      ticker_data = %{
        "BTC/USD" => %{ask: "50000.0", bid: "49900.0"},
        "ETH/USD" => %{ask: "3000.0", bid: "2990.0"}
      }

      Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", ticker_data)

      # Verify the pair count is displayed
      assert render(view) =~ "2 pairs"

      # Update with different number of pairs
      new_ticker_data = %{
        "BTC/USD" => %{ask: "50000.0", bid: "49900.0"}
      }

      Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, "tickers", new_ticker_data)

      # Verify the updated pair count
      assert render(view) =~ "1 pairs"
    end
  end
end
