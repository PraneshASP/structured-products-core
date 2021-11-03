// SPDX-License-Identifier: ISC

pragma solidity ^0.8.4;

interface ICurveFi {
    function get_virtual_price() external view returns (uint256);

    function calc_token_amount(uint256[2] calldata _amounts, bool isDeposit)
        external
        view
        returns (uint256);

    function add_liquidity(uint256[2] calldata amounts, uint256 min_mint_amount)
        external
        payable;

    function remove_liquidity(uint256 _amount, uint256[2] calldata amounts)
        external;
}
