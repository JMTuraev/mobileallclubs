import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';

final clientActionsServiceProvider = Provider<ClientActionsService>((ref) {
  return ClientActionsService(
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(firebaseFunctionsProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

class CreateClientRequest {
  const CreateClientRequest({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.gender,
    this.birthDate,
    this.note,
    this.imageUrl,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String gender;
  final String? birthDate;
  final String? note;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': phone.trim(),
      'gender': gender.trim().isEmpty ? 'male' : gender.trim(),
      'birthDate': birthDate?.trim().isEmpty == true ? null : birthDate?.trim(),
      'note': note?.trim() ?? '',
      'image': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
    };
  }
}

class CreateClientResult {
  const CreateClientResult({required this.success, required this.clientId});

  final bool success;
  final String clientId;
}

class SessionActionResult {
  const SessionActionResult({
    required this.success,
    required this.sessionId,
    this.barDebt,
  });

  final bool success;
  final String sessionId;
  final num? barDebt;
}

class ClientActionsService {
  const ClientActionsService({
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _functions = functions,
       _firestore = firestore,
       _auth = auth,
       _storage = storage;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  Future<String> uploadClientPhoto({
    required String gymId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final normalizedGymId = gymId.trim();
    final normalizedFileName = fileName.trim();
    final currentUserId = _auth.currentUser?.uid.trim();

    if (normalizedGymId.isEmpty) {
      throw Exception('Missing gymId');
    }

    if (bytes.isEmpty) {
      throw Exception('Missing image bytes');
    }

    final extension = _fileExtension(normalizedFileName);
    final fileSuffix = extension == null ? '' : '.$extension';
    final uploadPath =
        'gyms/$normalizedGymId/clients/'
        '${DateTime.now().millisecondsSinceEpoch}-${currentUserId != null && currentUserId.isNotEmpty ? currentUserId : 'user'}$fileSuffix';
    final ref = _storage.ref().child(uploadPath);

    try {
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<CreateClientResult> createClient({
    required CreateClientRequest request,
  }) async {
    if (request.firstName.trim().isEmpty) {
      throw Exception('First name is required');
    }

    try {
      final result = await _functions
          .httpsCallable('createClient')
          .call(request.toJson());
      final data = result.data;

      if (data is! Map) {
        throw Exception('Failed to create client');
      }

      final success = data['success'] != false;
      final clientId =
          data['clientId']?.toString() ?? data['id']?.toString() ?? '';

      if (!success || clientId.isEmpty) {
        throw Exception(data['error']?.toString() ?? 'Failed to create client');
      }

      return CreateClientResult(success: true, clientId: clientId);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to create client'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> archiveClient({required String clientId}) async {
    final normalizedClientId = clientId.trim();
    if (normalizedClientId.isEmpty) {
      throw Exception('Missing clientId');
    }

    try {
      final result = await _functions.httpsCallable('archiveClient').call({
        'clientId': normalizedClientId,
      });
      final data = result.data;

      if (data is Map && data['success'] == false) {
        throw Exception(
          data['error']?.toString() ?? 'Failed to archive client',
        );
      }
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to archive client'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> bindClientCard({
    required String gymId,
    required String clientId,
    required String cardId,
  }) async {
    final normalizedGymId = gymId.trim();
    final normalizedClientId = clientId.trim();
    final normalizedCardId = cardId.trim();

    if (normalizedGymId.isEmpty) {
      throw Exception('Missing gymId');
    }

    if (normalizedClientId.isEmpty) {
      throw Exception('Missing clientId');
    }

    if (normalizedCardId.isEmpty) {
      throw Exception('INVALID_CARD');
    }

    final clientRef = _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('clients')
        .doc(normalizedClientId);
    final cardRef = _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('cards')
        .doc(normalizedCardId);

    try {
      await _firestore.runTransaction((transaction) async {
        final clientSnap = await transaction.get(clientRef);
        final cardSnap = await transaction.get(cardRef);

        if (!clientSnap.exists) {
          throw Exception('CLIENT_NOT_FOUND');
        }

        if (cardSnap.exists) {
          throw Exception('CARD_ALREADY_LINKED');
        }

        final currentCardId = clientSnap.data()?['cardId']?.toString();
        if (currentCardId != null &&
            currentCardId.trim().isNotEmpty &&
            currentCardId.trim() != normalizedCardId) {
          throw Exception('CLIENT_ALREADY_HAS_CARD');
        }

        transaction.set(cardRef, {
          'clientId': normalizedClientId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        transaction.update(clientRef, {'cardId': normalizedCardId});
      });
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> removeClientCard({
    required String gymId,
    required String clientId,
    required String cardId,
  }) async {
    final normalizedGymId = gymId.trim();
    final normalizedClientId = clientId.trim();
    final normalizedCardId = cardId.trim();

    if (normalizedGymId.isEmpty) {
      throw Exception('Missing gymId');
    }

    if (normalizedClientId.isEmpty) {
      throw Exception('Missing clientId');
    }

    if (normalizedCardId.isEmpty) {
      throw Exception('INVALID_CARD');
    }

    final clientRef = _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('clients')
        .doc(normalizedClientId);
    final cardRef = _firestore
        .collection('gyms')
        .doc(normalizedGymId)
        .collection('cards')
        .doc(normalizedCardId);

    try {
      await _firestore.runTransaction((transaction) async {
        final clientSnap = await transaction.get(clientRef);
        final cardSnap = await transaction.get(cardRef);

        if (!clientSnap.exists) {
          throw Exception('CLIENT_NOT_FOUND');
        }

        if (cardSnap.exists) {
          final linkedClientId = cardSnap.data()?['clientId']?.toString();
          if (linkedClientId != null &&
              linkedClientId.isNotEmpty &&
              linkedClientId != normalizedClientId) {
            throw Exception('CARD_LINKED_TO_ANOTHER_CLIENT');
          }

          transaction.delete(cardRef);
        }

        transaction.update(clientRef, {'cardId': null});
      });
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<SessionActionResult> startSession({
    required String clientId,
    String? lockerNumber,
  }) async {
    final normalizedClientId = clientId.trim();
    final normalizedLocker = lockerNumber?.trim();

    if (normalizedClientId.isEmpty) {
      throw Exception('Missing clientId');
    }

    try {
      final result = await _functions.httpsCallable('startSession').call({
        'clientId': normalizedClientId,
        'lockerNumber': normalizedLocker?.isEmpty == true
            ? null
            : normalizedLocker,
      });
      final data = result.data;

      if (data is! Map) {
        throw Exception('Failed to start session');
      }

      final success = data['success'] != false;
      final sessionId = data['sessionId']?.toString() ?? '';

      if (!success || sessionId.isEmpty) {
        throw Exception(data['error']?.toString() ?? 'Failed to start session');
      }

      return SessionActionResult(success: true, sessionId: sessionId);
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to start session'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<SessionActionResult> endSession({required String sessionId}) async {
    final normalizedSessionId = sessionId.trim();

    if (normalizedSessionId.isEmpty) {
      throw Exception('Missing sessionId');
    }

    try {
      final result = await _functions.httpsCallable('endSession').call({
        'sessionId': normalizedSessionId,
      });
      final data = result.data;

      if (data is! Map) {
        throw Exception('Failed to end session');
      }

      final success = data['success'] != false;
      final returnedSessionId =
          data['sessionId']?.toString() ?? normalizedSessionId;

      if (!success) {
        throw Exception(data['error']?.toString() ?? 'Failed to end session');
      }

      return SessionActionResult(
        success: true,
        sessionId: returnedSessionId,
        barDebt: data['barDebt'] as num?,
      );
    } on FirebaseFunctionsException catch (error) {
      throw Exception(_firebaseMessage(error, 'Failed to end session'));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }
}

String? _fileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return null;
  }

  return fileName.substring(dotIndex + 1).trim();
}

String _firebaseMessage(FirebaseFunctionsException error, String fallback) {
  return error.details?.toString() ?? error.message ?? fallback;
}

String _cleanError(Object error) {
  return error.toString().replaceFirst('Exception: ', '');
}
