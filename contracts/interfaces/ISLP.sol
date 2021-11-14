// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

interface ISLP {
    function getReserves()
        external
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        );

    function totalSupply() external view returns (uint256);
}
