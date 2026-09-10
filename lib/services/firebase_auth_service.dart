import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_bootstrap_service.dart';
import 'firebase_sync_service.dart';

enum CentralLoginResult { authenticated, localOnly }

class FirebaseAuthService {
  FirebaseAuthService._();

  static final instance = FirebaseAuthService._();

  String emailForDni(String dni) => '$dni@auth.murwy.local';

  bool get hasCentralSession => FirebaseBootstrapService.instance.isReady &&
      FirebaseAuth.instance.currentUser != null;

  Future<CentralLoginResult> signInWorker({
    required String dni,
    required String password,
  }) async {
    if (!FirebaseBootstrapService.instance.isReady) {
      return CentralLoginResult.localOnly;
    }
    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailForDni(dni),
        password: password,
      );
      await credential.user?.getIdToken(true);
      unawaited(FirebaseSyncService.instance.syncPending());
      return CentralLoginResult.authenticated;
    } on FirebaseAuthException {
      // La cuenta central puede estar aún sin provisionar o el celular sin red.
      // La validación local ya protegió el acceso y permite seguir trabajando.
      return CentralLoginResult.localOnly;
    }
  }

  Future<bool> updateCurrentPassword(String password) async {
    if (!FirebaseBootstrapService.instance.isReady) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      await user.updatePassword(password);
      await user.getIdToken(true);
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  Future<void> signOut() async {
    if (!FirebaseBootstrapService.instance.isReady) return;
    await FirebaseAuth.instance.signOut();
  }
}
