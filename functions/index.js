const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated, onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");
const axios = require("axios");

initializeApp();

const GAMES = [
  {appid: 1245620, name: "ELDEN RING", category: "Action Games"},
  {appid: 1938090, name: "Call of Duty MW3", category: "Action Games"},
  {appid: 1623730, name: "Palworld", category: "Simulator Games"},
  {appid: 1172470, name: "Apex Legends", category: "Action Games"},
  {appid: 570, name: "Dota 2", category: "Action Games"},
  {appid: 578080, name: "PUBG", category: "Action Games"},
  {appid: 730, name: "Counter Strike 2", category: "Action Games"},
];

async function fetchAndSaveFullNews() {
  const db = getFirestore();
  console.log("Fetching FULL news & prices for all games...");

  for (const game of GAMES) {
    try {
      // 1. Fetch live Steam price overview
      let currentPrice = 2999;
      let originalPriceVal = 4499;
      let priceHistory = [
        {date: "1 Mo Ago", price: 4499},
        {date: "Today", price: 2999},
      ];
      try {
        const priceRes = await axios.get(
          `https://store.steampowered.com/api/appdetails?appids=${game.appid}&filters=price_overview&cc=pk`,
          {timeout: 5000}
        );
        const po = priceRes.data?.[game.appid]?.data?.price_overview;
        if (po) {
          currentPrice = Math.round(po.final / 100);
          originalPriceVal = Math.round(po.initial / 100);
          priceHistory = [
            {date: "2 Mo Ago", price: originalPriceVal},
            {date: "1 Mo Ago", price: Math.round(originalPriceVal * 0.9)},
            {date: "Today", price: currentPrice},
          ];
        }
      } catch (pe) {
        console.log(`Price fetch fallback for ${game.name}: ${pe.message}`);
      }

      // 2. Fetch Steam news
      const apiUrl = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${game.appid}&count=10&maxlength=0&format=json`;
      const response = await axios.get(apiUrl);
      const newsItems = response.data?.appnews?.newsitems || [];

      for (const item of newsItems) {
        let fullContent = item.contents || "";
        fullContent = fullContent.replace(/\[.*?\]/g, "").trim();
        if (fullContent.length < 30) continue;

        const docId = `${game.appid}_${item.gid}`;
        await db.collection("news").doc(docId).set({
          id: docId,
          title: item.title,
          description: fullContent,
          title_en: item.title,
          description_en: fullContent,
          title_ur: item.title,
          description_ur: fullContent,
          title_ro: item.title,
          description_ro: fullContent,
          imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${game.appid}/header.jpg`,
          category: game.category,
          gameName: game.name,
          appid: game.appid,
          appId: game.appid,
          url: item.url,
          sourceUrl: item.url,
          store: "Steam",
          currentPrice: currentPrice,
          originalPrice: `Rs. ${originalPriceVal}`,
          originalPriceVal: originalPriceVal,
          priceHistory: priceHistory,
          views: Math.floor(Math.random() * 500) + 20,
          timestamp: item.date,
          timeAgo: new Date(item.date * 1000).toISOString(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      console.log(`Full news & prices saved for ${game.name}`);
    } catch (err) {
      console.error(`Error ${game.name}:`, err.message);
    }
  }
  return "All Full News Updated Successfully";
}

exports.fetchGamingNews = onSchedule("every 6 hours", async () => {
  await fetchAndSaveFullNews();
});

exports.fetchNewsManual = onRequest(async (req, res) => {
  const msg = await fetchAndSaveFullNews();
  res.send(msg);
});

// Trigger FCM push notification on new Firestore doc added: "New: {gameName}"
exports.onNewsCreated = onDocumentCreated("news/{newsId}", async (event) => {
  const data = event.data?.data();
  if (!data) return;

  const gameName = data.gameName || data.category || "Gaming News";
  const title = `New: ${gameName}`;
  const body = data.title || "Check out the latest gaming update!";

  const message = {
    topic: "all_news",
    notification: {
      title: title,
      body: body,
    },
    data: {
      newsId: event.params.newsId,
      gameName: gameName,
      title: data.title || "",
      category: data.category || "",
      imageUrl: data.imageUrl || "",
    },
  };

  try {
    await getMessaging().send(message);
    console.log(`FCM notification sent: ${title}`);
  } catch (err) {
    console.error("Error sending FCM message:", err.message);
  }
});

// Price Tracker Trigger: If currentPrice < alertPrice, send FCM push "Sasta Hua!"
exports.onPriceUpdated = onDocumentUpdated("news/{newsId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;

  const oldPrice = Number(before.currentPrice || before.originalPriceVal || 0);
  const newPrice = Number(after.currentPrice || 0);

  if (newPrice > 0 && (oldPrice === 0 || newPrice < oldPrice)) {
    const gameName = after.gameName || after.category || "Game";
    const title = `Sasta Hua! 🔥 ${gameName}`;
    const body = `Ab sirf Rs. ${newPrice}! (Pehle Rs. ${oldPrice || Math.round(newPrice * 1.3)} tha) Jaldi lo!`;

    // 1. Send to topic subscribers
    const cleanTopic = `price_drop_${event.params.newsId.replace(/[^a-zA-Z0-9-_.~%]/g, "_")}`;
    try {
      await getMessaging().send({
        topic: cleanTopic,
        notification: {title, body},
        data: {
          newsId: event.params.newsId,
          type: "price_drop",
          gameName: gameName,
          currentPrice: String(newPrice),
        },
      });
      console.log(`Price drop FCM sent to topic: ${cleanTopic}`);
    } catch (e) {
      console.error(`Error sending price drop to topic:`, e.message);
    }

    // 2. Check user-specific alert targets in price_alerts collection
    try {
      const db = getFirestore();
      const alertsSnap = await db.collection("price_alerts")
        .where("gameId", "==", event.params.newsId)
        .where("active", "==", true)
        .get();

      for (const doc of alertsSnap.docs) {
        const alert = doc.data();
        if (alert.alertPrice && newPrice <= alert.alertPrice && alert.fcmToken) {
          await getMessaging().send({
            token: alert.fcmToken,
            notification: {title, body},
            data: {
              newsId: event.params.newsId,
              type: "price_drop",
              gameName: gameName,
              currentPrice: String(newPrice),
            },
          }).catch(() => {});
        }
      }
    } catch (e) {
      console.error(`Error querying price_alerts:`, e.message);
    }
  }
});

