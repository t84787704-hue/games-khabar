const admin = require('firebase-admin');
const axios = require('axios');

// Firebase Admin init - GitHub Secret se
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
      const url = `https://api.steampowered.com/ISteamNews/GetNewsForApp/v2/?appid=${appId}&count=3`;
      const res = await axios.get(url);
      const items = res.data?.appnews?.newsitems || [];
      
      for (const item of items) {
        // Duplicate check - pehle se hai to skip
        const existing = await db.collection('news').where('sourceUrl', '==', item.url).limit(1).get();
        if (!existing.empty) continue;

        await db.collection('news').add({
          title: item.title,
          content: item.contents,
          sourceUrl: item.url,
          gameName: gameName,
          category: detectCategory(item.title + ' ' + item.contents),
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          source: 'Steam',
          appId: appId,
          isVideo: false,
          imageUrl: `https://cdn.akamai.steamstatic.com/steam/apps/${appId}/header.jpg`,
        });
        total++;
        console.log(`Saved: ${gameName} - ${item.title}`);
      }
    } catch (e) {
      console.log(`Skip ${gameName}: ${e.message}`);
    }
    // 2 sec delay taake Steam block na kare
    await new Promise(r => setTimeout(r, 2000));
  }
  console.log(`Done! Total ${total} news saved`);
}

fetchAll();