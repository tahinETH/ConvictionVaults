//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import {ERC721} from "../dependencies/openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC721} from "../dependencies/openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721URIStorage} from "../dependencies/openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Strings} from "../dependencies/openzeppelin/contracts/utils/Strings.sol";
import {LockingStorage} from "./LockingStorage.sol";

contract ConvictionBadge is ERC721URIStorage {
    using Strings for uint256;
    uint256 public tokenCounter;
    mapping(uint256 => string) private _tokenURIs;

    address public vaultFactoryContract;
    string private tokenBaseURI;
    address public owner;

    //URIs for four lock periods
    string private baseURI1;
    string private baseURI2;
    string private baseURI3;
    string private baseURI4;
    mapping(address => bool) internal TimeLockedVaults;
    mapping(uint256 => TokenInfo) public tokenInfo;
    uint256[4] public lockPeriodsToMonths;

    struct TokenInfo {
        address lockedNFTAddress;
        uint256 lockedNFTID;
        uint256 lockPeriod;
        bool exists;
    }

    constructor(
        string memory name,
        string memory symbol,
        string[] memory uris
    ) ERC721(name, symbol) {
        owner = msg.sender;
        tokenCounter = 0;
        vaultFactoryContract = msg.sender; //deployer needs to assign factory contract after deployment.
        baseURI1 = uris[0];
        baseURI2 = uris[1];
        baseURI3 = uris[2];
        baseURI4 = uris[3];
        lockPeriodsToMonths[0] = 3;
        lockPeriodsToMonths[1] = 6;
        lockPeriodsToMonths[2] = 12;
        lockPeriodsToMonths[3] = 24;
    }

    modifier onlyVaultFactory() {
        require(msg.sender != owner, "Only vault factory can access this.");
        require(
            msg.sender == vaultFactoryContract,
            "This is not the vault contract."
        );
        _;
    }

    modifier onlyTimeLockedVaults() {
        require(
            TimeLockedVaults[msg.sender],
            "Caller must be a Time Locked Wallet!"
        );
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the contract owner.");
        _;
    }

    /**
     * @notice ConvictionBadge contract precedes VaultFactory, thus needs
     * external assignment after the deployment.
     * @param _vaultFactoryContract Address of the vault factory contract that will produce time-locked vaults.
     */

    function setVFContractFirstTime(address _vaultFactoryContract)
        external
        onlyOwner
        returns (address)
    {
        require(
            msg.sender == vaultFactoryContract,
            "Vault Contract already set."
        );
        vaultFactoryContract = _vaultFactoryContract;
        return vaultFactoryContract;
    }

    /**
     * @notice Gets the address of the locked NFT corresponding to a conviction Badge Id.
     * @param _tokenID conviction Badge Id
     */
    function getTokenInfoLTA(uint256 _tokenID)
        public
        view
        virtual
        returns (address)
    {
        return (tokenInfo[_tokenID].lockedNFTAddress);
    }

    /**
     * @notice Sets who can access the createCollectible function. Can be called only by the vault factory contract.
     * @param _TimeLockedVault address of the to-be-authorized time-locked vault.
     */

    function setTimeLockedVaults(address _TimeLockedVault)
        external
        virtual
        onlyVaultFactory
    {
        TimeLockedVaults[_TimeLockedVault] = true;
    }

    /**
     * @notice Gets the Token ID of the locked NFT corresponding to a conviction Badge Id.
     * @param _tokenID conviction Badge Id
     */

    function getTokenInfoLTI(uint256 _tokenID)
        public
        view
        virtual
        returns (uint256)
    {
        return (tokenInfo[_tokenID].lockedNFTID);
    }

    /**
     * @notice Gets the lock period of the locked NFT corresponding to a conviction Badge Id.
     * @param _tokenID conviction Badge Id
     */

    function getTokenInfoLoP(uint256 _tokenID)
        public
        view
        virtual
        returns (uint256)
    {
        return (tokenInfo[_tokenID].lockPeriod);
    }

    /**
     * @notice For updating the underlying lock contract
     * @param _vaultFactoryContract of the new vaultFactory Contract that will produce time-locked vaults.
     */

    function changeVFContract(address _vaultFactoryContract)
        external
        onlyVaultFactory
        returns (address)
    {
        require(
            vaultFactoryContract != _vaultFactoryContract,
            "This is already the vault contract."
        );
        vaultFactoryContract = _vaultFactoryContract;
        return vaultFactoryContract;
    }

    /**
     * @notice Sets the tokenURI for a conviction badge upon minting.
     * @param _tokenID conviction Badge token ID to which the URI will be assigned to.
     * @param _lockPeriod Index of an array that indicates the lockup period of the NFT.
     */

    function _setTokenURI(uint256 _tokenID, uint256 _lockPeriod)
        internal
        virtual
    {
        require(
            _exists(_tokenID),
            "ERC721Metadata: URI set of nonexistent token"
        );
        if (_lockPeriod == 0) {
            _tokenURIs[_tokenID] = baseURI1;
        } else if (_lockPeriod == 1) {
            _tokenURIs[_tokenID] = baseURI2;
        } else if (_lockPeriod == 2) {
            _tokenURIs[_tokenID] = baseURI3;
        } else if (_lockPeriod == 3) {
            _tokenURIs[_tokenID] = baseURI4;
        } else {
            _tokenURIs[_tokenID] = "";
        }
    }

    function _baseURI() internal view override returns (string memory) {
        return tokenBaseURI;
    }

    /**
     * @notice Creates a unique ERC721 conviction badge for the Locked NFT.
     * and stores the NFT address, the NFT token Id, and the lock period on that badge token.
     * @param _mintee Address of the locking account that will receive the conviction badge corresponding to the lock.
     * @param _lockPeriod Index of an array that indicates the lockup period of the NFT.
     * @param _lockedNFTID Token ID of the locked NFT.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     */
    function createCollectible(
        address _mintee,
        uint256 _lockPeriod,
        uint256 _lockedNFTID,
        address _lockedNFTAddress
    ) external onlyTimeLockedVaults returns (uint256) {
        uint256 newTokenID = tokenCounter;

        _safeMint(_mintee, newTokenID);
        _setTokenURI(newTokenID, _lockPeriod);
        _setTokenInfo(newTokenID, _lockPeriod, _lockedNFTID, _lockedNFTAddress);
        tokenCounter = tokenCounter + 1;
        return newTokenID;
    }

    /**
     * @notice Stores the NFT address, the NFT token Id, and the lock period corresponding to a badge token upon a new mint.
     * @param newTokenID conviction badge token ID to be updated.
     * @param _lockPeriod Index of an array that indicates the lockup period of the NFT.
     * @param _lockedNFTID Token ID of the locked NFT.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     */
    function _setTokenInfo(
        uint256 newTokenID,
        uint256 _lockPeriod,
        uint256 _lockedNFTID,
        address _lockedNFTAddress
    ) internal {
        require(tokenInfo[newTokenID].exists == false);
        tokenInfo[newTokenID].lockPeriod = lockPeriodsToMonths[_lockPeriod];
        tokenInfo[newTokenID].lockedNFTID = _lockedNFTID;
        tokenInfo[newTokenID].lockedNFTAddress = _lockedNFTAddress;
        tokenInfo[newTokenID].exists = true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(to == address(0), "Cannot transfer it to another account.");
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(to == address(0), "Cannot transfer it to another account.");
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @notice Transfer existing badges to the contract for minting the new
     * @param _tokenIDs A list of conviction badge IDs to be merged together.
     */

    function _burnBadges(uint256[] memory _tokenIDs) internal {
        //batch transfer
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            _burn(_tokenIDs[i]);
        }
    }

    function mergeBadges(uint256[] memory _tokenIDs)
        external
        payable
        returns (uint256)
    {
        address mintee_ = msg.sender;
        require(
            _tokenIDs.length > 1 && _tokenIDs.length < 9,
            "Need to do this for multiple tokens."
        );
        _checkOwnership(_tokenIDs);
        uint256 newLockPeriod = _checkTokenInfo(_tokenIDs);
        _burnBadges(_tokenIDs);
        uint256 newTokenID = _mergeBadges(_tokenIDs, newLockPeriod, mintee_);
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
                getTokenInfoLTI(_tokenIDs[i]) ==
                    getTokenInfoLTI(_tokenIDs[i + 1]),
                "Conviction doesn't belong to the same token!"
            );
            require(
                getTokenInfoLTA(_tokenIDs[i]) ==
                    getTokenInfoLTA(_tokenIDs[i + 1]),
                "Conviction doesn't belong to the same token!"
            );
        }

        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            previouslockPeriod = getTokenInfoLoP(_tokenIDs[i]);

            require(
                newLockPeriod + previouslockPeriod <= 24,
                "Can only merge up to 2 years."
            );
            newLockPeriod = newLockPeriod + previouslockPeriod;
        }
        require(
            newLockPeriod == 6 || newLockPeriod == 12 || newLockPeriod == 24,
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
                msg.sender == ownerOf(_tokenIDs[i]),
                "You don't own these tokens"
            );
        }
    }

    /**
     * @notice Mint the merged conviction badge.
     * @param _tokenIDs A list of conviction badge IDs to be merged together.
     * @param _newLockPeriod New lock period to be assigned to the token.
     * @param mintee The address of the badge receiver.
     */

    function _mergeBadges(
        uint256[] memory _tokenIDs,
        uint256 _newLockPeriod,
        address mintee
    ) internal returns (uint256) {
        uint256 newLockPeriodIndex;
        uint256 lockedtokenID = getTokenInfoLTI(_tokenIDs[0]);
        address lockedTokenAddress = getTokenInfoLTA(_tokenIDs[0]);
        if (_newLockPeriod == 6) {
            newLockPeriodIndex = 1;
        } else if (_newLockPeriod == 12) {
            newLockPeriodIndex = 2;
        } else if (_newLockPeriod == 24) {
            newLockPeriodIndex = 3;
        } else {
            newLockPeriodIndex = 0;
        }
        uint256 newTokenID = tokenCounter;
        _mergeMint(
            mintee,
            newTokenID,
            newLockPeriodIndex,
            lockedtokenID,
            lockedTokenAddress
        );
        tokenCounter = tokenCounter + 1;
        return (newTokenID);
    }

    /**
     * @notice Internal function called by mergeMint to merge multiple conviction badges rewarded for the same NFT
     * (e.g. CoolCat #3432 locked twice for 3 months and once for 6 months.
     * mergeMint will mint a new conviction badge for 12 months in exchange for the three badges.)
     * @param mintee Address of the merging account that will receive the conviction badge corresponding to the merge.
     * @param lockPeriod Index of an array that indicates the sum of the lock periods of the badge.
     * @param _lockedNFTID Token ID of the locked NFT.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     */
    function _mergeMint(
        address mintee,
        uint256 newTokenID,
        uint256 lockPeriod,
        uint256 _lockedNFTID,
        address _lockedNFTAddress
    ) internal {
        _safeMint(mintee, newTokenID);
        _setTokenURI(newTokenID, lockPeriod);
        _setTokenInfo(newTokenID, lockPeriod, _lockedNFTID, _lockedNFTAddress);
    }
}
