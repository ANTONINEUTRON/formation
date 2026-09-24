import 'package:formation/features/auth/domain/entities/app_user.dart';

/// Repository interface for authentication operations.
abstract class AuthRepository {
  /// Returns the currently authenticated user, or null if not authenticated.
  AppUser? get currentUser;

  /// Signs in with email and password.
  Future<AppUser> signIn(String email, String password);

  /// Signs out the current user.
  Future<void> signOut();
}
