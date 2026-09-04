const admin = require('firebase-admin');

if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
  console.error('FIREBASE_SERVICE_ACCOUNT secret is missing.');
  process.exit(1);
}

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

async function cleanOldShortNews() {
  console.log('Starting cleanup of short (< 500 chars) and invalid news...');
  const snap = await db.collection('news').get();
  console.log(`Total documents in Firestore 'news': ${snap.size}`);

  let deletedShort = 0;
  let deletedWrongImage = 0;
  let deletedInvalid = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const title = data.title || data.titleMap?.en || '';
    const desc = data.description || data.content || data.descriptionMap?.en || '';
    const img = data.imageUrl || '';
    const game = (data.gameName || '').toLowerCase();

    // 1. Check if description/content is shorter than 500 characters
    if (desc.trim().length < 500) {
      await doc.ref.delete();
      deletedShort++;
      continue;
    }

    // 2. Check if image is an invalid URL or fallback Elden Ring for non-Elden-Ring game
    if (img.includes('1245620') && !game.includes('elden ring') && !title.toLowerCase().includes('elden ring')) {
      await doc.ref.delete();
      deletedWrongImage++;
      continue;
    }

    if (!img.startsWith('http')) {
      await doc.ref.delete();
      deletedInvalid++;
      continue;
    }
  }

  console.log(`Cleanup summary:`);
  console.log(`- Deleted short news (< 500 chars): ${deletedShort}`);
  console.log(`- Deleted wrong Elden Ring image news: ${deletedWrongImage}`);
  console.log(`- Deleted invalid image news: ${deletedInvalid}`);
  console.log(`- Remaining high quality full news: ${snap.size - (deletedShort + deletedWrongImage + deletedInvalid)}`);

  await admin.app().delete();
}

cleanOldShortNews().catch(err => {
  console.error('Error during cleanup:', err);
  process.exit(1);
});
