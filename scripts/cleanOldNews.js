require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = process.env.SUPABASE_URL || 'https://dxdkitnroypbblazblja.supabase.co';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_KEY;

if (!SUPABASE_SERVICE_KEY) {
  console.error('SUPABASE_SERVICE_KEY is missing. Please set it in your .env or environment.');
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function cleanOldShortNews() {
  console.log('Starting cleanup of short (< 500 chars) and invalid news from Supabase...');
  
  const { data: rows, error } = await supabase
    .from('news')
    .select('id, title, titleMap, description, content, descriptionMap, imageUrl, gameName');

  if (error) {
    console.error('Error fetching news:', error.message);
    process.exit(1);
  }

  console.log(`Total documents in Supabase 'news': ${rows.length}`);

  let deletedShort = 0;
  let deletedWrongImage = 0;
  let deletedInvalid = 0;

  for (const item of rows) {
    const id = item.id;
    const title = item.title || (typeof item.titleMap === 'object' ? item.titleMap?.en : '') || '';
    const desc = item.description || item.content || (typeof item.descriptionMap === 'object' ? item.descriptionMap?.en : '') || '';
    const img = item.imageUrl || '';
    const game = (item.gameName || '').toLowerCase();

    // 1. Check if description/content is shorter than 500 characters
    if (desc.trim().length < 500) {
      await supabase.from('news').delete().eq('id', id);
      deletedShort++;
      continue;
    }

    // 2. Check if image is an invalid URL or fallback Elden Ring for non-Elden-Ring game
    if (img.includes('1245620') && !game.includes('elden ring') && !title.toLowerCase().includes('elden ring')) {
      await supabase.from('news').delete().eq('id', id);
      deletedWrongImage++;
      continue;
    }

    if (!img.startsWith('http')) {
      await supabase.from('news').delete().eq('id', id);
      deletedInvalid++;
      continue;
    }
  }

  console.log(`Cleanup summary:`);
  console.log(`- Deleted short news (< 500 chars): ${deletedShort}`);
  console.log(`- Deleted wrong Elden Ring image news: ${deletedWrongImage}`);
  console.log(`- Deleted invalid image news: ${deletedInvalid}`);
  console.log(`- Remaining high quality full news: ${rows.length - (deletedShort + deletedWrongImage + deletedInvalid)}`);
}

cleanOldShortNews().catch(err => {
  console.error('Error during cleanup:', err);
  process.exit(1);
});
