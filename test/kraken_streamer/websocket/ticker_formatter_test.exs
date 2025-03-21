defmodule KrakenStreamer.WebSocket.TickerFormatterTest do
  use ExUnit.Case, async: true
  alias KrakenStreamer.WebSocket.TickerFormatter

  describe "validate_and_format_tickers/1" do
    test "successfully formats valid ticker data" do
      tickers = %{
        "BTC/USD" => %{ask: 50000.0, bid: 49900.0}
      }

      assert {:ok, formatted} = TickerFormatter.validate_and_format_tickers(tickers)
      assert %{"BTC/USD" => %{ask: "50000.00", bid: "49900.00"}} = formatted
    end

    test "formats multiple pairs" do
      tickers = %{
        "BTC/USD" => %{ask: 50000.0, bid: 49900.0},
        "ETH/USD" => %{ask: 2000.0, bid: 1990.0}
      }

      assert {:ok, formatted} = TickerFormatter.validate_and_format_tickers(tickers)

      assert %{
               "BTC/USD" => %{ask: "50000.00", bid: "49900.00"},
               "ETH/USD" => %{ask: "2000.00", bid: "1990.00"}
             } = formatted
    end

    test "handles integer prices" do
      tickers = %{
        "ETH/USD" => %{ask: 2000, bid: 1999}
      }

      assert {:ok, formatted} = TickerFormatter.validate_and_format_tickers(tickers)
      assert %{"ETH/USD" => %{ask: "2000.00", bid: "1999.00"}} = formatted
    end

    test "handles very small numbers with appropriate precision" do
      tickers = %{
        "SHIB/USD" => %{ask: 0.00000789, bid: 0.00000788}
      }

      assert {:ok, formatted} = TickerFormatter.validate_and_format_tickers(tickers)
      assert %{"SHIB/USD" => %{ask: "0.00000789", bid: "0.00000788"}} = formatted
    end

    test "handles very large numbers" do
      tickers = %{
        "BTC/JPY" => %{ask: 7_500_000.0, bid: 7_499_000.0}
      }

      assert {:ok, formatted} = TickerFormatter.validate_and_format_tickers(tickers)
      assert %{"BTC/JPY" => %{ask: "7500000.00", bid: "7499000.00"}} = formatted
    end

    test "returns error for non-string symbol" do
      tickers = %{
        123 => %{ask: 50000.0, bid: 49900.0}
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Symbol must be a string"
    end

    test "returns error for empty symbol" do
      tickers = %{
        "" => %{ask: 50000.0, bid: 49900.0}
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Symbol cannot be empty"
    end

    test "returns error for missing ask price" do
      tickers = %{
        "BTC/USD" => %{bid: 49900.0}
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Missing ask or bid value"
    end

    test "returns error for missing bid price" do
      tickers = %{
        "BTC/USD" => %{ask: 50000.0}
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Missing ask or bid value"
    end

    test "returns error for invalid ask price" do
      tickers = %{
        "BTC/USD" => %{ask: "invalid", bid: 49900.0}
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Invalid ticker data: Invalid data type for \"BTC/USD\": %{ask: \"invalid\", bid: 49900.0}"
    end

    test "returns error for invalid bid price" do
      tickers = %{
        "BTC/USD" => %{ask: 50000.0, bid: "invalid"}
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Invalid ticker data: Invalid data type for \"BTC/USD\": %{ask: 50000.0, bid: \"invalid\"}"
    end

    test "returns error for non-map ticker data" do
      tickers = %{
        "BTC/USD" => "invalid"
      }

      assert {:error, message} = TickerFormatter.validate_and_format_tickers(tickers)
      assert message =~ "Invalid data type"
    end

    test "returns error for non-map input" do
      assert {:error, message} = TickerFormatter.validate_and_format_tickers("invalid")
      assert message =~ "Expected map for ticker data"
    end
  end

  describe "convert_to_float/1" do
    test "converts integer to float" do
      assert TickerFormatter.convert_to_float(123) == 123.0
    end

    test "keeps float as is" do
      assert TickerFormatter.convert_to_float(123.45) == 123.45
    end

    test "converts valid string to float" do
      assert TickerFormatter.convert_to_float("123.45") == 123.45
    end

    test "returns nil for invalid string" do
      assert TickerFormatter.convert_to_float("invalid") == nil
    end

    test "returns nil for nil input" do
      assert TickerFormatter.convert_to_float(nil) == nil
    end

    test "returns nil for other types" do
      assert TickerFormatter.convert_to_float([]) == nil
      assert TickerFormatter.convert_to_float(%{}) == nil
    end
  end

  describe "dynamic_format/1" do
    test "formats large numbers with 2 decimal places" do
      assert TickerFormatter.dynamic_format(1234.5678) == "1234.57"
      assert TickerFormatter.dynamic_format(1.0) == "1.00"
    end

    test "formats medium numbers (≥0.01) with 4 decimal places" do
      assert TickerFormatter.dynamic_format(0.12345) == "0.1235"
      assert TickerFormatter.dynamic_format(0.01) == "0.0100"
    end

    test "formats small numbers (≥0.0001) with 6 decimal places" do
      assert TickerFormatter.dynamic_format(0.0001234) == "0.000123"
      assert TickerFormatter.dynamic_format(0.0001) == "0.000100"
    end

    test "formats very small numbers (≥0.000001) with 8 decimal places" do
      assert TickerFormatter.dynamic_format(0.00000123) == "0.00000123"
      assert TickerFormatter.dynamic_format(0.000001) == "0.00000100"
    end

    test "formats extremely small numbers with 10 decimal places" do
      assert TickerFormatter.dynamic_format(0.0000001234) == "0.0000001234"
    end

    test "handles negative numbers" do
      assert TickerFormatter.dynamic_format(-1234.5678) == "-1234.57"
      assert TickerFormatter.dynamic_format(-0.0001234) == "-0.000123"
    end

    test "handles boundary conditions" do
      assert TickerFormatter.dynamic_format(1.0) == "1.00"
      assert TickerFormatter.dynamic_format(0.01) == "0.0100"
      assert TickerFormatter.dynamic_format(0.0001) == "0.000100"
      assert TickerFormatter.dynamic_format(0.000001) == "0.00000100"
    end
  end
end
