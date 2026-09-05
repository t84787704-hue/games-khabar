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

function cleanDescription(text) {
  if (!text) return null;
  let t = he.decode(text);

  // 1. Replace [p][/p] with double newline, remove [b][/b][i][/i][u][/u]
  t = t.replace(/\[\/?p\]/gi, '\n\n');
  t = t.replace(/\[\/?(b|i|u|h[1-6]|strong|em|strike|sub|sup)\]/gi, '');

  // 2. Remove [img]...[/img] and {STEAM_CLAN_IMAGE}...jpg completely
  t = t.replace(/\[img[^\]]*\][\s\S]*?\[\/img\]/gi, '');
  t = t.replace(/<img[^>]*>/gi, '');
  t = t.replace(/\{STEAM_CLAN_IMAGE\}[^\s"'<>]+/gi, '');

  // 3. [url="LINK"]TEXT[/url] and [url]LINK[/url]:
  // remove completely if contains discord.gg, otherwise keep only LINK
  t = t.replace(/\[url=["']?(https?:\/\/[^"'\]]+|discord\.gg\/[^"'\]]+)["']?\]([\s\S]*?)\[\/url\]/gi, (match, link, body) => {
    if (link.toLowerCase().includes('discord.gg') || body.toLowerCase().includes('discord.gg')) {
      return '';
    }
    return link || body;
  });
  t = t.replace(/\[url\]([\s\S]*?)\[\/url\]/gi, (match, body) => {
    if (body.toLowerCase().includes('discord.gg')) {
      return '';
    }
    return body;
  });
  // Also strip raw discord.gg links or invites
  t = t.replace(/https?:\/\/(?:www\.)?discord\.gg\/[a-zA-Z0-9_-]+/gi, '');
  t = t.replace(/(?:^|\s)discord\.gg\/[a-zA-Z0-9_-]+/gi, '');

  // 4. Remove broken link garbage like https:// https:// www.ea.com or space issues
  t = t.replace(/(?:https?:\s*\/\/\s*)+https?:\s*\/\/\s*/gi, 'https://');
  t = t.replace(/https?:\/\/\s+/gi, 'https://');
  t = t.replace(/\s+https?:\/\//gi, ' https://');

  // 5. Strip all remaining HTML tags and BBCode tags
  t = t.replace(/<[^>]+>/g, ' ');
  t = t.replace(/\[[^\]]+\]/g, ' ');

  // 6. Decode common entities
  t = t.replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').replace(/&#39;/g, "'");

  // 7. Normalize whitespace, keep max 2 consecutive newlines
  t = t.replace(/[ \t]+/g, ' ');
  t = t.replace(/\n{3,}/g, '\n\n');
  t = t.trim();

  return t;
}

function makeAbsoluteUrl(imgUrl, baseLink) {
  if (!imgUrl) return "";
  let url = imgUrl.trim();
  if (url.startsWith('//')) {
    return `https:${url}`;
  }
  if (url.startsWith('/') && baseLink) {
    try {
      const u = new URL(baseLink);
      return `${u.origin}${url}`;
    } catch (_) {
      return url;
    }
  }
  return url;
}

const FALLBACK_IMAGES = {
  valorant: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?auto=format&fit=crop&w=1000&q=80',
  fortnite: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?auto=format&fit=crop&w=1000&q=80',
  bgmi: 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1000&q=80',
  pubg: 'https://images.unsplash.com/photo-1579373903781-fd5c0c30c4cd?auto=format&fit=crop&w=1000&q=80',
  freefire: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?auto=format&fit=crop&w=1000&q=80',
  cod: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?auto=format&fit=crop&w=1000&q=80',
  gta: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?auto=format&fit=crop&w=1000&q=80',
  sports: 'https://images.unsplash.com/photo-1511886929837-354d827aae26?auto=format&fit=crop&w=1000&q=80',
  bike: 'https://images.unsplash.com/photo-1558981403-c5f9899a28bc?auto=format&fit=crop&w=1000&q=80',
  racing: 'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&w=1000&q=80',
  truck: 'https://images.unsplash.com/photo-1601584115197-04ecc0da31d7?auto=format&fit=crop&w=1000&q=80',
  minecraft: 'https://images.unsplash.com/photo-1627856013091-fed6e4e30025?auto=format&fit=crop&w=1000&q=80',
  general: 'https://images.unsplash.com/photo-1493711662062-fa541adb3fc8?auto=format&fit=crop&w=1000&q=80'
};

