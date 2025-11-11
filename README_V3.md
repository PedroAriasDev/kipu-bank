# KipuBankV3 - DeFi Multi-Token Banking with Uniswap V2 Integration

## 📋 Descripción General

KipuBankV3 es una aplicación DeFi avanzada que extiende las capacidades de KipuBankV2, incorporando integración con Uniswap V2 para soportar depósitos de **cualquier token ERC20** con conversión automática a USDC.

### 🎯 Características Principales

1. **Integración Uniswap V2**: Acepta cualquier token soportado por Uniswap V2 y lo convierte automáticamente a USDC
2. **Preservación de Funcionalidad V2**: Mantiene todos los mecanismos de depósito/retiro de ETH, USDC y tokens soportados
3. **Respeto al Bank Cap**: Valida límites después de realizar swaps
4. **Seguridad Avanzada**:
   - Protección contra reentradas (ReentrancyGuard)
   - Sistema de pausa de emergencia (Pausable)
   - Recuperación de fondos para emergencias
5. **Manejo Robusto de ETH**: Funciones fallback/receive redirigen a depositETH()

## 🏗️ Arquitectura

```
KipuBankV3
├── AccessControl (Roles: ADMIN, TREASURY, EMERGENCY)
├── Pausable (Pausar operaciones en emergencias)
├── ReentrancyGuard (Protección contra ataques de reentrada)
└── Integración Uniswap V2 Router
```

### Roles

- **ADMIN_ROLE**: Gestión de tokens soportados, configuración del sistema
- **TREASURY_ROLE**: Retiro de fondos operativos
- **EMERGENCY_ROLE**: Pausar/despausar contrato, recuperar fondos en emergencias

## 🚀 Mejoras sobre KipuBankV2

### ✅ Implementadas del Feedback V2

1. **Fallback/Receive Functions**: Cualquier ETH enviado al contrato se acredita automáticamente vía `depositETH()`
2. **Sistema de Pausa**: Función `pause()`/`unpause()` para detener operaciones en emergencias
3. **Recuperación de Fondos**: Función `recoverFunds()` para rescatar fondos atrapados (solo cuando está pausado)

### 🆕 Nuevas Funcionalidades V3

1. **depositTokenWithSwap()**: Deposita cualquier token ERC20 y lo convierte a USDC automáticamente
2. **estimateSwapOutput()**: Consulta el monto estimado de USDC antes de depositar
3. **Validación de Slippage**: Parámetro `minUSDCOut` protege contra slippage excesivo
4. **Eventos Extendidos**: `DepositedWithSwap` rastrea conversiones de tokens

## 📝 Funciones Principales

### Depósitos

```solidity
// Depositar ETH directamente
function depositETH() external payable

// Depositar tokens soportados (USDC, etc.)
function depositToken(address token, uint256 amount) external

// ⭐ NUEVO: Depositar cualquier token y swapear a USDC
function depositTokenWithSwap(
    address tokenIn,
    uint256 amountIn,
    uint256 minUSDCOut,
    uint256 deadline
) external
```

### Retiros

```solidity
// Retirar tokens (respeta WITHDRAWAL_LIMIT_USD)
function withdraw(address token, uint256 amount) external
```

### Administración

```solidity
// Agregar token soportado con price feed de Chainlink
function addToken(address token, address priceFeed, uint8 decimals) external

// Pausar operaciones en emergencia
function pause() external

// Despausar operaciones
function unpause() external

// Recuperar fondos atrapados (solo cuando pausado)
function recoverFunds(address token, uint256 amount, address recipient) external
```

### Consultas

```solidity
// Estimar USDC a recibir por un swap
function estimateSwapOutput(address tokenIn, uint256 amountIn) external view returns (uint256)

// Ver balance de usuario
function getUserBalance(address user, address token) external view

// Estadísticas del banco
function getBankStats() external view
```

## 🔧 Despliegue

### Requisitos Previos

```bash
# Dependencias necesarias
npm install @openzeppelin/contracts
npm install @chainlink/contracts
```

### Parámetros de Constructor

