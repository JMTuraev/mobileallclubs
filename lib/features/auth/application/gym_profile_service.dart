import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_clients.dart';
import '../../../core/utils/backend_action_error.dart';
import '../../../core/utils/phone_utils.dart';

final gymProfileServiceProvider = Provider<GymProfileService>((ref) {
  return GymProfileService(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
    storage: ref.watch(firebaseStorageProvider),
  );
});

class UpdateGymProfileRequest {
  const UpdateGymProfileRequest({
    required this.gymId,
    required this.name,
    required this.city,
    required this.phone,
    this.logoUrl,
    this.removeLogo = false,
  });

  final String gymId;
  final String name;
  final String city;
  final String phone;
  final String? logoUrl;
  final bool removeLogo;
}

class GymProfileService {
  const GymProfileService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
  }) : _auth = auth,
       _firestore = firestore,
       _storage = storage;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<String> uploadGymLogo({
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
        'gyms/$normalizedGymId/branding/'
        '${DateTime.now().millisecondsSinceEpoch}-${currentUserId != null && currentUserId.isNotEmpty ? currentUserId : 'user'}$fileSuffix';
    final ref = _storage.ref().child(uploadPath);

    try {
      await ref.putData(bytes);
      return await ref.getDownloadURL();
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }

  Future<void> updateGymProfile({
    required UpdateGymProfileRequest request,
  }) async {
    final normalizedGymId = request.gymId.trim();
    final normalizedName = request.name.trim();
    final normalizedCity = request.city.trim();
    final normalizedPhone = request.phone.trim();

    if (normalizedGymId.isEmpty) {
      throw Exception('Missing gymId');
    }

    if (normalizedName.isEmpty) {
      throw Exception('Gym name is required');
    }

    if (normalizedPhone.isNotEmpty && !isValidPhoneNumber(normalizedPhone)) {
      throw Exception('Invalid phone number');
    }

    final updates = <String, dynamic>{
      'name': normalizedName,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _putTrimmedOrDelete(updates, 'city', normalizedCity);
    _putTrimmedOrDelete(updates, 'phone', normalizedPhone);

    if (request.removeLogo) {
      for (final field in const [
        'logoUrl',
        'logoURL',
        'logo',
        'imageUrl',
        'image',
        'photoUrl',
        'photoURL',
      ]) {
        updates[field] = FieldValue.delete();
      }
    } else if (request.logoUrl != null && request.logoUrl!.trim().isNotEmpty) {
      final normalizedLogoUrl = request.logoUrl!.trim();
      updates['logoUrl'] = normalizedLogoUrl;
      updates['logo'] = normalizedLogoUrl;
    }

    try {
      await _firestore
          .collection('gyms')
          .doc(normalizedGymId)
          .set(updates, SetOptions(merge: true));
    } catch (error) {
      throw Exception(_cleanError(error));
    }
  }
}

void _putTrimmedOrDelete(
  Map<String, dynamic> updates,
  String field,
  String value,
) {
  if (value.isEmpty) {
    updates[field] = FieldValue.delete();
    return;
  }

  updates[field] = value;
}

String? _fileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return null;
  }

  return fileName.substring(dotIndex + 1).toLowerCase();
}

String _cleanError(Object error) {
  final message = describeBackendActionError(
    error,
    fallback: 'Unexpected error',
  ).trim();
  return message.isEmpty ? 'Unexpected error' : message;
}
