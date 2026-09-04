const admin = require('firebase-admin');
const axios = require('axios');
const Parser = require('rss-parser');
const cheerio = require('cheerio');
const he = require('he');
const parser = new Parser({ customFields: { item: ['media:content', 'enclosure', 'media:thumbnail'] } });
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const APP_CATEGORIES = ['Racing Games','Driving Games','Simulator Games','Bike Games','Car Simulator','Truck Simulator','Battle Royale','FPS / Shooting','Action Games','Adventure Games','Survival Games','Sports Games','Strategy Games','Horror Games','Multiplayer Games','Offline Games'];
let fbIndex = 0;

// Duniya ki Top 50 Authentic Websites ke RSS
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
  { name: 'Game Informer', url: 'https://www.gameinformer.com/rss.xml' },
  { name: 'Rock Paper Shotgun', url: 'https://www.rockpapershotgun.com/feed' },
  { name: 'PCGamesN', url: 'https://www.pcgamesn.com/mainrss.xml' },
  { name: 'Shacknews', url: 'https://www.shacknews.com/rss' },
  { name: 'DualShockers', url: 'https://www.dualshockers.com/feed/' },
  { name: 'Game Rant', url: 'https://gamerant.com/feed/' },
  { name: 'The Gamer', url: 'https://www.thegamer.com/feed/' },
  { name: 'Push Square', url: 'https://www.pushsquare.com/feeds/latest' },
  { name: 'Pure Xbox', url: 'https://www.purexbox.com/feeds/latest' },
  { name: 'Nintendo Life', url: 'https://www.nintendolife.com/feeds/latest' },
  { name: 'Nintendo Everything', url: 'https://nintendoeverything.com/feed/' },
  { name: 'PlayStation Blog', url: 'https://blog.playstation.com/feed/' },
  { name: 'Xbox Wire', url: 'https://news.xbox.com/en-us/feed/' },
  { name: 'Siliconera', url: 'https://www.siliconera.com/feed/' },
  { name: 'Gematsu', url: 'https://www.gematsu.com/feed' },
  { name: 'Niche Gamer', url: 'https://nichegamer.com/feed/' },
  { name: 'GamingBolt', url: 'https://gamingbolt.com/feed' },
  { name: 'MP1st', url: 'https://mp1st.com/feed' },
  { name: 'GamesIndustry', url: 'https://www.gamesindustry.biz/feed' },
  { name: 'Dot Esports', url: 'https://dotesports.com/feed' },
  { name: 'Dexerto', url: 'https://www.dexerto.com/gaming/feed/' },
  { name: 'Screen Rant', url: 'https://screenrant.com/feed/gaming/' },
  { name: 'ComicBook Gaming', url: 'https://comicbook.com/gaming/feed/' },
  { name: 'Wccftech Gaming', url: 'https://wccftech.com/category/gaming/feed/' },
  { name: 'TouchArcade', url: 'https://toucharcade.com/feed/' },
  { name: 'Pocket Gamer', url: 'https://www.pocketgamer.com/rss/' },
  { name: 'One Esports', url: 'https://www.oneesports.gg/feed/' },
  { name: 'Hardcore Gamer', url: 'https://www.hardcoregamer.com/feed/' },
  { name: 'Ubisoft News', url: 'https://news.ubisoft.com/en-us/feed' },
  { name: 'Rockstar Newswire', url: 'https://www.rockstargames.com/newswire/feed' },
  // Famous Games ke liye Authentic Google News Sources
  { name: 'Free Fire', url: 'https://news.google.com/rss/search?q=Garena+Free+Fire+MAX&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Battle Royale' },
  { name: 'PUBG Mobile', url: 'https://news.google.com/rss/search?q=PUBG+Mobile+BGMI&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Battle Royale' },
  { name: 'Fortnite', url: 'https://news.google.com/rss/search?q=Fortnite+Epic+Games&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Battle Royale' },
  { name: 'Valorant', url: 'https://news.google.com/rss/search?q=Valorant+Riot+Games&hl=en-US&gl=US&ceid=US:en', fixedCat: 'FPS / Shooting' },
  { name: 'Call of Duty', url: 'https://news.google.com/rss/search?q=Call+of+Duty+Warzone+Mobile&hl=en-US&gl=US&ceid=US:en', fixedCat: 'FPS / Shooting' },
  { name: 'GTA 6', url: 'https://news.google.com/rss/search?q=GTA+6+Grand+Theft+Auto+6&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Action Games' },
  { name: 'WCC3', url: 'https://news.google.com/rss/search?q=WCC3+World+Cricket+Championship+game&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Sports Games' },
  { name: 'FIFA FC24', url: 'https://news.google.com/rss/search?q=EA+FC+24+FIFA+news&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Sports Games' },
  { name: 'Jedi Survivor', url: 'https://news.google.com/rss/search?q=Star+Wars+Jedi+Survivor&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Adventure Games' },
  { name: 'Minecraft', url: 'https://news.google.com/rss/search?q=Minecraft+update&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Survival Games' },
  { name: 'Bike Racing', url: 'https://news.google.com/rss/search?q=MotoGP+Ride+5+bike+racing+game&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Bike Games' },
  { name: 'Car Simulator', url: 'https://news.google.com/rss/search?q=Forza+Horizon+Car+Simulator+game&hl=en-US&gl=US&ceid=US:en', fixedCat: 'Car Simulator' },
];

