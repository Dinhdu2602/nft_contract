const {ethers} = require("hardhat")
const {BigNumber} = require("ethers")
const provider = ethers.provider
const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const {solidity} = require('ethereum-waffle')
const chai = require('chai')
chai.use(solidity)
const { expect } = require("chai")

describe("complex value splitter", function () {

    async function deployContract() {

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount1, otherAccount2] = await ethers.getSigners();
        // owner.estimateGas(3500000);

        const License = await ethers.getContractFactory("ERC721_Example");
        const license = await License.deploy();

        return {license, owner, otherAccount1, otherAccount2};
    }

    describe("Deploy contract", function () {
        it("should deploy", async function () {
            const {license} = await loadFixture(deployContract);
            expect(await license.owner()).to.not.equal(0);
        });
    });
    describe("Mint token", function () {
        it("should mint a token", async function () {
            const {license, owner,otherAccount1} = await loadFixture(deployContract);
            let ownerBalance = await provider.getBalance(owner.address);
            let otherBalance = await provider.getBalance(otherAccount1.address);
            license.connect(owner).setPrice(ethers.utils.parseEther("20.0"));
            let currentPrice = await license.getPrice();
            console.log(ethers.utils.parseEther(currentPrice.toString()))
            // console.log("owner balance: ", ownerBalance.toString());
            await license.connect(otherAccount1).mint(otherAccount1.address, "https://ipfs.io/",{value: ethers.utils.parseEther("20")});
            expect(await license.balanceOf(otherAccount1.address)).to.equal(1);
            expect(await provider.getBalance(owner.address)).to.equal(ownerBalance.add(ethers.utils.parseEther("20")));
        });
    });
})