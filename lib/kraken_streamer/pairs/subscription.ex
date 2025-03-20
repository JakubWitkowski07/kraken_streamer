defmodule KrakenStreamer.Pairs.Subscription do
  require Logger

  @batch_delay 200

  # Sends subscription requests for each batch of pairs.
  @spec subscribe_batches([{[String.t()], non_neg_integer()}]) :: :ok
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

  # Sends unsubscription requests for each batch of pairs.
  @spec unsubscribe_batches([{[String.t()], non_neg_integer()}]) :: :ok
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
  @spec delay_execution(non_neg_integer()) :: :ok
  defp delay_execution(delay) do
    :timer.sleep(delay)
  end
end
