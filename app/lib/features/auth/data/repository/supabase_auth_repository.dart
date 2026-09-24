import 'package:formation/features/auth/domain/entities/app_user.dart';
import 'package:formation/features/auth/domain/repositories/auth_repository.dart';

/// Supabase implementation of [AuthRepository].
///
/// Basic stub - implement actual Supabase calls as needed.
class SupabaseAuthRepository implements AuthRepository {
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Future<AppUser> signIn(String email, String password) async {
    // TODO: Implement actual Supabase auth
    _currentUser = AppUser(id: '1', email: email);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    // TODO: Implement actual Supabase sign out
    _currentUser = null;
  }
}
