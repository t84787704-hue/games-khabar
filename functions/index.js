const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Parser = require('rss-parser');

admin.initializeApp();
const parser = new Parser({
  customFields: {
    item: [
      ['media:content', 'mediaContent', { keepArray: false }],
      ['media:thumbnail', 'mediaThumbnail', { keepArray: false }],
      ['content:encoded', 'contentEncoded'],
      ['description', 'descriptionSnippet'],
    ],
  },
});

async function syncLogic() {
  const db = admin.firestore();
  let sourcesSnap = await db.collection('rss_sources').where('isActive', '==', true).get();
  let docs = sourcesSnap.docs;

  if (docs.length === 0) {
    const fallbackSnap = await db.collection('scraper_sources').where('isEnabled', '==', true).get();
    if (!fallbackSnap.empty) docs = fallbackSnap.docs;
  }

  let sourceList = [];
  if (docs.length > 0) {
    sourceList = docs.map(d => ({ id: d.id,...d.data() }));
  } else {
    sourceList = [
      { name: 'Sportskeeda BGMI', url: 'https://www.sportskeeda.com/rss/bgmi', category: 'BGMI', isActive: true },
      { name: 'Sportskeeda Free Fire', url: 'https://www.sportskeeda.com/rss/free-fire', category: 'Free Fire', isActive: true },
      { name: 'IGN India', url: 'https://in.ign.com/feed.xml', category: 'Gaming', isActive: true },
    ];
  }

  let count = 0;
  for (const source of sourceList) {
    if (!source.url) continue;
    try {
      const feed = await parser.parseURL(source.url);
      const items = (feed.items || []).slice(0, 5);

      for (const item of items) {
        if (!item.title &&!item.link) continue;

        let exists = false;
        if (item.link) {
          const checkLink = await db.collection('news').where('sourceUrl', '==', item.link).limit(1).get();
          if (!checkLink.empty) exists = true;
        }
        if (exists) continue;

        let imageUrl = item.enclosure?.url || '';
        if (!imageUrl && item.mediaContent?.$?.url) imageUrl = item.mediaContent.$.url;
        if (!imageUrl && item.mediaThumbnail?.$?.url) imageUrl = item.mediaThumbnail.$.url;
        if (!imageUrl && (item.content || item.contentEncoded || item.descriptionSnippet)) {
          const html = item.content || item.contentEncoded || item.descriptionSnippet || '';
          const imgMatch = html.match(/<img[^>]+src=["']([^"']+)["']/i);
          if (imgMatch && imgMatch[1]) imageUrl = imgMatch[1];
        }

        // FINAL FALLBACK - har news ki alag pic
        if (!imageUrl) {
          imageUrl = `https://picsum.photos/seed/${encodeURIComponent(item.title || Math.random())}/800/600`;
        }

        let rawContent = item.contentSnippet || item.contentEncoded || item.content || item.descriptionSnippet || '';
        const cleanContent = rawContent.replace(/<[^>]*>/g, '').trim();

        const newsPayload = {
          title: item.title? item.title.trim() : 'Gaming Update',
          content: cleanContent || 'Check the full source link for detailed news.',
          description: cleanContent || 'Check the full source link for detailed news.',
          imageUrl: imageUrl,
          link: item.link || '',
          sourceUrl: item.link || '',
          sourceName: source.name || 'Gaming RSS',
          category: source.category || 'Gaming News',
          isAuto: true,
          tag: 'AUTO',
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          publishedAt: item.pubDate || new Date().toISOString(),
          views: Math.floor(Math.random() * 200) + 15,
        };

        await db.collection('news').add(newsPayload);
        count++;
      }
    } catch (e) {
      console.error('RSS error:', source.name || source.url, e.message);
    }
  }
  return { count };
}

exports.manualSyncFeeds = functions.https.onCall(async (data, context) => {
  const result = await syncLogic();
  return result;
});

exports.scheduledSync = functions.pubsub.schedule('every 30 minutes').onRun(async () => {
  await syncLogic();
  return null;
});