const dotenv = require('dotenv');
const { createClient } = require('@supabase/supabase-js');
const { chromium } = require('playwright');

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);
function formatDate(d) {
  if (!d) return null;
  const [day, month, year] = d.split('-');
  if (!day || !month || !year) return null;
  return `${year}-${month}-${day}`;
}

function parseWeight(w) {
  if (!w) return null;
  const match = w.match(/[\d.]+/);
  return match ? parseFloat(match[0]) : null;
}
// =========================
// LOGIN
// =========================
async function login(page) {
  await page.goto('https://www.zooeasyonline.com');
  await page.fill('#Email', process.env.ZE_USERNAME);
  await page.fill('#Password1', process.env.ZE_PASSWORD);
  await page.click('#loginBtnOne');
  await page.waitForURL('**/index.php', { timeout: 10000 });
  console.log('â Logged in');
}

// =========================
// MAIN
// =========================
async function fetchDogDetails() {

  let processed = 0;
  let updated = 0;
  let photos = 0;

  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage']
  });

  const page = await browser.newPage();
  await login(page);

  // ð¥ TEST 5 DOGs ONLY
  const BATCH_SIZE = 5;
    // =========================
    // 🔁 RESUME CONTROL
    // =========================

    // 👉 Resume from specific point
    // let lastDogAla = '0141-024-11';

    // 👉 Start from newest (recommended for full scan)
    let lastDogAla = null; // ð¥ RESUME POINT
    let hasMore = true;

    while (hasMore) {

      // =========================
// 🔎 DOG SELECTION QUERY
// =========================

// Base query (always runs)
let query = supabase
  .from('dogs')
  .select('dog_ala')
  .not('dog_ala', 'is', null)
  .order('dog_ala', { ascending: false })
  .limit(BATCH_SIZE);

// 🔥 OPTIONAL FILTERS (toggle ON/OFF below)

// 👉 OPTION 1: Only unmerged dogs (original behaviour)
// query = query.eq('has_been_merged', false);

// 👉 OPTION 2: Only your kennel (Amity 0174)
// query = query.ilike('dog_ala', '0174-%');

// 👉 OPTION 3: Specific breeder (example 0021)
// query = query.ilike('dog_ala', '0021-%');

// 👉 OPTION 4: Only dogs missing photos
// query = query.eq('has_photo', false);

// 👉 OPTION 5: Only dogs missing DNA
// query = query.is('dna_result', null);

      if (lastDogAla) {
        query = query.lt('dog_ala', lastDogAla);
      }

      const { data: dogs, error } = await query;

      // =========================
    // 🧠 POST FILTERING (JS LEVEL)
    // =========================

    // 👉 ONLY VALID ALA FORMAT (xxxx-xxx-xx)
    let filteredDogs = (dogs || []).filter(d => {
    const ala = (d.dog_ala || '').trim();
    return /^\d{4}-\d{3}-\d{2}$/.test(ala);
    });

    // 👉 OPTIONAL: ONLY SPECIFIC BREEDER (UNCOMMENT TO USE)
    // filteredDogs = filteredDogs.filter(d => d.dog_ala.startsWith('0021-'));

    // 👉 OPTIONAL: ONLY AMITY
    // filteredDogs = filteredDogs.filter(d => d.dog_ala.startsWith('0174-'));

    console.log(`🐶 Total fetched: ${dogs.length}`);
    console.log(`✅ After filter: ${filteredDogs.length}`);

    if (error) {
      console.log('â Error fetching batch:', error);
      break;
    }

    if (!dogs || dogs.length === 0) {
      console.log('â No more dogs to process');
      hasMore = false;
      break;
    }

    console.log(`ð¦ Batch starting after: ${lastDogAla}`);

    for (let dog of filteredDogs) {
    processed++;

    const ala = dog.dog_ala?.trim();
    if (!ala) continue;

    console.log(`â¡ï¸ Processing ${ala}`);

    try {

      // =========================
      // SEARCH
      // =========================
      await page.goto('https://www.zooeasyonline.com/animals.php?menu=1');

      await page.selectOption('#searchOption', 'RegistrationNumber');
      await page.fill('#txtSearch', ala);

      await page.evaluate(() => {
        validateSearch('https://www.zooeasyonline.com/views/');
        const downloadEl = document.querySelector('#fancybox-title a[href*="download.php"]');

        const download_url = downloadEl ? downloadEl.href : null;
      });

      await page.waitForSelector('table.list tbody tr', { timeout: 5000 }).catch(() => {});

      const rows = page.locator('table.list tbody tr');

      if (await rows.count() === 0) {
        console.log(`â ï¸ No ZooEasy result for ${ala}`);
        continue;
      }

      const link = rows.first().locator('td').first().locator('a');
      await link.click();

      await page.waitForURL('**/animalform.php**');
      // Open image viewer to expose download link
      const imageThumb = await page.$('img.dier_fotoindexdata');

      if (imageThumb) {
        await imageThumb.click();
        await page.waitForSelector('#fancybox-title a[href*="download.php"]', { timeout: 3000 }).catch(() => {});
      }

      // =========================
      // EXTRACTION
      // =========================
      const dataExtract = await page.evaluate(() => {

        const clean = el => el ? el.innerText.trim() : null;
        const val = id => document.querySelector(`#${id}`)?.value || null;

        const findRow = txt =>
          Array.from(document.querySelectorAll('td.first label'))
            .find(l => l.innerText.includes(txt))
            ?.closest('tr');

        const parentName = row => {
          if (!row) return null;
          return row.querySelector('table.ouder td:nth-child(2)')?.innerText.trim()
            || row.querySelectorAll('td')[1]?.innerText.trim()
            || null;
        };

        const extra = id => document.querySelector(`#${id}`)?.value || null;

        // =========================
        // NOTES + PARSING
        // =========================
        const notesEl = document.querySelector('td[style*="border:1px"]');
        const notesText = notesEl ? notesEl.innerText.trim() : null;

        const sex =
        document.querySelector('#Sex')?.value ||
        document.querySelector('#Gender')?.value ||
        Array.from(document.querySelectorAll('td.first label'))
          .find(l => l.innerText.includes('Sex'))
          ?.closest('tr')
          ?.querySelectorAll('td')[1]?.innerText.trim() ||
        null;

        const parseNotes = (text) => {
          if (!text) return {};

          const result = {};

          text.split(';').forEach(part => {
            const [rawKey, value] = part.split(':').map(s => s?.trim());
            if (!rawKey || !value) return;

            const key = rawKey.toLowerCase().replace(/\(.*?\)/g, '').trim();

            if (key.includes('status')) result.status = value;
            else if (key.includes('dna')) result.dna_result = value;
            else if (key.includes('pennhip')) result.pennhip = value;
            else if (key.includes('hip score')) result.hip_score = value;
            else if (key.includes('elbows')) result.elbows = value;
            else if (key.includes('weight')) result.weight = value;
            else if (key.includes('grading')) result.ala_grade = value;
          });

          return result;
        };

        const parsed = parseNotes(notesText);

        const photoEl = document.querySelector('img[src*="animal"]');
        const downloadEl = document.querySelector('a[href*="download.php"]');
        const download_url = downloadEl ? downloadEl.href : null;  

        return {
          pedigreeNo: val('RegistrationNumber'),
          name: clean(findRow('Name')?.querySelector('.value')),
          dob: val('Born'),

          sex: sex,   // â FIXED

          father_ala: val('Father'),
          father_name: parentName(findRow('Father')),

          mother_ala: val('Mother'),
          mother_name: parentName(findRow('Mother')),

          // structured hidden fields
          inbreeding: extra('InbreedingCoefficient'),
          avk: extra('AVKValue'),
          ecg: extra('ECG'),
          breed_percentage: extra('BreedPercentage'),
          complete_generations: extra('CompleteGenerations'),

          // notes + parsed
          notes: notesText,
          ...parsed,

          photo_url: photoEl ? photoEl.src : null,
          download_url
          
        };
      });

      console.log('ð¦ Extracted:', dataExtract);

      const pedigreeNo = (dataExtract.pedigreeNo || ala).trim();

      // =========================
      // MATCH
      // =========================
      const { data: existingDog } = await supabase
        .from('dogs')
        .select('id')
        .eq('dog_ala', pedigreeNo)
        .maybeSingle();

      // =========================
      // UPDATE
      // =========================
      if (existingDog) {

        console.log('ð Updating existing dog');

        const { data: updateResult, error: updateError } = await supabase
          .from('dogs')
          .update({
            dog_name: dataExtract.name,
            dob: formatDate(dataExtract.dob),

            father_ala: dataExtract.father_ala,
            father_name: dataExtract.father_name,
            mother_ala: dataExtract.mother_ala,
            mother_name: dataExtract.mother_name,

            inbreeding_coefficient: dataExtract.inbreeding,
            avk: dataExtract.avk,
            ecg: dataExtract.ecg,
            breed_percentage: dataExtract.breed_percentage,
            complete_generations: dataExtract.complete_generations,
            ala_grade: dataExtract.ala_grade,

            status: dataExtract.status,
            dna_result: dataExtract.dna_result,
            hip_score: dataExtract.hip_score,
            elbows: dataExtract.elbows,
            pennhip: dataExtract.pennhip,
            weight: parseWeight(dataExtract.weight),

            notes: dataExtract.notes,
            zooeasy_raw: dataExtract,
            has_photo: !!dataExtract.photo_url,
            has_been_merged: true,
            zooeasy_last_synced_at: new Date().toISOString()
          })
          .eq('dog_ala', pedigreeNo)
          .select();
          if (!updateError) updated++;
        // =========================
      // PHOTO PIPELINE (0174 ONLY)
      // =========================
      if (pedigreeNo.startsWith('0174') && dataExtract.photo_url) {

        console.log('ð¸ ZooEasy photo found');

        // Check if hero already exists
        const { data: existingPhoto } = await supabase
          .from('dog_photos')
          .select('id')
          .eq('dog_id', existingDog.id)
          .eq('is_hero', true)
          .maybeSingle();

        if (existingPhoto) {
          console.log('ð¸ Hero photo already exists, skipping upload');
        } else {

          try {
            console.log('â¬ï¸ Downloading image...');

            const imageUrl = dataExtract.download_url || dataExtract.photo_url;

            console.log('â¬ï¸ Downloading from:', imageUrl);

            const imageBufferArray = await page.evaluate(async (url) => {
              const res = await fetch(url);
              const blob = await res.blob();
              const arrayBuffer = await blob.arrayBuffer();
              return Array.from(new Uint8Array(arrayBuffer));
            }, imageUrl);

            const buffer = Buffer.from(imageBufferArray);

            const fileName = `${Date.now()}.jpg`;
            const filePath = `${pedigreeNo}/photos/${fileName}`;

            console.log('âï¸ Uploading to Supabase...');

            const { error: uploadError } = await supabase.storage
              .from('dog_files')
              .upload(filePath, buffer, {
                contentType: 'image/jpeg'
              });

            if (uploadError) {
              console.log('â Upload failed:', uploadError);
            } else {

              const { data: publicUrlData } = supabase.storage
                .from('dog_files')
                .getPublicUrl(filePath);

              const publicUrl = publicUrlData.publicUrl;

              console.log('â Uploaded:', publicUrl);

              const { data: photoInsert, error: photoError } = await supabase
                .from('dog_photos')
                .insert({
                  dog_id: existingDog.id,
                  dog_ala: pedigreeNo,
                  url: publicUrl,
                  file_name: fileName,
                  is_hero: true,
                  display_order: 0,
                  photo_exists_on_zooeasy: true
                })
                .select();

              console.log('â PHOTO ERROR:', photoError);

              console.log('ð¼ï¸ Hero photo saved');
              photos++;

              // Update dogs table
              await supabase.from('dogs').update({
                has_photo: true,
                sex: dataExtract.sex || undefined,
              }).eq('id', existingDog.id);
            }

          } catch (err) {
            console.log('â Photo pipeline error:', err.message);
          }
        }
      }

      } else {

        console.log('â Inserting new dog');

        await supabase.from('dogs').insert({
          dog_ala: pedigreeNo,
          dog_name: dataExtract.name,
          dob: formatDate(dataExtract.dob),

          father_ala: dataExtract.father_ala,
          father_name: dataExtract.father_name,
          mother_ala: dataExtract.mother_ala,
          mother_name: dataExtract.mother_name,

          inbreeding_coefficient: dataExtract.inbreeding,
          avk: dataExtract.avk,
          ecg: dataExtract.ecg,
          breed_percentage: dataExtract.breed_percentage,
          complete_generations: dataExtract.complete_generations,
          ala_grade: dataExtract.ala_grade,

          status: dataExtract.status,
          dna_result: dataExtract.dna_result,
          hip_score: dataExtract.hip_score,
          elbows: dataExtract.elbows,
          pennhip: dataExtract.pennhip,
          weight: parseWeight(dataExtract.weight),

          notes: dataExtract.notes,
          zooeasy_raw: dataExtract,
          has_photo: !!dataExtract.photo_url,
          has_been_merged: true,
          zooeasy_last_synced_at: new Date().toISOString()
        });

      }

    } catch (err) {
      console.log(`â Error for ${ala}:`, err.message);
    }
  }
    // â ADD THIS HERE
    await page.waitForTimeout(1000);    
    if (dogs.length > 0) {
      lastDogAla = dogs[dogs.length - 1].dog_ala;
    }
}

  await browser.close();
  console.log('ð DONE');
  console.log(`ð Progress â Processed: ${processed} | Updated: ${updated} | Photos: ${photos}`);
}

fetchDogDetails();