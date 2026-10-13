# Aeroreal

Aeroreal is a real-world asset platform with Solidity contracts, a Flutter client, and a small Node.js agent API. The contracts target Monad Testnet and use Foundry for building, testing, and deployment.

## Repository Layout

- `src/` - Solidity contracts
- `test/` - Foundry tests
- `script/` - deployment and interaction scripts
- `broadcast/` - recorded deployment transactions
- `lib/` - Foundry dependencies (`forge-std` and OpenZeppelin)
- `aeroreal_app/` - Flutter application
- `agent-api/` - Node.js API service

## Prerequisites

- Foundry
- Flutter SDK (Dart SDK `^3.11.0`)
- Node.js and npm
- A Monad Testnet wallet and RPC access for deployments

## Smart Contracts

From this directory:

```shell
forge install
forge build
forge test
forge fmt --check
```

For deployment, set credentials in your shell rather than committing them:

```shell
set MONADSCAN_API_KEY=your_api_key
set PRIVATE_KEY=your_private_key
forge script script/Deploy.s.sol:DeployScript --rpc-url https://testnet-rpc.monad.xyz --private-key %PRIVATE_KEY% --broadcast
```

Use the equivalent environment variable syntax for your shell. Never commit private keys, API keys, or `.env` files.

### Arbitrary Simulated Assets

The simulated-asset factory verifies short-lived EIP-712 quotes signed by the
oracle wallet. A user's wallet submits the factory transaction, approves AREAL,
and buys the asset through the configured simulated marketplace. The user's MON
balance pays for each Monad Testnet transaction. The oracle wallet only signs
quotes and updates token prices; it does not sign user purchases.
New purchases from the RWA detail screen use factory-backed search results so
the asset price is quoted and maintained by the currently configured oracle.
After a purchase, users can sell the holding from its portfolio detail page.
Sales use the marketplace's current AREAL liquidity and fee, and also require
MON for gas.

After configuring `PRIVATE_KEY` for the oracle wallet and funding it with test
MON, deploy an isolated marketplace and factory stack from this directory:

```shell
read -s -p "Oracle wallet private key: " PRIVATE_KEY
printf '\n'
export PRIVATE_KEY
forge script script/DeployRotatedSimulatedStack.s.sol:DeployRotatedSimulatedStack --rpc-url https://testnet-rpc.monad.xyz --private-key "$PRIVATE_KEY" --broadcast
unset PRIVATE_KEY
```

Current isolated Monad Testnet deployments:

- Marketplace: `0x5D086cEA4f204Ec493ac02b4b9d6deE7Ba50C9C0`
- Factory: `0xa1475cc417fF294B1A1a1Fc7E48c74d32D672a70`
- Oracle: `0x8d67b3fd9ec2b168FC6986024e0B20Ab7564A758`

Set the returned addresses in `AppConstants.simulatedMarketplace` and
`AppConstants.simulatedAssetFactory` in `aeroreal_app/lib/config/constants.dart`,
and as `SIMULATED_MARKETPLACE_ADDRESS` and `SIMULATED_ASSET_FACTORY_ADDRESS`
in `agent-api/.env`. Keep the same oracle wallet key in the API environment,
set `MONAD_CHAIN_ID=10143` and `COINGECKO_API_KEY`, and run
`node simulated-oracle.js` from `agent-api` to refresh prices for
factory-created tokens. Do not commit the key or `.env`.

The previous marketplace and its fixed simulated tokens are legacy deployments
whose ownership/oracle was not safely transferable. This isolated stack does
not migrate their balances; legacy holdings cannot be traded through the new
marketplace and must be treated as read-only.

Until the factory is deployed and configured in both the app and API, the
simulated-asset purchase controls remain disabled.

## Flutter App

```shell
cd aeroreal_app
copy .env.example .env
flutter pub get
flutter analyze
flutter test
flutter run
```

Update `.env` with local service settings before running the app.

## Agent API

```shell
cd agent-api
copy .env.example .env
npm install
npm start
```

The API listens on port `3000` by default.

## Configuration

The Foundry explorer configuration reads `MONADSCAN_API_KEY` from the environment. RPC URLs and application settings should also be supplied through local environment files or shell variables. The committed `.env.example` files contain placeholders only.

## Deployed Contracts

The fraction marketplace is deployed on Monad Testnet:

- `FractionMarketplace`: `0x301426360A0E81c62C45cCA1E308963be6926C69`
- Payment token: `mUSD` at `0x01eA8d5FF45f5fAaC8b5BbE1e48cc734cd104512`
- Deployment transaction: `0x8c1d81572d470ce988ebf428bdda72bd302e52d368fc1b5438c2f736a6e33393`
