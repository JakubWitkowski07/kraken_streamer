defmodule KrakenStreamer.Pairs.Subscription do
  @moduledoc """
  Handles WebSocket subscriptions for trading pairs.
  Manages batch subscriptions and unsubscriptions with rate limiting.
  """

  require Logger

  @batch_delay 200

  @doc """
  Subscribes to batches of trading pairs via PubSub.
  Introduces delay between batches to prevent rate limiting.

  ## Parameters
    * `batches` - List of {pairs, index} tuples
    * `topic` - PubSub topic (default: "pairs:subscription")

  ## Returns
    * `:ok` - Successfully subscribed to all batches
    * `{:error, :invalid_batches}` - Invalid batch format
  """
  @spec subscribe_batches([{[String.t()], non_neg_integer()}], String.t()) ::
          :ok | {:error, :invalid_batches}
  def subscribe_batches(batches, topic \\ "pairs:subscription")

  def subscribe_batches(batches, topic) when is_list(batches) and length(batches) > 0 do
    batches
    |> Enum.each(fn {batch, idx} ->
      Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, topic, {:pairs_subscribe, batch})

      Logger.debug("Broadcasting subscription for batch #{idx + 1} with #{length(batch)} pairs")
      delay_execution(@batch_delay)
    end)

    :ok
  end

  def subscribe_batches(_batches, _topic) do
    {:error, :invalid_batches}
  end

  @doc """
  Unsubscribes from batches of trading pairs via PubSub.
  Introduces delay between batches to prevent rate limiting.

  ## Parameters
    * `batches` - List of {pairs, index} tuples
    * `topic` - PubSub topic (default: "pairs:subscription")

  ## Returns
    * `:ok` - Successfully unsubscribed from all batches
    * `{:error, :invalid_batches}` - Invalid batch format
  """
  @spec unsubscribe_batches([{[String.t()], non_neg_integer()}], String.t()) ::
          :ok | {:error, :invalid_batches}
  def unsubscribe_batches(batches, topic \\ "pairs:subscription")

  def unsubscribe_batches(batches, topic) when is_list(batches) and length(batches) > 0 do
    batches
    |> Enum.each(fn {batch, idx} ->
      Phoenix.PubSub.broadcast(KrakenStreamer.PubSub, topic, {:pairs_unsubscribe, batch})

      Logger.debug("Broadcasting unsubscription for batch #{idx + 1} with #{length(batch)} pairs")
      delay_execution(@batch_delay)
    end)

    :ok
  end

  def unsubscribe_batches(_batches, _topic) do
    {:error, :invalid_batches}
  end

  # Helper function to introduce a delay between operations.
  @doc false
  @spec delay_execution(non_neg_integer()) :: :ok
  defp delay_execution(delay) do
    :timer.sleep(delay)
  end
end
