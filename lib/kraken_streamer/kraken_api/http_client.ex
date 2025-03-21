defmodule KrakenStreamer.KrakenAPI.HTTPClient do
  @moduledoc """
  HTTP client behavior and implementation for making requests to Kraken API.
  Supports dependency injection for testing.
  """

  @type response :: {:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}

  @callback get(String.t()) :: response

  @doc """
  Makes a GET request to the specified URL.
  Uses the configured HTTP client (defaults to HTTPoison).
  """
  @spec get(String.t()) :: response
  def get(url), do: impl().get(url)

  @doc """
  Returns the configured HTTP client implementation.
  Defaults to HTTPoison if not configured.
  """
  @spec impl() :: module()
  def impl, do: Application.get_env(:kraken_streamer, :http_client, HTTPoison)
end
