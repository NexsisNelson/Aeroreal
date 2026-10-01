require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { ethers } = require('ethers');
const NodeCache = require('node-cache');
const { XMLParser } = require('fast-xml-parser');
const { CctpBridge } = require('./cctp-bridge');
const {
  getProfile,
  updateProfile,
  addSearchQuery,
  deleteProfile,
} = require('./user-profile');

const app = express();
app.use(cors());
app.use(express.json());

const PINATA_JWT = process.env.PINATA_JWT;

// Network and market-data settings are environment-driven so local, testnet,
// and production deployments can use the same server code.
const PORT = Number(process.env.PORT || 3001);
const RPC_URL = process.env.MONAD_RPC_URL || 'https://10143.rpc.thirdweb.com';
const CMC_API_KEY = process.env.CMC_API_KEY;
const CMC_BASE = 'https://pro-api.coinmarketcap.com';
const COINGECKO_API_KEY = process.env.COINGECKO_API_KEY;
const COINGECKO_BASE = 'https://api.coingecko.com/api/v3';
const ZERION_API_KEY = process.env.ZERION_API_KEY;
const ZERION_BASE = 'https://api.zerion.io/v1';
const BLOCKVISION_API_KEY = process.env.BLOCKVISION_API_KEY;
const BLOCKVISION_BASE = 'https://api.blockvision.org/v2';
const MAGIC_EDEN_API_KEY = process.env.MAGIC_EDEN_API_KEY;
const RWA_CATEGORY_IDS = new Set([
  'tokenized-treasuries',
  'tokenized-commodities',
  'real-estate',
  'tokenized-private-credit',
  'collectibles',
  'tokenized-stock',
  'real-world-assets-rwa',
]);
const cmcCache = new NodeCache({ stdTTL: 60 });
const newsCache = new NodeCache({ stdTTL: 600 });
const reputationCache = new NodeCache({ stdTTL: 600 });
const zerionCache = new NodeCache({ stdTTL: 30 });
const blockvisionCache = new NodeCache({ stdTTL: 30 });
const provider = new ethers.JsonRpcProvider(RPC_URL);

// These addresses are read-only data sources for the agent endpoints. Private
// keys are intentionally not needed because the API never submits a tx.
const CONTRACTS = {
  goldVault: '0xe524bd915098eec8f0fb73e9f4d7321597c90d72',
  coffeeVault: '0x05d826fba0271cd5fe6d10a0aebe79da6c49ac9e',
  treasuryVault: '0x934f83a89c4471b5d375f4ac52ee45c9f5e94df0',
  revenueOracle: '0x867Ca7417E20c191AAf149219B8af86f3Bb6d689',
  mockStablecoin: '0x01eA8d5FF45f5fAaC8b5BbE1e48cc734cd104512',
  treasuryFractionToken: '0x44e1D5A9d1Aa66D056847749b889cd4fBC1da440',
  fractionMarketplace: '0x301426360A0E81c62C45cCA1E308963be6926C69',
};

const VAULT_ABI = [
  'function getCommodityInfo() view returns (string, uint256, string, string, string, string, string)',
  'function getInvoiceInfo() view returns (address, address, uint256, uint256, uint256, uint256, bool, uint256, address, string, string)',
  'function fractionToken() view returns (address)',
];

const ERC20_ABI = [
  'function totalSupply() view returns (uint256)',
  'function balanceOf(address owner) view returns (uint256)',
];

async function readFractionSupply(vault) {
  // Vaults create their fraction token during deployment, so the API resolves
  // that address before reading the current total supply.
  const fractionTokenAddress = await vault.fractionToken();
  const fractionToken = new ethers.Contract(
    fractionTokenAddress,
    ERC20_ABI,
    provider,
  );
  return {
    fraction_token: fractionTokenAddress,
    total_fractions: (await fractionToken.totalSupply()).toString(),
  };
}

async function readCommodityVault(address, riskLevel, yieldApy) {
  const vault = new ethers.Contract(address, VAULT_ABI, provider);
  const info = await vault.getCommodityInfo();
  const supply = await readFractionSupply(vault);

  return {
    asset_type: 'Commodity',
    asset_name: info[0],
    quantity: info[1].toString(),
    unit: info[2],
    storage_location: info[3],
    audit_report: info[4],
    insurance_report: info[5],
    custodian: info[6],
    ...supply,
    trading_enabled: false,
    jurisdiction: 'Global',
    risk_level: riskLevel,
    yield_apy: yieldApy,
  };
}

async function readGoldVault() {
  return readCommodityVault(CONTRACTS.goldVault, 'A', '4.2%');
}

async function readCoffeeVault() {
  return readCommodityVault(CONTRACTS.coffeeVault, 'B', '3.8%');
}

async function readTreasuryVault() {
  const vault = new ethers.Contract(CONTRACTS.treasuryVault, VAULT_ABI, provider);
  const info = await vault.getInvoiceInfo();
  const supply = await readFractionSupply(vault);

  return {
    asset_type: 'Invoice',
    asset_name: 'US Treasury Bill - 90 Day',
    face_value: info[2].toString(),
    discount_bps: info[3].toString(),
    maturity_date: info[5].toString(),
    is_settled: info[6],
    settlement_token: info[8],
    jurisdiction: info[10],
    ...supply,
    trading_enabled: false,
    risk_level: 'AAA',
    yield_apy: '4.8%',
  };
}

async function withRpcRetry(reader, attempts = 2) {
  // RPC providers can fail transiently. Retry reads only, keeping the API
  // responsive without hiding a persistent chain outage.
  let lastError;
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    try {
      return await reader();
    } catch (error) {
      lastError = error;
      if (attempt + 1 < attempts) {
        await new Promise((resolve) => setTimeout(resolve, 250));
      }
    }
  }
  throw lastError;
}

async function readVaultById(id) {
  if (id === 'gold') return withRpcRetry(readGoldVault);
  if (id === 'coffee') return withRpcRetry(readCoffeeVault);
  if (id === 'treasury') return withRpcRetry(readTreasuryVault);
  return null;
}

