// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

import "./Types.sol";

interface IBalancer is Types {
    function swap(
        SingleSwap calldata singleSwap,
        FundManagement calldata funds,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256 assetDelta);
}
