const {ethers} = require("hardhat")
const {BigNumber} = require("ethers")

const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const {solidity} = require('ethereum-waffle')
const chai = require('chai')
chai.use(solidity)
const { expect } = require("chai")

describe("complex attributes splitter", function () {
        async function deployContract() {

            // Contracts are deployed using the first signer/account by default
            const [owner, otherAccount1, otherAccount2] = await ethers.getSigners();
            // owner.estimateGas(3500000);

            const Contract = await ethers.getContractFactory("Complex_Attributes_Contract");
            const contract = await Contract.deploy();

            return {contract, owner, otherAccount1, otherAccount2};
        }
        describe("Deploy", function () {
            it("should deploy to the right owner", async function () {
                const {contract,owner} = await loadFixture(deployContract);
                expect(await contract.owner()).to.not.equal(0);
                expect(await contract.owner()).to.equal(owner.address);
            });
        })
        describe("Mint", function () {
            it("should mint a token", async function () {
                const {contract, owner} = await loadFixture(deployContract);
                await contract.connect(owner).mint(owner.address, "https://ipfs.io/", "xe may", "honda", ["den_led","lop_xe","phanh"],["led sieu sang","Lop cang","abs"],
                    ["den_led","lop_xe"],["led sieu sang","Lop cang"],["https://ipfs.io/","https://ipfs.io/"],
                    [["pin","loai"],["cao su","ap suat"]],[["200v","hoi sang"],["michelin","2.5 bar"]]
                    );
                expect(await contract.balanceOf(owner.address)).to.equal(1);
                expect(await contract.ownerOf(1)).to.equal(owner.address);
                console.log(await contract.getAttributes(1))
                await contract.connect(owner).mint(owner.address, "example","phanh","abs",[],[],[],[],[],[],[]);
                await contract.connect(owner).addTrait(4,1);
                console.log(await contract.getAttributes(1));
                await contract.connect(owner).removeTraitAt(1,1);
                console.log(await contract.getAttributes(1));
                expect(await contract.tokenOfOwner(owner.address)).to.deep.equal([BigNumber.from(1),BigNumber.from(3)]);
            })
        })
    }
)

// function mint(address to, string memory tokenURI, string memory majorName, string memory majorValue,
//     string[] memory acceptNames, string[] memory acceptValues,
//     string[] memory attributes, string[] memory values, string[] memory attrURI,
//     string[][] memory acceptAttrNames, string[][] memory acceptAttrValue)