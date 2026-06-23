/*
 * Bulk import all school data into Supabase.
 *
 * Tables used from supabase/migrations/001_create_schema.sql:
 * - auth.users
 * - public.users
 * - public.roles
 * - public.user_roles
 * - public.guru
 * - public.siswa
 * - public.tahun_ajaran
 * - public.kelas
 * - public.kelas_siswa
 *
 * Default credentials:
 * - username: first name from the source row
 * - password: 12345
 *
 * Usage:
 *   node scripts/import_all_data_to_supabase.js
 *   node scripts/import_all_data_to_supabase.js --apply
 *   node scripts/import_all_data_to_supabase.js --guru guru.csv --kelas7 "kelas 7.csv" --kelas8 "kelas 8.csv" --kelas9 "kelas 9.csv" --tahun-ajaran 2025_2026 --apply
 *
 * Required env vars:
 * - SUPABASE_URL
 * - SUPABASE_SERVICE_ROLE_KEY
 */

const fs = require('fs');
const path = require('path');

require('dotenv').config();

const XLSX = require('xlsx');
const { createClient } = require('@supabase/supabase-js');

const DEFAULT_PASSWORD = '12345';
const DEFAULT_DOMAIN = 'smpn1jenar.local';
const DEFAULT_TAHUN_AJARAN = '2025_2026';
const GURU_ROLE = 'guru';
const STUDENT_ROLE = 'siswa';
const HEADMASTER_ROLE = 'kepala_sekolah';
const STUDENT_AFFAIRS_ROLE = 'kesiswaan';

const EXIT_NOTE_REGEX = /(mengundurkan|keluar|mutasi|pindah)/i;
const CLASS_NAME_REGEX = /^[789][A-F]$/;

function parseArgs(argv) {
  const args = argv.slice(2);

  const getValue = (name, fallback = null) => {
    const idx = args.indexOf(`--${name}`);
    if (idx < 0) return fallback;
    return args[idx + 1] ?? fallback;
  };

  return {
    apply: args.includes('--apply'),
    guruFile: getValue('guru', 'guru.csv'),
    kelas7File: getValue('kelas7', 'kelas 7.csv'),
    kelas8File: getValue('kelas8', 'kelas 8.csv'),
    kelas9File: getValue('kelas9', 'kelas 9.csv'),
    tahunAjaran: getValue('tahun-ajaran', DEFAULT_TAHUN_AJARAN),
    password: getValue('password', DEFAULT_PASSWORD),
    domain: getValue('domain', DEFAULT_DOMAIN),
  };
}

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Env ${name} wajib diisi.`);
  }
  return value;
}

function normalizeText(value) {
  return String(value ?? '')
    .replace(/\u00A0/g, ' ')
    .replace(/`/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

function removeDiacritics(value) {
  return normalizeText(value)
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '');
}

function slugify(value) {
  const base = removeDiacritics(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '');
  return base || 'user';
}

function toDisplayName(value) {
  const normalized = normalizeText(value);
  if (!normalized) return '';

  return normalized
    .split(' ')
    .map((part) => {
      if (!part) return part;
      if (part.includes('.')) {
        return part
          .split('.')
          .map((piece) => (piece ? piece.charAt(0).toUpperCase() + piece.slice(1).toLowerCase() : piece))
          .join('.');
      }
      const lower = part.toLowerCase();
      return lower.charAt(0).toUpperCase() + lower.slice(1);
    })
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function extractUsernameSeed(fullName) {
  const base = normalizeText(fullName).split(',')[0] || normalizeText(fullName);
  const firstToken = base.split(/\s+/)[0] || base;
  return slugify(firstToken);
}

function uniqueIdentity(seed, state, domain) {
  const base = slugify(seed);
  const nextCount = (state.usernameCounts.get(base) ?? 0) + 1;
  state.usernameCounts.set(base, nextCount);

  const username = nextCount === 1 ? base : `${base}${nextCount}`;
  const email = `${username}@${domain}`;
  return { username, email };
}

function parseDate(value) {
  const text = normalizeText(value);
  if (!text) return null;

  const iso = text.match(/^(\d{4})-(\d{1,2})-(\d{1,2})$/);
  if (iso) {
    const [, year, month, day] = iso;
    return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day))).toISOString();
  }

  const parts = text.match(/^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$/);
  if (!parts) {
    return null;
  }

  const day = Number(parts[1]);
  const month = Number(parts[2]);
  let year = Number(parts[3]);
  if (year < 100) {
    year += year >= 70 ? 1900 : 2000;
  }

  if (!day || !month || !year) {
    return null;
  }

  return new Date(Date.UTC(year, month - 1, day)).toISOString();
}

function parseGender(value) {
  const normalized = normalizeText(value).toUpperCase();
  if (normalized === 'L') return 'Laki-laki';
  if (normalized === 'P') return 'Perempuan';
  return null;
}

