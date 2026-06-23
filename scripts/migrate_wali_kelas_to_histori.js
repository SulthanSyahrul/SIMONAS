/*
 * Migrate legacy kelas.wali_kelas_uid + kelas.tahun_ajaran_id
 * into histori_wali_kelas collection.
 *
 * Usage:
 * node scripts/migrate_wali_kelas_to_histori.js --service-account ./serviceAccountKey.json
 *
 * Notes:
 * - Safe to run multiple times (skips duplicates).
 * - Keeps legacy fields in collection kelas for backward compatibility.
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = argv.slice(2);

  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  const hasFlag = (name) => args.includes(`--${name}`);

  return {
    serviceAccount: getValue('service-account', null),
    dryRun: hasFlag('dry-run'),
    limit: Number(getValue('limit', '0')) || 0,
  };
}

function initFirebase(serviceAccountPath) {
  if (admin.apps.length > 0) {
    return admin.firestore();
  }

  if (serviceAccountPath) {
    const absolutePath = path.resolve(serviceAccountPath);
    if (!fs.existsSync(absolutePath)) {
      throw new Error(`Service account file tidak ditemukan: ${absolutePath}`);
    }

    const serviceAccount = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    return admin.firestore();
  }

  admin.initializeApp();
  return admin.firestore();
}

function normalizeString(value) {
  return String(value ?? '').trim();
}

async function loadExistingAssignments(db) {
  const snapshot = await db.collection('histori_wali_kelas').where('isDeleted', '==', false).get();
  const keys = new Set();

  for (const doc of snapshot.docs) {
    const row = doc.data() || {};
    const kelasId = normalizeString(row.kelas_id);
    const guruUid = normalizeString(row.guru_uid);
    const tahunAjaranId = normalizeString(row.tahun_ajaran_id);
    if (!kelasId || !guruUid || !tahunAjaranId) {
      continue;
    }

    keys.add(`${kelasId}|${guruUid}|${tahunAjaranId}`);
  }

  return keys;
}

async function main() {
  const opts = parseArgs(process.argv);
  const db = initFirebase(opts.serviceAccount);

  const kelasRef = db.collection('kelas');
  let query = kelasRef.where('isDeleted', '==', false);
  if (opts.limit > 0) {
    query = query.limit(opts.limit);
  }

  const kelasSnapshot = await query.get();
  const existingKeys = await loadExistingAssignments(db);

  let scanned = 0;
  let eligible = 0;
  let created = 0;
  let skippedNoLegacy = 0;
  let skippedIncomplete = 0;
  let skippedDuplicate = 0;

  let batch = db.batch();
  let batchCount = 0;
  const commitIfNeeded = async (force = false) => {
    if (batchCount === 0) {
      return;
    }
    if (!force && batchCount < 400) {
      return;
    }
    if (!opts.dryRun) {
      await batch.commit();
    }
    batch = db.batch();
    batchCount = 0;
  };

  for (const kelasDoc of kelasSnapshot.docs) {
    scanned += 1;

    const kelas = kelasDoc.data() || {};
    const kelasId = normalizeString(kelasDoc.id);
    const guruUid = normalizeString(kelas.wali_kelas_uid);
    const tahunAjaranId = normalizeString(kelas.tahun_ajaran_id);

    if (!guruUid && !tahunAjaranId) {
      skippedNoLegacy += 1;
      continue;
    }

    if (!guruUid || !tahunAjaranId) {
      skippedIncomplete += 1;
      continue;
    }

    eligible += 1;
    const dedupeKey = `${kelasId}|${guruUid}|${tahunAjaranId}`;
    if (existingKeys.has(dedupeKey)) {
      skippedDuplicate += 1;
      continue;
    }

    const historiRef = db.collection('histori_wali_kelas').doc();
    batch.set(historiRef, {
      kelas_id: kelasId,
      guru_uid: guruUid,
      tahun_ajaran_id: tahunAjaranId,
      isAktif: true,
      isDeleted: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      deletedAt: null,
    });
    batchCount += 1;
    created += 1;
    existingKeys.add(dedupeKey);

    await commitIfNeeded(false);
  }

  await commitIfNeeded(true);

  console.log(
    JSON.stringify(
      {
        dryRun: opts.dryRun,
        scanned,
        eligible,
        created,
        skippedNoLegacy,
        skippedIncomplete,
        skippedDuplicate,
      },
      null,
      2,
    ),
  );
}

main().catch((err) => {
  console.error('ERROR:', err.message);
  process.exitCode = 1;
});
