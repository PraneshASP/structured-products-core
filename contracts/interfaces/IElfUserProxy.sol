// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

import "./Types.sol";

interface IElfUserProxy is Types {
    function mint(
        uint256 _amount,
        address _underlying,
        uint256 _expiration,
        address _position,
        PermitData[] calldata _permitCallData
    ) external payable returns (uint256, uint256);
}
