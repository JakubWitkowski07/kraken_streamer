defmodule KrakenStreamer.KrakenAPI.ClientTest do
  use ExUnit.Case, async: true
  import Mox

  alias KrakenStreamer.KrakenAPI.Client

  setup :verify_on_exit!
  
  describe "fetch_pairs_from_api" do
    test "successfully fetches and processes pairs" do
      # Create the JSON content.
      json_body =
        Jason.encode!(%{
          "error" => [],
          "result" => %{
            "BTCUSD" => %{
              "wsname" => "XBT/USD"
            },
            "ETHUSD" => %{
              "wsname" => "ETH/USD"
            },
            "XDGUSD" => %{
              "wsname" => "XDG/USD"
            }
          }
        })

      # Create a proper HTTPoison.Response struct.
      api_response = %HTTPoison.Response{
        status_code: 200,
        body: json_body
      }

      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url -> {:ok, api_response} end)

      # Call the function being tested.
      {:ok, pairs} = Client.fetch_pairs_from_api()

      # Convert the returned list of pairs into a MapSet for assertions.
      pairs_set = MapSet.new(pairs)


      assert MapSet.member?(pairs_set, "BTC/USD")
      assert MapSet.member?(pairs_set, "ETH/USD")
      assert MapSet.member?(pairs_set, "DOGE/USD")
      assert MapSet.size(pairs_set) == 3
    end

    test "handles empty result from API" do
      json_body = Jason.encode!(%{"error" => [], "result" => %{}})
      api_response = %HTTPoison.Response{status_code: 200, body: json_body}

      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok, api_response}
      end)

      {:ok, pairs} = Client.fetch_pairs_from_api()
      assert MapSet.size(pairs) == 0
    end

    test "handles API error responses" do
      # Create a proper HTTPoison.Response struct with error status
      error_response = %HTTPoison.Response{
        status_code: 500,
        body: "Internal Server Error"
      }

      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok, error_response}
      end)

      result = Client.fetch_pairs_from_api()

      assert {:error, error_message} = result
      assert error_message =~ "HTTP error: 500"
    end

    test "handles network failures" do
      # Create a proper HTTPoison.Error struct
      network_error = %HTTPoison.Error{
        reason: "network_error"
      }

      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:error, network_error}
      end)

      result = Client.fetch_pairs_from_api()

      assert {:error, error_message} = result
      assert error_message =~ "HTTP request failed"
    end

    test "handles JSON parsing errors" do
      # Create a response with invalid JSON
      invalid_json_response = %HTTPoison.Response{
        status_code: 200,
        body: "{invalid json}"
      }

      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok, invalid_json_response}
      end)

      result = Client.fetch_pairs_from_api()

      assert {:error, error_message} = result
      assert error_message =~ "Failed to decode API response"
    end
  end
end
