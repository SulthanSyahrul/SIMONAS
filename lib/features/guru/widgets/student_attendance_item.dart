import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

enum StatusAbsensi { hadir, izin, sakit, alpa }

extension StatusAbsensiLabel on StatusAbsensi {
  String get label {
    switch (this) {
      case StatusAbsensi.hadir:
        return 'Hadir';
      case StatusAbsensi.izin:
        return 'Izin';
      case StatusAbsensi.sakit:
        return 'Sakit';
      case StatusAbsensi.alpa:
        return 'Alpa';
    }
  }
}

class SiswaModel {
  SiswaModel({
    required this.nama,
    required this.nis,
    this.statusAbsensi = StatusAbsensi.hadir,
  });

  final String nama;
  final String nis;
  StatusAbsensi statusAbsensi;

  void updateStatus(StatusAbsensi value) {
    statusAbsensi = value;
  }
}

/// Widget reusable untuk item absensi siswa
/// Dengan dropdown status kehadiran
class StudentAttendanceItem extends StatefulWidget {
  final SiswaModel siswa;
  final Function(StatusAbsensi) onStatusChanged;

  const StudentAttendanceItem({
    super.key,
    required this.siswa,
    required this.onStatusChanged,
  });

  @override
  State<StudentAttendanceItem> createState() => _StudentAttendanceItemState();
}

class _StudentAttendanceItemState extends State<StudentAttendanceItem> {
  late StatusAbsensi _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.siswa.statusAbsensi;
  }

  /// Mendapatkan warna berdasarkan status absensi
  Color _getStatusColor(StatusAbsensi status) {
    switch (status) {
      case StatusAbsensi.hadir:
        return AppColors.success;
      case StatusAbsensi.izin:
        return AppColors.warning;
      case StatusAbsensi.sakit:
        return AppColors.info;
      case StatusAbsensi.alpa:
        return AppColors.error;
    }
  }

  /// Mendapatkan icon berdasarkan status absensi
  IconData _getStatusIcon(StatusAbsensi status) {
    switch (status) {
      case StatusAbsensi.hadir:
        return Icons.check_circle;
      case StatusAbsensi.izin:
        return Icons.info;
      case StatusAbsensi.sakit:
        return Icons.local_hospital;
      case StatusAbsensi.alpa:
        return Icons.cancel;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          // Avatar siswa
          CircleAvatar(
            backgroundColor: AppColors.primary,
            radius: 20,
            child: Text(
              widget.siswa.nama[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info siswa
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nama siswa
                Text(
                  widget.siswa.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),

                // NIS
                Text(
                  'NIS: ${widget.siswa.nis}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Dropdown status absensi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(_currentStatus).withAlpha(26),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(_currentStatus).withAlpha(128),
              ),
            ),
            child: DropdownButton<StatusAbsensi>(
              value: _currentStatus,
              underline: const SizedBox(),
              icon: Icon(
                Icons.arrow_drop_down,
                color: _getStatusColor(_currentStatus),
                size: 20,
              ),
              items: StatusAbsensi.values.map((status) {
                return DropdownMenuItem<StatusAbsensi>(
                  value: status,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(status),
                        size: 14,
                        color: _getStatusColor(status),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (StatusAbsensi? newStatus) {
                if (newStatus != null) {
                  setState(() {
                    _currentStatus = newStatus;
                    widget.siswa.updateStatus(newStatus);
                  });
                  widget.onStatusChanged(newStatus);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
