# KiloScribe Smart Contracts

A simple set of Smart Contracts enabling NFT minting capabilities on Hedera. The system uses a factory pattern to deploy individual minting contracts, each with its own configuration for pricing, allowlists, and fee distribution.

These contracts were developed as part of [Hello Future Hackathon](https://hellofuturehackathon.dev "Hello Future Hackathon") and utilized in the [KiloScribe](https://kiloscribe.com "KiloScribe") LaunchPage tool.

## ⚠️ Disclaimer

**USE AT YOUR OWN RISK**: This smart contract system was developed as part of a hackathon and has not undergone a formal security audit. While the risk remains quite low, we recommend caution in using these contracts in production environments.

## Key Features

- **Factory Pattern**: Deploy new minting contracts with custom configurations
- **Multi-tier Allowlist System**: Support for different allowlist tiers with varying mint limits
  - Basic Allowlist
  - Secondary Allowlist
  - Discounted List
  - Public List
- **Dynamic Pricing**: Configurable pricing for different minting phases
- **Royalty Management**: Support for multiple royalty recipients with customizable fee structures
- **Owner Controls**: Comprehensive admin functions for managing allowlists, pricing, and minting phases

## Smart Contract Architecture

### KiloScribeMinterFactory

The main factory contract that deploys new minting contract instances. It handles the creation and initial configuration of minting contracts.

### KiloScribeMinter

The core minting contract with the following components:

- **AllowList**: Manages different tiers of allowlists and their mint limits
- **MintMechanics**: Handles pricing and minting phase controls
- **LaunchpadLib**: Utility functions for the minting process
- **HederaTokenService**: Interface with Hedera token services
- **PrngSystemContract**: Provides randomization capabilities

## Deployed Contract Addresses

### Mainnet

Factory Contract: 0.0.7770565
EVM Address: 0x00000000000000000000000000000000007691c5

### Testnet

Factory Contract: 0.0.5276339
EVM Address: 0x00000000000000000000000000000000005082b3

## Usage

The contracts support the following operations:

1. **Deploy New Minting Contract**

   ```javascript
   // Using the factory to create a new minting contract
   const newContract = await factory.createContract(
     tokenAddress,
     discountedMintPrice,
     allowListMintPrice,
     mintPrice,
     tokensRemaining,
     launchpadFees,
     feeAddresses,
     baseTokenURI,
     isHashinal
   );
   ```

2. **Configure Allowlists**

   ```javascript
   // Add users to allowlist
   await contract.addUsers(users, BASIC_ALLOW_LIST);
   ```

3. **Set Pricing**
   ```javascript
   // Update mint prices
   await contract.setMintPrice(newPrice);
   await contract.setAllowListMintPrice(newPrice);
   await contract.setDiscountedMintPrice(newPrice);
   ```

## Security Features

- Owner-only access controls for administrative functions
- Safe math operations for all calculations
- Hedera native token service integration
- Multi-tier access control system

## Dependencies

- Hedera SDK
- OpenZeppelin Contracts
- Hardhat Development Environment

## Development

1. Install dependencies:

   ```bash
   npm install
   ```

2. Set up environment variables:

   ```bash
   cp .env.example .env
   ```

   Configure the following variables in your `.env` file:

   - `HEDERAS_OPERATOR_KEY`: Your Hedera operator's private key
   - `HEDERAS_OPERATOR_ID`: Your Hedera operator's account ID
   - `TESTNET_LP_ADDRESS_1`: Launchpad address 1 for testnet
   - `TESTNET_LP_ADDRESS_2`: Launchpad address 2 for testnet
   - `FEE_ADDRESS`: Fee collection address
   - `FEE_ADDRESS_2`: Secondary fee collection address

3. Compile contracts:

   ```bash
   npm run compile
   ```

4. Deploy factory:
   ```bash
   npm start
   ```

## Error Decoder

The project includes a TypeScript-based error decoder to help debug contract errors. To use it:

1. Install TypeScript dependencies:

   ```bash
   npm install --save-dev typescript @types/node ts-node @types/winston
   ```

2. When you encounter a contract error, note the contract ID and network (testnet/mainnet)

3. Run the error decoder:
   ```bash
   npm run decode -- <network> <contract-id>
   ```
   Example:
   ```bash
   npm run decode -- testnet 0.0.1234567
   ```

The decoder will:

- Fetch the error from the Hedera Mirror Node
- Decode the error using the contract ABI
- Display detailed information about the error, including:
  - Error name and type
  - Parameter values
  - Hedera address translations for address parameters
  - Nested error information if present

Error handling has been improved to:

- Provide clear error messages for common issues
- Handle network connectivity problems gracefully
- Support nested error decoding
- Include proper TypeScript types for maintainability

## License

This project is licensed under the Apache-2.0 License.