function readCsvRows(filePath) {
  const absolutePath = path.resolve(filePath);
  if (!fs.existsSync(absolutePath)) {
    return null;
  }

  const workbook = XLSX.readFile(absolutePath, { raw: false });
  const sheetName = workbook.SheetNames[0];
  if (!sheetName) {
    return [];
  }

  const sheet = workbook.Sheets[sheetName];
  return XLSX.utils.sheet_to_json(sheet, {
    header: 1,
    defval: '',
    raw: false,
  });
}

function detectClassHeaderRow(rows) {
  for (let rowIndex = 0; rowIndex < rows.length; rowIndex += 1) {
    const row = rows[rowIndex] ?? [];
    const entries = [];

    for (let columnIndex = 0; columnIndex < row.length; columnIndex += 1) {
      const value = normalizeText(row[columnIndex]).toUpperCase();
      if (CLASS_NAME_REGEX.test(value)) {
        entries.push({
          className: value,
          nameCol: columnIndex,
          genderCol: columnIndex + 1,
          noteCol: columnIndex + 2,
        });
      }
    }

    if (entries.length >= 2) {
      return { rowIndex, entries };
    }
  }

  return null;
}

function parseStudentFile(filePath) {
  const rows = readCsvRows(filePath);
  if (!rows) {
    return { classes: [], students: [] };
  }

  const header = detectClassHeaderRow(rows);
  if (!header) {
    return { classes: [], students: [] };
  }

  const classMap = new Map();
  for (const entry of header.entries) {
    if (!classMap.has(entry.className)) {
      classMap.set(entry.className, []);
    }
  }

  for (let rowIndex = header.rowIndex + 1; rowIndex < rows.length; rowIndex += 1) {
    const row = rows[rowIndex] ?? [];
    const rowText = normalizeText(row.join(' '));

    for (const entry of header.entries) {
      const rawName = normalizeText(row[entry.nameCol]);
      if (!rawName) {
        continue;
      }

      const upper = rawName.toUpperCase();
      if (upper.includes('NAMA PESERTA DIDIK') || CLASS_NAME_REGEX.test(upper)) {
        continue;
      }

      const note = normalizeText(row[entry.noteCol]);
      if ((note && EXIT_NOTE_REGEX.test(note)) || EXIT_NOTE_REGEX.test(rowText)) {
        continue;
      }

      const gender = parseGender(row[entry.genderCol]);
      const classStudents = classMap.get(entry.className);
      const displayName = toDisplayName(rawName);
      if (!displayName) {
        continue;
      }

      const dedupeKey = `${displayName.toLowerCase()}|${entry.className}`;
      if (classStudents.some((student) => student.dedupeKey === dedupeKey)) {
        continue;
      }

      classStudents.push({
        dedupeKey,
        nama: displayName,
        gender,
        kelas: entry.className,
      });
    }
  }

  const classes = [...classMap.keys()].sort((a, b) => a.localeCompare(b, 'id'));
  const students = classes.flatMap((className) => {
    const items = [...classMap.get(className)];
    items.sort((a, b) => a.nama.localeCompare(b.nama, 'id'));
    return items.map((item) => ({
      nama: item.nama,
      gender: item.gender,
      kelas: className,
    }));
  });

  return { classes, students };
}

