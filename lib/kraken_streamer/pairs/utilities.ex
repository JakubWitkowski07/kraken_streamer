defmodule KrakenStreamer.Pairs.Utilities do
  @moduledoc """
  Utility functions for handling trading pairs.
  Provides pair normalization, batching, and comparison functionality.
  """

  require Logger

  @batch_size Application.compile_env(:kraken_streamer, KrakenStreamer.Pairs.Utilities)[:batch_size]

  @doc """
  Splits trading pairs into batches for efficient processing.

  ## Parameters
    * `pairs` - Set of trading pair strings

  ## Returns
    * List of {batch, index} tuples, where each batch has at most #{@batch_size} pairs
  """
  @spec batch_pairs(MapSet.t(String.t())) :: [{[String.t()], non_neg_integer()}]
  def batch_pairs(pairs) do
    pairs
    |> Enum.chunk_every(@batch_size)
    |> Enum.with_index()
  end

  @doc """
  Normalizes a list of trading pair strings.

  ## Examples
      iex> normalize_pairs(["XBT/USD", "XDG/EUR"])
      ["BTC/USD", "DOGE/EUR"]
  """
  @spec normalize_pairs([String.t()]) :: [String.t()]
  def normalize_pairs(pairs) when is_list(pairs) do
    pairs
    |> Enum.map(&normalize_pair/1)
  end

  @doc """
  Normalizes a single trading pair string.

  ## Examples
      iex> normalize_pair("XBT/USD")
      "BTC/USD"
  """
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

  @doc """
  Normalizes cryptocurrency symbols to their standard form.

  ## Examples
      iex> normalize_symbol("XBT")
      "BTC"
      iex> normalize_symbol("XDG")
      "DOGE"
  """
  @spec normalize_symbol(String.t()) :: String.t()
  def normalize_symbol("XBT"), do: "BTC"
  def normalize_symbol("XDG"), do: "DOGE"
  def normalize_symbol(symbol), do: symbol

  @doc """
  Compares two sets of pairs to detect changes.

  ## Returns
    * `{:ok, :no_changes}` - Sets are identical
    * `{:ok, :changes}` - Sets are different
  """
  @spec compare_pair_sets(MapSet.t(String.t()), MapSet.t(String.t())) ::
          {:ok, :no_changes | :changes}
  def compare_pair_sets(old_pairs, new_pairs) do
    if MapSet.equal?(old_pairs, new_pairs) do
      {:ok, :no_changes}
    else
      {:ok, :changes}
    end
  end
end
