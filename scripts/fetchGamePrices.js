const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firebase Admin
if (!admin.apps.length) {
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    try {
      const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    } catch (e) {
      console.warn("Could not parse FIREBASE_SERVICE_ACCOUNT JSON, using default app credentials:", e.message);
      admin.initializeApp();
    }
  } else {
    admin.initializeApp();
  }
}
const db = admin.firestore();

const GAMES = [
  "GTA VI",
  "Elden Ring",
  "Cyberpunk 2077",
  "God of War",
  "EA Sports FC 26",
  "Call of Duty",
  "Tekken 8",
  "Counter-Strike 2",
  "Palworld",
  "Helldivers 2",
];

const STORE_MAP = {
  "1": "Steam",
  "2": "GamersGate",
  "3": "GreenManGaming",
  "7": "GOG",
  "11": "Humble Store",
  "25": "Epic Games",
};

const DEFAULT_PRICES = {
  "GTA VI": { currentPrice: 69.99, originalPrice: 69.99, lowestPrice: 69.99, discount: 0 },
  "Elden Ring": { currentPrice: 59.99, originalPrice: 59.99, lowestPrice: 35.99, discount: 0 },
  "Cyberpunk 2077": { currentPrice: 29.99, originalPrice: 59.99, lowestPrice: 19.99, discount: 50 },
  "God of War": { currentPrice: 24.99, originalPrice: 49.99, lowestPrice: 19.99, discount: 50 },
  "EA Sports FC 26": { currentPrice: 69.99, originalPrice: 69.99, lowestPrice: 29.99, discount: 0 },
  "Call of Duty": { currentPrice: 69.99, originalPrice: 69.99, lowestPrice: 34.99, discount: 0 },
  "Tekken 8": { currentPrice: 49.99, originalPrice: 69.99, lowestPrice: 41.99, discount: 29 },
  "Counter-Strike 2": { currentPrice: 14.99, originalPrice: 14.99, lowestPrice: 9.99, discount: 0 },
  "Palworld": { currentPrice: 29.99, originalPrice: 29.99, lowestPrice: 26.99, discount: 0 },
  "Helldivers 2": { currentPrice: 39.99, originalPrice: 39.99, lowestPrice: 31.99, discount: 0 },
};

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function fetchGamePrice(game) {
  console.log(`\n[Checking] ${game}...`);
  const docId = game.toLowerCase().trim().replace(/\s+/g, '_');

  let currentPrice = 0;
  let originalPrice = 0;
  let lowestPrice = 0;
  let discountPercent = 0;
  let dealID = '';
  let dealUrl = '';
  let store = 'Steam';

  try {
    // 1. Search game on CheapShark
    const searchUrl = `https://www.cheapshark.com/api/1.0/games?title=${encodeURIComponent(game)}&limit=1`;
    const searchRes = await axios.get(searchUrl, { timeout: 10000 });
    const searchData = searchRes.data;

    if (searchData && searchData.length > 0 && searchData[0].gameID) {
      const gameID = searchData[0].gameID;

      // 2. Fetch game details
      const detailUrl = `https://www.cheapshark.com/api/1.0/games?id=${gameID}`;
      const detailRes = await axios.get(detailUrl, { timeout: 10000 });
      const detail = detailRes.data;

      if (detail && detail.deals && detail.deals.length > 0) {
        const deal = detail.deals[0];
        currentPrice = parseFloat(deal.price || searchData[0].cheapest || 0);
        originalPrice = parseFloat(deal.retailPrice || currentPrice);
        lowestPrice = parseFloat(detail.cheapestPriceEver?.price || currentPrice);
        discountPercent = Math.round(parseFloat(deal.savings || 0));
        dealID = deal.dealID || '';
        dealUrl = dealID ? `https://www.cheapshark.com/redirect?dealID=${dealID}` : '';
        store = STORE_MAP[deal.storeID] || 'Steam';
      }
    }
  } catch (err) {
    console.warn(`CheapShark API error for ${game}: ${err.message}`);
  }

  // Fallback if not found or unreleased game
  if (currentPrice <= 0) {
    const fb = DEFAULT_PRICES[game] || { currentPrice: 39.99, originalPrice: 59.99, lowestPrice: 19.99, discount: 33 };
    currentPrice = fb.currentPrice;
    originalPrice = fb.originalPrice;
    lowestPrice = fb.lowestPrice;
    discountPercent = fb.discount;
    dealUrl = `https://store.steampowered.com/search/?term=${encodeURIComponent(game)}`;
    store = 'Steam';
  }

  // Retrieve existing priceHistory
  let priceHistory = [];
  try {
    const existingDoc = await db.collection('game_prices').doc(docId).get();
    if (existingDoc.exists && existingDoc.data().priceHistory) {
      priceHistory = existingDoc.data().priceHistory;
    }
  } catch (_) {}

  const todayStr = new Date().toISOString().split('T')[0];
  // Add new price entry
  priceHistory.push({ date: todayStr, price: currentPrice });

  // Keep last 30 entries
  if (priceHistory.length > 30) {
    priceHistory = priceHistory.slice(priceHistory.length - 30);
  }

  // Write to game_prices
  await db.collection('game_prices').doc(docId).set({
    gameName: game,
    currentPrice: currentPrice,
    originalPrice: originalPrice,
    lowestPrice: lowestPrice,
    store: store,
    dealID: dealID,
    dealUrl: dealUrl,
    discountPercent: discountPercent,
    priceHistory: priceHistory,
    lastChecked: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log(`[Updated] ${game} (${docId}): $${currentPrice} (was $${originalPrice}, lowest $${lowestPrice}, store: ${store})`);

  // Query user_price_alerts for triggers
  try {
    const alertsSnap = await db.collection('user_price_alerts')
      .where('gameName', '==', game)
      .where('isActive', '==', true)
      .get();

    for (const doc of alertsSnap.docs) {
      const alert = doc.data();
      const targetUSD = Number(alert.targetPriceUSD || 0);
      if (targetUSD > 0 && currentPrice <= targetUSD) {
        console.log(`ALERT TRIGGER for userId: ${alert.userId} on ${game}! (Current: $${currentPrice} <= Target: $${targetUSD} / Rs. ${alert.targetPricePKR})`);
      }
    }
  } catch (alertErr) {
    console.warn(`Error checking user alerts for ${game}: ${alertErr.message}`);
  }
}

async function run() {
  console.log(`Starting Price Tracker fetch for ${GAMES.length} games...`);

  for (const game of GAMES) {
    await fetchGamePrice(game);
    // 1.5s delay between games to avoid rate limit
    await sleep(1500);
  }

  console.log("DONE - PRICES FETCHED");
  process.exit(0);
}

run().catch(err => {
  console.error("Fatal error during fetchGamePrices:", err);
  process.exit(1);
});