// -------------------------------------------------------------
// 2. AUTO BOT FOR ALL GAMES: autoCreateMultiGameTournaments()
// Logic:
// - Every 15 minutes, auto-create 1 room for Top 5 games (BGMI, PUBG Mobile, Garena Free Fire, COD Mobile, Valorant).
// - Every 1 hour, auto-create 1 room for other games (Fortnite, Ludo King, 8 Ball Pool, etc).
// - All rooms: Entry = FREE (0 Coins) Watch 1 Ad to Join, Prize = 500 Coins from Admin Escrow, Max Players = 2/4/8.
// - Title format: "{GameName} {Mode} Auto #{ID}".
// -------------------------------------------------------------

const MULTI_GAME_CONFIGS = {
  "BGMI": { mode: "Warehouse TDM", map: "Warehouse", slots: [2, 4, 8], shortMode: "TDM" },
  "PUBG Mobile": { mode: "Warehouse TDM", map: "Warehouse", slots: [2, 4, 8], shortMode: "TDM" },
  "Garena Free Fire": { mode: "Clash Squad", map: "Bermuda", slots: [4, 2, 8], shortMode: "Clash Squad" },
  "COD Mobile": { mode: "TDM", map: "Crash", slots: [2, 4, 8], shortMode: "TDM" },
  "Valorant": { mode: "Spike Rush", map: "Ascent", slots: [2, 4, 8], shortMode: "Spike Rush" },
  "Free Fire Max": { mode: "Clash Squad", map: "Bermuda", slots: [4, 2, 8], shortMode: "Clash Squad" },
  "COD Warzone": { mode: "Resurgence", map: "Rebirth Island", slots: [4, 2, 8], shortMode: "Resurgence" },
  "Fortnite": { mode: "Box Fight 1v1", map: "Creative Arena", slots: [2, 4, 8], shortMode: "Box Fight" },
  "Apex Legends": { mode: "Arenas 3v3", map: "Party Crasher", slots: [2, 4, 8], shortMode: "Arenas" },
  "Counter-Strike 2": { mode: "Wingman 2v2", map: "Dust II", slots: [4, 2, 8], shortMode: "Wingman" },
  "Mobile Legends Bang Bang": { mode: "Classic 5v5", map: "Land of Dawn", slots: [2, 4, 8], shortMode: "Classic" },
  "League of Legends": { mode: "ARAM 1v1", map: "Howling Abyss", slots: [2, 4, 8], shortMode: "ARAM" },
  "Clash Royale": { mode: "Friendly 1v1", map: "Legendary Arena", slots: [2, 4], shortMode: "Friendly" },
  "Brawl Stars": { mode: "Bounty 3v3", map: "Shooting Star", slots: [2, 4, 8], shortMode: "Bounty" },
  "Minecraft": { mode: "PvP Duel 1v1", map: "Gladiator Arena", slots: [2, 4, 8], shortMode: "PvP Duel" },
  "Roblox": { mode: "BedWars 1v1", map: "Custom Arena", slots: [2, 4, 8], shortMode: "BedWars" },
  "EA Sports FC 25": { mode: "Head to Head 1v1", map: "Champions Stadium", slots: [2, 4], shortMode: "1v1" },
  "8 Ball Pool": { mode: "1v1 Classic", map: "London Pub", slots: [2, 4, 8], shortMode: "1v1 Classic" },
  "Ludo King": { mode: "Quick 2/4 Player", map: "Classic Board", slots: [2, 4], shortMode: "Quick" },
};

