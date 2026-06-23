# Sistem Monitoring Kelas SMP Negeri 1 Jenar

Aplikasi mobile Flutter untuk monitoring dan pengelolaan kelas di SMP Negeri 1 Jenar. Aplikasi ini dirancang dengan **arsitektur multi-role** untuk Guru, Kepala Sekolah, dan Siswa.

## 📱 Fitur Utama

### 1. **Login Multi-Role**
- Support 3 role pengguna: Guru, Kepala Sekolah, Siswa
- Credentials demo:
  - **Guru**: `guru` / `guru123`
  - **Kepala Sekolah**: `kepsek` / `kepsek123`
  - **Siswa**: `siswa` / `siswa123`

### 2. **Dashboard per Role**
- **Dashboard Guru**: Jadwal, Jurnal & Absensi, Nilai
- **Dashboard Kepala Sekolah**: Monitoring, Laporan (dalam pengembangan)
- **Dashboard Siswa**: Jadwal, Nilai, Tugas (dalam pengembangan)
- Setiap dashboard memiliki dropdown Tahun Ajaran di AppBar

### 3. **Fitur Guru**

#### Jadwal Mengajar
- Lihat jadwal mengajar per hari
- Informasi lengkap: waktu, kelas, mata pelajaran, ruangan
- Tampilan terkelompok berdasarkan hari
- Filter berdasarkan tahun ajaran

#### Jurnal & Absensi (Terintegrasi)
- Input jurnal mengajar harian
- Form lengkap: tanggal, kelas, mata pelajaran, materi, metode, catatan
- **Absensi terintegrasi** dalam jurnal
- Daftar siswa berubah otomatis sesuai kelas yang dipilih
- Dropdown status per siswa: Hadir, Izin, Sakit, Alpa
- Ringkasan statistik kehadiran
- Validasi input lengkap
- Data disimpan ke console (demo)

#### Nilai
- Placeholder untuk development selanjutnya

## 🏗️ Arsitektur & Struktur Folder (REFACTORED)

Project ini menggunakan **Clean Architecture berbasis Feature & Role** dengan pemisahan yang jelas:

```
lib/
├── main.dart                 # Entry point aplikasi
├── app.dart                  # Root widget & routing
│
├── core/                     # Core utilities & shared
│   ├── constants/
│   │   ├── app_colors.dart   # Definisi warna
│   │   ├── app_theme.dart    # Tema Material
│   │   └── user_role.dart    # Enum role user
│   ├── providers/
│   │   └── academic_year_provider.dart  # State tahun ajaran
│   ├── widgets/
│   │   └── academic_year_dropdown.dart  # Widget dropdown tahun ajaran
│   └── utils/
│       └── app_utils.dart    # Helper functions
│
├── features/                 # Fitur per role (scalable)
│   │
│   ├── auth/                 # Autentikasi
│   │   └── screens/
│   │       └── login_screen.dart
│   │
│   ├── guru/                 # Fitur khusus Guru
│   │   ├── dashboard/
│   │   │   └── screens/
│   │   │       └── guru_dashboard_screen.dart
│   │   ├── jadwal/
│   │   │   └── screens/
│   │   │       └── jadwal_screen.dart
│   │   ├── jurnal/
│   │   │   └── screens/
│   │   │       └── jurnal_screen.dart  # Dengan absensi terintegrasi
│   │   ├── nilai/
│   │   │   └── screens/
│   │   │       └── nilai_screen.dart
│   │   └── widgets/
│   │       ├── menu_card.dart
│   │       ├── jadwal_card.dart
│   │       └── student_attendance_item.dart
│   │
│   ├── kepala_sekolah/       # Fitur Kepala Sekolah
│   │   └── dashboard/
│   │       └── screens/
│   │           └── kepala_sekolah_dashboard_screen.dart
│   │
│   └── siswa/                # Fitur Siswa
│       └── dashboard/
│           └── screens/
│               └── siswa_dashboard_screen.dart
│
├── models/                   # Data models (shared)
│   ├── jadwal_model.dart
│   ├── jurnal_model.dart
│   └── siswa_model.dart
│
└── services/                 # Services layer
    └── auth_service.dart
```

## 🎯 Key Features & Improvements

### 1. **Multi-Role Architecture**
- Struktur folder terpisah per role
- Scalable untuk penambahan role baru
- Tidak ada kode campur antar role
- Routing dinamis berdasarkan credentials

