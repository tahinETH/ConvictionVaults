from brownie import (
    TestCollectible,
    VaultFactory,
    ConvictionBadge,
    Contract,
    interface,
    network,
)
from scripts.helpful_scripts import (
    get_account,
    LOCAL_BLOCKCHAIN_ENVIRONMENTS,
)
from scripts.get_abi import get_abi
from brownie.network.state import Chain


gas_limit = 10000000
mintBadgeFee = 5000000000000000
URIS = [
    "https://ipfs.io/ipfs/QmPcsgSK17uPmLU83gEQvHpaUvfgktrqkJ16KRrwGu4MRa?filename=vault-one-month.png",
    "https://ipfs.io/ipfs/QmYZkoq5k9ZaPibGKA5XkYZ74FD3rKafQeLbgFsH2n6BnA?filename=vault-three-months.png",
    "https://ipfs.io/ipfs/QmdJNGUHECbMVSJXcGR5Df22FZaTtKEQpChgdLvVR52wnX?filename=vault-six-months.png",
    "https://ipfs.io/ipfs/QmVhKBQRtmfY2Cwzd9cAhz6o4CFjmu7zVxdFzhUuPb4guQ?filename=vault-one-year.png",
]


def main():
    full_scale_deploy()


def full_scale_deploy():
    LockPeriod = 2
    account = get_account()

    # =====DEPLOY TROPHY_TOKEN=====
    trophy_token = ConvictionBadge.deploy(
        "Conviction", "CNV", URIS, {"from": account}, publish_source=False
    )
    ##
    #
    latestConvictionBadge = ConvictionBadge[-1]
    print(f"Latest Conviction Badge Address: {latestConvictionBadge}")
    ##
    #
    ConvictionBadgeContractAddress = latestConvictionBadge
    ConvictionBadgeContract = Contract(
        "ConvictionBadge",
        address=ConvictionBadgeContractAddress,
        abi=get_abi("ConvictionBadge"),
    )
    ConvictionBadgeId = ConvictionBadgeContract.tokenCounter()

    # =====DEPLOY NFT_ESCROW_FACTORY====
    VaultFactory.deploy(
        account, ConvictionBadgeContractAddress, mintBadgeFee, {"from": account}
    )
    latest_factory = VaultFactory[-1]
    setUp = latestConvictionBadge.setVFContractFirstTime(
        latest_factory, {"from": account}
    )
    #
    ##
    #
    # =====CREATE NEW TIME_LOCKED_VAULT=====
    newVault = latest_factory.createNewVault(
        True,
        "TrialVault",
        {"from": account, "gas_limit": gas_limit},
    )
    newVault.wait(1)
    latest_vault_address = latest_factory.getLatestVault()
    print(f"This is latest time locked wallet address: {latest_vault_address}")

    # =======MINT TEST_COLLECTIBLE_NFT=======
    (trialNFTContractAddress, trialNFTTokenId) = mint_trial_nft()
    print(trialNFTTokenId)
    print(
        f"Let's see if the latest TLV got included in Conviction Badge: {ConvictionBadgeContract.TimeLockedVaults(latest_vault_address)}"
    )
    print("Initiating the Time Lock.")

    # =====DEPOSIT_AND_LOCK_NFT=======
    initiate_a_time_lock(
        latest_vault_address,
        account,
        trialNFTContractAddress,
        trialNFTTokenId,
        LockPeriod,
        ConvictionBadgeContractAddress,
        ConvictionBadgeId,
        doWeMint=True,
    )

    # ======FAST_FORWARD_TIME_FOR_GANACHE=======
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        print("Fastforwarding the chain.")
        fast_forward(LockPeriod)
        # ======WITHDRAW_NFT========
    print("Withdrawing NFT.")
    withdrawNFT(
        latest_vault_address,
        account,
        trialNFTContractAddress,
        trialNFTTokenId,
        LockPeriod,
    )

    # Depositing the tokens once again to get two conviction badges for merging.
    initiate_a_time_lock(
        latest_vault_address,
        account,
        trialNFTContractAddress,
        trialNFTTokenId,
        LockPeriod,
        ConvictionBadgeContractAddress,
        ConvictionBadgeId,
        doWeMint=True,
    )
    # ======WITHDRAW_NFT========
    print("Withdrawing NFT.")

    # ======FAST_FORWARD_TIME_FOR_GANACHE=======
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        print("Fastforwarding the chain.")
        fast_forward(LockPeriod)
        # ======WITHDRAW_NFT========
    withdrawNFT(
        latest_vault_address,
        account,
        trialNFTContractAddress,
        trialNFTTokenId,
        LockPeriod,
    )
    mergeConvictions(ConvictionBadgeContractAddress, account)
    MergeContractAddress = ConvictionBadgeContract.getMergeContract()

    print(
        f"Here is the address list ==> ConvictionBadgeAddress:{ConvictionBadgeContractAddress}, MergeBadgesAddress: {MergeContractAddress}, NFT Escrow Factory Address: {latest_factory},TLV Address: {latest_vault_address}, TestCollectible: {trialNFTContractAddress}"
    )


