from solcx import compile_source
import json
from web3 import Web3


def get_abi(contractName):

    json_file = open(f"./build/contracts/{contractName}.json")
    variables = json.load(json_file)
    json_file.close()
    abi = variables["abi"]
    return abi

    """ with open("./build/contracts/TimeLockedWallet.json", "r") as file:
        time_locked_wallet = file.read()
        print(time_locked_wallet)
 """
