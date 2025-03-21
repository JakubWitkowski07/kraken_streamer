defmodule KrakenStreamer.WebSocket.TickerFormatterTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog
  alias KrakenStreamer.WebSocket.TickerFormatter

  describe "validate_all_tickers/1" do
    test "returns valid tickers" do
      tickers = %{
        "BTC/USD" => %{ask: 50_000.0, bid: 49_950.0},
        "ETH/USD" => %{ask: 1800.0, bid: 1795.0}
      }

      assert {:ok, validated_tickers} = TickerFormatter.validate_all_tickers(tickers)
      assert validated_tickers == tickers
    end

    test "filters out invalid tickers while keeping valid ones" do
      tickers = %{
        "BTC/USD" => %{ask: 50_000.0, bid: 49_950.0},
        "ETH/USD" => %{ask: "invalid", bid: 1795.0},
        "XRP/USD" => %{ask: 1.5, bid: nil},
        "DOGE/USD" => %{ask: 0.1, bid: 0.09}
      }

      log =
        capture_log(fn ->
          assert {:ok, validated_tickers} = TickerFormatter.validate_all_tickers(tickers)
          assert map_size(validated_tickers) == 2
          assert validated_tickers["BTC/USD"] == %{ask: 50_000.0, bid: 49_950.0}
          assert validated_tickers["DOGE/USD"] == %{ask: 0.1, bid: 0.09}
          refute Map.has_key?(validated_tickers, "ETH/USD")
          refute Map.has_key?(validated_tickers, "XRP/USD")
        end)

      assert log =~ "Invalid ticker data: Invalid price: \"invalid\""
      assert log =~ "Invalid ticker data: Invalid price: nil"
    end

    test "handles empty map" do
      assert {:ok, validated_tickers} = TickerFormatter.validate_all_tickers(%{})
      assert validated_tickers == %{}
    end

    test "logs error for non-map input" do
      for invalid_input <- [[], nil, "invalid"] do
        log =
          capture_log(fn ->
            TickerFormatter.validate_all_tickers(invalid_input)
          end)

        assert log =~ "Invalid tickers data during validation: #{inspect(invalid_input)}"
      end
    end

    test "filters out tickers with empty symbols" do
      tickers = %{
        "" => %{ask: 50_000.0, bid: 49_950.0},
        "BTC/USD" => %{ask: 1800.0, bid: 1795.0}
      }

      log =
        capture_log(fn ->
          assert {:ok, validated_tickers} = TickerFormatter.validate_all_tickers(tickers)
          assert map_size(validated_tickers) == 1
          assert validated_tickers["BTC/USD"] == %{ask: 1800.0, bid: 1795.0}
        end)

      assert log =~ "Invalid ticker data: Invalid symbol: \"\""
    end

    test "filters out tickers with invalid structure" do
      tickers = %{
        "BTC/USD" => %{ask: 50_000.0, bid: 49_950.0},
        "ETH/USD" => %{price: 1800.0},
        "XRP/USD" => nil,
        "DOGE/USD" => "invalid"
      }

      log =
        capture_log(fn ->
          assert {:ok, validated_tickers} = TickerFormatter.validate_all_tickers(tickers)
          assert map_size(validated_tickers) == 1
          assert validated_tickers["BTC/USD"] == %{ask: 50_000.0, bid: 49_950.0}
        end)

      assert log =~ "Invalid ticker data"
    end
  end

  describe "format_all_tickers/1" do
    test "formats valid tickers with appropriate precision" do
      tickers = %{
        "BTC/USD" => %{ask: 50_000.0, bid: 49_950.0},
        "ETH/USD" => %{ask: 1800.0, bid: 1795.0},
        "DOGE/USD" => %{ask: 0.00345678, bid: 0.00345}
      }

      assert {:ok, formatted_tickers} = TickerFormatter.format_all_tickers(tickers)

      assert formatted_tickers == %{
               "BTC/USD" => %{ask: "50000.00", bid: "49950.00"},
               "ETH/USD" => %{ask: "1800.00", bid: "1795.00"},
               "DOGE/USD" => %{ask: "0.003457", bid: "0.003450"}
             }
    end

    test "handles empty map" do
      assert {:ok, formatted_tickers} = TickerFormatter.format_all_tickers(%{})
      assert formatted_tickers == %{}
    end

    test "logs error for non-map input" do
      for invalid_input <- [[], nil, "invalid"] do
        log =
          capture_log(fn ->
            TickerFormatter.format_all_tickers(invalid_input)
          end)

        assert log =~ "Invalid tickers data during formatting: #{inspect(invalid_input)}"
      end
    end

    test "formats tickers with different precisions based on magnitude" do
      tickers = %{
        "LARGE" => %{ask: 1234.5678, bid: 1234.5678},
        "MEDIUM" => %{ask: 0.12345, bid: 0.12345},
        "SMALL" => %{ask: 0.0001234, bid: 0.0001234},
        "VERY_SMALL" => %{ask: 0.00000123, bid: 0.00000123},
        "TINY" => %{ask: 0.0000001234, bid: 0.0000001234}
      }

      assert {:ok, formatted_tickers} = TickerFormatter.format_all_tickers(tickers)

      assert formatted_tickers == %{
               "LARGE" => %{ask: "1234.57", bid: "1234.57"},
               "MEDIUM" => %{ask: "0.1235", bid: "0.1235"},
               "SMALL" => %{ask: "0.000123", bid: "0.000123"},
               "VERY_SMALL" => %{ask: "0.00000123", bid: "0.00000123"},
               "TINY" => %{ask: "0.0000001234", bid: "0.0000001234"}
             }
    end

    test "handles negative numbers" do
      tickers = %{
        "NEG_LARGE" => %{ask: -1234.5678, bid: -1234.5678},
        "NEG_SMALL" => %{ask: -0.0001234, bid: -0.0001234}
      }

      assert {:ok, formatted_tickers} = TickerFormatter.format_all_tickers(tickers)

      assert formatted_tickers == %{
               "NEG_LARGE" => %{ask: "-1234.57", bid: "-1234.57"},
               "NEG_SMALL" => %{ask: "-0.000123", bid: "-0.000123"}
             }
    end

    test "handles boundary conditions" do
      tickers = %{
        "ONE" => %{ask: 1.0, bid: 1.0},
        "POINT_OH_ONE" => %{ask: 0.01, bid: 0.01},
        "POINT_OH_OH_OH_ONE" => %{ask: 0.0001, bid: 0.0001},
        "SIX_ZEROS_ONE" => %{ask: 0.000001, bid: 0.000001}
      }

      assert {:ok, formatted_tickers} = TickerFormatter.format_all_tickers(tickers)

      assert formatted_tickers == %{
               "ONE" => %{ask: "1.00", bid: "1.00"},
               "POINT_OH_ONE" => %{ask: "0.0100", bid: "0.0100"},
               "POINT_OH_OH_OH_ONE" => %{ask: "0.000100", bid: "0.000100"},
               "SIX_ZEROS_ONE" => %{ask: "0.00000100", bid: "0.00000100"}
             }
    end
  end

  # describe "convert_to_float/1" do
  #   test "converts integer to float" do
  #     assert TickerFormatter.convert_to_float(123) == 123.0
  #   end

  #   test "keeps float as is" do
  #     assert TickerFormatter.convert_to_float(123.45) == 123.45
  #   end

  #   test "converts valid string to float" do
  #     assert TickerFormatter.convert_to_float("123.45") == 123.45
  #   end

  #   test "returns nil for invalid string" do
  #     assert TickerFormatter.convert_to_float("invalid") == nil
  #   end

  #   test "returns nil for nil input" do
  #     assert TickerFormatter.convert_to_float(nil) == nil
  #   end

  #   test "returns nil for other types" do
  #     assert TickerFormatter.convert_to_float([]) == nil
  #     assert TickerFormatter.convert_to_float(%{}) == nil
  #   end
  # end

  # describe "dynamic_format/1" do
  #   test "formats large numbers with 2 decimal places" do
  #     assert TickerFormatter.dynamic_format(1234.5678) == "1234.57"
  #     assert TickerFormatter.dynamic_format(1.0) == "1.00"
  #   end

  #   test "formats medium numbers (≥0.01) with 4 decimal places" do
  #     assert TickerFormatter.dynamic_format(0.12345) == "0.1235"
  #     assert TickerFormatter.dynamic_format(0.01) == "0.0100"
  #   end

  #   test "formats small numbers (≥0.0001) with 6 decimal places" do
  #     assert TickerFormatter.dynamic_format(0.0001234) == "0.000123"
  #     assert TickerFormatter.dynamic_format(0.0001) == "0.000100"
  #   end

  #   test "formats very small numbers (≥0.000001) with 8 decimal places" do
  #     assert TickerFormatter.dynamic_format(0.00000123) == "0.00000123"
  #     assert TickerFormatter.dynamic_format(0.000001) == "0.00000100"
  #   end

  #   test "formats extremely small numbers with 10 decimal places" do
  #     assert TickerFormatter.dynamic_format(0.0000001234) == "0.0000001234"
  #   end

  #   test "handles negative numbers" do
  #     assert TickerFormatter.dynamic_format(-1234.5678) == "-1234.57"
  #     assert TickerFormatter.dynamic_format(-0.0001234) == "-0.000123"
  #   end

  #   test "handles boundary conditions" do
  #     assert TickerFormatter.dynamic_format(1.0) == "1.00"
  #     assert TickerFormatter.dynamic_format(0.01) == "0.0100"
  #     assert TickerFormatter.dynamic_format(0.0001) == "0.000100"
  #     assert TickerFormatter.dynamic_format(0.000001) == "0.00000100"
  #   end
  # end
end
