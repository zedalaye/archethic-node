defmodule Uniris.DB.CassandraImpl.Migrations.CreateChainLookupByLastAddressTable do
  def execute do
    Xandra.execute!(:xandra_conn, """
    CREATE TABLE IF NOT EXISTS uniris.chain_lookup_by_last_address(
      transaction_address blob,
      last_transaction_address blob,
      timestamp timestamp,
      PRIMARY KEY (transaction_address, timestamp)
    ) WITH CLUSTERING ORDER BY (timestamp DESC);
    """)
  end
end
