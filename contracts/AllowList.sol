// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.8 <0.9.0;
pragma experimental ABIEncoderV2;

import "./OnlyOwner.sol";
import "./MintLimit.sol";
import "./LaunchpadLib.sol";

struct AllowListUser {
    address accountId;
    uint8 mintLimit;
}

struct AllowListKind {
    uint8 allowListKind;
    uint8 mintLimit;
}

contract AllowList is OnlyOwner, MintLimit {
    // order is always, DL -> SAL -> AL -> Public
    uint8 public constant BASIC_ALLOW_LIST = 1;
    // not always enabled
    uint8 public constant SECONDARY_ALLOW_LIST = 4;
    uint8 public constant DISCOUNTED_LIST = 2;
    uint8 public constant PUBLIC_LIST = 3;

    bool public allowListEnabled;

    bool public limitModeEnabled;

    bool public disableListsWhenPublic;

    bool public discountTransitionsToAllowList;

    mapping(address => uint8) private basicAllowListAddresses;

    mapping(address => uint8) private secondaryAllowListAddresses;

    mapping(address => uint8) private discountedAllowListAddresses;

    constructor() {
        allowListEnabled = false;
        limitModeEnabled = false;
        disableListsWhenPublic = false;
        discountTransitionsToAllowList = true;
    }

    function updateUser(
        address _addressToUpdate,
        uint8 allowListKind,
        uint8 _limitAmount,
        bool fungible
    ) internal {
        // if you mint using a fungible token
        // it should not effect your hbar pricing
        if (fungible && fungibleMintLimit > 0) {
            return;
        }
        if (allowListKind == BASIC_ALLOW_LIST) {
            uint256 newAmount = LaunchpadLib.basicSub(
                basicAllowListAddresses[_addressToUpdate],
                _limitAmount
            );

            if (newAmount <= 0) {
                delete basicAllowListAddresses[_addressToUpdate];
            } else {
                basicAllowListAddresses[_addressToUpdate] = uint8(newAmount);
            }
        } else if (allowListKind == DISCOUNTED_LIST) {
            uint256 newAmount = LaunchpadLib.basicSub(
                discountedAllowListAddresses[_addressToUpdate],
                _limitAmount
            );

            if (newAmount <= 0) {
                delete discountedAllowListAddresses[_addressToUpdate];
            } else {
                discountedAllowListAddresses[_addressToUpdate] = uint8(
                    newAmount
                );
            }
        } else if (allowListKind == SECONDARY_ALLOW_LIST) {
            uint256 newAmount = LaunchpadLib.basicSub(
                secondaryAllowListAddresses[_addressToUpdate],
                _limitAmount
            );

            if (newAmount <= 0) {
                delete secondaryAllowListAddresses[_addressToUpdate];
            } else {
                secondaryAllowListAddresses[_addressToUpdate] = uint8(
                    newAmount
                );
            }
        }
    }

    // any one can call this function.
    function verifyAllowList(address _user) public view returns (bool) {
        // which list is the user on
        // it is important to check from the largest discount first
        // in case a user ends up on two lists by mistake
        uint256 allowListKind = getAllowListKind(_user);
        if (allowListKind == DISCOUNTED_LIST) {
            return discountedAllowListAddresses[_user] > 0;
        } else if (allowListKind == BASIC_ALLOW_LIST) {
            return basicAllowListAddresses[_user] > 0;
        } else if (allowListKind == SECONDARY_ALLOW_LIST) {
            return secondaryAllowListAddresses[_user] > 0;
        }
        return false;
    }

    /// @dev returns a number greater than 0 indicating which list the user is on
    function getAllowListKind(address _user) public view returns (uint8) {
        if (!allowListEnabled && disableListsWhenPublic) {
            return PUBLIC_LIST;
        }

        if (discountedAllowListAddresses[_user] > 0) {
            return DISCOUNTED_LIST;
        }

        if (secondaryAllowListAddresses[_user] > 0) {
            return SECONDARY_ALLOW_LIST;
        }

        if (basicAllowListAddresses[_user] > 0) {
            return BASIC_ALLOW_LIST;
        }

        return PUBLIC_LIST;
    }

    /// @dev returns a number greater AllowListKind for the user
    /// This is a seperate function to reduce gas costs when we do not need the mint limit
    function getAllowListKindWithLimit(
        address _user
    ) public view returns (AllowListKind memory) {
        if (!allowListEnabled && disableListsWhenPublic) {
            return AllowListKind(PUBLIC_LIST, 0);
        }

        // always check discounted first in case user is on two lists.
        if (discountedAllowListAddresses[_user] > 0) {
            return
                AllowListKind(
                    DISCOUNTED_LIST,
                    discountedAllowListAddresses[_user]
                );
        }

        if (secondaryAllowListAddresses[_user] > 0) {
            return
                AllowListKind(
                    SECONDARY_ALLOW_LIST,
                    secondaryAllowListAddresses[_user]
                );
        }

        if (basicAllowListAddresses[_user] > 0) {
            return
                AllowListKind(BASIC_ALLOW_LIST, basicAllowListAddresses[_user]);
        }

        return AllowListKind(PUBLIC_LIST, 0);
    }

    // only owner can call this function
    function addUser(
        AllowListUser calldata _user,
        uint8 allowListKind
    ) public onlyOwner {
        if (allowListKind == BASIC_ALLOW_LIST) {
            basicAllowListAddresses[_user.accountId] = _user.mintLimit;
        } else if (allowListKind == SECONDARY_ALLOW_LIST) {
            secondaryAllowListAddresses[_user.accountId] = _user.mintLimit;
        } else if (allowListKind == DISCOUNTED_LIST) {
            discountedAllowListAddresses[_user.accountId] = _user.mintLimit;
        }
    }

    function addUsers(
        AllowListUser[] calldata _users,
        uint8 allowListKind
    ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            if (allowListKind == BASIC_ALLOW_LIST) {
                basicAllowListAddresses[_users[i].accountId] = _users[i]
                    .mintLimit;
            } else if (allowListKind == DISCOUNTED_LIST) {
                discountedAllowListAddresses[_users[i].accountId] = _users[i]
                    .mintLimit;
            } else if (allowListKind == SECONDARY_ALLOW_LIST) {
                secondaryAllowListAddresses[_users[i].accountId] = _users[i]
                    .mintLimit;
            }
        }
    }

    function removeUsers(
        AllowListUser[] calldata _users,
        uint8 allowListKind
    ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            if (allowListKind == BASIC_ALLOW_LIST) {
                delete basicAllowListAddresses[_users[i].accountId];
            } else if (allowListKind == DISCOUNTED_LIST) {
                delete discountedAllowListAddresses[_users[i].accountId];
            } else if (allowListKind == SECONDARY_ALLOW_LIST) {
                delete secondaryAllowListAddresses[_users[i].accountId];
            }
        }
    }

    function toggleLimitMode(
        bool _limitModeEnabled
    ) public onlyOwner returns (bool) {
        limitModeEnabled = _limitModeEnabled;

        return limitModeEnabled;
    }

    function toggleDiscountTransitionsToAllowList(
        bool _discountTransitionsToAllowList
    ) public onlyOwner returns (bool) {
        discountTransitionsToAllowList = _discountTransitionsToAllowList;

        return discountTransitionsToAllowList;
    }

    function toggleDisableListsWhenPublic(
        bool _disableListsWhenPublic
    ) public onlyOwner returns (bool) {
        disableListsWhenPublic = _disableListsWhenPublic;

        return disableListsWhenPublic;
    }

    function toggleAllowList(
        bool allowListStatus
    ) public onlyOwner returns (bool) {
        allowListEnabled = allowListStatus;

        return allowListEnabled;
    }
}
