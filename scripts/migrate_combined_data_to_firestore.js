/*
 * Migration script: COMBINED DATA NAMA.xlsx -> Firestore
 *
 * Collections written:
 * - users
 * - user_roles
 * - kelas
 * - kelas_siswa
 *
 * Usage:
 * 1) Preview only (no write):
 *    node scripts/migrate_combined_data_to_firestore.js --file "COMBINED DATA NAMA.xlsx"
 *
 * 2) Upload to Firestore:
 *    node scripts/migrate_combined_data_to_firestore.js --file "COMBINED DATA NAMA.xlsx" --upload
 *
 * Optional:
 * - --year 2025_2026
 * - --service-account ./serviceAccountKey.json
 */

const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');
const admin = require('firebase-admin');

const DEFAULT_YEAR = '2025_2026';
const EXIT_NOTE_REGEX = /(mengundurkan|keluar|mutasi|pindah)/i;
const CLASS_NAME_REGEX = /^[789][A-Z]$/;

function parseArgs(argv) {
  const args = argv.slice(2);
  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  return {
    file: getValue('file', 'COMBINED DATA NAMA.xlsx'),
    year: getValue('year', DEFAULT_YEAR),
    upload: args.includes('--upload'),
    serviceAccount: getValue('service-account', null),
  };
}

