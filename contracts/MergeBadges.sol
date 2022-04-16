// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC721Receiver} from "../dependencies/openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "../dependencies/openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IConvictionBadge} from "../interfaces/IConvictionBadge.sol";

/**
 * - Users can:
 *   # Merge multiple conviction badges rewarded for an NFT into one.
 * - This contract needs to be spun up or later get assined by the TrophyToken contract to mint badges.
 **/
contract MergeBadges is IERC721Receiver {
    IConvictionBadge convictionBadge;
    IERC721 convictionBadgeERC721Basics;
    address public convictionBadgeAddress;

    /**@param _convictionBadgeAddress Address of the conviction badge address.
     */
    constructor(address _convictionBadgeAddress) {
        convictionBadgeAddress = _convictionBadgeAddress;
        convictionBadge = IConvictionBadge(_convictionBadgeAddress);
        convictionBadgeERC721Basics = IERC721(_convictionBadgeAddress);
    }

    /**
     * @notice Merges multiple badges into one.
     * @param _tokenIDs A list of conviction badge Ids to be merged together.
     * These Ids should correspond to the locking of the same NFT. (e.g. CoolCat #3432 locked twice for 3 months and once for 6 months.
     * mergeBadges will mint a new conviction badge for 12 months in exchange for the three badges.)
     */
    function mergeBadges(uint256[] memory _tokenIDs)
        external
        payable
        returns (uint256)
    {
        address mintee_ = msg.sender;
        require(
            _tokenIDs.length > 1 && _tokenIDs.length < 12,
            "Need to do this for multiple tokens."
        );
        _checkOwnership(_tokenIDs);
        uint256 newLockPeriod = _checkTokenInfo(_tokenIDs);
        _transferToMerge(_tokenIDs);
        uint256 newTokenID = _mintMergedTokens(
            _tokenIDs,
            newLockPeriod,
            mintee_
        );
        return (newTokenID);
    }

    /**
     * @notice Checks if all conviction badges are issued for the same NFT.
     * Then calculates the sum of their lock periods.
     * @param _tokenIDs A list of conviction badge IDs to be merged together.
     */
    function _checkTokenInfo(uint256[] memory _tokenIDs)
        internal
        view
        returns (uint256)
    {
        uint256 newLockPeriod = 0;
        uint256 previouslockPeriod;
        for (uint256 i = 0; i < _tokenIDs.length - 1; i++) {
            require(
                convictionBadge.getTokenInfoLTI(_tokenIDs[i]) ==
                    convictionBadge.getTokenInfoLTI(_tokenIDs[i + 1]),
                "Conviction doesn't belong to the same token!"
            );
            require(
                convictionBadge.getTokenInfoLTA(_tokenIDs[i]) ==
                    convictionBadge.getTokenInfoLTA(_tokenIDs[i + 1]),
                "Conviction doesn't belong to the same token!"
            );
        }

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            previouslockPeriod = convictionBadge.getTokenInfoLoP(_tokenIDs[i]);

            require(
                newLockPeriod + previouslockPeriod <= 12,
                "Can only merge up to 1 year."
            );
            newLockPeriod = newLockPeriod + previouslockPeriod;
        }
        require(
            newLockPeriod == 3 || newLockPeriod == 6 || newLockPeriod == 12,
            "Token lock periods must total up to three, six, or twelve months."
        );
        return newLockPeriod;
    }

    /**
     * @notice Checks if the merger owns the badges.
     * @param _tokenIDs A list of conviction badge IDs to be merged together.
     */
    function _checkOwnership(uint256[] memory _tokenIDs) internal view {
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            require(
                msg.sender == convictionBadgeERC721Basics.ownerOf(_tokenIDs[i]),
                "You don't own these tokens"
            );
        }
    }

    /**
     * @notice Transfer existing badges to the contract for minting the new
     * @param _tokenIDs A list of conviction badge IDs to be merged together.
     */

    function _transferToMerge(uint256[] memory _tokenIDs) internal {
        //batch transfer
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            convictionBadgeERC721Basics.safeTransferFrom(
                msg.sender,
                address(this),
                _tokenIDs[i]
            );
        }
    }

    /**
     * @notice Mint the merged conviction badge.
     * @param _tokenIDs A list of conviction badge IDs to be merged together.
     * @param _newLockPeriod New lock period to be assigned to the token.
     * @param mintee The address of the badge receiver.
     */

    function _mintMergedTokens(
        uint256[] memory _tokenIDs,
        uint256 _newLockPeriod,
        address mintee
    ) internal returns (uint256) {
        uint256 newLockPeriodIndex;
        uint256 lockedtokenID = convictionBadge.getTokenInfoLTI(_tokenIDs[0]);
        address lockedTokenAddress = convictionBadge.getTokenInfoLTA(
            _tokenIDs[0]
        );
        if (_newLockPeriod == 3) {
            newLockPeriodIndex = 1;
        } else if (_newLockPeriod == 6) {
            newLockPeriodIndex = 2;
        } else if (_newLockPeriod == 12) {
            newLockPeriodIndex = 3;
        } else {
            newLockPeriodIndex = 0;
        }

        uint256 newTokenID = convictionBadge.mergeMint(
            mintee,
            newLockPeriodIndex,
            lockedtokenID,
            lockedTokenAddress
        );
        return (newTokenID);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
