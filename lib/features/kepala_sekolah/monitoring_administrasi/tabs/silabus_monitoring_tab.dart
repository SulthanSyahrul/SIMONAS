import 'package:flutter/material.dart';

import '../widgets/administrasi_monitoring_content.dart';

class SilabusMonitoringTab extends StatelessWidget {
  const SilabusMonitoringTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdministrasiMonitoringContent(
      jenis: 'silabus',
      title: 'Silabus',
    );
  }
}