async function cmcRequest(url) {
  if (!CMC_API_KEY) return { error: 'CMC_API_KEY not configured' };

  try {
    const response = await fetch(url, {
      headers: { 'X-CMC_PRO_API_KEY': CMC_API_KEY },
      signal: AbortSignal.timeout(10000),
    });
    const body = await response.json();
    if (!response.ok && !body.status) {
      body.status = {
        error_code: response.status,
        error_message: `CMC returned ${response.status}`,
      };
    }
    return body;
  } catch (error) {
    return {
      error: `CoinMarketCap request failed: ${error.message}`,
      retryable: true,
    };
  }
}

async function fetchRwaList({ search, assetType, limit = 50 } = {}) {
  // Cache identical list queries to reduce external API traffic and improve
  // response time for repeated marketplace searches.
  const cacheKey = `rwa_list_${search || 'all'}_${assetType || 'all'}_${limit}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  try {
    const url = new URL(`${CMC_BASE}/v5/real-world-assets/list`);
    url.searchParams.set('limit', String(Math.min(Math.max(limit, 1), 100)));
    if (assetType) url.searchParams.set('asset_type', assetType);

    const body = await cmcRequest(url);
    if (body.error) return body;
    const status = body.status || {};
    if (status.error_code && status.error_code !== 0) {
      const errorCode = Number(status.error_code);
      return {
        error: status.error_message || 'CoinMarketCap error',
        error_code: status.error_code,
        retryable: errorCode === 500,
      };
    }

    let assets = body.data?.rwa_assets || body.data || [];
    if (!Array.isArray(assets)) assets = [];

    if (search) {
      const query = search.toLowerCase();
      assets = assets.filter((asset) =>
        [asset.name, asset.symbol, asset.rwa_slug]
          .filter(Boolean)
          .some((value) => String(value).toLowerCase().includes(query)),
      );
    }

    const result = {
      total: assets.length,
      assets: assets.map((asset) => ({
        rwa_id: asset.rwa_id,
        rwa_slug: asset.rwa_slug,
        symbol: asset.symbol,
        name: asset.name,
        asset_type: asset.asset_type,
        average_tokenized_price: asset.average_tokenized_price,
        tokenized_market_cap: asset.tokenized_market_cap,
        tokenized_volume_24h: asset.tokenized_volume_24h,
      })),
    };
    cmcCache.set(cacheKey, result, 60);
    return result;
  } catch (error) {
    return { error: error.message, retryable: true };
  }
}

async function fetchRwaListWithRetry(options, maxRetries = 3) {
  let lastError = null;
  for (let attempt = 0; attempt < maxRetries; attempt += 1) {
    const result = await fetchRwaList(options);
    if (!result.error) return result;
    if (!result.retryable) return result;
    lastError = result;
    if (attempt + 1 < maxRetries) {
      const delay = 2 ** (attempt + 1) * 1000;
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }
  return lastError || { error: 'Max retries exceeded', retryable: true };
}

async function coingeckoRequest(path, params = {}) {
  if (!COINGECKO_API_KEY) return { error: 'COINGECKO_API_KEY not configured' };

  try {
    const url = new URL(`${COINGECKO_BASE}${path}`);
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        url.searchParams.set(key, String(value));
      }
    });
    const response = await fetch(url, {
      headers: { 'x-cg-demo-api-key': COINGECKO_API_KEY },
      signal: AbortSignal.timeout(10000),
    });
    const body = await response.json();
    if (!response.ok) {
      return {
        error:
          body.error ||
          body.status?.error_message ||
          `CoinGecko returned ${response.status}`,
        retryable: response.status >= 500 || response.status === 429,
      };
    }
    return body;
  } catch (error) {
    return {
      error: `CoinGecko request failed: ${error.message}`,
      retryable: true,
    };
  }
}

function normalizeMarketAsset(asset) {
  return {
    id: asset.id,
    rwa_id: asset.id,
    rwa_slug: asset.id,
    symbol: asset.symbol?.toUpperCase(),
    name: asset.name,
    asset_type: 'tokenized_asset',
    image: asset.image,
    average_tokenized_price: asset.current_price,
    tokenized_market_cap: asset.market_cap,
    tokenized_volume_24h: asset.total_volume,
    price_usd: asset.current_price,
    market_cap_usd: asset.market_cap,
    volume_24h_usd: asset.total_volume,
    percent_change_24h: asset.price_change_percentage_24h,
  };
}

async function searchRwaAssets(query = '') {
  const cacheKey = `coingecko_search_${query || 'all'}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  const search = await coingeckoRequest('/search', { query: query || 'tokenized real world assets' });
  if (search.error) return search;
  const coins = (search.coins || []).slice(0, 20);
  if (!coins.length) return { total: 0, assets: [], source: 'coingecko' };

  const markets = await coingeckoRequest('/coins/markets', {
    vs_currency: 'usd',
    ids: coins.map((coin) => coin.id).join(','),
    order: 'market_cap_desc',
    per_page: 20,
    page: 1,
    sparkline: false,
  });
  if (markets.error) return markets;

  const result = {
    total: markets.length,
    source: 'coingecko',
    assets: markets.map(normalizeMarketAsset),
  };
  cmcCache.set(cacheKey, result, 60);
  return result;
}

async function getRwaCategoryAssets(categoryId) {
  if (!RWA_CATEGORY_IDS.has(categoryId)) {
    return { error: 'Unsupported RWA category' };
  }

  const cacheKey = `coingecko_category_${categoryId}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  const markets = await coingeckoRequest('/coins/markets', {
    vs_currency: 'usd',
    category: categoryId,
    order: 'market_cap_desc',
    per_page: 50,
    page: 1,
    sparkline: false,
  });
  if (markets.error) return markets;

  const result = {
    total: markets.length,
    source: 'coingecko',
    category: categoryId,
    assets: markets.map(normalizeMarketAsset),
  };
  cmcCache.set(cacheKey, result, 60);
  return result;
}

async function searchNftCollections(query = '') {
  if (!query.trim()) return { total: 0, collections: [], source: 'coingecko' };

  const cacheKey = `coingecko_nft_search_${query.toLowerCase()}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  const search = await coingeckoRequest('/search', { query });
  if (search.error) return search;

  const matches = (search.nfts || []).slice(0, 10);
  const collections = await Promise.all(matches.map(async (match) => {
    const details = await coingeckoRequest(
      `/nfts/${encodeURIComponent(match.id)}`,
    );
    const floor = details.error ? null : details.floor_price;
    const volume = details.error ? null : details.volume_24h;
    const marketCap = details.error ? null : details.market_cap;
    return {
      id: match.id,
      name: match.name,
      symbol: match.symbol,
      image: match.thumb,
      floor_price_usd: floor?.usd ?? null,
      volume_24h_usd: volume?.usd ?? null,
      market_cap_usd: marketCap?.usd ?? null,
      source: 'coingecko',
    };
  }));

  const result = { total: collections.length, collections, source: 'coingecko' };
  cmcCache.set(cacheKey, result, 60);
  return result;
}

