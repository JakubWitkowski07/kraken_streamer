ExUnit.start()

Mox.defmock(KrakenStreamer.KrakenAPI.MockHTTPClient, for: KrakenStreamer.KrakenAPI.HTTPClient)
Application.put_env(:kraken_streamer, :http_client, KrakenStreamer.KrakenAPI.MockHTTPClient)