def initiate_a_time_lock(
    ContractAddress,
    account,
    trialNFTContractAddress,
    trialNFTTokenId,
    LockPeriod,
    ConvictionBadgeContractAddress,
    ConvictionBadgeId,
    doWeMint=False,
):
    Latest_TLV = Contract(
        "TimeLockedVault", address=ContractAddress, abi=get_abi("TimeLockedVault")
    )
    tx = interface.IERC721(trialNFTContractAddress).approve(
        ContractAddress, trialNFTTokenId, {"from": account}
    )
    print(f"Balance of the contract before locking: {Latest_TLV.returnBalance()}")
    tx.wait(1)
    print(Latest_TLV.getUserInfo(account))

    lets_try_locking = Latest_TLV.DepositAndLockNFT(
        trialNFTContractAddress,
        trialNFTTokenId,
        LockPeriod,
        doWeMint,
        {
            "from": account,
            "gas_limit": gas_limit,
            "allow_revert": True,
            "value": mintBadgeFee,
        },
    )
    print(lets_try_locking)
    lets_try_locking.wait(1)
    print(Latest_TLV.getUserInfo(account))
    print(f"Balance of the contract after locking: {Latest_TLV.returnBalance()}")


def mergeConvictions(ConvictionBadgeContractAddress, account):
    ConvictionBadgeContract = Contract(
        "ConvictionBadge",
        address=ConvictionBadgeContractAddress,
        abi=get_abi("ConvictionBadge"),
    )
    MergeContractAddress = ConvictionBadgeContract.getMergeContract()

    MergeContract = Contract(
        "MergeBadges", address=MergeContractAddress, abi=get_abi("MergeBadges")
    )
    oldOwner0 = ConvictionBadgeContract.ownerOf(0)
    oldOwner1 = ConvictionBadgeContract.ownerOf(1)

    print(
        f"Owners of the Token ID 0 and Token ID 1, respectively: {oldOwner0} --- {oldOwner1}"
    )

    ConvictionBadgeContract.setApprovalForAll(
        MergeContractAddress, True, {"from": account}
    )
    lti = ConvictionBadgeContract.getTokenInfoLTI(0)
    lta = ConvictionBadgeContract.getTokenInfoLTA(0)
    lop = ConvictionBadgeContract.getTokenInfoLoP(0)

    print(f"LockedTokenID:{lti}, LockedTokenAddress:{lta}, LockPeriod:{lop}")
    ##
    print(f"Merge contract :{MergeContractAddress}")
    MergeContract.mergeBadges(
        [0, 1], {"from": account, "value": gas_limit, "gas_limit": gas_limit}
    )
    ##
    newOwner0 = ConvictionBadgeContract.ownerOf(0)
    newOwner1 = ConvictionBadgeContract.ownerOf(1)
    print(
        f"Owners of the Token ID 0 and Token ID 1, respectively: {newOwner0} --- {newOwner1}"
    )
    mergeContractAddress = ConvictionBadgeContract.getMergeContract({"from": account})

    print(f"Owner of the new token: {ConvictionBadgeContract.ownerOf(2)}")


def fast_forward(LockPeriod):
    chain = Chain()
    print(chain.time())
    current = chain.time()
    # fastforward a month
    if LockPeriod == 0:
        fastforward = current + 2592000
    # fastforward three months
    if LockPeriod == 1:
        fastforward = current + 2592000 * 3
    # fastforward six months
    if LockPeriod == 2:
        fastforward = current + 2592000 * 6
    # fast forward a year
    if LockPeriod == 3:
        fastforward = current + 2592000 * 12 + (2592000 / 6)

    chain.mine(1, fastforward)
    print(chain.time())


def withdrawNFT(
    ContractAddress, account, trialNFTContractAddress, trialNFTTokenId, LockPeriod
):
    Latest_TLV = Contract(
        "TimeLockedVault", address=ContractAddress, abi=get_abi("TimeLockedVault")
    )
    withdrawal = Latest_TLV.withdraw(
        trialNFTContractAddress, trialNFTTokenId, {"from": account}
    )
    withdrawal.wait(1)
    print(Latest_TLV.getUserInfo(account))


def mint_trial_nft():
    account = get_account()
    tx = TestCollectible.deploy({"from": account})
    testCollectible = TestCollectible[-1]
    create1 = testCollectible.createCollectible({"from": account})
    create1.wait(1)
    tokenId = testCollectible.tokenCounter() - 1
    latestTrialAddress = TestCollectible[-1]
    return (latestTrialAddress, tokenId)
