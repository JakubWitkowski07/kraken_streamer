defmodule KrakenStreamer.KrakenAPI.HTTPClient do
  @type response :: {:ok, %HTTPoison.Response{}} | {:error, %HTTPoison.Error{}}

  @callback get(String.t()) :: response


  @spec get(String.t()) :: response
  def get(url), do: impl().get(url)


  @spec impl() :: module()
  def impl, do: Application.get_env(:kraken_streamer, :http_client, HTTPoison)
end