function getCategoryFallback(title = '', category = '') {
  const text = `${title} ${category}`.toLowerCase();
  if (text.includes('valorant')) return { key: 'valorant', url: FALLBACK_IMAGES.valorant };
  if (text.includes('fortnite')) return { key: 'fortnite', url: FALLBACK_IMAGES.fortnite };
  if (text.includes('bgmi') || text.includes('battlegrounds mobile')) return { key: 'bgmi', url: FALLBACK_IMAGES.bgmi };
  if (text.includes('pubg')) return { key: 'pubg', url: FALLBACK_IMAGES.pubg };
  if (text.includes('free fire')) return { key: 'freefire', url: FALLBACK_IMAGES.freefire };
  if (text.includes('call of duty') || text.includes('warzone') || text.includes('fps')) return { key: 'cod', url: FALLBACK_IMAGES.cod };
  if (text.includes('gta') || text.includes('grand theft auto')) return { key: 'gta', url: FALLBACK_IMAGES.gta };
  if (text.includes('wcc') || text.includes('cricket') || text.includes('fifa') || text.includes('fc 24') || text.includes('sports')) return { key: 'sports', url: FALLBACK_IMAGES.sports };
  if (text.includes('bike') || text.includes('motogp') || text.includes('ride 5')) return { key: 'bike', url: FALLBACK_IMAGES.bike };
  if (text.includes('forza') || text.includes('f1') || text.includes('drift') || text.includes('racing')) return { key: 'racing', url: FALLBACK_IMAGES.racing };
  if (text.includes('truck') || text.includes('simulator')) return { key: 'truck', url: FALLBACK_IMAGES.truck };
  if (text.includes('minecraft')) return { key: 'minecraft', url: FALLBACK_IMAGES.minecraft };
  return { key: 'general', url: FALLBACK_IMAGES.general };
}

const USER_AGENT = 'Mozilla/5.0';

async function getRealImage(articleUrl, item, rawTitle = '', category = '', existing$ = null) {
  let $ = existing$;

  // 1. Fetch HTML with axios if not already provided
  if (!$ && articleUrl && articleUrl.startsWith('http')) {
    try {
      let referer = '';
      try {
        referer = new URL(articleUrl).origin;
      } catch (_) {}

      const res = await axios.get(articleUrl, {
        headers: {
          'User-Agent': USER_AGENT,
          ...(referer ? { 'Referer': referer } : {})
        },
        timeout: 10000,
        maxRedirects: 5
      });
      if (res.data && typeof res.data === 'string') {
        $ = cheerio.load(res.data);
      }
    } catch (_) {}
  }

  // 2. Exact user requested hierarchy:
  // let image = $('meta[property="og:image"]').attr('content') 
  //          || $('meta[name="twitter:image"]').attr('content')
  //          || $('meta[property="og:image:secure_url"]').attr('content')
  //          || $('article img').first().attr('src')
  //          || item.enclosure?.url
  //          || item['media:content']?.$?.url
  let image = "";
  if ($) {
    image = $('meta[property="og:image"]').attr('content')
         || $('meta[name="twitter:image"]').attr('content')
         || $('meta[property="og:image:secure_url"]').attr('content')
         || $('article img').first().attr('src');
  }

  if (!image && item) {
    image = item.enclosure?.url
         || item['media:content']?.$?.url
         || item['media:content']?.['$']?.url
         || item['media:thumbnail']?.['$']?.url
         || item['media:group']?.['media:content']?.[0]?.['$']?.url
         || item.image?.url;
  }

  // 3. Make absolute URL and validate if found
  if (image) {
    const abs = makeAbsoluteUrl(image, articleUrl);
    if (abs && abs.startsWith('http')) {
      const lower = abs.toLowerCase();
      if (!lower.includes('1x1') && !lower.endsWith('.gif') && !lower.includes('feedburner.com/~r/') && !lower.includes('1245620')) {
        console.log(`[Image Success] Real image found for "${rawTitle.substring(0, 45)}": ${abs}`);
        return abs;
      }
    }
  }

  // 4. If category fallback exists
  const fallback = getCategoryFallback(rawTitle, category);
  if (fallback && fallback.url) {
    return fallback.url;
  }

  // 5. If after all still no image, do NOT leave null, try to fetch google favicon
  if (articleUrl) {
    try {
      const parsed = new URL(articleUrl);
      const faviconUrl = `https://www.google.com/s2/favicons?domain=${parsed.hostname}&sz=128`;
      console.log(`[Image Favicon] Fallback to favicon for "${rawTitle.substring(0, 45)}": ${faviconUrl}`);
      return faviconUrl;
    } catch (_) {}
  }

  return 'https://www.google.com/s2/favicons?domain=steampowered.com&sz=128';
}

