import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'app.dart';
import 'core/config/supabase_config.dart';
import 'core/services/app_metrics.dart';

/// Entry point aplikasi
/// Sistem Monitoring Kelas SMP Negeri 1 Jenar
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppMetrics().markStartupStarted();

  final bootstrapFuture = _initializeCoreServices();
  runApp(ProviderScope(child: MyApp(bootstrapFuture: bootstrapFuture)));
}

Future<void> _initializeCoreServices() async {
  final timer = PerfTimer('core_services_init');
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    anonKey: SupabaseConfig.publishableKey,
  );
  timer.stopIfSlow(thresholdMs: 300);

  if (kDebugMode) {
    debugPrint('Supabase initialized: ${Supabase.instance.client}');
  }
}
