// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

/**
 * Library Like Contract. Not Required for deployment
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this;
        return msg.data;
    }

    function _msgValue() internal view virtual returns (uint256) {
        return msg.value;
    }
}
