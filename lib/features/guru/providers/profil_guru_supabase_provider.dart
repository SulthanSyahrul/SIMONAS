import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/guru_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/supabase_providers.dart';
import '../../shared/providers/shared_academic_context_provider.dart';

class ProfilGuruState {
  final UserRecord? profile;
  final GuruRecord? guruProfile;
  final bool isLoading;
  final String? error;

  const ProfilGuruState({
    required this.profile,
    required this.guruProfile,
    required this.isLoading,
    required this.error,
  });

  factory ProfilGuruState.initial() {
    return const ProfilGuruState(
      profile: null,
      guruProfile: null,
      isLoading: false,
      error: null,
    );
  }

  ProfilGuruState copyWith({
    Object? profile = _profilGuruSentinel,
    Object? guruProfile = _profilGuruSentinel,
    bool? isLoading,
    Object? error = _profilGuruSentinel,
  }) {
    return ProfilGuruState(
      profile: profile == _profilGuruSentinel ? this.profile : profile as UserRecord?,
      guruProfile: guruProfile == _profilGuruSentinel
          ? this.guruProfile
          : guruProfile as GuruRecord?,
      isLoading: isLoading ?? this.isLoading,
      error: error == _profilGuruSentinel ? this.error : error as String?,
    );
  }
}

class ProfilGuruNotifier extends StateNotifier<ProfilGuruState> {
  ProfilGuruNotifier(this._ref, this._guruUid) : super(ProfilGuruState.initial());

  final Ref _ref;
  final String _guruUid;

  Future<void> getProfile({bool forceRefresh = false}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final cache = _ref.read(appMasterCacheProvider);
      final user = await cache.getUserProfileByUid(
        _ref.read,
        _guruUid,
        forceRefresh: forceRefresh,
      );
      final guruProfile = await _ref
          .read(guruServiceProvider)
          .getFirstByUid(_guruUid);

      state = state.copyWith(
        profile: user,
        guruProfile: guruProfile,
        isLoading: false,
        error: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat profil guru: $error',
      );
    }
  }
}

final profilGuruSupabaseProvider = StateNotifierProvider.autoDispose
    .family<ProfilGuruNotifier, ProfilGuruState, String>((ref, guruUid) {
      final notifier = ProfilGuruNotifier(ref, guruUid);
      Future.microtask(notifier.getProfile);
      return notifier;
    });

const Object _profilGuruSentinel = Object();
