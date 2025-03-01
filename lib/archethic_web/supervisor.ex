defmodule ArchethicWeb.Supervisor do
  @moduledoc false

  use Supervisor

  alias Archethic.Utils

  alias ArchethicCache.{LRU, LRUDisk}

  alias ArchethicWeb.{
    Endpoint,
    TransactionCache,
    FaucetRateLimiter,
    TransactionSubscriber,
    ExplorerLive.TopTransactionsCache
  }

  require Logger

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec init(any) :: {:ok, {Supervisor.sup_flags(), list(Supervisor.child_spec())}}
  def init(_) do
    children =
      [
        web_hosting_cache_ref_tx(),
        web_hosting_cache_file(),
        FaucetRateLimiter,
        TransactionCache,
        TopTransactionsCache,
        TransactionSubscriber,
        {Phoenix.PubSub, [name: ArchethicWeb.PubSub, adapter: Phoenix.PubSub.PG2]},
        {PlugAttack.Storage.Ets, name: ArchethicWeb.PlugAttack.Storage, clean_period: 60_000},
        Endpoint,
        {Absinthe.Subscription, Endpoint}
      ]
      |> Utils.configurable_children()

    opts = [strategy: :one_for_one]
    Supervisor.init(children, opts)
  end

  # this is used in web_hosting_controller.ex
  # it does not store an entire transaction, but a triplet {address, json_content, timestamp}
  defp web_hosting_cache_ref_tx() do
    %{
      id: :web_hosting_cache_ref_tx,
      start:
        {LRU, :start_link,
         [
           :web_hosting_cache_ref_tx,
           web_hosting_config(:tx_cache_bytes)
         ]}
    }
  end

  defp web_hosting_cache_file() do
    %{
      id: :web_hosting_cache_file,
      start:
        {LRUDisk, :start_link,
         [
           :web_hosting_cache_file,
           web_hosting_config(:file_cache_bytes),
           Path.join(Utils.mut_dir(), "aeweb")
         ]}
    }
  end

  defp web_hosting_config(key) do
    config = Application.fetch_env!(:archethic, ArchethicWeb.API.WebHostingController)
    Keyword.get(config, key)
  end
end
