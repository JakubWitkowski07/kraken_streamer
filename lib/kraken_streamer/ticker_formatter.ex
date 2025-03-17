defmodule KrakenStreamer.TickerFormatter do
  # Validates and formats ticker data.
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

  # Handle case when input is not a map
  def validate_and_format_tickers(invalid_data) do
    {:error, "Expected map for ticker data, got: #{inspect(invalid_data)}"}
  end

  # Converts various types to float for consistent handling.
  def convert_to_float(value) when is_float(value), do: value
  def convert_to_float(value) when is_integer(value), do: value * 1.0

  def convert_to_float(value) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ -> nil
    end
  end

  def convert_to_float(_), do: nil

  # Formats floating point values with dynamic precision, e.g. 3.23e-6 to 0.00000323
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
