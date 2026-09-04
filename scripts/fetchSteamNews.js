const admin = require('firebase-admin');
const axios = require('axios');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

const allGamesAppIds = {
  'Forza Horizon 5': 1551360,
  'Euro Truck Simulator 2': 227300,
  'American Truck Simulator': 270880,
  'Assetto Corsa': 244210,
  'BeamNG.drive': 284160,
  'CarX Drift Racing': 635260,
  'GTA 5': 271590,
  'Red Dead Redemption 2': 1174180,
  'Cyberpunk 2077': 1091500,
  'Elden Ring': 1245620,
  'The Witcher 3': 292030,
  'Rust': 252490,
  'Farming Simulator 22': 1248130,
  'PowerWash Simulator': 1290000,
  'PUBG': 578080,
  'Apex Legends': 1172470,
  'Counter Strike 2': 730,
  'Call of Duty': 2519060,
  'Cities Skylines': 255710,
  'Palworld': 1623730,
};

function detectCategory(text) {
  text = text.toLowerCase();
  if (text.includes('truck') || text.includes('simulator') || text.includes('farming')) return 'Simulator Games';
  if (text.includes('forza') || text.includes('drift') || text.includes('racing') || text.includes('assetto')) return 'Driving Games';
  if (text.includes('gta') || text.includes('red dead') || text.includes('witcher') || text.includes('open world')) return 'Open World';
  return 'Action Games';
}

async function fetchAll() {
  console.log('Fetching started for', Object.keys(allGamesAppIds).length, 'games');
  let total = 0;
  
  for (const [gameName, appId] of Object.entries(allGamesAppIds)) {
    try {
      // YAHAN maxlength=0 ADD KIYA HAI TAKE PURI NEWS AAYE
      const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=3&maxlength=0`;
      const res = await axios.get(url);
      const items = res.data?.appnews?.newsitems || [];
      
      for (const item of items) {
        const fullDesc = item.contents || "";
        const title = item.title || "";
        const docId = `${appId}_${item.gid}`;

        await db.collection('news').doc(docId).set({
          id: docId,
          title: title,
          description: fullDesc,
          titleMap: { en: title, ur: title, ro: title },
          descriptionMap: { en: fullDesc, ur: fullDesc, ro: fullDesc },
          imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
          appid: appId,
          appId: appId,
          url: item.url || "",
          sourceUrl: item.url || "",
          gameName: gameName,
          category: detectCategory(title + ' ' + fullDesc),
          timestamp: item.date || Math.floor(Date.now()/1000),
          timeAgo: new Date().toISOString(),
          views: 0,
          isFeatured: false,
          isAuto: true,
          isFree: false,
          videoUrl: null,
        }, { merge: true });
        
        total++;
        console.log(`Saved: ${gameName} - ${title}`);
      }
    } catch (e) {
      console.log(`Skip ${gameName}: ${e.message}`);
    }
    await new Promise(r => setTimeout(r, 2000));
  }
  console.log(`Done! Total ${total} news saved`);
}

fetchAll();