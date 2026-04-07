import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/gym_invite_summary.dart';

class SendInviteRequest {
  const SendInviteRequest({
    required this.email,
    required this.fullName,
    required this.phone,
    this.photo,
    this.role = 'staff',
    this.gymName,
    this.inviterName,
  });

  final String email;
  final String fullName;
  final String phone;
  final String? photo;
  final String role;
  final String? gymName;
  final String? inviterName;

  Map<String, dynamic> toJson() {
    return {
      'email': email.trim().toLowerCase(),
      'role': role,
      'staffData': {
        'fullName': fullName.trim(),
        'phone': phone.trim(),
        'photo': photo,
      },
      if (gymName != null && gymName!.trim().isNotEmpty) 'gymName': gymName,
      if (inviterName != null && inviterName!.trim().isNotEmpty)
        'inviterName': inviterName,
    };
  }
}

class InviteActionResult {
  const InviteActionResult({
    required this.success,
    this.message,
    this.inviteId,
    this.token,
    this.userId,
    this.gymId,
    this.assignedExistingUser = false,
  });

  final bool success;
  final String? message;
  final String? inviteId;
  final String? token;
  final String? userId;
  final String? gymId;
  final bool assignedExistingUser;
}

Future<InviteActionResult> sendInvite({
  required FirebaseFunctions functions,
  required SendInviteRequest request,
}) async {
  final normalizedEmail = request.email.trim().toLowerCase();
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalizedEmail)) {
    throw Exception('Invalid email format');
  }

  try {
    final result = await functions
        .httpsCallable('sendInvite')
        .call(request.toJson());
    final data = _asMap(result.data);

    if (data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to send invite');
    }

    return InviteActionResult(
      success: true,
      inviteId: data['inviteId']?.toString(),
      token: data['token']?.toString(),
      userId: data['userId']?.toString(),
      assignedExistingUser: data['assignedExistingUser'] == true,
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      error.details?.toString() ?? error.message ?? 'Failed to send invite',
    );
  } catch (error) {
    throw Exception(error.toString().replaceFirst('Exception: ', ''));
  }
}

Future<InviteActionResult> cancelInvite({
  required FirebaseFunctions functions,
  required String inviteId,
}) async {
  final normalizedInviteId = inviteId.trim();
  if (normalizedInviteId.isEmpty) {
    throw Exception('Invite ID is required');
  }

  try {
    final result = await functions.httpsCallable('cancelInvite').call({
      'inviteId': normalizedInviteId,
    });
    final data = _asMap(result.data);

    if (data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to cancel invite');
    }

    return InviteActionResult(
      success: true,
      inviteId: data['inviteId']?.toString() ?? normalizedInviteId,
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      error.details?.toString() ?? error.message ?? 'Failed to cancel invite',
    );
  } catch (error) {
    throw Exception(error.toString().replaceFirst('Exception: ', ''));
  }
}

Future<InviteActionResult> resendInvite({
  required FirebaseFunctions functions,
  required String inviteId,
}) async {
  final normalizedInviteId = inviteId.trim();
  if (normalizedInviteId.isEmpty) {
    throw Exception('Invite ID is required');
  }

  try {
    final result = await functions.httpsCallable('resendInvite').call({
      'inviteId': normalizedInviteId,
    });
    final data = _asMap(result.data);

    if (data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to resend invite');
    }

    return InviteActionResult(
      success: true,
      inviteId: data['inviteId']?.toString() ?? normalizedInviteId,
      token: data['token']?.toString(),
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      error.details?.toString() ?? error.message ?? 'Failed to resend invite',
    );
  } catch (error) {
    throw Exception(error.toString().replaceFirst('Exception: ', ''));
  }
}

