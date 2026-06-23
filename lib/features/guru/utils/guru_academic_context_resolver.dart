import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/shared_academic_context_provider.dart';

class GuruAcademicContext {
  final String tahunAjaranId;
  final int semester;

  const GuruAcademicContext({
    required this.tahunAjaranId,
    required this.semester,
  });
}

Future<GuruAcademicContext> resolveGuruAcademicContext(
  WidgetRef ref,
  String selectedYear, {
  int fallbackSemester = 1,
}) async {
  final target = await ref
      .read(sharedAcademicContextCacheProvider)
      .getGuruAcademicContext(
        ref.read,
        selectedYear,
        fallbackSemester: fallbackSemester,
      );

  return GuruAcademicContext(
    tahunAjaranId: target.tahunAjaranId,
    semester: target.semester,
  );
}
