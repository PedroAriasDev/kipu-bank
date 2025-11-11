// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title IUniswapV2Router02
 * @notice Interface for Uniswap V2 Router
 */
interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function WETH() external pure returns (address);
}

/**
 * @title KipuBankV3
 * @author Arias, Pedro. Git_Hub: https://github.com/PedroAriasDev
 * @notice Advanced DeFi banking contract with Uniswap V2 integration for multi-token support
 * @dev Extends KipuBankV2 with automatic token swapping to USDC via Uniswap V2
 *
 * Key Features:
 * - Accept any Uniswap V2 supported token and auto-swap to USDC
 * - Preserve all KipuBankV2 functionality (deposits, withdrawals, role management)
 * - Emergency pause mechanism for security
 * - Fund recovery capabilities for admin
 * - Reentrancy protection on critical functions
 */
contract KipuBankV3 is AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                            TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Structure to store user balance information for a specific token
    struct TokenBalance {
        uint256 balance;
        uint256 totalDeposited;
        uint256 totalWithdrawn;
    }

    /// @notice Structure to store token configuration
    struct TokenConfig {
        bool isSupported;
        address priceFeed;
        uint8 decimals;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    address public constant ETH_ADDRESS = address(0);
    uint8 public constant ACCOUNTING_DECIMALS = 6;
    uint256 public constant PRICE_FEED_TIMEOUT = 24 hours;

    /*//////////////////////////////////////////////////////////////
                        IMMUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public immutable WITHDRAWAL_LIMIT_USD;
    uint256 public immutable BANK_CAP_USD;

    /// @notice USDC token address (primary accounting token)
    address public immutable USDC;

    /// @notice Uniswap V2 Router address
    IUniswapV2Router02 public immutable uniswapRouter;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public totalValueLockedUSD;
    uint256 public totalDepositCount;
    uint256 public totalWithdrawalCount;

    /// @notice Nested mapping: user => token => TokenBalance
    /// @dev For V3, most balances will be stored in USDC after swapping
    mapping(address => mapping(address => TokenBalance)) private userBalances;

    /// @notice Mapping of token address to its configuration
    mapping(address => TokenConfig) public tokenConfigs;

    /// @notice Array of supported token addresses
    address[] public supportedTokens;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposited(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 valueUSD
    );

    event DepositedWithSwap(
        address indexed user,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 usdcReceived,
        uint256 valueUSD
    );

    event Withdrawn(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 valueUSD
    );

    event TokenAdded(address indexed token, address priceFeed);
    event TokenRemoved(address indexed token);

    event TreasuryWithdrawal(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    event EmergencyFundsRecovered(
        address indexed token,
        uint256 amount,
        address indexed recipient
    );

    event EmergencyPaused(address indexed admin);
    event EmergencyUnpaused(address indexed admin);

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error KipuBankV3__AmountMustBeGreaterThanZero();
    error KipuBankV3__TokenNotSupported();
    error KipuBankV3__BankCapExceeded();
    error KipuBankV3__WithdrawalExceedsLimit();
    error KipuBankV3__InsufficientBalance();
    error KipuBankV3__TransferFailed();
    error KipuBankV3__TokenAlreadySupported();
    error KipuBankV3__InvalidPriceFeed();
    error KipuBankV3__StalePriceData();
    error KipuBankV3__InvalidPrice();
    error KipuBankV3__InvalidAddress();
    error KipuBankV3__SlippageExceeded();
    error KipuBankV3__SwapFailed();
    error KipuBankV3__InvalidSwapPath();

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes KipuBankV3 with Uniswap V2 integration
     * @param _withdrawalLimitUSD Maximum withdrawal per transaction in USD (6 decimals)
     * @param _bankCapUSD Maximum total value the bank can hold in USD (6 decimals)
     * @param _admin Address to be granted admin role
     * @param _treasury Address to be granted treasury role
     * @param _usdc USDC token address
     * @param _uniswapRouter Uniswap V2 Router address
     */
    constructor(
        uint256 _withdrawalLimitUSD,
        uint256 _bankCapUSD,
        address _admin,
        address _treasury,
        address _usdc,
        address _uniswapRouter
    ) {
        if (_admin == address(0) || _treasury == address(0))
            revert KipuBankV3__InvalidAddress();
        if (_usdc == address(0) || _uniswapRouter == address(0))
            revert KipuBankV3__InvalidAddress();

        WITHDRAWAL_LIMIT_USD = _withdrawalLimitUSD;
        BANK_CAP_USD = _bankCapUSD;
        USDC = _usdc;
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(TREASURY_ROLE, _treasury);
        _grantRole(EMERGENCY_ROLE, _admin);
    }

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert KipuBankV3__AmountMustBeGreaterThanZero();
        _;
    }

    modifier onlySupportedToken(address token) {
        if (!tokenConfigs[token].isSupported) revert KipuBankV3__TokenNotSupported();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Adds a new token to the supported list
     * @param token Address of the token (use address(0) for ETH)
     * @param priceFeed Address of the Chainlink price feed
     * @param decimals Token decimals
     */
    function addToken(
        address token,
        address priceFeed,
        uint8 decimals
    ) external onlyRole(ADMIN_ROLE) {
        if (tokenConfigs[token].isSupported) revert KipuBankV3__TokenAlreadySupported();
        if (priceFeed == address(0)) revert KipuBankV3__InvalidPriceFeed();

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
     * @param token Address of the token to remove
     */
    function removeToken(address token) external onlyRole(ADMIN_ROLE) {
        if (!tokenConfigs[token].isSupported) revert KipuBankV3__TokenNotSupported();

        tokenConfigs[token].isSupported = false;

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
     * @notice Pauses all deposit and withdrawal operations
     * @dev Only callable by EMERGENCY_ROLE
     */
    function pause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
        emit EmergencyPaused(msg.sender);
    }

    /**
     * @notice Unpauses all operations
     * @dev Only callable by EMERGENCY_ROLE
     */
    function unpause() external onlyRole(EMERGENCY_ROLE) {
        _unpause();
        emit EmergencyUnpaused(msg.sender);
    }

    /**
     * @notice Emergency function to recover stuck funds
     * @dev Only callable by EMERGENCY_ROLE when paused
     * @param token Address of the token to recover
     * @param amount Amount to recover
     * @param recipient Address to receive the recovered funds
     */
    function recoverFunds(
        address token,
        uint256 amount,
        address recipient
    ) external onlyRole(EMERGENCY_ROLE) whenPaused nonZeroAmount(amount) {
        if (recipient == address(0)) revert KipuBankV3__InvalidAddress();

        if (token == ETH_ADDRESS) {
            _safeTransferETH(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit EmergencyFundsRecovered(token, amount, recipient);
    }

    /**
     * @notice Allows treasury to withdraw funds for operational purposes
     * @param token Address of the token to withdraw
     * @param amount Amount to withdraw
     * @param recipient Address to receive the funds
     */
    function treasuryWithdraw(
        address token,
        uint256 amount,
        address recipient
    ) external onlyRole(TREASURY_ROLE) nonZeroAmount(amount) {
        if (recipient == address(0)) revert KipuBankV3__InvalidAddress();

        if (token == ETH_ADDRESS) {
            _safeTransferETH(recipient, amount);
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }

        emit TreasuryWithdrawal(token, amount, recipient);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Deposits ETH into the user's vault
     * @dev Payable function for native ETH deposits
     */
    function depositETH()
        public
        payable
        nonZeroAmount(msg.value)
        onlySupportedToken(ETH_ADDRESS)
        whenNotPaused
        nonReentrant
    {
        _deposit(ETH_ADDRESS, msg.value);
    }

    /**
     * @notice Deposits ERC20 tokens directly (for USDC or other supported tokens)
     * @param token Address of the ERC20 token
     * @param amount Amount to deposit in token's native decimals
     */
    function depositToken(address token, uint256 amount)
        external
        nonZeroAmount(amount)
        onlySupportedToken(token)
        whenNotPaused
        nonReentrant
    {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _deposit(token, amount);
    }

    /**
     * @notice Deposits any ERC20 token and swaps it to USDC via Uniswap V2
     * @dev This is the core V3 feature - accepts any token and converts to USDC
     * @param tokenIn Address of the token to deposit
     * @param amountIn Amount of tokenIn to deposit
     * @param minUSDCOut Minimum USDC to receive (slippage protection)
     * @param deadline Transaction deadline timestamp
     */
    function depositTokenWithSwap(
        address tokenIn,
        uint256 amountIn,
        uint256 minUSDCOut,
        uint256 deadline
    ) external nonZeroAmount(amountIn) whenNotPaused nonReentrant {
        if (tokenIn == address(0)) revert KipuBankV3__InvalidAddress();
        if (tokenIn == USDC) revert KipuBankV3__InvalidSwapPath();

        // Transfer tokens from user
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve Uniswap router
        IERC20(tokenIn).safeIncreaseAllowance(address(uniswapRouter), amountIn);

        // Setup swap path: tokenIn -> USDC (direct pair assumed)
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = USDC;

        // Execute swap
        uint256[] memory amounts;
        try uniswapRouter.swapExactTokensForTokens(
            amountIn,
            minUSDCOut,
            path,
            address(this),
            deadline
        ) returns (uint256[] memory _amounts) {
            amounts = _amounts;
        } catch {
            revert KipuBankV3__SwapFailed();
        }

        uint256 usdcReceived = amounts[amounts.length - 1];

        if (usdcReceived < minUSDCOut) revert KipuBankV3__SlippageExceeded();

        // Get value in USD (for USDC, 1 USDC = 1 USD)
        uint256 valueUSD = usdcReceived; // USDC has 6 decimals, same as ACCOUNTING_DECIMALS

        // Check bank cap
        if (totalValueLockedUSD + valueUSD > BANK_CAP_USD) {
            revert KipuBankV3__BankCapExceeded();
        }

        // Update user balance in USDC
        TokenBalance storage userBalance = userBalances[msg.sender][USDC];
        userBalance.balance += usdcReceived;
        userBalance.totalDeposited += usdcReceived;
        totalValueLockedUSD += valueUSD;
        totalDepositCount++;

        emit DepositedWithSwap(msg.sender, tokenIn, amountIn, usdcReceived, valueUSD);
    }

    /*//////////////////////////////////////////////////////////////
                        WITHDRAWAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Withdraws tokens from the user's vault
     * @param token Address of the token (address(0) for ETH)
     * @param amount Amount to withdraw in token's native decimals
     */
    function withdraw(address token, uint256 amount)
        external
        nonZeroAmount(amount)
        onlySupportedToken(token)
        whenNotPaused
        nonReentrant
    {
        TokenBalance storage userBalance = userBalances[msg.sender][token];
        if (amount > userBalance.balance) revert KipuBankV3__InsufficientBalance();

        uint256 valueUSD = _convertToUSD(token, amount);

        if (valueUSD > WITHDRAWAL_LIMIT_USD) revert KipuBankV3__WithdrawalExceedsLimit();

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

    /**
     * @notice Estimates USDC output for a given token input via Uniswap
     * @param tokenIn Address of input token
     * @param amountIn Amount of input token
     * @return estimatedUSDC Estimated USDC output
     */
    function estimateSwapOutput(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 estimatedUSDC)
    {
        if (tokenIn == USDC) return amountIn;

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = USDC;

        uint256[] memory amounts = uniswapRouter.getAmountsOut(amountIn, path);
        return amounts[amounts.length - 1];
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal deposit logic for direct deposits (no swap)
     * @param token Address of the token
     * @param amount Amount to deposit
     */
    function _deposit(address token, uint256 amount) private {
        uint256 valueUSD = _convertToUSD(token, amount);

        if (totalValueLockedUSD + valueUSD > BANK_CAP_USD) {
            revert KipuBankV3__BankCapExceeded();
        }

        TokenBalance storage userBalance = userBalances[msg.sender][token];
        userBalance.balance += amount;
        userBalance.totalDeposited += amount;
        totalValueLockedUSD += valueUSD;
        totalDepositCount++;

        emit Deposited(msg.sender, token, amount, valueUSD);
    }

    /**
     * @notice Converts token amount to USD value
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

        uint256 price = _getLatestPrice(config.priceFeed);

        uint256 numerator = amount * price * (10 ** ACCOUNTING_DECIMALS);
        uint256 denominator = (10 ** config.decimals) * (10 ** 8);

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

        if (answer <= 0) revert KipuBankV3__InvalidPrice();
        if (updatedAt == 0 || answeredInRound < roundId) revert KipuBankV3__StalePriceData();
        if (block.timestamp - updatedAt > PRICE_FEED_TIMEOUT) revert KipuBankV3__StalePriceData();

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
        if (!success) revert KipuBankV3__TransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                        FALLBACK FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fallback function redirects ETH to depositETH()
     * @dev Implements feedback suggestion for robust ETH handling
     */
    fallback() external payable {
        depositETH();
    }

    /**
     * @notice Receive function redirects ETH to depositETH()
     * @dev Implements feedback suggestion for robust ETH handling
     */
    receive() external payable {
        depositETH();
    }
}
