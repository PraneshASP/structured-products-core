pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StructPLP is ERC20 {
    mapping(address => bool) minters;
    address public owner;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        owner = _msgSender();
    }

    function addMinter(address minter, bool enabled) external {
        require(_msgSender() == owner, "Caller not owner");
        minters[minter] = enabled;
    }

    function mint(uint256 value, address recipient) external {
        require(minters[_msgSender()], "Caller not minter");
        _mint(recipient, value);
    }
}
