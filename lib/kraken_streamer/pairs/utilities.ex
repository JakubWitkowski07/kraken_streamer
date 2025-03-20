defmodule KrakenStreamer.Pairs.Utilities do
  require Logger

  @batch_size 250

  # Batches the pairs into smaller groups.
  @spec batch_pairs(MapSet.t(String.t())) :: [{[String.t()], non_neg_integer()}]
  def batch_pairs(pairs) do
    pairs
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
  end

  # Applies normalization to a list of trading pairs.
  @spec normalize_pairs([String.t()]) :: [String.t()]
  def normalize_pairs(pairs) when is_list(pairs) do
    pairs
    |> Enum.map(&normalize_pair/1)
  end

  # Normalizes a single trading pair string.
  @spec normalize_pair(String.t()) :: String.t()
  def normalize_pair(pair)
  def normalize_pair(pair) when is_binary(pair) do
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
  @spec normalize_symbol(String.t()) :: String.t()
  def normalize_symbol("XBT"), do: "BTC"
  def normalize_symbol("XDG"), do: "DOGE"
  def normalize_symbol(symbol), do: symbol

  # Compares two sets of pairs.
  @spec compare_pair_sets(MapSet.t(String.t()), MapSet.t(String.t())) :: {:ok, :no_changes | :changes}
  def compare_pair_sets(old_pairs, new_pairs) do
    if MapSet.equal?(old_pairs, new_pairs) do
      {:ok, :no_changes}
    else
      {:ok, :changes}
    end
  end
end
