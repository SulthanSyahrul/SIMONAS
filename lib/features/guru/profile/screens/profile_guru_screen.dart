import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/academic_year_provider.dart';
import '../../../profile/providers/self_profile_provider.dart';
import '../../../profile/screens/self_profile_screen.dart';

class ProfileGuruScreen extends ConsumerWidget {
  final AcademicYearProvider academicYearProvider;
  final String guruUid;

  const ProfileGuruScreen({
    super.key,
    required this.academicYearProvider,
    required this.guruUid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SelfProfileScreen(
      uid: guruUid,
      role: 'guru',
      profileType: SelfProfileType.staff,
    );
  }
}
