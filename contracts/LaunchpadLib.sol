// SPDX-License-Identifier: MIT
pragma solidity >=0.5.8 <0.9.0;
import "./HederaTokenService.sol";
import "./IPrngSystemContract.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

library LaunchpadLib {
    address private constant PRECOMPILE_ADDRESS = address(0x169);

    error PaymentError(uint256 errorCode);

    error TransferError(uint256 errorCode, int64[] serialNumbers);
    error ExchangeError(uint256 errorCode, int64 serialNumber);

    error InvalidOwner(address _address, int64 serial, address owner);

    event NftTransfer(
        address indexed tokenAddress,
        address indexed from,
        address indexed to,
        int64[] serialNumbers
    );

    using SafeMath for uint256;

    using SafeMath for uint64;

    function percent(
        uint256 _value,
        uint64 basePercent
    ) public pure returns (uint256) {
        return SafeMath.div(SafeMath.mul(_value, basePercent), 10000);
    }

    function percent64(
        uint64 _value,
        uint64 basePercent
    ) public pure returns (uint256) {
        return SafeMath.div(SafeMath.mul(_value, basePercent), 10000);
    }

    function basicSub(
        uint8 _value1,
        uint8 _value2
    ) public pure returns (uint256) {
        return SafeMath.sub(_value1, _value2);
    }

    /**
     * Returns a pseudorandom number in the range [lo, hi) using the seed generated from "getPseudorandomSeed"
     */
    function getPseudorandomNumber(
        uint32 lo,
        uint32 hi
    ) public returns (uint32) {
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
        return lo + (choice % (hi - lo));
    }

    // @dev Helper function which generates array of addresses required for HTSPrecompiled
    function generateAddressArrayForHTS(
        address _address,
        uint256 _items
    ) public pure returns (address[] memory _addresses) {
        _addresses = new address[](_items);
        for (uint256 i = 0; i < _items; i++) {
            _addresses[i] = _address;
        }
    }

    // @dev Helper function which generates array required for metadata by HTSPrecompiled
    function generateBytesArrayForHTS(
        bytes memory _bytes,
        uint256 _items
    ) public pure returns (bytes[] memory _bytesArray) {
        return _generateBytesArrayForHTS(_bytes, _items);
    }

    function _generateBytesArrayForHTS(
        bytes memory _bytes,
        uint256 _items
    ) internal pure returns (bytes[] memory _bytesArray) {
        _bytesArray = new bytes[](_items);
        for (uint256 i = 0; i < _items; i++) {
            _bytesArray[i] = _bytes;
        }
    }

    function generateMetadataString(
        uint256 index,
        string memory baseTokenURI,
        string memory suffix,
        bool disableIndex
    ) public pure returns (bytes[] memory) {
        string memory newIndex = Strings.toString(index);

        string memory mintURI = !disableIndex
            ? string(abi.encodePacked(baseTokenURI, newIndex, suffix))
            : string(abi.encodePacked(baseTokenURI));

        bytes memory strAsMemory = bytes(mintURI);
        bytes[] memory nftMetadatas = _generateBytesArrayForHTS(strAsMemory, 1);

        return nftMetadatas;
    }

    function tokenURI(
        address token,
        int64 tokenId
    ) public view returns (string memory) {
        return IERC721Metadata(token).tokenURI(uint256(int256(tokenId)));
    }

    function isValidOwner(
        address tokenAddress,
        int64 serialNumber,
        address owner
    ) public view {
        if (ownerOf(tokenAddress, serialNumber) != owner) {
            revert InvalidOwner(tokenAddress, serialNumber, owner);
        }
    }

    function ownerOf(
        address tokenAddress,
        int64 serialNumber
    ) public view returns (address) {
        return IERC721(tokenAddress).ownerOf(uint256(uint64(serialNumber)));
    }
}
