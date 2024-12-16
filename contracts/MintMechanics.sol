// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./AllowList.sol";

contract MintMechanics is AllowList {
    // @dev The price for a mint
    uint64 public publicMintPrice;
    // @dev The price for an AL mint
    uint64 public allowListMintPrice;
    // @dev The price for an AL mint
    uint64 public secondaryAllowListMintPrice;
    // @dev The price for a discounted mint
    uint64 public discountedMintPrice;

    bool public isPremint = false;

    function setMintPrice(
        uint64 _publicMintPrice
    ) public onlyOwner returns (uint64) {
        publicMintPrice = _publicMintPrice;

        return _publicMintPrice;
    }

    function setIsPremint(bool _isPremint) public onlyOwner returns (bool) {
        isPremint = _isPremint;

        return isPremint;
    }

    function setAllowListMintPrice(
        uint64 _allowListMintPrice
    ) public onlyOwner returns (uint64) {
        allowListMintPrice = _allowListMintPrice;

        return _allowListMintPrice;
    }

    function setSecondaryAllowListMintPrice(
        uint64 _secondaryAllowListMintPrice
    ) public onlyOwner returns (uint64) {
        secondaryAllowListMintPrice = _secondaryAllowListMintPrice;

        return _secondaryAllowListMintPrice;
    }

    function setDiscountedMintPrice(
        uint64 _discountedMintPrice
    ) public onlyOwner returns (uint64) {
        discountedMintPrice = _discountedMintPrice;

        return _discountedMintPrice;
    }
}
