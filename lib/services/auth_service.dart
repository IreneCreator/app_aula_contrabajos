import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static Stream<User?> get cambios => _auth.authStateChanges();

  static Future<void> entrarConGoogle() async {
    await _auth.signInWithPopup(GoogleAuthProvider());
  }

  static Future<void> salir() => _auth.signOut();
}
