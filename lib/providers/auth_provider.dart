import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final DatabaseService _dbService = DatabaseService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;
  String _username = 'User';
  RealtimeChannel? _profileChannel;
  bool _isInitialized = false;

  AuthProvider() {
    _user = _supabaseService.currentUser;
    if (_user != null) {
      _isInitialized = true;
      loadUserProfile();
      subscribeToProfileChanges();
    }

    // Listen to real-time auth changes (sign in, sign out, token refresh)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final newUser = data.session?.user;
      final userChanged = _user?.id != newUser?.id;
      _user = newUser;
      _isInitialized = true;
      
      if (userChanged) {
        if (_user != null) {
          loadUserProfile();
          subscribeToProfileChanges();
        } else {
          _username = 'User';
          _profileChannel?.unsubscribe();
          _profileChannel = null;
        }
      }
      notifyListeners();
    });

    // Fallback: Ensure we mark initialized if Supabase takes too long
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!_isInitialized) {
        _isInitialized = true;
        notifyListeners();
      }
    });
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get username => _username;
  bool get isInitialized => _isInitialized;

  // Clear current error state
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Fetch profile details
  Future<void> loadUserProfile() async {
    if (_user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', _user!.id)
          .maybeSingle();
      if (data != null && data['username'] != null) {
        _username = data['username'] as String;
        notifyListeners();
      }
    } catch (e) {
      print('Error loading user profile: $e');
    }
  }

  // Subscribe to profile changes in real time
  void subscribeToProfileChanges() {
    if (_user == null) return;
    _profileChannel?.unsubscribe();
    _profileChannel = Supabase.instance.client
        .channel('public:profiles:${_user!.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _user!.id,
          ),
          callback: (payload) {
            final newUsername = payload.newRecord['username'] as String?;
            if (newUsername != null) {
              _username = newUsername;
              notifyListeners();
            }
          },
        );
    _profileChannel!.subscribe();
  }

  // Edit user profile name
  Future<bool> updateUsername(String newUsername) async {
    if (_user == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Update profiles table
      await Supabase.instance.client
          .from('profiles')
          .update({
            'username': newUsername,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _user!.id);

      // 2. Update auth user metadata so local app session metadata matches
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'username': newUsername}),
      );

      _username = newUsername;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Log in existing user
  Future<bool> logIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabaseService.logIn(email: email, password: password);
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign up new user
  Future<bool> signUp(String email, String password, String username) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Registration error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Log out current user
  Future<void> logOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      _profileChannel?.unsubscribe();
      _profileChannel = null;
      await _supabaseService.logOut();
      await _dbService.clearLocalCache();
      _user = null;
      _username = 'User';
    } catch (e) {
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
