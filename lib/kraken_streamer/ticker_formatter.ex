defmodule KrakenStreamer.TickerFormatter do
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
  Validates and formats a map of ticker data.

  Takes a map where keys are ticker symbols and values are maps containing
  ask and bid prices. Validates the structure and formats the prices with
  appropriate precision.

  ## Parameters

  - `tickers`: Map of ticker symbols to their data (ask/bid prices)

  ## Returns

  - `{:ok, formatted_tickers}` - Validation and formatting successful
  - `{:error, reason}` - Failed validation with error message

  ## Examples

      iex> validate_and_format_tickers(%{"BTC/USD" => %{ask: 50000.0, bid: 49950.0}})
      {:ok, %{"BTC/USD" => %{ask: "50000.00", bid: "49950.00"}}}

      iex> validate_and_format_tickers(%{"ETH/USD" => %{ask: "invalid", bid: 1800.0}})
      {:error, "Invalid ticker data: ..."}
  """
  @spec validate_and_format_tickers(tickers_map()) :: validation_result()
  def validate_and_format_tickers(tickers) when is_map(tickers) do
    try do
      formatted_tickers =
        tickers
        |> Enum.map(fn {symbol, data} ->
          # Validate symbol first
          with true <- is_binary(symbol),
               true <- symbol != "",
               true <- is_map(data),
               ask when not is_nil(ask) <- Map.get(data, :ask),
               bid when not is_nil(bid) <- Map.get(data, :bid),
               true <- is_number(ask) and is_number(bid) do
            # Format the prices using dynamic_format
            formatted_data = %{
              ask: convert_to_float(ask) |> dynamic_format(),
              bid: convert_to_float(bid) |> dynamic_format()
            }

            {symbol, formatted_data}
          else
            false when not is_binary(symbol) ->
              raise "Symbol must be a string, got: #{inspect(symbol)}"

            false when symbol == "" ->
              raise "Symbol cannot be empty"

            nil ->
              raise "Missing ask or bid value for #{inspect(symbol)}"

            false ->
              raise "Invalid data type for #{inspect(symbol)}: #{inspect(data)}"

            value ->
              raise "Invalid value in ticker data: #{inspect(value)}"
          end
        end)
        |> Map.new()

      {:ok, formatted_tickers}
    rescue
      e ->
        {:error, "Invalid ticker data: #{Exception.message(e)}"}
    end
  end

  @doc """
  Handles validation for non-map inputs.

  ## Parameters

  - `invalid_data`: Any non-map data that was incorrectly passed to the validator

  ## Returns

  - `{:error, reason}` - Error message indicating invalid input type
  """
  @spec validate_and_format_tickers(term()) :: {:error, String.t()}
  def validate_and_format_tickers(invalid_data) do
    {:error, "Expected map for ticker data, got: #{inspect(invalid_data)}"}
  end

  @doc """
  Converts various data types to float for consistent handling.

  ## Parameters

  - `value`: A value that needs to be converted to float

  ## Returns

  - A float value if conversion is possible
  - `nil` if conversion fails

  ## Examples

      iex> convert_to_float(123)
      123.0

      iex> convert_to_float("45.67")
      45.67

      iex> convert_to_float("invalid")
      nil
  """
  @spec convert_to_float(float()) :: float()
  def convert_to_float(value) when is_float(value), do: value

  @spec convert_to_float(integer()) :: float()
  def convert_to_float(value) when is_integer(value), do: value * 1.0

  @spec convert_to_float(String.t()) :: float() | nil
  def convert_to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ -> nil
    end
  end

  @spec convert_to_float(term()) :: nil
  def convert_to_float(_), do: nil

  @doc """
  Formats floating point values with dynamic precision based on magnitude.

  Larger values get fewer decimal places, while smaller values get more
  decimal places to maintain readability.

  ## Precision Rules

  - Values ≥ 1: 2 decimal places
  - Values ≥ 0.01: 4 decimal places
  - Values ≥ 0.0001: 6 decimal places
  - Values ≥ 0.000001: 8 decimal places
  - Smaller values: 10 decimal places

  ## Parameters

  - `value`: The float value to format

  ## Returns

  - Formatted string with appropriate precision

  ## Examples

      iex> dynamic_format(1234.5678)
      "1234.57"

      iex> dynamic_format(0.00345678)
      "0.003457"
  """
  @spec dynamic_format(float()) :: String.t()
  def dynamic_format(value) when is_float(value) do
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
