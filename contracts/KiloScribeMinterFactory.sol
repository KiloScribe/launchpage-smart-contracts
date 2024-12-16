// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.8 <0.9.0;

import "./KiloScribeMinter.sol";

contract KiloScribeMinterFactory {
    event ContractCreated(address contractAddress);
    
    function createContract(
        address tokenAddress,
        uint64 discountedMintPrice,
        uint64 allowListMintPrice,
        uint64 mintPrice,
        uint64 tokensRemaining,
        uint64[] memory launchpadFees,
        address payable[] memory feeAddresses,
        string memory baseTokenURI,
        bool isHashinal
    ) public returns (address) {
        // Deploy new instance of KiloScribeMinter contract
        KiloScribeMinter newContract = new KiloScribeMinter(
            tokenAddress,
            discountedMintPrice,
            allowListMintPrice,
            mintPrice,
            tokensRemaining,
            launchpadFees,
            feeAddresses,
            baseTokenURI,
            isHashinal
        );
        
        // Transfer ownership to the caller
        newContract.transferOwnership(msg.sender);
        
        // Emit event for tracking
        emit ContractCreated(address(newContract));
        
        return address(newContract);
    }
}
