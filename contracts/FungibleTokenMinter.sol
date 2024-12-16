// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./MintMechanics.sol";

// import "./LaunchpadLib.sol";

contract FungibleTokenMinter is HederaTokenService, MintMechanics {
    using LaunchpadLib for *;
    error InsufficientFungibleAmount(uint256 balance, uint64 amount);

    // @dev Error used to revert if an error occured during HTS transfer
    error FungibleTransferError(uint256 errorCode);

    // @notice Error used when reverting the minting function if it doesn't receive the required payment amount
    error InsufficientPay(uint8 errorCode);

    // @notice Error used when reverting the minting function if it doesn't receive the required payment amount
    error IncorrectList(uint8 errorCode);

    // @dev Error used to revert if an error occured during HTS mint
    error MintError(int32 errorCode);

    uint32[] internal internalSerials;

    address private fungibleTokenId;

    // @dev The address of the treasury
    address internal treasuryAddress;

    // @dev 0-100 launchpad fee
    uint64 public launchpadFee;

    // @dev The address which launchpad fees are paid out to
    address payable public launchpadAddress;

    // @dev The address which collection sales are paid out to
    address payable public collectionAddress;
    // @dev The price for a mint
    uint64 public publicFungibleMintPrice;
    // @dev The price for an AL mint
    uint64 public allowListFungibleMintPrice;
    // @dev The price for an AL mint
    uint64 public secondaryAllowListFungibleMintPrice;
    // @dev The price for a discounted mint
    uint64 public discountedFungibleMintPrice;

    constructor(
        uint64[] memory _launchpadFees,
        address payable[] memory _feeAddresses
    ) {
        launchpadFee = _launchpadFees[0];
        launchpadAddress = _feeAddresses[0];
        collectionAddress = _feeAddresses[1];
    }

    /// @dev Before we call this function, we need approval for the token
    function takePayment(uint64 amount, address spender) internal {
        uint256 currentBalance = IERC721(fungibleTokenId).balanceOf(spender);

        if (currentBalance < amount) {
            revert InsufficientFungibleAmount(currentBalance, amount);
        }

        //  we need to split this up the payment...
        coordinateLaunchpadFeeFungible(amount, spender);
    }

    function setFungibleTokenID(
        address _fungibleTokenId
    ) public onlyOwner returns (address) {
        fungibleTokenId = _fungibleTokenId;

        return _fungibleTokenId;
    }

    function getPaymentAmount(
        uint8 amount,
        AllowListKind memory kind
    ) internal view returns (uint64) {
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
            return publicFungibleMintPrice * amount;
        } else if (kind.allowListKind == DISCOUNTED_LIST) {
            return discountedFungibleMintPrice * amount;
        } else if (kind.allowListKind == SECONDARY_ALLOW_LIST) {
            return secondaryAllowListFungibleMintPrice * amount;
        } else if (kind.allowListKind == BASIC_ALLOW_LIST) {
            return allowListFungibleMintPrice * amount;
        }

        // this should never happen, but just in case so we can handle the error.
        revert IncorrectList(10);
    }

    function transferTokens(
        uint64 amount,
        address spender,
        uint64 fee,
        address receiver,
        bool useTransferFrom
    ) internal {
        uint256 percentValue = useTransferFrom
            ? uint256(amount)
            : LaunchpadLib.percent(amount, fee);

        int256 responseCode = useTransferFrom
            ? HederaTokenService.transferFrom(
                fungibleTokenId,
                spender,
                receiver,
                percentValue
            )
            : HederaTokenService.transferToken(
                fungibleTokenId,
                spender,
                receiver,
                SafeCast.toInt64(int256(percentValue))
            );

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert FungibleTransferError(uint256(responseCode));
        }
    }

    function coordinateLaunchpadFeeFungible(
        uint64 amount,
        address spender
    ) internal {
        // first transfer the tokens into the contract...
        transferTokens(amount, spender, 0, address(this), true);
        // launchpad cost
        transferTokens(
            amount,
            address(this),
            launchpadFee,
            launchpadAddress,
            false
        );

        transferTokens(
            amount,
            address(this),
            10000 - launchpadFee,
            collectionAddress,
            false
        );
    }

    function setFungibleMintPrice(
        uint64 _publicMintPrice
    ) public onlyOwner returns (uint64) {
        publicFungibleMintPrice = _publicMintPrice;

        return _publicMintPrice;
    }

    function setFungibleAllowListMintPrice(
        uint64 _allowListMintPrice
    ) public onlyOwner returns (uint64) {
        allowListFungibleMintPrice = _allowListMintPrice;

        return _allowListMintPrice;
    }


    function setFungibleSecondaryAllowListMintPrice(
        uint64 _secondaryAllowListMintPrice
    ) public onlyOwner returns (uint64) {
        secondaryAllowListFungibleMintPrice = _secondaryAllowListMintPrice;

        return _secondaryAllowListMintPrice;
    }

    function setFungibleDiscountedMintPrice(
        uint64 _discountedMintPrice
    ) public onlyOwner returns (uint64) {
        discountedFungibleMintPrice = _discountedMintPrice;

        return _discountedMintPrice;
    }

    function addSerials(
        uint32[] memory _numbers,
        bool reset
    ) external onlyOwner {
        // remove previous serials
        if (reset) {
            internalSerials = new uint32[](0);
        }
        for (uint32 i = 0; i < _numbers.length; i++) {
            internalSerials.push(_numbers[i]);
        }
    }

    function getSerials() external view onlyOwner returns (uint32[] memory) {
        return internalSerials;
    }

    function getRandomSerial() internal returns (uint32) {
        // minted out
        if (internalSerials.length <= 0) {
            revert MintError(511);
        }

        uint32 randomIndex = LaunchpadLib.getPseudorandomNumber(
            0,
            uint32(internalSerials.length)
        );

        uint32 randomNumber = internalSerials[randomIndex];
        internalSerials[randomIndex] = internalSerials[
            internalSerials.length - 1
        ];
        internalSerials.pop();
        return randomNumber;
    }
}
