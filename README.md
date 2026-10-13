# AeroReal Flutter App

AeroReal is a Flutter client for exploring tokenized real-world assets (RWAs)
and NFTs, managing a wallet, and interacting with smart-contract features on
Monad Testnet. The app also includes sample and simulated asset flows for
demonstration.

This README covers the mobile/web client workflow, its local API dependency,
configuration, and development commands. The parent repository README
([`../README.md`](../README.md)) describes the wider project, including the
agent API and Solidity contracts.

> **Important:** This project is a testnet/demo application, not a production
> wallet or investment service. Market data, KYC, simulated assets, and some
> profile features are demonstrative. Do not use real funds, sensitive identity
> documents, production credentials, or a mainnet wallet with this app.

## App workflow

### 1. Start the app and connect

At startup, the app loads its `.env` asset and initializes local notifications.
On native platforms it initializes Privy, restores the user's Privy session if
available, and ensures that an authenticated user has an embedded Ethereum
wallet. It also restores the app's locally managed wallet state and loads the
user profile for an authenticated address.

- An authenticated Privy user is routed to the main app.
- A new or signed-out user starts at onboarding.
- Onboarding supports email or SMS verification with a six-digit code. Once
  verified, the app displays the connected wallet and its MON balance.
- Privy initialization is skipped on web. The web build can be used to inspect
  UI, but Privy authentication and wallet transaction workflows require a
  supported native target.

### 2. Use the four main tabs

The persistent bottom navigation is implemented by `MainShell`:

| Tab | What you can do |
| --- | --- |
| **Home** | Review the wallet/portfolio summary, MON and token balances, holdings, and recent activity. Refresh data and open common actions such as funding, sending, receiving, portfolio, NFT creation, yield, watchlist, and settings. |
| **Explore** | Search and filter assets, browse featured assets and categories (including commodities, invoices, treasuries, real estate, private credit, collectibles, and equities), and open asset details. |
| **Create** | Choose a creation flow: create an NFT, fractionalize an NFT, or tokenize an RWA. These flows may require the local API and/or a connected wallet. |
| **Market** | Browse NFT marketplace listings, open listing details, and use the available listing or purchase actions. Fractional listings and their market are also reachable from the related asset flows. |

### 3. Explore and manage assets

Selecting an RWA opens its detail view, where the app presents available
pricing/market information, charts, asset metadata, disclosures, and applicable
wallet actions. Search results, news, NFT collection data, and portfolio data
can come from the local API or external data providers.

The Home screen and Portfolio screens combine wallet balances and on-chain
contract reads with profile information and cached data. Watchlist, preferences,
notifications, transaction history, traction, and settings are reached through
Home or the Settings screen.

### 4. Create, trade, and view transactions

- **NFT creation:** choose an image, provide NFT details, upload through the
  local API, and submit the available mint flow.
- **NFT fractionalization:** select an eligible NFT and follow the transaction
  prompts to create fractions.
- **RWA tokenization:** select the asset type and complete the tokenization
  form. RWA actions are subject to the app's demo KYC state.
- **Funding and transfers:** use Fund, Send, and Receive to view funding
  instructions, share an address, or send supported tokens/NFTs.
- **Yield:** view positions, revenue, and claim actions where the deployed
  contracts support them.
- **Transaction feedback:** contract actions prompt for confirmation, submit
  through the connected Privy wallet, wait for a receipt, and may add a local
  notification/history entry.

Transactions require MON for network gas. The app's write-contract configuration
is for Monad Testnet (chain ID `10143`); the separate Monad Mainnet RPC constant
is used for read-only price-feed data. Always verify the wallet, chain, and
transaction details before approving.

### 5. Verify identity (demo flow)

The Settings screen links to the identity-verification screens. The app guides
the user through choosing a document type and capturing a document image, but
the current `KycService` only records a local demo verification flag in device
preferences. It is **not** a regulated identity check and does not itself
update an on-chain compliance whitelist. Do not submit real identity documents.

## Project layout

```text
lib/
  main.dart                 App initialization, providers, theme, and routes
  config/                   Routes, contract addresses/ABIs, categories, demo data
  models/                   App data models
  screens/                  Onboarding, tabs, detail, wallet, settings, and KYC UI
  services/                 Wallet, Privy, contracts, API, profile, and data services
  utils/                    Formatting, errors, icons, and transaction feedback
  widgets/                  Shared cards, navigation, charts, and disclosures
assets/                     App images and other bundled resources
test/                       Unit and widget tests
```

`main.dart` injects `PrivyService`, `WalletService`, `UserProfileService`, and
`ContractService` through Provider. `MainShell` keeps the four primary screens
in an `IndexedStack`; detail and utility screens are pushed on top as routes.

