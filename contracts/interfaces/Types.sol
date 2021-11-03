// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

interface Types {
    // Memory encoding of the permit data
    struct PermitData {
        address tokenContract;
        address who;
        uint256 amount;
        uint256 expiration;
        bytes32 r;
        bytes32 s;
        uint8 v;
    }
}
