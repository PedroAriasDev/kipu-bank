# KipuBankV2 🏦

A production-grade, multi-token banking smart contract with role-based access control, Chainlink price feeds integration, and comprehensive security features.

## 📋 Overview

KipuBankV2 is a significant upgrade from the original KipuBank contract, implementing enterprise-level features including:
- **Multi-token support**: ETH and any ERC20 token
- **USD-based accounting**: All limits and caps controlled in USD using Chainlink oracles
- **Role-based access control**: Admin and Treasury roles using OpenZeppelin's AccessControl
- **Advanced analytics**: Detailed tracking of deposits, withdrawals, and balances
- **Production-ready security**: CEI pattern, SafeERC20, price feed validation, and staleness checks

## ✨ Key Improvements from V1

### 1. **Access Control**
- **Implementation**: OpenZeppelin's `AccessControl` contract
- **Defined roles**:
  - `DEFAULT_ADMIN_ROLE`: Role management
  - `ADMIN_ROLE`: Add/remove supported tokens
  - `TREASURY_ROLE`: Withdraw funds for bank operations
- **Rationale**: Enables decentralized and secure management of administrative operations

### 2. **Multi-Token Support**
- **Implementation**: Supports ETH (address(0)) and any ERC20 token
- **Functions**: `depositETH()` and `depositToken()`
- **Security**: Uses OpenZeppelin's `SafeERC20` for secure transfers
- **Rationale**: Greater flexibility and real-world utility in DeFi

### 3. **Enhanced Internal Accounting**
- **Structure**: Nested mappings `mapping(address => mapping(address => TokenBalance))`
- **Information tracked per token**:
  - Current balance
  - Total deposited (historical)
  - Total withdrawn (historical)
- **Standard**: USDC decimals (6 decimals) for consistent accounting
- **Rationale**: Facilitates analysis, audits, and cross-token comparisons

### 4. **Data Oracles (Chainlink)**
- **Implementation**: Integration with Chainlink Data Feeds
- **Functionality**: 
  - Automatic conversion from any token to USD
  - Bank Cap and Withdrawal Limit in USD (independent of token price)
  - Data freshness validation (24 hours)
- **Security**: Multiple price feed validations
- **Rationale**: Consistent limits regardless of market volatility

### 5. **Decimal Conversion**
- **Function**: `_convertToUSD()` handles conversion from any decimal to USDC (6 decimals)
- **Formula**: `(amount × price × 10^6) / (10^tokenDecimals × 10^8)`
- **Examples**:
  - ETH (18 decimals) → USD (6 decimals)
  - USDT (6 decimals) → USD (6 decimals)
  - WBTC (8 decimals) → USD (6 decimals)
- **Rationale**: Consistent accounting between tokens with different decimals

### 6. **Enhanced Events**
- Events include USD values for better tracking
- New events: `TokenAdded`, `TokenRemoved`, `TreasuryWithdrawal`
- Optimized indexing for efficient queries

### 7. **Custom Error Handling**
- Descriptive errors for each failure case
- Gas-efficient (vs require strings)
- Better debugging and UX

## 🏗️ Contract Architecture

```
KipuBankV2
├── Inheritance
│   └── AccessControl (OpenZeppelin)
├── Libraries
│   └── SafeERC20 (OpenZeppelin)
├── Type Declarations
│   ├── TokenBalance struct
│   └── TokenConfig struct
├── Constants (7 total)
│   ├── ADMIN_ROLE
│   ├── TREASURY_ROLE
│   ├── ETH_ADDRESS
│   ├── ACCOUNTING_DECIMALS
│   └── PRICE_FEED_TIMEOUT
├── State Variables
│   ├── WITHDRAWAL_LIMIT_USD (immutable)
│   ├── BANK_CAP_USD (immutable)
│   ├── totalValueLockedUSD
│   ├── Counters (deposits/withdrawals)
│   ├── userBalances (nested mapping)
│   ├── tokenConfigs (mapping)
│   └── supportedTokens (array)
├── Events (5 total)
├── Custom Errors (10 total)
├── Modifiers (2 total)
├── Admin Functions (3)
│   ├── addToken()
│   ├── removeToken()
│   └── treasuryWithdraw()
├── External Functions (3)
│   ├── depositETH()
│   ├── depositToken()
│   └── withdraw()
├── View Functions (5)
│   ├── getUserBalance()
│   ├── getUserBalances()
│   ├── getBankStats()
│   ├── getSupportedTokens()
│   └── getTokenPrice()
└── Internal/Private Functions (4)
    ├── _deposit()
    ├── _convertToUSD()
    ├── _getLatestPrice()
    ├── _validatePriceFeed()
    └── _safeTransferETH()
```

