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
