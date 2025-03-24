defmodule KrakenStreamer.Pairs.ManagerTest do
  use ExUnit.Case
  import Mox

  # use KrakenStreamer.MockHTTPClient, async: true
  alias KrakenStreamer.Pairs.Manager

  setup :set_mox_global
  setup :verify_on_exit!


  setup do
    # Sample test data
    test_pairs = MapSet.new(["BTC/USD", "ETH/USD"])
    test_batches = [{["BTC/USD", "ETH/USD"], 0}]

    # Generate unique name for each test
    test_name = :"Manager#{System.unique_integer()}"

    {:ok, %{test_pairs: test_pairs, test_batches: test_batches, test_name: test_name}}
  end

  describe "initialization" do
    test "starts and fetches initial pairs", %{test_pairs: test_pairs, test_name: test_name} do
      # Mock the API response
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "error" => [],
               "result" => %{
                 "BTCUSD" => %{"wsname" => "BTC/USD"},
                 "ETHUSD" => %{"wsname" => "ETH/USD"}
               }
             })
         }}
      end)

      # Start the Manager with unique name
      {:ok, pid} = Manager.start_link(%{name: test_name})
      Manager.initialize_pairs_set(pid)
      # Give it some time to process the initialization message
      Process.sleep(100)

      # Get the state using :sys.get_state (useful for testing)
      state = :sys.get_state(pid)
      assert state.pairs == test_pairs
    end

    test "handles API error during initialization", %{test_name: test_name} do
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:error, %HTTPoison.Error{reason: "network error"}}
      end)

      {:ok, pid} = Manager.start_link(%{name: test_name})
      Manager.initialize_pairs_set(pid)
      Process.sleep(100)

      state = :sys.get_state(pid)
      assert state.pairs == MapSet.new()
      assert state.batches == []
    end
  end

  describe "pair updates" do
    test "handles no changes in pairs", %{test_pairs: test_pairs, test_name: test_name} do
      # First call for initialization
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, 2, fn _url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "error" => [],
               "result" => %{
                 "BTCUSD" => %{"wsname" => "BTC/USD"},
                 "ETHUSD" => %{"wsname" => "ETH/USD"}
               }
             })
         }}
      end)

      {:ok, pid} = Manager.start_link(%{name: test_name})
      Manager.initialize_pairs_set(pid)
      Process.sleep(100)

      # Trigger update manually instead of waiting for the interval
      send(pid, :update_pairs)
      Process.sleep(100)

      state = :sys.get_state(pid)
      assert state.pairs == test_pairs
    end

    test "handles changes in pairs", %{test_pairs: test_pairs, test_name: test_name} do
      # Initial pairs
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "error" => [],
               "result" => %{
                 "BTCUSD" => %{"wsname" => "BTC/USD"},
                 "ETHUSD" => %{"wsname" => "ETH/USD"}
               }
             })
         }}
      end)

      # Updated pairs
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "error" => [],
               "result" => %{
                 "BTCUSD" => %{"wsname" => "BTC/USD"},
                 "ETHUSD" => %{"wsname" => "ETH/USD"},
                 "DOGEUSD" => %{"wsname" => "DOGE/USD"}
               }
             })
         }}
      end)

      {:ok, pid} = Manager.start_link(%{name: test_name})
      Manager.initialize_pairs_set(pid)
      Process.sleep(100)

      # Initial state should have original pairs
      state = :sys.get_state(pid)
      assert state.pairs == test_pairs

      # Trigger update
      send(pid, :update_pairs)
      Process.sleep(100)

      # Updated state should have new pairs
      updated_state = :sys.get_state(pid)
      assert MapSet.member?(updated_state.pairs, "DOGE/USD")
    end

    test "handles API error during update", %{test_pairs: test_pairs, test_name: test_name} do
      # Successful initial fetch
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:ok,
         %HTTPoison.Response{
           status_code: 200,
           body:
             Jason.encode!(%{
               "error" => [],
               "result" => %{
                 "BTCUSD" => %{"wsname" => "BTC/USD"},
                 "ETHUSD" => %{"wsname" => "ETH/USD"}
               }
             })
         }}
      end)

      # Error during update
      KrakenStreamer.KrakenAPI.MockHTTPClient
      |> expect(:get, fn _url ->
        {:error, %HTTPoison.Error{reason: "network error"}}
      end)

      {:ok, pid} = Manager.start_link(%{name: test_name})
      Manager.initialize_pairs_set(pid)
      Process.sleep(100)

      initial_state = :sys.get_state(pid)
      assert initial_state.pairs == test_pairs

      # Trigger update
      send(pid, :update_pairs)
      Process.sleep(100)

      # State should remain unchanged after error
      error_state = :sys.get_state(pid)
      assert error_state == initial_state
    end
  end
end
