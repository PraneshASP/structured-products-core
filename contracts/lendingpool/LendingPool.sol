//SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "../interfaces/IStructPLP.sol";
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
    uint256 public totalDeposited;
    uint256 public totalDebt;
    uint256 public ltvLimit;
    uint256 public liquidationThreshold;
    uint256 public liquidationBonus;
    mapping(address => uint256) usersDebtShare;

    struct LendingPosition {
        address user;
        uint256 pShare;
        uint256 aShare;
    }

    mapping(address => uint256[]) public tokensSuppliedAsCollateral;
    mapping(address => LendingPosition) public userLendingPositions;

    constructor(
        address _reserve,
        uint256 _ltvLimit,
        uint256 _liqThreshold,
        uint256 _liqBonus
    ) {
        RESERVE = _reserve;
        ltvLimit = _ltvLimit;
        liquidationThreshold = _liqThreshold;
        liquidationBonus = _liqBonus;
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
        require(amount > 0, "INSUFFICIENT_BALANCE");
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
}
