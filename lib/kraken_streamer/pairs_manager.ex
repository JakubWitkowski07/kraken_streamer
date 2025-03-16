defmodule KrakenStreamer.PairsManager do
  use GenServer
  require Logger

  @kraken_pairs_url "https://api.kraken.com/0/public/AssetPairs"
  @check_interval :timer.minutes(10)

  # PUBLIC API

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # GENSERVER CALLBACKS

  def init(_opts) do
    send(self(), :initialize_pairs_set)
    {:ok, %{pairs: MapSet.new()}}
  end

  # Handles the initial pairs set
  def handle_info(:initialize_pairs_set, state) do
    case fetch_pairs_from_api() do
      {:ok, ws_names} ->
        Logger.info(
          "Successfully fetched #{MapSet.size(ws_names)} tradable pairs. Tradable pairs: #{inspect(ws_names)}"
        )

        schedule_pair_updates()
        {:noreply, %{state | pairs: ws_names}}

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

            schedule_pair_updates()
            {:noreply, %{state | pairs: updated_pairs}}
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
end
