import 'package:flutter/material.dart';

import '../widgets/administrasi_monitoring_content.dart';

class RppMonitoringTab extends StatelessWidget {
  const RppMonitoringTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdministrasiMonitoringContent(
      jenis: 'rencana_pembelajaran',
      title: 'Rencana Pembelajaran',
    );
  }
}
