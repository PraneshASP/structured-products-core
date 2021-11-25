pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./utils/ReentrancyGuard.sol";

/**
 * @title Struct finance Principal LP token contract
 * @author Pranesh
 */

contract StructPLP is ERC1155, ReentrancyGuard {
    address public controller;
    uint256 public _currentPositionId;
    mapping(address => bool) minters;

    struct Position {
        uint256 _id;
        uint256 plpTokens; ///Number of principal tokens
        uint256 shareInPool; ///Share of aggregator position
    }

    mapping(uint256 => Position) public positions;

    // Contract name
    string public name;

    // Contract symbol
    string public symbol;

    ///Events
    event PositionCreated(uint256 positionId);

    modifier onlyController() {
        require(_msgSender() == controller, "Caller not controller");
        _;
    }

    constructor(
        address _controller,
        string memory _name,
        string memory _symbol
    ) ERC1155("") {
        controller = _controller;
        name = _name;
        symbol = _symbol;
        _currentPositionId = 0;
    }

    /**
     * @dev Creates a new position and mints a ERC1155 token to the user representing the position
     * @param _userWallet  The wallet address to send the PLP tokens.
     * @param _plpTokens   Number of principal tokens
     * @param _shareInPool  Share of aggregator position
     */
    function createNewPosition(
        address _userWallet,
        uint256 _plpTokens,
        uint256 _shareInPool
    ) external nonReentrant returns (uint256) {
        require(minters[_msgSender()], "Caller not minter");
        uint256 _id = _getNextTokenID();
        _incrementContractId();
        Position memory newPosition = Position(_id, _plpTokens, _shareInPool);
        positions[_id] = newPosition;
        _mint(_userWallet, _id, 1, ""); // Mint 1 StructPLP token to the user address
        emit PositionCreated(_id);
        return _id;
    }

    /**
    @dev Adds a new minter; only controller can call this method
    @param minter - Wallet address of minter
    @param enabled - set as 'true'/'false' to enable/disable    
    */

    function addMinter(address minter, bool enabled) external {
        require(_msgSender() == controller, "Caller not controller");
        minters[minter] = enabled;
    }

    /**
     * @dev calculates the next token ID based on value of _currentPositionId
     * @return uint256 for the next token ID
     */
    function _getNextTokenID() private view returns (uint256) {
        return _currentPositionId + 1;
    }

    /**
     * @dev increments the value of _currentPositionId
     */
    function _incrementContractId() private {
        _currentPositionId++;
    }

    function getPositionDetails(uint256 _positionId)
        external
        view
        returns (uint256, uint256)
    {
        return (
            positions[_positionId].plpTokens,
            positions[_positionId].shareInPool
        );
    }
}
