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

    //Balancer Structs
    enum SwapKind {
        GIVEN_IN,
        GIVEN_OUT
    }

    struct SingleSwap {
        bytes32 poolId;
        SwapKind kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }
}
