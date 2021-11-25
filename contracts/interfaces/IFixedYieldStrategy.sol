// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

interface IFixedYieldStrategy {
    function _getTotalPrincipalValue() external view returns (uint256);

    function _getTotalAggregatorValue() external view returns (uint256);

    function _getPFactor() external view returns (uint256);

    function _getAFactor() external view returns (uint256);
}
