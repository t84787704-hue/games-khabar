const admin = require('firebase-admin');
const axios = require('axios');
const Parser = require('rss-parser');
const cheerio = require('cheerio');
const he = require('he');

const parser = new Parser({ customFields: { item: ['media:content', 'media:thumbnail', 'enclosure'] } });
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

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

// App ke exact naam
const APP_CATEGORIES = ['Racing Games','Driving Games','Simulator Games','Bike Games','Car Simulator','Truck Simulator','Battle Royale','FPS / Shooting','Action Games','Adventure Games','Survival Games','Sports Games','Strategy Games','Horror Games','Multiplayer Games','Offline Games'];
let fallbackIndex = 0;

const GAME_CATEGORY_MAP = {
  'Forza Horizon 5': 'Racing Games', 'CarX Drift Racing': 'Racing Games', 'Assetto Corsa': 'Racing Games',
  'BeamNG.drive': 'Driving Games', 'Euro Truck Simulator 2': 'Truck Simulator', 'American Truck Simulator': 'Truck Simulator',
  'Farming Simulator 22': 'Simulator Games', 'PowerWash Simulator': 'Simulator Games',
  'PUBG': 'Battle Royale', 'Apex Legends': 'Battle Royale',
  'Counter Strike 2': 'FPS / Shooting', 'Call of Duty': 'FPS / Shooting',
  'GTA 5': 'Action Games', 'Cyberpunk 2077': 'Action Games', 'Elden Ring': 'Action Games',
  'Red Dead Redemption 2': 'Adventure Games', 'The Witcher 3': 'Adventure Games',
  'Rust': 'Survival Games', 'Palworld': 'Survival Games',
  'Cities Skylines': 'Strategy Games'
};

const RSS_SOURCES = [
  { name: 'IGN', url: 'https://feeds.feedburner.com/ign/games-all' },
  { name: 'GameSpot', url: 'https://www.gamespot.com/feeds/mashup/' },
  { name: 'PC Gamer', url: 'https://www.pcgamer.com/rss/' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/feed' },
  { name: 'Polygon', url: 'https://www.polygon.com/rss/index.xml' },
  { name: 'GamesRadar', url: 'https://www.gamesradar.com/rss/' },
  { name: 'Kotaku', url: 'https://kotaku.com/rss' },
  { name: 'VG247', url: 'https://www.vg247.com/feed' },
  { name: 'Destructoid', url: 'https://www.destructoid.com/feed/' },
];

function cleanHtml(text){ if(!text) return ""; return he.decode(text).replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim(); }
function getImage(item){
  if(item.enclosure?.url) return item.enclosure.url;
  if(item['media:content']?.['$']?.url) return item['media:content']['$'].url;
  const m = item.content?.match(/<img[^>]+src="([^">]+)"/); if(m) return m[1];
  return `https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg`;
}
async function getFullArticle(url){
  try{
    const {data} = await axios.get(url,{headers:{'User-Agent':'Mozilla/5.0'},timeout:15000});
    const $ = cheerio.load(data); let txt="";
    $('article p,.entry-content p,.post-content p').each((i,el)=>{ let p=$(el).text().trim(); if(p.length>40) txt+=p+"\n\n"; });
    if(txt.length>300) return txt.substring(0,5000); return null;
  }catch(e){ return null; }
}

