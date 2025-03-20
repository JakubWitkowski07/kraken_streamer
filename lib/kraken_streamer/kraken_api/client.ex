defmodule KrakenStreamer.KrakenAPI.Client do
  require Logger
  alias KrakenStreamer.KrakenAPI.HTTPClient
  alias KrakenStreamer.Pairs.Utilities

  @kraken_pairs_url "https://api.kraken.com/0/public/AssetPairs"

  @spec fetch_pairs_from_api() :: {:ok, MapSet.t(String.t())} | {:error, String.t()}
  def fetch_pairs_from_api() do
    Logger.debug("Fetching pairs from Kraken API: #{@kraken_pairs_url}")

    case HTTPClient.get(@kraken_pairs_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => result}} ->
            # Retrieve only the wsname from the result to collect all pairs in format "BTC/USD"
            ws_names =
              result
              |> Enum.map(fn {_key, pair_data} ->
                pair_data["wsname"]
              end)
              |> Utilities.normalize_pairs()
              |> MapSet.new()

            {:ok, ws_names}

          {:error, reason} ->
            {:error, "Failed to decode API response: #{inspect(reason)}"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        {:error, "HTTP error: #{status_code} - #{body}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end
