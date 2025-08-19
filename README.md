# Pop-up Retail and Temporary Venues System

A comprehensive blockchain-based platform for managing short-term retail spaces, built on the Stacks blockchain using Clarity smart contracts.

## Overview

This system enables efficient management of temporary retail venues through smart contracts that handle lease agreements, revenue sharing, inventory tracking, and vendor coordination. The platform provides transparency and automation for all stakeholders in the pop-up retail ecosystem.

## Core Features

### 🏢 Venue Management
- Register and manage temporary retail spaces
- Track space availability and utilization metrics
- Monitor foot traffic and performance analytics
- Automated space allocation and scheduling

### 📋 Lease Agreements
- Smart contract-based lease terms
- Automated payment processing
- Flexible duration and pricing models
- Dispute resolution mechanisms

### 💰 Revenue Sharing
- Transparent revenue distribution
- Real-time payment processing
- Configurable sharing percentages
- Automated settlement system

### 📦 Inventory Management
- Real-time inventory tracking
- Multi-vendor coordination
- Stock level monitoring
- Automated reorder notifications

### 🤝 Vendor Coordination
- Vendor registration and verification
- Performance tracking and ratings
- Community engagement tools
- Local partnership facilitation

## Smart Contracts

### 1. Venue Manager (`venue-manager.clar`)
Core contract for managing retail spaces and their properties.

**Key Functions:**
- `register-venue`: Register a new temporary retail space
- `update-venue-status`: Modify venue availability and status
- `get-venue-info`: Retrieve venue details and metrics
- `track-foot-traffic`: Record visitor analytics

### 2. Lease Agreement (`lease-agreement.clar`)
Handles all lease-related operations and terms.

**Key Functions:**
- `create-lease`: Establish new lease agreement
- `execute-payment`: Process lease payments
- `terminate-lease`: End lease agreement
- `get-lease-details`: Retrieve lease information

### 3. Revenue Sharing (`revenue-sharing.clar`)
Manages transparent revenue distribution between parties.

**Key Functions:**
- `set-revenue-split`: Configure revenue sharing percentages
- `distribute-revenue`: Automatically distribute earnings
- `claim-revenue`: Allow parties to claim their share
- `get-revenue-history`: View payment history

### 4. Inventory Tracker (`inventory-tracker.clar`)
Tracks inventory across multiple vendors and locations.

**Key Functions:**
- `add-inventory-item`: Register new inventory
- `update-stock-level`: Modify inventory quantities
- `transfer-inventory`: Move items between locations
- `get-inventory-status`: Check current stock levels

### 5. Vendor Coordinator (`vendor-coordinator.clar`)
Manages vendor relationships and community engagement.

**Key Functions:**
- `register-vendor`: Add new vendor to platform
- `update-vendor-rating`: Modify vendor performance scores
- `coordinate-event`: Organize community events
- `get-vendor-profile`: Retrieve vendor information

## Technical Architecture

### Blockchain Integration
- **Platform**: Stacks Blockchain
- **Language**: Clarity Smart Contracts
- **Consensus**: Proof of Transfer (PoX)
- **Security**: Bitcoin-level security inheritance

### Data Storage
- On-chain: Critical business logic and state
- Off-chain: Analytics and performance metrics
- Hybrid: User preferences and configurations

### Access Control
- Role-based permissions system
- Multi-signature requirements for critical operations
- Time-locked functions for security
- Emergency pause mechanisms

## Getting Started

### Prerequisites
- Node.js 18+
- Clarinet CLI
- Stacks Wallet
- Git

### Installation

1. Clone the repository:
   \`\`\`bash
   git clone <repository-url>
   cd popup-retail-system
   \`\`\`

2. Install dependencies:
   \`\`\`bash
   npm install
   \`\`\`

3. Initialize Clarinet:
   \`\`\`bash
   clarinet integrate
   \`\`\`

4. Run tests:
   \`\`\`bash
   npm test
   \`\`\`

5. Deploy contracts:
   \`\`\`bash
   clarinet deploy --testnet
   \`\`\`

### Configuration

Update `Clarinet.toml` with your specific network settings and contract deployment parameters.

## Testing

The system includes comprehensive test coverage using Vitest:

\`\`\`bash
# Run all tests
npm test

# Run specific test file
npm test venue-manager.test.js

# Run tests in watch mode
npm run test:watch
\`\`\`

## Usage Examples

### Registering a Venue
```clarity
(contract-call? .venue-manager register-venue 
  "Downtown Pop-up Space" 
  u1000 
  u50 
  "123 Main St")
