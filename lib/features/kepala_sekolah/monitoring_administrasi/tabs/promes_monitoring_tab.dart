import 'package:flutter/material.dart';

import '../widgets/administrasi_monitoring_content.dart';

class PromesMonitoringTab extends StatelessWidget {
  const PromesMonitoringTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdministrasiMonitoringContent(
      jenis: 'program_semester',
      title: 'Program Semester',
    );
  }
}
