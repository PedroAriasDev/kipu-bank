# KipuBank 🏦

A secure and feature-rich smart contract banking system built on Ethereum that allows users to manage personal vaults with deposit and withdrawal capabilities.

## 📋 Overview

KipuBank is a smart contract that implements a decentralized banking system where users can:
- Deposit native ETH into personal vaults
- Withdraw funds with per-transaction limits
- Track deposit and withdrawal statistics
- Benefit from security best practices and gas-optimized code

## ✨ Features

- **Personal Vaults**: Each user has their own isolated vault for storing ETH
- **Withdrawal Limits**: Configurable per-transaction withdrawal limit for security
- **Bank Capacity**: Maximum amount of ETH the bank can manage at any given time
- **Transaction Tracking**: Monitors total deposits and withdrawals
- **Security First**: Implements CEI pattern, custom errors, and safe transfer mechanisms
- **Gas Optimized**: Uses immutable variables and efficient storage patterns
- **Full Documentation**: Comprehensive NatSpec comments for all functions

## 🛠️ Technical Stack

- **Solidity**: ^0.8.26
- **License**: MIT
- **Development Framework**: Remix IDE

## 📦 Contract Structure

```
KipuBank/
├── State Variables
│   ├── WITHDRAWAL_LIMIT (immutable)
│   ├── BANK_CAP (immutable)
│   ├── totalBalance
│   ├── depositCount
│   ├── withdrawalCount
│   └── userVaults (mapping)
├── Events
│   ├── Deposited
│   └── Withdrawn
├── Custom Errors
│   ├── KipuBank__DepositMustBeGreaterThanZero
│   ├── KipuBank__BankCapExceeded
│   ├── KipuBank__WithdrawalMustBeGreaterThanZero
│   ├── KipuBank__WithdrawalExceedsLimit
│   ├── KipuBank__InsufficientBalance
│   └── KipuBank__TransferFailed
├── Modifiers
│   └── nonZeroAmount
└── Functions
    ├── deposit() - external payable
    ├── withdraw() - external
    ├── getVaultBalance() - external view
    ├── getMyBalance() - external view
    ├── getContractStats() - external view
    └── _safeTransferETH() - private
```

## 🚀 Deployment Instructions

### Prerequisites