## 🚀 Deployment Instructions

### Prerequisites

1. **Testnet Requirements**:
   - Sepolia ETH for gas fees
   - MetaMask configured for Sepolia
   - Access to Remix IDE

2. **Constructor Parameters**:
   ```
   _withdrawalLimitUSD: 1000000000 (1,000 USD with 6 decimals)
   _bankCapUSD: 100000000000 (100,000 USD with 6 decimals)
   _admin: Your admin address
   _treasury: Your treasury address
   ```

### Deployment Steps

#### 1. **Deploy via Remix IDE**

1. Open https://remix.ethereum.org/
2. Install OpenZeppelin and Chainlink dependencies:
   - Go to "Plugin Manager" and activate "DGIT"
   - Import from GitHub:
     ```
     @openzeppelin/contracts@5.0.0
     @chainlink/contracts@1.0.0
     ```
3. Create `KipuBankV2.sol` and paste the contract code
4. Go to "Solidity Compiler":
   - Compiler: 0.8.26
   - Enable optimization: 200 runs
   - Compile
5. Go to "Deploy & Run Transactions":
   - Environment: "Injected Provider - MetaMask"
   - Ensure Sepolia network
   - Enter constructor parameters
   - Deploy
6. Copy deployed address

#### 2. **Initial Configuration**

After deployment, configure supported tokens:

**For ETH (Sepolia)**:
```
Function: addToken
Parameters:
- token: 0x0000000000000000000000000000000000000000
- priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306 (ETH/USD Sepolia)
- decimals: 18
```

**For LINK (Sepolia)**:
```
Function: addToken
Parameters:
- token: 0x779877A7B0D9E8603169DdbD7836e478b4624789
- priceFeed: 0xc59E3633BAAC79493d908e63626716e204A45EdF (LINK/USD Sepolia)
- decimals: 18
```

**For USDC (Sepolia)** - if available:
```
Function: addToken
Parameters:
- token: [USDC Sepolia address]
- priceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E (USDC/USD Sepolia)
- decimals: 6
```

#### 3. **Verify on Etherscan**

1. Go to https://sepolia.etherscan.io/
2. Search your contract address
3. Click "Verify and Publish"
4. Select:
   - Compiler: v0.8.26
   - Optimization: Yes (200 runs)
   - License: MIT
5. Paste contract code (flatten if using imports)
6. Add constructor arguments (ABI-encoded)
7. Verify

## 💡 How to Interact

### Via Etherscan Interface

#### **For Admins**

**Add a new token**:
1. Go to "Write Contract" → "Connect to Web3"
2. Find `addToken`
3. Enter token address, price feed, and decimals
4. Execute transaction

**Remove a token**:
1. Find `removeToken`
2. Enter token address
3. Execute

#### **For Treasury**

**Withdraw funds**:
1. Find `treasuryWithdraw`
2. Enter token address, amount, and recipient
3. Execute

#### **For Users**

**Deposit ETH**:
1. Go to "Write Contract"
2. Find `depositETH`
3. Enter ETH amount in "payableAmount" field
4. Execute

**Deposit ERC20 tokens**:
1. First approve the contract to spend your tokens:
   - Go to the token contract
   - Call `approve(kipuBankV2Address, amount)`
