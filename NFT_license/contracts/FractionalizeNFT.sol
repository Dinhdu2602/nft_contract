pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import './FractionToken.sol';
import './IShareAddress.sol';

contract FractionalizeNFT is IERC721Receiver, IShareAddress {

    address NFTContractAddress;
    constructor(address _NFTContractAddress) {
        NFTContractAddress = _NFTContractAddress;
    }
    address[] fractionContracts;

    function depositNft(uint256 _nftId) internal {
        //address must approve this contract to transfer the nft they own before calling this function
        //fractionalize contract needs to hold the nft so it can be fractionalize
        ERC721 NFT = ERC721(NFTContractAddress);
        NFT.safeTransferFrom(msg.sender, address(this), _nftId);
    }

    function createFraction(string memory _fractionName, string memory _factionSymbol, uint256 _nftid,uint256 _initialSupply, address _mintAddress) public {
        depositNft(_nftid);
        FractionToken fractionToken = new FractionToken(_fractionName, _factionSymbol, _nftid, _initialSupply, _mintAddress, address(this));
        fractionContracts.push(address(fractionToken));
        setUserShareAddress(address(fractionToken), _mintAddress);
    }

    function setUserShareAddress(address _shareAddress, address _userAddress) public override {
        require(checkIfFractionExists(_shareAddress)||msg.sender==address(this), "Only fractions or the contract itself can call this function");
        userAddressToFractionAddress[_userAddress].push(_shareAddress);
    }

    function removeUserShareAddress(address _shareAddress, address _userAddress) public override {
        require(checkIfFractionExists(_shareAddress)||msg.sender==address(this), "Only fractions or the contract itself can call this function");
        for (uint256 i = 0; i < userAddressToFractionAddress[_userAddress].length; i++) {
            if (userAddressToFractionAddress[_userAddress][i] == _shareAddress) {
                userAddressToFractionAddress[_userAddress][i] = userAddressToFractionAddress[_userAddress][userAddressToFractionAddress[_userAddress].length - 1];
                userAddressToFractionAddress[_userAddress].pop();
                break;
            }
        }
    }

    function getUserFractions(address useraddress) view external returns (address[] memory){
        return userAddressToFractionAddress[useraddress];
    }

    function checkIfFractionExists(address _fractionContract) internal view returns (bool) {
        for (uint256 i = 0; i < fractionContracts.length; i++) {
            if (fractionContracts[i] == _fractionContract) {
                return true;
            }
        }
        return false;
    }

    //can withdraw the NFT if you own the total supply
    function withdrawNft(address _fractionContract) public {
        //address must approve this contract to transfer fraction tokens

        FractionToken fraction = FractionToken(_fractionContract);

        require(fraction.getContractDeployer() == address(this), "Only fraction tokens created by this fractionalize contract can be accepted");
        require(checkIfFractionExists(_fractionContract), "Fraction contract does not exist");
        require(fraction.balanceOf(msg.sender) == fraction.totalSupply(), "You do not own all shares");
        uint256 NFTId = fraction.getnftId();

        //remove tokens from existence as they are no longer valid (NFT leaving this contract)
        fraction.disableFractionForTokenWithdraw(msg.sender);

        ERC721 NFT = ERC721(NFTContractAddress);
        NFT.safeTransferFrom(address(this), msg.sender, NFTId);
        removeUserShareAddress(address(_fractionContract), msg.sender);
        //remove unused fraction contract
        for(uint256 i = 0; i<fractionContracts.length; i++){
            if(fractionContracts[i] == _fractionContract){
                fractionContracts[i] = fractionContracts[fractionContracts.length-1];
                fractionContracts.pop();
                break;
            }
        }
    }

    //required function for ERC721
    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}