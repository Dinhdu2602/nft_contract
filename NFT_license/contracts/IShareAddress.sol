pragma solidity ^0.8.9;

abstract contract IShareAddress {
    mapping (address => address[]) userAddressToFractionAddress;
    function setUserShareAddress(address _shareAddress, address _userAddress) public virtual;
    function removeUserShareAddress(address _shareAddress, address _userAddress) public virtual;
}