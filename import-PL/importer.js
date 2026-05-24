const admin = require('firebase-admin');
const fs = require('fs');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function getPolygonCentroid(coords) {
  const ring = coords[0];

  let area = 0;
  let cx = 0;
  let cy = 0;

  for (let i = 0; i < ring.length - 1; i++) {
    const x0 = ring[i][0];
    const y0 = ring[i][1];
    const x1 = ring[i + 1][0];
    const y1 = ring[i + 1][1];

    const cross = x0 * y1 - x1 * y0;

    area += cross;
    cx += (x0 + x1) * cross;
    cy += (y0 + y1) * cross;
  }

  area = area / 2;

  if (area === 0) {
    return {
      lat: ring[0][1],
      lng: ring[0][0]
    };
  }

  return {
    lat: cy / (6 * area),
    lng: cx / (6 * area)
  };
}

async function importGeo() {
  console.log('🚀 START IMPORT');

  const data = JSON.parse(fs.readFileSync('poland_regions.json', 'utf8'));
  const features = data.features;

  console.log(`📦 Total features: ${features.length}`);

  let batch = db.batch();
  let counter = 0;
  let success = 0;
  let skipped = 0;

  for (const feature of features) {
    try {
      const name = feature.properties?.name?.trim();
      if (!name) {
        skipped++;
        continue;
      }

      const geometry = feature.geometry;
      if (!geometry?.coordinates) {
        skipped++;
        continue;
      }

      const coordinates = geometry.coordinates;

      const centroid = getPolygonCentroid(coordinates);

      const docId = name
        .toLowerCase()
        .replace(/[^a-z0-9ąćęłńóśźż]/g, '_')
        .replace(/_+/g, '_');

      const ref = db.collection('regions').doc(docId);

      batch.set(ref, {
        name,
        nameLower: name.toLowerCase(),
        terc: feature.properties?.terc || '',
        type: geometry.type,

        // ✅ FIX: no nested arrays
        coordinates: JSON.stringify(coordinates),

        center: new admin.firestore.GeoPoint(
          centroid.lat,
          centroid.lng
        ),

        country: 'Poland',
        countryCode: 'PL',
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      counter++;
      success++;

      if (counter >= 450) {
        await batch.commit();
        batch = db.batch(); // 🔥 fresh batch
        counter = 0;

        console.log(`⏳ Committed: ${success}`);
      }

    } catch (e) {
      console.log('❌ Error:', e.message);
      skipped++;
    }
  }

  if (counter > 0) {
    await batch.commit();
  }

  console.log('\n🎉 IMPORT FINISHED');
  console.log(`✅ Success: ${success}`);
  console.log(`⚠️ Skipped: ${skipped}`);
}

importGeo();