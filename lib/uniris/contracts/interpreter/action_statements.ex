defmodule Uniris.Contracts.Interpreter.ActionStatements do
  @moduledoc false

  alias Uniris.Contracts.Contract

  alias Uniris.TransactionChain.Transaction
  alias Uniris.TransactionChain.TransactionData.NFTLedger
  alias Uniris.TransactionChain.TransactionData.UCOLedger

  @doc """
  Return the atom used in the action statements
  """
  @spec allowed_atoms() :: list(atom())
  def allowed_atoms do
    [
      :set_type,
      :add_uco_transfer,
      :add_nft_transfer,
      :set_content,
      :set_code,
      :set_secret,
      :add_authorized_key,
      :add_recipient,
      :to,
      :amount,
      :nft,
      :public_key,
      :encrypted_secret_key
    ]
  end

  @doc """
  Set the transaction type

  ## Examples

       iex> ActionStatements.set_type(%Contract{}, :transfer)
       %Contract{ next_transaction: %Transaction{type: :transfer, data: %TransactionData{}} }
  """
  @spec set_type(Contract.t(), Transaction.transaction_type()) :: Contract.t()
  def set_type(contract = %Contract{}, type) do
    put_in(contract, access_path([:next_transaction, :type]), type)
  end

  @doc """
  Add a UCO transfer

  ## Examples

      iex> ActionStatements.add_uco_transfer(%Contract{}, 
      ...>  to: "22368B50D3B2976787CFCC27508A8E8C67483219825F998FC9D6908D54D0FE10", 
      ...>  amount: 10.04
      ...> )
      %Contract{
          next_transaction: %Transaction{
            data: %TransactionData{
                ledger: %Ledger{
                    uco: %UCOLedger{
                        transfers: [
                            %UCOLedger.Transfer{
                                to: <<34, 54, 139, 80, 211, 178, 151, 103, 135, 207, 204, 39, 80, 138, 142, 140,
                                        103, 72, 50, 25, 130, 95, 153, 143, 201, 214, 144, 141, 84, 208, 254, 16>>,
                                amount: 10.04
                            }
                        ]
                    }
                }
            }
        }
      }
  """
  @spec add_uco_transfer(Contract.t(), to: binary(), amount: float()) :: Contract.t()
  def add_uco_transfer(contract = %Contract{}, opts \\ []) when is_list(opts) do
    to = Keyword.fetch!(opts, :to)
    amount = Keyword.fetch!(opts, :amount)

    update_in(
      contract,
      access_path([:next_transaction, :data, :ledger, :uco, :transfers]),
      &[%UCOLedger.Transfer{to: decode_binary(to), amount: amount} | &1]
    )
  end

  @doc """
  Add a NFT transfer

  ## Examples

      iex> ActionStatements.add_nft_transfer(%Contract{},
      ...>   to: "22368B50D3B2976787CFCC27508A8E8C67483219825F998FC9D6908D54D0FE10", 
      ...>   amount: 10.0, 
      ...>   nft: "70541604258A94B76DB1F1AF5A2FC2BEF165F3BD9C6B7DDB3F1ACC628465E528"
      ...> )
      %Contract{
          next_transaction: %Transaction{
            data: %TransactionData{
                ledger: %Ledger{
                  nft: %NFTLedger{
                      transfers: [
                          %NFTLedger.Transfer{
                              to: <<34, 54, 139, 80, 211, 178, 151, 103, 135, 207, 204, 39, 80, 138, 142, 140,
                                103, 72, 50, 25, 130, 95, 153, 143, 201, 214, 144, 141, 84, 208, 254, 16>>,
                              amount: 10.0,
                              nft: <<112, 84, 22, 4, 37, 138, 148, 183, 109, 177, 241, 175, 90, 47, 194, 190, 241, 101, 243, 
                                189, 156, 107, 125, 219, 63, 26, 204, 98, 132, 101, 229, 40>>
                          }
                      ]
                  }
              }
            }
        }
      }
  """
  @spec add_nft_transfer(Contract.t(), to: binary(), amount: float(), nft: binary()) ::
          Contract.t()
  def add_nft_transfer(contract = %Contract{}, opts \\ []) when is_list(opts) do
    to = Keyword.fetch!(opts, :to)
    amount = Keyword.fetch!(opts, :amount)
    nft_address = Keyword.fetch!(opts, :nft)

    update_in(
      contract,
      access_path([:next_transaction, :data, :ledger, :nft, :transfers]),
      &[
        %NFTLedger.Transfer{
          to: decode_binary(to),
          amount: amount,
          nft: decode_binary(nft_address)
        }
        | &1
      ]
    )
  end

  @doc ~S"""
  Set transaction data content

  ## Examples

        iex> ActionStatements.set_content(%Contract{}, "hello")
        %Contract{
            next_transaction: %Transaction{
                data: %TransactionData{
                    content: "hello"
                }
            }
        }
  """
  def set_content(contract = %Contract{}, content) when is_binary(content) do
    put_in(contract, access_path([:next_transaction, :data, :content]), decode_binary(content))
  end

  @doc ~S"""
  Set transaction smart contract code

  ## Examples

        iex> ActionStatements.set_code(%Contract{}, "condition origin_family: biometric")
        %Contract{
            next_transaction: %Transaction{
                data: %TransactionData{
                    code: "condition origin_family: biometric"
                }
            }
        }
  """
  def set_code(contract = %Contract{}, code) when is_binary(code) do
    put_in(contract, access_path([:next_transaction, :data, :code]), code)
  end

  @doc """
  Add an authorized public key to read the secret with an encrypted key

  ## Examples

      iex> ActionStatements.add_authorized_key(%Contract{},
      ...>   public_key: "22368B50D3B2976787CFCC27508A8E8C67483219825F998FC9D6908D54D0FE10", 
      ...>   encrypted_secret_key: "FB49F76933689ECC9D260D57C2BEF9489234FE72DD2ED1C77E2E8B4E94D9137F"
      ...> )
      %Contract{
          next_transaction: %Transaction{
            data: %TransactionData{
                keys: %Keys{
                    authorized_keys: %{
                        <<34, 54, 139, 80, 211, 178, 151, 103, 135, 207, 204, 39, 80, 138, 142, 140,
                            103, 72, 50, 25, 130, 95, 153, 143, 201, 214, 144, 141, 84, 208, 254, 16>> => 
                                <<251, 73, 247, 105, 51, 104, 158, 204, 157, 38, 13, 87, 194, 190, 249, 72, 146,
                                52, 254, 114, 221, 46, 209, 199, 126, 46, 139, 78, 148, 217, 19, 127>>
                    }
                }
            }
        }
      }
  """
  @spec add_authorized_key(Contract.t(), public_key: binary(), encrypted_secret_key: binary()) ::
          Contract.t()
  def add_authorized_key(contract = %Contract{}, opts \\ []) when is_list(opts) do
    public_key = Keyword.fetch!(opts, :public_key)
    encrypted_secret_key = Keyword.fetch!(opts, :encrypted_secret_key)

    update_in(
      contract,
      access_path([:next_transaction, :data, :keys, :authorized_keys]),
      &Map.put(&1, decode_binary(public_key), decode_binary(encrypted_secret_key))
    )
  end

  @doc ~S"""
  Set the transaction encrypted secret

  ## Examples

      iex> ActionStatements.set_secret(%Contract{}, "mysecret")
      %Contract{
          next_transaction: %Transaction{
            data: %TransactionData{
                keys: %Keys{
                    secret: "mysecret"
                }
            }
        }
      }
  """
  @spec set_secret(Contract.t(), binary()) :: Contract.t()
  def set_secret(contract = %Contract{}, secret) when is_binary(secret) do
    put_in(
      contract,
      access_path([:next_transaction, :data, :keys, :secret]),
      decode_binary(secret)
    )
  end

  @doc """
  Add an recipient

  ## Examples

      iex> ActionStatements.add_recipient(%Contract{}, "22368B50D3B2976787CFCC27508A8E8C67483219825F998FC9D6908D54D0FE10")
      %Contract{
        next_transaction: %Transaction{
          data: %TransactionData{
            recipients: [<<34, 54, 139, 80, 211, 178, 151, 103, 135, 207, 204, 39, 80, 138, 142, 140,
                          103, 72, 50, 25, 130, 95, 153, 143, 201, 214, 144, 141, 84, 208, 254, 16>>]
          }
        }
      }
  """
  @spec add_recipient(Contract.t(), binary()) :: Contract.t()
  def add_recipient(contract = %Contract{}, recipient_address)
      when is_binary(recipient_address) do
    update_in(
      contract,
      access_path([:next_transaction, :data, :recipients]),
      &[decode_binary(recipient_address) | &1]
    )
  end

  defp access_path(list), do: Enum.map(list, &Access.key(&1, %{}))

  defp decode_binary(bin) do
    if String.printable?(bin) do
      case Base.decode16(bin, case: :mixed) do
        {:ok, hex} ->
          hex

        _ ->
          bin
      end
    else
      bin
    end
  end
end
