pragma solidity >=0.6.0;

interface IStructOracle {
    function getLatestETHPrice() external view returns (uint256);
}
