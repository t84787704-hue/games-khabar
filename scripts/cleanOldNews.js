require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = (process.env.SUPABASE_URL && process.env.SUPABASE_URL.trim() !== '')
  ? process.env.SUPABASE_URL.trim()
  : 'https://dxdkitnroypbblazblja.supabase.co';

const SUPABASE_SERVICE_KEY = (process.env.SUPABASE_SERVICE_KEY && process.env.SUPABASE_SERVICE_KEY.trim() !== '')
  ? process.env.SUPABASE_SERVICE_KEY.trim()
  : ((process.env.SUPABASE_KEY && process.env.SUPABASE_KEY.trim() !== '')
      ? process.env.SUPABASE_KEY.trim()
      : 'sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y');

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

async function cleanOldShortNews() {
  console.log('Starting cleanup of short (< 500 chars) and invalid news from Supabase...');
  
  const { data: rows, error } = await supabase
    .from('steam_news')
    .select('*');

  if (error) {
    console.error('Error fetching news:', error.message);
    process.exit(1);
  }

  console.log(`Total documents in Supabase 'news': ${rows ? rows.length : 0}`);

  let deletedShort = 0;
  let deletedWrongImage = 0;
  let deletedInvalid = 0;

  for (const item of (rows || [])) {
    const id = item.id;
    const title = item.title || (typeof item.titleMap === 'object' ? item.titleMap?.en : '') || '';
    const desc = item.description || (typeof item.descriptionMap === 'object' ? item.descriptionMap?.en : '') || '';
    const img = item.imageUrl || item.image_url || '';
    const game = (item.gameName || item.game || '').toLowerCase();

    // 1. Check if description/content is shorter than 500 characters
    if (desc.trim().length < 500) {
      await supabase.from('steam_news').delete().eq('id', id);
      deletedShort++;
      continue;
    }

    // 2. Check if image is a Google logo, favicon, or invalid URL
    const lowerImg = img.toLowerCase();
    if (lowerImg.includes('google') ||
        lowerImg.includes('gstatic') ||
        lowerImg.includes('favicon')) {
      await supabase.from('steam_news').delete().eq('id', id);
      deletedWrongImage++;
      continue;
    }

    if (img.includes('1245620') && !game.includes('elden ring') && !title.toLowerCase().includes('elden ring')) {
      await supabase.from('steam_news').delete().eq('id', id);
      deletedWrongImage++;
      continue;
    }

    if (!img.startsWith('http')) {
      await supabase.from('steam_news').delete().eq('id', id);
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
