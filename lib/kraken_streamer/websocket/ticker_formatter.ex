defmodule KrakenStreamer.WebSocket.TickerFormatter do
  @moduledoc """
  Provides functionality for validating and formatting ticker data from cryptocurrency exchanges.

  This module is responsible for:
  - Validating the structure and data types of ticker information
  - Converting price values to consistent float formats
  - Formatting prices with appropriate decimal precision based on magnitude

  The formatter applies dynamic decimal precision to make values more readable:
  - Large values (≥1): 2 decimal places
  - Medium values (≥0.01): 4 decimal places
  - Small values: up to 10 decimal places for very small numbers
  """
  require Logger

  @typedoc """
  Raw ticker data structure with ask and bid prices
  """
  @type raw_ticker :: %{
          ask: number() | String.t() | nil,
          bid: number() | String.t() | nil
        }

  @typedoc """
  Formatted ticker data with string-formatted ask and bid prices
  """
  @type formatted_ticker :: %{
          ask: String.t(),
          bid: String.t()
        }

  @typedoc """
  Map of ticker data by symbol
  """
  @type tickers_map :: %{String.t() => raw_ticker()}

  @typedoc """
  Result of validation and formatting operation
  """
  @type validation_result :: {:ok, %{String.t() => formatted_ticker()}} | {:error, String.t()}

  @doc """
  Validates all tickers in a map and returns only valid ones.

  A ticker is considered valid if:
  - The symbol is a non-empty string
  - Both ask and bid prices are numbers
  - The ticker data structure matches the expected format

  ## Parameters

  - `tickers`: Map of ticker symbols to their data (ask/bid prices)

  ## Returns

  - `{:ok, valid_tickers}` - Map containing only valid tickers
  - `{:error, reason}` - Error message if input is invalid

  ## Examples

      iex> validate_all_tickers(%{"BTC/USD" => %{ask: 50000.0, bid: 49950.0}})
      {:ok, %{"BTC/USD" => %{ask: 50000.0, bid: 49950.0}}}

      iex> validate_all_tickers(%{"ETH/USD" => %{ask: "invalid", bid: 1800.0}})
      {:ok, %{}} # Invalid ticker is filtered out
  """
  @spec validate_all_tickers(tickers_map()) :: {:ok, tickers_map()} | {:error, String.t()}
  def validate_all_tickers(tickers) when is_map(tickers) do
    valid_tickers =
      Enum.filter(tickers, &validate_ticker/1)
      |> Map.new()

    {:ok, valid_tickers}
  end

  def validate_all_tickers(invalid_data) do
    Logger.error("Invalid tickers data during validation: #{inspect(invalid_data)}")
  end

  # Validates a single ticker.
  @doc false
  @spec validate_ticker({String.t(), raw_ticker()}) :: boolean()
  defp validate_ticker({symbol, %{ask: ask, bid: bid}}) do
    with {:ok, _symbol} <- validate_symbol(symbol),
         {:ok, _ask} <- validate_price(ask),
         {:ok, _bid} <- validate_price(bid) do
      true
    else
      {:error, reason} ->
        Logger.error("Invalid ticker data: #{reason}")
        false
    end
  end

  defp validate_ticker(invalid_data) do
    Logger.error("Invalid ticker data: #{inspect(invalid_data)}")
    false
  end

  # Validates the symbol of a ticker.
  @doc false
  @spec validate_symbol(term()) :: {:ok, String.t()} | {:error, String.t()}
  defp validate_symbol(symbol) do
    if is_binary(symbol) and symbol != "" do
      {:ok, symbol}
    else
      {:error, "Invalid symbol: #{inspect(symbol)}"}
    end
  end

  # Validates the price of a ticker.
  @doc false
  @spec validate_price(term()) :: {:ok, number()} | {:error, String.t()}
  defp validate_price(price) do
    if is_number(price) do
      {:ok, price}
    else
      {:error, "Invalid price: #{inspect(price)}"}
    end
  end

  @doc """
  Formats all tickers in a map with appropriate precision.

  Takes a map of tickers and formats their prices according to the following rules:
  - Values ≥ 1: 2 decimal places
  - Values ≥ 0.01: 4 decimal places
  - Values ≥ 0.0001: 6 decimal places
  - Values ≥ 0.000001: 8 decimal places
  - Smaller values: 10 decimal places

  ## Parameters

  - `tickers`: Map of ticker symbols to their data (ask/bid prices)

  ## Returns

  - `{:ok, formatted_tickers}` - Map with formatted price strings
  - `{:error, reason}` - Error message if formatting fails

  ## Examples

      iex> format_all_tickers(%{"BTC/USD" => %{ask: 50000.0, bid: 49950.0}})
      {:ok, %{"BTC/USD" => %{ask: "50000.00", bid: "49950.00"}}}

      iex> format_all_tickers(%{"ETH/USD" => %{ask: 0.00345678, bid: 0.00345}})
      {:ok, %{"ETH/USD" => %{ask: "0.003457", bid: "0.003450"}}}
  """
  @spec format_all_tickers(tickers_map()) :: validation_result()
  def format_all_tickers(tickers) when is_map(tickers) do
    formatted_tickers =
      Enum.map(tickers, &format_ticker/1)
      |> Map.new()

    {:ok, formatted_tickers}
  end

  def format_all_tickers(invalid_data) do
    Logger.error("Invalid tickers data during formatting: #{inspect(invalid_data)}")
  end

  # Formats a single ticker with appropriate precision.
  @doc false
  @spec format_ticker({String.t(), raw_ticker()}) :: {String.t(), formatted_ticker()}
  defp format_ticker({symbol, %{ask: ask, bid: bid}}) do
    {symbol,
     %{
       ask: convert_to_float(ask) |> dynamic_format(),
       bid: convert_to_float(bid) |> dynamic_format()
     }}
  end

  # Converts various data types to float for consistent handling.
  @doc false
  @spec convert_to_float(number() | String.t() | term()) :: float() | nil
  defp convert_to_float(value) when is_float(value), do: value
  defp convert_to_float(value) when is_integer(value), do: value * 1.0

  defp convert_to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ -> nil
    end
  end

  defp convert_to_float(_), do: nil

  # Formats floating point values with dynamic precision based on magnitude.
  @doc false
  @spec dynamic_format(float()) :: String.t()
  defp dynamic_format(value) when is_float(value) do
    # Determine precision
    precision =
      cond do
        abs(value) >= 1 -> 2
        abs(value) >= 0.01 -> 4
        abs(value) >= 0.0001 -> 6
        abs(value) >= 0.000001 -> 8
        true -> 10
      end

    # Convert to string with specified precision
    :erlang.float_to_binary(value, decimals: precision)
  end
end
