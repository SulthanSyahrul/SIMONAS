/*
 * Configure CORS for Firebase Storage bucket used by web upload.
 *
 * Usage:
 * node scripts/set_storage_cors.js --service-account ./serviceAccountKey.json
 * node scripts/set_storage_cors.js --service-account ./serviceAccountKey.json --bucket smp-1-jenar-pengawasan-kelas.firebasestorage.app
 */

const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

const DEFAULT_PROJECT_ID = 'smp-1-jenar-pengawasan-kelas';

function parseArgs(argv) {
  const args = argv.slice(2);

  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  return {
    serviceAccount: getValue('service-account', null),
    bucket: getValue('bucket', null),
    projectId: getValue('project-id', DEFAULT_PROJECT_ID),
  };
}

function initFirebase(serviceAccountPath) {
  if (admin.apps.length > 0) {
    return;
  }

  if (!serviceAccountPath) {
    admin.initializeApp();
    return;
  }

  const absolutePath = path.resolve(serviceAccountPath);
  if (!fs.existsSync(absolutePath)) {
    throw new Error(`Service account file tidak ditemukan: ${absolutePath}`);
  }

  const serviceAccount = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

function createCorsConfig(projectId) {
  const webOrigins = [
    `https://${projectId}.web.app`,
    `https://${projectId}.firebaseapp.com`,
  ];

  const localhostOrigins = [
    'http://localhost',
    'http://127.0.0.1',
    'http://localhost:3000',
    'http://localhost:5000',
    'http://localhost:5500',
    'http://localhost:57552',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:5000',
    'http://127.0.0.1:5500',
    'http://127.0.0.1:57552',
  ];

  return [
    {
      origin: [...new Set([...webOrigins, ...localhostOrigins])],
      method: ['GET', 'HEAD', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
      responseHeader: [
        'Content-Type',
        'Authorization',
        'x-firebase-gmpid',
        'x-goog-resumable',
        'x-goog-upload-protocol',
        'x-goog-upload-command',
        'x-goog-upload-header-content-length',
        'x-goog-upload-header-content-type',
      ],
      maxAgeSeconds: 3600,
    },
  ];
}

async function resolveBucketName(explicitBucket, projectId) {
  const candidates = explicitBucket
    ? [explicitBucket]
    : [
        `${projectId}.firebasestorage.app`,
        `${projectId}.appspot.com`,
      ];

  for (const name of candidates) {
    try {
      const bucket = admin.storage().bucket(name);
      const [exists] = await bucket.exists();
      if (exists) {
        return name;
      }
    } catch (_) {
      // Continue trying next candidate.
    }
  }

  throw new Error(
    `Bucket tidak ditemukan. Coba tentukan manual dengan --bucket. Kandidat: ${candidates.join(', ')}`,
  );
}

async function main() {
  const opts = parseArgs(process.argv);
  initFirebase(opts.serviceAccount);

  const bucketName = await resolveBucketName(opts.bucket, opts.projectId);
  const bucket = admin.storage().bucket(bucketName);

  const corsConfig = createCorsConfig(opts.projectId);
  await bucket.setMetadata({ cors: corsConfig });

  const [metadata] = await bucket.getMetadata();
  const appliedCors = metadata.cors || [];

  console.log(
    JSON.stringify(
      {
        bucket: bucketName,
        message: 'CORS bucket berhasil diperbarui.',
        cors: appliedCors,
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
