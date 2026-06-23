import 'absensi_service.dart';
import 'administrasi_pembelajaran_service.dart';
import 'guru_service.dart';
import 'histori_wali_kelas_service.dart';
import 'jadwal_service.dart';
import 'jurnal_service.dart';
import 'kelas_service.dart';
import 'kelas_siswa_service.dart';
import 'mapel_service.dart';
import 'nilai_tugas_service.dart';
import 'nilai_ujian_service.dart';
import 'semester_service.dart';
import 'tahun_ajaran_service.dart';
import 'tugas_service.dart';

class KepalaSekolahService {
  final TahunAjaranService tahunAjaranService;
  final SemesterService semesterService;
  final KelasService kelasService;
  final MapelService mapelService;
  final GuruService guruService;
  final JadwalService jadwalService;
  final JurnalService jurnalService;
  final AbsensiService absensiJurnalService;
  final NilaiUjianService nilaiService;
  final NilaiTugasService nilaiTugasService;
  final TugasService tugasService;
  final KelasSiswaService kelasSiswaService;
  final AdministrasiPembelajaranService administrasiPembelajaranService;
  final HistoriWaliKelasService historiWaliKelasService;

  KepalaSekolahService({
    TahunAjaranService? tahunAjaranService,
    SemesterService? semesterService,
    KelasService? kelasService,
    MapelService? mapelService,
    GuruService? guruService,
    JadwalService? jadwalService,
    JurnalService? jurnalService,
    AbsensiService? absensiJurnalService,
    NilaiUjianService? nilaiService,
    NilaiTugasService? nilaiTugasService,
    TugasService? tugasService,
    KelasSiswaService? kelasSiswaService,
    AdministrasiPembelajaranService? administrasiPembelajaranService,
    HistoriWaliKelasService? historiWaliKelasService,
  }) : tahunAjaranService = tahunAjaranService ?? TahunAjaranService(),
       semesterService = semesterService ?? SemesterService(),
       kelasService = kelasService ?? KelasService(),
       mapelService = mapelService ?? MapelService(),
       guruService = guruService ?? GuruService(),
       jadwalService = jadwalService ?? JadwalService(),
       jurnalService = jurnalService ?? JurnalService(),
       absensiJurnalService = absensiJurnalService ?? AbsensiService(),
       nilaiService = nilaiService ?? NilaiUjianService(),
       nilaiTugasService = nilaiTugasService ?? NilaiTugasService(),
       tugasService = tugasService ?? TugasService(),
       kelasSiswaService = kelasSiswaService ?? KelasSiswaService(),
       administrasiPembelajaranService =
           administrasiPembelajaranService ?? AdministrasiPembelajaranService(),
       historiWaliKelasService =
           historiWaliKelasService ?? HistoriWaliKelasService();
}
