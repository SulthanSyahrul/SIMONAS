enum StatusMonitoring {
  masuk,
  izin,
  belumIsi;

  int get colorValue {
    switch (this) {
      case StatusMonitoring.masuk:
        return 0xFF4CAF50;
      case StatusMonitoring.izin:
        return 0xFFFFC107;
      case StatusMonitoring.belumIsi:
        return 0xFF9E9E9E;
    }
  }

  String get label {
    switch (this) {
      case StatusMonitoring.masuk:
        return 'Masuk';
      case StatusMonitoring.izin:
        return 'Izin';
      case StatusMonitoring.belumIsi:
        return 'Belum Isi';
    }
  }
}

class MonitoringKelasModel {
  final String kelasId;
  final String kelasNama;
  final int lantai;
  final StatusMonitoring status;
  final String? guruUid;
  final String? mataPelajaranId;
  final String? namaGuru;
  final String? mataPelajaran;
  final DateTime tanggal;
  final int jamKe;

  const MonitoringKelasModel({
    required this.kelasId,
    required this.kelasNama,
    required this.lantai,
    required this.status,
    this.guruUid,
    this.mataPelajaranId,
    this.namaGuru,
    this.mataPelajaran,
    required this.tanggal,
    required this.jamKe,
  });
}