```solidity
constructor(
    uint256 _withdrawalLimitUSD,    // Ej: 10_000 * 10**6 = $10,000 USD
    uint256 _bankCapUSD,             // Ej: 1_000_000 * 10**6 = $1,000,000 USD
    address _admin,                  // Dirección del administrador
    address _treasury,               // Dirección de tesorería
    address _usdc,                   // Dirección del token USDC
    address _uniswapRouter           // Dirección de Uniswap V2 Router
)
```

### Direcciones de Referencia (Sepolia Testnet)

```
USDC (Mock): 0x...
Uniswap V2 Router: 0x...
```

### Script de Despliegue (Foundry)

```solidity
forge create contracts/KipuBankV3.sol:KipuBankV3 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --constructor-args \
    10000000000 \              # $10,000 withdrawal limit
    1000000000000 \            # $1,000,000 bank cap
    $ADMIN_ADDRESS \
    $TREASURY_ADDRESS \
    $USDC_ADDRESS \
    $UNISWAP_ROUTER_ADDRESS \
    --verify
```

## 🔐 Seguridad

### Mecanismos Implementados

1. **ReentrancyGuard**: Todas las funciones de depósito/retiro están protegidas
2. **Pausable**: Permite detener operaciones ante vulnerabilidades detectadas
3. **SafeERC20**: Manejo seguro de transferencias ERC20
4. **Validación de Precios**: Verifica freshness de price feeds de Chainlink
5. **Slippage Protection**: `minUSDCOut` previene front-running en swaps
6. **Access Control**: Roles granulares para operaciones sensibles

### Consideraciones

- Los swaps asumen pares directos `tokenIn -> USDC` en Uniswap V2
- Para tokens sin par directo, considere implementar rutas multi-hop
- El contrato debe tener aprobaciones de Uniswap Router gestionadas correctamente

## 📊 Flujo de Operación

### Depósito con Swap

```mermaid
Usuario → transferFrom(tokenIn) → Contrato
Contrato → approve(UniswapRouter) → UniswapRouter
Contrato → swapExactTokensForTokens() → Recibe USDC
Contrato → Valida bank cap
Contrato → Acredita balance[usuario][USDC]
```

### Respeto al Bank Cap

```solidity
if (totalValueLockedUSD + valueUSD > BANK_CAP_USD) {
    revert KipuBankV3__BankCapExceeded();
}
```

## 🧪 Testing

```bash
# Ejecutar tests
forge test

# Tests con cobertura
forge coverage

# Tests específicos
forge test --match-contract KipuBankV3Test
```

## 📈 Gas Optimization

- Uso de `immutable` para variables constantes (USDC, uniswapRouter)
- `SafeERC20.safeIncreaseAllowance()` en lugar de `approve()` infinito
- Validaciones tempranas con custom errors (ahorro vs. `require`)

## 🎓 Decisiones de Diseño

### ¿Por qué convertir todo a USDC?

1. **Simplificación contable**: Un solo activo base facilita tracking de TVL
2. **Reducción de riesgo de volatilidad**: USDC es stablecoin
3. **Compatibilidad con bank cap**: Más fácil validar límites en un solo token

### ¿Por qué Uniswap V2 en lugar de V3?

- V2 es más simple de integrar (pares fijos vs. pools con rangos)
- Mayor liquidez en testnet para pruebas
- Arquitectura más estable y battle-tested

### Trade-offs

- **Pares directos requeridos**: Tokens sin par directo USDC no pueden depositarse
- **Slippage risk**: Usuario debe estimar `minUSDCOut` adecuadamente
- **Gas costs**: Swaps incrementan costo vs. depósitos directos

## 📄 Licencia

MIT

## 👨‍💻 Autor

**Pedro Arias**
GitHub: [PedroAriasDev](https://github.com/PedroAriasDev)

---

## 🔗 Enlaces Útiles

- [Documentación Uniswap V2](https://docs.uniswap.org/protocol/V2/introduction)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts)

---

**Versión**: 3.0.0
**Solidity**: 0.8.26
**Network**: Ethereum Sepolia Testnet
