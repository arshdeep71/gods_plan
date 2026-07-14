import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get currently logged-in user
  User? get currentUser => _client.auth.currentUser;

  // Get current user session
  Session? get currentSession => _client.auth.currentSession;

  // Register user with email, password and a username
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
      },
    );
    
    // Create database entry in public.profiles table after sign up
    if (response.user != null) {
      try {
        await _client.from('profiles').upsert({
          'id': response.user!.id,
          'username': username,
          'email': email,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        // Log database profile creation failure but do not crash the signup process
        print('Profile upsert warning: $e');
      }
    }
    
    return response;
  }

  // Log in user with email & password
  Future<AuthResponse> logIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Log out current user
  Future<void> logOut() async {
    await _client.auth.signOut();
  }

  // Check if session is active/valid
  bool isAuthenticated() {
    return _client.auth.currentSession != null;
  }
}
