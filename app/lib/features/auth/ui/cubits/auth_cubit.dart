import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/features/auth/domain/entities/app_user.dart';
import 'package:symbians/features/auth/ui/cubits/auth_state.dart';

export 'package:symbians/features/auth/ui/cubits/auth_state.dart';

/// Cubit for managing authentication state.
///
/// Basic implementation - extend as needed.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthInitial());

  /// Signs in with email and password.
  Future<void> signIn(String email, String password) async {
    emit(const AuthLoading());
    // TODO: Implement actual auth
    emit(AuthAuthenticated(
      AppUser(id: '1', email: email),
    ));
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    emit(const AuthLoading());
    emit(const AuthUnauthenticated());
  }
}
