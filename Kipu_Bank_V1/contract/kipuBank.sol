// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title KipuBank
 * @author Pedro Arias: http://github.com/PedroAriasDev
 * @notice A secure banking contract that allows users to deposit and withdraw native tokens (ETH)
 * @dev Implements security best practices including CEI pattern, custom errors, and safe transfer handling
 */
contract KipuBank {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum amount that can be withdrawn per transaction
    /// @dev Immutable variable set during deployment
    uint256 public immutable WITHDRAWAL_LIMIT;

    /// @notice Maximum amount of ETH the bank can manage at any given time
    /// @dev Immutable variable set during deployment representing the bank's capacity
    uint256 public immutable BANK_CAP;

    /// @notice Current total balance held in the contract across all users
    uint256 public totalBalance;

    /// @notice Total number of deposit transactions executed
    uint256 public depositCount;

    /// @notice Total number of withdrawal transactions executed
    uint256 public withdrawalCount;

    /// @notice Mapping of user addresses to their vault balances
    mapping(address => uint256) private userVaults;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user successfully deposits ETH
    /// @param user Address of the depositor
    /// @param amount Amount deposited in wei
    /// @param newBalance User's new vault balance
    event Deposited(address indexed user, uint256 amount, uint256 newBalance);

    /// @notice Emitted when a user successfully withdraws ETH
    /// @param user Address of the withdrawer
    /// @param amount Amount withdrawn in wei
    /// @param remainingBalance User's remaining vault balance
    event Withdrawn(address indexed user, uint256 amount, uint256 remainingBalance);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when deposit amount is zero
    error KipuBank__DepositMustBeGreaterThanZero();

    /// @notice Thrown when deposit would exceed the bank's management capacity
    error KipuBank__BankCapExceeded();

    /// @notice Thrown when withdrawal amount is zero
    error KipuBank__WithdrawalMustBeGreaterThanZero();

    /// @notice Thrown when withdrawal amount exceeds the per-transaction limit
    error KipuBank__WithdrawalExceedsLimit();

    /// @notice Thrown when user tries to withdraw more than their vault balance
    error KipuBank__InsufficientBalance();

    /// @notice Thrown when ETH transfer fails
    error KipuBank__TransferFailed();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the KipuBank contract with withdrawal limit and bank capacity
     * @param _withdrawalLimit Maximum amount that can be withdrawn per transaction
     * @param _bankCap Maximum amount of ETH the bank can manage at any time
     */
    constructor(uint256 _withdrawalLimit, uint256 _bankCap) {
        WITHDRAWAL_LIMIT = _withdrawalLimit;
        BANK_CAP = _bankCap;
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ensures the amount is greater than zero
     * @param amount The amount to validate
     */
    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) {
            revert KipuBank__DepositMustBeGreaterThanZero();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows users to deposit ETH into their personal vault
     * @dev Follows CEI pattern and validates against bank capacity
     */
    function deposit() external payable nonZeroAmount(msg.value) {
        // Checks
        if (totalBalance + msg.value > BANK_CAP) {
            revert KipuBank__BankCapExceeded();
        }

        // Effects
        userVaults[msg.sender] += msg.value;
        totalBalance += msg.value;
        depositCount++;

        // Interactions (event emission)
        emit Deposited(msg.sender, msg.value, userVaults[msg.sender]);
    }

    /**
     * @notice Allows users to withdraw ETH from their vault
     * @dev Enforces withdrawal limit per transaction and validates sufficient balance
     * @param amount The amount of ETH to withdraw in wei
     */
    function withdraw(uint256 amount) external nonZeroAmount(amount) {
        // Checks
        if (amount > WITHDRAWAL_LIMIT) {
            revert KipuBank__WithdrawalExceedsLimit();
        }

        uint256 userBalance = userVaults[msg.sender];
        if (amount > userBalance) {
            revert KipuBank__InsufficientBalance();
        }

        // Effects
        userVaults[msg.sender] = userBalance - amount;
        totalBalance -= amount;
        withdrawalCount++;

        // Interactions
        _safeTransferETH(msg.sender, amount);

        emit Withdrawn(msg.sender, amount, userVaults[msg.sender]);
    }

    /**
     * @notice Returns the vault balance of a specific user
     * @param user Address of the user to query
     * @return balance The user's vault balance in wei
     */
    function getVaultBalance(address user) external view returns (uint256 balance) {
        return userVaults[user];
    }

    /**
     * @notice Returns the vault balance of the caller
     * @return balance The caller's vault balance in wei
     */
    function getMyBalance() external view returns (uint256 balance) {
        return userVaults[msg.sender];
    }

    /**
     * @notice Returns comprehensive contract statistics
     * @return currentBalance Current total balance managed by the bank
     * @return totalDepositsCount Total number of deposit transactions
     * @return totalWithdrawalsCount Total number of withdrawal transactions
     * @return withdrawalLimit Maximum withdrawal per transaction
     * @return bankCapacity Maximum balance the bank can manage
     */
    function getContractStats()
        external
        view
        returns (
            uint256 currentBalance,
            uint256 totalDepositsCount,
            uint256 totalWithdrawalsCount,
            uint256 withdrawalLimit,
            uint256 bankCapacity
        )
    {
        return (totalBalance, depositCount, withdrawalCount, WITHDRAWAL_LIMIT, BANK_CAP);
    }

    /*//////////////////////////////////////////////////////////////
                        PRIVATE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Safely transfers ETH to a recipient
     * @dev Uses low-level call to prevent issues with contracts that reject transfers
     * @param to Address to receive the ETH
     * @param amount Amount of ETH to transfer in wei
     */
    function _safeTransferETH(address to, uint256 amount) private {
        (bool success,) = payable(to).call{value: amount}("");
        if (!success) {
            revert KipuBank__TransferFailed();
        }
    }
}

