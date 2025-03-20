defmodule KrakenStreamer.KrakenAPI.HTTPClientTest do
  use ExUnit.Case, async: false
  import Mox

  alias KrakenStreamer.KrakenAPI.HTTPClient

  setup do
    # Store the original config
    original_client = Application.get_env(:kraken_streamer, :http_client)

    on_exit(fn ->
      # Restore the original config after each test
      Application.put_env(:kraken_streamer, :http_client, original_client)
    end)
  end

  test "uses HTTPoison as default implementation" do
    Application.delete_env(:kraken_streamer, :http_client)
    assert HTTPClient.impl() == HTTPoison
  end

  test "uses configured implementation" do
    custom_client = KrakenStreamer.KrakenAPI.MockHTTPClient
    Application.put_env(:kraken_streamer, :http_client, custom_client)
    assert HTTPClient.impl() == custom_client
  end

  describe "get/1" do
    setup do
      Application.put_env(:kraken_streamer, :http_client, KrakenStreamer.KrakenAPI.MockHTTPClient)
      :ok
    end

    test "delegates to configured implementation for Kraken API request" do
      url = "https://api.kraken.com/0/public/AssetPairs"

      expected_response =
        {:ok, %HTTPoison.Response{status_code: 200, body: ~s({"result":{},"error":[]})}}

      expect(KrakenStreamer.KrakenAPI.MockHTTPClient, :get, fn ^url -> expected_response end)

      assert HTTPClient.get(url) == expected_response
    end

    test "handles Kraken API error responses" do
      url = "https://api.kraken.com/0/public/AssetPairs"
      expected_error = {:error, %HTTPoison.Error{reason: "connection_error"}}

      expect(KrakenStreamer.KrakenAPI.MockHTTPClient, :get, fn ^url -> expected_error end)

      assert HTTPClient.get(url) == expected_error
    end
  end
end
