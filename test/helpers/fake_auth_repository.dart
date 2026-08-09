import 'dart:async';

import 'package:perako/features/auth/domain/auth_repository.dart';

/// In-memory [AuthRepository] for widget/unit tests.
class FakeAuthRepository implements AuthRepository {
  String? uid;
  String? email;
  final _controller = StreamController<String?>.broadcast();

  void signIn(String newUid, {String? newEmail}) {
    uid = newUid;
    email = newEmail ?? 'user@test.local';
    _controller.add(newUid);
  }

  void signOutUser() {
    uid = null;
    email = null;
    _controller.add(null);
  }

  @override
  String? get currentUid => uid;

  @override
  String? get currentEmail => email;

  @override
  Stream<String?> get authStateChanges => _controller.stream;

  @override
  Future<String?> signInWithEmail(String email, String password) async {
    signIn('uid_$email', newEmail: email);
    return currentUid;
  }

  @override
  Future<void> signOut() async => signOutUser();
}