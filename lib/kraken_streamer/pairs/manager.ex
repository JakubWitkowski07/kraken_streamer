defmodule KrakenStreamer.Pairs.Manager do
  @moduledoc """
  Manages trading pairs for the Kraken WebSocket connection.
  Periodically fetches available pairs and maintains subscriptions.
  """

  use GenServer
  require Logger

  alias KrakenStreamer.Pairs.{Utilities, Subscription}
  alias KrakenStreamer.KrakenAPI.Client

  @check_interval Application.compile_env(:kraken_streamer, KrakenStreamer.Pairs.Manager)[
                    :check_interval
                  ]

  defstruct pairs: MapSet.new(), batches: []

  @type t :: %__MODULE__{
          pairs: MapSet.t(String.t()),
          batches: [{[String.t()], non_neg_integer()}]
        }

  @doc """
  Starts the pairs manager process.
  """
  @spec start_link(map()) :: GenServer.on_start()
  def start_link(opts \\ %{}) do
    name = Map.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initializes first pairs set and schedules pair updates.
  """
  @spec initialize_pairs_set(GenServer.server()) :: :ok
  def initialize_pairs_set(server \\ __MODULE__) do
    GenServer.cast(server, :initialize_pairs_set)
  end

  @doc false
  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @doc false
  @impl true
  def handle_cast(:initialize_pairs_set, state) do
    Logger.info("Fetching available pairs from Kraken API")

    case Client.fetch_pairs_from_api() do
      {:ok, ws_names} ->
        Logger.info(
          "Successfully fetched #{MapSet.size(ws_names)} tradable pairs. Tradable pairs: #{inspect(ws_names)}"
        )

        batches =
          Utilities.batch_pairs(ws_names)
          |> Subscription.subscribe_batches()

        schedule_pair_updates()
        {:noreply, %{state | pairs: ws_names, batches: batches}}

      {:error, reason} ->
        Logger.error("Error fetching pairs: #{reason}")

        Process.send_after(self(), :initialize_pairs_set, :timer.minutes(5))
        {:noreply, state}
    end
  end

  @doc false
  @impl true
  def handle_info(:update_pairs, state) do
    Logger.info("Checking for pairs updates")

    case Client.fetch_pairs_from_api() do
      {:ok, updated_pairs} ->
        case Utilities.compare_pair_sets(MapSet.new(state.pairs), MapSet.new(updated_pairs)) do
          {:ok, :no_changes} ->
            Logger.info("No changes in pairs")
            schedule_pair_updates()
            {:noreply, state}

          {:ok, :changes} ->
            Logger.info(
              "Successfully fetched update for #{MapSet.size(updated_pairs)} tradable pairs. Tradable pairs: #{inspect(updated_pairs)}"
            )

            Subscription.unsubscribe_batches(state.batches)

            batches =
              Utilities.batch_pairs(updated_pairs)
              |> Subscription.subscribe_batches()

            schedule_pair_updates()
            {:noreply, %{state | pairs: updated_pairs, batches: batches}}
        end

      {:error, reason} ->
        Logger.error("Error fetching pairs: #{reason}")

        Process.send_after(self(), :update_pairs, :timer.seconds(30))
        {:noreply, state}
    end
  end

  defp schedule_pair_updates do
    Process.send_after(self(), :update_pairs, @check_interval)
  end
end
