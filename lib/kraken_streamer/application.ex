defmodule KrakenStreamer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      KrakenStreamerWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:kraken_streamer, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: KrakenStreamer.PubSub},
      # Start a WebSocket client to receive ticker data
      {KrakenStreamer.WebSocket.Client, %{}},
      # Start a PairsManager to fetch and manage trading pairs
      {KrakenStreamer.Pairs.Manager, %{}},
      # Start to serve requests, typically the last entry
      KrakenStreamerWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KrakenStreamer.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KrakenStreamerWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
