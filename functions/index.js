const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onRequest} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const axios = require("axios");

initializeApp();

const GAMES = [
  {appid: 1938090, name: "Call of Duty MW3", category: "Action Games"},
  {appid: 1623730, name: "Palworld", category: "Simulator Games"},
  {appid: 1172470, name: "Apex Legends", category: "Action Games"},
  {appid: 570, name: "Dota 2", category: "Action Games"},
  {appid: 578080, name: "PUBG", category: "Action Games"},
];

async function fetchAndSaveFullNews() {
  const db = getFirestore();
  console.log("Fetching FULL news start...");

  for (const game of GAMES) {
    try {
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
          appid: game.appid,
          url: item.url,
          views: Math.floor(Math.random() * 500) + 20,
          timestamp: item.date,
          timeAgo: new Date(item.date * 1000).toISOString(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
      }
    } catch (err) {
      console.error(`Error ${game.name}`, err.message);
    }
  }
  return "Full News Updated";
}

exports.fetchGamingNews = onSchedule("every 6 hours", async () => {
  await fetchAndSaveFullNews();
});

exports.fetchNewsManual = onRequest(async (req, res) => {
  const msg = await fetchAndSaveFullNews();
  res.send(msg);
});