function normalizeSpaces(value) {
  return String(value ?? '')
    .replace(/\u00A0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function capitalizeToken(token) {
  if (!token) return token;

  // Pertahankan token bertitik (gelar/abreviasi) agar tidak rusak.
  if (token.includes('.')) {
    return token;
  }

  return token
    .split(/([-'])/)
    .map((part) => {
      if (part === '-' || part === "'") return part;
      if (!part) return part;
      const lower = part.toLowerCase();
      return lower.charAt(0).toUpperCase() + lower.slice(1);
    })
    .join('');
}

function normalizeName(rawName) {
  const value = normalizeSpaces(String(rawName ?? '').replace(/`/g, "'"));
  if (!value) return '';

  return value
    .split(' ')
    .map(capitalizeToken)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeNip(raw) {
  const digits = String(raw ?? '').replace(/\D/g, '');
  return digits.length >= 8 ? digits : null;
}

function slugifyName(name) {
  const base = normalizeSpaces(name)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');

  return base || 'user';
}

function createIdentityGenerator(domain = 'school.local') {
  const used = new Map();

  return (name) => {
    const base = slugifyName(name);
    const count = used.get(base) ?? 0;
    used.set(base, count + 1);

    const suffix = count === 0 ? '' : `${count + 1}`;
    const username = `${base}${suffix}`;
    return {
      username,
      email: `${username}@${domain}`,
    };
  };
}

function detectClassHeaderRow(rows) {
  for (let r = 0; r < rows.length; r++) {
    const row = rows[r] ?? [];
    const entries = [];
    for (let c = 0; c < row.length; c++) {
      const value = normalizeSpaces(row[c]).toUpperCase();
      if (CLASS_NAME_REGEX.test(value)) {
        entries.push({ className: value, nameCol: c, genderCol: c + 1, noteCol: c + 2 });
      }
    }
    if (entries.length >= 2) {
      return { rowIndex: r, entries };
    }
  }
  return null;
}

function parseStudentSheets(workbook) {
  const classMap = new Map();

  const kelasSheetNames = workbook.SheetNames.filter((name) =>
    /^KELAS\s+[789]$/i.test(name),
  );

  for (const sheetName of kelasSheetNames) {
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: '',
      raw: false,
    });

    const header = detectClassHeaderRow(rows);
    if (!header) continue;

    for (const entry of header.entries) {
      if (!classMap.has(entry.className)) {
        classMap.set(entry.className, new Map());
      }
    }

    for (let r = header.rowIndex + 1; r < rows.length; r++) {
      const row = rows[r] ?? [];

      for (const entry of header.entries) {
        const rawName = normalizeSpaces(row[entry.nameCol]);
        if (!rawName) continue;

        const upperName = rawName.toUpperCase();
        if (upperName.includes('NAMA PESERTA DIDIK') || CLASS_NAME_REGEX.test(upperName)) {
          continue;
        }

        const note = normalizeSpaces(row[entry.noteCol]);
        if (note && EXIT_NOTE_REGEX.test(note)) {
          continue;
        }

        const nama = normalizeName(rawName);
        if (!nama) continue;

        const genderRaw = normalizeSpaces(row[entry.genderCol]).toUpperCase();
        const gender = genderRaw === 'P' ? 'P' : genderRaw === 'L' ? 'L' : null;

        const dedupeKey = nama.toLowerCase();
        const classStudents = classMap.get(entry.className);
        if (!classStudents.has(dedupeKey)) {
          classStudents.set(dedupeKey, {
            nama,
            gender,
            kelas: entry.className,
          });
        }
      }
    }
  }

  const classes = [...classMap.keys()].sort((a, b) => a.localeCompare(b));
  const students = classes.flatMap((kelas) => {
    const rows = [...classMap.get(kelas).values()];
    rows.sort((a, b) => a.nama.localeCompare(b.nama, 'id'));
    return rows;
  });

  return { classes, students };
}

function parseGuruSheet(workbook) {
  const sheet = workbook.Sheets.GURU;
  if (!sheet) {
    return [];
  }

  const rows = XLSX.utils.sheet_to_json(sheet, {
    header: 1,
    defval: '',
    raw: false,
  });

  const teacherMap = new Map();

  for (const row of rows) {
    const no = normalizeSpaces(row[0]);
    if (!/^\d+$/.test(no)) {
      continue;
    }

    const nama = normalizeName(row[1]);
    if (!nama) {
      continue;
    }

    const nip = normalizeNip(row[2]);
    const key = nip ? `nip:${nip}` : `nama:${nama.toLowerCase()}`;
    if (teacherMap.has(key)) {
      continue;
    }

    teacherMap.set(key, {
      nama,
      nip,
    });
  }

  const teachers = [...teacherMap.values()];
  teachers.sort((a, b) => a.nama.localeCompare(b.nama, 'id'));
  return teachers;
}

function floorForClass(className) {
  const grade = String(className).charAt(0);
  if (grade === '7') return 1;
  if (grade === '8') return 2;
  if (grade === '9') return 3;
  return 1;
}

function transformData(workbook, tahunAjaranId) {
  const { classes, students } = parseStudentSheets(workbook);
  const teachers = parseGuruSheet(workbook);

  const nextIdentity = createIdentityGenerator('school.local');

  const kelasRows = classes.map((namaKelas) => ({
    nama_kelas: namaKelas,
    lantai: floorForClass(namaKelas),
    wali_kelas_uid: null,
    tahun_ajaran_id: tahunAjaranId,
  }));

  const teacherUsers = teachers.map((teacher) => {
    const identity = nextIdentity(teacher.nama);
    return {
      source: 'teacher',
      nama: teacher.nama,
      nip: teacher.nip,
      ...identity,
      role: 'guru',
    };
  });

  const studentUsers = students.map((student) => {
    const identity = nextIdentity(student.nama);
    return {
      source: 'student',
      nama: student.nama,
      nip: null,
      kelas: student.kelas,
      gender: student.gender,
      ...identity,
      role: 'siswa',
    };
  });

  return {
    tahunAjaranId,
    kelasRows,
    teacherUsers,
    studentUsers,
  };
}

function buildPreview(transformed) {
  const studentByClass = transformed.studentUsers.reduce((acc, row) => {
    if (!acc[row.kelas]) acc[row.kelas] = [];
    acc[row.kelas].push(row.nama);
    return acc;
  }, {});

  for (const kelas of Object.keys(studentByClass)) {
    studentByClass[kelas].sort((a, b) => a.localeCompare(b, 'id'));
  }

  return {
    summary: {
      kelasCount: transformed.kelasRows.length,
      teacherCount: transformed.teacherUsers.length,
      studentCount: transformed.studentUsers.length,
      userCount: transformed.teacherUsers.length + transformed.studentUsers.length,
      roleCount: transformed.teacherUsers.length + transformed.studentUsers.length,
      kelasSiswaCount: transformed.studentUsers.length,
      tahunAjaranId: transformed.tahunAjaranId,
    },
    kelas: transformed.kelasRows,
    teachersPreview: transformed.teacherUsers.slice(0, 12),
    studentsPreview: transformed.studentUsers.slice(0, 20),
    studentsByClassCount: Object.fromEntries(
      Object.entries(studentByClass).map(([kelas, names]) => [kelas, names.length]),
    ),
  };
}

function initFirebase(serviceAccountPath) {
  if (admin.apps.length > 0) {
    return admin.firestore();
  }

  if (serviceAccountPath) {
    const absolutePath = path.resolve(serviceAccountPath);
    const serviceAccount = JSON.parse(fs.readFileSync(absolutePath, 'utf8'));
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });
    return admin.firestore();
  }

  admin.initializeApp();
  return admin.firestore();
}

async function uploadToFirestore(db, transformed) {
  const ts = admin.firestore.FieldValue.serverTimestamp();

  let batch = db.batch();
  let opCount = 0;
  const commitPromises = [];

  const queueSet = (ref, data) => {
    if (opCount >= 500) {
      commitPromises.push(batch.commit());
      batch = db.batch();
      opCount = 0;
    }

    batch.set(ref, data, { merge: false });
    opCount += 1;
  };

  const baseMeta = {
    createdAt: ts,
    updatedAt: ts,
    deletedAt: null,
    isDeleted: false,
  };

  const kelasIdByName = new Map();
  for (const kelas of transformed.kelasRows) {
    const kelasRef = db.collection('kelas').doc();
    kelasIdByName.set(kelas.nama_kelas, kelasRef.id);

    queueSet(kelasRef, {
      ...kelas,
      ...baseMeta,
    });
  }

  for (const teacher of transformed.teacherUsers) {
    const userRef = db.collection('users').doc();
    const uid = userRef.id;

    queueSet(userRef, {
      uid,
      nama: teacher.nama,
      email: teacher.email,
      username: teacher.username,
      password: null,
      nip: teacher.nip,
      status: 'aktif',
      active: true,
      ...baseMeta,
    });

    const roleRef = db.collection('user_roles').doc();
    queueSet(roleRef, {
      uid,
      role: 'guru',
      ...baseMeta,
    });
  }

  for (const student of transformed.studentUsers) {
    const userRef = db.collection('users').doc();
    const uid = userRef.id;

    queueSet(userRef, {
      uid,
      nama: student.nama,
      email: student.email,
      username: student.username,
      password: null,
      nip: null,
      status: 'aktif',
      active: true,
      ...baseMeta,
    });

    const roleRef = db.collection('user_roles').doc();
    queueSet(roleRef, {
      uid,
      role: 'siswa',
      ...baseMeta,
    });

    const kelasId = kelasIdByName.get(student.kelas);
    if (!kelasId) {
      throw new Error(`kelas_id tidak ditemukan untuk kelas ${student.kelas}`);
    }

    const kelasSiswaRef = db.collection('kelas_siswa').doc();
    queueSet(kelasSiswaRef, {
      siswa_id: uid,
      kelas_id: kelasId,
      tahun_ajaran_id: transformed.tahunAjaranId,
      status: 'aktif',
      ...baseMeta,
    });
  }

  if (opCount > 0) {
    commitPromises.push(batch.commit());
  }

  await Promise.all(commitPromises);

  return {
    kelasWritten: transformed.kelasRows.length,
    usersWritten: transformed.teacherUsers.length + transformed.studentUsers.length,
    userRolesWritten: transformed.teacherUsers.length + transformed.studentUsers.length,
    kelasSiswaWritten: transformed.studentUsers.length,
  };
}

async function main() {
  const opts = parseArgs(process.argv);
  const filePath = path.resolve(opts.file);

  if (!fs.existsSync(filePath)) {
    throw new Error(`File Excel tidak ditemukan: ${filePath}`);
  }

  const workbook = XLSX.readFile(filePath);
  const transformed = transformData(workbook, opts.year);
  const preview = buildPreview(transformed);

  const outputDir = path.resolve('scripts', 'output');
  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(
    path.join(outputDir, 'combined_data.transformed.json'),
    JSON.stringify(transformed, null, 2),
    'utf8',
  );
  fs.writeFileSync(
    path.join(outputDir, 'combined_data.preview.json'),
    JSON.stringify(preview, null, 2),
    'utf8',
  );

  console.log('Parsed JSON preview:');
  console.log(JSON.stringify(preview, null, 2));
  console.log(
    `\nTransformed file saved: ${path.join('scripts', 'output', 'combined_data.transformed.json')}`,
  );
  console.log(`Preview file saved: ${path.join('scripts', 'output', 'combined_data.preview.json')}`);

  if (!opts.upload) {
    console.log('\nDry-run selesai. Tambahkan --upload untuk menulis ke Firestore.');
    return;
  }

  const db = initFirebase(opts.serviceAccount);
  const result = await uploadToFirestore(db, transformed);

  console.log('\nUpload selesai:');
  console.log(JSON.stringify(result, null, 2));
}

main().catch((err) => {
  console.error('Migration failed:', err.message);
  process.exitCode = 1;
});
