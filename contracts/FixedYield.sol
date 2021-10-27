//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./utils/Ownable.sol";
import "./interfaces/ICurveFi.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVault.sol";

/**
 * @title FixedYield strategy.
 */
contract FixedYield is Ownable {
    /*
     * @notice Curve addresses
     */
    address public constant CURVE_ST_ETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
    address public constant STE_CRV_TOKEN = 0x06325440D014e39736583c165C2963BA99fAf14E;

    /*
     * @notice Yearn addresses
     */
    address public constant YEARN_ST_ETH_VAULT = 0xdCD90C7f6324cfa40d7169ef80b12031770B4325;

    /**
     * @dev Will deposit ETH into Vault to execute strategy.
     */
    function deposit(uint256[2] calldata amounts) public payable {
        // 1. Deposit ETH into Curve StETH pool, obtain steCRV token
        ICurveFi(CURVE_ST_ETH_POOL).add_liquidity(amounts, 1);

        // Obtain updated user balance
        uint256 steCrvUserBalance = IERC20(STE_CRV_TOKEN).balanceOf(msg.sender);

        // 2. Deposit steCRV tokens into Yearn Finance
        IVault(YEARN_ST_ETH_VAULT).deposit(steCrvUserBalance);

        // TODO: 3. Deposit yvcrvSTETH into Element Finance
    }
}
