defmodule ArchEthic.Metrics.Collector.MetricsEndpoint do
  @moduledoc """
  This module provides a REST endpoint for metrics.
  """

  alias ArchEthic.Metrics.Collector

  @behaviour Collector

  @node_metric_endpoint_uri "/metrics"
  @node_metric_request_type "GET"

  @impl Collector
  def fetch_metrics(ip_address) do
    with {:ok, conn_ref} <- establish_connection(ip_address),
         {:ok, conn, _req_ref} <- request(conn_ref) do
      stream_responses(conn)
    end
  end

  defp establish_connection(ip) do
    port =
      Application.get_env(:archethic, ArchEthicWeb.Endpoint)
      |> Keyword.get(:http)
      |> Keyword.get(:port)

    Mint.HTTP.connect(:http, ip |> :inet.ntoa() |> to_string(), port)
  end

  defp request(conn_ref) do
    Mint.HTTP.request(
      conn_ref,
      @node_metric_request_type,
      @node_metric_endpoint_uri,
      [],
      []
    )
  end

  defp stream_responses(conn) do
    receive do
      message ->
        with {:ok, conn, [{:status, _, 200}, {:headers, _, _}, {:data, _, data}, {:done, _}]} <-
               Mint.HTTP.stream(conn, message),
             {:ok, _} <- Mint.HTTP.close(conn) do
          {:ok, data}
        end
    after
      5_000 ->
        {:error, :timeout}
    end
  end
end
