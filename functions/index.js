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
  
  // Read from rss_sources or scraper_sources for maximum flexibility
  let sourcesSnap = await db.collection('rss_sources').where('isActive', '==', true).get();
  let docs = sourcesSnap.docs;
  
  if (docs.length === 0) {
    // Try scraper_sources collection fallback
    const fallbackSnap = await db.collection('scraper_sources').where('isEnabled', '==', true).get();
    if (!fallbackSnap.empty) {
      docs = fallbackSnap.docs;
    }
  }

  // If no sources exist yet in Firestore, use default sources
  let sourceList = [];
  if (docs.length > 0) {
    sourceList = docs.map(d => ({ id: d.id, ...d.data() }));
  } else {
    sourceList = [
      {
        name: 'Sportskeeda BGMI',
        url: 'https://www.sportskeeda.com/rss/bgmi',
        category: 'BGMI',
        isActive: true,
      },
      {
        name: 'Sportskeeda Free Fire',
        url: 'https://www.sportskeeda.com/rss/free-fire',
        category: 'Free Fire',
        isActive: true,
      },
      {
        name: 'IGN India',
        url: 'https://in.ign.com/feed.xml',
        category: 'Gaming',
        isActive: true,
      },
    ];
  }

  let count = 0;
  for (const source of sourceList) {
    if (!source.url) continue;
    try {
      const feed = await parser.parseURL(source.url);
      const items = (feed.items || []).slice(0, 5); // 5 latest per source

      for (const item of items) {
        if (!item.title && !item.link) continue;
        
        // Check duplicate by link or title
        let exists = false;
        if (item.link) {
          const checkLink = await db.collection('news').where('link', '==', item.link).limit(1).get();
          if (!checkLink.empty) exists = true;
        }
        if (!exists && item.title) {
          const checkTitle = await db.collection('news').where('title', '==', item.title).limit(1).get();
          if (!checkTitle.empty) exists = true;
        }

        if (exists) continue;

        // Image extraction
        let imageUrl = item.enclosure?.url || '';
        if (!imageUrl && item.mediaContent?.$?.url) {
          imageUrl = item.mediaContent.$.url;
        }
        if (!imageUrl && item.mediaThumbnail?.$?.url) {
          imageUrl = item.mediaThumbnail.$.url;
        }
        if (!imageUrl && (item.content || item.contentEncoded || item.descriptionSnippet)) {
          const html = item.content || item.contentEncoded || item.descriptionSnippet || '';
          const imgMatch = html.match(/<img[^>]+src=["']([^"']+)["']/i);
          if (imgMatch && imgMatch[1]) {
            imageUrl = imgMatch[1];
          }
        }

        // Clean content
        let rawContent = item.contentSnippet || item.contentEncoded || item.content || item.descriptionSnippet || '';
        const cleanContent = rawContent.replace(/<[^>]*>/g, '').trim();

        const newsPayload = {
          title: item.title ? item.title.trim() : 'Gaming Update',
          content: cleanContent || 'Check the full source link for detailed news and game insights.',
          description: cleanContent || 'Check the full source link for detailed news and game insights.',
          imageUrl: imageUrl || 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
          link: item.link || '',
          sourceUrl: item.link || '',
          sourceName: source.name || 'Gaming RSS',
          category: source.category || 'Gaming News',
          isAuto: true,
          tag: 'AUTO',
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          publishedAt: item.pubDate || new Date().toISOString(),
          views: Math.floor(Math.random() * 200) + 15,
        };

        await db.collection('news').add(newsPayload);
        count++;
      }
    } catch (e) {
      console.error('RSS error for source:', source.name || source.url, e.message);
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
