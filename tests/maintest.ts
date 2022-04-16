import { expect } from "chai";
import { defaultAccounts } from "ethereum-waffle";
import { ethers } from "hardhat";
import { deployConvictionBadge, deployVaultFactory, deployTestCollectible } from "../scripts/deploy";


var CBAddress = "0";
var VFAddress = "0";
const mintBadgeFee = 5000000000000000;
const vAddressThatImTooDumbToChange = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"



describe("createNewVault", function () {
    beforeEach(async () => {
        CBAddress = await deployConvictionBadge();
        console.log(CBAddress);
        VFAddress = await deployVaultFactory();
        const [trialNFTContractAddress, trialNFTTokenId] = await deployTestCollectible();
        console.log(VFAddress);

    });

    it("Should create a new timee-locked vault contract from the vault factory contract."), async function () {

        const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
        await vaultFactory.createNewVault(true, "TrialVault");
        const latestVaultAddress = await vaultFactory.getLatestVault();
        expect(await vaultFactory.getLatestVault()).to.not.eql("0x0000000000000000000000000000000000000000");
        const timeLockedVault = await (await ethers.getContractFactory("TimeLockedVault")).attach(VFAddress);
        expect(await timeLockedVault.vaultName()).to.eql("TrialVault");
        const [owner] = await ethers.getSigners();
        expect(await timeLockedVault.owner()).to.equal(owner.address);
    }
    /*     it("Should initiate a timelock from the TimeLockedVault."), async (trialNFTContractAddress: any, trialNFTTokenId: any) => {
            const [owner] = await ethers.getSigners();
            const vaultFactory = await (await ethers.getContractFactory("VaultFactory")).attach(VFAddress);
            const latestVaultAddress = await vaultFactory.getLatestVault();
            expect(await vaultFactory.getLatestVault().to.not.eql("0x0000000000000000000000000000000000000000"));
    
            const testCollectible = await (await ethers.getContractFactory("TestCollectible")).attach(trialNFTContractAddress);
            await testCollectible.approve(vfAddressThatImTooDumToChange, trialNFTTokenId);
            expect(await testCollectible.isApprovedOrOwner(vfAddressThatImTooDumToChange, trialNFTTokenId).to.eql(true));
    
    
            const timeLockedVault = await (await (await ethers.getContractFactory("TimeLockedVault")).attach(vfAddressThatImTooDumToChange));
            let lockPeriod = 1;
            let doWeMint = true;
            timeLockedVault.DepositAndLockNFT(trialNFTContractAddress, trialNFTTokenId, lockPeriod, doWeMint, { value: mintBadgeFee });
            expect(await timeLockedVault.returnBalance().to.be.above(0));
            expect(await testCollectible.owner().to.eql(vfAddressThatImTooDumToChange));
        } */
});

