import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const firebaseFunctionsRegion = 'asia-south1';

final firebaseAppProvider = Provider<FirebaseApp>((ref) => Firebase.app());

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firebaseFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final firebaseFunctionsProvider = Provider<FirebaseFunctions>(
  (ref) => firebaseFunctionsInstance(app: ref.watch(firebaseAppProvider)),
);

final firebaseStorageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instanceFor(app: ref.watch(firebaseAppProvider)),
);

FirebaseFunctions firebaseFunctionsInstance({FirebaseApp? app}) {
  return FirebaseFunctions.instanceFor(
    app: app,
    region: firebaseFunctionsRegion,
  );
}
