// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title KipuBankV2
 * @author Arias, Pedro. Git_Hub: https://github.com/PedroAriasDev
 * @notice A production-grade multi-token banking contract with role-based access control and Chainlink price feeds
 * @dev Implements AccessControl, supports ETH and ERC20 tokens, uses Chainlink oracles for USD conversion
 */
contract KipuBankV2 is AccessControl {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Structure to store user balance information for a specific token
    /// @param balance Current balance in token's native decimals
    /// @param totalDeposited Cumulative amount deposited (for analytics)
    /// @param totalWithdrawn Cumulative amount withdrawn (for analytics)
    struct TokenBalance {
        uint256 balance;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
    }

    /// @notice Structure to store token configuration
    /// @param isSupported Whether this token is accepted by the bank
    /// @param priceFeed Chainlink price feed address for this token
    /// @param decimals Token decimals
    struct TokenConfig {
        bool isSupported;
        address priceFeed;
        uint8 decimals;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Role identifier for admin operations
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Role identifier for treasury operations
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");

    /// @notice Address representation for native ETH (address(0))
    address public constant ETH_ADDRESS = address(0);

    /// @notice Target decimals for internal accounting (USDC standard: 6 decimals)
    uint8 public constant ACCOUNTING_DECIMALS = 6;

    /// @notice Maximum allowed price feed staleness (24 hours)
    uint256 public constant PRICE_FEED_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum withdrawal amount per transaction in USD (6 decimals)
    uint256 public immutable WITHDRAWAL_LIMIT_USD;

    /// @notice Maximum total bank capacity in USD (6 decimals)
    uint256 public immutable BANK_CAP_USD;

    /// @notice Current total value locked in the bank (in USD with 6 decimals)
    uint256 public totalValueLockedUSD;

    /// @notice Total number of deposits across all tokens
    uint256 public totalDepositCount;

    /// @notice Total number of withdrawals across all tokens
    uint256 public totalWithdrawalCount;

    /// @notice Nested mapping: user => token => TokenBalance
    mapping(address => mapping(address => TokenBalance)) private userBalances;

    /// @notice Mapping of token address to its configuration
    mapping(address => TokenConfig) public tokenConfigs;

    /// @notice Array of supported token addresses for iteration
    address[] public supportedTokens;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a user deposits tokens
    /// @param user Address of the depositor
    /// @param token Address of the token (address(0) for ETH)
    /// @param amount Amount deposited in token's native decimals
    /// @param valueUSD Value in USD (6 decimals)
    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 valueUSD
    );

    /// @notice Emitted when a user withdraws tokens
    /// @param user Address of the withdrawer
    /// @param token Address of the token (address(0) for ETH)
    /// @param amount Amount withdrawn in token's native decimals
    /// @param valueUSD Value in USD (6 decimals)
    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 valueUSD
    );

    /// @notice Emitted when a new token is added to supported list
    /// @param token Address of the token
    /// @param priceFeed Address of the Chainlink price feed
    event TokenAdded(address indexed token, address priceFeed);

    /// @notice Emitted when a token is removed from supported list
    /// @param token Address of the token
    event TokenRemoved(address indexed token);

    /// @notice Emitted when treasury withdraws funds
    /// @param token Address of the token
    /// @param amount Amount withdrawn
    /// @param recipient Address receiving the funds
    event TreasuryWithdrawal(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error KipuBankV2__AmountMustBeGreaterThanZero();
    error KipuBankV2__TokenNotSupported();
    error KipuBankV2__BankCapExceeded();
    error KipuBankV2__WithdrawalExceedsLimit();
    error KipuBankV2__InsufficientBalance();
    error KipuBankV2__TransferFailed();
    error KipuBankV2__TokenAlreadySupported();
    error KipuBankV2__InvalidPriceFeed();
    error KipuBankV2__StalePriceData();
    error KipuBankV2__InvalidPrice();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes KipuBankV2 with USD-based limits and role assignments
     * @param _withdrawalLimitUSD Maximum withdrawal per transaction in USD (6 decimals)
     * @param _bankCapUSD Maximum total value the bank can hold in USD (6 decimals)
     * @param _admin Address to be granted admin role
     * @param _treasury Address to be granted treasury role
     */
    constructor(
        uint256 _withdrawalLimitUSD,
        uint256 _bankCapUSD,
        address _admin,
        address _treasury
    ) {
        WITHDRAWAL_LIMIT_USD = _withdrawalLimitUSD;
        BANK_CAP_USD = _bankCapUSD;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(TREASURY_ROLE, _treasury);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Ensures the amount is greater than zero
    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert KipuBankV2__AmountMustBeGreaterThanZero();
        _;
    }

    /// @notice Ensures the token is supported
    modifier onlySupportedToken(address token) {
        if (!tokenConfigs[token].isSupported) revert KipuBankV2__TokenNotSupported();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new token to the supported list with its Chainlink price feed
     * @dev Only callable by admin role
     * @param token Address of the token (use address(0) for ETH)
     * @param priceFeed Address of the Chainlink price feed
     * @param decimals Token decimals
     */
    function addToken(
        address token,
        address priceFeed,
        uint8 decimals
    ) external onlyRole(ADMIN_ROLE) {
        if (tokenConfigs[token].isSupported) revert KipuBankV2__TokenAlreadySupported();
        if (priceFeed == address(0)) revert KipuBankV2__InvalidPriceFeed();

        // Validate price feed by attempting to fetch price
        _validatePriceFeed(priceFeed);

        tokenConfigs[token] = TokenConfig({
            isSupported: true,
            priceFeed: priceFeed,
            decimals: decimals
        });

        supportedTokens.push(token);

        emit TokenAdded(token, priceFeed);
    }

    /**
     * @notice Removes a token from the supported list
     * @dev Only callable by admin role
     * @param token Address of the token to remove
     */
    function removeToken(address token) external onlyRole(ADMIN_ROLE) {
        if (!tokenConfigs[token].isSupported) revert KipuBankV2__TokenNotSupported();

        tokenConfigs[token].isSupported = false;

        // Remove from supportedTokens array
        for (uint256 i = 0; i < supportedTokens.length; i++) {
            if (supportedTokens[i] == token) {
                supportedTokens[i] = supportedTokens[supportedTokens.length - 1];
                supportedTokens.pop();
                break;
            }
        }

        emit TokenRemoved(token);
    }

    /**
     * @notice Allows treasury to withdraw funds for operational purposes
     * @dev Only callable by treasury role
     * @param token Address of the token to withdraw
     * @param amount Amount to withdraw
     * @param recipient Address to receive the funds
     */
    function treasuryWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyRole(TREASURY_ROLE) nonZeroAmount(amount) {
        if (recipient == address(0)) revert KipuBankV2__TransferFailed();

        // Transfer tokens
        if (token == ETH_ADDRESS) {
            _safeTransferETH(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit TreasuryWithdrawal(token, amount, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits ETH into the user's vault
     * @dev Payable function for native ETH deposits
     */
    function depositETH()
        external
        payable
        nonZeroAmount(msg.value)
        onlySupportedToken(ETH_ADDRESS)
    {
        _deposit(ETH_ADDRESS, msg.value);
    }

    /**
     * @notice Deposits ERC20 tokens into the user's vault
     * @param token Address of the ERC20 token
     * @param amount Amount to deposit in token's native decimals
     */
    function depositToken(address token, uint256 amount)
        external
        nonZeroAmount(amount)
        onlySupportedToken(token)
    {
        // Transfer tokens from user to contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        _deposit(token, amount);
    }

    /**
     * @notice Withdraws tokens from the user's vault
     * @param token Address of the token (address(0) for ETH)
     * @param amount Amount to withdraw in token's native decimals
     */
    function withdraw(address token, uint256 amount)
        external
        nonZeroAmount(amount)
        onlySupportedToken(token)
    {
        // Checks
        TokenBalance storage userBalance = userBalances[msg.sender][token];
        if (amount > userBalance.balance) revert KipuBankV2__InsufficientBalance();

        // Get value in USD
        uint256 valueUSD = _convertToUSD(token, amount);

        // Check withdrawal limit
        if (valueUSD > WITHDRAWAL_LIMIT_USD) revert KipuBankV2__WithdrawalExceedsLimit();

        // Effects
        userBalance.balance -= amount;
        userBalance.totalWithdrawn += amount;
        totalValueLockedUSD -= valueUSD;
        totalWithdrawalCount++;

        // Interactions
        if (token == ETH_ADDRESS) {
            _safeTransferETH(msg.sender, amount);
        } else {
            IERC20(token).safeTransfer(msg.sender, amount);
        }

        emit Withdrawn(msg.sender, token, amount, valueUSD);
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the balance of a user for a specific token
     * @param user Address of the user
     * @param token Address of the token
     * @return balance Current balance
     * @return totalDeposited Total amount deposited
     * @return totalWithdrawn Total amount withdrawn
     */
    function getUserBalance(address user, address token)
        external
        view
        returns (
            uint256 balance,
            uint256 totalDeposited,
            uint256 totalWithdrawn
        )
    {
        TokenBalance memory userBalance = userBalances[user][token];
        return (
            userBalance.balance,
            userBalance.totalDeposited,
            userBalance.totalWithdrawn
        );
    }

    /**
     * @notice Returns all balances for a user across all supported tokens
     * @param user Address of the user
     * @return tokens Array of token addresses
     * @return balances Array of balances
     * @return valuesUSD Array of values in USD
     */
    function getUserBalances(address user)
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory balances,
            uint256[] memory valuesUSD
        )
    {
        tokens = supportedTokens;
        balances = new uint256[](supportedTokens.length);
        valuesUSD = new uint256[](supportedTokens.length);

        for (uint256 i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            balances[i] = userBalances[user][token].balance;
            if (balances[i] > 0) {
                valuesUSD[i] = _convertToUSD(token, balances[i]);
            }
        }

        return (tokens, balances, valuesUSD);
    }

    /**
     * @notice Returns comprehensive bank statistics
     * @return tvlUSD Total value locked in USD
     * @return deposits Total deposit count
     * @return withdrawals Total withdrawal count
     * @return withdrawalLimitUSD Withdrawal limit in USD
     * @return bankCapUSD Bank capacity in USD
     */
    function getBankStats()
        external
        view
        returns (
            uint256 tvlUSD,
            uint256 deposits,
            uint256 withdrawals,
            uint256 withdrawalLimitUSD,
            uint256 bankCapUSD
        )
    {
        return (
            totalValueLockedUSD,
            totalDepositCount,
            totalWithdrawalCount,
            WITHDRAWAL_LIMIT_USD,
            BANK_CAP_USD
        );
    }

    /**
     * @notice Returns the list of all supported tokens
     * @return Array of supported token addresses
     */
    function getSupportedTokens() external view returns (address[] memory) {
        return supportedTokens;
    }

    /**
     * @notice Gets the current price of a token in USD from Chainlink
     * @param token Address of the token
     * @return price Price in USD (8 decimals from Chainlink)
     */
    function getTokenPrice(address token) external view returns (uint256 price) {
        return _getLatestPrice(tokenConfigs[token].priceFeed);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal deposit logic shared by ETH and ERC20 deposits
     * @param token Address of the token
     * @param amount Amount to deposit
     */
    function _deposit(address token, uint256 amount) private {
        // Get value in USD
        uint256 valueUSD = _convertToUSD(token, amount);

        // Check bank cap
        if (totalValueLockedUSD + valueUSD > BANK_CAP_USD) {
            revert KipuBankV2__BankCapExceeded();
        }

        // Effects
        TokenBalance storage userBalance = userBalances[msg.sender][token];
        userBalance.balance += amount;
        userBalance.totalDeposited += amount;
        totalValueLockedUSD += valueUSD;
        totalDepositCount++;

        // Interactions (event)
        emit Deposited(msg.sender, token, amount, valueUSD);
    }

    /**
     * @notice Converts token amount to USD value with accounting decimals
     * @param token Address of the token
     * @param amount Amount in token's native decimals
     * @return valueUSD Value in USD with ACCOUNTING_DECIMALS (6 decimals)
     */
    function _convertToUSD(address token, uint256 amount)
        private
        view
        returns (uint256 valueUSD)
    {
        TokenConfig memory config = tokenConfigs[token];

        // Get price from Chainlink (8 decimals)
        uint256 price = _getLatestPrice(config.priceFeed);

        // Formula: (amount * price) / (10^tokenDecimals) / (10^priceDecimals) * (10^accountingDecimals)
        // Simplified: (amount * price * 10^accountingDecimals) / (10^tokenDecimals * 10^priceDecimals)
        
        uint256 numerator = amount * price * (10 ** ACCOUNTING_DECIMALS);
        uint256 denominator = (10 ** config.decimals) * (10 ** 8); // Chainlink uses 8 decimals

        return numerator / denominator;
    }

    /**
     * @notice Gets the latest price from a Chainlink price feed
     * @param priceFeed Address of the Chainlink price feed
     * @return price Latest price (8 decimals)
     */
    function _getLatestPrice(address priceFeed) private view returns (uint256 price) {
        AggregatorV3Interface feed = AggregatorV3Interface(priceFeed);

        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();

        // Validate price data
        if (answer <= 0) revert KipuBankV2__InvalidPrice();
        if (updatedAt == 0 || answeredInRound < roundId) revert KipuBankV2__StalePriceData();
        if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert KipuBankV2__StalePriceData();

        return uint256(answer);
    }

    /**
     * @notice Validates that a price feed is working correctly
     * @param priceFeed Address of the price feed to validate
     */
    function _validatePriceFeed(address priceFeed) private view {
        _getLatestPrice(priceFeed);
    }

    /**
     * @notice Safely transfers ETH to a recipient
     * @param to Address to receive ETH
     * @param amount Amount of ETH to transfer
     */
    function _safeTransferETH(address to, uint256 amount) private {
        (bool success, ) = payable(to).call{value: amount}("");
        if (!success) revert KipuBankV2__TransferFailed();
    }

    /**
     * @notice Allows contract to receive ETH
     */
    receive() external payable {}
}