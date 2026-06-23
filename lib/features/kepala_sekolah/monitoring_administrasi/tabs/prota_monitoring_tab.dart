import 'package:flutter/material.dart';

import '../widgets/administrasi_monitoring_content.dart';

class ProtaMonitoringTab extends StatelessWidget {
  const ProtaMonitoringTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdministrasiMonitoringContent(
      jenis: 'program_tahunan',
      title: 'Program Tahunan',
    );
  }
}