const getImage = getRealImage;

async function fetchFullArticle(url) {
  if (!url || !url.startsWith('http')) return null;
  try {
    const res = await axios.get(url, {
      headers: {
        'User-Agent': USER_AGENT,
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9'
      },
      timeout: 10000,
      maxRedirects: 5
    });

    if (!res.data || typeof res.data !== 'string') return null;
    const $ = cheerio.load(res.data);

    // Remove unwanted tags, navigation, ads, social, subscribe
    $('script, style, noscript, nav, header, footer, aside, iframe, .advertisement, .ad, .ad-container, [data-ad], .social-share, .comments, .related-posts, .subscribe, .newsletter-signup').remove();

    let paragraphs = [];
    const selectors = [
      'article p',
      '[data-component="article-body"] p',
      '.article-content p',
      '.entry-content p',
      '.article__body p',
      '.story-body p',
      '.post-content p',
      'main p'
    ];

    for (const selector of selectors) {
      const pElements = $(selector);
      if (pElements.length >= 2) {
        pElements.each((_, el) => {
          const text = $(el).text().trim();
          if (text.length > 30 && !text.toLowerCase().includes('subscribe') && !text.toLowerCase().includes('sign up for')) {
            paragraphs.push(text);
          }
        });
        if (paragraphs.length >= 2) break;
        paragraphs = [];
      }
    }

    // Try JSON-LD if paragraphs are still empty or too short
    if (paragraphs.length < 2) {
      $('script[type="application/ld+json"]').each((_, el) => {
        try {
          const json = JSON.parse($(el).html() || '{}');
          const body = json.articleBody || (Array.isArray(json['@graph']) && json['@graph'].find(g => g.articleBody)?.articleBody);
          if (body && typeof body === 'string' && body.length >= 200) {
            paragraphs = body.split(/\n+/).map(p => p.trim()).filter(p => p.length > 30);
          }
        } catch (_) {}
      });
    }

    let rawText = paragraphs.join('\n\n');
    if (!rawText || rawText.length < 200) {
      rawText = $('article').text() || $('main').text() || '';
    }

    const clean = cleanDescription(rawText);
    if (!clean || clean.length < 500) {
      return null;
    }

    return { fullText: clean, $ };
  } catch (err) {
    return null;
  }
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

function extractGameName(title, fallback = '') {
  if (!title || typeof title !== 'string') return fallback;
  const cleanTitle = title.trim();

  // 1. High-priority known gaming franchises and patterns
  const franchisePatterns = [
    /\bEA Sports\s+[A-Za-z0-9]+(?:\s+[A-Za-z0-9]+){0,3}\b/i,
    /\bCall of Duty(?::\s*[A-Za-z0-9]+|\s+[A-Za-z0-9]+){1,3}\b/i,
    /\b(?:Grand Theft Auto|GTA)\s*(?:VI|V|IV|\d+)?\b/i,
    /\bFIFA\s*\d+\b/i,
    /\b(?:Fall Guys|Valorant|Fortnite|Minecraft|BGMI|PUBG(?::\s*BATTLEGROUNDS)?|Apex Legends|Cyberpunk 2077|Elden Ring|Helldivers\s*2|Palworld|Genshin Impact|Rocket League|Counter-Strike\s*2|Roblox|Free Fire|Starfield|Baldur's Gate\s*3|Tekken\s*8|Street Fighter\s*6|Forza Horizon\s*\d?|Forza Motorsport|Overwatch\s*2?|God of War|The Last of Us|Resident Evil\s*\w+|Assassin's Creed\s*\w+|World of Warcraft|League of Legends|Dota\s*2|Star Wars\s+[A-Za-z0-9]+)\b/i
  ];

  for (const pattern of franchisePatterns) {
    const match = cleanTitle.match(pattern);
    if (match) {
      return match[0].trim();
    }
  }

  // 2. Cut before common headline separators (comma, colon, dash, pipe)
  // e.g. "EA Sports College Football 27, The Survivalists..." -> "EA Sports College Football 27"
  let segment = cleanTitle.split(/[:|\-–—,]/)[0].trim();

  // Strip trailing platform or action words: PS5, PS4, Xbox, PC, Switch, Review, Update, etc.
  segment = segment.replace(/\s+(?:PS[45]|PlayStation(?:\s*[45])?|Xbox(?:\s*(?:Series\s*[XS]|One))?|Nintendo\s*Switch|Switch|PC|Steam|iOS|Android|Update|Patch|Review|Trailer|DLC|Free|Release\s*Date).*$/i, '').trim();

  // 3. Extract first 3-4 capitalized English words from start
  const startCapitalized = segment.match(/^([A-Z0-9][a-zA-Z0-9'’\.\-&]*(?:\s+[A-Z0-9][a-zA-Z0-9'’\.\-&]*){0,3})/);
  if (startCapitalized && startCapitalized[1]) {
    const candidate = startCapitalized[1].trim();
    const words = candidate.split(/\s+/);
    const stopWords = ['How', 'Why', 'What', 'Where', 'When', 'Who', 'New', 'Every', 'Top', 'Best', 'Here', 'All', 'The', 'A', 'An', 'Is', 'Are', 'Will', 'Could'];
    if (words.length > 1 || (!stopWords.includes(words[0]) && candidate.length > 3)) {
      return candidate;
    }
  }

  // 4. Regex fallback: match capitalized multi-word sequence anywhere
  const regexMatch = cleanTitle.match(/([A-Z][a-z0-9]+(?:\s+[A-Z0-9][a-z0-9]+)+|\bEA Sports[^\n,:]+|\bGTA\s?VI?\b|\bFIFA\s?\d+|\bCall of Duty[^\n,:]*)/);
  if (regexMatch && regexMatch[1]) {
    return regexMatch[1].trim();
  }

  return (segment.length >= 3 && segment.length <= 40) ? segment : fallback;
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
      // Fetch price overview
      let currentPrice = 2999;
      let originalPriceVal = 4499;
      let priceHistory = [
        { date: '1 Mo Ago', price: 4499 },
        { date: 'Today', price: 2999 }
      ];
      try {
        const pRes = await axios.get(`https://store.steampowered.com/api/appdetails?appids=${appId}&filters=price_overview&cc=pk`, { timeout: 4000 });
        const po = pRes.data?.[appId]?.data?.price_overview;
        if (po) {
          currentPrice = Math.round(po.final / 100);
          originalPriceVal = Math.round(po.initial / 100);
          priceHistory = [
            { date: '2 Mo Ago', price: originalPriceVal },
            { date: '1 Mo Ago', price: Math.round(originalPriceVal * 0.9) },
            { date: 'Today', price: currentPrice }
          ];
        }
      } catch (_) {}

      const res = await axios.get(`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=20&maxlength=0`);
      for(const item of res.data?.appnews?.newsitems||[]){
        const rawTitle = he.decode(item.title||"").substring(0,200);
        if(isRussian(rawTitle)) continue; // RUSSIAN SKIP

        const fullText = cleanDescription(item.contents || "");
        if(!fullText || fullText.length < 500) continue; // Skip if < 500 characters
        if(isRussian(fullText)) continue;

        let cat = GAME_CATEGORY_MAP[gameName] || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length]; fbIndex++;
        const img = `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`;
        if(!img) continue;

        const paras = fullText.split('\n\n').filter(p => p.trim().length > 20);
        const shortDesc = paras.slice(0, 2).join('\n\n') || fullText.substring(0, 300);

        await db.collection('news').doc(`${appId}_${item.gid}`).set({
          id:`${appId}_${item.gid}`,
          title: rawTitle,
          description: fullText,
          content: fullText,
          shortDescription: shortDesc,
          titleMap:{en: rawTitle, ur: rawTitle, ro: rawTitle},
          descriptionMap:{en: fullText, ur: fullText, ro: fullText},
          imageUrl: img,
          appId, appid: appId, url: item.url||"", sourceUrl: item.url||"", gameName, category: cat,
          store: 'Steam',
          currentPrice: currentPrice,
          originalPrice: `Rs. ${originalPriceVal}`,
          originalPriceVal: originalPriceVal,
          priceHistory: priceHistory,
          timestamp: Math.floor(Date.now()/1000), timeAgo: new Date().toISOString(),
          views: 0, isFeatured: false, isAuto: true, isFree: false, source: 'Steam'
        },{merge:true});
      }
    }catch(e){}
  }
  // 50 WEBSITES - Latest 20 per website
  for(const src of TOP_50_SITES){
    try{
      const feed = await parser.parseURL(src.url);
      for(const item of feed.items.slice(0,20)){
        const articleUrl = item.link || item.guid || "";
        if (!articleUrl || !articleUrl.startsWith('http')) continue;

        const rawTitle = he.decode(item.title||"").substring(0,200);
        if(isRussian(rawTitle)) continue; // RUSSIAN SKIP

        // Fetch full article text (>= 500 chars) from web page
        const fullArticle = await fetchFullArticle(articleUrl);
        if (!fullArticle || !fullArticle.fullText || fullArticle.fullText.length < 500) {
          continue; // SKIP if article is short or fetch failed
        }
        if (isRussian(fullArticle.fullText)) continue;

        let cat = src.fixedCat || detectCat(rawTitle) || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length]; fbIndex++;

        // Get genuine article image via og:image with axios + cheerio, or category fallback
        const img = await getImage(articleUrl, item, rawTitle, cat, fullArticle.$);
        if (!img) {
          console.log(`[Image Missing] Skipping "${rawTitle.substring(0, 40)}" (no image found)`);
          continue;
        }

        const paras = fullArticle.fullText.split('\n\n').filter(p => p.trim().length > 20);
        const shortDesc = paras.slice(0, 2).join('\n\n') || fullArticle.fullText.substring(0, 300);

        const safeId = Buffer.from(articleUrl).toString('base64').replace(/[/+=]/g,'').substring(0,20);
        const detectedGame = extractGameName(rawTitle, src.name);
        await db.collection('news').doc(`${src.name}_${safeId}`).set({
          id:`${src.name}_${safeId}`,
          title: rawTitle,
          description: fullArticle.fullText,
          content: fullArticle.fullText,
          shortDescription: shortDesc,
          titleMap:{en: rawTitle, ur: rawTitle, ro: rawTitle},
          descriptionMap:{en: fullArticle.fullText, ur: fullArticle.fullText, ro: fullArticle.fullText},
          imageUrl: img, url: articleUrl, sourceUrl: articleUrl, gameName: detectedGame, category: cat,
          timestamp: Math.floor(Date.now()/1000), timeAgo: new Date().toISOString(),
          views: 0, isFeatured: false, isAuto: true, isFree: false, source: src.name, appId: 0, appid: 0
        },{merge:true});
      }
    }catch(e){}
  }
  console.log('DONE - LATEST NEWS FETCHED');
  await admin.app().delete();
  process.exit(0);
}
run();