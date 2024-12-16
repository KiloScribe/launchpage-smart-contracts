// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.8 <0.9.0;
pragma experimental ABIEncoderV2;

interface IHederaTokenService {
    /// Transfers cryptocurrency among two or more accounts by making the desired adjustments to their
    /// balances. Each transfer list can specify up to 10 adjustments. Each negative amount is withdrawn
    /// from the corresponding account (a sender), and each positive one is added to the corresponding
    /// account (a receiver). The amounts list must sum to zero. Each amount is a number of tinybars
    /// (there are 100,000,000 tinybars in one hbar).  If any sender account fails to have sufficient
    /// hbars, then the entire transaction fails, and none of those transfers occur, though the
    /// transaction fee is still charged. This transaction must be signed by the keys for all the sending
    /// accounts, and for any receiving accounts that have receiverSigRequired == true. The signatures
    /// are in the same order as the accounts, skipping those accounts that don't need a signature.
    struct AccountAmount {
        // The Account ID, as a solidity address, that sends/receives cryptocurrency or tokens
        address accountID;
        // The amount of  the lowest denomination of the given token that
        // the account sends(negative) or receives(positive)
        int64 amount;
    }

    /// A sender account, a receiver account, and the serial number of an NFT of a Token with
    /// NON_FUNGIBLE_UNIQUE type. When minting NFTs the sender will be the default AccountID instance
    /// (0.0.0 aka 0x0) and when burning NFTs, the receiver will be the default AccountID instance.
    struct NftTransfer {
        // The solidity address of the sender
        address senderAccountID;
        // The solidity address of the receiver
        address receiverAccountID;
        // The serial number of the NFT
        int64 serialNumber;
    }

    struct TokenTransferList {
        // The ID of the token as a solidity address
        address token;
        // Applicable to tokens of type FUNGIBLE_COMMON. Multiple list of AccountAmounts, each of which
        // has an account and amount.
        AccountAmount[] transfers;
        // Applicable to tokens of type NON_FUNGIBLE_UNIQUE. Multiple list of NftTransfers, each of
        // which has a sender and receiver account, including the serial number of the NFT
        NftTransfer[] nftTransfers;
    }

    /// Expiry properties of a Hedera token - second, autoRenewAccount, autoRenewPeriod
    struct Expiry {
        // The epoch second at which the token should expire; if an auto-renew account and period are
        // specified, this is coerced to the current epoch second plus the autoRenewPeriod
        uint32 second;
        // ID of an account which will be automatically charged to renew the token's expiration, at
        // autoRenewPeriod interval, expressed as a solidity address
        address autoRenewAccount;
        // The interval at which the auto-renew account will be charged to extend the token's expiry
        uint32 autoRenewPeriod;
    }

    /// A Key can be a public key from either the Ed25519 or ECDSA(secp256k1) signature schemes, where
    /// in the ECDSA(secp256k1) case we require the 33-byte compressed form of the public key. We call
    /// these public keys <b>primitive keys</b>.
    /// A Key can also be the ID of a smart contract instance, which is then authorized to perform any
    /// precompiled contract action that requires this key to sign.
    /// Note that when a Key is a smart contract ID, it <i>doesn't</i> mean the contract with that ID
    /// will actually create a cryptographic signature. It only means that when the contract calls a
    /// precompiled contract, the resulting "child transaction" will be authorized to perform any action
    /// controlled by the Key.
    /// Exactly one of the possible values should be populated in order for the Key to be valid.
    struct KeyValue {
        // if set to true, the key of the calling Hedera account will be inherited as the token key
        bool inheritAccountKey;
        // smart contract instance that is authorized as if it had signed with a key
        address contractId;
        // Ed25519 public key bytes
        bytes ed25519;
        // Compressed ECDSA(secp256k1) public key bytes
        bytes ECDSA_secp256k1;
        // A smart contract that, if the recipient of the active message frame, should be treated
        // as having signed. (Note this does not mean the <i>code being executed in the frame</i>
        // will belong to the given contract, since it could be running another contract's code via
        // <tt>delegatecall</tt>. So setting this key is a more permissive version of setting the
        // contractID key, which also requires the code in the active message frame belong to the
        // the contract with the given id.)
        address delegatableContractId;
    }

    /// A list of token key types the key should be applied to and the value of the key
    struct TokenKey {
        // bit field representing the key type. Keys of all types that have corresponding bits set to 1
        // will be created for the token.
        // 0th bit: adminKey
        // 1st bit: kycKey
        // 2nd bit: freezeKey
        // 3rd bit: wipeKey
        // 4th bit: supplyKey
        // 5th bit: feeScheduleKey
        // 6th bit: pauseKey
        // 7th bit: ignored
        uint256 keyType;
        // the value that will be set to the key type
        KeyValue key;
    }

    /// Basic properties of a Hedera Token - name, symbol, memo, tokenSupplyType, maxSupply,
    /// treasury, freezeDefault. These properties are related both to Fungible and NFT token types.
    struct HederaToken {
        // The publicly visible name of the token. The token name is specified as a Unicode string.
        // Its UTF-8 encoding cannot exceed 100 bytes, and cannot contain the 0 byte (NUL).
        string name;
        // The publicly visible token symbol. The token symbol is specified as a Unicode string.
        // Its UTF-8 encoding cannot exceed 100 bytes, and cannot contain the 0 byte (NUL).
        string symbol;
        // The ID of the account which will act as a treasury for the token as a solidity address.
        // This account will receive the specified initial supply or the newly minted NFTs in
        // the case for NON_FUNGIBLE_UNIQUE Type
        address treasury;
        // The memo associated with the token (UTF-8 encoding max 100 bytes)
        string memo;
        // IWA compatibility. Specified the token supply type. Defaults to INFINITE
        bool tokenSupplyType;
        // IWA Compatibility. Depends on TokenSupplyType. For tokens of type FUNGIBLE_COMMON - the
        // maximum number of tokens that can be in circulation. For tokens of type NON_FUNGIBLE_UNIQUE -
        // the maximum number of NFTs (serial numbers) that can be minted. This field can never be changed!
        uint32 maxSupply;
        // The default Freeze status (frozen or unfrozen) of Hedera accounts relative to this token. If
        // true, an account must be unfrozen before it can receive the token
        bool freezeDefault;
        // list of keys to set to the token
        TokenKey[] tokenKeys;
        // expiry properties of a Hedera token - second, autoRenewAccount, autoRenewPeriod
        Expiry expiry;
    }

