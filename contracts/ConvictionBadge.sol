//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "./MergeBadges.sol";

contract ConvictionBadge is ERC721URIStorage {
    using Strings for uint256;
    uint256 public tokenCounter;
    mapping(uint256 => string) private _tokenURIs;
    mapping(address => bool) public TimeLockedVaults;
    address vaultFactoryContract;
    string private tokenBaseURI;
    address public owner;

    address mergeBadgesContract;

    //URIs for four lock periods
    string private baseURI1;
    string private baseURI2;
    string private baseURI3;
    string private baseURI4;

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
        lockPeriodsToMonths[0] = 1;
        lockPeriodsToMonths[1] = 3;
        lockPeriodsToMonths[2] = 6;
        lockPeriodsToMonths[3] = 12;
        MergeBadges mergeBadges = new MergeBadges(address(this));
        mergeBadgesContract = address(mergeBadges);
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

    modifier onlyMergeContract() {
        require(
            msg.sender == mergeBadgesContract,
            "This is not the badge merging contract."
        );
        _;
    }

    /**
     * @notice ConvictionBadge contract precedes VaultFactory, thus needs
     * external assignment after the deployment.
     * @param _vaultFactoryContract Address of the vault factory contract that will produce time-locked vaults.
     */

    function setVaultFactoryContractFirstTime(address _vaultFactoryContract)
        external
        onlyOwner
        returns (address)
    {
        require(
            msg.sender == vaultFactoryContract,
            "vault Contract already set."
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

    function getMergeContract() public view returns (address) {
        return mergeBadgesContract;
    }

    /**
     * @notice For updating the underlying lock contract
     * @param Address of the new vaultFactory Contract that will produce time-locked vaults.
     */

    function changeVaultFactoryContract(address _vaultFactoryContract)
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
     * @param _newTokenID conviction badge token ID to be updated.
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
     * @notice Sets who can access the createCollectible function. Can be called only by the vault factory contract.
     * @param _TimeLockedVault address of the to-be-unauthorized time-locked vault.
     */
    function removeTimeLockedVaults(address _TimeLockedVault)
        external
        virtual
        onlyVaultFactory
    {
        TimeLockedVaults[_TimeLockedVault] = false;
    }

    /**
     * @notice Allows the MergeContract to merge multiple conviction badges rewarded for the same NFT
     * (e.g. CoolCat #3432 locked twice for 3 months and once for 6 months.
     * mergeMint will mint a new conviction badge for 12 months in exchange for the three badges.)
     * @param _mintee Address of the merging account that will receive the conviction badge corresponding to the merge.
     * @param _lockPeriod Index of an array that indicates the sum of the lock periods of the badge.
     * @param _lockedNFTID Token ID of the locked NFT.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     */
    function mergeMint(
        address _mintee,
        uint256 _lockPeriod,
        uint256 _lockedNFTID,
        address _lockedNFTAddress
    ) external onlyMergeContract returns (uint256) {
        uint256 newTokenID = tokenCounter;
        _mergeMint(
            _mintee,
            newTokenID,
            _lockPeriod,
            _lockedNFTID,
            _lockedNFTAddress
        );
        tokenCounter = tokenCounter + 1;
        return (newTokenID);
    }

    /**
     * @notice For updating the conviction badge merging contract.
     * @param _newContract Address of the new merging contract.
     */
    function changeMergeContract(address _newContract)
        external
        virtual
        onlyOwner
    {
        require(
            _newContract != address(0),
            "MergeContract Error: Cannot set to 0x00."
        );
        mergeBadgesContract = _newContract;
    }

    /**
     * @notice Internal function called by mergeMint to merge multiple conviction badges rewarded for the same NFT
     * (e.g. CoolCat #3432 locked twice for 3 months and once for 6 months.
     * mergeMint will mint a new conviction badge for 12 months in exchange for the three badges.)
     * @param _mintee Address of the merging account that will receive the conviction badge corresponding to the merge.
     * @param _lockPeriod Index of an array that indicates the sum of the lock periods of the badge.
     * @param _lockedNFTID Token ID of the locked NFT.
     * @param _lockedNFTAddress Address of the NFT collection locked token belongs to.
     */
    function _mergeMint(
        address mintee,
        uint256 newTokenID,
        uint256 lockPeriod,
        uint256 lockedNFTID,
        address lockedNFTAddress
    ) internal {
        //imported from openzeppelin
        _safeMint(mintee, newTokenID);
        _setTokenURI(newTokenID, lockPeriod);
        _setTokenInfo(newTokenID, lockPeriod, lockedNFTID, lockedNFTAddress);
    }
}
