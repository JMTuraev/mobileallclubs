import 'package:flutter_test/flutter_test.dart';
import 'package:mobileallclubs/core/utils/backend_action_error.dart';

void main() {
  test('maps billing read-only failures to a single user-facing message', () {
    final message = describeBackendActionError(
      Exception(
        'firebase_functions/failed-precondtion gym is in ready-only mode until billing is active',
      ),
      fallback: 'Fallback',
    );

    expect(message, gymBillingReadOnlyMessage);
  });

  test('maps the live firebase functions read-only banner payload', () {
    final message = describeBackendActionError(
      Exception(
        '[firebase_functions/failed-precondition] Gym is in read-only mode until billing is active',
      ),
      fallback: 'Fallback',
    );

    expect(message, gymBillingReadOnlyMessage);
  });

  test('maps raw string read-only payloads too', () {
    final message = describeBackendActionError(
      '[firebase_functions/failed-precondition] Gym is in read-only mode until billing is active',
      fallback: 'Fallback',
    );

    expect(message, gymBillingReadOnlyMessage);
  });

  test('strips generic exception prefixes from backend messages', () {
    final message = describeBackendActionError(
      Exception('Exception: Failed to create package'),
      fallback: 'Fallback',
    );

    expect(message, 'Failed to create package');
  });
}