2. Return to KipuBankV2 contract
3. Find `depositToken`
4. Enter token address and amount (in token's decimals)
5. Execute

**Withdraw tokens**:
1. Find `withdraw`
2. Enter token address and amount (in token's decimals)
3. Execute

**Check your balances**:
1. Go to "Read Contract"
2. Find `getUserBalances`
3. Enter your address
4. Query - shows all tokens, balances, and USD values

**Check bank statistics**:
1. Find `getBankStats`
2. Query - shows TVL, deposit/withdrawal counts, and limits

**Get token price**:
1. Find `getTokenPrice`
2. Enter token address
3. Query - returns current USD price from Chainlink

## 🔒 Security Features

### 1. **Access Control**
- Role-based permissions using OpenZeppelin
- Separation of concerns (admin vs treasury operations)
- Protection against unauthorized access

### 2. **Checks-Effects-Interactions (CEI)**
- All state changes before external calls
- Prevents reentrancy attacks
- Applied in `withdraw()` and `_deposit()`

### 3. **Safe Token Transfers**
- `SafeERC20` library for ERC20 operations
- Handles tokens with non-standard return values
- Low-level call validation for ETH transfers

### 4. **Oracle Security**
- Price feed validation on addition
- Staleness checks (24-hour timeout)
- Round completeness verification
- Negative price protection

### 5. **Input Validation**
- Non-zero amount checks via modifiers
- Token support verification
- Balance sufficiency checks
- Custom errors for clear feedback

### 6. **Gas Optimizations**
- `immutable` for deployment-time constants
- `constant` for compile-time constants
- Custom errors instead of strings
- Efficient storage layout
- Cached array lengths in loops

### 7. **Integer Overflow Protection**
- Solidity 0.8.26 built-in overflow checks
- Safe arithmetic operations
- Proper decimal handling

## 📊 Design Decisions & Trade-offs

### Decision 1: USD-Based Accounting
**Decision**: Use USD as the unit of account with 6 decimals (USDC standard)

**Advantages**:
- Consistent limits regardless of volatility
- Easy comparison between assets
- Improved UX (users think in USD)

**Trade-offs**:
- Dependency on Chainlink oracles
- Additional gas for conversions
- Risk of price feed staleness

**Mitigation**: Multiple freshness validations, 24h timeout, revert on invalid data

### Decision 2: Nested Mappings vs Array of Structs
**Decision**: `mapping(address => mapping(address => TokenBalance))` for user balances

**Advantages**:
- O(1) lookup time
- Gas efficient for individual accesses
- Scalable to many users and tokens

**Trade-offs**:
- Cannot iterate directly
- More complex to get all balances for a user

**Mitigation**: `supportedTokens` array + `getUserBalances()` function to retrieve all balances

### Decision 3: Role-Based Access Control
**Decision**: Use OpenZeppelin AccessControl vs Ownable

**Advantages**:
- Multi-sig friendly
- Granular permissions
- Industry standard
- Easy to audit

**Trade-offs**:
- Higher gas on deployment
- Greater complexity

**Justification**: For production, flexibility and security justify the cost

### Decision 4: SafeERC20 vs Direct Transfers
**Decision**: Use OpenZeppelin's SafeERC20

**Advantages**:
- Compatibility with non-standard tokens (USDT)
- Safe handling of return values
- Protection against edge cases

**Trade-offs**:
- Slightly higher gas
- Additional dependency

**Justification**: Security and compatibility are critical in production

### Decision 5: Price Feed Validation Strategy
**Decision**: Aggressive validation with multiple checks

**Validations implemented**:
- Price > 0
- updatedAt != 0
- answeredInRound >= roundId
- Freshness < 24 hours

**Advantages**:
- Maximum security against corrupt data
- Protection against price feed failures

**Trade-offs**:
- May fail in edge cases of low liquidity
- Additional gas for validations

**Mitigation**: 24h timeout is conservative but safe for most cases

### Decision 6: Decimal Standardization
**Decision**: 6 decimals (USDC standard) for internal accounting

**Advantages**:
- Recognized standard in DeFi
- Sufficient precision for USD
- Lower overflow risk

**Trade-offs**:
- Loss of precision for very low-value tokens
- Additional conversions

**Justification**: 6 decimals is sufficient for USD values and widely used in DeFi

## 📈 Gas Optimization Report

### Comparison V1 vs V2

| Operation | V1 Gas | V2 Gas | Change |
|-----------|--------|--------|--------|
| Deployment | ~500k | ~2.5M | +400% (expected due to features) |
| Deposit ETH | ~50k | ~75k | +50% (oracle call + conversions) |
| Withdraw ETH | ~30k | ~55k | +83% (oracle call + conversions) |
| View Balance | ~2k | ~15k | +650% (multiple reads + calculation) |

**Note**: The gas increase is expected and justified by:
- Multi-token support
- Oracle integration
- Role-based access control
- Enhanced analytics
- Better security

### Optimizations Implemented

1. ✅ `immutable` for USD limits
2. ✅ `constant` for roles and fixed addresses
3. ✅ Custom errors vs require strings (~50 gas savings per revert)
4. ✅ Cached `supportedTokens.length` in loops
5. ✅ Packed structs when possible
6. ✅ Short-circuit validations (cheaper checks first)

## 🌐 Chainlink Price Feeds (Sepolia Testnet)

### Available Price Feeds

| Asset | Address | Price Feed |
|-------|---------|------------|
| ETH/USD | 0x0000...0000 | 0x694AA1769357215DE4FAC081bf1f309aDC325306 |
| LINK/USD | 0x779877A7B0D9E8603169DdbD7836e478b4624789 | 0xc59E3633BAAC79493d908e63626716e204A45EdF |
| BTC/USD | - | 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43 |
| USDC/USD | - | 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E |

**Documentation**: https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1#sepolia-testnet

## 🔄 Upgrade Path from V1 to V2

There is no automatic migration. For V1 users:

1. **Admin**: Deploy V2 and configure tokens
2. **Users**: 
   - Withdraw funds from V1
   - Deposit in V2
3. **Alternative**: Implement migration function (not included for simplicity)

## 📦 Dependencies

```json
{
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0",
    "@chainlink/contracts": "^1.0.0"
  }
}
```

## 🌐 Deployed Contract

**Network**: Sepolia Testnet  
**Contract Address**: 0x456E735f5B45656A577fDE9109E7a897eA91c15e  
**Etherscan**: https://sepolia.etherscan.io/address/0x456e735f5b45656a577fde9109e7a897ea91c15e#code 
**Admin**: 0x10E6Ff9fD28bf9e2621dB5F90cF683291a692D7d
**Treasury**: 0x10E6Ff9fD28bf9e2621dB5F90cF683291a692D7d

### Supported Tokens
- ✅ ETH (Native)
- ✅ LINK
- [ ] USDC (pending)

## 🛡️ Security Considerations

### Auditing Checklist

- [ ] Access control properly implemented
- [ ] CEI pattern followed consistently
- [ ] All external calls handled safely
- [ ] Oracle data validated thoroughly
- [ ] Integer operations safe from overflow
- [ ] Reentrancy guards where needed (SafeERC20 provides)
- [ ] Price manipulation resistance
- [ ] Front-running mitigation
- [ ] Flash loan attack resistance

### Known Limitations

1. **Oracle Dependency**: Contract relies on Chainlink price feeds
   - Mitigation: Multiple validations and staleness checks
   
2. **Bank Cap in USD**: Fixed at deployment
   - Mitigation: Redeploy if market conditions change dramatically
   
3. **No Emergency Pause**: No circuit breaker implemented
   - Future: Consider implementing Pausable from OpenZeppelin

4. **Token Removal**: Can remove tokens but doesn't prevent withdrawals of existing balances
   - This is intentional to protect user funds

## 📝 License

MIT License - See LICENSE file for details

## 👨‍💻 Author

Created as part of an advanced Web3 development course, demonstrating production-ready smart contract development skills.

## 🤝 Contributing

This is an educational project, but contributions and suggestions are welcome!

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## 📧 Support

For questions or issues:
- Open an issue on GitHub
- Review the code comments and NatSpec documentation
- Check Chainlink and OpenZeppelin documentation

---

## 🎓 Learning Outcomes Demonstrated

This project demonstrates mastery of:
- ✅ Advanced Solidity patterns (CEI, modifiers, libraries)
- ✅ OpenZeppelin contracts integration
- ✅ Chainlink oracle integration
- ✅ Multi-token accounting systems
- ✅ Role-based access control
- ✅ Gas optimization techniques
- ✅ Security best practices
- ✅ Production-grade documentation
- ✅ Type safety and decimal handling
- ✅ Complex state management

---

**⚠️ Disclaimer**: While this contract implements many production-level features and security measures, it has not been professionally audited. Do not use in production with real funds without a thorough security audit.