pragma solidity ^0.8.4;

interface IStructPLP {
    function createNewPosition(
        address newUser,
        uint256 _plpTokens,
        uint256 _shareInPool
    ) external returns (uint256);
}
