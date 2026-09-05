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

