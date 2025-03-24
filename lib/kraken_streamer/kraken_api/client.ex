defmodule KrakenStreamer.KrakenAPI.Client do
  @moduledoc """
  Client for interacting with the Kraken API.
  Fetches available trading pairs and normalizes them to a standard format.
  """

  require Logger
  alias KrakenStreamer.KrakenAPI.HTTPClient
  alias KrakenStreamer.Pairs.Utilities

  @kraken_pairs_url Application.compile_env(:kraken_streamer, KrakenStreamer.KrakenAPI.Client)[
                      :url
                    ]

  @doc """
  Fetches available trading pairs from Kraken API.
  Returns normalized pairs in format "BTC/USD".

  ## Returns
    * `{:ok, pairs}` - Set of available trading pairs
    * `{:error, reason}` - Error message if request fails
  """
  @spec fetch_pairs_from_api() :: {:ok, MapSet.t(String.t())} | {:error, String.t()}
  def fetch_pairs_from_api() do
    Logger.info("Fetching pairs from Kraken API: #{@kraken_pairs_url}")

    case HTTPClient.get(@kraken_pairs_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => result}} ->
            # Retrieve only the wsname from the result to collect all pairs in format "BTC/USD"
            ws_names = extract_ws_names(result)
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

  # Extracts the wsname from the result to collect all pairs in format "BTC/USD"
  @doc false
  @spec extract_ws_names(map()) :: MapSet.t(String.t())
  defp extract_ws_names(result) do
    result
    |> Enum.map(fn {_key, pair_data} ->
      pair_data["wsname"]
    end)
    |> Utilities.normalize_pairs()
    |> MapSet.new()
  end
end
