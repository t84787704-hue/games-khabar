require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');
const axios = require('axios');
const Parser = require('rss-parser');
const cheerio = require('cheerio');
const he = require('he');
const crypto = require('crypto');

function stringToUuid(str) {
  const hash = crypto.createHash('md5').update(String(str)).digest('hex');
  return `${hash.substring(0, 8)}-${hash.substring(8, 12)}-${hash.substring(12, 16)}-${hash.substring(16, 20)}-${hash.substring(20, 32)}`;
}

const parser = new Parser({ customFields: { item: ['media:content', 'enclosure'] } });

const SUPABASE_URL = (process.env.SUPABASE_URL && process.env.SUPABASE_URL.trim() !== '')
  ? process.env.SUPABASE_URL.trim()
  : 'https://dxdkitnroypbblazblja.supabase.co';

const SUPABASE_SERVICE_KEY = (process.env.SUPABASE_SERVICE_KEY && process.env.SUPABASE_SERVICE_KEY.trim() !== '')
  ? process.env.SUPABASE_SERVICE_KEY.trim()
  : ((process.env.SUPABASE_KEY && process.env.SUPABASE_KEY.trim() !== '')
      ? process.env.SUPABASE_KEY.trim()
      : 'sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y');

if (!SUPABASE_SERVICE_KEY) {
  console.error('SUPABASE_SERVICE_KEY is missing. Please set it in your .env or environment.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const APP_CATEGORIES = ['Racing Games','Driving Games','Simulator Games','Bike Games','Car Simulator','Truck Simulator','Battle Royale','FPS / Shooting','Action Games','Adventure Games','Survival Games','Sports Games','Strategy Games','Horror Games','Multiplayer Games','Offline Games'];
let fbIndex = 0;

// RUSSIAN FILTER
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

// 2. TOP 50 GAMING WEBSITES & MAJOR SOURCES
const TOP_50_SITES = [
  { name: 'IGN', url: 'https://feeds.feedburner.com/ign/games-all', cat: 'Action Games' },
  { name: 'GameSpot', url: 'https://www.gamespot.com/feeds/mashup/', cat: 'Action Games' },
  { name: 'PC Gamer', url: 'https://www.pcgamer.com/rss/', cat: 'FPS / Shooting' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/feed', cat: 'Adventure Games' },
  { name: 'Polygon', url: 'https://www.polygon.com/rss/index.xml', cat: 'Adventure Games' },
  { name: 'GamesRadar', url: 'https://www.gamesradar.com/rss/', cat: 'Action Games' },
  { name: 'Kotaku', url: 'https://kotaku.com/rss', cat: 'Action Games' },
  { name: 'VG247', url: 'https://www.vg247.com/feed', cat: 'Action Games' },
  { name: 'Destructoid', url: 'https://www.destructoid.com/feed/', cat: 'Action Games' },
  { name: 'Rock Paper Shotgun', url: 'https://www.rockpapershotgun.com/feed', cat: 'Action Games' },
  { name: 'PCGamesN', url: 'https://www.pcgamesn.com/mainrss.xml', cat: 'FPS / Shooting' },
  { name: 'Game Rant', url: 'https://gamerant.com/feed/', cat: 'Action Games' },
  { name: 'Push Square', url: 'https://www.pushsquare.com/feeds/latest', cat: 'Action Games' },
  { name: 'Nintendo Life', url: 'https://www.nintendolife.com/feeds/latest', cat: 'Adventure Games' },
  { name: 'PlayStation Blog', url: 'https://blog.playstation.com/feed/', cat: 'Action Games' },
  { name: 'Xbox Wire', url: 'https://news.xbox.com/en-us/feed/', cat: 'Action Games' },
  { name: 'Gematsu', url: 'https://www.gematsu.com/feed', cat: 'Adventure Games' },
  { name: 'GamingBolt', url: 'https://gamingbolt.com/feed', cat: 'Action Games' },
  { name: 'DualShockers', url: 'https://www.dualshockers.com/feed/', cat: 'Action Games' },
  { name: 'Pure Xbox', url: 'https://www.purexbox.com/feeds/latest', cat: 'Action Games' },
  { name: 'Siliconera', url: 'https://www.siliconera.com/feed/', cat: 'Adventure Games' },
  { name: 'Video Games Chronicle', url: 'https://www.videogameschronicle.com/feed/', cat: 'Action Games' },
  { name: 'Attack of the Fanboy', url: 'https://attackofthefanboy.com/feed/', cat: 'Action Games' },
  { name: 'TheGamer', url: 'https://www.thegamer.com/feed/', cat: 'Action Games' },
  { name: 'Dexerto', url: 'https://www.dexerto.com/feed/', cat: 'Multiplayer Games' },
  { name: 'Dot Esports', url: 'https://dotesports.com/feed', cat: 'Multiplayer Games' },
  { name: 'Pocket Gamer', url: 'https://www.pocketgamer.com/rss/', cat: 'Multiplayer Games' },
  { name: 'Droid Gamers', url: 'https://www.droidgamers.com/feed/', cat: 'Multiplayer Games' },
  { name: 'TouchArcade', url: 'https://toucharcade.com/feed/', cat: 'Multiplayer Games' },
  { name: 'Screen Rant Gaming', url: 'https://screenrant.com/feed/gaming/', cat: 'Action Games' },
  { name: 'Traxion.GG', url: 'https://traxion.gg/feed/', fixedCat: 'Truck Simulator' },
  { name: 'GamingonPhone', url: 'https://gamingonphone.com/feed/', fixedCat: 'Battle Royale' },
  { name: 'Pocket Tactics', url: 'https://www.pockettactics.com/feed', fixedCat: 'Multiplayer Games' },
  { name: 'Charlie Intel', url: 'https://charlieintel.com/feed/', fixedCat: 'FPS / Shooting' },
  { name: 'Esports Insider', url: 'https://esportsinsider.com/feed/', fixedCat: 'Multiplayer Games' },
  { name: 'VG247', url: 'https://www.vg247.com/feed', fixedCat: 'Action Games' },
  { name: 'Eurogamer', url: 'https://www.eurogamer.net/feed', fixedCat: 'Action Games' },
  { name: 'OverTake Racing', url: 'https://www.overtake.gg/news/feed/', fixedCat: 'Racing Games' }
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

  // 3. Remove discord links
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
  t = t.replace(/https?:\/\/(?:www\.)?discord\.gg\/[a-zA-Z0-9_-]+/gi, '');
  t = t.replace(/(?:^|\s)discord\.gg\/[a-zA-Z0-9_-]+/gi, '');

  // 4. Remove broken link garbage
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

async function translateToUrdu(text) {
  if (!text || typeof text !== 'string') return '';
  const clean = text.trim();
  if (!clean) return '';
  if (/[\u0600-\u06FF]/.test(clean)) return clean;
  try {
    const cleanChunk = clean.substring(0, 400);
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ur&dt=t&q=${encodeURIComponent(cleanChunk)}`;
    const res = await axios.get(url, {
      timeout: 2000,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0 Safari/537.36'
      }
    });
    if (res.data && Array.isArray(res.data[0])) {
      const trans = res.data[0].map(item => item[0]).join('').trim();
      if (trans && /[\u0600-\u06FF]/.test(trans)) {
        return trans;
      }
    }
  } catch (_) {}
  return clean;
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

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

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
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Sec-Ch-Ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
          'Sec-Ch-Ua-Mobile': '?0',
          'Sec-Ch-Ua-Platform': '"Windows"',
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

  let image = "";
  if ($) {
    image = $('meta[property="og:image"]').attr('content')
         || $('meta[content][property="og:image"]').attr('content')
         || $('meta[name="twitter:image"]').attr('content')
         || $('meta[content][name="twitter:image"]').attr('content')
         || $('meta[property="og:image:url"]').attr('content')
         || $('meta[property="og:image:secure_url"]').attr('content')
         || $('meta[name="twitter:image:src"]').attr('content')
         || $('meta[itemprop="image"]').attr('content')
         || $('link[rel="image_src"]').attr('href')
         || $('article img').first().attr('src')
         || $('.featured-image img, .post-thumbnail img, main img').first().attr('src');

    if (!image) {
      $('script[type="application/ld+json"]').each((_, el) => {
        try {
          const json = JSON.parse($(el).html() || '{}');
          const imgObj = json.image || (Array.isArray(json['@graph']) && json['@graph'].find(g => g.image)?.image);
          if (typeof imgObj === 'string' && imgObj.startsWith('http')) {
            image = imgObj;
          } else if (imgObj && typeof imgObj === 'object') {
            const candidate = imgObj.url || (Array.isArray(imgObj) && imgObj[0]?.url) || (Array.isArray(imgObj) && typeof imgObj[0] === 'string' ? imgObj[0] : null);
            if (candidate && candidate.startsWith('http')) {
              image = candidate;
            }
          }
        } catch (_) {}
      });
    }
  }

  if (!image && item) {
    image = item.enclosure?.url
         || item['media:content']?.$?.url
         || item['media:content']?.['$']?.url
         || item['media:thumbnail']?.['$']?.url
         || item['media:group']?.['media:content']?.[0]?.['$']?.url
         || item.image?.url;
  }

  if (image) {
    const abs = makeAbsoluteUrl(image, articleUrl);
    if (abs && abs.startsWith('http')) {
      const lower = abs.toLowerCase();
      const isBadImage = lower.includes('1x1') ||
        lower.endsWith('.gif') ||
        lower.includes('feedburner.com/~r/') ||
        lower.includes('1245620') ||
        lower.includes('google') ||
        lower.includes('gstatic') ||
        lower.includes('favicon') ||
        lower.includes('logo') ||
        lower.includes('unsplash.com');

      if (!isBadImage) {
        console.log(`[Image Success] Real image found for "${rawTitle.substring(0, 45)}": ${abs}`);
        return abs;
      }
    }
  }

  const fallback = getCategoryFallback(rawTitle, category);
  if (fallback && fallback.url) {
    return fallback.url;
  }

  return FALLBACK_IMAGES.general;
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
      timeout: 8000,
      maxRedirects: 5
    });

    if (!res.data || typeof res.data !== 'string') return null;
    const $ = cheerio.load(res.data);

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
    if (!clean || clean.length < 200) {
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

  let segment = cleanTitle.split(/[:|\-–—,]/)[0].trim();
  segment = segment.replace(/\s+(?:PS[45]|PlayStation(?:\s*[45])?|Xbox(?:\s*(?:Series\s*[XS]|One))?|Nintendo\s*Switch|Switch|PC|Steam|iOS|Android|Update|Patch|Review|Trailer|DLC|Free|Release\s*Date).*$/i, '').trim();

  const startCapitalized = segment.match(/^([A-Z0-9][a-zA-Z0-9'’\.\-&]*(?:\s+[A-Z0-9][a-zA-Z0-9'’\.\-&]*){0,3})/);
  if (startCapitalized && startCapitalized[1]) {
    const candidate = startCapitalized[1].trim();
    const words = candidate.split(/\s+/);
    const stopWords = ['How', 'Why', 'What', 'Where', 'When', 'Who', 'New', 'Every', 'Top', 'Best', 'Here', 'All', 'The', 'A', 'An', 'Is', 'Are', 'Will', 'Could'];
    if (words.length > 1 || (!stopWords.includes(words[0]) && candidate.length > 3)) {
      return candidate;
    }
  }

  const regexMatch = cleanTitle.match(/([A-Z][a-z0-9]+(?:\s+[A-Z0-9][a-z0-9]+)+|\bEA Sports[^\n,:]+|\bGTA\s?VI?\b|\bFIFA\s?\d+|\bCall of Duty[^\n,:]*)/);
  if (regexMatch && regexMatch[1]) {
    return regexMatch[1].trim();
  }

  return (segment.length >= 3 && segment.length <= 40) ? segment : fallback;
}

function extractPublishedDate(item, articleUrl, cheerioDoc) {
  if (item) {
    if (item.isoDate) {
      const d = new Date(item.isoDate);
      if (!isNaN(d.getTime())) return d;
    }
    if (item.pubDate) {
      const d = new Date(item.pubDate);
      if (!isNaN(d.getTime())) return d;
    }
    if (item.date) {
      const ts = typeof item.date === 'number' ? item.date : parseInt(item.date);
      if (!isNaN(ts) && ts > 0) {
        return new Date(ts > 10000000000 ? ts : ts * 1000);
      }
    }
  }

  if (cheerioDoc) {
    const metaDate = cheerioDoc('meta[property="article:published_time"]').attr('content') ||
      cheerioDoc('meta[name="article:published_time"]').attr('content') ||
      cheerioDoc('meta[property="og:published_time"]').attr('content') ||
      cheerioDoc('meta[name="pubdate"]').attr('content') ||
      cheerioDoc('meta[name="publish-date"]').attr('content') ||
      cheerioDoc('time[datetime]').attr('datetime');
    if (metaDate) {
      const d = new Date(metaDate);
      if (!isNaN(d.getTime())) return d;
    }
  }

  if (articleUrl) {
    const match = articleUrl.match(/\/(\d{4})\/(\d{1,2})\/(\d{1,2})\b/);
    if (match) {
      const y = parseInt(match[1]);
      const m = parseInt(match[2]) - 1;
      const d = parseInt(match[3]);
      const date = new Date(Date.UTC(y, m, d, 12, 0, 0));
      if (!isNaN(date.getTime())) return date;
    }
    const matchMonth = articleUrl.match(/\/(\d{4})\/(\d{1,2})\b/);
    if (matchMonth) {
      const y = parseInt(matchMonth[1]);
      const m = parseInt(matchMonth[2]) - 1;
      const date = new Date(Date.UTC(y, m, 15, 12, 0, 0));
      if (!isNaN(date.getTime())) return date;
    }
  }

  return new Date();
}

async function run(){
  console.log('START FETCH - STEAM NEWS TO SUPABASE');

  const existingIds = new Set();
  // STEP 0 - PURANI RUSSIAN DELETE KARO & LOAD EXISTING IDS FROM SUPABASE
  try {
    const { data: snap } = await supabase.from('steam_news').select('id, title, titleMap');
    let del = 0;
    if (snap) {
      for (const row of snap) {
        if (row.id) existingIds.add(String(row.id));
        const title = row.title || row.titleMap?.en || "";
        if (isRussian(title)) {
          await supabase.from('steam_news').delete().eq('id', row.id);
          existingIds.delete(String(row.id));
          del++;
        }
      }
    }
    console.log(`Loaded ${existingIds.size} existing articles from Supabase (Cleaned ${del} Russian).`);
  } catch(e) {
    console.log("Clean fail", e.message);
  }

  // STEP 0.5 - REPAIR EXISTING ARTICLES WITH GENERIC / UNSPLASH IMAGES
  try {
    const { data: unsplashRows } = await supabase
      .from('steam_news')
      .select('id, title, url, sourceUrl, imageUrl, image_url')
      .or('image_url.like.*unsplash.com*,imageUrl.like.*unsplash.com*')
      .limit(100);

    if (unsplashRows && unsplashRows.length > 0) {
      console.log(`Repairing ${unsplashRows.length} articles with generic Unsplash images...`);
      for (const row of unsplashRows) {
        const targetUrl = row.url || row.sourceUrl;
        if (!targetUrl || !targetUrl.startsWith('http')) continue;
        try {
          const realImg = await getRealImage(targetUrl, null, row.title || '');
          if (realImg && !realImg.includes('unsplash.com')) {
            console.log(`[Repaired Real Image] for ${row.id}: ${realImg}`);
            await supabase.from('steam_news').update({
              imageUrl: realImg,
              image_url: realImg
            }).eq('id', row.id);
          }
        } catch (_) {}
      }
    }
  } catch (err) {
    console.warn("Unsplash repair warning:", err.message);
  }

  // STEP 0.6 - REPAIR DATES FOR EXISTING ARTICLES IN SUPABASE
  try {
    const { data: dateRows } = await supabase
      .from('steam_news')
      .select('id, url, sourceUrl, created_at, published_at')
      .order('id', { ascending: false })
      .limit(200);

    if (dateRows && dateRows.length > 0) {
      for (const row of dateRows) {
        const targetUrl = row.url || row.sourceUrl;
        if (!targetUrl) continue;
        const match = targetUrl.match(/\/(\d{4})\/(\d{1,2})\/(\d{1,2})\b/);
        if (match) {
          const y = parseInt(match[1]);
          const m = parseInt(match[2]) - 1;
          const d = parseInt(match[3]);
          const realDate = new Date(Date.UTC(y, m, d, 12, 0, 0));
          const realIso = realDate.toISOString();
          if (row.published_at !== realIso) {
            await supabase.from('steam_news').update({
              published_at: realIso,
              created_at: realIso,
              timeAgo: realIso,
              timestamp: Math.floor(realDate.getTime() / 1000)
            }).eq('id', row.id);
          }
        }
      }
    }
  } catch (err) {
    console.warn("Date repair warning:", err.message);
  }

  // STEAM - Latest 5 per game (only fetch new)
  for (const [gameName, appId] of Object.entries(allGamesAppIds)) {
    try {
      let currentPrice = 2999;
      let originalPriceVal = 4499;
      let priceHistory = [
        { date: '1 Mo Ago', price: 4499 },
        { date: 'Today', price: 2999 }
      ];
      try {
        const pRes = await axios.get(`https://store.steampowered.com/api/appdetails?appids=${appId}&filters=price_overview&cc=pk`, { timeout: 3000 });
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

      const res = await axios.get(`https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=6&maxlength=0`, { timeout: 4000 });
      for (const item of (res.data?.appnews?.newsitems || []).slice(0, 5)) {
        const rawId = `steam_${appId}_${item.gid}`;
        const uuidId = stringToUuid(rawId);
        if (existingIds.has(uuidId)) {
          continue; // Already in Supabase, skip to save time
        }

        const rawTitle = he.decode(item.title || "").substring(0, 200);
        if (isRussian(rawTitle)) continue;

        const fullText = cleanDescription(item.contents || "");
        if (!fullText || fullText.length < 500) continue;
        if (isRussian(fullText)) continue;

        let cat = GAME_CATEGORY_MAP[gameName] || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length];
        fbIndex++;
        const img = `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`;
        if (!img) continue;

        const paras = fullText.split('\n\n').filter(p => p.trim().length > 20);
        const steamDate = item.date ? new Date((typeof item.date === 'number' ? item.date : parseInt(item.date)) * 1000) : new Date();
        const steamIso = steamDate.toISOString();
        const steamTs = item.date ? parseInt(item.date) : Math.floor(steamDate.getTime() / 1000);

        const urduTitle = await translateToUrdu(rawTitle);
        const urduDesc = await translateToUrdu(shortDesc || fullText.substring(0, 300));

        const newsPayload = {
          id: uuidId,
          title: (urduTitle && urduTitle.length > 5) ? urduTitle : rawTitle,
          description: fullText,
          shortDescription: shortDesc,
          titleMap: { en: rawTitle, ur: urduTitle || rawTitle, ro: rawTitle },
          descriptionMap: { en: fullText, ur: urduDesc || fullText, ro: fullText },
          imageUrl: img,
          image_url: img,
          created_at: steamIso,
          published_at: steamIso,
          appId,
          appid: appId,
          url: item.url || "",
          sourceUrl: item.url || "",
          gameName,
          category: cat,
          store: 'Steam',
          currentPrice: currentPrice,
          originalPrice: `Rs. ${originalPriceVal}`,
          originalPriceVal: originalPriceVal,
          priceHistory: priceHistory,
          timestamp: steamTs,
          timeAgo: steamIso,
          views: 0,
          isFeatured: false,
          isAuto: true,
          isFree: false,
          source: 'Steam'
        };

        const { error: insErr } = await supabase.from('steam_news').upsert(newsPayload, { onConflict: 'id' });
        if (insErr) {
          console.warn(`steam_news upsert warning (${newsPayload.id}): ${insErr.message}`);
        } else {
          existingIds.add(uuidId);
        }
      }
    } catch(e) {
      console.warn(`Error processing game ${gameName}: ${e.message}`);
    }
  }

  // 50 WEBSITES - Latest 4 per website (skip existing)
  for (const src of TOP_50_SITES) {
    try {
      const feed = await parser.parseURL(src.url);
      for (const item of feed.items.slice(0, 4)) {
        const articleUrl = item.link || item.guid || "";
        if (!articleUrl || !articleUrl.startsWith('http')) continue;

        const uuidId = stringToUuid(`${src.name}_${articleUrl}`);
        if (existingIds.has(uuidId)) {
          continue; // Already in Supabase, skip to save time
        }

        const rawTitle = he.decode(item.title || "").substring(0, 200);
        if (isRussian(rawTitle)) continue;

        let articleBody = null;
        let cheerioDoc = null;

        const fullArticle = await fetchFullArticle(articleUrl);
        if (fullArticle && fullArticle.fullText && fullArticle.fullText.length >= 200) {
          articleBody = fullArticle.fullText;
          cheerioDoc = fullArticle.$;
        } else {
          const rssRaw = item['content:encoded'] || item.content || item.contentSnippet || item.summary || item.description || "";
          const rssCleaned = cleanDescription(rssRaw);
          if (rssCleaned && rssCleaned.length >= 80) {
            articleBody = rssCleaned;
          }
        }

        if (!articleBody || articleBody.length < 80) {
          continue;
        }
        if (isRussian(articleBody)) continue;

        let cat = src.fixedCat || detectCat(rawTitle) || APP_CATEGORIES[fbIndex % APP_CATEGORIES.length];
        fbIndex++;

        const img = await getImage(articleUrl, item, rawTitle, cat, cheerioDoc);
        if (!img) continue;

        const paras = articleBody.split('\n\n').filter(p => p.trim().length > 20);
        const shortDesc = paras.slice(0, 2).join('\n\n') || articleBody.substring(0, 300);

        const detectedGame = extractGameName(rawTitle, src.name);
        const pubDate = extractPublishedDate(item, articleUrl, cheerioDoc);
        const pubIso = pubDate.toISOString();
        const pubTimestamp = Math.floor(pubDate.getTime() / 1000);

        const urduTitle = await translateToUrdu(rawTitle);
        const urduDesc = await translateToUrdu(shortDesc || articleBody.substring(0, 300));

        const newsPayload = {
          id: uuidId,
          title: (urduTitle && urduTitle.length > 5) ? urduTitle : rawTitle,
          description: articleBody,
          shortDescription: shortDesc,
          titleMap: { en: rawTitle, ur: urduTitle || rawTitle, ro: rawTitle },
          descriptionMap: { en: articleBody, ur: urduDesc || articleBody, ro: articleBody },
          imageUrl: img,
          image_url: img,
          created_at: pubIso,
          published_at: pubIso,
          url: articleUrl,
          sourceUrl: articleUrl,
          gameName: detectedGame,
          category: cat,
          timestamp: pubTimestamp,
          timeAgo: pubIso,
          views: 0,
          isFeatured: false,
          isAuto: true,
          isFree: false,
          source: src.name,
          appId: 0,
          appid: 0
        };

        const { error: insErr } = await supabase.from('steam_news').upsert(newsPayload, { onConflict: 'id' });
        if (insErr) {
          console.warn(`steam_news upsert warning (${newsPayload.id}): ${insErr.message}`);
        } else {
          existingIds.add(uuidId);
        }
      }
    } catch(e) {
      console.warn(`Error processing site ${src.name}: ${e.message}`);
    }
  }

  console.log('DONE - STEAM NEWS FETCHED TO SUPABASE');
  process.exit(0);
}

run();