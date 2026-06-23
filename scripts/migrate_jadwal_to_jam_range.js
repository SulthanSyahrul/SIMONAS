/*
 * Migrate jadwal docs from per-period rows (jam_ke) to range rows (jam_awal, jam_akhir).
 *
 * Default mode: dry-run (no writes).
 * Apply mode: add --apply
 *
 * Usage examples:
 * node scripts/migrate_jadwal_to_jam_range.js --service-account ./serviceAccountKey.json
 * node scripts/migrate_jadwal_to_jam_range.js --service-account ./serviceAccountKey.json --apply
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const MAX_BATCH_WRITES = 400;

function parseArgs(argv) {
  const args = argv.slice(2);

  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  return {
    apply: args.includes('--apply'),
    serviceAccount: getValue('service-account', null),
    projectId: getValue('project-id', null),
  };
}

function normalizeText(value) {
  return String(value ?? '').trim();
}

function parseIntOrNull(value) {
  if (value == null) return null;
  if (typeof value === 'number') return Number.isFinite(value) ? Math.trunc(value) : null;
  const parsed = parseInt(String(value), 10);
  return Number.isNaN(parsed) ? null : parsed;
}

function makeGroupingKey(docData) {
  return [
    normalizeText(docData.guru_uid ?? docData.guruId ?? docData.guruUid),
    normalizeText(docData.kelas_id ?? docData.kelasId),
    normalizeText(docData.mapel_id ?? docData.mapelId),
    normalizeText(docData.tahun_ajaran_id ?? docData.tahunAjaranId),
    String(parseIntOrNull(docData.semester) ?? 1),
    normalizeText(docData.hari),
    normalizeText(docData.waktu_mulai ?? docData.waktuMulai),
    normalizeText(docData.waktu_selesai ?? docData.waktuSelesai),
    normalizeText(docData.ruangan),
  ].join('|');
}

function splitIntoContiguousSegments(sortedRows) {
  const segments = [];
  let current = [];
  let previousJam = null;

  for (const row of sortedRows) {
    if (current.length === 0) {
      current.push(row);
      previousJam = row.jam;
      continue;
    }

    if (row.jam <= previousJam + 1) {
      current.push(row);
      previousJam = row.jam;
      continue;
    }

    segments.push(current);
    current = [row];
    previousJam = row.jam;
  }

  if (current.length > 0) {
    segments.push(current);
  }

  return segments;
}

function initializeFirebase({ serviceAccount, projectId }) {
  if (admin.apps.length > 0) {
    return admin.firestore();
  }

  if (serviceAccount) {
    const resolved = path.resolve(serviceAccount);
    if (!fs.existsSync(resolved)) {
      throw new Error(`Service account file not found: ${resolved}`);
    }

    const credentials = JSON.parse(fs.readFileSync(resolved, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(credentials),
      ...(projectId ? { projectId } : {}),
    });
    return admin.firestore();
  }

  admin.initializeApp(projectId ? { projectId } : undefined);
  return admin.firestore();
}

async function commitBatches(db, operations, apply) {
  if (!apply || operations.length === 0) {
    return;
  }

  let index = 0;
  while (index < operations.length) {
    const chunk = operations.slice(index, index + MAX_BATCH_WRITES);
    const batch = db.batch();

    for (const op of chunk) {
      if (op.type === 'update') {
        batch.update(op.ref, op.payload);
      } else if (op.type === 'set') {
        batch.set(op.ref, op.payload, { merge: true });
      }
    }

    await batch.commit();
    index += chunk.length;
    console.log(`Committed ${index}/${operations.length} writes`);
  }
}

async function run() {
  const args = parseArgs(process.argv);
  const db = initializeFirebase(args);

  console.log('='.repeat(80));
  console.log('Jadwal migration to jam range');
  console.log(`Mode           : ${args.apply ? 'APPLY' : 'DRY-RUN'}`);
  console.log(`Project        : ${args.projectId || '(default credentials project)'}`);
  console.log('='.repeat(80));

  const snapshot = await db
    .collection('jadwal')
    .where('isDeleted', '==', false)
    .get();

  console.log(`Fetched active jadwal docs: ${snapshot.size}`);

  const groups = new Map();
  const cleanupOnly = [];
  const skippedInvalid = [];

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const jamAwal = parseIntOrNull(data.jam_awal ?? data.jamAwal);
    const jamAkhir = parseIntOrNull(data.jam_akhir ?? data.jamAkhir);
    const jamKe = parseIntOrNull(data.jam_ke ?? data.jamKe);

    const hasRange = jamAwal != null && jamAkhir != null;
    const hasLegacyJam = jamKe != null;

    if (hasRange && !hasLegacyJam) {
      continue;
    }

    if (!hasLegacyJam && hasRange) {
      cleanupOnly.push({ doc, jamAwal, jamAkhir });
      continue;
    }

    if (!hasLegacyJam) {
      skippedInvalid.push({ id: doc.id, reason: 'missing jam field' });
      continue;
    }

    const key = makeGroupingKey(data);
    const list = groups.get(key) || [];
    list.push({ doc, data, jam: jamKe });
    groups.set(key, list);
  }

  const operations = [];
  let groupsProcessed = 0;
  let docsUpdatedAsRange = 0;
  let docsSoftDeleted = 0;

  for (const [key, rows] of groups.entries()) {
    if (rows.length === 0) {
      continue;
    }

    rows.sort((a, b) => {
      if (a.jam !== b.jam) return a.jam - b.jam;
      return a.doc.id.localeCompare(b.doc.id);
    });

    const segments = splitIntoContiguousSegments(rows);
    groupsProcessed += 1;

    for (const segment of segments) {
      const jamAwalSegment = segment[0].jam;
      const jamAkhirSegment = segment[segment.length - 1].jam;
      const keeper = segment[0];

      operations.push({
        type: 'update',
        ref: keeper.doc.ref,
        payload: {
          jam_awal: jamAwalSegment,
          jam_akhir: jamAkhirSegment,
          jam_ke: admin.firestore.FieldValue.delete(),
          jamKe: admin.firestore.FieldValue.delete(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
      });
      docsUpdatedAsRange += 1;

      for (let i = 1; i < segment.length; i += 1) {
        const duplicate = segment[i];
        operations.push({
          type: 'update',
          ref: duplicate.doc.ref,
          payload: {
            isDeleted: true,
            deletedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            migrated_to: keeper.doc.id,
          },
        });
        docsSoftDeleted += 1;
      }
    }

    if (groupsProcessed % 100 === 0) {
      console.log(`Processed ${groupsProcessed} groups...`);
    }
  }

  for (const item of cleanupOnly) {
    operations.push({
      type: 'update',
      ref: item.doc.ref,
      payload: {
        jam_awal: item.jamAwal,
        jam_akhir: item.jamAkhir,
        jam_ke: admin.firestore.FieldValue.delete(),
        jamKe: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
    });
    docsUpdatedAsRange += 1;
  }

  console.log('-'.repeat(80));
  console.log(`Groups processed        : ${groupsProcessed}`);
  console.log(`Docs updated as range   : ${docsUpdatedAsRange}`);
  console.log(`Docs soft-deleted merge : ${docsSoftDeleted}`);
  console.log(`Cleanup-only docs       : ${cleanupOnly.length}`);
  console.log(`Invalid docs skipped    : ${skippedInvalid.length}`);
  console.log(`Planned writes          : ${operations.length}`);

  if (skippedInvalid.length > 0) {
    console.log('Sample invalid docs (max 10):');
    for (const item of skippedInvalid.slice(0, 10)) {
      console.log(`- ${item.id}: ${item.reason}`);
    }
  }

  await commitBatches(db, operations, args.apply);

  console.log('-'.repeat(80));
  if (args.apply) {
    console.log('Migration applied successfully.');
  } else {
    console.log('Dry-run complete. Re-run with --apply to write changes.');
  }
}

run().catch((error) => {
  console.error('Migration failed:', error);
  process.exitCode = 1;
});