1. Get testnet ETH from a faucet (Sepolia recommended: https://sepoliafaucet.com/)
2. Install MetaMask browser extension
3. Switch MetaMask to Sepolia testnet

### Deploying with Remix IDE

1. **Open Remix IDE**
   - Go to https://remix.ethereum.org/

2. **Create the contract file**
   - In the File Explorer, create a new file: `KipuBank.sol`
   - Copy and paste the contract code

3. **Compile the contract**
   - Go to the "Solidity Compiler" tab (left sidebar)
   - Select compiler version `0.8.26`
   - Click "Compile KipuBank.sol"
   - Ensure there are no errors

4. **Deploy the contract**
   - Go to the "Deploy & Run Transactions" tab
   - Set ENVIRONMENT to "Injected Provider - MetaMask"
   - MetaMask will prompt you to connect - approve it
   - Ensure you're on Sepolia testnet in MetaMask
   - In the constructor parameters, enter:
     - `_WITHDRAWALLIMIT`: `1000000000000000000` (1 ETH in wei)
     - `_BANKCAP`: `100000000000000000000` (100 ETH in wei)
   - Click "Deploy"
   - Confirm the transaction in MetaMask
   - Wait for deployment confirmation

5. **Verify the contract on Etherscan**
   - Copy your deployed contract address
   - Go to https://sepolia.etherscan.io/
   - Search for your contract address
   - Click on "Contract" tab
   - Click "Verify and Publish"
   - Select:
     - Compiler Type: Solidity (Single file)
     - Compiler Version: v0.8.26
     - License Type: MIT
   - Paste your contract code
   - In constructor arguments, enter the ABI-encoded parameters:
     ```
     0000000000000000000000000000000000000000000000000de0b6b3a7640000
     0000000000000000000000000000000000000000000000056bc75e2d63100000
     ```
   - Click "Verify and Publish"

6. **Save your contract address**
   - Copy the deployed contract address
   - Update this README with your deployed address below

## 💡 How to Interact

Once your contract is deployed and verified on Etherscan, you can interact with it directly through the Etherscan interface.

### Access the Contract on Etherscan

1. Go to https://sepolia.etherscan.io/
2. Enter your contract address in the search bar
3. Click on the "Contract" tab
4. Click on "Write Contract" or "Read Contract"

### Depositing ETH

1. Click on **"Write Contract"**
2. Click **"Connect to Web3"** and connect your MetaMask
3. Find the **`deposit`** function
4. Enter the amount of ETH you want to deposit in the **"payableAmount"** field (in ETH, e.g., `0.5`)
5. Click **"Write"**
6. Confirm the transaction in MetaMask
7. Wait for confirmation

### Withdrawing ETH

1. In **"Write Contract"** section
2. Find the **`withdraw`** function
3. Enter the amount to withdraw in wei in the **`amount`** field
   - Example: To withdraw 0.3 ETH, enter: `300000000000000000`
   - Tip: Use a converter like https://eth-converter.com/
4. Click **"Write"**
5. Confirm the transaction in MetaMask

### Checking Your Balance

1. Click on **"Read Contract"**
2. Find the **`getMyBalance`** function
3. Click **"Query"**
4. The result will show your balance in wei
   - Divide by 1000000000000000000 to get ETH
   - Example: `500000000000000000` = 0.5 ETH

### Checking Another User's Balance

1. In **"Read Contract"** section
2. Find the **`getVaultBalance`** function
3. Enter the user's address in the **`user`** field
4. Click **"Query"**
5. View the balance in wei

### Getting Contract Statistics

1. In **"Read Contract"** section
2. Find the **`getContractStats`** function
3. Click **"Query"**
4. You'll see:
   - `currentBalance`: Total ETH managed by the bank (in wei)
   - `totalDepositsCount`: Number of deposits made
   - `totalWithdrawalsCount`: Number of withdrawals made
   - `withdrawalLimit`: Maximum withdrawal per transaction (in wei)
   - `bankCapacity`: Maximum ETH the bank can manage (in wei)

### Viewing Contract Constants

1. In **"Read Contract"** section
2. Check **`WITHDRAWAL_LIMIT`**: Maximum amount per withdrawal (in wei)
3. Check **`BANK_CAP`**: Maximum capacity of the bank (in wei)
4. Check **`depositCount`**: Total number of deposits
5. Check **`withdrawalCount`**: Total number of withdrawals
6. Check **`totalBalance`**: Current total balance in the bank

### Tips for Using Etherscan Interface

- **Wei Converter**: Remember 1 ETH = 1,000,000,000,000,000,000 wei
- **Gas Fees**: Always ensure you have enough ETH for gas fees
- **Transaction History**: Click on "Events" tab to see all Deposited and Withdrawn events
- **Error Messages**: If a transaction fails, Etherscan will show the custom error (e.g., `KipuBank__WithdrawalExceedsLimit`)

## 🔒 Security Features

1. **CEI Pattern**: Follows Checks-Effects-Interactions to prevent reentrancy
2. **Custom Errors**: Gas-efficient error handling instead of require strings
3. **Safe Transfers**: Uses low-level call with success verification
4. **Input Validation**: Modifier-based validation for amounts
5. **Immutable Variables**: Gas optimization for constants
6. **Balance Tracking**: Prevents withdrawal of non-existent funds

## 📊 Gas Optimization

- Uses `immutable` for deployment-time constants
- Custom errors instead of strings (saves ~50 gas per revert)
- Efficient storage layout
- Minimal external calls

## 🌐 Testnet Deployment

**Network**: Sepolia Testnet  
**Contract Address**: 0x683744a10becaf9fb389b4186b789f8f52d02dd8  
**Explorer**: https://sepolia.etherscan.io/address/0x683744a10becaf9fb389b4186b789f8f52d02dd8#code

## 📝 License

This project is licensed under the MIT License.

## 👨‍💻 Author

Created as part of a Web3 development portfolio project.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

## 📧 Contact

For questions or suggestions, please open an issue in this repository.

---

**Note**: This is a learning project. Do not use in production without thorough auditing.
