const admin = require('firebase-admin');
const axios = require('axios');
const Parser = require('rss-parser');
const cheerio = require('cheerio');
const he = require('he');

const parser = new Parser({ customFields: { item: ['media:content', 'enclosure'] } });

// Firebase
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const APP_CATEGORIES = ['Racing Games','Driving Games','Simulator Games','Bike Games','Car Simulator','Truck Simulator','Battle Royale','FPS / Shooting','Action Games','Adventure Games','Survival Games','Sports Games','Strategy Games','Horror Games','Multiplayer Games','Offline Games'];
let fbIndex = 0;

// RUSSIAN FILTER - ye naya hai
function isRussian(text){
  if(!text) return false;
  return /[а-яА-ЯёЁ]/.test(text);
}

// 1. STEAM GAMES
const allGamesAppIds = {
  'Forza Horizon 5': 1551360, 'Euro Truck Simulator 2': 227300, 'American Truck Simulator': 270880,
  'BeamNG.drive': 284160, 'Assetto Corsa': 244210, 'CarX Drift': 635260, 'GTA 5': 271590,
  'Red Dead Redemption 2': 1174180, 'Cyberpunk 2077': 1091500, 'Elden Ring': 1245620,
  'The Witcher 3': 292030, 'Rust': 252490, 'PUBG': 578080, 'Counter Strike 2': 730,
  'Apex Legends': 1172470, 'Call of Duty': 2519060, 'Palworld': 1623730, 'Phasmophobia': 739630,
  'Star Wars Jedi Survivor': 1774580, 'FC 24': 2195250, 'Forza Motorsport': 2440510, 'F1 23': 2108330
};

const GAME_CATEGORY_MAP = {
  'Forza Horizon 5': 'Racing Games', 'CarX Drift': 'Racing Games', 'Forza Motorsport': 'Racing Games', 'F1 23': 'Racing Games',
  'BeamNG.drive': 'Driving Games', 'Assetto Corsa': 'Driving Games',
  'Euro Truck Simulator 2': 'Truck Simulator', 'American Truck Simulator': 'Truck Simulator',
  'PUBG': 'Battle Royale', 'Apex Legends': 'Battle Royale',
  'Counter Strike 2': 'FPS / Shooting', 'Call of Duty': 'FPS / Shooting',
  'GTA 5': 'Action Games', 'Cyberpunk 2077': 'Action Games', 'Elden Ring': 'Action Games',
  'Star Wars Jedi Survivor': 'Adventure Games', 'The Witcher 3': 'Adventure Games',
  'Rust': 'Survival Games', 'Palworld': 'Survival Games',
  'Phasmophobia': 'Horror Games', 'FC 24': 'Sports Games'
};

// 2. TOP 50 WEBSITES
const TOP_50_SITES = [
  { name: 'IGN', url: 'https://feeds.feedburner.com/ign/games-all' },
  { name: 'GameSpot', url: 'https://www.gamespot.com/feeds/mashup/' },
  { name: 'PC Gamer', url: 'https://www.pcgamer.com/rss/' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/feed' },
  { name: 'Polygon', url: 'https://www.polygon.com/rss/index.xml' },
  { name: 'GamesRadar', url: 'https://www.gamesradar.com/rss/' },
  { name: 'Kotaku', url: 'https://kotaku.com/rss' },
  { name: 'VG247', url: 'https://www.vg247.com/feed' },
  { name: 'Destructoid', url: 'https://www.destructoid.com/feed/' },
  { name: 'Rock Paper Shotgun', url: 'https://www.rockpapershotgun.com/feed' },
  { name: 'PCGamesN', url: 'https://www.pcgamesn.com/mainrss.xml' },
  { name: 'Game Rant', url: 'https://gamerant.com/feed/' },
  { name: 'Push Square', url: 'https://www.pushsquare.com/feeds/latest' },
  { name: 'Nintendo Life', url: 'https://www.nintendolife.com/feeds/latest' },
  { name: 'PlayStation Blog', url: 'https://blog.playstation.com/feed/' },
  { name: 'Xbox Wire', url: 'https://news.xbox.com/en-us/feed/' },
  { name: 'Gematsu', url: 'https://www.gematsu.com/feed' },
  { name: 'GamingBolt', url: 'https://gamingbolt.com/feed' },
  { name: 'Free Fire', url: 'https://news.google.com/rss/search?q=Garena+Free+Fire+MAX&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Battle Royale' },
  { name: 'PUBG Mobile', url: 'https://news.google.com/rss/search?q=PUBG+Mobile+BGMI&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Battle Royale' },
  { name: 'Fortnite', url: 'https://news.google.com/rss/search?q=Fortnite+Epic+Games&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Battle Royale' },
  { name: 'Valorant', url: 'https://news.google.com/rss/search?q=Valorant+Riot+Games&hl=en-US&gl=US&ceid=US:en', fixedCat: 'FPS / Shooting' },
  { name: 'GTA 6', url: 'https://news.google.com/rss/search?q=GTA+6+Grand+Theft+Auto+6&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Action Games' },
  { name: 'WCC3', url: 'https://news.google.com/rss/search?q=WCC3+World+Cricket+Championship+game&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Sports Games' },
  { name: 'FIFA FC24', url: 'https://news.google.com/rss/search?q=EA+FC+24+game&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Sports Games' },
  { name: 'Jedi Survivor', url: 'https://news.google.com/rss/search?q=Star+Wars+Jedi+Survivor&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Adventure Games' },
  { name: 'Minecraft', url: 'https://news.google.com/rss/search?q=Minecraft+game+update&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Survival Games' },
  { name: 'Bike Racing', url: 'https://news.google.com/rss/search?q=MotoGP+Ride+5+bike+game&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Bike Games' },
];

function cleanText(dirty){
  if(!dirty) return "";
  let t = he.decode(dirty);
  t = t.replace(/\[img\][\s\S]*?\[\/img\]/gi, '').replace(/<img[^>]*>/gi, '').replace(/<[^>]*>/g,' ');
  return t.replace(/\s+/g,' ').trim().substring(0,7000);
}
function getImage(item){
  if(item.enclosure?.url) return item.enclosure.url;
  if(item['media:content']?.['$']?.url) return item['media:content']['$'].url;
  const m = item.content?.match(/<img[^>]+src="([^">]+)"/); if(m) return m[1];
  return `https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg`;
}
function detectCat(title){
  const t=title.toLowerCase();
  if(t.includes('free fire')||t.includes('pubg')||t.includes('fortnite')) return 'Battle Royale';
  if(t.includes('wcc')||t.includes('cricket')||t.includes('fifa')||t.includes('fc 24')) return 'Sports Games';
  if(t.includes('jedi')||t.includes('gta')) return 'Adventure Games';
  if(t.includes('bike')||t.includes('motogp')) return 'Bike Games';
  if(t.includes('truck')) return 'Truck Simulator';
  if(t.includes('valorant')||t.includes('call of duty')) return 'FPS / Shooting';
  if(t.includes('racing')||t.includes('forza')||t.includes('f1')) return 'Racing Games';
  return null;
}

