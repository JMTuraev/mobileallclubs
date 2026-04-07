import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../domain/gym_invite_summary.dart';
import 'invite_service.dart';

final gymInvitesProvider = FutureProvider<List<GymInviteSummary>>((ref) async {
  return getGymInvites(functions: ref.watch(firebaseFunctionsProvider));
});

final inviteTokenValidationProvider =
    FutureProvider.family<InviteTokenValidationResult, String>((
      ref,
      token,
    ) async {
      return validateInviteToken(
        functions: ref.watch(firebaseFunctionsProvider),
        token: token,
      );
    });
