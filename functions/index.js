const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const cheerio = require("cheerio");
admin.initializeApp();
const db = admin.firestore();

function cleanContent(text) {
  if (!text) return "";
  let cleaned = text;
  cleaned = cleaned.replace(/\[img\][^\[]*\[\/img\]/gi, "");
  cleaned = cleaned.replace(/\[url[^\]]*\](.*?)\[\/url\]/gi, "$1");
  cleaned = cleaned.replace(/\[b\](.*?)\[\/b\]/gi, "$1");
  cleaned = cleaned.replace(/\[i\](.*?)\[\/i\]/gi, "$1");
  cleaned = cleaned.replace(/\[list\](.*?)\[\/list\]/gis, "$1");
  cleaned = cleaned.replace(/\[\*\]/g, "\n• ");
  cleaned = cleaned.replace(/\[.*?\]/g, "");
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
    let content = $(".apphub_CardTextContent").text() || $(".announcement_body").text() || $("#js_announcement_body").text() || $("div.announcement").text();
    if (!content || content.trim().length < 100) {
      content = $("p").map((i, el) => $(el).text()).get().join("\n\n");
    }
    content = content.replace(/\s+/g, " ").trim();
    return content.length > 300? content.substring(0, 5000) : null;
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
      await new Promise(r => setTimeout(r, 300));
    }
    return fullTranslated || text;
  } catch (e) {
    console.log("Translate error", targetLang, e.message);
    return text;
  }
}

async function translateToRomanUrdu(text) {
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=ur&dt=t&dt=rm&q=${encodeURIComponent(text.substring(0,4000))}`;
    const res = await fetch(url);
    const data = await res.json();
    let urdu = "";
    let roman = "";
    if (data && data[0]) {
      urdu = data[0].map(x => x[0]).join('');
      try { roman = data[0].map(x => x[3] || "").join(''); } catch(e){ roman = urdu; }
    }
    if (!roman || roman.length < 5) roman = urdu;
    return { urdu, roman };
  } catch(e){ return { urdu: text, roman: text }; }
}

exports.fetchSteamNews = functions.pubsub.schedule("every 60 minutes").onRun(async (context) => {
  const apps = [570, 730, 578080, 1245620, 252490];
  for (const appId of apps) {
    try {
      const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=5`;
      const res = await fetch(url);
      const json = await res.json();
      const news = json.appnews? json.appnews.newsitems : [];
      for (const item of news) {
        const existingDoc = await db.collection('news').doc(item.gid).get();
        if (existingDoc.exists) continue;
        let titleEn = cleanContent(item.title);
        let contentEn = cleanContent(item.contents);
        if (contentEn.length < 500 && item.url) {
          const full = await getFullArticleFromSteamUrl(item.url);
          if (full && full.length > contentEn.length) {
            contentEn = cleanContent(full);
          }
        }
        if (contentEn.length < 50) continue;
        const { urdu: titleUr, roman: titleRoman } = await translateToRomanUrdu(titleEn);
        const { urdu: contentUr, roman: contentRoman } = await translateToRomanUrdu(contentEn);
        const titleHi = await translateText(titleEn, 'hi');
        const titleBn = await translateText(titleEn, 'bn');
        const titleAr = await translateText(titleEn, 'ar');
        const titleZh = await translateText(titleEn, 'zh-CN');
        const contentHi = await translateText(contentEn, 'hi');
        const contentBn = await translateText(contentEn, 'bn');
        const contentAr = await translateText(contentEn, 'ar');
        const contentZh = await translateText(contentEn, 'zh-CN');
        const titleMap = { en: titleEn, roman: titleRoman, ro: titleEn, hi: titleHi, ur: titleUr, bn: titleBn, ar: titleAr, zh: titleZh, "zh-cn": titleZh };
        const contentMap = { en: contentEn, roman: contentRoman, ro: contentEn, hi: contentHi, ur: contentUr, bn: contentBn, ar: contentAr, zh: contentZh, "zh-cn": contentZh };
        await db.collection('news').doc(item.gid).set({
          title: titleEn,
          description: contentEn,
          titleMap: titleMap,
          descriptionMap: contentMap,
          title_translations: titleMap,
          description_translations: contentMap,
          category: 'Gaming News',
          imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
          appId: appId,
          views: 0,
          isFeatured: false,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          sourceUrl: "",
          originalSourceUrl: item.url,
        }, { merge: true });
        await new Promise(r => setTimeout(r, 1000));
      }
    } catch (err) {
      console.log(`Error for app ${appId}`, err.message);
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  return null;
});