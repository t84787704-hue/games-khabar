
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const cheerio = require("cheerio");
admin.initializeApp();
const db = admin.firestore();

// BBCode + HTML Cleaner - app ke jaisa hi
function cleanContent(text) {
  if (!text) return "";
  let cleaned = text;
  // BBCode remove
  cleaned = cleaned.replace(/\[img\][^\[]*\[\/img\]/gi, "");
  cleaned = cleaned.replace(/\[url[^\]]*\](.*?)\[\/url\]/gi, "$1");
  cleaned = cleaned.replace(/\[b\](.*?)\[\/b\]/gi, "$1");
  cleaned = cleaned.replace(/\[i\](.*?)\[\/i\]/gi, "$1");
  cleaned = cleaned.replace(/\[list\](.*?)\[\/list\]/gis, "$1");
  cleaned = cleaned.replace(/\[\*\]/g, "\n• ");
  cleaned = cleaned.replace(/\[.*?\]/g, "");
  // URLs remove from description (taake app me bahar ka link na dikhe)
  cleaned = cleaned.replace(/https?:\/\/[^\s]+/g, "");
  cleaned = cleaned.replace(/www\.[^\s]+/g, "");
  cleaned = cleaned.replace(/\s+/g, " ").trim();
  return cleaned;
}

async function getFullArticleFromSteamUrl(steamUrl) {
  try {
    const res = await fetch(steamUrl, { timeout: 10000, headers: { "User-Agent": "Mozilla/5.0" } });
    const html = await res.text();
    const $ = cheerio.load(html);
    // Steam announcement page selectors
    let content = $(".apphub_CardTextContent").text() || $(".announcement_body").text() || $("#js_announcement_body").text() || $("div.announcement").text();
    if (!content || content.trim().length < 100) {
      // Fallback - get all paragraphs
      content = $("p").map((i, el) => $(el).text()).get().join("\n\n");
    }
    content = content.replace(/\s+/g, " ").trim();
    return content.length > 300 ? content.substring(0, 5000) : null;
  } catch (e) {
    console.log("Scrape error for", steamUrl, e.message);
    return null;
  }
}

async function translateText(text, targetLang) {
  if (!text || targetLang === 'en' || targetLang === 'roman' || targetLang === 'ro') return text;
  let code = targetLang;
  if (targetLang === 'zh' || targetLang === 'zh-cn') code = 'zh-CN';
  try {
    // Google free API has 5000 char limit, chunk it
    const chunks = [];
    let temp = text;
    while (temp.length > 0) {
      chunks.push(temp.substring(0, 4000));
      temp = temp.substring(4000);
    }
    let fullTranslated = "";
    for (const chunk of chunks) {
      const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${code}&dt=t&q=${encodeURIComponent(chunk)}`;
      const res = await fetch(url);
      const data = await res.json();
      if (data && data[0]) {
        fullTranslated += data[0].map(x => x[0]).join('');
      } else {
        fullTranslated += chunk;
      }
      // Thoda delay taake block na ho
      await new Promise(r => setTimeout(r, 300));
    }
    return fullTranslated || text;
  } catch (e) {
    console.log("Translate error", targetLang, e.message);
    return text;
  }
}

exports.fetchSteamNews = functions.pubsub.schedule("every 60 minutes").onRun(async (context) => {
  const apps = [570, 730, 578080, 1245620, 252490]; // Dota, CS, PUBG, etc
  for (const appId of apps) {
    try {
      const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=5`;
      const res = await fetch(url);
      const json = await res.json();
      const news = json.appnews ? json.appnews.newsitems : [];

      for (const item of news) {
        const existingDoc = await db.collection('news').doc(item.gid).get();
        if (existingDoc.exists) continue; // Duplicate skip

        let titleEn = cleanContent(item.title);
        let contentEn = cleanContent(item.contents);

        // Agar content short hai to full scrape karo
        if (contentEn.length < 500 && item.url) {
          const full = await getFullArticleFromSteamUrl(item.url);
          if (full && full.length > contentEn.length) {
            contentEn = cleanContent(full);
            console.log(`Full scraped for ${item.gid}, length ${contentEn.length}`);
          }
        }

        if (contentEn.length < 50) continue; // Bohat hi chota hai to skip

        // Translate to 7 languages
        const titleHi = await translateText(titleEn, 'hi');
        const titleUr = await translateText(titleEn, 'ur');
        const titleBn = await translateText(titleEn, 'bn');
        const titleAr = await translateText(titleEn, 'ar');
        const titleZh = await translateText(titleEn, 'zh-CN');

        const contentHi = await translateText(contentEn, 'hi');
        const contentUr = await translateText(contentEn, 'ur');
        const contentBn = await translateText(contentEn, 'bn');
        const contentAr = await translateText(contentEn, 'ar');
        const contentZh = await translateText(contentEn, 'zh-CN');

        const titleMap = {
          en: titleEn,
          roman: titleEn,
          ro: titleEn,
          hi: titleHi,
          ur: titleUr,
          bn: titleBn,
          ar: titleAr,
          zh: titleZh,
          "zh-cn": titleZh
        };

        const contentMap = {
          en: contentEn,
          roman: contentEn,
          ro: contentEn,
          hi: contentHi,
          ur: contentUr,
          bn: contentBn,
          ar: contentAr,
          zh: contentZh,
          "zh-cn": contentZh
        };

        await db.collection('news').doc(item.gid).set({
          title: titleEn,
          description: contentEn,
          titleMap: titleMap,
          descriptionMap: contentMap,
          title_translations: titleMap, // backward compatibility
          description_translations: contentMap,
          category: 'Gaming News',
          imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
          appId: appId,
          views: 0,
          isFeatured: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          sourceUrl: "", // Empty rakho taake app me button na aaye - agar chahiye to item.url daal do
          originalSourceUrl: item.url, // Backup ke liye
        }, { merge: true });

        console.log(`Saved news ${item.gid} - ${titleEn.substring(0, 50)}`);
        await new Promise(r => setTimeout(r, 1000)); // 1 sec delay between news
      }
    } catch (err) {
      console.log(`Error for app ${appId}`, err.message);
    }
    await new Promise(r => setTimeout(r, 2000)); // 2 sec delay between apps
  }
  return null;
});
