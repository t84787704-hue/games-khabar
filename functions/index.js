const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
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
  console.log("Fetching FULL news for all games...");

  for (const game of GAMES) {
    try {
      // Yahan &maxlength=0 ka matlab hai PURI NEWS DO, aadhi nahi
      const apiUrl = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${game.appid}&count=10&maxlength=0&format=json`;
      const response = await axios.get(apiUrl);
      const newsItems = response.data?.appnews?.newsitems || [];

      for (const item of newsItems) {
        let fullContent = item.contents || "";
        // [b] jaise tags saaf karo, content ko kaato mat
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
          appid: game.appid,
          url: item.url,
          views: Math.floor(Math.random() * 500) + 20,
          timestamp: item.date,
          timeAgo: new Date(item.date * 1000).toISOString(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
      console.log(`Full news saved for ${game.name}`);
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
