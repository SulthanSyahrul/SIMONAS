class SupabaseConfig {
  const SupabaseConfig._();

  // The base project URL must NOT include the '/rest/v1/' path —
  // Supabase client appends API paths itself.
  static const String projectUrl = 'https://ppdsbjwjtewbizoktcwp.supabase.co';
  static const String publishableKey =
      'sb_publishable_GRciSTtW9eP4zp-eQAOzKg_2ANLgbEy';

  static const String storageBucket = 'administrasi_pembelajaran';
}
