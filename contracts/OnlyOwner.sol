// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.5.8 <0.9.0;

contract OnlyOwner {
    address public _owner;
    mapping(address => bool) private approvedOwners;

    error NotTheOwner();
    error ZeroAddress();

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _owner = msg.sender;
        approvedOwners[_owner] = true;
    }

    modifier onlyOwner() {
        // Using custom error instead of require statement
        if (!approvedOwners[msg.sender]) revert NotTheOwner();
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        address oldOwner = _owner;
        _owner = newOwner;
        // Remove old owner from approved list
        approvedOwners[oldOwner] = false;
        // Add new owner to approved list
        approvedOwners[newOwner] = true;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function addApprovedOwner(address newOwner) public onlyOwner {
        approvedOwners[newOwner] = true;
    }

    function removeApprovedOwner(address existingOwner) public onlyOwner {
        if (existingOwner == _owner) revert NotTheOwner();
        delete approvedOwners[existingOwner];
    }

    function getOwner() public view returns (address) {
        return _owner;
    }
}
