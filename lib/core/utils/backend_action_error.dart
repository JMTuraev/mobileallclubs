import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';

const String gymBillingReadOnlyMessage =
    'This gym is in read-only mode until billing is active. '
    'Operational write actions are temporarily blocked. '
    'Activate billing for the gym, then try again.';

String describeBackendActionError(
  Object error, {
  required String fallback,
}) {
  if (isGymBillingReadOnlyError(error)) {
    return gymBillingReadOnlyMessage;
  }

  final message = _cleanupErrorMessage(_extractRawErrorMessage(error));
  return message.isEmpty ? fallback : message;
}

bool isGymBillingReadOnlyError(Object error) {
  final code = _extractErrorCode(error);
  final message = _normalizeForMatching(_extractRawErrorMessage(error));

  final hasReadOnly =
      message.contains('read-only') || message.contains('read only');
  final hasBilling = message.contains('billing');
  final hasFailedPrecondition =
      code == 'failed-precondition' ||
      code == 'failed-precondtion' ||
      message.contains('failed-precondition') ||
      message.contains('failed precondition');

  return (hasReadOnly && hasBilling) ||
      (hasFailedPrecondition && hasReadOnly);
}

String _extractRawErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.details?.toString() ?? error.message ?? '';
  }

  if (error is FirebaseException) {
    return error.message ?? error.toString();
  }

  return error.toString();
}

String _extractErrorCode(Object error) {
  if (error is FirebaseFunctionsException) {
    return error.code.trim().toLowerCase();
  }

  if (error is FirebaseException) {
    return error.code.trim().toLowerCase();
  }

  final message = _normalizeForMatching(error.toString());
  if (message.contains('failed-precondition')) {
    return 'failed-precondition';
  }
  if (message.contains('failed-precondtion')) {
    return 'failed-precondtion';
  }

  return '';
}

String _cleanupErrorMessage(String message) {
  return message
      .trim()
      .replaceFirst(RegExp(r'^(?:Exception:\s*)+'), '')
      .replaceFirst(RegExp(r'^(?:FirebaseException:\s*)+'), '')
      .replaceFirst(RegExp(r'^\[firebase_[^/]+/[^\]]+\]\s*'), '')
      .replaceFirst(RegExp(r'^firebase_[^/]+/[A-Za-z-]+\s*'), '')
      .trim();
}

String _normalizeForMatching(String message) {
  return _cleanupErrorMessage(message)
      .toLowerCase()
      .replaceAll('ready-only', 'read-only')
      .replaceAll('readonly', 'read-only')
      .replaceAll('precondtion', 'precondition');
}
