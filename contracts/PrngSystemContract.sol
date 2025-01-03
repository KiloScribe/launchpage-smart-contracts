// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.5.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./IPrngSystemContract.sol";

contract PrngSystemContract {
    address private constant PRECOMPILE_ADDRESS = address(0x169);
    uint32 private randNum;

    /**
     * Returns a pseudorandom number in the range [lo, hi) using the seed generated from "getPseudorandomSeed"
     */
    function getPseudorandomNumber(
        uint32 lo,
        uint32 hi
    ) external returns (uint32) {
        (bool success, bytes memory result) = PRECOMPILE_ADDRESS.call(
            abi.encodeWithSelector(
                IPrngSystemContract.getPseudorandomSeed.selector
            )
        );
        require(success);
        uint32 choice;
        assembly {
            choice := mload(add(result, 0x20))
        }
        randNum = lo + (choice % (hi - lo));
        return randNum;
    }

    function getNumber() public view returns (uint32) {
        return randNum;
    }
}
