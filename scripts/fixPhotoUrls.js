import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function run() {

  console.log('🔧 Fixing photo URLs...');

  // get all rows with full URLs
  const { data: photos, error } = await supabase
    .from('dog_photos')
    .select('id, url')
    .like('url', 'http%');

  if (error) {
    console.log('❌ Fetch error:', error);
    return;
  }

  let fixed = 0;

  for (let photo of photos) {

    try {
      const fullUrl = photo.url;

      // extract file name
      const fileName = fullUrl.split('/').pop();

      if (!fileName) continue;

      const { error: updateError } = await supabase
        .from('dog_photos')
        .update({
          url: fileName,
          file_name: fileName
        })
        .eq('id', photo.id);

      if (updateError) {
        console.log(`❌ Update error ${photo.id}:`, updateError);
        continue;
      }

      console.log(`✅ Fixed: ${fileName}`);
      fixed++;

    } catch (err) {
      console.log(`❌ Error:`, err.message);
    }
  }

  console.log(`🎉 DONE — ${fixed} rows fixed`);
}

run();
