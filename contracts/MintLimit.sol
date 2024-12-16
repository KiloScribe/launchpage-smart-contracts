// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.8 <0.9.0;

import "./OnlyOwner.sol";

contract MintLimit is OnlyOwner {
    bool public mintLimitEnabled;

    // a mint limit on a fungible token
    uint8 public fungibleMintLimit;
    // a mint limit on hbar payment
    uint8 public mintLimit;
    uint64 public maxMintLimit;
    uint64 public minted;

    // @dev Error used to revert if all tokens are minted
    error OverMintLimit(uint8 amount, uint64 mintLimit);

    mapping(address => uint8) private mintedAddresses;
    mapping(address => uint8) private mintedFungibleAddresses;

    constructor() {
        mintLimitEnabled = false;
    }

    function toggleMintLimitEnabled(
        bool _mintLimitEnabled
    ) public onlyOwner returns (bool) {
        mintLimitEnabled = _mintLimitEnabled;

        return mintLimitEnabled;
    }

    function toggleMintLimit(
        uint8 _mintLimit
    ) public onlyOwner returns (uint8) {
        mintLimit = _mintLimit;

        return mintLimit;
    }

    function toggleFungibleMintLimit(
        uint8 _fungibleMintLimit
    ) public onlyOwner returns (uint8) {
        fungibleMintLimit = _fungibleMintLimit;

        return fungibleMintLimit;
    }

    function isOverMintLimit(
        address _to,
        uint8 amount,
        bool fungible
    ) public view returns (bool) {
        if (maxMintLimit > 0 && minted + amount > maxMintLimit) {
            revert OverMintLimit(amount, maxMintLimit);
        }

        if (!mintLimitEnabled) {
            return false;
        }

        if (fungible) {
            return mintedFungibleAddresses[_to] + amount > fungibleMintLimit;
        }
        return
            mintLimit <= 0 ? false : mintedAddresses[_to] + amount > mintLimit;
    }

    function increaseMintedAmount(
        address _mintAddress,
        uint8 amount,
        bool fungible
    ) internal {
        if (fungible) {
            mintedFungibleAddresses[_mintAddress] += amount;
        } else {
            mintedAddresses[_mintAddress] += amount;
        }
    }

    function setMaxMintLimit(
        uint64 _maxMintLimit
    ) public onlyOwner returns (uint64) {
        maxMintLimit = _maxMintLimit;

        return maxMintLimit;
    }
}
