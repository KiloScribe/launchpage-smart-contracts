// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.8 <0.9.0;

import "./FungibleTokenMinter.sol";

contract KiloScribeMinter is FungibleTokenMinter {
    FungibleTokenMinter private fungibleMinter;

    using LaunchpadLib for *;

    // @dev The address of the Non-Fungible token
    address public tokenAddress;

    // if true, full mint URI does not include a number
    bool public isHashinal;

    uint64 public tokensRemaining;

    // secondary index for free mints
    uint64 public secondaryIndex;

    string public baseTokenURI;

    string public tokenSuffix;

    // index to start off for a n+1 drops.
    uint64 private startIndex;

    mapping(uint64 => uint64) private _tokenIds;

    bool public mintEnabled = false;

    // @dev Error used to revert if an error occured during HTS mint
    error AllowListError(address user);

    // @dev Error used to revert if mint is not enabled
    error MintEnabled(bool mintStatus);

    // @dev Error used to revert if all tokens are minted
    error MintedOut(uint64 tokensRemaining);

    // event UpgradeMetadata(string metadata);
    // @dev event used if a mint was successful
    event NftMint(address indexed tokenAddress, int64[] serialNumbers);

    event NftMintUpgrade(
        address indexed tokenAddress,
        uint256[] indexes,
        string replacedString
    );

    // @dev event used after tokens have been transferred
    event NftTransfer(
        address indexed tokenAddress,
        address indexed from,
        address indexed to,
        int64[] serialNumbers
    );

    // @dev Constructor
    constructor(
        address _tokenAddress,
        uint64 _discountedMintPrice,
        uint64 _allowListMintPrice,
        uint64 _mintPrice,
        uint64 _tokensRemaining,
        uint64[] memory _launchpadFees,
        address payable[] memory _feeAddresses,
        string memory _baseTokenURI,
        bool _isHashinal
    ) FungibleTokenMinter(_launchpadFees, _feeAddresses) {
        setTokenAddress(_tokenAddress);
        publicMintPrice = _mintPrice;
        allowListMintPrice = _allowListMintPrice;
        discountedMintPrice = _discountedMintPrice;
        baseTokenURI = _baseTokenURI;
        isHashinal = _isHashinal;

        tokensRemaining = _tokensRemaining;
        startIndex = 1;
        tokenSuffix = ".json";
    }

    function getRNG() private returns (uint64) {
        return
            uint64(
                LaunchpadLib.getPseudorandomNumber(
                    0,
                    uint32(tokensRemaining + 1)
                )
            );
    }

    function setBaseTokenURI(
        string memory _baseTokenURI
    ) public onlyOwner returns (string memory) {
        baseTokenURI = _baseTokenURI;

        return baseTokenURI;
    }

    function toggleMintEnabled(
        bool _mintStatus
    ) public onlyOwner returns (bool) {
        mintEnabled = _mintStatus;

        return mintEnabled;
    }

    function setStartIndex(
        uint64 _startIndex
    ) public onlyOwner returns (uint64) {
        startIndex = _startIndex;

        return startIndex;
    }

    function setSecondaryIndex(
        uint64 _secondaryIndex
    ) public onlyOwner returns (uint64) {
        secondaryIndex = _secondaryIndex;

        return secondaryIndex;
    }

    function setLaunchpadAddress(
        address payable _launchpadAddress
    ) public onlyOwner returns (address payable) {
        launchpadAddress = _launchpadAddress;

        return launchpadAddress;
    }

    /// @notice only used for immutable tokens.
    /// @dev Contract is created first, and then token is set.
    function setTokenAddress(
        address _tokenAddress
    ) public onlyOwner returns (address) {
        tokenAddress = _tokenAddress;

        // Try to associate but don't revert if it fails
        tryAssociateToken(address(this), tokenAddress);

        return tokenAddress;
    }

    function setTokenSuffix(
        string memory _tokenSuffix
    ) public onlyOwner returns (string memory) {
        tokenSuffix = _tokenSuffix;

        return tokenSuffix;
    }

    function setCollectionFeeAddress(
        address payable _collectionFeeAddress
    ) public onlyOwner returns (address payable) {
        collectionAddress = _collectionFeeAddress;

        return collectionAddress;
    }

    function setIsHashinal(bool _hashinal) public onlyOwner returns (bool) {
        isHashinal = _hashinal;
        return isHashinal;
    }

    function setTokensRemaining(
        uint64 _tokensRemaining
    ) public onlyOwner returns (uint64) {
        tokensRemaining = _tokensRemaining;

        return tokensRemaining;
    }

    // @dev Modifier to test if while minting, the necessary amount is paid
    modifier isPaymentCovered(address _to, uint8 amount) {
        // we need to check each allowList to see which the user is on
        AllowListKind memory kind = getAllowListKindWithLimit(_to);

        if (
            limitModeEnabled &&
            kind.allowListKind != PUBLIC_LIST &&
            amount > kind.mintLimit
        ) {
            // check if the current amount > mintLimit
            revert OverMintLimit(amount, kind.mintLimit);
        }

        // default for all none-holders
        if (kind.allowListKind == PUBLIC_LIST) {
            if (msg.value != publicMintPrice * amount) {
                revert InsufficientPay(kind.allowListKind);
            }
        } else if (kind.allowListKind == DISCOUNTED_LIST) {
            if (msg.value != discountedMintPrice * amount) {
                revert InsufficientPay(kind.allowListKind);
            }
        } else if (kind.allowListKind == SECONDARY_ALLOW_LIST) {
            if (msg.value != secondaryAllowListMintPrice * amount) {
                revert InsufficientPay(kind.allowListKind);
            }
        } else if (kind.allowListKind == BASIC_ALLOW_LIST) {
            if (msg.value != allowListMintPrice * amount) {
                revert InsufficientPay(kind.allowListKind);
            }
        }
        _;
    }

    function isMintedOut(uint8 amount) private view {
        if (!mintEnabled) {
            revert MintEnabled(mintEnabled);
        }

        if (
            tokensRemaining <= 0 ||
            int64(tokensRemaining) - int256(int8(amount)) < 0
        ) {
            revert MintedOut(tokensRemaining);
        }
    }

    function isMeetingBasicChecks(
        address _to,
        uint8 amount,
        bool fungible
    ) private view {
        isMintedOut(amount);

        if (allowListEnabled && !verifyAllowList(_to)) {
            revert AllowListError(_to);
        }

        if (isOverMintLimit(_to, amount, fungible)) {
            revert OverMintLimit(amount, mintLimit);
        }
    }

    function getTokenAt(uint64 i) private view returns (uint64) {
        if (_tokenIds[i] > 0) {
            return _tokenIds[i];
        } else {
            return i;
        }
    }

    // @dev Main minting and transferring function
    // @param to The address to which the tokens are transferred after being minted
    // @param amount The number of tokens to be minted
    // @return The serial numbers of the tokens which have been minted
    function mint(
        address to,
        uint8 amount
    ) external payable isPaymentCovered(to, amount) returns (int64[] memory) {
        // check exchanges + basic checks
        isMeetingBasicChecks(to, amount, false);
        uint8 allowListKind = getAllowListKind(to);

        int64[] memory serials = internalMint(amount);

        minted += amount;

        transferSerialsAndUpdateLimits(
            to,
            amount,
            allowListKind,
            serials,
            false
        );

        coordinateLaunchpadFee();

        return serials;
    }

    /**
     * @dev When serial are preminted, this function is used by the caller instead
     of mint().
     **/
    function premint(
        address to,
        uint8 amount
    ) external payable isPaymentCovered(to, amount) returns (int64[] memory) {
        isMeetingBasicChecks(to, amount, false);
        uint8 allowListKind = getAllowListKind(to);

        int64[] memory serials = generateSerials(amount, true);

        transferSerialsAndUpdateLimits(
            to,
            amount,
            allowListKind,
            serials,
            false
        );

        coordinateLaunchpadFee();

        tokensRemaining -= amount;

        return serials;
    }

    // When minting with a fungible token the caller should
    // call this
    function mintWithFungibleToken(
        address to,
        uint8 amount
    ) external payable returns (int64[] memory) {
        isMeetingBasicChecks(to, amount, true);
        AllowListKind memory kind = getAllowListKindWithLimit(to);

        // get payment amount, and take from msg.sender which could
        // differ from address to, technically.
        takePayment(getPaymentAmount(amount, kind), msg.sender);

        int64[] memory generatedSerials = generateSerials(
            amount,
            internalSerials.length > 0
        );

        transferSerialsAndUpdateLimits(
            to,
            amount,
            kind.allowListKind,
            generatedSerials,
            true
        );

        minted += amount;

        return generatedSerials;
    }

    function generateSerials(
        uint8 amount,
        bool _isPremint
    ) internal returns (int64[] memory) {
        if (_isPremint) {
            int64[] memory serials = new int64[](amount);

            for (uint8 i = 0; i < amount; i++) {
                uint32 currentIndex = getRandomSerial();

                serials[i] = int64(int32(currentIndex));

                emit NftMint(tokenAddress, serials);
            }
            return serials;
        }
        return internalMint(amount);
    }

    function transferSerialsAndUpdateLimits(
        address to,
        uint8 amount,
        uint8 allowListType,
        int64[] memory serials,
        bool fungible
    ) internal {
        if (limitModeEnabled) {
            updateUser(to, allowListType, amount, fungible);
        }

        // toggle off for NFTs that dont need this
        if (mintLimitEnabled) {
            increaseMintedAmount(to, amount, fungible);
        }

        // transfer NFT to sender.
        transferFrom(to, serials);
    }

    function transferFrom(
        address to,
        int64[] memory serialNumbers
    ) private returns (int256) {
        address[] memory tokenTreasuryArray = LaunchpadLib
            .generateAddressArrayForHTS(address(this), serialNumbers.length);

        address[] memory minterArray = LaunchpadLib.generateAddressArrayForHTS(
            to,
            serialNumbers.length
        );

        int256 responseCode = HederaTokenService.transferNFTs(
            tokenAddress,
            tokenTreasuryArray,
            minterArray,
            serialNumbers
        );

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert LaunchpadLib.TransferError(
                uint256(responseCode),
                serialNumbers
            );
        }

        return responseCode;
    }

    function coordinateLaunchpadFee() internal {
        uint256 launchpadValue = (msg.value * uint256(launchpadFee)) / 10000;
        uint256 collectionValue = msg.value -
            ((msg.value * (uint256(launchpadFee))) / 10000);

        // Now that state changes are complete, we conduct the external calls
        launchpadAddress.transfer(launchpadValue);
        collectionAddress.transfer(collectionValue);
    }

    function internalMint(uint8 amount) internal returns (int64[] memory) {
        int64[] memory serials = new int64[](amount);

        for (uint8 i = 0; i < amount; i++) {
            // random number between 1-25 eg 6
            // ensure we do not start at 0
            uint64 currentIndex = (getRNG() % tokensRemaining) + startIndex;
            // returns the current index, unless this number was set before
            uint64 randomIndex = getTokenAt(currentIndex);
            // removes the current number from the pool of available numbers, and sets it to the remainTokens -1
            _tokenIds[currentIndex] = getTokenAt(
                tokensRemaining + startIndex - 1
            );
            // removes one number to save gas cost over time
            _tokenIds[tokensRemaining + startIndex - 1] = 0;
            tokensRemaining -= 1;

            bytes[] memory nftMetadatas = LaunchpadLib.generateMetadataString(
                randomIndex,
                baseTokenURI,
                tokenSuffix,
                isHashinal
            );

            (
                int64 responseCode,
                ,
                int64[] memory serialNumbers
            ) = HederaTokenService.mintToken(tokenAddress, 0, nftMetadatas);

            serials[i] = serialNumbers[0];

            if (responseCode != HederaResponseCodes.SUCCESS) {
                revert MintError(int32(responseCode));
            }

            emit NftMint(tokenAddress, serialNumbers);
        }
        return serials;
    }
}
