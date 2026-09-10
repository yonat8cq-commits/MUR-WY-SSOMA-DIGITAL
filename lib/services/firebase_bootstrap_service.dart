import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

enum FirebaseConnectionState { initializing, ready, unavailable }

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FirebaseBootstrapService extends ChangeNotifier {
  FirebaseBootstrapService._();

  static final instance = FirebaseBootstrapService._();

  FirebaseConnectionState state = FirebaseConnectionState.initializing;
  String? error;
  String? messagingToken;

  bool get isReady => state == FirebaseConnectionState.ready;

  Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      state = FirebaseConnectionState.ready;
      error = null;
      notifyListeners();

      try {
        messagingToken = await FirebaseMessaging.instance.getToken();
        notifyListeners();
      } catch (_) {
        // El token se obtendrá de nuevo cuando el dispositivo tenga conexión.
      }
    } catch (exception) {
      state = FirebaseConnectionState.unavailable;
      error = exception.toString();
      notifyListeners();
      debugPrint('Firebase no disponible: $exception');
    }
  }
}
