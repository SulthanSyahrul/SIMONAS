/// Standarisasi key cache global per fitur.
/// Format utama: [fitur]
/// Gunakan [userScoped] agar data cache antar user tidak saling tertukar.
class CacheKeys {
  CacheKeys._();

  static const String jurnalGuru = 'jurnal_guru';
  static const String nilaiSiswa = 'nilai_siswa';
  static const String tugasGuru = 'tugas_guru';
  static const String jadwalSiswa = 'jadwal_siswa';
  static const String monitoringKepsek = 'monitoring_kepsek';
  static const String dataSiswaKemahasiswaan = 'data_siswa_kemahasiswaan';

  // Tambahan agar siap dipakai fitur lain
  static const String guruNilai = 'guru_nilai';
  static const String guruTugas = 'guru_tugas';
  static const String kemahasiswaanSiswa = 'kemahasiswaan_siswa';
  static const String kemahasiswaanKelas = 'kemahasiswaan_kelas';
  static const String kepsekJadwal = 'kepsek_jadwal';
  static const String siswaJadwal = 'siswa_jadwal';
  static const String siswaTugas = 'siswa_tugas';

  static String userScoped(String baseKey, String userId) {
    final sanitizedUserId = userId.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );
    return '${baseKey}_$sanitizedUserId';
  }
}