function getFallbackCollections(limit = 10) {
  const fallback = [
    {
      id: 'bored-ape-yacht-club',
      name: 'Bored Ape Yacht Club',
      symbol: 'BAYC',
      image: 'https://assets.coingecko.com/nft_contracts/images/122/standard/bored-ape-yacht-club.png',
      floorPriceUsd: 180326699,
      volume24hUsd: 0,
      floorPriceChange24h: 0,
      marketCapUsd: 0,
      totalSupply: 0,
      owners: 0,
      nftMarketplace: 'ETH',
    },
    {
      id: 'pudgy-penguins',
      name: 'Pudgy Penguins',
      symbol: 'PPG',
      image: 'https://assets.coingecko.com/nft_contracts/images/1085/standard/pudgy-penguins.png',
      floorPriceUsd: 97139100,
      volume24hUsd: 86337207,
      floorPriceChange24h: -1.78,
      marketCapUsd: 0,
      totalSupply: 0,
      owners: 0,
      nftMarketplace: 'ETH',
    },
    {
      id: 'cryptopunks',
      name: 'CryptoPunks',
      symbol: 'PUNK',
      image: 'https://assets.coingecko.com/nft_contracts/images/5/standard/cryptopunks.png',
      floorPriceUsd: 1329900000,
      volume24hUsd: 0,
      floorPriceChange24h: 0,
      marketCapUsd: 0,
      totalSupply: 0,
      owners: 0,
      nftMarketplace: 'ETH',
    },
  ];
  return fallback.slice(0, limit);
}

async function getRwaAsset(id) {
  const cacheKey = `coingecko_asset_${id}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  const asset = await coingeckoRequest(`/coins/${encodeURIComponent(id)}`, {
    localization: false,
    tickers: false,
    market_data: true,
    community_data: false,
    developer_data: false,
  });
  if (asset.error) return asset;
  const market = asset.market_data || {};
  const result = {
    id: asset.id,
    rwa_id: asset.id,
    rwa_slug: asset.id,
    symbol: asset.symbol?.toUpperCase(),
    name: asset.name,
    description: asset.description?.en || '',
    asset_type: 'tokenized_asset',
    image: asset.image?.large || asset.image?.small,
    price_usd: market.current_price?.usd,
    market_cap_usd: market.market_cap?.usd,
    volume_24h_usd: market.total_volume?.usd,
    percent_change_24h: market.price_change_percentage_24h,
    last_updated: asset.last_updated,
    source: 'coingecko',
  };
  cmcCache.set(cacheKey, result, 60);
  return result;
}

async function getRwaChart(id, days = 30) {
  const normalizedDays = Math.min(Math.max(Number(days) || 30, 1), 365);
  const chart = await coingeckoRequest(`/coins/${encodeURIComponent(id)}/market_chart`, {
    vs_currency: 'usd',
    days: normalizedDays,
    interval: normalizedDays <= 1 ? 'hourly' : 'daily',
  });
  if (chart.error) return chart;
  return {
    id,
    source: 'coingecko',
    candles: (chart.prices || []).map(([time, price]) => ({
      time: new Date(time).toISOString(),
      close: price,
    })),
  };
}

async function getRwaCategories() {
  const cached = cmcCache.get('coingecko_categories');
  if (cached) return cached;
  const categories = await coingeckoRequest('/coins/categories/list');
  if (categories.error) return categories;
  const result = {
    source: 'coingecko',
    categories: categories.filter((category) =>
      /real|rwa|token|commodit/i.test(`${category.id} ${category.name}`),
    ),
  };
  cmcCache.set('coingecko_categories', result, 600);
  return result;
}

async function computeIssuerReputation(issuerAddress) {
  const normalizedIssuer = String(issuerAddress).trim();
  const cacheKey = `rep_${normalizedIssuer.toLowerCase()}`;
  const cached = reputationCache.get(cacheKey);
  if (cached) return cached;

  const baseline = {
    issuer: normalizedIssuer,
    score: 50,
    tier: 'C+',
    assets_tokenized: 0,
    on_time_settlement: null,
    audits_passed: 0,
    first_seen: null,
    last_updated: new Date().toISOString(),
    breakdown: { assets_score: 0, settlement_score: 20, audit_score: 0 },
  };

  try {
    const vaults = await fetchRwaList({ limit: 100 });
    if (vaults.error) {
      reputationCache.set(cacheKey, baseline);
      return baseline;
    }
    const issuerVaults = (vaults.assets || []).filter((vault) => {
      const issuer = vault.smeIssuer || vault.issuer;
      return issuer && issuer.toLowerCase() === normalizedIssuer.toLowerCase();
    });
    const assetsTokenized = issuerVaults.length;
    let settledOnTime = 0;
    let settledLate = 0;
    for (const vault of issuerVaults) {
      const invoice = vault.invoiceInfo;
      if (!invoice || !invoice.isSettled) continue;
      const settledAt = Number(invoice.settledAt);
      const maturityDate = Number(invoice.maturityDate);
      if (!Number.isFinite(settledAt) || !Number.isFinite(maturityDate)) continue;
      if (settledAt <= maturityDate) settledOnTime++;
      else settledLate++;
    }

    const totalSettled = settledOnTime + settledLate;
    const onTimeRate = totalSettled > 0 ? settledOnTime / totalSettled : null;
    const auditsPassed = issuerVaults.filter(
      (vault) => vault.auditReportURI,
    ).length;
    const assetsScore = Math.min(assetsTokenized * 5, 20);
    const settlementScore = onTimeRate === null ? 20 : onTimeRate * 40;
    const auditScore = Math.min(auditsPassed * 10, 40);
    const score = Math.round(assetsScore + settlementScore + auditScore);

    let tier = 'C';
    if (score >= 90) tier = 'A+';
    else if (score >= 80) tier = 'A';
    else if (score >= 70) tier = 'B+';
    else if (score >= 60) tier = 'B';
    else if (score >= 50) tier = 'C+';

    const result = {
      issuer: normalizedIssuer,
      score,
      tier,
      assets_tokenized: assetsTokenized,
      on_time_settlement:
          onTimeRate === null ? null : Math.round(onTimeRate * 100),
      audits_passed: auditsPassed,
      first_seen: null,
      last_updated: new Date().toISOString(),
      breakdown: {
        assets_score: Math.round(assetsScore),
        settlement_score: Math.round(settlementScore),
        audit_score: Math.round(auditScore),
      },
    };
    reputationCache.set(cacheKey, result);
    return result;
  } catch (_) {
    reputationCache.set(cacheKey, baseline);
    return baseline;
  }
}

async function withCmcFallback(primary, fallback) {
  // CoinGecko is the primary source for broad market data; CoinMarketCap is a
  // fallback so a provider outage does not make the marketplace unusable.
  let result;
  try {
    result = await primary();
  } catch (error) {
    result = { error: error.message, retryable: true };
  }
  if (!result.error) return result;
  let backup;
  try {
    backup = await fallback();
  } catch (error) {
    backup = { error: error.message, retryable: true };
  }
  if (!backup.error) return { ...backup, source: 'coinmarketcap_fallback' };
  return {
    error: result.error,
    primary_error: result.error,
    fallback_error: backup.error,
    retryable: result.retryable || backup.retryable || false,
  };
}

async function fetchRwaQuote(slug) {
  const cacheKey = `rwa_quote_${slug}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  try {
    const url = new URL(`${CMC_BASE}/v5/real-world-assets/quotes/latest`);
    url.searchParams.set('rwa_slug', slug);
    url.searchParams.set('convert', 'USD');
    const body = await cmcRequest(url);
    if (body.error) return body;

    const asset = (body.data?.rwa_assets || body.data || [])[0];
    if (!asset) return { error: 'Asset not found' };
    const quote = asset.average_tokenized_price?.quote?.USD || {};
    const result = {
      rwa_id: asset.rwa_id,
      symbol: asset.symbol,
      name: asset.name,
      price_usd: quote.price,
      market_cap_usd: asset.tokenized_market_cap?.quote?.USD?.price,
      volume_24h_usd: asset.tokenized_volume_24h?.quote?.USD?.price,
      percent_change_24h: quote.percent_change_24h,
      last_updated: quote.last_updated,
      tokens: asset.tokens || [],
    };
    cmcCache.set(cacheKey, result, 60);
    return result;
  } catch (error) {
    return { error: error.message };
  }
}

