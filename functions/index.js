const functions = require("firebase-functions");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
admin.initializeApp();
const db = admin.firestore();

// Google Free Translate
async function translateText(text, targetLang) {
  if (!text || targetLang === 'en' || targetLang === 'roman' || targetLang === 'ro') return text;
  let code = targetLang;
  if (targetLang === 'zh' || targetLang === 'zh-cn') code = 'zh-CN';
  try {
    const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=${code}&dt=t&q=${encodeURIComponent(text.substring(0, 4000))}`;
    const res = await fetch(url);
    const data = await res.json();
    if (data && data[0]) {
      return data[0].map(x => x[0]).join('');
    }
    return text;
  } catch (e) {
    console.log("Translate error", e);
    return text;
  }
}

exports.fetchSteamNews = functions.pubsub.schedule("every 60 minutes").onRun(async (context) => {
  const apps = [570, 730, 578080, 1245620, 252490]; // Dota, CS, PUBG etc
  for (const appId of apps) {
    const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=5`;
    const res = await fetch(url);
    const json = await res.json();
    const news = json.appnews? json.appnews.newsitems : [];

    for (const item of news) {
      const titleEn = item.title;
      const contentEn = item.contents;

      // Sab languages me translate karo
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
        title: titleMap,
        content: contentMap,
        description: contentMap,
        category: 'Gaming News',
        imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
        appId: appId,
        views: 0,
        isFeatured: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        sourceUrl: item.url,
      }, { merge: true });
    }
  }
  return null;
});