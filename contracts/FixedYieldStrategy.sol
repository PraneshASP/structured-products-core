//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interfaces/ICurveFi.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IVault.sol";
import "./interfaces/IAlphaTranche.sol";
import "./interfaces/IBalancer.sol";
import "./interfaces/IElfUserProxy.sol";
import "./interfaces/Types.sol";
import "./interfaces/ISushi.sol";
import "./interfaces/IStructPLP.sol";
import "./interfaces/IStructOracle.sol";
import "./interfaces/ISLP.sol";

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
    address public constant SUSHI_LP_STAKING_POOL =
        0xc2EdaD668740f1aA35E4D8f227fB8E17dcA888Cd;

    address public constant SLP_TOKEN =
        0xC3D03e4F041Fd4cD388c549Ee2A29a9E5075882f;

    uint256 public slpInFarm;

    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

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

    uint256 public yFactor = 0;

    // address public structPLPToken;
    IStructOracle structOracle;
    IStructPLP structPLPToken;

    event DepositSuccess(
        uint256 positionId,
        uint256 pTokenAmount,
        uint256 share
    );

    constructor(address _structPLPToken, address _structOracle) {
        structPLPToken = IStructPLP(_structPLPToken);
        structOracle = IStructOracle(_structOracle);
    }

    function deposit() external payable nonReentrant {
        (uint256 amountToCurve, uint256 amountToSushi) = this
            ._calculateDepositValue(_msgValue());
        uint256[2] memory amounts;
        amounts[0] = amountToCurve;

        /// Deposit ETH into Curve, obtain steCRV token
        ICurveFi(CURVE_ST_ETH_POOL).add_liquidity{value: amountToCurve}(
            amounts,
            0
        );

        uint256 steCrvBalance = IERC20(STE_CRV_TOKEN).balanceOf(address(this));

        ///Sell steCrv tokens for Element finance Principal token
        uint256 elfPTokensReceived = this._swapForElfPtokens(steCrvBalance);

        uint256 principalTokens = elfPTokensReceived;
        uint256 share = this._calculateShare(amountToSushi);
        yFactor += share;
        uint256 positionId = structPLPToken.createNewPosition(
            _msgSender(),
            principalTokens,
            share
        );

        uint256 swapToDai = amountToSushi / 2;
        uint256 toLp = amountToSushi / 2;

        /// Sell 50% of ETH for DAI and add liquidity to the WETH/DAI pool
        this._swapForDAI(swapToDai);
        this._addLiquidity(toLp);

        ///Farm the SLP tokens
        uint256 slpBalance = this._getSLPBalance();
        slpInFarm += slpBalance;
        this._stakeSlpTokens(slpBalance);
        emit DepositSuccess(positionId, principalTokens, share);
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

        // uint256 toCurve = 1 *10**18 -
        //     365 * 10**18 /
        //     (DAYS_REMAINING * (10000+FIXED_RATE)/10**2); //TODO: Should be 1.05

        uint256 toCurve = ((10**21 * 100) /
            (100 * 10**3 + ((FIXED_RATE * DAYS_REMAINING * 1000) / 365)));

        uint256 toSushi = 1 * 10**18 - toCurve;

        return (toCurve, toSushi);
    }

    function _swapForElfPtokens(uint256 _steCrvAmount)
        external
        returns (uint256)
    {
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

        uint256 amountReceived = IBalancer(BALANCER_VAULT).swap(
            singleSwap,
            fm,
            0,
            block.timestamp + 10 minutes
        );
        return amountReceived;
    }

    function getUnlockTimestamp() internal view returns (uint256) {
        return IAlphaTranche(ALPHA_P_TRANCHE).unlockTimestamp();
    }

    function _getEstimate(uint256 _ethValue) public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = DAI;
        return ISushi(SUSHI_ROUTER).getAmountsOut(_ethValue, path)[1];
    }

    function _swapForDAI(uint256 _ethAmount) external payable returns (bool) {
        uint256 daiAmount = _getEstimate(_ethAmount);
        address[] memory path = new address[](2);

        path[0] = WETH;
        path[1] = DAI;
        ISushi(SUSHI_ROUTER).swapExactETHForTokens{value: _ethAmount}(
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

    function _getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function _getSLPBalance() external view returns (uint256) {
        return IERC20(SLP_TOKEN).balanceOf(address(this));
    }

    function _addLiquidity(uint256 _ethAmount) external returns (bool) {
        uint256 _daiAmount = _getEstimate(_ethAmount);
        this._wrap{value: _ethAmount}();
        IERC20(DAI).approve(SUSHI_ROUTER, _daiAmount);
        IERC20(WETH).approve(SUSHI_ROUTER, _ethAmount);
        ISushi(SUSHI_ROUTER).addLiquidity(
            DAI,
            WETH,
            _daiAmount,
            _ethAmount,
            0,
            0,
            address(this),
            block.timestamp + 15 minutes
        );
        return true;
    }

    function _wrap() external payable {
        IERC20(WETH).deposit{value: _msgValue()}();
    }

    function _stakeSlpTokens(uint256 _slpAmount) external returns (bool) {
        IERC20(SLP_TOKEN).approve(SUSHI_LP_STAKING_POOL, _slpAmount);
        ISushi(SUSHI_LP_STAKING_POOL).deposit(2, _slpAmount);
        return true;
    }

    function _setStructPlpTokenAddress(address _structPlpToken)
        external
        onlyOwner
    {
        structPLPToken = IStructPLP(_structPlpToken);
    }

    function _calculateShare(uint256 _ethDeposited)
        external
        view
        returns (uint256)
    {
        if (yFactor == 0) return _ethDeposited;
        else {
            uint256 _slpPrice = this._calculateSlpPrice();
            uint256 _tvl = (_slpPrice * slpInFarm) / 10**18;
            return ((_ethDeposited / _tvl) * yFactor);
        }
    }

    function _calculateSlpPrice() external view returns (uint256) {
        uint256 _currentEthPrice = structOracle.getLatestETHPrice();
        (uint256 _daiReserve, uint256 _ethReserve, ) = ISLP(SLP_TOKEN)
            .getReserves();
        uint256 _totalSupply = ISLP(SLP_TOKEN).totalSupply();
        uint256 _price = (_daiReserve + ((_currentEthPrice) * _ethReserve)) /
            _totalSupply;
        return (_price * 10**18) / _currentEthPrice;
    }
}
