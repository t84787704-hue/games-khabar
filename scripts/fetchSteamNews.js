const admin = require('firebase-admin');
const axios = require('axios');
const Parser = require('rss-parser');
const parser = new Parser({
  customFields: { item: ['media:content', 'media:thumbnail', 'enclosure'] }
});

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

// Steam Games (tumhari purani list)
const allGamesAppIds = {
  'Forza Horizon 5': 1551360, 'Euro Truck Simulator 2': 227300,
  'American Truck Simulator': 270880, 'Assetto Corsa': 244210,
  'BeamNG.drive': 284160, 'CarX Drift Racing': 635260,
  'GTA 5': 271590, 'Red Dead Redemption 2': 1174180,
  'Cyberpunk 2077': 1091500, 'Elden Ring': 1245620,
  'The Witcher 3': 292030, 'Rust': 252490,
  'Farming Simulator 22': 1248130, 'PowerWash Simulator': 1290000,
  'PUBG': 578080, 'Apex Legends': 1172470,
  'Counter Strike 2': 730, 'Call of Duty': 2519060,
  'Cities Skylines': 255710, 'Palworld': 1623730,
};

// Top Authentic Websites ke RSS
const RSS_SOURCES = [
  { name: 'IGN', url: 'https://feeds.feedburner.com/ign/games-all', category: 'Gaming News' },
  { name: 'GameSpot', url: 'https://www.gamespot.com/feeds/mashup/', category: 'Gaming News' },
  { name: 'PC Gamer', url: 'https://www.pcgamer.com/rss/', category: 'PC Games' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/feed', category: 'Gaming News' },
  { name: 'Polygon', url: 'https://www.polygon.com/rss/index.xml', category: 'Gaming News' },
  { name: 'GamesRadar', url: 'https://www.gamesradar.com/rss/', category: 'Gaming News' },
  { name: 'Kotaku', url: 'https://kotaku.com/rss', category: 'Gaming News' },
  { name: 'VG247', url: 'https://www.vg247.com/feed', category: 'Gaming News' },
  { name: 'Destructoid', url: 'https://www.destructoid.com/feed/', category: 'Gaming News' },
  { name: 'PlayStation Blog', url: 'https://blog.playstation.com/feed/', category: 'PlayStation' },
  { name: 'Xbox Wire', url: 'https://news.xbox.com/en-us/feed/', category: 'Xbox' },
];

function cleanHtml(text) {
  if (!text) return "";
  return text.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim();
}
function detectCategory(text) {
  text = text.toLowerCase();
  if (text.includes('truck') || text.includes('simulator')) return 'Simulator Games';
  if (text.includes('forza') || text.includes('racing')) return 'Driving Games';
  if (text.includes('gta') || text.includes('red dead')) return 'Open World';
  if (text.includes('playstation') || text.includes('ps5')) return 'PlayStation';
  if (text.includes('xbox')) return 'Xbox';
  return 'Gaming News';
}
function getImage(item) {
  if (item.enclosure && item.enclosure.url) return item.enclosure.url;
  if (item['media:content'] && item['media:content']['$'] && item['media:content']['$'].url) return item['media:content']['$'].url;
  if (item['media:thumbnail'] && item['media:thumbnail']['$']) return item['media:thumbnail']['$'].url;
  const match = item.content ? item.content.match(/<img[^>]+src="([^">]+)"/) : null;
  if (match) return match[1];
  return `https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg`;
}

async function fetchSteam() {
  console.log('Fetching Steam...');
  for (const [gameName, appId] of Object.entries(allGamesAppIds)) {
    try {
      const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=2&maxlength=0`;
      const res = await axios.get(url);
      const items = res.data?.appnews?.newsitems || [];
      for (const item of items) {
        const fullDesc = cleanHtml(item.contents || "");
        const title = item.title || "";
        const docId = `${appId}_${item.gid}`;
        await db.collection('news').doc(docId).set({
          id: docId, title: title, description: fullDesc,
          titleMap: { en: title, ur: title, ro: title },
          descriptionMap: { en: fullDesc, ur: fullDesc, ro: fullDesc },
          imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
          appid: appId, appId: appId, url: item.url || "", sourceUrl: item.url || "",
          gameName: gameName, category: detectCategory(title + ' ' + fullDesc),
          timestamp: item.date || Math.floor(Date.now()/1000),
          timeAgo: new Date().toISOString(), views: 0,
          isFeatured: false, isAuto: true, isFree: false, videoUrl: null, source: 'Steam'
        }, { merge: true });
        console.log(`Saved Steam: ${gameName}`);
      }
    } catch (e) { console.log(`Skip Steam ${gameName}`); }
    await new Promise(r => setTimeout(r, 1500));
  }
}

async function fetchRSS() {
  console.log('Fetching Top Websites...');
  for (const src of RSS_SOURCES) {
    try {
      const feed = await parser.parseURL(src.url);
      const items = feed.items.slice(0, 4);
      for (const item of items) {
        const title = item.title || "";
        const desc = cleanHtml(item.contentSnippet || item.content || "");
        const safeId = Buffer.from(item.link).toString('base64').replace(/[/+=]/g, '').substring(0, 20);
        const docId = `${src.name}_${safeId}`;
        await db.collection('news').doc(docId).set({
          id: docId, title: title, description: desc,
          titleMap: { en: title, ur: title, ro: title },
          descriptionMap: { en: desc, ur: desc, ro: desc },
          imageUrl: getImage(item),
          url: item.link || "", sourceUrl: item.link || "",
          gameName: src.name, category: src.category,
          timestamp: Math.floor(new Date(item.pubDate || Date.now()).getTime() / 1000),
          timeAgo: new Date(item.pubDate || Date.now()).toISOString(),
          views: 0, isFeatured: true, isAuto: true, isFree: false, videoUrl: null, source: src.name
        }, { merge: true });
        console.log(`Saved ${src.name}: ${title.substring(0,30)}`);
      }
    } catch (e) { console.log(`Skip ${src.name}: ${e.message}`); }
    await new Promise(r => setTimeout(r, 1500));
  }
}

(async () => {
  await fetchSteam();
  await fetchRSS();
  console.log('DONE - All sources fetched');
})();