//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "../utils/Ownable.sol";
import "../utils/ReentrancyGuard.sol";
import "../interfaces/ICurveFi.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IVault.sol";
import "../interfaces/IAlphaTranche.sol";
import "../interfaces/IBalancer.sol";
import "../interfaces/IElfUserProxy.sol";
import "../interfaces/Types.sol";
import "../interfaces/ISushiRouter02.sol";

/**
 * @title FixedYield strategy.
 */
contract FixedYieldStrategy is Ownable, ReentrancyGuard, Types {
    /**
     * @notice Curve addresses
     */

    address public constant CURVE_ST_ETH_POOL =
        0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;

    uint256 SECONDS_PER_DAY = 86400;

    address public constant STE_CRV_TOKEN =
        0x06325440D014e39736583c165C2963BA99fAf14E;

    address public constant BALANCER_VAULT =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    address public constant SUSHI_ROUTER =
        0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    event Estimate(
        uint256 stEth,
        uint256 ethAmount,
        uint256 setCrvSold,
        uint256 pTokenBal
    );
    /**
     * @notice Yearn addresses
     */

    address public constant YEARN_ST_ETH_VAULT =
        0xdCD90C7f6324cfa40d7169ef80b12031770B4325;

    address public ALPHA_P_TRANCHE = 0x2361102893CCabFb543bc55AC4cC8d6d0824A67E;

    address public yvCurve_stETH = 0xdCD90C7f6324cfa40d7169ef80b12031770B4325;
    address public ELF_USER_PROXY = 0xEe4e158c03A10CBc8242350d74510779A364581C;
    address public ELF_yvCurve_stETH =
        0xB3295e739380BD68de96802F7c4Dba4e54477206;

    address public ELF_PTOKEN = 0x2361102893CCabFb543bc55AC4cC8d6d0824A67E;
    address public ELF_YTOKEN = 0xEb1a6C6eA0CD20847150c27b5985fA198b2F90bD;

    address public constant STRUCT_PLP =
        0x4EE6eCAD1c2Dae9f525404De8555724e3c35d07B;

    /**
     * @dev Will deposit ETH into Vault to execute strategy.
     */
    function deposit() external payable {
        (uint256 amountToCurve, uint256 amountToSushi) = this
            ._calculateDepositValue(_msgValue());
        uint256[2] memory amounts;
        amounts[0] = amountToCurve;

        uint256 stEthEstimate = ICurveFi(CURVE_ST_ETH_POOL).calc_token_amount(
            amounts,
            true
        );

        // /// 1. Deposit ETH into Curve StETH pool, obtain steCRV token
        ICurveFi(CURVE_ST_ETH_POOL).add_liquidity{value: amountToCurve}(
            amounts,
            0
        );

        uint256 steCrvBalance = IERC20(STE_CRV_TOKEN).balanceOf(address(this));

        this._swapForElfPtokens(steCrvBalance);

        uint256 steCrvBalanceAfter = IERC20(STE_CRV_TOKEN).balanceOf(
            address(this)
        );

        // /// 4. Mint ePyvcrvSTETH & eYyvcrvSTETH

        uint256 pTokenBalance = IERC20(ELF_PTOKEN).balanceOf(address(this));

        /// 5. Mint PoL tokens (structPLP tokens) representing the user's position
        /// 1:1 ePyvcrvSTETH

        // IERC20(STRUCT_PLP).mint(pTokenBalance,_msgSender());

        /// eYyvcrvSTETH -> steCrv

        /// END

        emit Estimate(stEthEstimate, _msgValue(), steCrvBalance, pTokenBalance);
    }

    function _estimateStEthValue(uint256 depositAmount)
        external
        view
        returns (uint256)
    {
        uint256[2] memory amounts;
        amounts[0] = depositAmount;
        return ICurveFi(CURVE_ST_ETH_POOL).calc_token_amount(amounts, true);
    }

    function _calculateDepositValue(uint256 ethAmount)
        external
        view
        returns (uint256, uint256)
    {
        (uint256 elfPercent, uint256 alphaPercent) = this
            ._calculateDepositPercent();

        uint256 amountToCurve = elfPercent * ethAmount;
        uint256 amountToAlphaFinance = alphaPercent * ethAmount;

        return (amountToCurve / 10**18, amountToAlphaFinance / 10**18);
    }

    function getDaysRemainingForMaturity(uint256 TRANCHE_END_TIMESTAMP)
        external
        view
        returns (uint256)
    {
        return (TRANCHE_END_TIMESTAMP - block.timestamp) / SECONDS_PER_DAY;
    }

    function _calculateDepositPercent()
        external
        view
        returns (uint256, uint256)
    {
        uint256 TRANCHE_END_TIMESTAMP = getUnlockTimestamp();

        uint256 DAYS_REMAINING = this.getDaysRemainingForMaturity(
            TRANCHE_END_TIMESTAMP
        );
        //  ///Set to 5% for now. Need to fetch the real time rate from Alpha finance
        uint256 FIXED_RATE = 5;

        uint256 toCurve = 1 *
            10**18 -
            (365 * 10**18) /
            (DAYS_REMAINING * FIXED_RATE);
        uint256 toAlpha = 1 * 10**18 - toCurve;
        return (toCurve, toAlpha);
    }

    function _swapForElfPtokens(uint256 _steCrvAmount) external returns (bool) {
        IERC20(STE_CRV_TOKEN).approve(BALANCER_VAULT, _steCrvAmount);
        bytes32 poolId = 0xb03c6b351a283bc1cd26b9cf6d7b0c4556013bdb0002000000000000000000ab;
        SingleSwap memory singleSwap = SingleSwap(
            poolId,
            SwapKind.GIVEN_IN,
            STE_CRV_TOKEN,
            ELF_PTOKEN,
            _steCrvAmount,
            "0x00"
        );
        FundManagement memory fm = FundManagement(
            address(this),
            false,
            address(this),
            false
        );
        IBalancer(BALANCER_VAULT).swap(
            singleSwap,
            fm,
            0,
            block.timestamp + 10 minutes
        );
        return true;
    }

    function getUnlockTimestamp() internal view returns (uint256) {
        return IAlphaTranche(ALPHA_P_TRANCHE).unlockTimestamp();
    }

    function _getEstimate(uint256 _ethValue) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;
        return ISushiRouter02(SUSHI_ROUTER).getAmountsOut(_ethValue, path)[1];
    }

    function _swapForDAI(uint256 _ethAmount) external payable returns (bool) {
        uint256 swappable = _ethAmount;
        uint256 daiAmount = _getEstimate(swappable);
        address[] memory path = new address[](2);

        path[0] = WETH;
        path[1] = DAI;
        ISushiRouter02(SUSHI_ROUTER).swapExactETHForTokens{value: swappable}(
            daiAmount,
            path,
            address(this),
            block.timestamp + 15 minutes
        );
        return true;
    }

    function _getBalanceOfDAI() external view returns (uint256) {
        return IERC20(DAI).balanceOf(address(this));
    }

    function _addLiquidity(uint256 _ethAmount) external payable returns (bool) {
        uint256 _daiAmount = _getEstimate(_ethAmount);

        IERC20(DAI).approve(SUSHI_ROUTER, _daiAmount);
        ISushiRouter02(SUSHI_ROUTER).addLiquidityETH{value: _ethAmount}(
            DAI,
            _daiAmount,
            _daiAmount - 100 * 10**18,
            _ethAmount,
            address(this),
            block.timestamp + 15 minutes
        );
        return true;
    }

    /// Conversion Module
    /// steCrv -> ETH ()
}