### Data and persistence

- **On-chain reads/writes:** `ContractService` and `WalletService` use
  `web3dart` with Monad RPC endpoints and contract definitions in `lib/config/`.
- **Authentication and embedded wallet:** `PrivyService` handles native Privy
  authentication and transaction signing.
- **API-backed features:** `RwaService`, `UserProfileService`, and other API
  services communicate with the sibling Node/Express app.
- **Local preferences:** `shared_preferences` stores selected demo/profile
  state, notification data, KYC demo state, and a locally managed private key.
  A private key in app preferences is not equivalent to secure hardware-backed
  wallet storage; treat this implementation as demonstration code only.
- **External data:** some screens query third-party market/data services
  directly or through the local API. Results depend on those services being
  available and their access policies.

## Requirements

- Flutter SDK and Dart SDK compatible with the constraint in `pubspec.yaml`
  (Dart `^3.11.4`)
- Android Studio/Android SDK for Android builds, or Xcode on macOS for iOS
- Node.js and npm to run the local API for API-backed screens
- A configured Privy app for native email/SMS authentication
- Monad Testnet MON for test transactions

Check the installed Flutter setup with:

```shell
flutter doctor
flutter devices
```

## Configure the Flutter app

The app loads `.env` from the project root as a Flutter asset at startup. Create
`aeroreal_app/.env` before running or building. At a minimum, set the Privy
client identifiers if you want native authentication:

```dotenv
PRIVY_APP_ID=your_privy_app_id
PRIVY_CLIENT_ID=your_privy_client_id
USER_NFT_COLLECTION=0x0000000000000000000000000000000000000000
```

Use the real collection address for your deployment if applicable. Without
`PRIVY_APP_ID` or `PRIVY_CLIENT_ID`, Privy does not initialize and the native
sign-in/transaction flow will not be available. The app currently defines most
Monad contract addresses and RPC URLs in `lib/config/constants.dart`; variables
declared by `lib/config/env.dart` should not be assumed to override every
deployed address.

**Never put private keys, API secrets, or other server credentials in the
Flutter `.env`.** The file is bundled into the client application and is not a
secret store. The app's `.gitignore` excludes the local `.env` file; verify
your repository's ignore rules before committing or sharing a working copy.

## Run the app

From `aeroreal_app/`:

```shell
flutter pub get
flutter run
```

To choose a target explicitly:

```shell
flutter devices
flutter run -d <device-id>
```

Flutter Web can be launched for UI inspection with `flutter run -d chrome`, but
Privy authentication is intentionally skipped on web.

## Run the local API

Several screens expect the sibling API at port `3001`. From the parent project
directory, run:

```shell
cd agent-api
npm ci
```

Create `agent-api/.env` from `agent-api/.env.example`, then populate only the
credentials needed by the features you are using. Keep this server-side file
private; do not copy its secrets into the Flutter `.env`.

```shell
npm start
```

The API-backed client services default to `http://10.0.2.2:3001` on the Android
emulator (the host machine) and `http://localhost:3001` on other targets. A
physical phone or tablet cannot normally reach the development computer through
those addresses; configure the service base URLs to use a reachable development
host and ensure the API is bound and firewalled appropriately. API-dependent
features may show errors or have reduced functionality while the service is
stopped.

## Test, analyze, and build

Run the Flutter static analyzer and tests from `aeroreal_app/`:

```shell
flutter analyze
flutter test
```

Run a focused test file when changing one workflow:

```shell
flutter test test/kyc_flow_test.dart
```

Example release builds:

```shell
flutter build apk
flutter build appbundle
flutter build web
```

iOS builds require macOS with Xcode configured. Ensure the correct API,
environment, signing identity, and target chain configuration are set before
producing a distributable build.

## Operational and security notes

- The configured on-chain write network is Monad Testnet. The app is not a
  production mainnet wallet.
- Never commit a wallet private key, Privy secret, API token, signing key, or
  production configuration. Privy app/client IDs are client configuration, not
  a place to store server-side secrets.
- The app's locally managed wallet private key is serialized to platform
  preferences by `WalletService`; do not use that storage design for valuable
  funds without replacing it with an audited secure-storage/key-management
  solution.
- KYC is local demo state, simulated assets are not equivalent to real
  underlying assets, and displayed prices/yield are not investment guarantees.
- Validate contract addresses, chain ID, API origin, and third-party service
  configuration before testing a transaction.

## Further reading

- [Parent project README](../README.md) — repository layout, API, and contracts
- [Flutter documentation](https://docs.flutter.dev/)
- [Monad Testnet explorer](https://testnet.monadscan.com/)
