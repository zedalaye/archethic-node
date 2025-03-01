defmodule Archethic.TransactionChain.TransactionData.UCOLedgerTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Archethic.TransactionChain.TransactionData.UCOLedger
  alias Archethic.TransactionChain.TransactionData.UCOLedger.Transfer

  doctest UCOLedger

  property "symmetric serialization/deserialization of uco ledger" do
    check all(
            transfers <-
              StreamData.map_of(StreamData.binary(length: 32), StreamData.positive_integer())
          ) do
      transfers =
        Enum.map(transfers, fn {to, amount} ->
          %Transfer{
            to: <<0::8, 0::8>> <> to,
            amount: amount
          }
        end)

      {uco_ledger, _} =
        %UCOLedger{transfers: transfers}
        |> UCOLedger.serialize(1)
        |> UCOLedger.deserialize(1)

      assert uco_ledger.transfers == transfers
    end
  end
end