    /// Additional post creation fungible and non fungible properties of a Hedera Token.
    struct TokenInfo {
        /// The hedera token;
        HederaToken hedera;
        /// Specifies whether the token kyc was defaulted with KycNotApplicable (true) or Revoked (false)
        bool defaultKycStatus;
        /// Specifies whether the token is deleted or not
        bool deleted;
        /// The ID of the network ledger
        string ledgerId;
        /// Specifies whether the token is currently paused or not
        bool pauseStatus;
        /// The number of tokens (fungible) or serials (non-fungible) of the token
        uint64 totalSupply;
    }

    /// Additional fungible properties of a Hedera Token.
    struct FungibleTokenInfo {
        /// The shared hedera token info
        TokenInfo tokenInfo;
        /// The number of decimal places a token is divisible by
        uint32 decimals;
    }

    /// Additional non fungible properties of a Hedera Token.
    struct NonFungibleTokenInfo {
        /// The shared hedera token info
        TokenInfo tokenInfo;
        /// The serial number of the nft
        int64 serialNumber;
        /// The account id specifying the owner of the non fungible token
        address ownerId;
        /// The epoch second at which the token was created.
        int64 creationTime;
        /// The unique metadata of the NFT
        bytes metadata;
        /// The account id specifying an account that has been granted spending permissions on this nft
        address spenderId;
    }

    /**********************
     * Direct HTS Calls   *
     **********************/

    /// Mints an amount of the token to the defined treasury account
    /// @param token The token for which to mint tokens. If token does not exist, transaction results in
    ///              INVALID_TOKEN_ID
    /// @param amount Applicable to tokens of type FUNGIBLE_COMMON. The amount to mint to the Treasury Account.
    ///               Amount must be a positive non-zero number represented in the lowest denomination of the
    ///               token. The new supply must be lower than 2^63.
    /// @param metadata Applicable to tokens of type NON_FUNGIBLE_UNIQUE. A list of metadata that are being created.
    ///                 Maximum allowed size of each metadata is 100 bytes
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    /// @return newTotalSupply The new supply of tokens. For NFTs it is the total count of NFTs
    /// @return serialNumbers If the token is an NFT the newly generate serial numbers, othersise empty.
    function mintToken(
        address token,
        uint64 amount,
        bytes[] memory metadata
    )
        external
        returns (
            int64 responseCode,
            uint64 newTotalSupply,
            int64[] memory serialNumbers
        );

    /**********************
     * ABIV1 calls        *
     **********************/

    /// Initiates a Non-Fungable Token Transfer
    /// @param token The ID of the token as a solidity address
    /// @param sender the sender of an nft
    /// @param receiver the receiver of the nft sent by the same index at sender
    /// @param serialNumber the serial number of the nft sent by the same index at sender
    function transferNFTs(
        address token,
        address[] memory sender,
        address[] memory receiver,
        int64[] memory serialNumber
    ) external returns (int64 responseCode);

    /// Transfers tokens where the calling account/contract is implicitly the first entry in the token transfer list,
    /// where the amount is the value needed to zero balance the transfers. Regular signing rules apply for sending
    /// (positive amount) or receiving (negative amount)
    /// @param token The token to transfer to/from
    /// @param sender The sender for the transaction
    /// @param recipient The receiver of the transaction
    /// @param amount Non-negative value to send. a negative value will result in a failure.
    function transferToken(
        address token,
        address sender,
        address recipient,
        int64 amount
    ) external returns (int64 responseCode);

    /// Transfers `amount` tokens from `from` to `to` using the
    //  allowance mechanism. `amount` is then deducted from the caller's allowance.
    /// Only applicable to fungible tokens
    /// @param token The address of the fungible Hedera token to transfer
    /// @param from The account address of the owner of the token, on the behalf of which to transfer `amount` tokens
    /// @param to The account address of the receiver of the `amount` tokens
    /// @param amount The amount of tokens to transfer from `from` to `to`
    /// @return responseCode The response code for the status of the request. SUCCESS is 22.
    function transferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) external returns (int64 responseCode);

    /// Transfers tokens where the calling account/contract is implicitly the first entry in the token transfer list,
    /// where the amount is the value needed to zero balance the transfers. Regular signing rules apply for sending
    /// (positive amount) or receiving (negative amount)
    /// @param token The token to transfer to/from
    /// @param sender The sender for the transaction
    /// @param recipient The receiver of the transaction
    /// @param serialNumber The serial number of the NFT to transfer.
    function transferNFT(
        address token,
        address sender,
        address recipient,
        int64 serialNumber
    ) external returns (int64 responseCode);

    /// Single-token variant of associateTokens. Will be mapped to a single entry array call of associateTokens
    /// @param account The account to be associated with the provided token
    /// @param token The token to be associated with the provided account
    function associateToken(
        address account,
        address token
    ) external returns (int64 responseCode);

}
