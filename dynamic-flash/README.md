# DynamiFlash - Dynamic Interest Rate Flash Loan Pool

DynamiFlash provides a secure and efficient flash loan system where interest rates automatically adjust based on pool utilization. This helps maintain pool liquidity while maximizing returns for liquidity providers.

## Features

- **Dynamic Interest Rates**: Automatically adjusts based on pool utilization
- **Secure Transactions**: Built-in reentrancy protection and safety checks
- **Governance Controls**: Configurable parameters for fine-tuning pool behavior
- **Emergency Controls**: Safety mechanisms for risk management
- **Event Logging**: Comprehensive transaction tracking
- **Pool Statistics**: Real-time pool metrics and utilization data

## Technical Specifications

### Core Parameters

- Precision: 4 decimal points (10000)
- Minimum Liquidity: 1,000,000 STX
- Maximum Utilization: 90%
- Base Interest Rate: 0.1% (10 basis points)
- Rate Multiplier Range: 0.5x to 5x

### Interest Rate Model

The interest rate is calculated using the formula:
```
Interest Rate = Base Rate + (Utilization Rate × Rate Multiplier)
```

Where:
- Base Rate: Configurable from 0.05% to 1%
- Utilization Rate: (Active Loan Amount / Total Liquidity)
- Rate Multiplier: Configurable from 0.5x to 5x

## Usage

### For Liquidity Providers

```clarity
;; Deposit liquidity
(contract-call? .dynamic-flash-pool-v1 deposit u1000000)

;; Check pool status
(contract-call? .dynamic-flash-pool-v1 get-pool-details)
```

### For Borrowers

```clarity
;; Execute a flash loan
(contract-call? .dynamic-flash-pool-v1 flash-loan u500000)

;; Check required repayment for a loan amount
(contract-call? .dynamic-flash-pool-v1 get-required-repayment u500000)
```

### For Contract Owner

```clarity
;; Update base interest rate
(contract-call? .dynamic-flash-pool-v1 update-base-rate u15)

;; Update rate multiplier
(contract-call? .dynamic-flash-pool-v1 update-rate-multiplier u200)

;; Emergency shutdown
(contract-call? .dynamic-flash-pool-v1 emergency-shutdown)
```

## Error Codes

| Code | Description |
|------|-------------|
| 1000 | Not authorized |
| 1001 | Insufficient funds |
| 1002 | Loan in progress |
| 1003 | Repayment failed |
| 1004 | Below minimum liquidity |
| 1005 | Maximum utilization exceeded |
| 1006 | Invalid amount |

## Security Considerations

1. **Reentrancy Protection**: The contract uses a loan-in-progress flag to prevent reentrancy attacks
2. **Balance Checks**: Multiple validation steps ensure sufficient funds for all operations
3. **Access Control**: Owner-only functions for sensitive operations
4. **Rate Limits**: Bounded parameters prevent extreme interest rates
5. **Minimum Liquidity**: Required minimum pool balance protects against drainage

## Development and Testing

### Prerequisites
- Clarity CLI
- Stacks blockchain local development environment

### Local Development
1. Clone the repository:
```bash
git clone https://github.com/yourusername/clarity-dynamic-flash-loans.git
cd clarity-dynamic-flash-loans
```

2. Run tests:
```bash
clarinet test
```