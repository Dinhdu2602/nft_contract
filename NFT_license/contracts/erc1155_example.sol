pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC1155, Ownable {
    uint[] tokenIds;
    //handle arrays
    function contains(uint[] memory arr, uint elem) pure private returns (bool){
        for(uint i=0; i<arr.length; i++){
            if(arr[i] == elem){
                return true;
            }
        }
        return false;
    }

    constructor() ERC1155("https://game.example/api/item/{id}.json") {}

    // Hàm mint token
    function mint(address to, uint256 id, uint256 amount) public payable {
        // Kiểm tra xem người dùng có đủ ETH để thanh toán phí hay không
        require(msg.value >= _fee, "Not enough ETH to pay fee");

        // Mint token
        _mint(to, id, amount, "");
        if(!contains(tokenIds, id)){
            tokenIds.push(id);
        }

        // Chuyển ETH cho owner của contract
        payable(owner()).transfer(_fee);
    }

    // Phí mint token
    uint256 private _fee = 0.01 ether;

    // Getter cho phí mint token
    function fee() public view returns (uint256) {
        return _fee;
    }

    // Thay đổi phí mint token
    function setFee(uint256 newFee) public onlyOwner {
        _fee = newFee;
    }

    function getTokenIds()external view returns(uint[] memory){
        return tokenIds;
    }
}