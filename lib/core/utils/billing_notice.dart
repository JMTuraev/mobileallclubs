import '../../models/auth_bootstrap_models.dart';
import 'backend_action_error.dart';

/// Statuses that mean the gym is in a read-only / blocked billing state.
/// These come from `gym.billingStatus` on the Firestore doc.
const Set<String> _blockedBillingStatuses = <String>{
  'inactive',
  'blocked',
  'read_only',
  'read-only',
  'past_due',
  'payment_required',
  'expired',
  'cancelled',
  'canceled',
};

/// Returns `true` when the gym can not accept write actions because of its
/// billing state. Use this to *proactively* gate POS / mutation UI instead
/// of waiting for the backend to reject the request.
bool isGymReadOnly(GymProfile? gym) {
  if (gym == null) return false;
  if (gym.isReadOnly == true) return true;
  final status = gym.billingStatus?.trim().toLowerCase();
  if (status == null || status.isEmpty) return false;
  return _blockedBillingStatuses.contains(status);
}

/// Returns a user-facing reason string when the gym is read-only, or `null`
/// when the gym is operational.
///
/// Prefers the backend-provided [GymProfile.readOnlyReason] (which may be
/// localized / customized per gym), falling back to the canonical message.
String? resolveBillingNotice(GymProfile? gym) {
  if (gym == null) return null;

  final explicit = gym.readOnlyReason?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  if (isGymReadOnly(gym)) {
    return gymBillingReadOnlyMessage;
  }

  return null;
}
