pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IShareAddress.sol";

contract FractionToken is ERC20 {
    address StorageAddress;
    bool isActiveFraction;
    uint256 NFTID;

    function _transfer(address from, address to, uint256 tokenId) internal virtual override {
        IShareAddress ltoken = IShareAddress(StorageAddress);
        if(balanceOf(to) == 0) {
            ltoken.setUserShareAddress(address(this), to);
        }
        super._transfer(from, to, tokenId);
        if(balanceOf(from) == 0) {
            ltoken.removeUserShareAddress(address(this), from);
        }
    }

    constructor(
        string memory name,
        string memory symbol,
        uint256 _NFTID,
        uint256 initialSupply,
        address mintAddress,
        address _StorageAddress
    ) ERC20(name, symbol) {
        NFTID = _NFTID;
        StorageAddress = _StorageAddress;
        _mint(mintAddress, initialSupply);
        isActiveFraction = true;
    }

    function getContractDeployer() public view returns (address) {
        return StorageAddress;
    }

    function disableFractionForTokenWithdraw(address withdraw) public {
        require(msg.sender == StorageAddress, "Only the contract deployer can disable the fraction");
        require(isActiveFraction, "Fraction is already disabled");
        require(balanceOf(withdraw) == totalSupply(), "You do not own all shares");
        _burn(withdraw, totalSupply());
        isActiveFraction = false;
    }

    function getnftId() external view returns (uint256) {
        return NFTID;
    }
}