function clean(t){ if(!t) return ""; return he.decode(t).replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim(); }
function getImage(item){
  if(item.enclosure?.url) return item.enclosure.url;
  if(item['media:content']?.['$']?.url) return item['media:content']['$'].url;
  const m = item.content?.match(/<img[^>]+src="([^">]+)"/); if(m) return m[1];
  return `https://cdn.akamai.steamstatic.com/steam/apps/1245620/header.jpg`;
}
// Puri khabar nikalne ka function
async function getFullArticle(url){
  try{
    const {data} = await axios.get(url,{headers:{'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36','Accept-Language':'en-US,en;q=0.9'},timeout:20000});
    const $ = cheerio.load(data);
    $('script,style,nav,footer,iframe,aside,.ad,.advertisement').remove();
    let txt=""; const selectors = ['article p','[data-component="text-block"] p','.article-body p','.entry-content p','.post-content p','.story-body p','.article-content p','main p','.content p'];
    for(const sel of selectors){ $(sel).each((i,el)=>{ let p=$(el).text().trim(); if(p.length>50 && !p.toLowerCase().includes('subscribe') && !p.toLowerCase().includes('cookie')) txt+=p+"\n\n"; }); if(txt.length>500) break; }
    if(txt.length<300){ $('p').each((i,el)=>{ let p=$(el).text().trim(); if(p.length>60) txt+=p+"\n\n"; }); }
    return txt.length>300 ? clean(txt).substring(0,8000) : null;
  }catch(e){ return null; }
}
function detectCat(title){
  const t=title.toLowerCase();
  if(t.includes('free fire')||t.includes('pubg')||t.includes('fortnite')||t.includes('battle royale')) return 'Battle Royale';
  if(t.includes('wcc')||t.includes('cricket')||t.includes('fifa')||t.includes('fc 24')||t.includes('nba')||t.includes('wwe')) return 'Sports Games';
  if(t.includes('jedi')||t.includes('gta 6')||t.includes('witcher')||t.includes('red dead')) return 'Adventure Games';
  if(t.includes('bike')||t.includes('motogp')) return 'Bike Games';
  if(t.includes('truck')) return 'Truck Simulator';
  if(t.includes('car')&&t.includes('simulator')) return 'Car Simulator';
  if(t.includes('valorant')||t.includes('call of duty')||t.includes('counter')||t.includes('fps')||t.includes('shooting')) return 'FPS / Shooting';
  if(t.includes('racing')||t.includes('forza')||t.includes('f1')) return 'Racing Games';
  if(t.includes('driving')||t.includes('beamng')) return 'Driving Games';
  if(t.includes('horror')||t.includes('resident evil')||t.includes('phasmophobia')) return 'Horror Games';
  if(t.includes('survival')||t.includes('minecraft')||t.includes('rust')||t.includes('ark')) return 'Survival Games';
  if(t.includes('strategy')||t.includes('cities skylines')) return 'Strategy Games';
  if(t.includes('simulator')) return 'Simulator Games';
  return null;
}

async function run(){
  for(const src of TOP_50_SITES){
    try{
      const feed = await parser.parseURL(src.url);
      for(const item of feed.items.slice(0,4)){
        let full = await getFullArticle(item.link);
        if(!full) full = clean(item.contentSnippet||item.content||item.summary||"");
        if(full.length<150) continue;
        let cat = src.fixedCat || detectCat(item.title||"") || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length]; fbIndex++;
        const safeId = Buffer.from(item.link||item.title||"").toString('base64').replace(/[/+=]/g,'').substring(0,25);
        await db.collection('news').doc(`${src.name}_${safeId}`).set({
          id:`${src.name}_${safeId}`, title:he.decode(item.title||""), description:full,
          titleMap:{en:he.decode(item.title||""),ur:he.decode(item.title||""),ro:he.decode(item.title||"")},
          descriptionMap:{en:full,ur:full,ro:full}, imageUrl:getImage(item), url:item.link||"", sourceUrl:item.link||"",
          gameName:src.name, category:cat, timestamp:Math.floor(new Date(item.pubDate||Date.now()).getTime()/1000),
          timeAgo:new Date().toISOString(), views:0, isFeatured:true, isAuto:true, source:src.name
        },{merge:true});
      }
      console.log(`OK ${src.name} - ${feed.items.length} news`);
    }catch(e){ console.log(`FAIL ${src.name}`); }
    await new Promise(r=>setTimeout(r,800));
  }
  console.log('DONE - TOP 50 AUTHENTIC WEBSITES FULL NEWS FETCHED');
}
run();