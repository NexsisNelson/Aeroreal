# AeroReal

AeroReal is a real-world asset platform with a Flutter client, an agent API, and Solidity smart contracts for tokenized assets, vaults, fractional ownership, and yield distribution.

## Repository Layout

- `aeroreal_app/` - Flutter application for the AeroReal client.
- `agent-api/` - Node.js and Express API used by the application and agent workflows.
- `contracts/` - Foundry project containing Solidity contracts, deployment scripts, and tests.

## Prerequisites

- Flutter SDK with Dart 3.11 or later
- Node.js and npm
- Foundry (`forge`, `cast`, and `anvil`)
- Access to the required blockchain RPC endpoint and application environment variables

## Run the Flutter App

```shell
cd aeroreal_app
flutter pub get
flutter run
```

The Flutter app loads environment variables from `aeroreal_app/.env`. Keep local credentials out of source control.

## Run the Agent API

```shell
cd agent-api
npm install
npm start
```

The API reads its configuration from environment variables. Use a local `.env` file for development and do not commit secrets.

## Build and Test the Contracts

```shell
cd contracts
forge build
forge test
forge fmt --check
```

To run a local development chain:

```shell
anvil
```

Deployment scripts and network settings are available in `contracts/script/` and `contracts/foundry.toml`.

## Development Notes

- Run `flutter analyze` and `flutter test` before submitting Flutter changes.
- Run `forge test` after changing contract code.
- Never commit private keys, API tokens, wallet credentials, or production configuration.
