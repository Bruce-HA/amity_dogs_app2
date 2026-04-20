import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function run() {

  console.log('🔍 Scanning bucket...');

  const { data: files, error } = await supabase.storage
    .from('dog_files')
    .list('', { limit: 1000 });

  if (error) {
    console.log('❌ List error:', error);
    return;
  }

  let processed = 0;

  for (let folder of files) {

    const dogAla = folder.name;

    // skip invalid folders
    if (!dogAla.includes('-')) continue;

    const { data: innerFiles } = await supabase.storage
      .from('dog_files')
      .list(`${dogAla}/photos`, { limit: 10 });

    if (!innerFiles || innerFiles.length === 0) continue;

    // get first photo
    const file = innerFiles[0];

    const filePath = `${dogAla}/photos/${file.name}`;

    const { data: publicUrlData } = supabase.storage
      .from('dog_files')
      .getPublicUrl(filePath);

    const publicUrl = publicUrlData.publicUrl;

    // get dog_id
    const { data: dog } = await supabase
      .from('dogs')
      .select('id')
      .eq('dog_ala', dogAla)
      .maybeSingle();

    if (!dog) {
      console.log(`❌ Dog not found: ${dogAla}`);
      continue;
    }

    // check existing
    const { data: existing } = await supabase
      .from('dog_photos')
      .select('id')
      .eq('dog_id', dog.id)
      .eq('is_hero', true)
      .maybeSingle();

    if (existing) {
      console.log(`⏭️ Already exists: ${dogAla}`);
      continue;
    }

    // insert
    const { error: insertError } = await supabase
      .from('dog_photos')
      .insert({
        dog_id: dog.id,
        dog_ala: dogAla,
        url: publicUrl,
        file_name: file.name,
        is_hero: true,
        display_order: 0,
        photo_exists_on_zooeasy: true,
        last_checked_at: new Date().toISOString()
      });

    if (insertError) {
      console.log(`❌ Insert error ${dogAla}:`, insertError);
      continue;
    }

    await supabase
      .from('dogs')
      .update({ has_photo: true })
      .eq('id', dog.id);

    console.log(`✅ Synced: ${dogAla}`);
    processed++;
  }

  console.log(`🎉 DONE — ${processed} photos synced`);
}

run();


