from brownie import network, accounts, config, interface
from web3 import Web3

OPENSEA_FORMAT = "https://testnets.opensea.io/assets/{}/{}"
NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["hardhat", "development", "ganache"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS + [
    "mainnet-fork",
    "binance-fork",
    "matic-fork",
]


def get_account(index=None, id=None):

    if index:
        return accounts[index]
    if id:
        return accounts.load(id)

    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS
    ):
        return accounts[0]
    else:
        return accounts.add(config["wallets"]["from_key"])


def getNFTName(nft_contract, account):
    name = nft_contract.name({"from": account})
    return name
