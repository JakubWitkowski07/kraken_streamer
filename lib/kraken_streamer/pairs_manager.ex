defmodule KrakenStreamer.PairsManager do
  use GenServer
  require Logger

  @kraken_pairs_url "https://api.kraken.com/0/public/AssetPairs"
  @check_interval :timer.minutes(10)
  @batch_size 250
  @batch_delay 200

  # PUBLIC API

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GENSERVER CALLBACKS

  def init(_opts) do
    send(self(), :initialize_pairs_set)
    {:ok, %{pairs: MapSet.new(), batches: []}}
  end

  # Handles the initial pairs set
  def handle_info(:initialize_pairs_set, state) do
    Logger.info("Fetching available pairs from Kraken API")

    case fetch_pairs_from_api() do
      {:ok, ws_names} ->
        Logger.info(
          "Successfully fetched #{MapSet.size(ws_names)} tradable pairs. Tradable pairs: #{inspect(ws_names)}"
        )

        batches =
          batch_pairs(ws_names)
          |> subscribe_batches()

        schedule_pair_updates()
        {:noreply, %{state | pairs: ws_names, batches: batches}}

      {:error, reason} ->
        Logger.error("Error fetching pairs: #{reason}")
        # Schedule a retry sooner on error
        Process.send_after(self(), :initialize_pairs_set, :timer.minutes(5))
        {:noreply, state}
    end
  end

  # Handles the pairs update
  def handle_info(:update_pairs, state) do
    Logger.info("Checking for pairs updates")

    case fetch_pairs_from_api() do
      {:ok, updated_pairs} ->
        current_pairs = MapSet.new(state.pairs)
        updated_pairs = MapSet.new(updated_pairs)

        cond do
          current_pairs == updated_pairs ->
            Logger.info("No changes in pairs")
            schedule_pair_updates()
            {:noreply, state}

          current_pairs != updated_pairs ->
            Logger.info(
              "Successfully fetched #{MapSet.size(updated_pairs)} tradable pairs. Tradable pairs: #{inspect(updated_pairs)}"
            )

            unsubscribe_batches(state.batches)

            batches =
              batch_pairs(updated_pairs)
              |> subscribe_batches()

            schedule_pair_updates()
            {:noreply, %{state | pairs: updated_pairs, batches: batches}}
        end

      {:error, reason} ->
        Logger.error("Error fetching pairs: #{reason}")
        # Schedule a retry sooner on error
        Process.send_after(self(), :update_pairs, :timer.seconds(30))
        {:noreply, state}
    end
  end

  # PRIVATE FUNCTIONS

  # Fetches the pairs from the Kraken API
  defp fetch_pairs_from_api do
    Logger.debug("Making request to Kraken API: #{@kraken_pairs_url}")

    case HTTPoison.get(@kraken_pairs_url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"result" => result}} ->
            # Retrieve only the wsname from the result to collect all pairs in format "BTC/USD"
            ws_names =
              result
              |> Enum.map(fn {_key, pair_data} ->
                pair_data["wsname"]
              end)
              |> normalize_pairs()
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

  # Schedules the next pair update check
  defp schedule_pair_updates do
    Logger.debug("Scheduling next pairs update in #{@check_interval}ms.")
    Process.send_after(self(), :update_pairs, @check_interval)
  end

  # Batches the pairs into smaller groups.
  defp batch_pairs(pairs) do
    pairs
    |> MapSet.to_list()
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
  end

  # Normalizes a single trading pair string.
  defp normalize_pair(pair) when is_binary(pair) do
    case String.split(pair, "/") do
      [base, quote] ->
        new_base = normalize_symbol(base)
        new_quote = normalize_symbol(quote)
        "#{new_base}/#{new_quote}"

      _ ->
        pair
    end
  end

  # Normalizes a single currency symbol.
  defp normalize_symbol(symbol) do
    cond do
      symbol == "XBT" -> "BTC"
      symbol == "XDG" -> "DOGE"
      true -> symbol
    end
  end

  # Applies normalization to a list of trading pairs.
  defp normalize_pairs(pairs) when is_list(pairs) do
    pairs
    |> Enum.map(&normalize_pair/1)
  end

  # Sends subscription requests for each batch of pairs.
  defp subscribe_batches(batches) do
    batches
    |> Enum.each(fn {batch, idx} ->
      Phoenix.PubSub.broadcast(
        KrakenStreamer.PubSub,
        "pairs:subscription",
        {:pairs_subscribe, batch}
      )

      Logger.debug("Broadcasting subscription for batch #{idx + 1} with #{length(batch)} pairs")
      delay_execution(@batch_delay)
    end)

    :ok
  end

  # Sends unsubscription requests for each batch of pairs.
  defp unsubscribe_batches(batches) do
    batches
    |> Enum.each(fn {batch, idx} ->
      Phoenix.PubSub.broadcast(
        KrakenStreamer.PubSub,
        "pairs:subscription",
        {:pairs_unsubscribe, batch}
      )

      Logger.debug("Broadcasting unsubscription for batch #{idx + 1} with #{length(batch)} pairs")
      delay_execution(@batch_delay)
    end)

    :ok
  end

  # Helper function to introduce a delay between operations.
  defp delay_execution(delay) do
    :timer.sleep(delay)
  end
end