async function fetchRwaChart(symbol, period = 'daily', count = 30) {
  const normalizedPeriod = period === 'hourly' ? 'hourly' : 'daily';
  const normalizedCount = Math.min(Math.max(count, 1), 100);
  const cacheKey = `rwa_chart_${symbol}_${normalizedPeriod}_${normalizedCount}`;
  const cached = cmcCache.get(cacheKey);
  if (cached) return cached;

  try {
    const url = new URL(`${CMC_BASE}/v2/cryptocurrency/ohlcv/historical`);
    url.searchParams.set('symbol', symbol);
    url.searchParams.set('time_period', normalizedPeriod);
    url.searchParams.set('count', String(normalizedCount + 1));
    url.searchParams.set('convert', 'USD');
    const body = await cmcRequest(url);
    if (body.error) return body;

    const dataKey = Object.keys(body.data || {})[0];
    const quotes = body.data?.[dataKey]?.quotes || [];
    const result = {
      symbol,
      period: normalizedPeriod,
      candles: quotes.map((quote) => ({
        time: quote.time_open,
        open: quote.quote?.USD?.open,
        high: quote.quote?.USD?.high,
        low: quote.quote?.USD?.low,
        close: quote.quote?.USD?.close,
        volume: quote.quote?.USD?.volume,
      })),
    };
    cmcCache.set(cacheKey, result, 600);
    return result;
  } catch (error) {
    return { error: error.message };
  }
}

app.post('/api/nft/upload', async (req, res) => {
  if (!PINATA_JWT) {
    return res.status(503).json({ error: 'PINATA_JWT not configured' });
  }

  try {
    const { name, description, image } = req.body || {};
    if (!name || !image) {
      return res.status(400).json({ error: 'name and image are required' });
    }

    const imageBase64 = String(image).replace(/^data:image\/\w+;base64,/, '');
    const imageBuffer = Buffer.from(imageBase64, 'base64');
    const safeName = String(name)
      .trim()
      .replace(/[^a-zA-Z0-9._-]+/g, '-')
      .replace(/-+/g, '-')
      .toLowerCase() || 'nft';

    const imageForm = new FormData();
    imageForm.append('file', new Blob([imageBuffer]), `${safeName}.png`);

    const imageRes = await fetch('https://api.pinata.cloud/pinning/pinFileToIPFS', {
      method: 'POST',
      headers: { Authorization: `Bearer ${PINATA_JWT}` },
      body: imageForm,
    });

    if (!imageRes.ok) {
      const reason = await imageRes.text();
      throw new Error(`Pinata image upload failed: ${imageRes.status} ${reason}`);
    }

    const imageData = await imageRes.json();
    const imageUri = `ipfs://${imageData.IpfsHash}`;

    const metadata = {
      name,
      description: description || '',
      image: imageUri,
      attributes: [],
    };

    const metadataRes = await fetch('https://api.pinata.cloud/pinning/pinJSONToIPFS', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${PINATA_JWT}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(metadata),
    });

    if (!metadataRes.ok) {
      const reason = await metadataRes.text();
      throw new Error(`Pinata metadata upload failed: ${metadataRes.status} ${reason}`);
    }

    const metadataData = await metadataRes.json();
    const tokenUri = `ipfs://${metadataData.IpfsHash}`;

    return res.json({
      tokenUri,
      imageUri,
      metadataUri: tokenUri,
    });
  } catch (error) {
    console.error('NFT upload error:', error);
    return res.status(500).json({
      error: error.message || 'NFT upload failed',
    });
  }
});

