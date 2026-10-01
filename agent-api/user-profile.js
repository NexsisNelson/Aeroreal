const fs = require('fs');
const path = require('path');

// JSON storage keeps the hackathon persistence layer easy to replace later.
const DB_PATH = path.join(__dirname, 'user-profiles.json');

function loadDb() {
  if (!fs.existsSync(DB_PATH)) fs.writeFileSync(DB_PATH, JSON.stringify({}));
  try {
    return JSON.parse(fs.readFileSync(DB_PATH, 'utf8'));
  } catch (_) {
    return {};
  }
}

function saveDb(db) {
  fs.writeFileSync(DB_PATH, JSON.stringify(db, null, 2));
}

function profileKey(walletAddress) {
  if (typeof walletAddress !== 'string' || walletAddress.trim().length === 0) {
    throw new Error('walletAddress is required');
  }
  return walletAddress.trim().toLowerCase();
}

function createProfile(key) {
  const now = new Date().toISOString();
  return {
    walletAddress: key,
    createdAt: now,
    updatedAt: now,
    watchlist: [],
    costBasis: {},
    txHistory: [],
    tractionLog: [],
    searchHistory: [],
    preferences: {
      theme: 'dark',
      currency: 'USD',
      notifications: true,
      hideBalances: false,
    },
    simulatedHoldings: {},
    simulatedNfts: [],
  };
}

function getProfile(walletAddress) {
  const db = loadDb();
  const key = profileKey(walletAddress);
  if (!db[key]) {
    db[key] = createProfile(key);
    saveDb(db);
  }
  return db[key];
}

function updateProfile(walletAddress, patch = {}) {
  const db = loadDb();
  const key = profileKey(walletAddress);
  const existing = db[key] || createProfile(key);

  for (const field of [
    'watchlist',
    'costBasis',
    'txHistory',
    'tractionLog',
    'searchHistory',
    'simulatedHoldings',
    'simulatedNfts',
  ]) {
    if (patch[field] !== undefined) existing[field] = patch[field];
  }
  if (patch.preferences !== undefined) {
    existing.preferences = { ...existing.preferences, ...patch.preferences };
  }
  if (patch.yieldHistory !== undefined) {
    existing.yieldHistory = patch.yieldHistory;
  }

  existing.updatedAt = new Date().toISOString();
  db[key] = existing;
  saveDb(db);
  return existing;
}

function addSearchQuery(walletAddress, query) {
  if (typeof query !== 'string' || query.trim().length === 0) {
    throw new Error('query is required');
  }

  const db = loadDb();
  const key = profileKey(walletAddress);
  const profile = db[key] || createProfile(key);
  const normalizedQuery = query.trim();
  profile.searchHistory = [
    normalizedQuery,
    ...(profile.searchHistory || []).filter((item) => item !== normalizedQuery),
  ].slice(0, 50);
  profile.updatedAt = new Date().toISOString();
  db[key] = profile;
  saveDb(db);
  return profile.searchHistory;
}

function deleteProfile(walletAddress) {
  const db = loadDb();
  delete db[profileKey(walletAddress)];
  saveDb(db);
}

module.exports = { getProfile, updateProfile, addSearchQuery, deleteProfile };