### 2. **Tahun Ajaran Management**
- Provider pattern untuk state management tahun ajaran
- Dropdown di setiap AppBar (kanan atas)
- Data tersinkron di seluruh fitur
- Pilihan: 2023/2024, 2024/2025, 2025/2026

### 3. **Jurnal & Absensi Terintegrasi**
- Absensi tidak lagi halaman terpisah
- Terintegrasi dalam form jurnal
- Daftar siswa **auto-update** saat kelas berubah
- Data siswa dummy per kelas (10A-12C)
- Widget reusable: `StudentAttendanceItem`

### 4. **Siswa Per Kelas**
- Mapping siswa berdasarkan kelas
- Total 30 siswa dummy (9 kelas)
- Method `SiswaModel.getByClass(kelas)`
- Setiap kelas memiliki 2-5 siswa

## 🎨 Design Pattern & Best Practices

### 1. **Feature-Based Structure**
- Pemisahan fitur berdasarkan role
- Setiap role memiliki folder independen
- Mudah untuk scaling dan maintenance

### 2. **State Management**
- ChangeNotifier untuk AcademicYearProvider
- ListenableBuilder untuk reactive UI
- setState untuk local state

### 3. **Widget Reusability**
- `MenuCard` - Grid menu dashboard
- `JadwalCard` - Item jadwal
- `StudentAttendanceItem` - Item absensi siswa
- `AcademicYearDropdown` - Dropdown tahun ajaran

### 4. **Clean Code Principles**
- Const constructors untuk optimasi
- Komentar pada bagian penting
- Naming convention konsisten
- Proper error handling
- Form validation

### 5. **Material Design**
- Consistent AppBar dengan tahun ajaran
- Card-based layouts
- Proper padding dan spacing
- Status colors untuk absensi

## 🚀 Cara Menjalankan

### Prerequisites
- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / VS Code
- Emulator atau device fisik

### Langkah-langkah

1. **Install dependencies**
   ```bash
   flutter pub get
   ```

2. **Jalankan aplikasi**
   ```bash
   flutter run
   ```

3. **Login dengan salah satu role:**
   - **Guru**: username `guru`, password `guru123`
   - **Kepala Sekolah**: username `kepsek`, password `kepsek123`
   - **Siswa**: username `siswa`, password `siswa123`

## 🧪 Testing

```bash
flutter test
```

## 📊 Data Dummy

### Kelas
- 10A (5 siswa), 10B (4 siswa), 10C (3 siswa)
- 11A (4 siswa), 11B (3 siswa), 11C (2 siswa)
- 12A (4 siswa), 12B (3 siswa), 12C (2 siswa)

### Jadwal
- 7 jadwal mengajar dummy dengan berbagai kelas dan mapel

### Tahun Ajaran
- 2023/2024, 2024/2025, 2025/2026

## 📝 Catatan Pengembangan

- **Status**: Demo/Prototype dengan struktur production-ready
- **Data**: Hardcoded (siap migrasi ke Supabase)
- **Backend**: Belum terintegrasi (structure ready)
- **Platform**: Android & iOS compatible

## 🔮 Future Development

1. **Backend Integration**
   - Supabase Auth untuk multi-role
   - Supabase Database (Postgres) untuk data
   - Supabase Storage untuk file

2. **Fitur Kepala Sekolah**
   - Monitoring jurnal semua guru
   - Laporan kehadiran per kelas
   - Statistik pembelajaran
   - Export laporan PDF

3. **Fitur Siswa**
   - Lihat jadwal pelajaran
   - Lihat nilai
   - Lihat dan submit tugas
   - Notifikasi

4. **Improvement**
   - State management dengan Riverpod/Bloc
   - Offline support dengan Hive
   - Advanced filtering
   - Export data Excel/PDF
   - Real-time notifications

## 🎓 Keunggulan Struktur

1. **Scalable**: Mudah menambah role atau fitur baru
2. **Maintainable**: Kode terpisah per role, tidak saling mengganggu
3. **Professional**: Arsitektur production-ready
4. **Clean**: Separation of concerns yang jelas
5. **Ready for TA**: Siap presentasi dengan dokumentasi lengkap

## 👨‍💻 Pengembang

Project Tugas Akhir - Sistem Monitoring Kelas SMP Negeri 1 Jenar

## 📄 License

This project is for educational purposes.

---

**Dibuat dengan ❤️ menggunakan Flutter & Clean Architecture**

