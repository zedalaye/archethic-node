defmodule ArchethicTest do
  use ArchethicCase

  alias Archethic.{Crypto, PubSub, P2P, P2P.Message, P2P.Node, TransactionChain}
  alias Archethic.{BeaconChain.SummaryTimer, SharedSecrets}
  alias Archethic.SelfRepair
  alias Archethic.SelfRepair.NetworkChain

  alias Message.{Balance, GetBalance, GetLastTransactionAddress, GetTransaction, Ok}
  alias Message.{GetTransactionChainLength, GetTransactionInputs, LastTransactionAddress}
  alias Message.{NotFound, StartMining, TransactionChainLength, TransactionInputList}
  alias Message.{NewTransaction}

  alias TransactionChain.{Transaction, TransactionData, Transaction.ValidationStamp}
  alias TransactionChain.{TransactionInput, VersionedTransactionInput}

  import ArchethicCase, only: [setup_before_send_tx: 0]

  import Mox
  import Mock
  setup :set_mox_global

  setup do
    setup_before_send_tx()

    :ok
  end

  describe "should follow sequence of checks when sending Transaction" do
    test "should forward Transaction, Current Node Unauthorized and Available" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: false,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: "node2",
        last_public_key: "node2",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: "node3",
        last_public_key: "node3",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)

      MockClient
      |> expect(:send_message, 1, fn
        _, %NewTransaction{}, _ ->
          {:ok, %Ok{}}
      end)

      assert :ok = Archethic.send_new_transaction(tx)
      Process.sleep(10)
    end

    test "should send StartMining Message, Current Node Synchronized and Available" do
      nss_genesis_address = "nss_genesis_address"
      nss_last_address = "nss_last_address"
      :persistent_term.put(:node_shared_secrets_gen_addr, nss_genesis_address)

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-20_000)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: "node2",
        last_public_key: "node2",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: "node3",
        last_public_key: "node3",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      start_supervised!({SummaryTimer, Application.get_env(:archethic, SummaryTimer)})

      now = DateTime.utc_now()

      MockDB
      |> stub(:get_last_chain_address, fn ^nss_genesis_address ->
        {nss_last_address, now}
      end)
      |> stub(
        :get_transaction,
        fn
          ^nss_last_address, [validation_stamp: [:timestamp]], :chain ->
            {:ok,
             %Transaction{
               validation_stamp: %ValidationStamp{
                 timestamp: SharedSecrets.get_last_scheduling_date(now)
               }
             }}

          _, _, _ ->
            {:error, :transaction_not_exists}
        end
      )

      MockClient
      |> expect(:send_message, 3, fn
        _, %StartMining{}, _ ->
          {:ok, %Ok{}}
      end)

      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)
      assert :ok = Archethic.send_new_transaction(tx)
    end

    test "should forward Transaction & Start Repair,  Current Node Not Synchronized" do
      nss_genesis_address = "nss_genesis_address"
      nss_last_address = "nss_last_address"
      :persistent_term.put(:node_shared_secrets_gen_addr, nss_genesis_address)

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-20_000)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: "node2",
        last_public_key: "node2",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: "node3",
        last_public_key: "node3",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      start_supervised!({SummaryTimer, Application.get_env(:archethic, SummaryTimer)})

      MockDB
      |> stub(:get_last_chain_address, fn ^nss_genesis_address ->
        {nss_last_address, DateTime.utc_now()}
      end)
      |> stub(
        :get_transaction,
        fn
          ^nss_last_address, [validation_stamp: [:timestamp]], :chain ->
            {:ok,
             %Transaction{
               validation_stamp: %ValidationStamp{
                 timestamp: DateTime.utc_now() |> DateTime.add(-86_400)
               }
             }}

          _, _, _ ->
            {:error, :transaction_not_exists}
        end
      )

      me = self()

      MockClient
      |> stub(:send_message, fn
        # validate nss chain from network
        # anticippated to be failed
        _, %GetLastTransactionAddress{}, _ ->
          {:ok, %LastTransactionAddress{address: "willnotmatchaddress"}}

        _, %NewTransaction{transaction: _, welcome_node: _}, _ ->
          # forward the tx
          send(me, :new_transaction)
          {:ok, %Ok{}}
      end)

      # last address is d/f it returns last address from quorum
      assert {:error, ["willnotmatchaddress"]} =
               NetworkChain.verify_synchronization(:node_shared_secrets)

      # trying to ssend a tx when NSS chain not synced
      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)

      with_mock(SelfRepair, resync: fn _, _, _ -> :ok end) do
        assert :ok = Archethic.send_new_transaction(tx)
        assert_receive :new_transaction, 100
        assert_called(SelfRepair.resync(:_, :_, :_))
      end
    end

    test "Should forward Transaction until StartMining message is sent without Node Loop & Message Waiting" do
      nss_genesis_address = "nss_genesis_address"
      nss_last_address = "nss_last_address"
      :persistent_term.put(:node_shared_secrets_gen_addr, nss_genesis_address)

      welcome_node = Crypto.first_node_public_key()
      second_node_first_public_key = "node2"

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-20_000)
      })

      P2P.add_and_connect_node(%Node{
        ip: {122, 12, 0, 5},
        port: 3000,
        first_public_key: second_node_first_public_key,
        last_public_key: second_node_first_public_key,
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      start_supervised!({SummaryTimer, Application.get_env(:archethic, SummaryTimer)})

      MockDB
      |> stub(:get_last_chain_address, fn ^nss_genesis_address ->
        {nss_last_address, DateTime.utc_now()}
      end)
      |> stub(
        :get_transaction,
        fn
          ^nss_last_address, [validation_stamp: [:timestamp]], :chain ->
            {:ok,
             %Transaction{
               validation_stamp: %ValidationStamp{
                 timestamp: DateTime.utc_now() |> DateTime.add(-86_400)
               }
             }}

          _, _, _ ->
            {:error, :transaction_not_exists}
        end
      )

      me = self()

      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)

      MockClient
      |> expect(:send_message, 5, fn
        # validate nss chain from network , anticippated to be failed
        _, %GetLastTransactionAddress{}, _ ->
          {:ok, %LastTransactionAddress{address: "willnotmatchaddress"}}

        %Node{first_public_key: ^second_node_first_public_key},
        %NewTransaction{transaction: ^tx, welcome_node: ^welcome_node},
        _ ->
          send(me, {:forwarded_to_node2, tx})
          {:ok, %Ok{}}

        _, %GetTransaction{address: _}, _ ->
          {:ok, %NotFound{}}

        _, %StartMining{transaction: ^tx, welcome_node_public_key: ^welcome_node}, _ ->
          # we are not handling CONSENSUS DFW order in prelimeinay checks for send transaction
          # we rely completely on DFW to handle it.
          {:ok, %Ok{}}
      end)

      # last address is d/f it returns last address from quorum
      assert {:error, ["willnotmatchaddress"]} =
               NetworkChain.verify_synchronization(:node_shared_secrets)

      # trying to ssend a tx when NSS chain not synced
      with_mock(SelfRepair, resync: fn _, _, _ -> :ok end) do
        assert :ok = Archethic.send_new_transaction(tx)
        assert_receive {:forwarded_to_node2, ^tx}, 100

        assert_called(SelfRepair.resync(:_, :_, :_))
      end

      Process.sleep(100)
      assert :ok = Archethic.send_new_transaction(tx)
    end
  end

  describe "search_transaction/1" do
    test "should request storage nodes and return the transaction" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.last_node_public_key(),
        last_public_key: Crypto.last_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> expect(:send_message, fn _, %GetTransaction{}, _ ->
        {:ok, %Transaction{address: "@Alice2"}}
      end)

      assert {:ok, %Transaction{address: "@Alice2"}} = Archethic.search_transaction("@Alice2")
    end

    test "should request storage nodes and return not exists as the transaction not exists" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.last_node_public_key(),
        last_public_key: Crypto.last_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> expect(:send_message, fn _, %GetTransaction{}, _ ->
        {:ok, %NotFound{}}
      end)

      assert {:error, :transaction_not_exists} = Archethic.search_transaction("@Alice2")
    end
  end

  describe "send_new_transaction/1" do
    test "should elect validation nodes and broadcast the transaction" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now() |> DateTime.add(-1)
      })

      tx = Transaction.new(:transfer, %TransactionData{}, "seed", 0)

      MockClient
      |> expect(:send_message, fn _, %StartMining{}, _ ->
        Process.sleep(20)
        PubSub.notify_new_transaction(tx.address)
        {:ok, %Ok{}}
      end)

      assert :ok = Archethic.send_new_transaction(tx)
    end
  end

  describe "get_last_transaction/1" do
    test "should request storages nodes to fetch the last transaction" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.last_node_public_key(),
        last_public_key: Crypto.last_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: :crypto.strong_rand_bytes(32),
        last_public_key: :crypto.strong_rand_bytes(32),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> stub(:send_message, fn
        _, %GetLastTransactionAddress{address: address}, _ ->
          {:ok, %LastTransactionAddress{address: address, timestamp: DateTime.utc_now()}}

        _, %GetTransaction{}, _ ->
          {:ok, %Transaction{previous_public_key: "Alice1"}}
      end)

      assert {:ok, %Transaction{previous_public_key: "Alice1"}} =
               Archethic.get_last_transaction(Crypto.hash("Alice1"))
    end

    test "should request storages nodes to fetch the last transaction but not exists" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.last_node_public_key(),
        last_public_key: Crypto.last_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA",
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: :crypto.strong_rand_bytes(32),
        last_public_key: :crypto.strong_rand_bytes(32),
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> stub(:send_message, fn
        _, %GetLastTransactionAddress{address: address}, _ ->
          {:ok, %LastTransactionAddress{address: address, timestamp: DateTime.utc_now()}}

        _, %GetTransaction{}, _ ->
          {:ok, %NotFound{}}
      end)

      assert {:error, :transaction_not_exists} =
               Archethic.get_last_transaction(Crypto.hash("Alice1"))
    end
  end

  describe "get_balance/1" do
    test "should request storage nodes to fetch the balance" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.last_node_public_key(),
        last_public_key: Crypto.last_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key2",
        last_public_key: "key2",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> expect(:send_message, 1, fn
        _, %GetBalance{}, _ ->
          {:ok,
           %Balance{
             uco: 1_000_000_000,
             token: %{
               {"ETH", 1} => 1
             }
           }}
      end)
      |> expect(:send_message, 1, fn
        _, %GetBalance{}, _ ->
          {:ok,
           %Balance{
             uco: 2_000_000_000,
             token: %{
               {"BTC", 2} => 1,
               {"ETH", 1} => 2
             }
           }}
      end)

      assert {:ok,
              %{
                uco: 2_000_000_000,
                token: %{
                  {"ETH", 1} => 2,
                  {"BTC", 2} => 1
                }
              }} = Archethic.get_balance("@Alice2")
    end
  end

  describe "get_transaction_inputs/1" do
    test "should request the storages nodes to fetch the inputs remotely, this is latest tx" do
      address1 = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> stub(:send_message, fn
        _, %GetTransactionInputs{address: ^address1}, _ ->
          {:ok,
           %TransactionInputList{
             inputs: [
               %VersionedTransactionInput{
                 input: %TransactionInput{
                   from: "@Bob3",
                   amount: 1_000_000_000,
                   spent?: false,
                   type: :UCO,
                   timestamp: DateTime.utc_now()
                 },
                 protocol_version: 1
               }
             ]
           }}

        _, %GetLastTransactionAddress{address: ^address1}, _ ->
          {:ok, %LastTransactionAddress{address: address1, timestamp: DateTime.utc_now()}}
      end)

      assert [%TransactionInput{from: "@Bob3", amount: 1_000_000_000, spent?: false, type: :UCO}] =
               Archethic.get_transaction_inputs(address1)
    end

    test "should request the storages nodes to fetch the inputs remotely, inputs are spent in a later tx" do
      address1 = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      address1bis = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> stub(:send_message, fn
        _, %GetTransactionInputs{address: ^address1}, _ ->
          {:ok,
           %TransactionInputList{
             inputs: [
               %VersionedTransactionInput{
                 input: %TransactionInput{
                   from: "@Bob3",
                   amount: 1_000_000_000,
                   spent?: false,
                   type: :UCO,
                   timestamp: DateTime.utc_now()
                 },
                 protocol_version: 1
               }
             ]
           }}

        _, %GetTransactionInputs{address: ^address1bis}, _ ->
          {:ok,
           %TransactionInputList{
             inputs: []
           }}

        _, %GetLastTransactionAddress{address: ^address1}, _ ->
          {:ok, %LastTransactionAddress{address: address1bis, timestamp: DateTime.utc_now()}}
      end)

      assert [%TransactionInput{from: "@Bob3", amount: 1_000_000_000, spent?: true, type: :UCO}] =
               Archethic.get_transaction_inputs(address1)
    end

    test "should request the storages nodes to fetch the inputs remotely, inputs are not spent in a later tx" do
      address1 = <<0::8, 0::8, :crypto.strong_rand_bytes(32)::binary>>
      address1bis = Crypto.derive_address(address1)

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.first_node_public_key(),
        last_public_key: Crypto.first_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> stub(:send_message, fn
        _, %GetTransactionInputs{address: ^address1}, _ ->
          {:ok,
           %TransactionInputList{
             inputs: [
               %VersionedTransactionInput{
                 input: %TransactionInput{
                   from: "@Bob3",
                   amount: 1_000_000_000,
                   spent?: false,
                   type: :UCO,
                   timestamp: DateTime.utc_now()
                 },
                 protocol_version: 1
               }
             ]
           }}

        _, %GetTransactionInputs{address: ^address1bis}, _ ->
          {:ok,
           %TransactionInputList{
             inputs: [
               %VersionedTransactionInput{
                 input: %TransactionInput{
                   from: "@Bob3",
                   amount: 1_000_000_000,
                   spent?: false,
                   type: :UCO,
                   timestamp: DateTime.utc_now()
                 },
                 protocol_version: 1
               }
             ]
           }}

        _, %GetLastTransactionAddress{address: ^address1}, _ ->
          {:ok, %LastTransactionAddress{address: address1bis, timestamp: DateTime.utc_now()}}
      end)

      assert [%TransactionInput{from: "@Bob3", amount: 1_000_000_000, spent?: false, type: :UCO}] =
               Archethic.get_transaction_inputs(address1)
    end
  end

  describe "get_transaction_chain_length/1" do
    test "should request the storage node to fetch the transaction chain length" do
      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: Crypto.last_node_public_key(),
        last_public_key: Crypto.last_node_public_key(),
        network_patch: "AAA",
        geo_patch: "AAA"
      })

      P2P.add_and_connect_node(%Node{
        ip: {127, 0, 0, 1},
        port: 3000,
        first_public_key: "key1",
        last_public_key: "key1",
        network_patch: "AAA",
        geo_patch: "AAA",
        available?: true,
        authorized?: true,
        authorization_date: DateTime.utc_now()
      })

      MockClient
      |> stub(:send_message, fn
        _, %GetLastTransactionAddress{}, _ ->
          {:ok, %LastTransactionAddress{address: "@Alice2"}}

        _, %GetTransactionChainLength{}, _ ->
          {:ok, %TransactionChainLength{length: 3}}
      end)

      assert {:ok, 3} == Archethic.get_transaction_chain_length("@Alice2")
    end
  end
end
