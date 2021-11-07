// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

interface IAlphaTranche {
    function unlockTimestamp() external view returns (uint256);
}