Future<List<GymInviteSummary>> getGymInvites({
  required FirebaseFunctions functions,
}) async {
  try {
    final result = await functions.httpsCallable('getGymInvites').call({});
    final data = result.data;

    final rawInvites = switch (data) {
      List<dynamic> value => value,
      Map<dynamic, dynamic> value when value['invites'] is List =>
        value['invites'] as List<dynamic>,
      _ => null,
    };

    if (rawInvites == null) {
      throw Exception('Unexpected getGymInvites response: ${data.runtimeType}');
    }

    return rawInvites
        .whereType<Map>()
        .map(
          (item) => GymInviteSummary.fromMap(
            item['id']?.toString() ?? '',
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .where((invite) => invite.id.isNotEmpty)
        .toList(growable: false);
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      error.details?.toString() ??
          error.message ??
          'Failed to load invite history',
    );
  } catch (error) {
    throw Exception(error.toString().replaceFirst('Exception: ', ''));
  }
}

Future<InviteTokenValidationResult> validateInviteToken({
  required FirebaseFunctions functions,
  required String token,
}) async {
  final normalizedToken = token.trim();
  if (normalizedToken.isEmpty) {
    return const InviteTokenValidationResult(
      valid: false,
      errorMessage: 'Missing invite token.',
    );
  }

  try {
    final result = await functions.httpsCallable('validateInviteToken').call({
      'token': normalizedToken,
    });
    final data = _asMap(result.data);
    final valid = data['valid'] == true;

    if (!valid) {
      return InviteTokenValidationResult(
        valid: false,
        errorMessage:
            data['error']?.toString() ?? 'Failed to validate invite token.',
      );
    }

    final inviteData = _asMap(data['invite']);
    return InviteTokenValidationResult(
      valid: true,
      invite: GymInviteSummary.fromMap(
        inviteData['id']?.toString() ?? '',
        inviteData,
      ),
    );
  } on FirebaseFunctionsException catch (error) {
    return InviteTokenValidationResult(
      valid: false,
      errorMessage:
          error.details?.toString() ??
          error.message ??
          'Failed to validate invite token.',
    );
  } catch (error) {
    return InviteTokenValidationResult(
      valid: false,
      errorMessage: error.toString().replaceFirst('Exception: ', ''),
    );
  }
}

Future<InviteActionResult> acceptInvite({
  required FirebaseAuth auth,
  required FirebaseFunctions functions,
  required String token,
  required String password,
  required String fullName,
}) async {
  final normalizedToken = token.trim();
  final trimmedFullName = fullName.trim();

  if (normalizedToken.isEmpty || password.isEmpty || trimmedFullName.isEmpty) {
    throw Exception('Token, password, and full name are required');
  }

  if (password.length < 6) {
    throw Exception('Password must be at least 6 characters long');
  }

  final validation = await validateInviteToken(
    functions: functions,
    token: normalizedToken,
  );

  if (!validation.valid || validation.invite == null) {
    throw Exception(validation.errorMessage ?? 'Invite is not valid');
  }

  final email = validation.invite?.email?.trim().toLowerCase() ?? '';
  if (email.isEmpty) {
    throw Exception('Invite email is missing');
  }

  try {
    await auth.createUserWithEmailAndPassword(email: email, password: password);
  } on FirebaseAuthException catch (error) {
    throw Exception(_messageFromAuthException(error));
  }

  try {
    final result = await functions.httpsCallable('acceptInvite').call({
      'token': normalizedToken,
      'fullName': trimmedFullName,
    });
    final data = _asMap(result.data);

    if (data['success'] == false) {
      throw Exception(data['error']?.toString() ?? 'Failed to accept invite');
    }

    return InviteActionResult(
      success: true,
      gymId: data['gymId']?.toString(),
      inviteId: validation.invite?.id,
    );
  } on FirebaseFunctionsException catch (error) {
    throw Exception(
      error.details?.toString() ?? error.message ?? 'Failed to accept invite',
    );
  } catch (error) {
    throw Exception(error.toString().replaceFirst('Exception: ', ''));
  }
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }

  return const <String, dynamic>{};
}

String _messageFromAuthException(FirebaseAuthException error) {
  switch (error.code) {
    case 'auth/email-already-in-use':
    case 'email-already-in-use':
      return 'An account with this email already exists. Please try logging in instead.';
    case 'auth/weak-password':
    case 'weak-password':
      return 'Password is too weak. Please choose a stronger password.';
    case 'auth/invalid-email':
    case 'invalid-email':
      return 'Invalid email address.';
    case 'auth/network-request-failed':
    case 'network-request-failed':
      return 'Network error. Please check your connection and try again.';
    default:
      return error.message ?? 'Authentication error: Unknown error';
  }
}
