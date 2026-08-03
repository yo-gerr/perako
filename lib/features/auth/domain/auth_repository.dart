import 'package:firebase_auth/firebase_auth.dart';

/// Wraps [FirebaseAuth] so the rest of the app (and tests) never touch the
/// Firebase SDK directly.
abstract class AuthRepository {
  String? get currentUid;

  Stream<String?> get authStateChanges;

  Future<String?> signInWithEmail(String email, String password);

  Future<void> signOut();
}

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Stream<String?> get authStateChanges {
    return _auth.authStateChanges().map((u) => u?.uid);
  }

  @override
  Future<String?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user?.uid;
  }

  @override
  Future<void> signOut() => _auth.signOut();
}