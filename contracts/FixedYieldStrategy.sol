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
import "./Constants.sol";

/**
 * @title FixedYield strategy contract.
 */

contract FixedYieldStrategy is Ownable, ReentrancyGuard, Types {
    uint256 public slpInFarm;
    uint256 public totalPrincipalTokens = 0;

    uint256 public aFactor = 0;
    uint256 public pFactor = 0;

    // address public structPLPToken;
    IStructOracle structOracle;
    IStructPLP structPLPToken;

    ///Emit event on successful deposit
    event DepositSuccess(
        uint256 positionId,
        uint256 pTokenAmount,
        uint256 share
    );

    constructor(address _structPLPToken, address _structOracle) {
        structPLPToken = IStructPLP(_structPLPToken);
        structOracle = IStructOracle(_structOracle);
    }

    /**
     * @dev This `deposit()` method works as follows
     * 1. Split the deposit value into to parts A (X%) and B (1-X%)
     * 2. A gets deposited into Curve StEth pool -> gets back setCrv tokens
     * 3. The steCrv tokens are swapped for the Element finance principal tokens (ePyvcrvSTETH)
     * 4. 50% of B is swapped for DAI on Sushi
     * 5. Liquidity is added to the WETH/DAI pool
     * 6. The received SLP tokens are farmed
     * 7. Struct SP token(ERC1155) representing the user's position is minted to the user.
     */

    function deposit() external payable nonReentrant {
        (uint256 amountToCurve, uint256 amountToSushi) = this
            ._calculateDepositValue(_msgValue());
        uint256[2] memory amounts;
        amounts[0] = amountToCurve;

        /// Deposit ETH into Curve, obtain steCRV token
        ICurveFi(Constants.CURVE_ST_ETH_POOL).add_liquidity{
            value: amountToCurve
        }(amounts, 0);

        uint256 steCrvBalance = IERC20(Constants.STE_CRV_TOKEN).balanceOf(
            address(this)
        );

        ///Sell steCrv tokens for Element finance Principal tokens (ePyvcrvSTETH)
        uint256 elfPTokensReceived = _swapForElfPtokens(steCrvBalance);

        uint256 principalTokenShare = this._calculatePrincipalTokensShare(
            elfPTokensReceived
        );

        pFactor += principalTokenShare;
        totalPrincipalTokens += elfPTokensReceived;

        uint256 aggregatorShare = this._calculateAggregatorShare(amountToSushi);
        aFactor += aggregatorShare;

        uint256 positionId = structPLPToken.createNewPosition(
            _msgSender(),
            principalTokenShare,
            aggregatorShare
        );

        uint256 swapToDai = amountToSushi / 2;
        uint256 toLp = amountToSushi / 2;

        /// Sell 50% of ETH for DAI and add liquidity to the WETH/DAI pool
        this._swapForDAI(swapToDai);
        _addLiquidity(toLp);

        ///Farm the SLP tokens
        uint256 slpBalance = this._getSLPBalance();
        slpInFarm += slpBalance;
        _stakeSlpTokens(slpBalance);
        emit DepositSuccess(positionId, principalTokenShare, aggregatorShare);
    }

    // /**
    //  * @dev Estimates the stEth amount that'll be sent from CurveFi
    //  * @param depositAmount - Amount of ETH to be deposited to Curve StEth Pool
    //  * @return The estimated value of StEth from CurveFi
    //  */

    // function _estimateStEthValue(uint256 depositAmount)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     uint256[2] memory amounts;
    //     amounts[0] = depositAmount;
    //     return
    //         ICurveFi(Constants.CURVE_ST_ETH_POOL).calc_token_amount(
    //             amounts,
    //             true
    //         );
    // }

    /**
     * @dev Used to calculate the value to be deposited on CurveFi and Sushi
     * @param ethAmount - Amount of ETH deposited by the caller/user
     * @return The value to be sent to Sushi and Curve Pool
     */
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

    /**
     * @dev Utility function to calculate the number of days to mature
     * @param trancheEndsAt Tranche end timestamp
     * @return The number of days remaining to mature
     */
    function getDaysRemainingForMaturity(uint256 trancheEndsAt)
        external
        view
        returns (uint256)
    {
        return (trancheEndsAt - block.timestamp) / Constants.SECONDS_PER_DAY;
    }

    function _calculateDepositPercent()
        external
        view
        returns (uint256, uint256)
    {
        uint256 trancheEndsAt = _getUnlockTimestamp();

        uint256 daysRemaining = this.getDaysRemainingForMaturity(trancheEndsAt);

        ///Fixed rate set to 5% for now.
        ///Need to fetch the real time rate from Alpha finance

        uint256 toCurve = ((10**21 * 100) /
            (100 *
                10**3 +
                ((Constants.FIXED_RATE * daysRemaining * 1000) / 365)));

        uint256 toSushi = 1 * 10**18 - toCurve;

        return (toCurve, toSushi);
    }

    /**
     * @dev Used to swap the steCrv for ePyvcrvSTETH on Balancer
     * @param _steCrvAmount - Amount of ETH to be deposited
     * @return The received ePyvcrvSTETH from balancer
     */
    function _swapForElfPtokens(uint256 _steCrvAmount)
        internal
        returns (uint256)
    {
        IERC20(Constants.STE_CRV_TOKEN).approve(
            Constants.BALANCER_VAULT,
            _steCrvAmount
        );
        bytes32 poolId = 0xb03c6b351a283bc1cd26b9cf6d7b0c4556013bdb0002000000000000000000ab;
        SingleSwap memory singleSwap = SingleSwap(
            poolId,
            SwapKind.GIVEN_IN,
            Constants.STE_CRV_TOKEN,
            Constants.ELF_PTOKEN,
            _steCrvAmount,
            "0x00"
        );

        FundManagement memory fm = FundManagement(
            address(this),
            false,
            address(this),
            false
        );

        uint256 amountReceived = IBalancer(Constants.BALANCER_VAULT).swap(
            singleSwap,
            fm,
            0,
            block.timestamp + 2 minutes
        );
        return amountReceived;
    }

    /// Returns the tranche end timestamp
    function _getUnlockTimestamp() internal view returns (uint256) {
        return IAlphaTranche(Constants.ALPHA_P_TRANCHE).unlockTimestamp();
    }

    /// Returns the swap path based on the assets passed
    function _constructPath(address asset1, address asset2)
        internal
        view
        returns (address[] memory)
    {
        address[] memory path = new address[](2);
        path[0] = asset1;
        path[1] = asset2;
        return path;
    }

    function _getEstimate(uint256 _ethAmount) public view returns (uint256) {
        address[] memory path = _constructPath(Constants.WETH, Constants.DAI);
        return
            ISushi(Constants.SUSHI_ROUTER).getAmountsOut(_ethAmount, path)[1];
    }

    ///Swap ETH for DAI
    function _swapForDAI(uint256 _ethAmount) external payable returns (bool) {
        uint256 daiAmount = _getEstimate(_ethAmount);
        address[] memory path = _constructPath(Constants.WETH, Constants.DAI);

        ISushi(Constants.SUSHI_ROUTER).swapExactETHForTokens{value: _ethAmount}(
            daiAmount,
            path,
            address(this),
            block.timestamp + 15 minutes
        );
        return true;
    }

    function _getBalanceOfDAI() external view returns (uint256) {
        return IERC20(Constants.DAI).balanceOf(address(this));
    }

    function _getEthBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function _getSLPBalance() external view returns (uint256) {
        return IERC20(Constants.SLP_TOKEN).balanceOf(address(this));
    }

    function _wrap() external payable {
        IERC20(Constants.WETH).deposit{value: _msgValue()}();
    }

    ///Adds liquidity to the Sushi LP
    function _addLiquidity(uint256 _ethAmount) internal returns (bool) {
        uint256 _daiAmount = _getEstimate(_ethAmount);
        this._wrap{value: _ethAmount}();
        IERC20(Constants.DAI).approve(Constants.SUSHI_ROUTER, _daiAmount);
        IERC20(Constants.WETH).approve(Constants.SUSHI_ROUTER, _ethAmount);
        ISushi(Constants.SUSHI_ROUTER).addLiquidity(
            Constants.DAI,
            Constants.WETH,
            _daiAmount,
            _ethAmount,
            0,
            0,
            address(this),
            block.timestamp + 5 minutes
        );
        return true;
    }

    function _stakeSlpTokens(uint256 _slpAmount) internal returns (bool) {
        IERC20(Constants.SLP_TOKEN).approve(
            Constants.SUSHI_LP_STAKING_POOL,
            _slpAmount
        );
        ISushi(Constants.SUSHI_LP_STAKING_POOL).deposit(2, _slpAmount);
        return true;
    }

    function _setStructPlpTokenAddress(address _structPlpToken)
        external
        onlyOwner
    {
        structPLPToken = IStructPLP(_structPlpToken);
    }

    function _calculateSlpPrice() internal view returns (uint256) {
        uint256 _currentEthPrice = structOracle.getLatestETHPrice();
        (uint256 _daiReserve, uint256 _ethReserve, ) = ISLP(Constants.SLP_TOKEN)
            .getReserves();
        uint256 _totalSupply = ISLP(Constants.SLP_TOKEN).totalSupply();
        uint256 _price = (_daiReserve + ((_currentEthPrice) * _ethReserve)) /
            _totalSupply;
        return (_price * 10**18) / _currentEthPrice;
    }

    /// Calculates the share of the user in aggregator pool
    function _calculateAggregatorShare(uint256 _ethDeposited)
        external
        view
        returns (uint256)
    {
        if (aFactor == 0) return _ethDeposited;
        else {
            uint256 _slpPrice = _calculateSlpPrice();
            uint256 _tvl = (_slpPrice * slpInFarm) / 10**18;
            return (_ethDeposited * aFactor) / _tvl;
        }
    }

    function _calculatePrincipalTokensShare(uint256 _elfPTokensReceived)
        external
        view
        returns (uint256)
    {
        if (pFactor == 0) return _elfPTokensReceived;
        else return (_elfPTokensReceived * pFactor) / totalPrincipalTokens;
    }

    function _getElfPrincipalPrice() external view returns (uint256) {
        //TODO Return actual price;
        return 95 * 10**16; //0.95 ETH
    }

    function _getElfPrincipalTokenBalance() external view returns (uint256) {
        return IERC20(Constants.ELF_PTOKEN).balanceOf(address(this));
    }

    function _getTotalPrincipalValue() external view returns (uint256) {
        return
            (this._getElfPrincipalPrice() *
                this._getElfPrincipalTokenBalance()) / 10**18;
    }

    function _getTotalAggregatorValue() external view returns (uint256) {
        return (_calculateSlpPrice() * slpInFarm) / 10**18;
    }

    function _getPFactor() external view returns (uint256) {
        return pFactor;
    }

    function _getAFactor() external view returns (uint256) {
        return aFactor;
    }
}