function parseGuruFile(filePath) {
  const rows = readCsvRows(filePath);
  if (!rows) {
    return [];
  }

  const teachers = [];
  const seen = new Set();

  for (const row of rows) {
    const no = normalizeText(row[2]);
    if (!/^\d+$/.test(no)) {
      continue;
    }

    const nama = toDisplayName(row[3]);
    if (!nama) {
      continue;
    }

    const nip = normalizeText(row[4]) || null;
    const nuptk = normalizeText(row[5]) || null;
    const gender = parseGender(row[6]);
    const tempatLahir = toDisplayName(row[7]) || null;
    const tanggalLahir = parseDate(row[8]);
    const golongan = normalizeText(row[10]) || null;
    const nipPegawai = normalizeText(row[4]) || null;
    const noHp = null;
    const alamat = normalizeText(row[23]) || null;
    const tugasUtama = normalizeText(row[17]).toUpperCase();
    const tugasTambahan = normalizeText(row[19]).toUpperCase();

    const key = nipPegawai ? `nip:${nipPegawai}` : `nama:${nama.toLowerCase()}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);

    teachers.push({
      nama,
      nip: nipPegawai,
      nuptk,
      gender,
      tempatLahir,
      tanggalLahir,
      golongan,
      noHp,
      alamat,
      tugasUtama,
      tugasTambahan,
    });
  }

  teachers.sort((a, b) => a.nama.localeCompare(b.nama, 'id'));
  return teachers;
}

function inferTeacherRoles(teacher) {
  const text = `${teacher.tugasUtama} ${teacher.tugasTambahan} ${teacher.nama}`.toUpperCase();
  const roles = new Set([GURU_ROLE]);

  if (/KA\s*SEK|KEPALA\s+SEKOLAH|KEPSEK/.test(text)) {
    roles.add(HEADMASTER_ROLE);
  }

  if (/KESISWAAN|BP\s*\/\s*BK|BK/.test(text)) {
    roles.add(STUDENT_AFFAIRS_ROLE);
  }

  return [...roles];
}

function inferStudentRoles() {
  return [STUDENT_ROLE];
}

function getClassLevel(className) {
  const level = Number(String(className).charAt(0));
  return Number.isFinite(level) ? level : 7;
}

async function upsertSingle(supabase, table, payload, onConflict, select = '*') {
  const { data, error } = await supabase
    .from(table)
    .upsert(payload, { onConflict })
    .select(select)
    .single();

  if (error) {
    throw error;
  }

  return data;
}

async function findAuthUserByEmail(supabase, email) {
  const target = email.trim().toLowerCase();
  let page = 1;
  const perPage = 200;

  while (true) {
    const { data, error } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) {
      throw error;
    }

    const users = data?.users ?? [];
    const match = users.find((item) => String(item.email ?? '').trim().toLowerCase() === target);
    if (match) {
      return match;
    }

    if (users.length < perPage) {
      return null;
    }

    page += 1;
  }
}

async function ensureAuthAccount(supabase, state, params) {
  const { email, username, fullName, password } = params;
  const existing = await findAuthUserByEmail(supabase, email);

  if (existing) {
    const { data, error } = await supabase.auth.admin.updateUserById(existing.id, {
      password,
      email_confirm: true,
      user_metadata: {
        username,
        full_name: fullName,
      },
    });

    if (error) {
      throw error;
    }

    state.authUpdated += 1;
    return data.user;
  }

  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: {
      username,
      full_name: fullName,
    },
  });

  if (error) {
    throw error;
  }

  state.authCreated += 1;
  return data.user;
}

async function ensureRole(supabase, roleName, description = null) {
  return upsertSingle(
    supabase,
    'roles',
    {
      role: roleName,
      description,
      is_deleted: false,
    },
    'role',
    'id, role',
  );
}

async function ensureStaticSeed(supabase) {
  const roleSeeds = [
    { role: HEADMASTER_ROLE, description: 'Kepala sekolah' },
    { role: GURU_ROLE, description: 'Guru' },
    { role: STUDENT_AFFAIRS_ROLE, description: 'Kesiswaan / BK' },
    { role: STUDENT_ROLE, description: 'Siswa' },
  ];

  const seededRoles = {};
  for (const role of roleSeeds) {
    seededRoles[role.role] = await ensureRole(supabase, role.role, role.description);
  }

  return seededRoles;
}

async function ensureTahunAjaran(supabase, tahunAjaran) {
  return upsertSingle(
    supabase,
    'tahun_ajaran',
    {
      tahun_ajaran: tahunAjaran,
      is_aktif: true,
      is_deleted: false,
    },
    'tahun_ajaran',
    'id, tahun_ajaran',
  );
}

async function ensureKelas(supabase, namaKelas) {
  return upsertSingle(
    supabase,
    'kelas',
    {
      nama_kelas: namaKelas,
      tingkat: getClassLevel(namaKelas),
      is_deleted: false,
    },
    'nama_kelas',
    'id, nama_kelas, tingkat',
  );
}

async function ensurePublicUser(supabase, authUser, username, email) {
  return upsertSingle(
    supabase,
    'users',
    {
      id: authUser.id,
      email,
      username,
      is_deleted: false,
    },
    'id',
    'id, email, username',
  );
}

async function ensureUserRole(supabase, userId, roleId) {
  return upsertSingle(
    supabase,
    'user_roles',
    {
      user_id: userId,
      role_id: roleId,
      is_deleted: false,
    },
    'user_id,role_id',
    'id, user_id, role_id',
  );
}

async function ensureGuruProfile(supabase, authUser, teacher) {
  return upsertSingle(
    supabase,
    'guru',
    {
      user_id: authUser.id,
      nama_lengkap: teacher.nama,
      nip: teacher.nip,
      nuptk: teacher.nuptk,
      golongan: teacher.golongan,
      no_hp: teacher.noHp,
      alamat: teacher.alamat,
      tanggal_lahir: teacher.tanggalLahir,
      tempat_lahir: teacher.tempatLahir,
      jenis_kelamin: teacher.gender,
      is_deleted: false,
    },
    'user_id',
    'id, user_id, nama_lengkap, nip, nuptk',
  );
}

async function ensureSiswaProfile(supabase, authUser, student) {
  return upsertSingle(
    supabase,
    'siswa',
    {
      user_id: authUser.id,
      nis: null,
      nama: student.nama,
      jenis_kelamin: student.gender,
      tempat_lahir: null,
      tanggal_lahir: null,
      alamat: null,
      no_hp: null,
      is_deleted: false,
    },
    'user_id',
    'id, user_id, nama, jenis_kelamin',
  );
}

async function ensureKelasSiswa(supabase, kelasId, siswaId, tahunAjaranId) {
  return upsertSingle(
    supabase,
    'kelas_siswa',
    {
      kelas_id: kelasId,
      siswa_uid: siswaId,
      tahun_ajaran_id: tahunAjaranId,
      status_aktif: true,
      is_deleted: false,
    },
    'kelas_id,siswa_uid,tahun_ajaran_id',
    'id, kelas_id, siswa_uid, tahun_ajaran_id',
  );
}

async function main() {
  const opts = parseArgs(process.argv);
  const supabaseUrl = requireEnv('SUPABASE_URL');
  const supabaseKey = requireEnv('SUPABASE_SERVICE_ROLE_KEY');

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  const guruRows = parseGuruFile(opts.guruFile);
  const studentFiles = [opts.kelas7File, opts.kelas8File, opts.kelas9File];
  const studentGroups = studentFiles.map((filePath) => parseStudentFile(filePath));

  const allClasses = new Map();
  for (const group of studentGroups) {
    for (const className of group.classes) {
      allClasses.set(className, true);
    }
  }
  const classNames = [...allClasses.keys()].sort((a, b) => a.localeCompare(b, 'id'));

  const allStudents = studentGroups.flatMap((group) => group.students);

  const summary = {
    apply: opts.apply,
    guruRows: guruRows.length,
    studentRows: allStudents.length,
    classes: classNames.length,
  };

  if (!opts.apply) {
    console.log(JSON.stringify({ summary, note: 'Dry run only. Add --apply to write to Supabase.' }, null, 2));
    return;
  }

  const state = {
    usernameCounts: new Map(),
    authCreated: 0,
    authUpdated: 0,
    usersCreated: 0,
    usersUpdated: 0,
    rolesAssigned: 0,
    guruProfiles: 0,
    siswaProfiles: 0,
    kelasCreated: 0,
    kelasSiswaCreated: 0,
  };

  const roleSeeds = await ensureStaticSeed(supabase);
  const tahunAjaran = await ensureTahunAjaran(supabase, opts.tahunAjaran);

  const kelasByName = new Map();
  for (const className of classNames) {
    const kelas = await ensureKelas(supabase, className);
    kelasByName.set(className, kelas);
    state.kelasCreated += 1;
  }

  for (const teacher of guruRows) {
    const seed = extractUsernameSeed(teacher.nama);
    const identity = uniqueIdentity(seed, state, opts.domain);
    const roles = inferTeacherRoles(teacher);

    const authUser = await ensureAuthAccount(supabase, state, {
      email: identity.email,
      username: identity.username,
      fullName: teacher.nama,
      password: opts.password,
    });

    await ensurePublicUser(supabase, authUser, identity.username, identity.email);
    state.usersCreated += 1;

    for (const roleName of roles) {
      const role = roleSeeds[roleName];
      await ensureUserRole(supabase, authUser.id, role.id);
      state.rolesAssigned += 1;
    }

    await ensureGuruProfile(supabase, authUser, teacher);
    state.guruProfiles += 1;
  }

  for (const student of allStudents) {
    const seed = extractUsernameSeed(student.nama);
    const identity = uniqueIdentity(seed, state, opts.domain);
    const roles = inferStudentRoles(student);

    const authUser = await ensureAuthAccount(supabase, state, {
      email: identity.email,
      username: identity.username,
      fullName: student.nama,
      password: opts.password,
    });

    await ensurePublicUser(supabase, authUser, identity.username, identity.email);
    state.usersCreated += 1;

    for (const roleName of roles) {
      const role = roleSeeds[roleName];
      await ensureUserRole(supabase, authUser.id, role.id);
      state.rolesAssigned += 1;
    }

    const siswaProfile = await ensureSiswaProfile(supabase, authUser, student);
    state.siswaProfiles += 1;

    const kelas = kelasByName.get(student.kelas);
    if (kelas) {
      await ensureKelasSiswa(supabase, kelas.id, siswaProfile.id, tahunAjaran.id);
      state.kelasSiswaCreated += 1;
    }
  }

  console.log(
    JSON.stringify(
      {
        summary,
        password: opts.password,
        domain: opts.domain,
        tahunAjaran: tahunAjaran.tahun_ajaran,
        totals: state,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error('ERROR:', error?.message ?? error);
  process.exitCode = 1;
});