function detectCategory(title, gameName){
  const t = (title+" "+gameName).toLowerCase();
  if(t.includes('bike')||t.includes('moto')||t.includes('ride')) return 'Bike Games';
  if(t.includes('truck')) return 'Truck Simulator';
  if(t.includes('car simulator')||t.includes('carx')) return 'Car Simulator';
  if(t.includes('battle royale')||t.includes('pubg')||t.includes('fortnite')||t.includes('apex')) return 'Battle Royale';
  if(t.includes('fps')||t.includes('shooting')||t.includes('shooter')||t.includes('call of duty')||t.includes('counter strike')||t.includes('valorant')||t.includes('cs2')) return 'FPS / Shooting';
  if(t.includes('racing')||t.includes('forza')||t.includes('f1')||t.includes('need for speed')) return 'Racing Games';
  if(t.includes('driving')||t.includes('beamng')) return 'Driving Games';
  if(t.includes('simulator')) return 'Simulator Games';
  if(t.includes('horror')||t.includes('resident evil')||t.includes('phasmophobia')) return 'Horror Games';
  if(t.includes('strategy')||t.includes('cities skylines')||t.includes('civilization')) return 'Strategy Games';
  if(t.includes('sport')||t.includes('fifa')||t.includes('football')||t.includes('fc 24')||t.includes('nba')) return 'Sports Games';
  if(t.includes('survival')||t.includes('rust')||t.includes('palworld')||t.includes('ark')) return 'Survival Games';
  if(t.includes('multiplayer')) return 'Multiplayer Games';
  if(t.includes('offline')) return 'Offline Games';
  if(t.includes('action')) return 'Action Games';
  if(t.includes('adventure')||t.includes('gta')||t.includes('red dead')||t.includes('witcher')) return 'Adventure Games';
  return null;
}

async function fetchSteam(){
  for(const [gameName, appId] of Object.entries(allGamesAppIds)){
    try{
      const res = await axios.get(`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=2&maxlength=0`);
      for(const item of res.data?.appnews?.newsitems||[]){
        const fullDesc = cleanHtml(item.contents||""); const title = he.decode(item.title||"");
        let cat = detectCategory(title, gameName) || GAME_CATEGORY_MAP[gameName] || APP_CATEGORIES[fallbackIndex % APP_CATEGORIES.length]; fallbackIndex++;
        await db.collection('news').doc(`${appId}_${item.gid}`).set({
          id:`${appId}_${item.gid}`, title, description: fullDesc,
          titleMap:{en:title,ur:title,ro:title}, descriptionMap:{en:fullDesc,ur:fullDesc,ro:fullDesc},
          imageUrl:`https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
          appid:appId, appId, url:item.url||"", sourceUrl:item.url||"", gameName, category:cat,
          timestamp:item.date||Math.floor(Date.now()/1000), timeAgo:new Date().toISOString(), views:0, isFeatured:false, isAuto:true, source:'Steam'
        },{merge:true});
      }
    }catch(e){} await new Promise(r=>setTimeout(r,700));
  }
}

async function fetchRSS(){
  for(const src of RSS_SOURCES){
    try{
      const feed = await parser.parseURL(src.url);
      for(const item of feed.items.slice(0,4)){
        let fullText = await getFullArticle(item.link); if(!fullText) fullText = cleanHtml(item.contentSnippet||item.content||"");
        let cat = detectCategory(item.title||"", "");
        if(!cat){ cat = APP_CATEGORIES[fallbackIndex % APP_CATEGORIES.length]; fallbackIndex++; }
        const safeId = Buffer.from(item.link||"").toString('base64').replace(/[/+=]/g,'').substring(0,20);
        await db.collection('news').doc(`${src.name}_${safeId}`).set({
          id:`${src.name}_${safeId}`, title:he.decode(item.title||""), description:fullText,
          titleMap:{en:he.decode(item.title||""),ur:he.decode(item.title||""),ro:he.decode(item.title||"")},
          descriptionMap:{en:fullText,ur:fullText,ro:fullText},
          imageUrl:getImage(item), url:item.link||"", sourceUrl:item.link||"", gameName:src.name, category:cat,
          timestamp:Math.floor(new Date(item.pubDate||Date.now()).getTime()/1000),
          timeAgo:new Date().toISOString(), views:0, isFeatured:true, isAuto:true, source:src.name
        },{merge:true});
      }
    }catch(e){} await new Promise(r=>setTimeout(r,700));
  }
}
(async()=>{ await fetchSteam(); await fetchRSS(); console.log('DONE ALL CATEGORIES FIXED'); })();