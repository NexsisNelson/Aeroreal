require('dotenv').config();

const { ethers } = require('ethers');

const RPC = process.env.MONAD_RPC_URL || 'https://10143.rpc.thirdweb.com';
const DEPLOYER_KEY = process.env.PRIVATE_KEY;
const COINGECKO_KEY = process.env.COINGECKO_API_KEY;
const INTERVAL_MS = 5 * 60 * 1000;

const ASSETS = {
  sBTC: {
    address: process.env.SIMULATED_BTC_ADDRESS || '0xc9918cBFdD2AeFaeA4270898C9dee2393749218a',
    coingeckoId: 'bitcoin',
  },
  sETH: {
    address: process.env.SIMULATED_ETH_ADDRESS || '0xdE522022eCE6793DB0Dab1B6690d80E87B9eb77F',
    coingeckoId: 'ethereum',
  },
  sGOLD: {
    address: process.env.SIMULATED_GOLD_ADDRESS || '0x625Cf7Ae602d2F084A2A2E85b60288588DF125C6',
    coingeckoId: 'pax-gold',
  },
  sCOFFEE: {
    address: process.env.SIMULATED_COFFEE_ADDRESS || '0x29dfbE86ab0aA6B2aF9EFd059E628Dc87998a9BB',
    manualPriceUsd: process.env.SIMULATED_COFFEE_PRICE_USD || '200',
  },
  sSOL: {
    address: process.env.SIMULATED_SOL_ADDRESS || '0x88e0b708e1350C481Fd4e8BE2Baffcb9C22E300d',
    coingeckoId: 'solana',
  },
};

const ABI = ['function updatePrice(uint256 _newPrice) external'];

async function fetchPrices(assetIds) {
  if (assetIds.length === 0) return {};

  const url = new URL('https://api.coingecko.com/api/v3/simple/price');
  url.searchParams.set('ids', assetIds.join(','));
  url.searchParams.set('vs_currencies', 'usd');
  const headers = COINGECKO_KEY ? { 'x-cg-demo-api-key': COINGECKO_KEY } : {};
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`CoinGecko returned ${response.status}`);
  return response.json();
}

async function updatePrices() {
  if (!DEPLOYER_KEY) throw new Error('PRIVATE_KEY is required');

  const configuredAssets = Object.entries(ASSETS).filter(([, asset]) => asset.address);
  if (configuredAssets.length === 0) {
    throw new Error('Set at least one SIMULATED_*_ADDRESS in agent-api/.env');
  }

  const ids = [...new Set(configuredAssets.map(([, asset]) => asset.coingeckoId).filter(Boolean))];
  const prices = await fetchPrices(ids);
  const provider = new ethers.JsonRpcProvider(RPC);
  const signer = new ethers.Wallet(DEPLOYER_KEY, provider);

  for (const [symbol, asset] of configuredAssets) {
    if (!ethers.isAddress(asset.address)) {
      console.warn(`${symbol}: invalid contract address`);
      continue;
    }

    const usdPrice = asset.manualPriceUsd ?? prices[asset.coingeckoId]?.usd;
    if (!usdPrice || !Number.isFinite(Number(usdPrice)) || Number(usdPrice) <= 0) {
      console.warn(`${symbol}: no valid price configured or returned`);
      continue;
    }

    try {
      const priceWei = ethers.parseUnits(String(usdPrice), 18);
      const contract = new ethers.Contract(asset.address, ABI, signer);
      const tx = await contract.updatePrice(priceWei);
      await tx.wait();
      console.log(`${symbol}: $${usdPrice} (tx: ${tx.hash})`);
    } catch (error) {
      console.error(`${symbol}: update failed: ${error.message}`);
    }
  }
}

async function run() {
  console.log('Simulated price oracle running...');
  if (process.argv.includes('--once')) {
    await updatePrices();
    return;
  }

  while (true) {
    try {
      await updatePrices();
    } catch (error) {
      console.error(`Oracle error: ${error.message}`);
    }
    await new Promise((resolve) => setTimeout(resolve, INTERVAL_MS));
  }
}

run();