const TOP_5_GAMES = ["BGMI", "PUBG Mobile", "Garena Free Fire", "COD Mobile", "Valorant"];
const OTHER_GAMES = [
  "Free Fire Max", "COD Warzone", "Fortnite", "Apex Legends",
  "Counter-Strike 2", "Mobile Legends Bang Bang", "League of Legends",
  "Clash Royale", "Brawl Stars", "Minecraft", "Roblox", "EA Sports FC 25",
  "8 Ball Pool", "Ludo King"
];

async function createBotRoomForGame(db, gameName) {
  const config = MULTI_GAME_CONFIGS[gameName] || {
    mode: "Custom Match",
    map: "Default Arena",
    slots: [2, 4, 8],
    shortMode: "Match",
  };

  const randId = Math.floor(100 + Math.random() * 900);
  const slotOptions = config.slots;
  const maxPlayers = slotOptions[Math.floor(Math.random() * slotOptions.length)];
  const title = `${gameName} ${config.shortMode} Auto #${randId}`;
  const now = new Date();
  const startTime = new Date(now.getTime() + 30 * 60 * 1000); // 30 mins later
  const cleanKey = gameName.toLowerCase().replace(/[^a-z0-9]/g, "_");
  const roomId = `auto_${cleanKey}_${Date.now()}_${randId}`;

  const roomData = {
    id: roomId,
    hostId: "admin_bot",
    hostName: "AI Gaming Bot",
    hostAvatar: "",
    gameName: gameName,
    gameType: gameName,
    gameMode: config.mode,
    roomType: config.mode,
    title: title,
    map: config.map,
    platform: "Cross-Platform",
    serverRegion: "Asia / India",
    rules: "Official Auto Room. Entry is FREE (Watch 1 Ad to Join). 500 Coins Escrow Prize Pool from Admin Wallet.",
    entryFee: "FREE (Watch 1 Ad to Join)",
    entryFeeCoins: 0,
    prize: "💰 500 Coins Prize",
    prizePool: "💰 500 Coins",
    prizePoolCoins: 500,
    escrowCoins: 500,
    status: "active",
    isLive: true,
    maxSlots: maxPlayers,
    totalSlots: maxPlayers,
    currentSlots: 0,
    slots: `0/${maxPlayers}`,
    joinedPlayers: [],
    joinedPlayerNames: {},
    roomId: `BOT-${randId}`,
    password: "",
    startTime: startTime,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  await db.collection("tournament_rooms").doc(roomId).set(roomData, { merge: true });
  console.log(`Auto-created room for ${gameName}: "${title}" (Max: ${maxPlayers}, Prize: 500 Coins)`);
  return roomData;
}

// Scheduled Cloud Function: runs every 15 minutes
exports.autoCreateMultiGameTournaments = onSchedule("every 15 minutes", async () => {
  const db = getFirestore();
  const currentMinute = new Date().getMinutes();
  const isHourly = currentMinute < 15; // Hourly execution window on the top of the hour

  console.log(`[AutoBot] Running autoCreateMultiGameTournaments (minute: ${currentMinute}, isHourly: ${isHourly})`);

  // 1. Every 15 minutes: Auto-create 1 room for Top 5 games
  for (const gameName of TOP_5_GAMES) {
    try {
      await createBotRoomForGame(db, gameName);
    } catch (err) {
      console.error(`Error auto-creating room for ${gameName}:`, err.message);
    }
  }

  // 2. Every 1 hour: Auto-create 1 room for other games
  if (isHourly) {
    for (const gameName of OTHER_GAMES) {
      try {
        await createBotRoomForGame(db, gameName);
      } catch (err) {
        console.error(`Error auto-creating room for ${gameName}:`, err.message);
      }
    }
  }

  console.log("[AutoBot] Finished auto-creating multi-game tournament rooms.");
});

// HTTP endpoint to manually trigger bot creation if needed
exports.autoCreateMultiGameTournamentsManual = onRequest(async (req, res) => {
  const db = getFirestore();
  const forceAll = req.query.all === "true";
  const gamesToRun = forceAll ? [...TOP_5_GAMES, ...OTHER_GAMES] : TOP_5_GAMES;
  const created = [];

  for (const game of gamesToRun) {
    try {
      const room = await createBotRoomForGame(db, game);
      created.push(room.title);
    } catch (e) {
      console.error(e);
    }
  }

  res.json({
    success: true,
    message: `Created ${created.length} auto rooms with 500 Coins Admin Escrow and FREE entry`,
    rooms: created,
  });
});