async function run(){
  console.log('START FETCH - LATEST NEWS');

  // STEP 0 - PURANI RUSSIAN DELETE KARO
  try{
    const snap = await db.collection('news').get();
    let del = 0;
    for(const doc of snap.docs){
      const title = doc.data().title || doc.data().titleMap?.en || "";
      if(isRussian(title)){
        await doc.ref.delete();
        del++;
      }
    }
    console.log(`Cleaned ${del} Russian old docs`);
  }catch(e){ console.log("Clean fail", e.message); }

  // STEAM - Latest 20 per game
  for(const [gameName, appId] of Object.entries(allGamesAppIds)){
    try{
      const res = await axios.get(`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=20&maxlength=0`);
      for(const item of res.data?.appnews?.newsitems||[]){
        const rawTitle = he.decode(item.title||"").substring(0,200);
        if(isRussian(rawTitle)) continue; // RUSSIAN SKIP
        let desc = cleanText(item.contents||"");
        if(desc.length<40) continue;
        if(isRussian(desc)) continue;

        let cat = GAME_CATEGORY_MAP[gameName] || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length]; fbIndex++;
        await db.collection('news').doc(`${appId}_${item.gid}`).set({
          id:`${appId}_${item.gid}`, title: rawTitle, description: desc,
          titleMap:{en: rawTitle, ur: rawTitle, ro: rawTitle},
          descriptionMap:{en: desc, ur: desc, ro: desc},
          imageUrl:`https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
          appId, appid: appId, url: item.url||"", sourceUrl: item.url||"", gameName, category: cat,
          timestamp: Math.floor(Date.now()/1000), timeAgo: new Date().toISOString(),
          views: 0, isFeatured: true, isAuto: true, isFree: false, source: 'Steam'
        },{merge:true});
      }
    }catch(e){}
  }
  // 50 WEBSITES - Latest 20 per website
  for(const src of TOP_50_SITES){
    try{
      const feed = await parser.parseURL(src.url);
      for(const item of feed.items.slice(0,20)){
        const rawTitle = he.decode(item.title||"").substring(0,200);
        if(isRussian(rawTitle)) continue; // RUSSIAN SKIP
        let full = cleanText(item.contentSnippet||item.content||"");
        if(full.length<60) continue;
        if(isRussian(full)) continue;

        let cat = src.fixedCat || detectCat(item.title||"") || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length]; fbIndex++;
        const safeId = Buffer.from(item.link||"").toString('base64').replace(/[/+=]/g,'').substring(0,20);
        await db.collection('news').doc(`${src.name}_${safeId}`).set({
          id:`${src.name}_${safeId}`, title: rawTitle, description: full,
          titleMap:{en: rawTitle, ur: rawTitle, ro: rawTitle},
          descriptionMap:{en: full, ur: full, ro: full},
          imageUrl: getImage(item), url: item.link||"", sourceUrl: item.link||"", gameName: src.name, category: cat,
          timestamp: Math.floor(Date.now()/1000), timeAgo: new Date().toISOString(),
          views: 0, isFeatured: true, isAuto: true, isFree: false, source: src.name, appId: 0, appid: 0
        },{merge:true});
      }
    }catch(e){}
  }
  console.log('DONE - LATEST NEWS FETCHED');
  await admin.app().delete();
  process.exit(0);
}
run();