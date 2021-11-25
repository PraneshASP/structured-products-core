//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../interfaces/IStructPLP.sol";
import "../interfaces/ISToken.sol";
import "../interfaces/IFixedYieldStrategy.sol";

import "../utils/Context.sol";

/**
 * @title LendingPool contract
 * @dev Main point of interaction with the Struct protocol's lending markets
 * - Users can:
 *   # Deposit
 *   # Withdraw
 *   # Borrow
 *   # Repay
 *   # Liquidate positions
 * @author StructFi
 **/

contract LendingPool is Context, ERC1155Holder {
    address public immutable RESERVE;
    address public immutable STRATEGY;

    uint256 public totalDeposited;
    uint256 public totalDebt;
    uint256 public dFactor;

    uint256 public ltvLimit;
    uint256 public liquidationThreshold;
    uint256 public liquidationBonus;
    uint256 public totalSTokensMinted;

    address public SToken;

    mapping(address => uint256) usersDebtShare;
    mapping(address => uint256[]) public tokensSuppliedAsCollateral;
    mapping(address => LendingPosition) public userLendingPositions;
    mapping(address => uint256) public totalEthLent;

    struct LendingPosition {
        address user;
        uint256 pShare;
        uint256 aShare;
    }

    constructor(
        address _reserve,
        address _sToken,
        address _strategyAddress,
        uint256 _ltvLimit /*, uint256 _liqThreshold, uint256 _liqBonus*/
    ) {
        RESERVE = _reserve;
        STRATEGY = _strategyAddress;
        SToken = _sToken;
        ltvLimit = _ltvLimit;
        //  liquidationThreshold = _liqThreshold;
        //  liquidationBonus=_liqBonus;
    }

    function depositCollateral(uint256 _spTokenId) external {
        require(
            IStructPLP(RESERVE).isApprovedForAll(_msgSender(), address(this)),
            "NOT_APPROVED"
        );
        uint256 amount = IStructPLP(RESERVE).balanceOf(
            _msgSender(),
            _spTokenId
        );
        require(amount > 0, "INSUFFICIENT_BAL");
        (uint256 _pShare, uint256 _aShare) = IStructPLP(RESERVE)
            .getPositionDetails(_spTokenId);
        if (userLendingPositions[_msgSender()].user == address(0)) {
            LendingPosition memory newPosition = LendingPosition(
                _msgSender(),
                _pShare,
                _aShare
            );
            userLendingPositions[_msgSender()] = newPosition;
        } else {
            LendingPosition storage userPosition = userLendingPositions[
                _msgSender()
            ];
            userPosition.pShare += _pShare;
            userPosition.aShare += _aShare;
        }

        tokensSuppliedAsCollateral[_msgSender()].push(_spTokenId);
        IStructPLP(RESERVE).safeTransferFrom(
            _msgSender(),
            address(this),
            _spTokenId,
            amount,
            ""
        );
    }

    function getTokensSuppliedAsCollateral(address user)
        external
        view
        returns (uint256[] memory)
    {
        return tokensSuppliedAsCollateral[_msgSender()];
    }

    function lendEth() external payable returns (bool) {
        require(
            _msgValue() <= _msgSender().balance,
            "INSUFFICIENT_ETH_BALANCE"
        );
        require(_msgValue() > 0, "CANNOT_LEND_ZERO_ETH");
        totalEthLent[_msgSender()] += _msgValue();
        uint256 sTokensAmount = this._calculateSTokens(_msgValue());
        totalSTokensMinted += sTokensAmount;
        totalDeposited += _msgValue();
        ISToken(SToken).mint(sTokensAmount, _msgSender());
        return true;
    }

    function _calculateSTokens(uint256 ethSent)
        external
        view
        returns (uint256)
    {
        if (totalSTokensMinted == 0) return ethSent;
        else {
            return (ethSent * totalSTokensMinted) / totalDeposited;
        }
    }

    function getEthBalance(address _addr) external view returns (uint256) {
        return _addr.balance;
    }

    function _getCollateralValue(address _userAddress)
        external
        view
        returns (uint256)
    {
        LendingPosition memory userPosition = userLendingPositions[
            _userAddress
        ];
        uint256 userPrincipalShare = userPosition.pShare;
        uint256 userAggregatorShare = userPosition.aShare;
        IFixedYieldStrategy strategy = IFixedYieldStrategy(STRATEGY);
        uint256 totalPrincipalValue = strategy._getTotalPrincipalValue();
        uint256 totalAggregatorValue = strategy._getTotalAggregatorValue();
        uint256 pFactor = strategy._getPFactor();
        uint256 aFactor = strategy._getAFactor();

        uint256 pVal = (userPrincipalShare / pFactor) * totalPrincipalValue;
        uint256 aVal = (userAggregatorShare / aFactor) * totalAggregatorValue;

        return pVal + aVal;
    }

    function _calculateDebtShare(uint256 _borrowAmount)
        external
        view
        returns (uint256)
    {
        if (dFactor == 0) return _borrowAmount;
        else {
            return (_borrowAmount * dFactor) / totalDebt;
        }
    }

    function _getDebtValueOfUser(address _user)
        external
        view
        returns (uint256)
    {
        if (dFactor == 0) return 0;

        uint256 debtShare = usersDebtShare[_user];
        return (debtShare * totalDebt) / dFactor;
    }

    function _calculateMaxAllowableLoan(address _user)
        external
        view
        returns (uint256)
    {
        return
            ltvLimit *
            (this._getCollateralValue(_user) - this._getDebtValueOfUser(_user));
    }

    function borrow(uint256 _borrowAmount) external returns (bool) {
        require(_borrowAmount > 0, "CANNOT_BORROW_ZERO");
        uint256 maxAllowableLoan = this._calculateMaxAllowableLoan(
            _msgSender()
        );
        require(
            maxAllowableLoan > _borrowAmount,
            "BORROW_AMOUNT_EXCEEDS_LIMIT"
        );

        uint256 availableToLend = totalDeposited - totalDebt;
        require(
            availableToLend > _borrowAmount,
            "BORROW_AMOUNT_EXCEEDS_LIMIT2"
        );
        uint256 debtShare = this._calculateDebtShare(_borrowAmount);
        usersDebtShare[_msgSender()] += debtShare;
        dFactor += debtShare;
        totalDebt += _borrowAmount;

        //Transfer ETH to the user

        payable(_msgSender()).transfer(_borrowAmount);

        return true;
    }
}