app.get('/api/nft/metadata/:cid', async (req, res) => {
  try {
    const cid = req.params.cid;
    const response = await fetch(`https://gateway.pinata.cloud/ipfs/${cid}`);
    if (!response.ok) {
      throw new Error(`IPFS fetch failed: ${response.status}`);
    }
    const metadata = await response.json();
    return res.json(metadata);
  } catch (error) {
    return res.status(500).json({ error: error.message || 'Metadata fetch failed' });
  }
});

app.get('/api/agent/health', (_req, res) => {
  // Lightweight health check used by clients and deployment monitors.
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.post('/api/bridge/cctp', async (req, res) => {
  const { amount, recipientAddress } = req.body || {};
  if (!amount || !recipientAddress) {
    return res.status(400).json({ error: 'amount and recipientAddress are required' });
  }
  if (!process.env.CCTP_BRIDGE_PRIVATE_KEY) {
    return res.status(503).json({ error: 'CCTP bridge is not configured on this server' });
  }
  try {
    if (!/^[0-9]+$/.test(String(amount))) {
      return res.status(400).json({ error: 'amount must be an integer in USDC base units' });
    }
    const result = await new CctpBridge(process.env.CCTP_BRIDGE_PRIVATE_KEY).bridge({
      amount: BigInt(amount),
      recipientAddress,
    });
    return res.json({ success: true, ...result });
  } catch (error) {
    console.error('CCTP bridge failed:', error.message);
    return res.status(502).json({ error: error.message });
  }
});

app.get('/api/bridge/status/:messageHash', async (req, res) => {
  try {
    const response = await fetch(
      `https://iris-api-sandbox.circle.com/attestations/${encodeURIComponent(req.params.messageHash)}`,
    );
    const data = await response.json();
    return res.status(response.ok ? 200 : response.status).json(data);
  } catch (error) {
    return res.status(502).json({ error: error.message });
  }
});

app.get('/api/agent/vaults', async (_req, res) => {
  // Read all protocol vaults concurrently so one request has predictable
  // latency while preserving a single response shape for the Flutter client.
  try {
    const [gold, coffee, treasury] = await Promise.all([
      withRpcRetry(readGoldVault),
      withRpcRetry(readCoffeeVault),
      withRpcRetry(readTreasuryVault),
    ]);

    res.json({
      protocol: 'Aeroreal',
      version: '1.0',
      chain: 'monad-testnet',
      chain_id: 10143,
      timestamp: new Date().toISOString(),
      vaults: {
        gold_vault: gold,
        coffee_vault: coffee,
        treasury_vault: treasury,
      },
      metadata: {
        total_vaults: 3,
        live_chainlink_feed: 'XAU/USD',
        compliance_layer: 'whitelist-enforced',
        settlement_token: 'mUSD',
      },
    });
  } catch (error) {
    console.error('Vault read failed:', error);
    res.status(502).json({ error: 'Unable to read vault data from Monad Testnet' });
  }
});

app.get('/api/agent/vaults/:id', async (req, res) => {
  try {
    const vault = await readVaultById(req.params.id);
    if (!vault) return res.status(404).json({ error: 'Vault not found' });
    res.json(vault);
  } catch (error) {
    console.error(`Vault read failed for ${req.params.id}:`, error);
    res.status(502).json({ error: 'Unable to read vault data from Monad Testnet' });
  }
});

app.get('/api/rwa/list', async (req, res) => {
  // Convert external-provider failures into HTTP statuses that distinguish a
  // temporary outage (503) from a non-retryable request error (500).
  const result = await fetchRwaListWithRetry({
    search: req.query.search,
    assetType: req.query.type,
    limit: Number.parseInt(req.query.limit, 10) || 100,
  });
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/rwa/search', async (req, res) => {
  const result = await withCmcFallback(
    () => searchRwaAssets(req.query.q || ''),
    () => fetchRwaList({ search: req.query.q, limit: 100 }),
  );
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/rwa/category/:categoryId', async (req, res) => {
  if (!RWA_CATEGORY_IDS.has(req.params.categoryId)) {
    res.status(400).json({ error: 'Unsupported RWA category' });
    return;
  }

  const result = await getRwaCategoryAssets(req.params.categoryId);
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/coingecko/nft/trending', async (req, res) => {
  const limit = Math.min(Math.max(Number.parseInt(req.query.limit, 10) || 10, 1), 20);
  try {
    const url = new URL('https://api.coingecko.com/api/v3/nfts/markets');
    url.searchParams.set('order', 'market_cap_usd_desc');
    url.searchParams.set('per_page', String(limit));
    url.searchParams.set('page', '1');

    const headers = {};
    if (COINGECKO_API_KEY) {
      headers['x-cg-demo-api-key'] = COINGECKO_API_KEY;
    }

    const response = await fetch(url, {
      headers,
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      const collections = getFallbackCollections(limit);
      return res.status(response.status >= 500 ? 502 : 200).json({
        collections,
        count: collections.length,
        source: 'fallback',
      });
    }

    const body = await response.json();
    const collections = (Array.isArray(body) ? body : []).map((collection) => ({
      id: collection.id || '',
      name: collection.name || 'Unknown',
      symbol: collection.symbol || '',
      image: collection.image?.small || collection.image?.thumb || null,
      floorPriceUsd: Number(collection.floor_price?.usd ?? collection.floor_price ?? 0) || 0,
      floorPriceNative: Number(collection.floor_price?.native_currency ?? 0) || 0,
      marketCapUsd: Number(collection.market_cap?.usd ?? 0) || 0,
      volume24hUsd: Number(collection.volume_24h?.usd ?? 0) || 0,
      volume24hNative: Number(collection.volume_24h?.native_currency ?? 0) || 0,
      floorPriceChange24h:
        Number(collection.floor_price_24h_percentage_change ?? 0) || 0,
      marketCapChange24h: Number(collection.market_cap_24h_percentage_change ?? 0) || 0,
      totalSupply: Number(collection.total_supply ?? 0) || 0,
      owners: Number(collection.owners ?? 0) || 0,
      nftMarketplace: collection.native_currency || 'ETH',
    }));

    return res.json({
      collections,
      count: collections.length,
      source: 'coingecko',
    });
  } catch (error) {
    console.error('CoinGecko NFT trending failed:', error);
    const collections = getFallbackCollections(limit);
    return res.status(502).json({
      collections,
      count: collections.length,
      source: 'error_fallback',
      error: error.message,
    });
  }
});

app.get('/api/nfts/search', async (req, res) => {
  const result = await searchNftCollections(String(req.query.q || ''));
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/rwa/asset/:id', async (req, res) => {
  const result = await withCmcFallback(
    () => getRwaAsset(req.params.id),
    () => fetchRwaQuote(req.params.id),
  );
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/rwa/asset/:id/chart', async (req, res) => {
  const result = await withCmcFallback(
    () => getRwaChart(req.params.id, req.query.days),
    () => fetchRwaChart(req.params.id, 'daily', Number.parseInt(req.query.days, 10) || 30),
  );
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/rwa/categories', async (_req, res) => {
  const result = await getRwaCategories();
  res.status(result.error ? (result.retryable ? 503 : 500) : 200).json(result);
});

app.get('/api/rwa/:slug/quote', async (req, res) => {
  const result = await fetchRwaQuote(req.params.slug);
  res.status(result.error ? 503 : 200).json(result);
});

app.get('/api/rwa/:symbol/chart', async (req, res) => {
  const result = await fetchRwaChart(
    req.params.symbol,
    req.query.period || 'daily',
    Number.parseInt(req.query.count, 10) || 30,
  );
  res.status(result.error ? 503 : 200).json(result);
});

app.get('/api/issuer/:address/reputation', async (req, res) => {
  try {
    res.json(await computeIssuerReputation(req.params.address));
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/zerion/nfts/:address', async (req, res) => {
  if (!ZERION_API_KEY) {
    return res.status(503).json({ error: 'ZERION_API_KEY not configured' });
  }
  if (!ethers.isAddress(req.params.address)) {
    return res.status(400).json({ error: 'Invalid wallet address' });
  }

  const cacheKey = req.params.address.toLowerCase();
  const cached = zerionCache.get(cacheKey);
  if (cached) return res.json(cached);

  try {
    const url = new URL(
      `${ZERION_BASE}/wallets/${req.params.address}/nft-positions/`,
    );
    url.searchParams.set('currency', 'usd');
    const auth = Buffer.from(`${ZERION_API_KEY}:`).toString('base64');
    const response = await fetch(url, {
      headers: {
        Authorization: `Basic ${auth}`,
        'X-Env': 'testnet',
        accept: 'application/json',
      },
      signal: AbortSignal.timeout(10000),
    });

    if (response.status === 202) {
      return res.status(202).json({
        status: 'indexing',
        message: 'Wallet is being indexed. Retry shortly.',
      });
    }
    if (!response.ok) {
      return res.status(response.status === 429 ? 429 : 502).json({
        error: `Zerion returned ${response.status}`,
        retryable: response.status === 429 || response.status >= 500,
      });
    }

    const body = await response.json();
    const nfts = (Array.isArray(body.data) ? body.data : [])
      .map((item) => {
        const attributes = item.attributes || {};
        const nft = attributes.nft || {};
        const collection = nft.collection || {};
        const floorPriceValue = attributes.floor_price?.value;
        const floorPrice =
          floorPriceValue == null ? null : Number(floorPriceValue);

        return {
          id: item.id || '',
          name: nft.name || 'Unnamed NFT',
          description: nft.description || '',
          collectionName: collection.name || 'Unknown Collection',
          collectionSymbol: collection.symbol || '',
          contractAddress: collection.contract_address || '',
          tokenId: nft.token_id || '',
          chain: item.relationships?.chain?.data?.id || 'monad',
          image:
            nft.content?.preview?.url || nft.content?.detail?.url || null,
          floorPriceUsd:
            floorPrice !== null && Number.isFinite(floorPrice)
              ? floorPrice
              : null,
          spam: nft.flags?.is_spam === true,
        };
      })
      .filter((nft) => !nft.spam);

    const result = { nfts, count: nfts.length };
    zerionCache.set(cacheKey, result);
    return res.json(result);
  } catch (error) {
    console.error('Zerion request failed:', error.message);
    return res.status(502).json({ error: 'Zerion request failed' });
  }
});

app.get('/api/blockvision/nfts/:address', async (req, res) => {
  if (!BLOCKVISION_API_KEY) {
    return res.status(503).json({ error: 'BLOCKVISION_API_KEY not configured' });
  }
  if (!ethers.isAddress(req.params.address)) {
    return res.status(400).json({ error: 'Invalid wallet address' });
  }

  const cacheKey = req.params.address.toLowerCase();
  const cached = blockvisionCache.get(cacheKey);
  if (cached) return res.json(cached);

  try {
    const url = new URL(`${BLOCKVISION_BASE}/monad/account/nfts`);
    url.searchParams.set('address', req.params.address);
    url.searchParams.set('limit', '50');
    const response = await fetch(url, {
      headers: {
        accept: 'application/json',
        'x-api-key': BLOCKVISION_API_KEY,
      },
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      return res.status(response.status === 429 ? 429 : 502).json({
        error: `BlockVision returned ${response.status}`,
        retryable: response.status === 429 || response.status >= 500,
      });
    }

    const body = await response.json();
    if (Number(body.code) !== 0) {
      return res.status(502).json({
        error: body.message || 'BlockVision returned an API error',
      });
    }

    const sourceCollections = Array.isArray(body.result?.data)
      ? body.result.data
      : [];
    const collections = sourceCollections.map((collection) => {
      const items = Array.isArray(collection.items) ? collection.items : [];
      return {
        contractAddress: collection.contractAddress || '',
        name: collection.name || 'Unknown Collection',
        image: collection.image || null,
        verified: collection.verified === true,
        ercStandard: collection.ercStandard || 'ERC721',
        itemCount: items.length,
        items: items.map((item) => ({
          name: item.name || 'Unnamed',
          tokenId: item.tokenId == null ? '' : String(item.tokenId),
          image: item.image || null,
          qty: item.qty == null ? '1' : String(item.qty),
        })),
      };
    });
    const result = {
      collections,
      totalCollections: collections.length,
      source: 'blockvision',
    };
    blockvisionCache.set(cacheKey, result);
    return res.json(result);
  } catch (error) {
    console.error('BlockVision request failed:', error.message);
    return res.status(502).json({ error: 'BlockVision request failed' });
  }
});

app.get('/api/magiceden/trending', async (_req, res) => {
  try {
    const chain = 'monad-testnet';
    const url = new URL('https://api-mainnet.magiceden.dev/v2/collections');
    url.searchParams.set('chain', chain);
    url.searchParams.set('limit', '10');

    const headers = { accept: 'application/json' };
    if (MAGIC_EDEN_API_KEY) {
      headers.Authorization = `Bearer ${MAGIC_EDEN_API_KEY}`;
    }

    const response = await fetch(url, {
      headers,
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      return res.json({
        collections: [
          {
            symbol: 'monad-apes',
            name: 'Monad Apes',
            image: 'https://api.dicebear.com/7.x/adventurer/svg?seed=monad-apes',
            floorPrice: 500,
            sales24h: 12,
            chain,
          },
          {
            symbol: 'monad-punks',
            name: 'Monad Punks',
            image: 'https://api.dicebear.com/7.x/bottts/svg?seed=monad-punks',
            floorPrice: 350,
            sales24h: 8,
            chain,
          },
          {
            symbol: 'monad-frogs',
            name: 'Monad Frogs',
            image: 'https://api.dicebear.com/7.x/big-smile/svg?seed=monad-frogs',
            floorPrice: 200,
            sales24h: 25,
            chain,
          },
        ],
        source: 'fallback',
      });
    }

    const body = await response.json();
    const collections = (Array.isArray(body) ? body : []).map((collection) => ({
      symbol: collection.symbol || '',
      name: collection.name || 'Unknown Collection',
      image:
        collection.image ||
        `https://api.dicebear.com/7.x/shapes/svg?seed=${encodeURIComponent(
          collection.symbol || 'collection',
        )}`,
      floorPrice: Number(collection.floorPrice ?? collection.floor_price ?? 0) || 0,
      sales24h: Number(collection.sales24h ?? collection.sales_24h ?? 0) || 0,
      chain: collection.chain || chain,
    }));

    return res.json({
      collections,
      count: collections.length,
      source: 'magiceden',
      chain,
    });
  } catch (error) {
    console.error('Magic Eden error:', error);
    return res.json({
      collections: [],
      source: 'error',
    });
  }
});

app.get('/api/blockvision/activity/:collectionAddress', async (req, res) => {
  try {
    const collectionAddress = req.params.collectionAddress;
    if (!collectionAddress) {
      return res.status(400).json({ error: 'Missing collection address' });
    }
    if (!BLOCKVISION_API_KEY) {
      return res.status(503).json({ error: 'BLOCKVISION_API_KEY not configured' });
    }

    const url = new URL(`${BLOCKVISION_BASE}/monad/collection/activities`);
    url.searchParams.set('address', collectionAddress);
    url.searchParams.set('limit', '10');

    const response = await fetch(url, {
      headers: {
        accept: 'application/json',
        'x-api-key': BLOCKVISION_API_KEY,
      },
      signal: AbortSignal.timeout(10000),
    });

    if (!response.ok) {
      return res.status(response.status === 429 ? 429 : 502).json({
        error: `BlockVision returned ${response.status}`,
      });
    }

    const body = await response.json();
    const activities = (Array.isArray(body.result?.data) ? body.result.data : []).map(
      (activity) => ({
        id:
          activity.transactionHash ||
          activity.hash ||
          `${activity.method || 'activity'}-${activity.timestamp || Date.now()}`,
        method: activity.method || 'Transfer',
        nftName: activity.nft?.name || 'Unknown NFT',
        nftImage: activity.nft?.image || null,
        from: activity.from || '',
        to: activity.to || '',
        timestamp: activity.timestamp || null,
      }),
    );

    return res.json({ activities });
  } catch (error) {
    console.error('BlockVision activity request failed:', error.message);
    return res.status(500).json({ error: 'BlockVision activity request failed' });
  }
});

app.get('/api/user/profile/:walletAddress', (req, res) => {
  try {
    res.json(getProfile(req.params.walletAddress));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.put('/api/user/profile/:walletAddress', (req, res) => {
  try {
    res.json(updateProfile(req.params.walletAddress, req.body));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.post('/api/user/search/:walletAddress', (req, res) => {
  try {
    res.json({
      searchHistory: addSearchQuery(req.params.walletAddress, req.body?.query),
    });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.post('/api/simulated/buy', async (req, res) => {
  try {
    const {
      walletAddress,
      symbol,
      amountAsset,
      arealCost,
      coingeckoId,
      imageUrl,
    } = req.body || {};
    if (!walletAddress || !symbol || amountAsset === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const profile = getProfile(walletAddress);
    const holdings = { ...(profile.simulatedHoldings || {}) };
    const key = String(symbol).toUpperCase();
    const amount = Number(amountAsset);
    const totalCost = Number(arealCost ?? amount * 0);

    const existing = holdings[key] || {
      symbol: key,
      coingeckoId: coingeckoId || key.toLowerCase(),
      imageUrl: typeof imageUrl === 'string' && imageUrl.trim()
        ? imageUrl.trim()
        : null,
      totalAmount: 0,
      totalCostAreal: 0,
      firstPurchase: new Date().toISOString(),
    };

    existing.coingeckoId =
      coingeckoId || existing.coingeckoId || key.toLowerCase();
    if (typeof imageUrl === 'string' && imageUrl.trim() && !existing.imageUrl) {
      existing.imageUrl = imageUrl.trim();
    }
    existing.totalAmount += amount;
    existing.totalCostAreal += totalCost;
    existing.lastPurchase = new Date().toISOString();
    existing.avgPrice = existing.totalAmount > 0
      ? existing.totalCostAreal / existing.totalAmount
      : 0;

    holdings[key] = existing;
    const updated = updateProfile(walletAddress, { simulatedHoldings: holdings });
    res.json({ success: true, profile: updated });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/simulated/sell', async (req, res) => {
  try {
    const { walletAddress, symbol, amountAsset, arealProceeds } = req.body || {};
    if (!walletAddress || !symbol || amountAsset === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const profile = getProfile(walletAddress);
    const holdings = { ...(profile.simulatedHoldings || {}) };
    const key = String(symbol).toUpperCase();
    const amount = Number(amountAsset);

    if (!holdings[key]) {
      return res.status(400).json({ error: 'No holding for this asset' });
    }

    const existing = holdings[key];
    if (existing.totalAmount < amount) {
      return res.status(400).json({ error: 'Insufficient balance' });
    }

    const soldFraction = amount / existing.totalAmount;
    existing.totalAmount -= amount;
    existing.totalCostAreal -= existing.totalCostAreal * soldFraction;

    if (existing.totalAmount <= 0) {
      delete holdings[key];
    } else {
      existing.avgPrice = existing.totalCostAreal / existing.totalAmount;
      holdings[key] = existing;
    }

    const updated = updateProfile(walletAddress, { simulatedHoldings: holdings });
    res.json({ success: true, profile: updated });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/simulated/nft/mint', (req, res) => {
  try {
    const {
      walletAddress,
      collectionSymbol,
      collectionName,
      contractAddress,
      tokenId,
      transactionHash,
    } = req.body || {};
    if (!walletAddress || !collectionSymbol || !contractAddress || !tokenId) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    if (!ethers.isAddress(contractAddress) || !/^\d+$/.test(String(tokenId))) {
      return res.status(400).json({ error: 'Invalid NFT contract or token ID' });
    }

    const profile = getProfile(walletAddress);
    const nfts = [...(profile.simulatedNfts || [])];
    const nft = {
      id: `${contractAddress.toLowerCase()}-${tokenId}`,
      collectionSymbol: String(collectionSymbol),
      collectionName: String(collectionName || collectionSymbol),
      contractAddress,
      tokenId: String(tokenId),
      transactionHash: transactionHash || null,
      mintedAt: new Date().toISOString(),
      fractionalized: false,
      fractionTokenAddress: null,
    };

    if (nfts.some((item) => item.id === nft.id)) {
      return res.status(409).json({ error: 'NFT is already recorded' });
    }
    nfts.push(nft);
    const updated = updateProfile(walletAddress, { simulatedNfts: nfts });
    res.json({ success: true, nft, profile: updated });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/simulated/nft/fractionalize', (req, res) => {
  try {
    const { walletAddress, nftId, fractionTokenAddress } = req.body || {};
    if (!walletAddress || !nftId || !fractionTokenAddress) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    if (!ethers.isAddress(fractionTokenAddress)) {
      return res.status(400).json({ error: 'Invalid fraction token address' });
    }

    const profile = getProfile(walletAddress);
    const nfts = [...(profile.simulatedNfts || [])];
    const nft = nfts.find((item) => item.id === nftId);
    if (!nft) return res.status(404).json({ error: 'NFT not found' });
    if (nft.fractionalized) {
      return res.status(409).json({ error: 'NFT is already fractionalized' });
    }

    nft.fractionalized = true;
    nft.fractionTokenAddress = fractionTokenAddress;
    nft.fractionalizedAt = new Date().toISOString();
    const updated = updateProfile(walletAddress, { simulatedNfts: nfts });
    res.json({ success: true, profile: updated });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/user/profile/:walletAddress', (req, res) => {
  try {
    deleteProfile(req.params.walletAddress);
    res.json({ success: true });
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

app.get('/api/news/rwa', async (_req, res) => {
  const cacheKey = 'rwa_news';
  const cached = newsCache.get(cacheKey);
  if (cached) return res.json(cached);

  try {
    const headers = COINGECKO_API_KEY
      ? { 'x-cg-demo-api-key': COINGECKO_API_KEY }
      : {};
    const response = await fetch(`${COINGECKO_BASE}/news`, {
      headers,
      signal: AbortSignal.timeout(10000),
    });
    const body = await response.json();
    if (!response.ok) {
      throw new Error(
        body.error || `CoinGecko news returned ${response.status}`,
      );
    }

    const items = (body.data || []).slice(0, 20).map((item) => ({
      id: item.id?.toString() || item.url,
      title: item.title || '',
      description: item.description || '',
      url: item.url || '',
      thumbnail: item.thumb_2x || item.thumb || null,
      source: item.news_site || 'Unknown',
      published_at: item.updated_at
        ? new Date(item.updated_at * 1000).toISOString()
        : null,
    }));
    const result = { items };
    newsCache.set(cacheKey, result);
    return res.json(result);
  } catch (error) {
    try {
      const rssResponse = await fetch(
        'https://www.coindesk.com/arc/outboundfeeds/rss/',
        { signal: AbortSignal.timeout(10000) },
      );
      if (!rssResponse.ok) {
        throw new Error(`CoinDesk RSS returned ${rssResponse.status}`);
      }
      const xml = await rssResponse.text();
      const parser = new XMLParser({ isArray: (name) => name === 'item' });
      const parsed = parser.parse(xml);
      const rssItems = parsed.rss?.channel?.item || [];
      const items = rssItems.slice(0, 20).map((item) => ({
        id: item.guid?.['#text'] || item.guid || item.link,
        title: item.title || '',
        description: item.description || '',
        url: item.link || '',
        thumbnail: item.enclosure?.['@_url'] || null,
        source: 'CoinDesk',
        published_at: item.pubDate
          ? new Date(item.pubDate).toISOString()
          : null,
      }));
      const result = { items };
      newsCache.set(cacheKey, result);
      return res.json(result);
    } catch (fallbackError) {
      console.error('News error:', error.message, fallbackError.message);
      return res.status(502).json({ error: error.message });
    }
  }
});

app.listen(PORT, () => {
  console.log(`Agent API listening on http://localhost:${PORT}`);
});
