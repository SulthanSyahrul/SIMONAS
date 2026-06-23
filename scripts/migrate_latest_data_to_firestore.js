/*
 * Full reset + import script: COMBINED DATA NAMA.xlsx -> Firestore
 *
 * Collections reset:
 * - users
 * - user_roles
 * - guru
 * - siswa
 * - kelas
 * - kelas_siswa
 * - histori_kelas_siswa
 *
 * Tahun ajaran behavior:
 * - Existing tahun_ajaran docs are kept
 * - Any active tahun_ajaran is deactivated
 * - Requested tahun ajaran is upserted as the only active record
 *
 * Usage:
 * 1) Dry-run preview (no write)
 *    node scripts/migrate_latest_data_to_firestore.js --file "COMBINED DATA NAMA.xlsx"
 *
 * 2) Reset + upload
 *    node scripts/migrate_latest_data_to_firestore.js --file "COMBINED DATA NAMA.xlsx" --upload --service-account ./serviceAccountKey.json
 *
 * Optional:
 * - --year 2025_2026
 * - --semester 1
 * - --domain school.local
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const XLSX = require('xlsx');
const admin = require('firebase-admin');

const DEFAULT_YEAR = '2025_2026';
const DEFAULT_SEMESTER = 1;
const DEFAULT_DOMAIN = 'school.local';
const DEFAULT_PASSWORD_INPUT = '12345';
const SOURCE_FILE_FALLBACK = 'COMBINED DATA NAMA.xlsx';

const PASSWORD_SALT = 'smpnegeri1jenarjaya3kali';
const HASH_ITERATIONS = 3;
const HASH_PREFIX = 'sha256$';

const SURONO_ACCESS_ROLES = ['kepala_sekolah', 'guru', 'kemahasiswaan', 'siswa'];
const RESET_COLLECTIONS = [
  'user_roles',
  'kelas_siswa',
  'histori_kelas_siswa',
  'guru',
  'siswa',
  'users',
  'kelas',
];
const FIXED_CLASS_NAMES = [
  '7A', '7B', '7C', '7D', '7E', '7F',
  '8A', '8B', '8C', '8D', '8E', '8F',
  '9A', '9B', '9C', '9D', '9E', '9F',
];

const EXIT_NOTE_REGEX = /(mengundurkan|keluar|mutasi|pindah)/i;
const CLASS_NAME_REGEX = /^[789][A-Z]$/;
const CLASS_SHEET_REGEX = /^KELAS\s+[789]$/i;

function hashPassword(rawPassword) {
  let value = String(rawPassword ?? '');

  for (let i = 0; i < HASH_ITERATIONS; i++) {
    value = crypto
      .createHash('sha256')
      .update(`${value}${PASSWORD_SALT}`, 'utf8')
      .digest('hex');
  }

  return `${HASH_PREFIX}${value}`;
}

const DEFAULT_PASSWORD_HASH = hashPassword(DEFAULT_PASSWORD_INPUT);

function parseArgs(argv) {
  const args = argv.slice(2);

  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  return {
    file: getValue('file', SOURCE_FILE_FALLBACK),
    year: getValue('year', DEFAULT_YEAR),
    semester: Number(getValue('semester', String(DEFAULT_SEMESTER))) || DEFAULT_SEMESTER,
    domain: getValue('domain', DEFAULT_DOMAIN),
    upload: args.includes('--upload'),
    skipReset: args.includes('--skip-reset'),
    serviceAccount: getValue('service-account', null),
  };
}

function normalizeSpaces(value) {
  return String(value ?? '')
    .replace(/\u00A0/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function stripAccents(value) {
  return normalizeSpaces(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function capitalizeToken(token) {
  if (!token) return token;

  return token
    .split(/([-'])/)
    .map((part) => {
      if (part === '-' || part === "'") return part;
      if (!part) return part;
      const lowered = part.toLowerCase();
      return lowered.charAt(0).toUpperCase() + lowered.slice(1);
    })
    .join('');
}

function normalizeName(rawName) {
  const value = normalizeSpaces(String(rawName ?? '').replace(/`/g, "'"));
  if (!value) {
    return '';
  }

  return value
    .split(' ')
    .map(capitalizeToken)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeDigits(rawValue) {
  const digits = String(rawValue ?? '').replace(/\D/g, '');
  return digits || null;
}

function normalizeNip(rawValue) {
  const digits = normalizeDigits(rawValue);
  if (!digits) {
    return null;
  }

  return digits.length >= 8 ? digits : null;
}

function normalizeGender(rawValue) {
  const value = normalizeSpaces(rawValue).toUpperCase();
  if (value === 'L' || value === 'P') {
    return value;
  }
  return null;
}

function parseDate(rawValue) {
  const value = normalizeSpaces(rawValue)
    .replace(/\./g, '-')
    .replace(/\//g, '-');

  if (!value) {
    return null;
  }

  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const [year, month, day] = value.split('-').map(Number);
    return buildUtcDate(year, month, day);
  }

  const match = value.match(/^(\d{1,2})-(\d{1,2})-(\d{2,4})$/);
  if (!match) {
    return null;
  }

  const day = Number(match[1]);
  const month = Number(match[2]);
  let year = Number(match[3]);
  if (year < 100) {
    year += year >= 70 ? 1900 : 2000;
  }

  return buildUtcDate(year, month, day);
}

function buildUtcDate(year, month, day) {
  if (!year || !month || !day) {
    return null;
  }

  const date = new Date(Date.UTC(year, month - 1, day));
  if (Number.isNaN(date.getTime())) {
    return null;
  }

  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }

  return date;
}

function normalizeComparableName(value) {
  return stripAccents(value)
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function firstWordToken(name) {
  const tokens = normalizeSpaces(name).split(' ').filter(Boolean);
  return tokens[0] ?? '';
}

function sanitizeUsernameToken(token) {
  return stripAccents(token)
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function normalizedFirstWord(name) {
  return sanitizeUsernameToken(firstWordToken(name));
}

function stableId(prefix, ...parts) {
  const raw = parts
    .map((part) => normalizeSpaces(part))
    .filter(Boolean)
    .join('|');
  const digest = crypto.createHash('sha1').update(raw || prefix, 'utf8').digest('hex').slice(0, 24);
  return `${prefix}_${digest}`;
}

function createIdentityGenerator(domain) {
  const usedUsernames = new Map();

  return (fullName) => {
    const firstWord = firstWordToken(fullName);
    const base = sanitizeUsernameToken(firstWord) || 'user';
    const count = usedUsernames.get(base) ?? 0;
    usedUsernames.set(base, count + 1);

    const username = count === 0 ? base : `${base}${count + 1}`;
    return {
      username,
      email: `${username}@${domain}`,
    };
  };
}

function detectClassHeaderRow(rows) {
  for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
    const row = rows[rowIndex] ?? [];
    const entries = [];

    for (let colIndex = 0; colIndex < row.length; colIndex += 1) {
      const value = normalizeSpaces(row[colIndex]).toUpperCase();
      if (!CLASS_NAME_REGEX.test(value)) {
        continue;
      }

      entries.push({
        className: value,
        classCol: colIndex,
        nisCol: colIndex,
        nameCol: colIndex + 1,
        genderCol: colIndex + 2,
      });
    }

    if (entries.length < 2) {
      continue;
    }

    const prevRow = rows[rowIndex - 1] ?? [];
    const hasNameHeader = entries.some((entry) => {
      return normalizeSpaces(prevRow[entry.nameCol]).toUpperCase() === 'NAMA PESERTA DIDIK';
    });

    if (!hasNameHeader) {
      continue;
    }

    const normalizedEntries = entries.map((entry, entryIndex) => {
      const nextEntry = entries[entryIndex + 1];
      const noteCols = [];
      const noteStart = entry.genderCol + 1;
      const noteEnd = (nextEntry ? nextEntry.classCol : row.length) - 1;

      for (let colIndex = noteStart; colIndex <= noteEnd; colIndex += 1) {
        noteCols.push(colIndex);
      }

      return {
        ...entry,
        noteCols,
      };
    });

    return {
      rowIndex,
      entries: normalizedEntries,
    };
  }

  return null;
}

function parseStudentSheets(workbook) {
  const studentsByClass = new Map();
  const seenNis = new Set();

  const classSheetNames = workbook.SheetNames.filter((name) => CLASS_SHEET_REGEX.test(name));

  for (const sheetName of classSheetNames) {
    const sheet = workbook.Sheets[sheetName];
    const rows = XLSX.utils.sheet_to_json(sheet, {
      header: 1,
      defval: '',
      raw: false,
    });

    const header = detectClassHeaderRow(rows);
    if (!header) {
      continue;
    }

    for (const entry of header.entries) {
      if (!studentsByClass.has(entry.className)) {
        studentsByClass.set(entry.className, new Map());
      }
    }

    for (let rowIndex = header.rowIndex + 1; rowIndex < rows.length; rowIndex += 1) {
      const row = rows[rowIndex] ?? [];

      for (const entry of header.entries) {
        const nama = normalizeName(row[entry.nameCol]);
        if (!nama) {
          continue;
        }

        const upperName = nama.toUpperCase();
        if (upperName.includes('NAMA PESERTA DIDIK') || CLASS_NAME_REGEX.test(upperName)) {
          continue;
        }

        const hasExitNote = entry.noteCols.some((colIndex) => {
          const note = normalizeSpaces(row[colIndex]);
          return EXIT_NOTE_REGEX.test(note);
        });
        if (hasExitNote) {
          continue;
        }

        const nis = normalizeDigits(row[entry.nisCol]);
        if (nis && seenNis.has(nis)) {
          continue;
        }

        const gender = normalizeGender(row[entry.genderCol]);
        const classKey = studentsByClass.get(entry.className);
        const dedupeKey = nis ? `nis:${nis}` : `name:${normalizeComparableName(nama)}`;

        if (classKey.has(dedupeKey)) {
          continue;
        }

        classKey.set(dedupeKey, {
          nama,
          nis,
          gender,
          kelas: entry.className,
        });

        if (nis) {
          seenNis.add(nis);
        }
      }
    }
  }

  const classes = [...studentsByClass.keys()].sort((left, right) => left.localeCompare(right));
  const students = classes.flatMap((kelas) => {
    const rows = [...studentsByClass.get(kelas).values()];
    rows.sort((left, right) => left.nama.localeCompare(right.nama, 'id'));
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

  const teachers = new Map();
  const seenNip = new Set();

  for (const row of rows) {
    const rowNo = normalizeSpaces(row[0]);
    if (!/^\d+$/.test(rowNo)) {
      continue;
    }

    const nama = normalizeName(row[1]);
    if (!nama) {
      continue;
    }

    const nip = normalizeNip(row[2]);
    const nuptk = normalizeNip(row[3]);

    if (nip && seenNip.has(nip)) {
      continue;
    }

    const key = nip
      ? `nip:${nip}`
      : nuptk
        ? `nuptk:${nuptk}`
        : `name:${normalizeComparableName(nama)}`;

    if (teachers.has(key)) {
      continue;
    }

    teachers.set(key, {
      nama,
      nip,
      nuptk,
      gender: normalizeGender(row[4]),
      tempatLahir: normalizeSpaces(row[5]) || null,
      tanggalLahir: parseDate(row[6]),
      statusPegawai: normalizeSpaces(row[7]) || null,
      golongan: normalizeSpaces(row[8]) || null,
      alamat: normalizeSpaces(row[21]) || null,
    });

    if (nip) {
      seenNip.add(nip);
    }
  }

  return [...teachers.values()].sort((left, right) => left.nama.localeCompare(right.nama, 'id'));
}

function parseTuSheet(workbook) {
  const sheet = workbook.Sheets.TU;
  if (!sheet) {
    return [];
  }

  const rows = XLSX.utils.sheet_to_json(sheet, {
    header: 1,
    defval: '',
    raw: false,
  });

  const staffMembers = new Map();
  const seenNip = new Set();

  for (const row of rows) {
    const rowNo = normalizeSpaces(row[0]);
    if (!/^\d+$/.test(rowNo)) {
      continue;
    }

    const nama = normalizeName(row[1]);
    if (!nama) {
      continue;
    }

    const nip = normalizeNip(row[2]);
    const nuptk = normalizeNip(row[3]);

    if (nip && seenNip.has(nip)) {
      continue;
    }

    const key = nip
      ? `nip:${nip}`
      : nuptk
        ? `nuptk:${nuptk}`
        : `name:${normalizeComparableName(nama)}`;

    if (staffMembers.has(key)) {
      continue;
    }

    staffMembers.set(key, {
      nama,
      nip,
      nuptk,
      gender: normalizeGender(row[4]),
      tempatLahir: normalizeSpaces(row[5]) || null,
      tanggalLahir: parseDate(row[6]),
      statusPegawai: normalizeSpaces(row[7]) || null,
      golongan: normalizeSpaces(row[8]) || null,
      alamat: normalizeSpaces(row[19]) || null,
    });

    if (nip) {
      seenNip.add(nip);
    }
  }

  return [...staffMembers.values()].sort((left, right) => left.nama.localeCompare(right.nama, 'id'));
}

function toYearName(yearId) {
  return normalizeSpaces(yearId).replace(/_/g, '/');
}

function createBaseAccount(person, nextIdentity) {
  const identity = nextIdentity(person.nama);
  return {
    uid: null,
    sourceKey: null,
    nama: person.nama,
    username: identity.username,
    email: identity.email,
    password: DEFAULT_PASSWORD_HASH,
    status: 'aktif',
    active: true,
    roles: new Set(),
    guruProfile: null,
    siswaProfile: null,
  };
}

function resolveLegacyPrimaryRole(roles) {
  const roleSet = new Set(
    [...roles]
      .map((role) => normalizeSpaces(role).toLowerCase())
      .filter(Boolean),
  );

  if (roleSet.has('kepala_sekolah')) {
    return 'kepsek';
  }
  if (roleSet.has('kemahasiswaan')) {
    return 'kemahasiswaan';
  }
  if (roleSet.has('guru')) {
    return 'guru';
  }
  if (roleSet.has('siswa')) {
    return 'siswa';
  }
  return 'guru';
}

function buildTeacherTuAccountMap(teachers, staffMembers, nextIdentity) {
  const accounts = new Map();

  const accountKeyForPerson = (person) => {
    if (person.nip) return `nip:${person.nip}`;
    if (person.nuptk) return `nuptk:${person.nuptk}`;
    return `name:${normalizeComparableName(person.nama)}`;
  };

  for (const teacher of teachers) {
    const key = accountKeyForPerson(teacher);
    const existing = accounts.get(key) ?? createBaseAccount(teacher, nextIdentity);

    existing.sourceKey = key;
    existing.roles.add('guru');
    existing.guruProfile = {
      uid: null,
      nip: teacher.nip,
      nuptk: teacher.nuptk,
      gender: teacher.gender,
      tempat_lahir: teacher.tempatLahir,
      tanggal_lahir: teacher.tanggalLahir,
      golongan: teacher.golongan,
      alamat: teacher.alamat,
      status_pegawai: teacher.statusPegawai,
    };

    if (normalizedFirstWord(teacher.nama) === 'surono') {
      for (const role of SURONO_ACCESS_ROLES) {
        existing.roles.add(role);
      }
      existing.siswaProfile = existing.siswaProfile ?? {
        uid: null,
        nis: null,
        gender: teacher.gender,
        tempat_lahir: null,
        tanggal_lahir: null,
        alamat: null,
      };
    } else if (!existing.roles.has('kepala_sekolah') && /surono/i.test(teacher.nama)) {
      existing.roles.add('kepala_sekolah');
    }

    accounts.set(key, existing);
  }

  for (const staffMember of staffMembers) {
    const key = accountKeyForPerson(staffMember);
    const existing = accounts.get(key) ?? createBaseAccount(staffMember, nextIdentity);

    existing.sourceKey = key;
    existing.roles.add('kemahasiswaan');
    accounts.set(key, existing);
  }

  return accounts;
}

function transformData(workbook, opts) {
  const { classes, students } = parseStudentSheets(workbook);
  const teachers = parseGuruSheet(workbook);
  const staffMembers = parseTuSheet(workbook);
  const nextIdentity = createIdentityGenerator(opts.domain);
  const classSet = new Set([...FIXED_CLASS_NAMES, ...classes]);

  const teacherAndStaffAccounts = buildTeacherTuAccountMap(teachers, staffMembers, nextIdentity);
  const studentAccounts = students.map((student) => {
    const identity = nextIdentity(student.nama);
    const roles = ['siswa'];
    return {
      uid: stableId('usr', 'siswa', student.nis || `${student.kelas}|${student.nama}`),
      nama: student.nama,
      username: identity.username,
      email: identity.email,
      password: DEFAULT_PASSWORD_HASH,
      role: resolveLegacyPrimaryRole(roles),
      status: 'aktif',
      active: true,
      roles,
      kelas: student.kelas,
      sourceKey: student.nis || `${student.kelas}|${student.nama}`,
      siswaProfile: {
        uid: null,
        nis: student.nis,
        gender: student.gender,
        tempat_lahir: null,
        tanggal_lahir: null,
        alamat: null,
      },
    };
  });

  const kelasRows = [...classSet].sort((left, right) => left.localeCompare(right)).map((namaKelas) => {
    const tingkat = Number(String(namaKelas).charAt(0)) || null;
    return {
      id: `${opts.year}_${namaKelas.toLowerCase()}`,
      nama_kelas: namaKelas,
      tingkat,
      wali_kelas_uid: null,
      tahun_ajaran_id: opts.year,
    };
  });

  const teacherAndStaffUsers = [...teacherAndStaffAccounts.values()]
    .map((account) => ({
      uid: stableId('usr', 'staff', account.sourceKey || account.nama),
      nama: account.nama,
      username: account.username,
      email: account.email,
      password: account.password,
      role: resolveLegacyPrimaryRole(account.roles),
      status: account.status,
      active: account.active,
      roles: [...account.roles].sort(),
      guruProfile: account.guruProfile,
      siswaProfile: account.siswaProfile,
    }))
    .sort((left, right) => left.nama.localeCompare(right.nama, 'id'));

  const tahunAjaranRow = {
    id: opts.year,
    nama: toYearName(opts.year),
    aktif: true,
    semester_aktif: opts.semester,
  };

  const roleCount = teacherAndStaffUsers.reduce((sum, row) => sum + row.roles.length, 0)
    + studentAccounts.reduce((sum, row) => sum + row.roles.length, 0);

  return {
    sourceFile: path.basename(opts.file),
    skipReset: opts.skipReset,
    tahunAjaranRow,
    kelasRows,
    teacherAndStaffUsers,
    studentUsers: studentAccounts,
    summary: {
      totalSiswa: studentAccounts.length,
      totalGuru: teachers.length,
      totalKemahasiswaan: staffMembers.length,
      totalClasses: kelasRows.length,
      totalUserRoles: roleCount,
      totalUsers: teacherAndStaffUsers.length + studentAccounts.length,
      totalGuruProfiles: teacherAndStaffUsers.filter((row) => row.guruProfile).length,
      totalSiswaProfiles:
        studentAccounts.length + teacherAndStaffUsers.filter((row) => row.siswaProfile).length,
      totalHistoriKelasSiswa: studentAccounts.length,
      suronoRoles:
        teacherAndStaffUsers.find((row) => normalizedFirstWord(row.nama) === 'surono')
          ?.roles ?? [],
    },
  };
}

function buildPreview(transformed) {
  const studentsByClassCount = transformed.studentUsers.reduce((acc, row) => {
    if (!acc[row.kelas]) {
      acc[row.kelas] = 0;
    }
    acc[row.kelas] += 1;
    return acc;
  }, {});

  return {
    summary: {
      sourceFile: transformed.sourceFile,
      tahunAjaranId: transformed.tahunAjaranRow.id,
      tahunAjaranNama: transformed.tahunAjaranRow.nama,
      semesterAktif: transformed.tahunAjaranRow.semester_aktif,
      defaultPasswordInput: DEFAULT_PASSWORD_INPUT,
      defaultPasswordHash: DEFAULT_PASSWORD_HASH,
      passwordHashPrefix: HASH_PREFIX,
      passwordHashIterations: HASH_ITERATIONS,
      totalSiswa: transformed.summary.totalSiswa,
      totalGuru: transformed.summary.totalGuru,
      totalKemahasiswaan: transformed.summary.totalKemahasiswaan,
      totalClasses: transformed.summary.totalClasses,
      totalUsers: transformed.summary.totalUsers,
      totalUserRoles: transformed.summary.totalUserRoles,
      totalGuruProfiles: transformed.summary.totalGuruProfiles,
      totalSiswaProfiles: transformed.summary.totalSiswaProfiles,
      totalKelasSiswa: transformed.summary.totalSiswa,
      totalHistoriKelasSiswa: transformed.summary.totalHistoriKelasSiswa,
      suronoRoles: transformed.summary.suronoRoles,
    },
    kelasPreview: transformed.kelasRows,
    guruDanStaffPreview: transformed.teacherAndStaffUsers.slice(0, 12),
    siswaPreview: transformed.studentUsers.slice(0, 20),
    studentsByClassCount,
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

async function resetCollection(db, collectionName, batchSize = 350) {
  let deleted = 0;

  while (true) {
    const snapshot = await db.collection(collectionName).limit(batchSize).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
    deleted += snapshot.size;
  }

  return deleted;
}

async function deactivateActiveYears(db) {
  const snapshot = await db.collection('tahun_ajaran').where('aktif', '==', true).get();
  if (snapshot.empty) {
    return 0;
  }

  let updated = 0;
  let batch = db.batch();
  let opCount = 0;

  for (const doc of snapshot.docs) {
    batch.update(doc.ref, {
      aktif: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    opCount += 1;
    updated += 1;

    if (opCount >= 450) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  return updated;
}

async function uploadToFirestore(db, transformed) {
  const ts = admin.firestore.FieldValue.serverTimestamp();
  const resetCounts = {};

  for (const collectionName of RESET_COLLECTIONS) {
    resetCounts[collectionName] = 0;
  }

  let deactivatedYears = 0;
  if (!transformed.skipReset) {
    for (const collectionName of RESET_COLLECTIONS) {
      resetCounts[collectionName] = await resetCollection(db, collectionName);
    }
    deactivatedYears = await deactivateActiveYears(db);
  }

  let batch = db.batch();
  let opCount = 0;
  const maxBatchOps = 200;

  const flushBatch = async () => {
    if (opCount <= 0) {
      return;
    }

    await batch.commit();
    batch = db.batch();
    opCount = 0;
  };

  const queueSet = (ref, data) => {
    batch.set(ref, data, { merge: false });
    opCount += 1;
  };

  const baseMeta = {
    createdAt: ts,
    updatedAt: ts,
    deletedAt: null,
    isDeleted: false,
  };

  const tahunRef = db.collection('tahun_ajaran').doc(transformed.tahunAjaranRow.id);
  queueSet(tahunRef, {
    nama: transformed.tahunAjaranRow.nama,
    aktif: transformed.tahunAjaranRow.aktif,
    semester_aktif: transformed.tahunAjaranRow.semester_aktif,
    ...baseMeta,
  });
  await flushBatch();

  const kelasIdByName = new Map();
  for (const kelas of transformed.kelasRows) {
    const kelasRef = db.collection('kelas').doc(kelas.id);
    kelasIdByName.set(kelas.nama_kelas, kelas.id);

    queueSet(kelasRef, {
      nama_kelas: kelas.nama_kelas,
      tingkat: kelas.tingkat,
      wali_kelas_uid: kelas.wali_kelas_uid,
      tahun_ajaran_id: kelas.tahun_ajaran_id,
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }
  }

  for (const account of transformed.teacherAndStaffUsers) {
    const uid = account.uid;
    const userRef = db.collection('users').doc(uid);

    queueSet(userRef, {
      uid,
      nama: account.nama,
      email: account.email,
      role: account.role,
      username: account.username,
      password: account.password,
      status: account.status,
      active: account.active,
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }

    for (const role of account.roles) {
      const roleRef = db.collection('user_roles').doc(`${uid}_${role}`);
      queueSet(roleRef, {
        uid,
        role,
        ...baseMeta,
      });

      if (opCount >= maxBatchOps) {
        await flushBatch();
      }
    }

    if (account.guruProfile) {
      const guruRef = db.collection('guru').doc(uid);
      queueSet(guruRef, {
        uid,
        nama: account.nama,
        nip: account.guruProfile.nip,
        nuptk: account.guruProfile.nuptk,
        gender: account.guruProfile.gender,
        tempat_lahir: account.guruProfile.tempat_lahir,
        tanggal_lahir: account.guruProfile.tanggal_lahir,
        golongan: account.guruProfile.golongan,
        alamat: account.guruProfile.alamat,
        ...baseMeta,
      });

      if (opCount >= maxBatchOps) {
        await flushBatch();
      }
    }

    if (account.siswaProfile) {
      const siswaRef = db.collection('siswa').doc(uid);
      queueSet(siswaRef, {
        uid,
        nama: account.nama,
        nis: account.siswaProfile.nis,
        gender: account.siswaProfile.gender,
        tempat_lahir: account.siswaProfile.tempat_lahir,
        tanggal_lahir: account.siswaProfile.tanggal_lahir,
        alamat: account.siswaProfile.alamat,
        ...baseMeta,
      });

      if (opCount >= maxBatchOps) {
        await flushBatch();
      }
    }
  }

  for (const student of transformed.studentUsers) {
    const uid = student.uid;
    const userRef = db.collection('users').doc(uid);

    queueSet(userRef, {
      uid,
      nama: student.nama,
      email: student.email,
      role: student.role,
      username: student.username,
      password: student.password,
      status: student.status,
      active: student.active,
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }

    const roleRef = db.collection('user_roles').doc(`${uid}_siswa`);
    queueSet(roleRef, {
      uid,
      role: 'siswa',
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }

    const siswaRef = db.collection('siswa').doc(uid);
    queueSet(siswaRef, {
      uid,
      nama: student.nama,
      nis: student.siswaProfile.nis,
      gender: student.siswaProfile.gender,
      tempat_lahir: student.siswaProfile.tempat_lahir,
      tanggal_lahir: student.siswaProfile.tanggal_lahir,
      alamat: student.siswaProfile.alamat,
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }

    const kelasId = kelasIdByName.get(student.kelas);
    if (!kelasId) {
      throw new Error(`kelas_id tidak ditemukan untuk kelas ${student.kelas}`);
    }

    const kelasSiswaRef = db.collection('kelas_siswa').doc(
      stableId('ks', uid, kelasId, transformed.tahunAjaranRow.id),
    );
    queueSet(kelasSiswaRef, {
      siswa_id: uid,
      kelas_id: kelasId,
      tahun_ajaran_id: transformed.tahunAjaranRow.id,
      status: 'aktif',
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }

    const historiRef = db.collection('histori_kelas_siswa').doc(
      stableId('hks', 'import_awal', uid, kelasId, transformed.tahunAjaranRow.id),
    );
    queueSet(historiRef, {
      siswa_id: uid,
      kelas_asal_id: null,
      kelas_tujuan_id: kelasId,
      tahun_ajaran_id: transformed.tahunAjaranRow.id,
      aksi: 'import_awal',
      catatan: `Import master data dari ${transformed.sourceFile}`,
      changed_by: 'system_import',
      ...baseMeta,
    });

    if (opCount >= maxBatchOps) {
      await flushBatch();
    }
  }

  await flushBatch();

  return {
    resetCounts,
    deactivatedActiveYears: deactivatedYears,
    tahunAjaranWritten: 1,
    kelasWritten: transformed.kelasRows.length,
    usersWritten: transformed.summary.totalUsers,
    userRolesWritten: transformed.summary.totalUserRoles,
    guruWritten: transformed.summary.totalGuruProfiles,
    siswaWritten: transformed.summary.totalSiswaProfiles,
    kelasSiswaWritten: transformed.summary.totalSiswa,
    historiKelasSiswaWritten: transformed.summary.totalHistoriKelasSiswa,
    passwordHashSample: DEFAULT_PASSWORD_HASH,
    summary: {
      totalSiswa: transformed.summary.totalSiswa,
      totalGuru: transformed.summary.totalGuru,
      totalKemahasiswaan: transformed.summary.totalKemahasiswaan,
      totalClasses: transformed.summary.totalClasses,
      totalUserRoles: transformed.summary.totalUserRoles,
    },
  };
}

async function main() {
  const opts = parseArgs(process.argv);
  const filePath = path.resolve(opts.file);

  if (!fs.existsSync(filePath)) {
    throw new Error(`File Excel tidak ditemukan: ${filePath}`);
  }

  const workbook = XLSX.readFile(filePath);
  const transformed = transformData(workbook, opts);
  const preview = buildPreview(transformed);

  const outputDir = path.resolve('scripts', 'output');
  fs.mkdirSync(outputDir, { recursive: true });

  const transformedPath = path.join(outputDir, 'latest_data.transformed.json');
  const previewPath = path.join(outputDir, 'latest_data.preview.json');

  fs.writeFileSync(transformedPath, JSON.stringify(transformed, null, 2), 'utf8');
  fs.writeFileSync(previewPath, JSON.stringify(preview, null, 2), 'utf8');

  console.log('Parsed JSON preview:');
  console.log(JSON.stringify(preview, null, 2));
  console.log(`\nTransformed file saved: ${transformedPath}`);
  console.log(`Preview file saved: ${previewPath}`);

  if (!opts.upload) {
    console.log('\nDry-run selesai. Tambahkan --upload untuk reset dan menulis ke Firestore.');
    return;
  }

  const db = initFirebase(opts.serviceAccount);
  const result = await uploadToFirestore(db, transformed);

  console.log('\nReset + upload selesai:');
  console.log(JSON.stringify(result, null, 2));
}

main().catch((err) => {
  console.error('Migration failed:', err.message);
  process.exitCode = 1;
});
