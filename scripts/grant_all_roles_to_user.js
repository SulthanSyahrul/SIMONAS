/*
 * Add all supported app roles to a specific user in Firestore.
 *
 * Usage:
 * node scripts/grant_all_roles_to_user.js --uid <USER_UID> --service-account ./serviceAccountKey.json
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const SUPPORTED_ROLES = ['kepala_sekolah', 'guru', 'bk', 'siswa'];

function parseArgs(argv) {
  const args = argv.slice(2);

  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  return {
    uid: getValue('uid', null),
    serviceAccount: getValue('service-account', null),
  };
}

function normalizeRole(role) {
  const value = String(role ?? '').trim().toLowerCase();
  switch (value) {
    case 'kepala sekolah':
    case 'kepalasekolah':
    case 'kepsek':
      return 'kepala_sekolah';
    default:
      return value;
  }
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

async function main() {
  const opts = parseArgs(process.argv);

  if (!opts.uid) {
    throw new Error('UID wajib diisi. Contoh: --uid 4SkkxOUwVaRciwCIq1lN');
  }

  const db = initFirebase(opts.serviceAccount);
  const uid = String(opts.uid).trim();

  const userRef = db.collection('users').doc(uid);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new Error(`User tidak ditemukan di collection users dengan UID: ${uid}`);
  }

  const userData = userSnap.data() || {};

  const roleRows = await db.collection('user_roles').where('uid', '==', uid).get();

  const existingActiveRoleSet = new Set();
  for (const doc of roleRows.docs) {
    const row = doc.data() || {};
    const isDeleted = Boolean(row.isDeleted);
    if (isDeleted) {
      continue;
    }

    existingActiveRoleSet.add(normalizeRole(row.role));
  }

  const missingRoles = SUPPORTED_ROLES.filter((role) => !existingActiveRoleSet.has(role));
  if (missingRoles.length === 0) {
    console.log(
      JSON.stringify(
        {
          uid,
          nama: userData.nama || null,
          username: userData.username || null,
          insertedRoles: [],
          existingActiveRoles: Array.from(existingActiveRoleSet).sort(),
          message: 'Semua role sudah tersedia. Tidak ada perubahan.',
        },
        null,
        2,
      ),
    );
    return;
  }

  const ts = admin.firestore.FieldValue.serverTimestamp();
  const batch = db.batch();

  for (const role of missingRoles) {
    const ref = db.collection('user_roles').doc();
    batch.set(ref, {
      uid,
      role,
      createdAt: ts,
      updatedAt: ts,
      deletedAt: null,
      isDeleted: false,
    });
  }

  await batch.commit();

  const finalRoleRows = await db.collection('user_roles').where('uid', '==', uid).get();
  const finalActiveRoleSet = new Set();
  for (const doc of finalRoleRows.docs) {
    const row = doc.data() || {};
    if (Boolean(row.isDeleted)) {
      continue;
    }
    finalActiveRoleSet.add(normalizeRole(row.role));
  }

  console.log(
    JSON.stringify(
      {
        uid,
        nama: userData.nama || null,
        username: userData.username || null,
        insertedRoles: missingRoles,
        finalActiveRoles: Array.from(finalActiveRoleSet).sort(),
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
