/*
 * Migrate jurnal docs from legacy jam_ke to jam_awal/jam_akhir.
 *
 * Default mode: dry-run (no writes)
 * Apply mode  : add --apply
 *
 * Usage:
 * node scripts/migrate_jurnal_to_jam_range.js --service-account ./serviceAccountKey.json
 * node scripts/migrate_jurnal_to_jam_range.js --service-account ./serviceAccountKey.json --apply
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

function parseIntOrNull(value) {
	if (value == null) return null;
	if (typeof value === 'number') return Number.isFinite(value) ? Math.trunc(value) : null;
	const parsed = parseInt(String(value), 10);
	return Number.isNaN(parsed) ? null : parsed;
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
			batch.update(op.ref, op.payload);
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
	console.log('Jurnal migration to jam range');
	console.log(`Mode    : ${args.apply ? 'APPLY' : 'DRY-RUN'}`);
	console.log(`Project : ${args.projectId || '(default credentials project)'}`);
	console.log('='.repeat(80));

	const snapshot = await db.collection('jurnal').get();
	console.log(`Fetched jurnal docs: ${snapshot.size}`);

	const operations = [];
	const stats = {
		migratedFromLegacy: 0,
		filledMissingAkhir: 0,
		cleanedLegacyOnly: 0,
		invalidSkipped: 0,
	};
	const invalidDocs = [];

	for (const doc of snapshot.docs) {
		const data = doc.data() || {};
		const jamKe = parseIntOrNull(data.jam_ke ?? data.jamKe);
		const jamAwal = parseIntOrNull(data.jam_awal ?? data.jamAwal);
		const jamAkhir = parseIntOrNull(data.jam_akhir ?? data.jamAkhir);

		let nextAwal = jamAwal;
		let nextAkhir = jamAkhir;
		let needsWrite = false;

		if (nextAwal == null && jamKe != null) {
			nextAwal = jamKe;
			nextAkhir = jamKe;
			stats.migratedFromLegacy += 1;
			needsWrite = true;
		} else if (nextAwal != null && nextAkhir == null) {
			nextAkhir = nextAwal;
			stats.filledMissingAkhir += 1;
			needsWrite = true;
		}

		if (nextAwal == null || nextAkhir == null) {
			stats.invalidSkipped += 1;
			invalidDocs.push(doc.id);
			continue;
		}

		if (nextAwal > nextAkhir) {
			const tmp = nextAwal;
			nextAwal = nextAkhir;
			nextAkhir = tmp;
			needsWrite = true;
		}

		if (jamKe != null) {
			stats.cleanedLegacyOnly += 1;
			needsWrite = true;
		}

		if (!needsWrite) {
			continue;
		}

		operations.push({
			ref: doc.ref,
			payload: {
				jam_awal: nextAwal,
				jam_akhir: nextAkhir,
				jam_ke: admin.firestore.FieldValue.delete(),
				jamKe: admin.firestore.FieldValue.delete(),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			},
		});
	}

	console.log('-'.repeat(80));
	console.log(`Migrated from jam_ke     : ${stats.migratedFromLegacy}`);
	console.log(`Filled missing jam_akhir : ${stats.filledMissingAkhir}`);
	console.log(`Legacy jam_ke cleaned    : ${stats.cleanedLegacyOnly}`);
	console.log(`Invalid skipped          : ${stats.invalidSkipped}`);
	console.log(`Planned writes           : ${operations.length}`);

	if (invalidDocs.length > 0) {
		console.log('Invalid sample (max 10):');
		for (const id of invalidDocs.slice(0, 10)) {
			console.log(`- ${id}`);
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

